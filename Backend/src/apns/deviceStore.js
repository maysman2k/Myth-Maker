import fs from "node:fs";
import path from "node:path";
import { config } from "../config.js";

/**
 * Stores registered device push tokens in a JSON file. Lives in the data
 * directory, which the GTFS import does not touch, so registrations survive
 * timetable re-imports and server restarts.
 */
export class DeviceStore {
  #tokens = new Set();
  #file;

  constructor() {
    this.#file = path.join(config.dataDir, "devices.json");
    try {
      this.#tokens = new Set(JSON.parse(fs.readFileSync(this.#file, "utf8")));
    } catch {
      this.#tokens = new Set();
    }
  }

  add(token) {
    if (typeof token !== "string" || token.length < 32) return;
    if (this.#tokens.has(token)) return;
    this.#tokens.add(token);
    this.#persist();
  }

  remove(token) {
    if (this.#tokens.delete(token)) this.#persist();
  }

  all() {
    return [...this.#tokens];
  }

  get count() {
    return this.#tokens.size;
  }

  #persist() {
    fs.mkdirSync(config.dataDir, { recursive: true });
    fs.writeFileSync(this.#file, JSON.stringify([...this.#tokens]));
  }
}
