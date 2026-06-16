import Database from "better-sqlite3";
import fs from "node:fs";
import { config } from "./config.js";

/**
 * Read-only handle to the GTFS database built by importGTFS.js.
 * The importer writes to a temp file and renames it into place, so the
 * server can simply reopen on demand.
 */
let db = null;

export function openDB() {
  if (db) return db;
  if (!fs.existsSync(config.dbPath)) {
    throw new Error(
      `No GTFS database at ${config.dbPath}. Run \`npm run import-gtfs\` first.`,
    );
  }
  db = new Database(config.dbPath, { readonly: true, fileMustExist: true });
  // No journal_mode pragma here: this is a read-only connection, and changing
  // the journal mode writes to the file ("attempt to write a readonly database").
  return db;
}

export function dbStats() {
  const d = openDB();
  const one = (sql) => d.prepare(sql).get().n;
  return {
    routes: one("SELECT COUNT(*) AS n FROM routes"),
    stops: one("SELECT COUNT(*) AS n FROM stops"),
    trips: one("SELECT COUNT(*) AS n FROM trips"),
    importedAt: d.prepare("SELECT value AS n FROM meta WHERE key='imported_at'").get()?.n,
  };
}

/** "HH:MM:SS" (hours may exceed 23 for past-midnight trips) → seconds. */
export function timeToSeconds(text) {
  if (!text) return null;
  const parts = text.split(":").map(Number);
  if (parts.length < 2 || parts.some(Number.isNaN)) return null;
  const [h, m, s = 0] = parts;
  if (h < 0 || m < 0 || m > 59 || s < 0 || s > 59) return null;
  return h * 3600 + m * 60 + s;
}

/** Seconds after midnight → "HH:MM:SS" (hours may exceed 23). */
export function secondsToTime(seconds) {
  if (seconds == null) return null;
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

/**
 * GTFS service_ids active on a date ("YYYY-MM-DD"), from calendar
 * weekday flags plus calendar_dates exceptions (1 = added, 2 = removed).
 */
export function activeServiceIDs(dateString) {
  const d = openDB();
  const date = new Date(`${dateString}T12:00:00Z`);
  if (Number.isNaN(date.getTime())) return new Set();
  const compact = dateString.replaceAll("-", "");
  const weekday = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"][
    date.getUTCDay()
  ];

  const base = d
    .prepare(
      `SELECT service_id FROM calendar
       WHERE ${weekday} = 1 AND start_date <= ? AND end_date >= ?`,
    )
    .all(compact, compact)
    .map((r) => r.service_id);

  const active = new Set(base);
  for (const row of d
    .prepare("SELECT service_id, exception_type FROM calendar_dates WHERE date = ?")
    .all(compact)) {
    if (row.exception_type === 1) active.add(row.service_id);
    else if (row.exception_type === 2) active.delete(row.service_id);
  }
  return active;
}
