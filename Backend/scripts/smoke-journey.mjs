/**
 * Smoke test for /api/journey. Builds a small fixture timetable, boots the
 * real server against it on a spare port, and asserts the planner's core
 * behaviours:
 *   1. direct options rank the nearest boarding stop first
 *   2. one-change journeys board at the nearest stop, include the walk leg,
 *      calling points, and a physically makeable connection
 *   3. yesterday's past-midnight (24:xx) trips are found and normalised
 *
 * Run: npm test   (safe anywhere — uses its own temp DB, never data/)
 */
import Database from "better-sqlite3";
import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PORT = 3197;
const backendRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const dbPath = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "buspulse-smoke-")), "gtfs.sqlite");

// ---- Fixture ---------------------------------------------------------------

const db = new Database(dbPath);
db.exec(`
  CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
  CREATE TABLE routes (id INTEGER PRIMARY KEY AUTOINCREMENT, gtfs_id TEXT UNIQUE NOT NULL,
    line_name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', mode TEXT);
  CREATE TABLE stops (atco TEXT PRIMARY KEY, naptan_code TEXT, name TEXT NOT NULL,
    lat REAL NOT NULL, lon REAL NOT NULL);
  CREATE TABLE trips (id INTEGER PRIMARY KEY AUTOINCREMENT, gtfs_id TEXT UNIQUE NOT NULL,
    route_id INTEGER NOT NULL, service_id TEXT NOT NULL, headsign TEXT, shape_id TEXT,
    start_seconds INTEGER);
  CREATE TABLE stop_times (trip_id INTEGER NOT NULL, seq INTEGER NOT NULL, atco TEXT NOT NULL,
    arrival_seconds INTEGER, departure_seconds INTEGER);
  CREATE TABLE calendar (service_id TEXT PRIMARY KEY, monday INTEGER, tuesday INTEGER,
    wednesday INTEGER, thursday INTEGER, friday INTEGER, saturday INTEGER, sunday INTEGER,
    start_date TEXT, end_date TEXT);
  CREATE TABLE calendar_dates (service_id TEXT NOT NULL, date TEXT NOT NULL, exception_type INTEGER NOT NULL);
  CREATE TABLE shapes (shape_id TEXT NOT NULL, seq INTEGER NOT NULL, lat REAL NOT NULL, lon REAL NOT NULL);
  CREATE TABLE route_stops (route_id INTEGER NOT NULL, atco TEXT NOT NULL, PRIMARY KEY (route_id, atco));
  CREATE INDEX idx_stop_times_trip ON stop_times (trip_id, seq);
  CREATE INDEX idx_stop_times_atco ON stop_times (atco);
  CREATE INDEX idx_trips_route ON trips (route_id);
  CREATE INDEX idx_stops_geo ON stops (lat, lon);
  CREATE INDEX idx_calendar_dates ON calendar_dates (date);
  CREATE INDEX idx_route_stops_atco ON route_stops (atco);
`);

// "now" in UK seconds-since-midnight, matching the server's clock.
const parts = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Europe/London", hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false,
}).formatToParts(new Date());
const v = (t) => Number(parts.find((p) => p.type === t)?.value ?? 0);
const now = (v("hour") % 24) * 3600 + v("minute") * 60 + v("second");

// Origin at (55.000, -1.600). NEAR is ~100m away, FAR ~500m. Direct buses run
// to CITY; the change-needed destination is VILL via INT1→INT2 (~200m walk).
const stops = [
  ["NEAR", "Home St Near", 55.0009, -1.6000],
  ["FAR",  "Home St Far",  55.0045, -1.6000],
  ["CITY", "City Centre",  55.0201, -1.6201],
  ["INT1", "Interchange A", 55.0500, -1.6500],
  ["INT2", "Interchange B", 55.0518, -1.6500],
  ["VILL", "Village Green", 55.1001, -1.7001],
];
const insStop = db.prepare("INSERT INTO stops VALUES (?, ?, ?, ?, ?)");
for (const [atco, name, lat, lon] of stops) insStop.run(atco, atco.toLowerCase(), name, lat, lon);
db.prepare("INSERT INTO calendar VALUES ('WK',1,1,1,1,1,1,1,'20200101','20301231')").run();
db.prepare("INSERT INTO meta VALUES ('imported_at', 'fixture')").run();

const insRoute = db.prepare("INSERT INTO routes (gtfs_id, line_name, description, mode) VALUES (?, ?, ?, 'bus')");
const insTrip = db.prepare("INSERT INTO trips (gtfs_id, route_id, service_id, headsign, start_seconds) VALUES (?, ?, 'WK', ?, ?)");
const insST = db.prepare("INSERT INTO stop_times VALUES (?, ?, ?, ?, ?)");
const insRS = db.prepare("INSERT OR IGNORE INTO route_stops VALUES (?, ?)");
function addTrip(routeId, gtfsId, headsign, calls) {
  const t = insTrip.run(gtfsId, routeId, headsign, calls[0][1]).lastInsertRowid;
  calls.forEach(([atco, secs], i) => { insST.run(t, i + 1, atco, secs, secs); insRS.run(routeId, atco); });
}

// X1: direct, boards at the NEAR (100m) stop — must rank first.
const x1 = insRoute.run("X1", "X1", "Home - City").lastInsertRowid;
addTrip(x1, "X1-a", "City", [["NEAR", now + 600], ["CITY", now + 1800]]);
// X1 short working: departs NEAR but terminates before CITY — its time must
// NOT appear among X1's departures.
addTrip(x1, "X1-short", "Short", [["NEAR", now + 60], ["FAR", now + 300]]);
// X1 night bus on YESTERDAY's service day (24:xx) — must appear, normalised.
addTrip(x1, "X1-night", "City", [["NEAR", now + 86_400 + 1200], ["CITY", now + 86_400 + 2400]]);
// X2: direct from the FAR (500m) stop — ranks second.
const x2 = insRoute.run("X2", "X2", "Home - City express").lastInsertRowid;
addTrip(x2, "X2-a", "City", [["FAR", now + 300], ["CITY", now + 1500]]);

// A second "X1" hundreds of miles south — search with a location must rank
// the local one first, not this one.
const [southA, southB] = [["SA", "South Stop A", 51.0, -1.0], ["SB", "South Stop B", 51.02, -1.02]];
insStop.run(southA[0], "sa", southA[1], southA[2], southA[3]);
insStop.run(southB[0], "sb", southB[1], southB[2], southB[3]);
const southX1 = insRoute.run("S-X1", "X1", "").lastInsertRowid;
addTrip(southX1, "S-X1-a", "Southville", [["SA", now + 600], ["SB", now + 1200]]);

// A route whose trips carry NO headsigns (common in parts of the data):
// stop lists must still get a direction label, from the trip's final stop.
const r77 = insRoute.run("77", "77", "").lastInsertRowid;
addTrip(r77, "77-a", null, [["NEAR", now + 7200], ["CITY", now + 8400]]);

// One-change to VILL. The FAR bus (11) reaches the interchange EARLIER, but
// the planner must board at NEAR (10) — nearest stop wins.
const r10 = insRoute.run("10", "10", "Home - Interchange").lastInsertRowid;
addTrip(r10, "10-a", "Interchange", [["NEAR", now + 900], ["INT1", now + 1500]]);
const r11 = insRoute.run("11", "11", "Home - Interchange fast").lastInsertRowid;
addTrip(r11, "11-a", "Interchange", [["FAR", now + 600], ["INT1", now + 1200]]);
const r22 = insRoute.run("22", "22", "Interchange - Village").lastInsertRowid;
addTrip(r22, "22-a", "Village", [["INT2", now + 2400], ["VILL", now + 3300]]);
db.close();

// ---- Boot the real server against the fixture ------------------------------

const server = spawn(process.execPath, ["src/server.js"], {
  cwd: backendRoot,
  env: {
    ...process.env, PORT: String(PORT), DB_PATH: dbPath,
    APP_SHARED_TOKEN: "", BODS_API_KEY: "", NODE_ENV: "test",
  },
  stdio: "ignore",
});

const get = async (query) => {
  const response = await fetch(`http://localhost:${PORT}/api/journey?${query}`);
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.json();
};

let failures = 0;
const check = (label, ok) => {
  console.log(`${ok ? "  ✓" : "  ✗ FAIL"} ${label}`);
  if (!ok) failures += 1;
};
const toSecs = (t) => t.split(":").reduce((acc, n) => acc * 60 + Number(n), 0);

try {
  // Wait for the server to accept connections (up to ~10s).
  for (let attempt = 0; ; attempt += 1) {
    try {
      await fetch(`http://localhost:${PORT}/health`);
      break;
    } catch {
      if (attempt >= 40) throw new Error("server did not start");
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }

  console.log("direct (origin → City):");
  const d = await get("fromLat=55.0&fromLon=-1.6&toLat=55.02&toLon=-1.62");
  check("direct options include the near and far routes",
        [x1, x2].every((id) => d.options.some((o) => o.service.id === id)));
  check("nearest stop (100m) ranks first",
        d.options[0]?.from?.atco === "NEAR" && d.options[0]?.from?.walk_meters <= 150);
  check("short working not listed as a departure",
        !(d.options[0]?.departures ?? []).includes(secondsToClock(now + 60)));
  check("yesterday's 24:xx night bus listed, normalised to today's clock",
        (d.options[0]?.departures ?? []).includes(secondsToClock(now + 1200)));
  check("live_vehicles field present", typeof d.options[0]?.live_vehicles === "number");

  console.log("one-change (origin → Village):");
  const c = await get("fromLat=55.0&fromLon=-1.6&toLat=55.1&toLon=-1.7");
  const journey = c.interchange?.[0];
  check("an interchange journey is returned", Boolean(journey));
  check("no direct options for this trip", (c.options ?? []).length === 0);
  check("boards at the nearest (100m) stop even though the far bus arrives sooner",
        journey?.legs?.[0]?.from?.atco === "NEAR");
  check("walk leg present (~200m)",
        journey?.legs?.[1]?.mode === "walk" && Math.abs(journey.legs[1].meters - 200) < 50);
  check("calling points on both bus legs",
        (journey?.legs?.[0]?.stops?.length ?? 0) >= 2 && (journey?.legs?.at(-1)?.stops?.length ?? 0) >= 2);
  const leg1Arr = journey?.legs?.[0]?.arrival, leg2Dep = journey?.legs?.at(-1)?.departure;
  check("connection is physically makeable (≥3 min + walk)",
        leg1Arr && leg2Dep && toSecs(leg2Dep) - toSecs(leg1Arr) >= 180);

  console.log("route search (two X1s in the country, user in the north):");
  const searchURL = `http://localhost:${PORT}/api/services/?search=X1&lat=55.0&lon=-1.6`;
  const s = await (await fetch(searchURL)).json();
  check("local X1 ranks first", s.results?.[0]?.id === x1);
  check("the distant X1 still appears, after it", s.results?.some((r) => r.id === southX1));
  check("descriptions come from the route's own destinations, not the stored name",
        s.results?.[0]?.description?.includes("City"));

  console.log("stops on a route (direction-grouped, journey order):");
  const st = await (await fetch(`http://localhost:${PORT}/api/stops/?service=${x1}`)).json();
  check("first stop is the origin in journey order, not alphabetical",
        st.results?.[0]?.atco_code === "NEAR");
  check("stops carry a direction label", (st.results?.[0]?.direction ?? "").startsWith("Towards"));
  check("no stop listed twice",
        new Set(st.results?.map((r) => r.atco_code)).size === (st.results?.length ?? 0));
  const st77 = await (await fetch(`http://localhost:${PORT}/api/stops/?service=${r77}`)).json();
  check("routes without headsigns still get directions (from the final stop)",
        st77.results?.[0]?.direction === "Towards City Centre");
} catch (error) {
  console.error("smoke test errored:", error.message);
  failures += 1;
} finally {
  server.kill();
  fs.rmSync(path.dirname(dbPath), { recursive: true, force: true });
}

function secondsToClock(seconds) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(Math.floor(seconds / 3600))}:${pad(Math.floor((seconds % 3600) / 60))}:${pad(seconds % 60)}`;
}

console.log(failures === 0 ? "\nAll journey smoke tests passed." : `\n${failures} check(s) FAILED.`);
process.exit(failures === 0 ? 0 : 1);
