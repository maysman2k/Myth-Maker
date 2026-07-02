/**
 * Polls the BODS GTFS-RT vehicle position feed (protobuf) and keeps an
 * in-memory store of current positions, enriched with route/trip details
 * from the GTFS database so the app gets line names and headsigns.
 */
import GtfsRealtimeBindings from "gtfs-realtime-bindings";
import yauzl from "yauzl";
import { config } from "../config.js";
import { openDB } from "../db.js";

const { transit_realtime } = GtfsRealtimeBindings;

/** Deterministic positive 32-bit id from a stable vehicle key (FNV-1a),
 *  so the app gets a consistent integer id per bus with no growing map. */
function stableIntID(key) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < key.length; i++) {
    hash ^= key.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

/**
 * BODS's bulk feed (/avl/download/gtfsrt) returns a ZIP containing the
 * GTFS-RT protobuf (gtfsrt.bin); the datafeed API returns raw protobuf.
 * Detect a zip by its "PK\x03\x04" magic bytes and unwrap the first file,
 * otherwise pass the buffer straight through.
 */
function extractProtobuf(buffer) {
  const isZip = buffer.length > 4
    && buffer[0] === 0x50 && buffer[1] === 0x4b
    && buffer[2] === 0x03 && buffer[3] === 0x04;
  if (!isZip) return Promise.resolve(buffer);

  return new Promise((resolve, reject) => {
    yauzl.fromBuffer(buffer, { lazyEntries: true }, (err, zipfile) => {
      if (err) return reject(err);
      zipfile.on("error", reject);
      zipfile.on("end", () => reject(new Error("zip contained no files")));
      zipfile.on("entry", (entry) => {
        if (entry.fileName.endsWith("/")) {
          zipfile.readEntry();
          return;
        }
        zipfile.openReadStream(entry, (streamErr, stream) => {
          if (streamErr) return reject(streamErr);
          const chunks = [];
          stream.on("data", (chunk) => chunks.push(chunk));
          stream.on("end", () => resolve(Buffer.concat(chunks)));
          stream.on("error", reject);
        });
      });
      zipfile.readEntry();
    });
  });
}

export class VehicleStore {
  /** @type {Map<string, object>} stable vehicle key → vehicle record.
   *  Rebuilt every poll: the bulk GTFS-RT feed is a complete snapshot of
   *  every current vehicle, so we replace the set rather than accumulate
   *  (which previously grew to hundreds of thousands of stale duplicates). */
  #vehicles = new Map();
  lastUpdated = null;
  lastError = null;

  /** SIRI-VM overlay: vehicle ref → { line, destination }. Fills in names
   *  for vehicles whose GTFS-RT ids match nothing in the timetable. */
  #siri = new Map();
  /** Enrichment health, refreshed each ingest — surfaced on /health. */
  matchStats = { total: 0, matchedToTimetable: 0, namedBySiri: 0, unnamed: 0,
                 sampleUnmatchedRouteIds: [] };

  /** Overlay freshness, surfaced on /health. */
  siriOverlaySize = 0;
  siriOverlayUpdated = null;

  applySiriOverlay(byRef) {
    const expanded = new Map();
    for (const [ref, info] of byRef) {
      const key = String(ref).toUpperCase();
      expanded.set(key, info);
      // GTFS-RT vehicle ids are sometimes "OPERATOR-1234" where SIRI says
      // "1234" (or vice versa) — index the bare suffix too.
      const suffix = key.split(/[-:]/).pop();
      if (suffix && suffix !== key && !expanded.has(suffix)) expanded.set(suffix, info);
    }
    this.#siri = expanded;
    this.siriOverlaySize = byRef.size;
    this.siriOverlayUpdated = new Date().toISOString();
  }

  #siriFor(key) {
    if (this.#siri.size === 0) return null;
    const k = String(key).toUpperCase();
    return this.#siri.get(k) ?? this.#siri.get(k.split(/[-:]/).pop()) ?? null;
  }

  /** Lazy caches over the GTFS db for enrichment. */
  #routeByGtfsID = new Map();
  #tripByGtfsID = new Map();
  /** Resolved once per poll: the GTFS db handle, or null if not imported yet.
   *  Live positions must work with no timetable data — enrichment (route
   *  names, headsigns) is a bonus that switches on the moment the import
   *  has run, without a server restart. */
  #dbHandle = undefined;

  #db() {
    if (this.#dbHandle === undefined) {
      try {
        this.#dbHandle = openDB();
      } catch {
        this.#dbHandle = null;
      }
    }
    return this.#dbHandle;
  }

  #route(gtfsRouteID) {
    if (!gtfsRouteID) return null;
    if (this.#routeByGtfsID.has(gtfsRouteID)) return this.#routeByGtfsID.get(gtfsRouteID);
    const db = this.#db();
    if (!db) return null; // no timetable yet — don't cache, retry when it lands
    const row = db
      .prepare("SELECT id, line_name FROM routes WHERE gtfs_id = ?")
      .get(gtfsRouteID);
    this.#routeByGtfsID.set(gtfsRouteID, row ?? null);
    return row ?? null;
  }

  #trip(gtfsTripID) {
    if (!gtfsTripID) return null;
    if (this.#tripByGtfsID.has(gtfsTripID)) return this.#tripByGtfsID.get(gtfsTripID);
    const db = this.#db();
    if (!db) return null;
    const row = db
      .prepare("SELECT id, headsign, route_id FROM trips WHERE gtfs_id = ?")
      .get(gtfsTripID);
    this.#tripByGtfsID.set(gtfsTripID, row ?? null);
    return row ?? null;
  }

  /** route id → geographic bounding box of its stops (null if unknown). */
  #routeBBoxCache = new Map();

  #routeBBox(routeID) {
    if (this.#routeBBoxCache.has(routeID)) return this.#routeBBoxCache.get(routeID);
    const db = this.#db();
    if (!db) return null;
    const row = db
      .prepare(
        `SELECT MIN(lat) AS minLat, MAX(lat) AS maxLat, MIN(lon) AS minLon, MAX(lon) AS maxLon
         FROM route_stops JOIN stops ON stops.atco = route_stops.atco
         WHERE route_stops.route_id = ?`,
      )
      .get(routeID);
    const box = row?.minLat != null ? row : null;
    this.#routeBBoxCache.set(routeID, box);
    return box;
  }

  /** The live feed's route/trip ids and the static timetable's are different
   *  namespaces that collide numerically, so an id match alone can pin a
   *  vehicle to the wrong route entirely (a London 42 "on" a Tyneside X8).
   *  Sanity-check the match: the vehicle must be near the route it claims. */
  #plausiblyOnRoute(routeID, lat, lon) {
    const box = this.#routeBBox(routeID);
    if (!box) return true; // no stop data to judge by — keep the match
    const pad = 0.15; // ~15 km beyond the route's stops
    return lat >= box.minLat - pad && lat <= box.maxLat + pad
        && lon >= box.minLon - pad && lon <= box.maxLon + pad;
  }

  ingest(feedMessage) {
    const now = Date.now();
    // Re-check for the timetable database once per poll so enrichment
    // begins automatically after the import runs. If the daily import swapped
    // the database since last poll, drop caches keyed by the old ids.
    const before = this.#dbHandle;
    this.#dbHandle = undefined;
    if (this.#db() !== before) {
      this.#routeByGtfsID.clear();
      this.#tripByGtfsID.clear();
      this.#routeBBoxCache.clear();
    }

    const fresh = new Map();
    const stats = { total: 0, matchedToTimetable: 0, namedBySiri: 0, unnamed: 0,
                    sampleUnmatchedRouteIds: [] };
    for (const entity of feedMessage.entity ?? []) {
      const vp = entity.vehicle;
      const position = vp?.position;
      if (!position) continue;

      // Identify a vehicle by its physical id where the feed gives one,
      // so the app sees a stable id across polls; fall back to entity/trip.
      const key = vp.vehicle?.id || entity.id || vp.trip?.tripId;
      if (!key) continue;

      let route = this.#route(vp.trip?.routeId);
      let trip = this.#trip(vp.trip?.tripId);
      if (route && !this.#plausiblyOnRoute(route.id, position.latitude, position.longitude)) {
        route = null;
      }
      if (trip && !this.#plausiblyOnRoute(trip.route_id, position.latitude, position.longitude)) {
        trip = null;
      }
      const siri = route ? null : this.#siriFor(key);
      const timestamp = vp.timestamp ? Number(vp.timestamp) * 1000 : now;

      stats.total += 1;
      if (route || trip) stats.matchedToTimetable += 1;
      else if (siri) stats.namedBySiri += 1;
      else {
        stats.unnamed += 1;
        if (stats.sampleUnmatchedRouteIds.length < 5 && vp.trip?.routeId) {
          stats.sampleUnmatchedRouteIds.push(String(vp.trip.routeId));
        }
      }

      fresh.set(String(key), {
        id: stableIntID(String(key)),
        journey_id: null,
        service_id: route?.id ?? trip?.route_id ?? null,
        trip_id: trip?.id ?? null,
        coordinates: [position.longitude, position.latitude],
        heading: Number.isFinite(position.bearing) && position.bearing !== 0
          ? position.bearing
          : null,
        datetime: new Date(timestamp).toISOString(),
        destination: trip?.headsign ?? siri?.destination ?? null,
        service: { line_name: route?.line_name ?? siri?.line ?? null },
        vehicle: {
          name: vp.vehicle?.label || vp.vehicle?.id || null,
          url: null,
        },
        delay: null, // Fast-follow: GTFS-RT trip updates.
      });
    }
    this.#vehicles = fresh;
    this.matchStats = stats;
    this.lastUpdated = new Date(now).toISOString();
  }

  /** All current vehicles inside a lon/lat bounding box. */
  inBoundingBox(xmin, ymin, xmax, ymax, limit = 1500) {
    const out = [];
    for (const vehicle of this.#vehicles.values()) {
      const [lon, lat] = vehicle.coordinates;
      if (lon >= xmin && lon <= xmax && lat >= ymin && lat <= ymax) {
        out.push(vehicle);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  onServices(serviceIDs) {
    const wanted = new Set(serviceIDs);

    // The static data holds several route rows for one public line (an "X8"
    // can exist twice), and live vehicles get enriched onto whichever row the
    // feed references — often a sibling of the row being asked about. Match
    // the PUBLIC LINE, not just the row: same line name, near this route.
    const db = this.#db();
    const lineBoxes = new Map(); // lowercased line name → bounding box
    if (db) {
      for (const id of serviceIDs) {
        const row = db.prepare("SELECT line_name FROM routes WHERE id = ?").get(id);
        const box = this.#routeBBox(id);
        if (row?.line_name && box) lineBoxes.set(row.line_name.trim().toLowerCase(), box);
      }
    }

    const pad = 0.15; // ~15 km around the route's stops
    return [...this.#vehicles.values()].filter((v) => {
      if (wanted.has(v.service_id)) return true;
      const line = (v.service?.line_name ?? "").trim().toLowerCase();
      const box = line ? lineBoxes.get(line) : undefined;
      if (!box) return false;
      const [lon, lat] = v.coordinates;
      return lat >= box.minLat - pad && lat <= box.maxLat + pad
          && lon >= box.minLon - pad && lon <= box.maxLon + pad;
    });
  }

  get count() {
    return this.#vehicles.size;
  }
}

export function startPolling(store) {
  let backoff = 0;
  /** Locked-in feed URL once a candidate succeeds. */
  let feedURL = null;

  // Some gov.uk front-ends reject requests with bare/absent user agents.
  const headers = {
    "User-Agent": "Mozilla/5.0 (compatible; BusPulse/1.0; +support@bricksinabag.com)",
    Accept: "*/*",
  };

  async function fetchFeed() {
    // Probe candidates until one answers; stick with it afterwards.
    const candidates = feedURL ? [feedURL] : config.gtfsRealtimeCandidates();
    let lastError = null;
    for (const candidate of candidates) {
      try {
        const response = await fetch(candidate, { redirect: "follow", headers });
        if (!response.ok) {
          // BODS explains refusals in the body — surface it.
          const body = (await response.text().catch(() => "")).slice(0, 200).trim();
          lastError = new Error(
            `HTTP ${response.status} from ${candidate.split("?")[0]}${body ? ` — ${body}` : ""}`,
          );
          if (!feedURL) console.error(`  candidate refused: ${lastError.message}`);
          continue;
        }
        const raw = Buffer.from(await response.arrayBuffer());
        const protobuf = await extractProtobuf(raw);
        const message = transit_realtime.FeedMessage.decode(protobuf);
        if (!feedURL) {
          feedURL = candidate;
          console.log(`Live feed connected: ${candidate.split("?")[0]} (${message.entity?.length ?? 0} vehicles)`);
        }
        return message;
      } catch (error) {
        lastError = error;
        if (!feedURL) console.error(`  candidate failed: ${String(error.message ?? error).slice(0, 200)}`);
      }
    }
    // Nothing worked — forget the lock so the next attempt re-probes all.
    feedURL = null;
    throw lastError ?? new Error("BODS GTFS-RT: no candidate URL succeeded");
  }

  async function poll() {
    try {
      const message = await fetchFeed();
      store.ingest(message);
      store.lastError = null;
      backoff = 0;
    } catch (error) {
      store.lastError = String(error.message ?? error);
      backoff = Math.min(120, backoff === 0 ? 10 : backoff * 2);
      console.error(`Poll failed (backing off ${backoff}s):`, store.lastError);
    }
    setTimeout(poll, (config.pollSeconds + backoff) * 1000);
  }

  poll();
}
