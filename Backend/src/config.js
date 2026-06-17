import "dotenv/config";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

// Stray whitespace in .env (e.g. "BODS_API_KEY= abc") silently breaks
// authentication — normalise the key once here so it can't.
const apiKey = (process.env.BODS_API_KEY ?? "").trim();
process.env.BODS_API_KEY = apiKey;

if (!apiKey || apiKey.startsWith("paste-")) {
  console.warn("⚠ BODS_API_KEY is not set — copy .env.example to .env and add your key.");
}

export const config = {
  bodsApiKey: process.env.BODS_API_KEY ?? "",
  gtfsRegion: process.env.GTFS_REGION ?? "north_west",
  /// Route map lines (shapes.txt) are the second-biggest part of the
  /// national dataset. Set GTFS_IMPORT_SHAPES=false to skip them and
  /// roughly halve the disk needed — route detail maps just lose the line.
  importShapes: (process.env.GTFS_IMPORT_SHAPES ?? "true").toLowerCase() !== "false",
  pollSeconds: Math.max(5, Number(process.env.POLL_SECONDS ?? 10)),
  port: Number(process.env.PORT ?? 3000),

  // --- Security / abuse protection ---
  // Requests allowed per IP per minute (rate limiting). Generous enough for
  // a phone polling the live map; low enough to blunt scraping/DoS.
  rateLimitPerMinute: Number(process.env.RATE_LIMIT_PER_MINUTE ?? 120),
  // Optional shared secret. When set, clients must send a matching
  // `x-app-token` header. Left empty in development so localhost just works;
  // set it in production for a basic gate against casual free-riding.
  appSharedToken: (process.env.APP_SHARED_TOKEN ?? "").trim(),
  // Reject stop/vehicle bounding boxes larger than this (square degrees) —
  // defends the server even if a client ignores its own clamp.
  maxQueryBBoxArea: 0.5,
  // True in production: suppresses internal error detail in responses.
  isProduction: process.env.NODE_ENV === "production",

  // --- Push notifications (APNs) ---
  // Token-based auth: a .p8 key from the Apple Developer account. Server
  // push is disabled until these are set.
  apns: {
    keyPath: process.env.APNS_KEY_PATH ?? path.join(root, "apns-key.p8"),
    keyId: (process.env.APNS_KEY_ID ?? "").trim(),
    teamId: (process.env.APNS_TEAM_ID ?? "").trim(),
    bundleId: (process.env.APNS_BUNDLE_ID ?? "com.bricksinabag.buspulse").trim(),
    // Dev/TestFlight device tokens use the sandbox; App Store uses production.
    production: (process.env.APNS_PRODUCTION ?? "false").toLowerCase() === "true",
  },
  // Protects admin-only endpoints (e.g. the test push).
  adminKey: (process.env.ADMIN_KEY ?? "").trim(),

  dataDir: path.join(root, "data"),
  dbPath: path.join(root, "data", "gtfs.sqlite"),

  // BODS endpoints. Documented at https://data.bus-data.dft.gov.uk/
  gtfsStaticURL: (region) =>
    `https://data.bus-data.dft.gov.uk/timetable/download/gtfs-file/${region}`,
  /// Candidate GTFS-RT live feed URLs — the poller probes these in order
  /// and locks onto the first that responds. (GOV.UK blocks automated doc
  /// reads, so the exact path couldn't be verified ahead of time; accounts
  /// have been observed on both.)
  gtfsRealtimeCandidates: () => [
    `https://data.bus-data.dft.gov.uk/avl/download/gtfsrt?api_key=${process.env.BODS_API_KEY}`,
    // The bulk download endpoint also serves without a key (verified in a
    // browser) — keeps live data flowing even if the key is misconfigured.
    "https://data.bus-data.dft.gov.uk/avl/download/gtfsrt",
    `https://data.bus-data.dft.gov.uk/api/v1/gtfsrtdatafeed/?api_key=${process.env.BODS_API_KEY}`,
  ],

  // Drop live vehicles not seen for this long.
  vehicleStaleSeconds: 300,
};
