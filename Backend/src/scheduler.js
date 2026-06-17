import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { config } from "./config.js";
import { closeDB } from "./db.js";

const importScript = path.join(path.dirname(fileURLToPath(import.meta.url)), "bods", "importGTFS.js");

/// Milliseconds until the next occurrence of `hourUK:00` in UK local time.
function msUntilNextRun(hourUK = 3) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/London", hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false,
  }).formatToParts(new Date());
  const value = (type) => Number(parts.find((p) => p.type === type)?.value ?? 0);
  const ukHour = value("hour") % 24;
  let seconds = ((hourUK - ukHour + 24) % 24) * 3600 - value("minute") * 60 - value("second");
  if (seconds <= 0) seconds += 24 * 3600;
  return seconds * 1000;
}

/// Re-imports the GTFS timetables once a day (~03:00 UK) so saved/served
/// schedules stay current, then reloads the database in place. Runs the import
/// as a child process so the live API keeps serving throughout.
export function scheduleDailyImport() {
  if (!config.bodsApiKey) {
    console.log("Daily GTFS auto-import disabled (no BODS_API_KEY).");
    return;
  }

  const run = () => {
    console.log("Scheduled GTFS import starting…");
    const child = spawn(process.execPath, [importScript], { stdio: "inherit" });
    child.on("exit", (code) => {
      if (code === 0) {
        closeDB();
        console.log("Scheduled GTFS import complete; database reloaded.");
      } else {
        console.error(`Scheduled GTFS import failed (exit ${code}); keeping previous data.`);
      }
      setTimeout(run, msUntilNextRun());
    });
  };

  setTimeout(run, msUntilNextRun());
  console.log("Daily GTFS auto-import scheduled (~03:00 UK).");
}
