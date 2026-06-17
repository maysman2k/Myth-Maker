import fs from "node:fs";
import http2 from "node:http2";
import jwt from "jsonwebtoken";
import { config } from "../config.js";

/**
 * Minimal Apple Push Notification service client using token-based auth
 * (a .p8 key) over HTTP/2. Opens a fresh connection per send — simple and
 * robust at low volume; pool connections if push traffic ever grows.
 */
export class ApnsClient {
  #jwt = null;
  #jwtIssuedAt = 0;
  #keyContents = null;

  get configured() {
    return Boolean(
      config.apns.keyId && config.apns.teamId && config.apns.keyPath
        && fs.existsSync(config.apns.keyPath),
    );
  }

  get host() {
    return config.apns.production
      ? "https://api.push.apple.com"
      : "https://api.sandbox.push.apple.com";
  }

  // APNs JWTs are valid up to 1 hour; reuse for ~50 minutes.
  #authToken() {
    const now = Math.floor(Date.now() / 1000);
    if (this.#jwt && now - this.#jwtIssuedAt < 3000) return this.#jwt;
    if (!this.#keyContents) this.#keyContents = fs.readFileSync(config.apns.keyPath, "utf8");
    this.#jwt = jwt.sign({ iss: config.apns.teamId, iat: now }, this.#keyContents, {
      algorithm: "ES256",
      header: { alg: "ES256", kid: config.apns.keyId },
    });
    this.#jwtIssuedAt = now;
    return this.#jwt;
  }

  /**
   * Sends an alert push. Resolves { status, reason }:
   *  200          → delivered
   *  400 / 410    → bad or expired device token (caller should drop it)
   *  0            → not configured / connection error (reason explains)
   */
  send(deviceToken, { title, body }) {
    return new Promise((resolve) => {
      if (!this.configured) return resolve({ status: 0, reason: "APNs not configured" });

      let authToken;
      try {
        authToken = this.#authToken();
      } catch (error) {
        return resolve({ status: 0, reason: `JWT error: ${error.message}` });
      }

      const payload = JSON.stringify({ aps: { alert: { title, body }, sound: "default" } });
      const client = http2.connect(this.host);
      client.on("error", (error) => resolve({ status: 0, reason: String(error.message) }));

      const req = client.request({
        ":method": "POST",
        ":path": `/3/device/${deviceToken}`,
        authorization: `bearer ${authToken}`,
        "apns-topic": config.apns.bundleId,
        "apns-push-type": "alert",
        "content-type": "application/json",
      });

      let status = 0;
      let data = "";
      req.on("response", (headers) => { status = headers[":status"]; });
      req.on("data", (chunk) => { data += chunk; });
      req.on("end", () => {
        client.close();
        let reason = "";
        try { reason = JSON.parse(data).reason ?? ""; } catch { /* empty body on success */ }
        resolve({ status, reason });
      });
      req.on("error", (error) => {
        client.close();
        resolve({ status: 0, reason: String(error.message) });
      });
      req.end(payload);
    });
  }
}
