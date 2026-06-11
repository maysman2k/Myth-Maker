import "dotenv/config";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

if (!process.env.BODS_API_KEY || process.env.BODS_API_KEY.startsWith("paste-")) {
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

  dataDir: path.join(root, "data"),
  dbPath: path.join(root, "data", "gtfs.sqlite"),

  // BODS endpoints. Documented at https://data.bus-data.dft.gov.uk/
  gtfsStaticURL: (region) =>
    `https://data.bus-data.dft.gov.uk/timetable/download/gtfs-file/${region}`,
  gtfsRealtimeURL: () =>
    `https://data.bus-data.dft.gov.uk/api/v1/gtfsrtdatafeed/?api_key=${process.env.BODS_API_KEY}`,

  // Drop live vehicles not seen for this long.
  vehicleStaleSeconds: 300,
};
