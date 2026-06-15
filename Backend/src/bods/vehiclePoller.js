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
  /** @type {Map<string, object>} entity id → vehicle record */
  #vehicles = new Map();
  /** Stable integer ids for the app (it expects Int ids). */
  #intIDs = new Map();
  #nextIntID = 1;
  lastUpdated = null;
  lastError = null;

  #intID(entityID) {
    if (!this.#intIDs.has(entityID)) this.#intIDs.set(entityID, this.#nextIntID++);
    return this.#intIDs.get(entityID);
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

  ingest(feedMessage) {
    const now = Date.now();
    // Re-check for the timetable database once per poll so enrichment
    // begins automatically after the import runs.
    this.#dbHandle = undefined;
    for (const entity of feedMessage.entity ?? []) {
      const vp = entity.vehicle;
      const position = vp?.position;
      if (!position) continue;

      const route = this.#route(vp.trip?.routeId);
      const trip = this.#trip(vp.trip?.tripId);
      const timestamp = vp.timestamp ? Number(vp.timestamp) * 1000 : now;

      this.#vehicles.set(entity.id, {
        id: this.#intID(entity.id),
        journey_id: null,
        service_id: route?.id ?? trip?.route_id ?? null,
        trip_id: trip?.id ?? null,
        coordinates: [position.longitude, position.latitude],
        heading: Number.isFinite(position.bearing) && position.bearing !== 0
          ? position.bearing
          : null,
        datetime: new Date(timestamp).toISOString(),
        destination: trip?.headsign ?? null,
        service: { line_name: route?.line_name ?? null },
        vehicle: {
          name: vp.vehicle?.label || vp.vehicle?.id || null,
          url: null,
        },
        delay: null, // Fast-follow: GTFS-RT trip updates / SIRI-VM.
        _seenAt: now,
      });
    }
    this.#prune(now);
    this.lastUpdated = new Date(now).toISOString();
  }

  #prune(now) {
    const cutoff = now - config.vehicleStaleSeconds * 1000;
    for (const [key, vehicle] of this.#vehicles) {
      if (vehicle._seenAt < cutoff) this.#vehicles.delete(key);
    }
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
    return [...this.#vehicles.values()].filter((v) => wanted.has(v.service_id));
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
