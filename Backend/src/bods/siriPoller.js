/**
 * SIRI-VM overlay — names the vehicles the timetable can't.
 *
 * The GTFS-RT live feed identifies vehicles by route/trip ids that must be
 * matched against the static timetable; when the ids don't line up (they
 * drift between data builds), a vehicle has no line name and can never be
 * shown "on route X8". BODS's other live feed, SIRI-VM, carries the line
 * name and destination directly on every vehicle — it's what bustimes.org
 * uses. We poll it slowly and merge: GTFS-RT stays the position source,
 * SIRI supplies names where timetable enrichment failed.
 */
import { config } from "../config.js";

/// VehicleRef → { line, destination } from a SIRI-VM XML document. Zero-dep,
/// tolerant scan: national feeds are tens of MB, so full XML parsing is
/// avoided in favour of per-<VehicleActivity> field extraction.
export function parseSiriVehicles(xml) {
  const out = new Map();
  const field = (block, name) =>
    block.match(new RegExp(`<${name}>([^<]*)</${name}>`))?.[1]?.trim() || null;
  for (const match of xml.matchAll(/<VehicleActivity>([\s\S]*?)<\/VehicleActivity>/g)) {
    const block = match[1];
    const ref = field(block, "VehicleRef");
    const line = field(block, "PublishedLineName") ?? field(block, "LineRef");
    if (!ref || !line) continue;
    out.set(ref, { line, destination: field(block, "DestinationName") });
  }
  return out;
}

export function startSiriPolling(store) {
  if (!config.bodsApiKey) {
    console.log("SIRI-VM overlay disabled (no BODS_API_KEY).");
    return;
  }
  const url = `https://data.bus-data.dft.gov.uk/api/v1/datafeed/?api_key=${config.bodsApiKey}`;
  let announced = false;
  let backoff = 0;

  async function poll() {
    try {
      const response = await fetch(url, {
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; BusPulse/1.0; +support@bricksinabag.com)",
          Accept: "*/*",
        },
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const overlay = parseSiriVehicles(await response.text());
      if (overlay.size > 0) {
        store.applySiriOverlay(overlay);
        backoff = 0;
        if (!announced) {
          announced = true;
          console.log(`SIRI-VM overlay active: line names for ${overlay.size} vehicles.`);
        }
      }
    } catch (error) {
      backoff = Math.min(backoff ? backoff * 2 : 60, 900);
      console.error(`SIRI-VM poll failed (backing off ${backoff}s):`,
                    String(error.message ?? error).slice(0, 200));
    }
    setTimeout(poll, (backoff || config.siriPollSeconds) * 1000);
  }

  poll();
}
