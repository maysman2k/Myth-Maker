# Wait Less — Live UK Bus Tracking

> **Every bus in the UK, live — with timetables that work when your signal doesn't.**

This is the master document for the **Wait Less** app (project nickname *"Wait time"*; codebase name **BusPulse**). It pulls together the iOS app, the backend server, the live infrastructure, and the current state of play so anyone — including future-you — can pick the project up cold.

---

## 1. Names & identity

The project carries three names for historical reasons. They all refer to the same thing:

| Name | Where it's used |
|---|---|
| **Wait Less** | The App Store **display name** (`CFBundleDisplayName`) — what users see under the icon |
| **Wait time** | Your local project **folder** name (`/Users/petermays/Documents/Vibecoding/Wait time`) |
| **BusPulse** | The **codebase / Xcode target / bundle name** and this repo's iOS folder |

- **Bundle ID:** `com.bricksinabag.buspulse`
- **Custom URL scheme:** `waitless://`
- **Production server:** `https://waitless.bricksinabag.com`
- **Business:** Bricks in a Bag (`bricksinabag.com`)
- **Platform:** Native iOS, SwiftUI, iOS 17+

> The repo (`Myth-Maker`) also contains a *separate* app, **Planr**. This document is **only** about Wait Less / BusPulse.

---

## 2. What the app does

Wait Less reimagines [bustimes.org](https://bustimes.org) — the community tracker of every UK bus stop, route and live vehicle — as a modern native app, then adds the things an app can do that a website can't: offline timetables, live-bus sharing, location-aware stop discovery, and bus-arrival alarms.

### Core features

- **Live map** — every bus in the visible area, polling on a configurable interval with exponential backoff. Markers are coloured to the real operator livery, show heading arrows, and a stops layer fades in as you zoom.
- **Vehicle sheet** — tap any bus for destination, fleet details, a punctuality chip (on time / late / early), **Follow mode** (camera tracks the bus), the live **"This Journey"** progress (upcoming stops + estimated arrival times based on current position) with the route drawn on a mini-map, and **Share live bus**.
- **Stops** — nearby (sorted by distance), favourites, and lookup by the SMS code printed on the stop flag. Stop detail shows live buses on its routes (tappable through to the bus), the routes calling there, and a **departure board computed entirely offline** from saved timetables.
- **Routes** — search by number or destination; route detail has a live mini-map with the route line, the stop list, and the offline download.
- **Saved timetables** — the headline offline feature. Download a route's full day of journeys (~tens of KB), browse every trip as a **proper grid** (stops down the side, journeys across — like the bustimes.org timetable view), with **Edit / swipe-to-delete** per route. Past-midnight night buses (24:xx / 25:xx times) handled correctly.
- **Journey planner** — pick a start and destination; see which **direct buses** link them and their next departures. (Multi-leg journeys with transfers are a noted future enhancement.)
- **Bus arrival alarms** — set an alarm for a bus approaching a stop; a local notification fires. (Server push plumbing is built — see §7.)
- **Sharing** — share a live bus via a `waitless://` deep link (and an HTTPS `/share` landing page), which opens straight to that bus/route/stop in the app.
- **Offline awareness** — a network monitor changes the app's tone when disconnected: a banner appears, live sections explain themselves, saved data keeps working.

---

## 3. Architecture overview

```
┌─────────────────────────┐     HTTPS      ┌──────────────────────────────┐
│   Wait Less (iOS app)    │ ─────────────▶ │  Backend proxy (DigitalOcean)│
│   SwiftUI, iOS 17+       │  bustimes.org- │  Node.js + SQLite + Caddy    │
│                          │  shaped JSON   │  waitless.bricksinabag.com   │
└─────────────────────────┘ ◀───────────── └──────────────┬───────────────┘
                                                           │  ingests
                                                           ▼
                                         ┌──────────────────────────────────┐
                                         │  DfT Bus Open Data Service (BODS) │
                                         │  GTFS timetables + GTFS-RT live   │
                                         │  Open Government Licence v3.0     │
                                         └──────────────────────────────────┘
```

The key design decision: **the backend serves the exact same URL paths and JSON shapes that bustimes.org does.** That means the app was first built against bustimes.org, then pointed at our own server with a **one-line base-URL change** and no feature-code changes. The app talks to data through a single `BusTimesAPIProviding` protocol, so the data source is fully swappable.

### Why our own backend (not bustimes.org directly)

- **Commercial use is allowed.** BODS data is published under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/), which explicitly permits commercial use (ad-funded apps included) with attribution. bustimes.org is a volunteer-run community site with no commercial licence — great for prototyping, wrong to build a business on.
- **No third-party goodwill in the request path** — our own infrastructure, our own uptime.

---

## 4. iOS app (BusPulse)

### Tech stack
SwiftUI · Observation framework (`@Observable`) · MapKit · CoreLocation · UserNotifications · async/await. iOS 17+. No third-party dependencies.

### Folder structure

```
BusPulse/
  App/
    BusPulseApp.swift     Entry point; wires environment, sets server base URL
    RootView.swift        Tabs + deep-link (.onOpenURL) handling
    AppDelegate.swift     Remote-notification registration
  Core/
    DesignSystem/         BPTheme (colour/spacing/font tokens) + Components
                          (RoutePill, LiveBadge, DelayChip, BPCard, EmptyState…)
    Utilities/            LocationProvider, NetworkMonitor
  Domain/
    Models/Models.swift   Stop, Service, VehiclePosition, CachedTimetable,
                          TimetableStopTime, JourneyOption…
    Logic/                Pure, unit-tested logic:
                            TimeOfDay, DepartureCalculator, BoundingBox,
                            DelayStatus, LiveryColor, TimetableGrid,
                            JourneyProgress, RouteVehicleMatcher,
                            VehiclePrioritiser
  Data/
    API/                  BusTimesAPIProviding protocol + BusTimesAPI client,
                          tolerant DTOs
    LiveVehiclesModel     Live polling engine (watch query, backoff, pause)
    TimetableStore        Offline timetable persistence
    FavoritesStore, SettingsStore
  Features/
    LiveMap/              LiveMapView, BusDetailView, MapNavigation
    Stops/                StopsView, StopDetailView
    Services/             ServiceSearchView, ServiceDetailView
    JourneyPlanner/       JourneyPlannerView
    Timetables/           OfflineTimetablesView (grid + delete)
    Alarms/               AlarmManager, BusAlarm, AlarmStopPickerSheet,
                          LocalNotifications
    Push/                 PushService (device-token registration)
    Sharing/              DeepLink (parser), WaitlessShare
    Settings/             SettingsView, LegalContent, LegalDocumentView
BusPulseTests/            Unit tests (see §9)
```

### Where the app gets its data
`BusPulseApp.swift` points every build at the live server:

```swift
BusTimesAPI(baseURL: URL(string: "https://waitless.bricksinabag.com")!)
```

For local backend work, temporarily swap in `http://localhost:3000` (the Info.plist allows insecure HTTP to `localhost` only; production is HTTPS).

---

## 5. Backend (BODS proxy)

A small Node.js service (`Backend/`) that ingests BODS and serves bustimes.org-compatible JSON.

### Tech stack
Node.js 20+ · Express · better-sqlite3 · GTFS-RT (`gtfs-realtime-bindings`) · `yauzl` (streaming unzip) · `jsonwebtoken` (APNs) · `express-rate-limit` · `csv-parse` · `dotenv`. Process-managed by **pm2**, fronted by **Caddy** (automatic HTTPS).

### Data flow

```
BODS (DfT, OGL v3, free)                 this server                       Wait Less app
─────────────────────────     ──────────────────────────────────      ─────────────────
GTFS-RT live positions    →    poller → in-memory vehicle store    →   GET /vehicles.json
GTFS timetables (zip)     →    daily import → SQLite               →   GET /api/trips/…
  stops, routes, trips,                                                GET /api/services/…
  stop_times, shapes                                                   GET /stops.json
                                                                       GET /services/{id}.json
                                                                       GET /api/journey
```

- **Live positions** (GTFS-RT) refresh on a **continuous poll every ~10 seconds** into an in-memory store; vehicles unseen for 5 minutes are dropped.
- **Static timetables** (GTFS) are imported into SQLite, then re-imported **automatically once a day at ~03:00 UK** (`scheduler.js`) — atomic swap of the database file, no downtime. *(This answers the "how often are timetables updated?" question: schedules daily overnight; live positions every few seconds.)*

### Endpoints

| Path | Backed by |
|---|---|
| `GET /vehicles.json?xmin&ymin&xmax&ymax` or `?service=ids` | GTFS-RT poller (in-memory) |
| `GET /stops.json?xmin&ymin&xmax&ymax` (GeoJSON) | GTFS `stops` + served-routes join |
| `GET /api/stops/?naptan_code__iexact=` / `?service=` | GTFS `stops` (`stop_code` = NaPTAN SMS code) |
| `GET /api/services/?search=` / `?stops=` | GTFS `routes` (with derived descriptions) |
| `GET /api/trips/?service=&date=` | GTFS `trips` + `stop_times` + `calendar` |
| `GET /api/trips/{id}/` | same (calling points incl. stop `location` for the map) |
| `GET /api/journey?fromLat&fromLon&toLat&toLon` | direct-bus journey planner |
| `GET /services/{id}.json` | GTFS `shapes` → MultiLineString route line |
| `GET /share?...` | HTML landing page with `waitless://` deep link |
| `GET /.well-known/apple-app-site-association` | Universal Links association |
| `POST /devices` | register an APNs device token |
| `POST /admin/test-push` | admin-key-protected test push |
| `GET /health` | poller freshness, DB stats, push status |

**ID handling:** GTFS route/trip IDs are strings; the app expects integers. The import assigns stable integer IDs and keeps the mapping.

### Configuration (`.env`)

| Key | Purpose |
|---|---|
| `BODS_API_KEY` | Your free BODS API key (whitespace auto-trimmed) |
| `GTFS_REGION` | Region to import — `all` for national, or e.g. `north_west` |
| `GTFS_IMPORT_SHAPES` | `false` to skip route lines and ~halve disk use |
| `POLL_SECONDS` | Live feed poll interval (min 5, default 10) |
| `PORT` | HTTP port (default 3000) |
| `NODE_ENV` | `production` hides internal error detail |
| `RATE_LIMIT_PER_MINUTE` | Per-IP rate limit (default 120) |
| `APP_SHARED_TOKEN` | Optional `x-app-token` gate |
| `APNS_KEY_PATH/_KEY_ID/_TEAM_ID/_BUNDLE_ID/_PRODUCTION` | Push (APNs) auth |
| `ADMIN_KEY` | Protects `/admin` endpoints |

---

## 6. Infrastructure & deployment

| Piece | Detail |
|---|---|
| **Host** | DigitalOcean Droplet (Ubuntu, 2 GB RAM / 50 GB disk) |
| **Process manager** | pm2 (`pm2 restart waitless`, `pm2 logs waitless`) |
| **TLS / reverse proxy** | Caddy (automatic HTTPS) |
| **Domain** | `waitless.bricksinabag.com` (subdomain A-record off the Wix-managed `bricksinabag.com`) |
| **Repo path on droplet** | `/root/Myth-Maker` |
| **Current data scale** | ~13,935 routes · ~313,505 stops · ~1.5M trips · ~24,000 live vehicles (national `all` import) |

### Deploy a backend change

```bash
cd /root/Myth-Maker
git pull
cd Backend
npm install
pm2 restart waitless
pm2 logs waitless --lines 30      # expect "Daily GTFS auto-import scheduled (~03:00 UK)."
curl -s localhost:3000/health     # check vehicles, gtfs stats, push status
```

> If `git pull` is blocked by an untracked `Backend/package-lock.json`, remove it first: `rm -f Backend/package-lock.json`.

### Deploy an app change
On the Mac: `git pull` in the project folder, then **Clean Build Folder + Run** in Xcode.

---

## 7. Push notifications (APNs)

**Stage 1 plumbing is built; the end-to-end test is the remaining step.**

- **Auth:** token-based — an ES256 JWT signed with a `.p8` key (kid = key ID, iss = team ID), cached ~50 min. Sent over HTTP/2 to APNs (`apnsClient.js`).
- **Device tokens:** the app registers for remote notifications (`AppDelegate` + `PushService`) and POSTs its token to `/devices`; stored in `data/devices.json` (`deviceStore.js`).
- **Sandbox vs production:** controlled by `APNS_PRODUCTION` (sandbox for Xcode/TestFlight device builds; production for App Store).
- **Status:** `/health` reports `push: { configured, devices }`. On the server `push.configured` is `true`; a device must run the app (with notifications allowed) before `devices > 0`.

### Remaining manual steps
1. **Xcode:** add the **Associated Domains** capability `applinks:waitless.bricksinabag.com` (for full Universal Links sharing).
2. **Test push:** run the app on a device, allow notifications, then:
   ```bash
   curl -X POST localhost:3000/admin/test-push -H "x-admin-key: <ADMIN_KEY>"
   ```
3. **Stage 2 (future):** wire bus-arrival alarms to server push instead of local notifications.

---

## 8. Security & abuse protection

- Security headers + **per-IP rate limiting** (default 120 req/min).
- Optional **`x-app-token`** shared-secret gate (exempts `/health`, `/devices`, `/share`, `/.well-known/`).
- **Bounding-box area cap** (`maxQueryBBoxArea`) rejects oversized stop/vehicle queries even if a client ignores its own clamp.
- **Admin-key** protection on `/admin/*`.
- Internal error detail suppressed when `NODE_ENV=production`.
- The `.p8` key and `.env` are git-ignored.

---

## 9. Testing

Unit tests (`BusPulseTests`, ⌘U) cover the pure logic:

- `TimetableLogicTests` — time parsing incl. past-midnight (24:xx/25:xx)
- `TimetableGridTests` — grouping journeys into the direction grid
- `JourneyProgressTests` — anchoring to nearest stop, ETA computation
- `DeepLinkParserTests` — `waitless://` and HTTPS `/share` URL parsing
- `BoundingBoxTests` — clamping to the API's area cap
- `VehiclePrioritiserTests` — which vehicles to keep when crowded
- `DTODecodingTests` — tolerant decoding against realistic feed fixtures

---

## 10. Recently completed work

The last development pass delivered five features plus daily auto-import (all committed on branch `claude/planr-ios-app-vwlu2z`):

1. **Tappable live buses** on the stop screen → open the bus detail.
2. **Operational share links** — `waitless://` deep links + `/share` page (Universal Links ready pending the Associated Domains capability).
3. **Fixed "This Journey"** — shows upcoming stops with position-based ETAs and draws the route line on the bus mini-map (previously showed a wrong/stale journey).
4. **Direct-bus journey planner** — start + destination → bus options.
5. **Timetable grid + delete** — saved timetables render as a proper grid with Edit/swipe-to-delete.
6. **Daily automatic GTFS refresh** (~03:00 UK).

---

## 11. Attribution (required — OGL v3)

Ship this in the app (Settings → About):

> Contains public sector information licensed under the Open Government Licence v3.0. Bus data from the Department for Transport's Bus Open Data Service.

---

## 12. Known gaps & roadmap

- **Multi-leg journeys with transfers** — planner currently does direct buses only.
- **No livery colours / fleet details from BODS** — community data only; route pills fall back to a default colour where unavailable.
- **`delay` from BODS** — live punctuality where the realtime feed provides it; the app handles it when present.
- **England-focused** — Scotland/Wales/NI publish via Traveline; add later.
- **Monetisation** — ads (AdMob + App Tracking Transparency + privacy manifest) noted, not built.
- **Siri / App Intents** — discussed, not built.
- **Nice-to-haves** — Lock Screen Live Activity while following a bus, home-screen widgets for favourite stops, a day-picker for timetable downloads.

---

## 13. Quick reference

| Thing | Value |
|---|---|
| App display name | Wait Less |
| Bundle ID | `com.bricksinabag.buspulse` |
| URL scheme | `waitless://` |
| Server | `https://waitless.bricksinabag.com` |
| Droplet repo | `/root/Myth-Maker` |
| Branch | `claude/planr-ios-app-vwlu2z` |
| iOS source | `BusPulse/` |
| Backend source | `Backend/` |
| Health check | `curl -s https://waitless.bricksinabag.com/health` |
| Timetable refresh | Daily ~03:00 UK |
| Live positions refresh | Every ~10s |
| Data licence | Open Government Licence v3.0 (commercial OK + attribution) |
</content>
</invoke>
