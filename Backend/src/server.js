/**
 * BusPulse backend — serves the same paths and JSON shapes as
 * bustimes.org's public endpoints, backed entirely by your own BODS data.
 * Swapping the app over is a base-URL change only.
 */
import express from "express";
import rateLimit from "express-rate-limit";
import { config } from "./config.js";
import { activeServiceIDs, dbStats, openDB, secondsToTime } from "./db.js";
import { startPolling, VehicleStore } from "./bods/vehiclePoller.js";
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
    const serviceID = Number(req.query.service);
    rows = db
      .prepare(
        `SELECT stops.* FROM route_stops
         JOIN stops ON stops.atco = route_stops.atco
         WHERE route_stops.route_id = ? ORDER BY stops.name LIMIT 400`,
      )
      .all(serviceID);
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
      line_names: lineNames.all(stop.atco).map((r) => r.name),
    })),
    next: null,
  });
});

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
    rows = db
      .prepare(
        `SELECT * FROM routes
         WHERE line_name LIKE ? OR description LIKE ?
         ORDER BY LENGTH(line_name), line_name LIMIT 40`,
      )
      .all(term, term);
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
 * A human description for a route. Many GTFS routes have an empty
 * route_long_name, leaving search results indistinguishable (ten identical
 * "X7"s). Fall back to the route's terminus destinations, taken from the two
 * most common trip headsigns, e.g. "Newcastle – Blyth".
 */
const routeDescriptionCache = new Map();
function describeRoute(db, route) {
  if (route.description && route.description.trim()) return route.description.trim();
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

  const active = activeServiceIDs(new Date().toISOString().slice(0, 10));
  const nowSeconds = ukSecondsSinceMidnight();
  const departuresStmt = db.prepare(
    `SELECT trips.service_id AS service_id, st.departure_seconds AS dep
     FROM trips JOIN stop_times st ON st.trip_id = trips.id
     WHERE trips.route_id = ? AND st.atco = ? AND st.departure_seconds IS NOT NULL
     ORDER BY st.departure_seconds`,
  );

  const options = [];
  for (const [routeID, pair] of byRoute) {
    const route = db.prepare("SELECT * FROM routes WHERE id = ?").get(routeID);
    if (!route) continue;
    const nextDeps = departuresStmt
      .all(routeID, pair.from_atco)
      .filter((t) => active.has(t.service_id) && t.dep >= nowSeconds)
      .slice(0, 3)
      .map((t) => secondsToTime(t.dep));
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
      totalWalk: pair.walk,
      nextDepartureSeconds: nextDeps.length
        ? (TimeOfDaySeconds(nextDeps[0]) ?? 99_999) : 99_999,
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
    .slice(0, 15)
    .map(({ totalWalk, nextDepartureSeconds, ...rest }) => rest);

  // When there's no good direct bus, work out journeys with a single change
  // (one bus, an optional short walk, a second bus) so we can tell the rider
  // "you'll need a change" with the actual route — not just a dead end.
  const interchange = direct.length >= 3
    ? []
    : oneChangeJourneys({ db, fromStops, toStops, active, now: nowSeconds });

  res.json({ options: direct, interchange });
});

/// Single-change journeys: board a near-term bus from the origin, ride to an
/// interchange, optionally walk a short way, then catch a second bus that
/// reaches the destination — with timing checked so the connection is real.
/// Bounded throughout so one request can't run away on the national dataset.
function oneChangeJourneys({ db, fromStops, toStops, active, now }) {
  const LEG1_WINDOW = 75 * 60;   // first bus departs within 75 min
  const LOOKAHEAD = 3 * 3600;    // arrive at destination within 3 h
  const TRANSFER_BUFFER = 180;   // need at least 3 min to change
  const MAX_WALK = 400;          // metres you'll walk between stops to change
  const WALK_SPEED = 1.3;        // m/s
  const LEG1_TRIPS = 60, LEG2_TRIPS = 200, DOWNSTREAM = 40, UPSTREAM = 40;
  const REACH_CAP = 250, BOARD_CAP = 500;

  const ph = (arr) => arr.map(() => "?").join(",");
  const fromAtcos = fromStops.map((s) => s.atco);
  const toAtcos = toStops.map((s) => s.atco);
  const fromDist = new Map(fromStops.map((s) => [s.atco, s.dist]));
  const toDist = new Map(toStops.map((s) => [s.atco, s.dist]));
  const fromName = new Map(fromStops.map((s) => [s.atco, s.name]));
  const toName = new Map(toStops.map((s) => [s.atco, s.name]));

  // Leg 1: near-term departures from the origin, and the earliest each
  // downstream stop can be reached (those are the candidate interchanges).
  const leg1 = db
    .prepare(
      `SELECT st.trip_id AS trip_id, st.atco AS board_atco, st.seq AS board_seq,
              st.departure_seconds AS dep, trips.route_id AS route_id, trips.service_id AS service_id
       FROM stop_times st JOIN trips ON trips.id = st.trip_id
       WHERE st.atco IN (${ph(fromAtcos)}) AND st.departure_seconds BETWEEN ? AND ?
       ORDER BY st.departure_seconds LIMIT 600`,
    )
    .all(...fromAtcos, now, now + LEG1_WINDOW)
    .filter((r) => active.has(r.service_id));

  const downstreamStmt = db.prepare(
    `SELECT atco, COALESCE(arrival_seconds, departure_seconds) AS arr, seq
     FROM stop_times WHERE trip_id = ? AND seq > ? ORDER BY seq LIMIT ${DOWNSTREAM}`,
  );

  const reach = new Map(); // interchange atco -> { arrive, routeId, boardAtco, boardDep }
  let used1 = 0;
  for (const b of leg1) {
    if (used1++ >= LEG1_TRIPS) break;
    for (const s of downstreamStmt.all(b.trip_id, b.board_seq)) {
      if (s.arr == null || fromDist.has(s.atco)) continue; // still in origin cluster
      const prev = reach.get(s.atco);
      if (!prev || s.arr < prev.arrive) {
        reach.set(s.atco, { arrive: s.arr, routeId: b.route_id, boardAtco: b.board_atco, boardDep: b.dep });
      }
    }
  }
  if (reach.size === 0) return [];

  // Leg 2: near-term arrivals into the destination, and from which upstream
  // stops (and when) you could have boarded to make them.
  const leg2 = db
    .prepare(
      `SELECT st.trip_id AS trip_id, st.atco AS alight_atco, st.seq AS alight_seq,
              COALESCE(st.arrival_seconds, st.departure_seconds) AS arr,
              trips.route_id AS route_id, trips.service_id AS service_id
       FROM stop_times st JOIN trips ON trips.id = st.trip_id
       WHERE st.atco IN (${ph(toAtcos)})
         AND COALESCE(st.arrival_seconds, st.departure_seconds) BETWEEN ? AND ?
       ORDER BY 4 LIMIT 1500`,
    )
    .all(...toAtcos, now, now + LOOKAHEAD)
    .filter((r) => active.has(r.service_id));

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
      list.push({ dep: s.dep, routeId: a.route_id, alightAtco: a.alight_atco, arriveD: a.arr });
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
  const reachArr = [...reach.entries()].sort((p, q) => p[1].arrive - q[1].arrive).slice(0, REACH_CAP);
  const boardArr = [...board2.keys()].slice(0, BOARD_CAP);
  const journeys = [];
  for (const [x, a] of reachArr) {
    const consider = (y, walk) => {
      const readyAt = a.arrive + TRANSFER_BUFFER + walk / WALK_SPEED;
      const opt = board2.get(y)?.find((o) => o.dep >= readyAt && o.routeId !== a.routeId);
      if (opt) journeys.push({ x, y, walk, a, opt });
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

  // Best journey per route-pair, soonest arrival at the destination first.
  const byPair = new Map();
  for (const j of journeys) {
    const key = `${j.a.routeId}>${j.opt.routeId}`;
    const prev = byPair.get(key);
    if (!prev || j.opt.arriveD < prev.opt.arriveD) byPair.set(key, j);
  }
  const best = [...byPair.values()].sort((p, q) => p.opt.arriveD - q.opt.arriveD).slice(0, 5);

  const routeInfo = (id) => db.prepare("SELECT * FROM routes WHERE id = ?").get(id);
  const nameOf = (atco) => fromName.get(atco) ?? toName.get(atco) ?? coord.get(atco)?.name ?? atco;
  const busLeg = (routeId, fromAtco, toAtco, dep, arr, fromWalk, toWalk) => {
    const r = routeInfo(routeId);
    return {
      mode: "bus",
      service: r ? { id: r.id, line_name: r.line_name, description: describeRoute(db, r) } : null,
      from: { atco: fromAtco, name: nameOf(fromAtco), walk_meters: fromWalk },
      to: { atco: toAtco, name: nameOf(toAtco), walk_meters: toWalk },
      departure: secondsToTime(dep),
      arrival: secondsToTime(arr),
    };
  };

  return best.map((j) => {
    const legs = [
      busLeg(j.a.routeId, j.a.boardAtco, j.x, j.a.boardDep, j.a.arrive,
             Math.round(fromDist.get(j.a.boardAtco) ?? 0), null),
    ];
    if (j.walk > 0) legs.push({ mode: "walk", meters: Math.round(j.walk) });
    legs.push(busLeg(j.opt.routeId, j.y, j.opt.alightAtco, j.opt.dep, j.opt.arriveD,
                     null, Math.round(toDist.get(j.opt.alightAtco) ?? 0)));
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
  const lines = shapeIDs
    .map((id) => points.all(id).map((p) => [p.lon, p.lat]))
    .filter((line) => line.length > 1);

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
    gtfs: stats,
    push: { configured: apns.configured, devices: devices.count },
  });
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
scheduleDailyImport();
app.listen(config.port, () => {
  console.log(`BusPulse backend listening on :${config.port}`);
  console.log("Attribution: contains public sector information licensed under OGL v3.0 (DfT BODS).");
});
