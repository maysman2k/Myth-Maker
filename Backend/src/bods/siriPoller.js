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
import yauzl from "yauzl";
import { config } from "../config.js";

/// Candidate SIRI-VM sources, probed in order; the first that yields
/// vehicles is locked in. The datafeed API returns raw XML (key required);
/// the bulk archive returns a zip containing one XML file.
const candidates = () => [
  `https://data.bus-data.dft.gov.uk/api/v1/datafeed/?api_key=${config.bodsApiKey}`,
  "https://data.bus-data.dft.gov.uk/avl/download/bulk_archive",
];

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

/// First entry of a zip buffer, as text.
function unzipFirstEntry(buffer) {
  return new Promise((resolve, reject) => {
    yauzl.fromBuffer(buffer, { lazyEntries: true }, (err, zip) => {
      if (err) return reject(err);
      zip.on("error", reject);
      zip.on("entry", (entry) => {
        zip.openReadStream(entry, (streamErr, stream) => {
          if (streamErr) return reject(streamErr);
          const chunks = [];
          stream.on("data", (chunk) => chunks.push(chunk));
          stream.on("error", reject);
          stream.on("end", () => {
            resolve(Buffer.concat(chunks).toString("utf8"));
            zip.close();
          });
        });
      });
      zip.readEntry();
    });
  });
}

export function startSiriPolling(store) {
  if (!config.bodsApiKey) {
    console.log("SIRI-VM overlay disabled (no BODS_API_KEY).");
    return;
  }
  let lockedURL = null;
  let announced = false;
  let backoff = 0;

  async function fetchOverlay(url) {
    const response = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; BusPulse/1.0; +support@bricksinabag.com)",
        Accept: "*/*",
      },
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const buffer = Buffer.from(await response.arrayBuffer());
    // Zip archives start "PK"; everything else is treated as XML text.
    const xml = buffer[0] === 0x50 && buffer[1] === 0x4b
      ? await unzipFirstEntry(buffer)
      : buffer.toString("utf8");
    const overlay = parseSiriVehicles(xml);
    if (overlay.size === 0) {
      throw new Error(`parsed 0 vehicles (body starts: ${xml.slice(0, 120).replaceAll("\n", " ")})`);
    }
    return overlay;
  }

  async function poll() {
    const urls = lockedURL ? [lockedURL] : candidates();
    let lastError = null;
    for (const url of urls) {
      try {
        const overlay = await fetchOverlay(url);
        store.applySiriOverlay(overlay);
        lockedURL = url;
        backoff = 0;
        if (!announced) {
          announced = true;
          console.log(`SIRI-VM overlay active: line names for ${overlay.size} vehicles.`);
        }
        lastError = null;
        break;
      } catch (error) {
        lastError = error;
        console.error(`SIRI-VM candidate failed (${url.split("?")[0]}):`,
                      String(error.message ?? error).slice(0, 200));
      }
    }
    if (lastError) {
      lockedURL = null; // re-probe all candidates next time
      backoff = Math.min(backoff ? backoff * 2 : 60, 900);
    }
    setTimeout(poll, (backoff || config.siriPollSeconds) * 1000);
  }

  poll();
}
