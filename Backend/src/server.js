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
app.listen(config.port, () => {
  console.log(`BusPulse backend listening on :${config.port}`);
  console.log("Attribution: contains public sector information licensed under OGL v3.0 (DfT BODS).");
});
