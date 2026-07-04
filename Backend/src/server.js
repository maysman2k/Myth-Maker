/**
 * BusPulse backend — serves the same paths and JSON shapes as
 * bustimes.org's public endpoints, backed entirely by your own BODS data.
 * Swapping the app over is a base-URL change only.
 */
import express from "express";
import rateLimit from "express-rate-limit";
import { config } from "./config.js";
import { activeServiceIDs, dbGeneration, dbStats, openDB, secondsToTime } from "./db.js";
import { startPolling, VehicleStore } from "./bods/vehiclePoller.js";
import { startSiriPolling } from "./bods/siriPoller.js";
import { ApnsClient } from "./apns/apnsClient.js";
import { DeviceStore } from "./apns/deviceStore.js";
import { scheduleDailyImport } from "./scheduler.js";

const app = express();
const store = new VehicleStore();
const apns = new ApnsClient();
const devices = new DeviceStore();

app.use(express.json({ limit: "16kb" }));

// Behind a reverse proxy (TLS terminator) in production, so client IPs and
// the secure flag come from forwarded headers.
app.set("trust proxy", 1);
app.disable("x-powered-by");

// Minimal security headers. HSTS only takes effect once served over HTTPS
// (the production reverse proxy), and is harmless otherwise.
app.use((req, res, next) => {
  res.set("Cache-Control", "no-store");
  res.set("X-Content-Type-Options", "nosniff");
  res.set("Referrer-Policy", "no-referrer");
  res.set("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
  next();
});

// Rate limit every client by IP to blunt scraping and denial-of-service.
app.use(rateLimit({
  windowMs: 60_000,
  limit: config.rateLimitPerMinute,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests. Slow down and try again shortly." },
}));

// Optional shared-token gate. Off unless APP_SHARED_TOKEN is set, so local
// development is unaffected; /health stays open for uptime checks.
app.use((req, res, next) => {
  if (!config.appSharedToken
      || req.path === "/health"
      || req.path === "/devices"
      || req.path === "/share"
      || req.path.startsWith("/api/debug/")
      || req.path.startsWith("/.well-known/")) return next();
  if (req.get("x-app-token") === config.appSharedToken) return next();
  res.status(401).json({ error: "Unauthorised." });
});

// MARK: Push — register a device token, plus an admin test push

app.post("/devices", (req, res) => {
  devices.add(req.body?.token);
  res.json({ ok: true });
});

app.post("/admin/test-push", async (req, res) => {
  if (!config.adminKey || req.get("x-admin-key") !== config.adminKey) {
    return res.status(401).json({ error: "Unauthorised." });
  }
  if (!apns.configured) {
    return res.status(503).json({ error: "APNs is not configured on the server." });
  }
  const targets = req.body?.token ? [req.body.token] : devices.all();
  if (targets.length === 0) return res.json({ sent: 0, note: "No devices registered yet." });

  const results = [];
  for (const token of targets) {
    const result = await apns.send(token, {
      title: "Wait Less",
      body: "Test push — your alarms are ready to go. 🚌",
    });
    if (result.status === 410) devices.remove(token); // token no longer valid
    results.push({ token: `${token.slice(0, 8)}…`, ...result });
  }
  res.json({ sent: results.length, results });
});

function parseBBox(query) {
  const [xmin, ymin, xmax, ymax] = ["xmin", "ymin", "xmax", "ymax"].map((k) =>
    Number(query[k]),
  );
  if (![xmin, ymin, xmax, ymax].every(Number.isFinite)) return null;
  // Reject absurd boxes (defence in depth; the app already clamps).
  const area = Math.abs(xmax - xmin) * Math.abs(ymax - ymin);
  if (area > config.maxQueryBBoxArea) return null;
  return { xmin, ymin, xmax, ymax };
}

function parseIntList(value) {
  return String(value ?? "")
    .split(",")
    .map((s) => Number(s.trim()))
    .filter(Number.isInteger);
}

// MARK: Live vehicles — GET /vehicles.json

app.get("/vehicles.json", (req, res) => {
  let vehicles = [];
  if (req.query.service) {
    vehicles = store.onServices(parseIntList(req.query.service));
  } else {
    const box = parseBBox(req.query);
    if (!box) return res.status(400).json({ error: "xmin/ymin/xmax/ymax or service required" });
    vehicles = store.inBoundingBox(box.xmin, box.ymin, box.xmax, box.ymax);
  }
  res.json(vehicles.map(({ _seenAt, ...vehicle }) => vehicle));
});

// MARK: Stops in a bounding box — GET /stops.json (GeoJSON)

app.get("/stops.json", (req, res) => {
  const box = parseBBox(req.query);
  if (!box) return res.status(400).json({ error: "xmin/ymin/xmax/ymax required" });

  const db = openDB();
  const stops = db
    .prepare(
      `SELECT atco, naptan_code, name, lat, lon FROM stops
       WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ? LIMIT 500`,
    )
    .all(box.ymin, box.ymax, box.xmin, box.xmax);

  const lineNames = db.prepare(
    `SELECT routes.line_name AS name FROM route_stops
     JOIN routes ON routes.id = route_stops.route_id
     WHERE route_stops.atco = ? ORDER BY routes.line_name LIMIT 12`,
  );

  res.json({
    type: "FeatureCollection",
    features: stops.map((stop) => ({
      type: "Feature",
      geometry: { type: "Point", coordinates: [stop.lon, stop.lat] },
      properties: {
        name: stop.name,
        indicator: null,
        bearing: null,
        url: `/stops/${stop.atco}`,
        services: lineNames.all(stop.atco).map((r) => r.name),
      },
    })),
  });
});

// MARK: Stop lookup — GET /api/stops/

app.get("/api/stops/", (req, res) => {
  const db = openDB();
  let rows = [];

  const naptan = req.query.naptan_code__iexact ?? req.query.naptan_code;
  if (naptan) {
    rows = db
      .prepare(
        "SELECT * FROM stops WHERE naptan_code = ? COLLATE NOCASE OR atco = ? LIMIT 5",
      )
      .all(String(naptan), String(naptan));
  } else if (req.query.service) {
    rows = stopsAlongRoute(db, Number(req.query.service));
  }

  const lineNames = db.prepare(
    `SELECT routes.line_name AS name FROM route_stops
     JOIN routes ON routes.id = route_stops.route_id
     WHERE route_stops.atco = ? ORDER BY routes.line_name LIMIT 12`,
  );

  res.json({
    results: rows.map((stop) => ({
      atco_code: stop.atco,
      naptan_code: stop.naptan_code,
      common_name: stop.name,
      name: stop.name,
      long_name: stop.name,
      location: [stop.lon, stop.lat],
      indicator: null,
      bearing: null,
      direction: stop.direction ?? null,
      line_names: lineNames.all(stop.atco).map((r) => r.name),
    })),
    next: null,
  });
});

/// Stops for a route in JOURNEY ORDER, split by direction — not an
/// alphabetical soup where every stop appears twice (once per side of the
/// road). Each direction's order comes from its longest timetabled trip;
/// stops only served by variant journeys are appended unlabelled.
/// One representative (longest) trip per direction of a route. Directions come
/// from trip headsigns where the data has them; where it doesn't, fall back to
/// the longest trips outright, labelled by each one's final stop.
function representativeTrips(db, routeID) {
  const representatives = [];
  const headsigns = db
    .prepare(
      `SELECT headsign, COUNT(*) AS c FROM trips
       WHERE route_id = ? AND headsign IS NOT NULL AND headsign <> ''
       GROUP BY headsign ORDER BY c DESC LIMIT 2`,
    )
    .all(routeID)
    .map((r) => r.headsign);
  if (headsigns.length > 0) {
    const longestTrip = db.prepare(
      `SELECT trips.id AS id FROM trips JOIN stop_times st ON st.trip_id = trips.id
       WHERE trips.route_id = ? AND trips.headsign = ?
       GROUP BY trips.id ORDER BY COUNT(*) DESC LIMIT 1`,
    );
    for (const headsign of headsigns) {
      const tripID = longestTrip.get(routeID, headsign)?.id;
      if (tripID) representatives.push({ tripID, label: `Towards ${headsign}` });
    }
  } else {
    const longest = db
      .prepare(
        `SELECT trips.id AS id FROM trips JOIN stop_times st ON st.trip_id = trips.id
         WHERE trips.route_id = ? GROUP BY trips.id ORDER BY COUNT(*) DESC LIMIT 8`,
      )
      .all(routeID);
    const lastStop = db.prepare(
      `SELECT stops.name AS name FROM stop_times JOIN stops ON stops.atco = stop_times.atco
       WHERE trip_id = ? ORDER BY seq DESC LIMIT 1`,
    );
    const seenTermini = new Set();
    for (const { id } of longest) {
      const terminus = lastStop.get(id)?.name;
      if (!terminus || seenTermini.has(terminus)) continue;
      seenTermini.add(terminus);
      representatives.push({ tripID: id, label: `Towards ${terminus}` });
      if (representatives.length === 2) break;
    }
  }
  return representatives;
}

function stopsAlongRoute(db, routeID) {
  const tripStops = db.prepare(
    `SELECT stops.* FROM stop_times JOIN stops ON stops.atco = stop_times.atco
     WHERE stop_times.trip_id = ? ORDER BY stop_times.seq LIMIT 200`,
  );
  const representatives = representativeTrips(db, routeID);

  const seen = new Set();
  const out = [];
  for (const { tripID, label } of representatives) {
    for (const stop of tripStops.all(tripID)) {
      if (seen.has(stop.atco)) continue;
      seen.add(stop.atco);
      out.push({ ...stop, direction: label });
    }
  }

  for (const stop of db
    .prepare(
      `SELECT stops.* FROM route_stops JOIN stops ON stops.atco = route_stops.atco
       WHERE route_stops.route_id = ? ORDER BY stops.name LIMIT 400`,
    )
    .all(routeID)) {
    if (seen.has(stop.atco)) continue;
    seen.add(stop.atco);
    out.push({ ...stop, direction: null });
  }
  return out.slice(0, 400);
}

// MARK: Services — GET /api/services/

app.get("/api/services/", (req, res) => {
  const db = openDB();
  let rows = [];

  if (req.query.search) {
    // Bound the search term: ignore trivially short queries and cap length
    // so a single request can't ask for an expensive scan.
    const raw = String(req.query.search).trim().slice(0, 60);
    if (raw.length < 1) return res.json({ results: [], next: null });
    const term = `%${raw}%`;
    const lat = Number(req.query.lat);
    const lon = Number(req.query.lon);
    const hasLocation = Number.isFinite(lat) && Number.isFinite(lon);

    // Rank: exact line-name match, then prefix, then contains — and within a
    // tier, NEAREST first when the client says where it is. A national
    // dataset has dozens of "X7"s; without locality the user's own is buried.
    // Match line number OR destination. Destinations live in trip headsigns,
    // not the (usually empty) description column, so a plain SQL LIKE on
    // routes can't find "Southampton". Search a cached index whose haystack
    // includes each route's derived description (its headsign termini).
    const needleRaw = raw.toLowerCase();
    const candidates = buildRouteSearchIndex(db)
      .filter((e) => e.haystack.includes(needleRaw))
      .slice(0, 300)
      .map((e) => e.route);
    const centroidStmt = db.prepare(
      `SELECT AVG(lat) AS lat, AVG(lon) AS lon
       FROM route_stops JOIN stops ON stops.atco = route_stops.atco
       WHERE route_stops.route_id = ?`,
    );
    const needle = raw.toLowerCase();
    const scored = candidates.map((route) => {
      const name = route.line_name.toLowerCase();
      const tier = name === needle ? 0 : name.startsWith(needle) ? 1 : 2;
      let distance = 9e9;
      if (hasLocation) {
        const centroid = centroidStmt.get(route.id);
        if (centroid?.lat != null) distance = metresBetween(lat, lon, centroid.lat, centroid.lon);
      }
      return { route, tier, distance };
    });
    scored.sort((a, b) =>
      a.tier - b.tier
      || a.distance - b.distance
      || a.route.line_name.length - b.route.line_name.length
      || a.route.line_name.localeCompare(b.route.line_name));

    // Collapse duplicates (same number, same description — typically the same
    // service imported once per direction or dataset), keeping the nearest.
    const seen = new Set();
    for (const { route } of scored) {
      const key = `${route.line_name.toLowerCase()}|${describeRoute(db, route).toLowerCase()}`;
      if (seen.has(key)) continue;
      seen.add(key);
      rows.push(route);
      if (rows.length >= 40) break;
    }
  } else if (req.query.stops) {
    rows = db
      .prepare(
        `SELECT routes.* FROM route_stops
         JOIN routes ON routes.id = route_stops.route_id
         WHERE route_stops.atco = ? ORDER BY routes.line_name LIMIT 60`,
      )
      .all(String(req.query.stops));
  }

  res.json({
    results: rows.map((route) => ({
      id: route.id,
      slug: null,
      line_name: route.line_name,
      description: describeRoute(db, route),
      mode: route.mode,
    })),
    next: null,
  });
});

/**
 * A human description for a route, derived from its own trips' destinations
 * (the two most common headsigns → "Newcastle – Blyth"). The GTFS
 * route_long_name is deliberately NOT trusted first: in the national BODS
 * feed it is frequently wrong — a North Tyneside X7 arrives labelled
 * "Salisbury – Southampton" — whereas headsigns describe the actual
 * journeys. The stored name is only a fallback when trips carry no headsign.
 */
/// Searchable index of every route: line number plus its derived description
/// (destination termini), so search matches place names as well as numbers.
/// Cached per database generation; rebuilt after the nightly import swap.
let routeSearchIndex = [];
let routeSearchIndexGeneration = -1;
function buildRouteSearchIndex(db) {
  if (routeSearchIndexGeneration === dbGeneration() && routeSearchIndex.length) {
    return routeSearchIndex;
  }
  const started = process.hrtime.bigint();
  routeSearchIndex = db.prepare("SELECT * FROM routes").all().map((route) => ({
    route,
    haystack: `${route.line_name} ${describeRoute(db, route)}`.toLowerCase(),
  }));
  routeSearchIndexGeneration = dbGeneration();
  const ms = Number(process.hrtime.bigint() - started) / 1e6;
  console.log(`Route search index built: ${routeSearchIndex.length} routes in ${ms.toFixed(0)}ms.`);
  return routeSearchIndex;
}

const routeDescriptionCache = new Map();
let routeDescriptionGeneration = -1;
function describeRoute(db, route) {
  if (routeDescriptionGeneration !== dbGeneration()) {
    routeDescriptionCache.clear();
    routeDescriptionGeneration = dbGeneration();
  }
  if (routeDescriptionCache.has(route.id)) return routeDescriptionCache.get(route.id);

  const headsigns = db
    .prepare(
      `SELECT headsign, COUNT(*) AS c FROM trips
       WHERE route_id = ? AND headsign IS NOT NULL AND headsign <> ''
       GROUP BY headsign ORDER BY c DESC LIMIT 2`,
    )
    .all(route.id)
    .map((r) => r.headsign);

  let description;
  if (headsigns.length >= 2) description = `${headsigns[0]} – ${headsigns[1]}`;
  else if (headsigns.length === 1) description = `Towards ${headsigns[0]}`;
  else if (route.description && route.description.trim()) description = route.description.trim();
  else description = route.mode ? `${route.mode[0].toUpperCase()}${route.mode.slice(1)} service` : "Bus service";

  routeDescriptionCache.set(route.id, description);
  return description;
}

// MARK: Timetable trips — GET /api/trips/ and /api/trips/:id/

function tripJSON(db, trip) {
  const times = db
    .prepare(
      `SELECT stop_times.*, stops.name AS stop_name, stops.lat AS stop_lat, stops.lon AS stop_lon
       FROM stop_times
       LEFT JOIN stops ON stops.atco = stop_times.atco
       WHERE trip_id = ? ORDER BY seq`,
    )
    .all(trip.id);
  return {
    id: trip.id,
    headsign: trip.headsign,
    times: times.map((t) => ({
      stop: {
        atco_code: t.atco,
        name: t.stop_name ?? t.atco,
        location: (t.stop_lon != null && t.stop_lat != null) ? [t.stop_lon, t.stop_lat] : null,
      },
      aimed_arrival_time: secondsToTime(t.arrival_seconds),
      aimed_departure_time: secondsToTime(t.departure_seconds),
    })),
  };
}

app.get("/api/trips/", (req, res) => {
  const db = openDB();
  const serviceID = Number(req.query.service);
  if (!Number.isInteger(serviceID)) {
    return res.status(400).json({ error: "service required" });
  }
  const date = String(req.query.date ?? new Date().toISOString().slice(0, 10));
  const active = activeServiceIDs(date);

  const trips = db
    .prepare("SELECT * FROM trips WHERE route_id = ? ORDER BY start_seconds")
    .all(serviceID)
    .filter((trip) => active.has(trip.service_id));

  res.json({ results: trips.map((trip) => tripJSON(db, trip)), next: null });
});

app.get("/api/trips/:id/", (req, res) => {
  const db = openDB();
  const trip = db.prepare("SELECT * FROM trips WHERE id = ?").get(Number(req.params.id));
  if (!trip) return res.status(404).json({ error: "trip not found" });
  res.json(tripJSON(db, trip));
});

// MARK: Journey planner — GET /api/journey (direct buses only, v1)
// Finds routes whose journeys call at a stop near the start before a stop
// near the destination, with the next few departures. No transfers yet.

function ukSecondsSinceMidnight(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/London", hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false,
  }).formatToParts(date);
  const value = (type) => Number(parts.find((p) => p.type === type)?.value ?? 0);
  return (value("hour") % 24) * 3600 + value("minute") * 60 + value("second");
}

/// "YYYY-MM-DD" in UK local time, optionally shifted by whole days. (Using the
/// UTC date instead is subtly wrong for the first BST hour after midnight.)
function ukDateString(offsetDays = 0) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/London" })
    .format(new Date(Date.now() + offsetDays * 86_400_000));
}

/// Count of live vehicles that look like this route, near the given stops —
/// same heuristic as the app's on-map matcher: a matched GTFS-RT route id, or
/// the same line name inside the corridor. Presence, not punctuality: lateness
/// needs the trip-updates feed (GTFS-RT ids ≠ static ids), a planned follow-up.
function liveVehiclesNear(routeID, lineName, points) {
  const coords = points.filter((p) => Number.isFinite(p?.lat) && Number.isFinite(p?.lon));
  if (coords.length === 0) return 0;
  const pad = 0.05; // ~5 km
  const lats = coords.map((p) => p.lat);
  const lons = coords.map((p) => p.lon);
  const nearby = store.inBoundingBox(
    Math.min(...lons) - pad, Math.min(...lats) - pad,
    Math.max(...lons) + pad, Math.max(...lats) + pad, 500,
  );
  const name = (lineName ?? "").trim().toLowerCase();
  return nearby.filter(
    (v) => v.service_id === routeID
      || (name && (v.service?.line_name ?? "").trim().toLowerCase() === name),
  ).length;
}

/// Straight-line distance in metres (equirectangular — accurate enough at the
/// short ranges used here, and cheap).
function metresBetween(lat1, lon1, lat2, lon2) {
  const x = (lon2 - lon1) * 111_320 * Math.cos((lat1 * Math.PI) / 180);
  const y = (lat2 - lat1) * 111_320;
  return Math.sqrt(x * x + y * y);
}

app.get("/api/journey", (req, res) => {
  const db = openDB();
  const fromLat = Number(req.query.fromLat);
  const fromLon = Number(req.query.fromLon);
  const toLat = Number(req.query.toLat);
  const toLon = Number(req.query.toLon);
  if (![fromLat, fromLon, toLat, toLon].every(Number.isFinite)) {
    return res.status(400).json({ error: "fromLat/fromLon/toLat/toLon required" });
  }

  // Stops within `radiusM` of a point, NEAREST FIRST, capped. Ordering by
  // distance (not arbitrary rowid) matters in dense city centres, where a
  // blind LIMIT could silently drop the very interchange the rider wants.
  const stopsNear = (lat, lon, radiusM, cap) => {
    const dLat = radiusM / 111_320;
    const dLon = dLat / Math.max(0.2, Math.cos((lat * Math.PI) / 180));
    return db
      .prepare(
        `SELECT atco, name, lat, lon FROM stops
         WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?`,
      )
      .all(lat - dLat, lat + dLat, lon - dLon, lon + dLon)
      .map((s) => ({ ...s, dist: metresBetween(lat, lon, s.lat, s.lon) }))
      .filter((s) => s.dist <= radiusM)
      .sort((a, b) => a.dist - b.dist)
      .slice(0, cap);
  };

  // Origin: keep it tight — you walk to a nearby stop. Destination: a place
  // search like "Newcastle" is one fuzzy pin standing for a whole centre, so
  // cast a wider net, or the obvious terminus (e.g. Haymarket) falls outside.
  const fromStops = stopsNear(fromLat, fromLon, 800, 50);
  const toStops = stopsNear(toLat, toLon, 1500, 80);
  if (fromStops.length === 0 || toStops.length === 0) return res.json({ options: [] });

  const toName = new Map(toStops.map((s) => [s.atco, s.name]));
  const fromName = new Map(fromStops.map((s) => [s.atco, s.name]));
  const fromDist = new Map(fromStops.map((s) => [s.atco, s.dist]));
  const toDist = new Map(toStops.map((s) => [s.atco, s.dist]));
  const ph = (arr) => arr.map(() => "?").join(",");

  const pairs = db
    .prepare(
      `SELECT DISTINCT trips.route_id AS route_id, st1.atco AS from_atco, st2.atco AS to_atco
       FROM stop_times st1
       JOIN stop_times st2 ON st2.trip_id = st1.trip_id AND st2.seq > st1.seq
       JOIN trips ON trips.id = st1.trip_id
       WHERE st1.atco IN (${ph(fromStops)}) AND st2.atco IN (${ph(toStops)})
       LIMIT 800`,
    )
    .all(...fromStops.map((s) => s.atco), ...toStops.map((s) => s.atco));

  // One option per route, choosing the from/to pairing with the LEAST total
  // walking — so we recommend your nearest stop, not just the first matched.
  const byRoute = new Map();
  for (const p of pairs) {
    const walk = (fromDist.get(p.from_atco) ?? 1e9) + (toDist.get(p.to_atco) ?? 1e9);
    const prev = byRoute.get(p.route_id);
    if (!prev || walk < prev.walk) byRoute.set(p.route_id, { ...p, walk });
  }

  const activeToday = activeServiceIDs(ukDateString());
  const activeYesterday = activeServiceIDs(ukDateString(-1));
  const nowSeconds = ukSecondsSinceMidnight();
  // Optional "arrive by" target (HH:MM, UK local) — plan backwards from it.
  const arriveBy = TimeOfDaySeconds(String(req.query.arriveBy ?? "")) ?? null;

  // Only trips that call at BOTH stops, in order — a departure from your stop
  // on a short working that turns back early is not a bus to your destination.
  // Also carry the arrival time at the destination stop, so we can show when
  // each bus gets you there (and honour an arrive-by target).
  const departuresStmt = db.prepare(
    `SELECT trips.service_id AS service_id, st.departure_seconds AS dep,
            COALESCE(st2.arrival_seconds, st2.departure_seconds) AS arr
     FROM trips
     JOIN stop_times st  ON st.trip_id = trips.id AND st.atco = ?
     JOIN stop_times st2 ON st2.trip_id = trips.id AND st2.atco = ? AND st2.seq > st.seq
     WHERE trips.route_id = ? AND st.departure_seconds IS NOT NULL
     ORDER BY st.departure_seconds`,
  );
  // Upcoming buses across two GTFS service days: today's, plus yesterday's
  // past-midnight (24:xx+) trips still to come. Each carries its departure and
  // its arrival at the destination. With arriveBy set, we keep the LATEST few
  // that still arrive in time (leave as late as possible); otherwise the
  // soonest few. Result is always shown chronologically.
  const nextDepartures = (routeID, fromAtco, toAtco) => {
    const rows = departuresStmt.all(fromAtco, toAtco, routeID);
    const byDep = new Map();
    for (const day of [{ off: 0, active: activeToday }, { off: 86_400, active: activeYesterday }]) {
      for (const t of rows) {
        if (!day.active.has(t.service_id) || t.arr == null) continue;
        const dep = t.dep - day.off;
        const arr = t.arr - day.off;
        if (dep < nowSeconds) continue;
        if (arriveBy != null && arr > arriveBy) continue;
        if (!byDep.has(dep)) byDep.set(dep, { dep, arr });
      }
    }
    const sorted = [...byDep.values()].sort((a, b) => a.dep - b.dep);
    const chosen = arriveBy != null ? sorted.slice(-3) : sorted.slice(0, 3);
    return chosen.map((t) => ({ departure: secondsToTime(t.dep), arrival: secondsToTime(t.arr) }));
  };

  const stopCoord = new Map([...fromStops, ...toStops].map((s) => [s.atco, s]));
  const options = [];
  for (const [routeID, pair] of byRoute) {
    const route = db.prepare("SELECT * FROM routes WHERE id = ?").get(routeID);
    if (!route) continue;
    const nextDeps = nextDepartures(routeID, pair.from_atco, pair.to_atco);
    options.push({
      service: { id: route.id, line_name: route.line_name, description: describeRoute(db, route) },
      from: {
        atco: pair.from_atco,
        name: fromName.get(pair.from_atco) ?? pair.from_atco,
        walk_meters: Math.round(fromDist.get(pair.from_atco) ?? 0),
      },
      to: {
        atco: pair.to_atco,
        name: toName.get(pair.to_atco) ?? pair.to_atco,
        walk_meters: Math.round(toDist.get(pair.to_atco) ?? 0),
      },
      departures: nextDeps,
      live_vehicles: liveVehiclesNear(route.id, route.line_name,
                                      [stopCoord.get(pair.from_atco), stopCoord.get(pair.to_atco)]),
      totalWalk: pair.walk,
      nextDepartureSeconds: nextDeps.length
        ? (TimeOfDaySeconds(nextDeps[0].departure) ?? 99_999) : 99_999,
    });
  }

  // Running buses first, then shortest total walk, then soonest departure —
  // surfaces the nearest convenient bus rather than an arbitrary match.
  const stillRunning = (o) => (o.departures.length ? 0 : 1);
  options.sort(
    (a, b) =>
      stillRunning(a) - stillRunning(b) ||
      a.totalWalk - b.totalWalk ||
      a.nextDepartureSeconds - b.nextDepartureSeconds,
  );
  const direct = options
    // With an arrive-by target, a route with no qualifying departure doesn't
    // get you there in time — drop it rather than show an empty card.
    .filter((o) => arriveBy == null || o.departures.length > 0)
    .slice(0, 15)
    .map(({ totalWalk, nextDepartureSeconds, ...rest }) => rest);

  // When there's no good direct bus, work out journeys with a single change
  // (one bus, an optional short walk, a second bus) so we can tell the rider
  // "you'll need a change" with the actual route — not just a dead end.
  const interchange = direct.length >= 3
    ? []
    : oneChangeJourneys({ db, fromStops, toStops, activeToday, activeYesterday, now: nowSeconds, arriveBy });

  res.json({ options: direct, interchange });
});

/// Single-change journeys: board a near-term bus from the origin, ride to an
/// interchange, optionally walk a short way, then catch a second bus that
/// reaches the destination — with timing checked so the connection is real.
/// Bounded throughout so one request can't run away on the national dataset.
function oneChangeJourneys({ db, fromStops, toStops, activeToday, activeYesterday, now, arriveBy = null }) {
  const LEG1_WINDOW = config.journey.leg1WindowMinutes * 60;
  const LOOKAHEAD = 3 * 3600;    // arrive at destination within 3 h
  const TRANSFER_BUFFER = config.journey.transferBufferSeconds;
  const MAX_WALK = config.journey.maxTransferWalkMeters;
  const WALK_SPEED = 1.3;        // m/s
  const LEG1_TRIPS = 60, LEG2_TRIPS = 200, DOWNSTREAM = 40, UPSTREAM = 40;
  const REACH_CAP = 250, BOARD_CAP = 500;

  // Times are searched on two GTFS service days — today, and yesterday's
  // past-midnight (24:xx+) trips. Each candidate carries `off` (0 or 86400);
  // subtracting it normalises every stored time to today's clock, after which
  // all the feasibility arithmetic below is day-agnostic.
  const serviceDays = [
    { off: 0, active: activeToday },
    { off: 86_400, active: activeYesterday },
  ];

  const ph = (arr) => arr.map(() => "?").join(",");
  const fromAtcos = fromStops.map((s) => s.atco);
  const toAtcos = toStops.map((s) => s.atco);
  const fromDist = new Map(fromStops.map((s) => [s.atco, s.dist]));
  const toDist = new Map(toStops.map((s) => [s.atco, s.dist]));
  const fromName = new Map(fromStops.map((s) => [s.atco, s.name]));
  const toName = new Map(toStops.map((s) => [s.atco, s.name]));

  // Leg 1: near-term departures from the origin, and the earliest each
  // downstream stop can be reached (those are the candidate interchanges).
  const leg1Stmt = db.prepare(
    `SELECT st.trip_id AS trip_id, st.atco AS board_atco, st.seq AS board_seq,
            st.departure_seconds AS dep, trips.route_id AS route_id, trips.service_id AS service_id
     FROM stop_times st JOIN trips ON trips.id = st.trip_id
     WHERE st.atco IN (${ph(fromAtcos)}) AND st.departure_seconds BETWEEN ? AND ?
     ORDER BY st.departure_seconds LIMIT 600`,
  );
  const leg1 = serviceDays
    .flatMap(({ off, active }) =>
      leg1Stmt.all(...fromAtcos, now + off, now + off + LEG1_WINDOW)
        .filter((r) => active.has(r.service_id))
        .map((r) => ({ ...r, dep: r.dep - off, off })))
    .sort((p, q) => p.dep - q.dep);

  const downstreamStmt = db.prepare(
    `SELECT atco, COALESCE(arrival_seconds, departure_seconds) AS arr, seq
     FROM stop_times WHERE trip_id = ? AND seq > ? ORDER BY seq LIMIT ${DOWNSTREAM}`,
  );

  const reach = new Map(); // interchange atco -> { arrive, routeId, boardAtco, boardDep, boardWalk, tripId, boardSeq, interSeq, off }
  let used1 = 0;
  for (const b of leg1) {
    if (used1++ >= LEG1_TRIPS) break;
    const boardWalk = fromDist.get(b.board_atco) ?? 0;
    for (const s of downstreamStmt.all(b.trip_id, b.board_seq)) {
      if (s.arr == null || fromDist.has(s.atco)) continue; // still in origin cluster
      const arrive = s.arr - b.off;
      const prev = reach.get(s.atco);
      // Prefer the boarding with the SHORTEST walk from the origin (then the
      // earliest arrival) — send the rider to their nearest usable stop.
      if (!prev || boardWalk < prev.boardWalk ||
          (boardWalk === prev.boardWalk && arrive < prev.arrive)) {
        reach.set(s.atco, {
          arrive, routeId: b.route_id, boardAtco: b.board_atco, boardDep: b.dep,
          boardWalk, tripId: b.trip_id, boardSeq: b.board_seq, interSeq: s.seq, off: b.off,
        });
      }
    }
  }
  if (reach.size === 0) return [];

  // Leg 2: near-term arrivals into the destination, and from which upstream
  // stops (and when) you could have boarded to make them.
  const leg2Stmt = db.prepare(
    `SELECT st.trip_id AS trip_id, st.atco AS alight_atco, st.seq AS alight_seq,
            COALESCE(st.arrival_seconds, st.departure_seconds) AS arr,
            trips.route_id AS route_id, trips.service_id AS service_id
     FROM stop_times st JOIN trips ON trips.id = st.trip_id
     WHERE st.atco IN (${ph(toAtcos)})
       AND COALESCE(st.arrival_seconds, st.departure_seconds) BETWEEN ? AND ?
     ORDER BY 4 LIMIT 1500`,
  );
  const leg2 = serviceDays
    .flatMap(({ off, active }) =>
      leg2Stmt.all(...toAtcos, now + off, now + off + LOOKAHEAD)
        .filter((r) => active.has(r.service_id))
        .map((r) => ({ ...r, arr: r.arr - off, off })))
    .sort((p, q) => p.arr - q.arr);

  const upstreamStmt = db.prepare(
    `SELECT atco, departure_seconds AS dep, seq
     FROM stop_times WHERE trip_id = ? AND seq < ? AND departure_seconds IS NOT NULL
     ORDER BY seq LIMIT ${UPSTREAM}`,
  );

  const board2 = new Map(); // boarding atco -> [{ dep, routeId, alightAtco, arriveD }]
  let used2 = 0;
  for (const a of leg2) {
    if (used2++ >= LEG2_TRIPS) break;
    if (a.arr == null) continue;
    for (const s of upstreamStmt.all(a.trip_id, a.alight_seq)) {
      if (toDist.has(s.atco)) continue; // boarding inside destination cluster = basically direct
      const list = board2.get(s.atco) ?? [];
      list.push({ dep: s.dep - a.off, routeId: a.route_id, alightAtco: a.alight_atco, arriveD: a.arr,
                  tripId: a.trip_id, boardSeq: s.seq, alightSeq: a.alight_seq, off: a.off });
      board2.set(s.atco, list);
    }
  }
  if (board2.size === 0) return [];
  for (const list of board2.values()) list.sort((p, q) => p.dep - q.dep);

  // Coordinates for the interchange stops (needed to measure walking transfers).
  const interAtcos = [...new Set([...reach.keys(), ...board2.keys()])];
  const coord = new Map();
  for (let i = 0; i < interAtcos.length; i += 400) {
    const chunk = interAtcos.slice(i, i + 400);
    for (const r of db
      .prepare(`SELECT atco, name, lat, lon FROM stops WHERE atco IN (${ph(chunk)})`)
      .all(...chunk)) {
      coord.set(r.atco, r);
    }
  }

  // Connect leg 1 → (optional walk) → leg 2, keeping only feasible timings.
  // Walk to the first stop dominates how it feels, so order candidates by it.
  const reachArr = [...reach.entries()]
    .sort((p, q) => p[1].boardWalk - q[1].boardWalk || p[1].arrive - q[1].arrive)
    .slice(0, REACH_CAP);
  const boardArr = [...board2.keys()].slice(0, BOARD_CAP);
  const journeys = [];
  for (const [x, a] of reachArr) {
    const consider = (y, walk) => {
      const readyAt = a.arrive + TRANSFER_BUFFER + walk / WALK_SPEED;
      const opt = board2.get(y)?.find(
        (o) => o.dep >= readyAt && o.routeId !== a.routeId
          && (arriveBy == null || o.arriveD <= arriveBy),
      );
      if (opt) {
        const totalWalk = a.boardWalk + walk + (toDist.get(opt.alightAtco) ?? 0);
        journeys.push({ x, y, walk, a, opt, totalWalk });
      }
    };
    if (board2.has(x)) consider(x, 0); // change at the same stop
    const xc = coord.get(x);
    if (xc) {
      for (const y of boardArr) {
        if (y === x) continue;
        const yc = coord.get(y);
        if (!yc) continue;
        const w = metresBetween(xc.lat, xc.lon, yc.lat, yc.lon);
        if (w <= MAX_WALK) consider(y, w);
      }
    }
  }
  if (journeys.length === 0) return [];

  // Best journey per route-pair by least total walk, then overall least-walk
  // / soonest-arriving — so your nearest boarding stop surfaces first.
  const byPair = new Map();
  for (const j of journeys) {
    const key = `${j.a.routeId}>${j.opt.routeId}`;
    const prev = byPair.get(key);
    if (!prev || j.totalWalk < prev.totalWalk ||
        (j.totalWalk === prev.totalWalk && j.opt.arriveD < prev.opt.arriveD)) {
      byPair.set(key, j);
    }
  }
  const best = [...byPair.values()]
    .sort((p, q) => p.totalWalk - q.totalWalk || p.opt.arriveD - q.opt.arriveD)
    .slice(0, 5);

  // Calling points for a slice of a trip, with stop names and times — these
  // power the full journey breakdown in the app.
  const sliceStmt = db.prepare(
    `SELECT st.atco AS atco, st.seq AS seq,
            COALESCE(st.departure_seconds, st.arrival_seconds) AS t, sp.name AS name
     FROM stop_times st JOIN stops sp ON sp.atco = st.atco
     WHERE st.trip_id = ? AND st.seq BETWEEN ? AND ? ORDER BY st.seq LIMIT 80`,
  );
  const callingPoints = (tripId, fromSeq, toSeq, off) =>
    sliceStmt.all(tripId, fromSeq, toSeq).map((r) => ({ name: r.name ?? r.atco, time: secondsToTime(r.t - off) }));

  const routeInfo = (id) => db.prepare("SELECT * FROM routes WHERE id = ?").get(id);
  const nameOf = (atco) => fromName.get(atco) ?? toName.get(atco) ?? coord.get(atco)?.name ?? atco;
  const coordOf = (atco) =>
    coord.get(atco) ?? fromStops.find((s) => s.atco === atco) ?? toStops.find((s) => s.atco === atco);
  const busLeg = (routeId, fromAtco, toAtco, dep, arr, fromWalk, toWalk, stops) => {
    const r = routeInfo(routeId);
    return {
      mode: "bus",
      service: r ? { id: r.id, line_name: r.line_name, description: describeRoute(db, r) } : null,
      from: { atco: fromAtco, name: nameOf(fromAtco), walk_meters: fromWalk },
      to: { atco: toAtco, name: nameOf(toAtco), walk_meters: toWalk },
      departure: secondsToTime(dep),
      arrival: secondsToTime(arr),
      live_vehicles: r ? liveVehiclesNear(r.id, r.line_name, [coordOf(fromAtco), coordOf(toAtco)]) : 0,
      stops,
    };
  };

  return best.map((j) => {
    const legs = [
      busLeg(j.a.routeId, j.a.boardAtco, j.x, j.a.boardDep, j.a.arrive,
             Math.round(j.a.boardWalk), null,
             callingPoints(j.a.tripId, j.a.boardSeq, j.a.interSeq, j.a.off)),
    ];
    if (j.walk > 0) legs.push({ mode: "walk", meters: Math.round(j.walk) });
    legs.push(busLeg(j.opt.routeId, j.y, j.opt.alightAtco, j.opt.dep, j.opt.arriveD,
                     null, Math.round(toDist.get(j.opt.alightAtco) ?? 0),
                     callingPoints(j.opt.tripId, j.opt.boardSeq, j.opt.alightSeq, j.opt.off)));
    return { changes: 1, arrival: secondsToTime(j.opt.arriveD), legs };
  });
}

function TimeOfDaySeconds(hhmm) {
  if (!hhmm) return null;
  const [h, m] = hhmm.split(":").map(Number);
  return Number.isFinite(h) && Number.isFinite(m) ? h * 3600 + m * 60 : null;
}

// MARK: Route geometry — GET /services/:id.json

app.get("/services/:id.json", (req, res) => {
  const db = openDB();
  const shapeIDs = db
    .prepare(
      `SELECT DISTINCT shape_id FROM trips
       WHERE route_id = ? AND shape_id IS NOT NULL LIMIT 12`,
    )
    .all(Number(req.params.id))
    .map((r) => r.shape_id);

  const points = db.prepare("SELECT lat, lon FROM shapes WHERE shape_id = ? ORDER BY seq");
  let lines = shapeIDs
    .map((id) => points.all(id).map((p) => [p.lon, p.lat]))
    .filter((line) => line.length > 1);

  // No shapes (e.g. imported with GTFS_IMPORT_SHAPES=false) — draw the line
  // by joining the stops of a representative trip in each direction. Not
  // road-accurate, but far better than a bare scatter of stops.
  if (lines.length === 0) {
    const tripStops = db.prepare(
      `SELECT stops.lon AS lon, stops.lat AS lat FROM stop_times
       JOIN stops ON stops.atco = stop_times.atco
       WHERE stop_times.trip_id = ? ORDER BY stop_times.seq LIMIT 400`,
    );
    lines = representativeTrips(db, Number(req.params.id))
      .map(({ tripID }) => tripStops.all(tripID).map((p) => [p.lon, p.lat]))
      .filter((line) => line.length > 1);
  }

  res.json({ geometry: { type: "MultiLineString", coordinates: lines } });
});

// MARK: Share pages — GET /share
// A small web page for shared links, so a recipient sees the bus/route even
// without the app. Once Universal Links are configured (needs the Apple
// Developer Team ID in an apple-app-site-association file), these same URLs
// will open the app directly instead.

function escapeHTML(value) {
  return String(value ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

// Apple App Site Association — lets the iOS app claim https://…/share links
// as Universal Links. Uses the same Team ID as APNs. The app must also add
// the Associated Domains capability (applinks:waitless.bricksinabag.com).
app.get("/.well-known/apple-app-site-association", (req, res) => {
  const appID = `${config.apns.teamId}.${config.apns.bundleId}`;
  res.json({
    applinks: {
      details: [{ appIDs: [appID], components: [{ "/": "/share*" }] }],
    },
  });
});

app.get("/share", (req, res) => {
  const type = String(req.query.type ?? "bus");
  const line = escapeHTML(req.query.line ?? "");
  const destination = escapeHTML(req.query.to ?? "");
  const stopName = escapeHTML(req.query.name ?? "");

  // Deep link into the app (works once installed via the custom scheme).
  const appQuery = new URLSearchParams();
  for (const key of ["type", "line", "service", "to", "atco", "name"]) {
    if (req.query[key] != null) appQuery.set(key, String(req.query[key]));
  }
  const appLink = `waitless://share?${appQuery.toString()}`;

  let heading;
  let detail = "";
  if (type === "stop") {
    heading = stopName || "Bus stop";
    detail = "See the next departures and live buses heading here.";
  } else if (type === "route") {
    let description = "";
    try {
      const serviceID = Number(req.query.service);
      if (Number.isInteger(serviceID)) {
        const route = openDB().prepare("SELECT * FROM routes WHERE id = ?").get(serviceID);
        if (route) description = describeRoute(openDB(), route);
      }
    } catch { /* DB optional for the share page */ }
    heading = `The ${line || "bus"}`;
    detail = description ? escapeHTML(description) : "Track this route live.";
  } else {
    heading = destination ? `The ${line} to ${destination}` : `The ${line || "bus"}`;
    detail = "Follow it live, with arrival alerts so you never miss it.";
  }

  res.set("Content-Type", "text/html; charset=utf-8");
  res.send(`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${heading} — Wait Less</title>
<style>
  :root { color-scheme: light dark; }
  body { margin: 0; font: 17px/1.5 -apple-system, system-ui, sans-serif;
         display: flex; min-height: 100vh; align-items: center; justify-content: center;
         background: #f4f6f8; color: #11161c; }
  @media (prefers-color-scheme: dark) { body { background: #12161b; color: #f1f4f7; } }
  .card { max-width: 420px; margin: 24px; padding: 28px; border-radius: 20px;
          background: #fff; box-shadow: 0 10px 40px rgba(0,0,0,.08); text-align: center; }
  @media (prefers-color-scheme: dark) { .card { background: #1b2027; } }
  .badge { display: inline-block; background: #00b0c4; color: #fff; font-weight: 800;
           padding: 6px 14px; border-radius: 10px; letter-spacing: .5px; }
  h1 { font-size: 26px; margin: 18px 0 6px; }
  p.detail { color: #6b7480; margin: 0 0 22px; }
  .cta { display: block; background: #e02438; color: #fff; text-decoration: none;
         font-weight: 700; padding: 14px; border-radius: 14px; margin-bottom: 10px; }
  .note { font-size: 13px; color: #8a929c; }
  .live { color: #e02438; font-weight: 700; }
</style>
</head>
<body>
  <div class="card">
    <span class="badge">🚌 Wait Less</span>
    <h1>${heading}</h1>
    <p class="detail">${detail}</p>
    <a class="cta" href="${escapeHTML(appLink)}">Open in Wait Less</a>
    <p class="note">Wait Less shows live buses across the UK, with arrival alarms.<br>Coming soon to the App Store.</p>
  </div>
</body>
</html>`);
});

// MARK: Health

app.get("/health", (req, res) => {
  let stats = null;
  try {
    stats = dbStats();
  } catch {
    // DB not imported yet — still report poller state.
  }
  res.json({
    vehicles: store.count,
    lastVehicleUpdate: store.lastUpdated,
    pollerError: store.lastError,
    live: store.matchStats,
    siri: { vehicles: store.siriOverlaySize, lastUpdated: store.siriOverlayUpdated },
    gtfs: stats,
    push: { configured: apns.configured, devices: devices.count },
  });
});

// MARK: Diagnostics — GET /api/debug/line?name=X8
// Shows, for one public line, exactly what each live feed knows: the
// vehicles we serve (with source + position age) and everything SIRI has.
// Read-only live data; handy for comparing our map against another tracker.
app.get("/api/debug/line", (req, res) => {
  const name = String(req.query.name ?? "").trim();
  if (!name) return res.status(400).json({ error: "name required, e.g. ?name=X8" });
  res.json(store.debugLine(name));
});

// MARK: Errors
// Catch anything thrown in a route (e.g. the GTFS database not yet imported)
// and return a clean JSON message. Never leak stack traces or file paths to
// clients — the full error is logged server-side only.

app.use((req, res) => {
  res.status(404).json({ error: "Not found." });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(`Request error on ${req.method} ${req.path}:`, err);
  const timetableMissing = String(err?.message ?? "").includes("No GTFS database");
  if (timetableMissing) {
    return res.status(503).json({ error: "Timetable data is not available yet." });
  }
  res.status(500).json({ error: "Something went wrong. Please try again." });
});

// MARK: Boot

try {
  openDB();
  console.log("GTFS database:", dbStats());
} catch (error) {
  console.warn(`⚠ ${error.message}`);
  console.warn("Timetable endpoints will return 503 until the import has run.");
}

startPolling(store);
startSiriPolling(store);
scheduleDailyImport();
app.listen(config.port, () => {
  console.log(`BusPulse backend listening on :${config.port}`);
  console.log("Attribution: contains public sector information licensed under OGL v3.0 (DfT BODS).");
  // Warm the route search index off the request path so the first search
  // isn't slow, without holding up the port opening.
  setImmediate(() => {
    try { buildRouteSearchIndex(openDB()); } catch { /* no timetable yet */ }
  });
});
