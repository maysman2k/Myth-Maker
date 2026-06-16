/**
 * Downloads the BODS GTFS timetable archive for the configured region and
 * builds the SQLite database the API serves from.
 *
 * Atomic: writes to gtfs.sqlite.tmp, then renames over the live file, so
 * the server never sees a half-built database. Run daily via cron.
 *
 * Usage: npm run import-gtfs
 */
import Database from "better-sqlite3";
import { parse } from "csv-parse";
import fs from "node:fs";
import path from "node:path";
import { pipeline } from "node:stream/promises";
import yauzl from "yauzl";
import { config } from "../config.js";
import { timeToSeconds } from "../db.js";

const SCHEMA = `
  CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
  CREATE TABLE routes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    gtfs_id TEXT UNIQUE NOT NULL,
    line_name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    mode TEXT
  );
  CREATE TABLE stops (
    atco TEXT PRIMARY KEY,
    naptan_code TEXT,
    name TEXT NOT NULL,
    lat REAL NOT NULL,
    lon REAL NOT NULL
  );
  CREATE TABLE trips (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    gtfs_id TEXT UNIQUE NOT NULL,
    route_id INTEGER NOT NULL,
    service_id TEXT NOT NULL,
    headsign TEXT,
    shape_id TEXT,
    start_seconds INTEGER
  );
  CREATE TABLE stop_times (
    trip_id INTEGER NOT NULL,
    seq INTEGER NOT NULL,
    atco TEXT NOT NULL,
    arrival_seconds INTEGER,
    departure_seconds INTEGER
  );
  CREATE TABLE calendar (
    service_id TEXT PRIMARY KEY,
    monday INTEGER, tuesday INTEGER, wednesday INTEGER, thursday INTEGER,
    friday INTEGER, saturday INTEGER, sunday INTEGER,
    start_date TEXT, end_date TEXT
  );
  CREATE TABLE calendar_dates (
    service_id TEXT NOT NULL,
    date TEXT NOT NULL,
    exception_type INTEGER NOT NULL
  );
  CREATE TABLE shapes (
    shape_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    lat REAL NOT NULL,
    lon REAL NOT NULL
  );
  CREATE TABLE route_stops (
    route_id INTEGER NOT NULL,
    atco TEXT NOT NULL,
    PRIMARY KEY (route_id, atco)
  );
`;

// Indexes built BEFORE deriving, so the derive queries below use them
// instead of full-scanning tens of millions of rows. (idx_stop_times_trip
// is the critical one — without it the derive step is effectively endless.)
const PRE_DERIVE_INDEXES = `
  CREATE INDEX idx_stop_times_trip ON stop_times (trip_id, seq);
  CREATE INDEX idx_stop_times_atco ON stop_times (atco);
  CREATE INDEX idx_trips_route ON trips (route_id);
  CREATE INDEX idx_trips_service ON trips (service_id);
  CREATE INDEX idx_shapes ON shapes (shape_id, seq);
  CREATE INDEX idx_stops_geo ON stops (lat, lon);
  CREATE INDEX idx_calendar_dates ON calendar_dates (date);
`;

// route_stops is only populated during the derive step, so its index is
// built afterwards.
const POST_DERIVE_INDEXES = `
  CREATE INDEX idx_route_stops_atco ON route_stops (atco);
`;

async function download(url, destination) {
  console.log(`Downloading ${url} …`);
  const response = await fetch(url, { redirect: "follow" });
  if (!response.ok) throw new Error(`Download failed: HTTP ${response.status}`);
  await pipeline(response.body, fs.createWriteStream(destination));
  const megabytes = (fs.statSync(destination).size / 1e6).toFixed(1);
  console.log(`Saved ${megabytes} MB`);
}

/**
 * Streaming unzip via yauzl. The national GTFS archive contains files
 * larger than 2 GB, which buffer-based unzippers cannot write in one go —
 * streaming each entry to disk handles any size in constant memory.
 * Entry names are flattened with basename(), which also prevents zip-slip.
 */
function extractZip(zipPath, destinationDir) {
  fs.mkdirSync(destinationDir, { recursive: true });
  return new Promise((resolve, reject) => {
    yauzl.open(zipPath, { lazyEntries: true }, (err, zipfile) => {
      if (err) return reject(err);
      zipfile.on("error", reject);
      zipfile.on("end", resolve);
      zipfile.on("entry", (entry) => {
        if (entry.fileName.endsWith("/")) {
          zipfile.readEntry();
          return;
        }
        const destination = path.join(destinationDir, path.basename(entry.fileName));
        zipfile.openReadStream(entry, (streamErr, stream) => {
          if (streamErr) return reject(streamErr);
          const out = fs.createWriteStream(destination);
          stream.on("error", reject);
          out.on("error", reject);
          out.on("finish", () => {
            console.log(`  extracted ${path.basename(destination)} (${(fs.statSync(destination).size / 1e6).toFixed(1)} MB)`);
            zipfile.readEntry();
          });
          stream.pipe(out);
        });
      });
      zipfile.readEntry();
    });
  });
}

/** Stream a GTFS csv file row-by-row through `onRow`, in one transaction per chunk.
 *  Deletes the file afterwards to keep peak disk usage down on big imports. */
async function importCSV(filePath, db, onRow, chunkSize = 5000) {
  if (!fs.existsSync(filePath)) {
    console.log(`(${path.basename(filePath)} not present — skipping)`);
    return 0;
  }
  let count = 0;
  let chunk = [];
  const flush = db.transaction((rows) => {
    for (const row of rows) onRow(row);
  });

  const parser = fs.createReadStream(filePath).pipe(
    parse({ columns: true, skip_empty_lines: true, bom: true, relax_column_count: true }),
  );
  for await (const row of parser) {
    chunk.push(row);
    if (chunk.length >= chunkSize) {
      flush(chunk);
      count += chunk.length;
      chunk = [];
    }
  }
  if (chunk.length) {
    flush(chunk);
    count += chunk.length;
  }
  console.log(`${path.basename(filePath)}: ${count.toLocaleString()} rows`);
  fs.rmSync(filePath, { force: true });
  return count;
}

async function main() {
  if (config.gtfsRegion === "all") {
    console.log(
      "⚠ GTFS_REGION=all is the national dataset: ~1.4 GB download and a LONG import.\n" +
      `  Recommend at least ${config.importShapes ? "15" : "10"} GB free disk before starting` +
      `${config.importShapes ? " (or set GTFS_IMPORT_SHAPES=false to need less)" : ""}.\n` +
      "  A regional import (e.g. GTFS_REGION=north_west) takes minutes. Continuing with 'all' …",
    );
  }
  fs.mkdirSync(config.dataDir, { recursive: true });
  const zipPath = path.join(config.dataDir, "gtfs.zip");
  const extractDir = path.join(config.dataDir, "gtfs");
  const tmpDB = `${config.dbPath}.tmp`;

  await download(config.gtfsStaticURL(config.gtfsRegion), zipPath);

  console.log("Extracting …");
  fs.rmSync(extractDir, { recursive: true, force: true });
  await extractZip(zipPath, extractDir);
  // Free the archive immediately — every gigabyte counts on big imports.
  fs.rmSync(zipPath, { force: true });
  if (!config.importShapes) {
    fs.rmSync(path.join(extractDir, "shapes.txt"), { force: true });
    console.log("(GTFS_IMPORT_SHAPES=false — skipping route map lines to save disk)");
  }

  fs.rmSync(tmpDB, { force: true });
  const db = new Database(tmpDB);
  db.pragma("journal_mode = OFF");
  db.pragma("synchronous = OFF");
  db.exec(SCHEMA);

  const file = (name) => path.join(extractDir, name);

  // Routes — route_short_name is the line number on the front of the bus.
  const insertRoute = db.prepare(
    "INSERT OR IGNORE INTO routes (gtfs_id, line_name, description, mode) VALUES (?, ?, ?, ?)",
  );
  await importCSV(file("routes.txt"), db, (r) => {
    const mode = r.route_type === "3" || r.route_type === "200" ? "bus" : r.route_type;
    insertRoute.run(
      r.route_id,
      r.route_short_name || r.route_long_name || "?",
      r.route_long_name || "",
      mode,
    );
  });
  const routeIDs = new Map(
    db.prepare("SELECT gtfs_id, id FROM routes").all().map((r) => [r.gtfs_id, r.id]),
  );

  // Stops — stop_code is the NaPTAN SMS code printed on the flag.
  const insertStop = db.prepare(
    "INSERT OR IGNORE INTO stops (atco, naptan_code, name, lat, lon) VALUES (?, ?, ?, ?, ?)",
  );
  await importCSV(file("stops.txt"), db, (r) => {
    const lat = Number(r.stop_lat);
    const lon = Number(r.stop_lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return;
    insertStop.run(r.stop_id, r.stop_code || null, r.stop_name || r.stop_id, lat, lon);
  });

  // Trips
  const insertTrip = db.prepare(
    `INSERT OR IGNORE INTO trips (gtfs_id, route_id, service_id, headsign, shape_id)
     VALUES (?, ?, ?, ?, ?)`,
  );
  await importCSV(file("trips.txt"), db, (r) => {
    const routeID = routeIDs.get(r.route_id);
    if (!routeID) return;
    insertTrip.run(r.trip_id, routeID, r.service_id, r.trip_headsign || null, r.shape_id || null);
  });
  const tripIDs = new Map(
    db.prepare("SELECT gtfs_id, id FROM trips").all().map((r) => [r.gtfs_id, r.id]),
  );

  // Stop times — the big one (can be millions of rows).
  const insertStopTime = db.prepare(
    `INSERT INTO stop_times (trip_id, seq, atco, arrival_seconds, departure_seconds)
     VALUES (?, ?, ?, ?, ?)`,
  );
  await importCSV(file("stop_times.txt"), db, (r) => {
    const tripID = tripIDs.get(r.trip_id);
    if (!tripID) return;
    insertStopTime.run(
      tripID,
      Number(r.stop_sequence) || 0,
      r.stop_id,
      timeToSeconds(r.arrival_time),
      timeToSeconds(r.departure_time),
    );
  });

  // Calendars
  const insertCalendar = db.prepare(
    `INSERT OR REPLACE INTO calendar VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  await importCSV(file("calendar.txt"), db, (r) => {
    insertCalendar.run(
      r.service_id,
      Number(r.monday), Number(r.tuesday), Number(r.wednesday), Number(r.thursday),
      Number(r.friday), Number(r.saturday), Number(r.sunday),
      r.start_date, r.end_date,
    );
  });
  const insertException = db.prepare("INSERT INTO calendar_dates VALUES (?, ?, ?)");
  await importCSV(file("calendar_dates.txt"), db, (r) => {
    insertException.run(r.service_id, r.date, Number(r.exception_type));
  });

  // Shapes (route geometry)
  const insertShape = db.prepare("INSERT INTO shapes VALUES (?, ?, ?, ?)");
  await importCSV(file("shapes.txt"), db, (r) => {
    const lat = Number(r.shape_pt_lat);
    const lon = Number(r.shape_pt_lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return;
    insertShape.run(r.shape_id, Number(r.shape_pt_sequence) || 0, lat, lon);
  });

  console.log("Indexing core tables (needed before deriving) …");
  db.exec(PRE_DERIVE_INDEXES);

  console.log("Deriving trip start times and route↔stop links …");
  db.exec(`
    UPDATE trips SET start_seconds = (
      SELECT MIN(COALESCE(departure_seconds, arrival_seconds))
      FROM stop_times WHERE stop_times.trip_id = trips.id
    );
    INSERT OR IGNORE INTO route_stops (route_id, atco)
      SELECT DISTINCT trips.route_id, stop_times.atco
      FROM stop_times JOIN trips ON trips.id = stop_times.trip_id;
  `);

  console.log("Indexing derived tables …");
  db.exec(POST_DERIVE_INDEXES);
  db.prepare("INSERT INTO meta VALUES ('imported_at', ?)").run(new Date().toISOString());
  db.prepare("INSERT INTO meta VALUES ('region', ?)").run(config.gtfsRegion);
  db.close();

  fs.renameSync(tmpDB, config.dbPath);
  fs.rmSync(extractDir, { recursive: true, force: true });
  fs.rmSync(zipPath, { force: true });
  console.log(`✓ Import complete → ${config.dbPath}`);
}

main().catch((error) => {
  console.error("Import failed:", error);
  process.exit(1);
});
