/**
 * Polls the BODS GTFS-RT vehicle position feed (protobuf) and keeps an
 * in-memory store of current positions, enriched with route/trip details
 * from the GTFS database so the app gets line names and headsigns.
 */
import GtfsRealtimeBindings from "gtfs-realtime-bindings";
import { config } from "../config.js";
import { openDB } from "../db.js";

const { transit_realtime } = GtfsRealtimeBindings;

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

  #route(gtfsRouteID) {
    if (!gtfsRouteID) return null;
    if (!this.#routeByGtfsID.has(gtfsRouteID)) {
      const row = openDB()
        .prepare("SELECT id, line_name FROM routes WHERE gtfs_id = ?")
        .get(gtfsRouteID);
      this.#routeByGtfsID.set(gtfsRouteID, row ?? null);
    }
    return this.#routeByGtfsID.get(gtfsRouteID);
  }

  #trip(gtfsTripID) {
    if (!gtfsTripID) return null;
    if (!this.#tripByGtfsID.has(gtfsTripID)) {
      const row = openDB()
        .prepare("SELECT id, headsign, route_id FROM trips WHERE gtfs_id = ?")
        .get(gtfsTripID);
      this.#tripByGtfsID.set(gtfsTripID, row ?? null);
    }
    return this.#tripByGtfsID.get(gtfsTripID);
  }

  ingest(feedMessage) {
    const now = Date.now();
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

  async function poll() {
    try {
      const response = await fetch(config.gtfsRealtimeURL());
      if (!response.ok) throw new Error(`BODS GTFS-RT: HTTP ${response.status}`);
      const buffer = Buffer.from(await response.arrayBuffer());
      const message = transit_realtime.FeedMessage.decode(buffer);
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
