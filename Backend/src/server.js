/**
 * BusPulse backend — serves the same paths and JSON shapes as
 * bustimes.org's public endpoints, backed entirely by your own BODS data.
 * Swapping the app over is a base-URL change only.
 */
import express from "express";
import { config } from "./config.js";
import { activeServiceIDs, dbStats, openDB, secondsToTime } from "./db.js";
import { startPolling, VehicleStore } from "./bods/vehiclePoller.js";

const app = express();
const store = new VehicleStore();

app.use((req, res, next) => {
  res.set("Cache-Control", "no-store");
  next();
});

function parseBBox(query) {
  const [xmin, ymin, xmax, ymax] = ["xmin", "ymin", "xmax", "ymax"].map((k) =>
    Number(query[k]),
  );
  if (![xmin, ymin, xmax, ymax].every(Number.isFinite)) return null;
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
    const term = `%${String(req.query.search).trim()}%`;
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
      description: route.description,
      mode: route.mode,
    })),
    next: null,
  });
});

// MARK: Timetable trips — GET /api/trips/ and /api/trips/:id/

function tripJSON(db, trip) {
  const times = db
    .prepare(
      `SELECT stop_times.*, stops.name AS stop_name FROM stop_times
       LEFT JOIN stops ON stops.atco = stop_times.atco
       WHERE trip_id = ? ORDER BY seq`,
    )
    .all(trip.id);
  return {
    id: trip.id,
    headsign: trip.headsign,
    times: times.map((t) => ({
      stop: { atco_code: t.atco, name: t.stop_name ?? t.atco },
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
  });
});

// MARK: Boot

try {
  openDB();
  console.log("GTFS database:", dbStats());
} catch (error) {
  console.warn(`⚠ ${error.message}`);
  console.warn("Timetable endpoints will 500 until the import has run.");
}

startPolling(store);
app.listen(config.port, () => {
  console.log(`BusPulse backend listening on :${config.port}`);
  console.log("Attribution: contains public sector information licensed under OGL v3.0 (DfT BODS).");
});
