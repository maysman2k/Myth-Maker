# BusPulse Backend — BODS proxy

A small Node.js service that ingests the UK Department for Transport's
**Bus Open Data Service (BODS)** and serves it to the BusPulse iOS app
using **exactly the same URL paths and JSON shapes** the app already
consumes. Pointing the app at this server instead of bustimes.org is a
one-line base-URL change — no feature code changes.

```
BODS (DfT, OGL v3, free)                this server                    BusPulse app
─────────────────────────    ──────────────────────────────────    ─────────────────
GTFS-RT live positions   →   poller → in-memory vehicle store  →   GET /vehicles.json?xmin…
GTFS timetables (zip)    →   daily import → SQLite             →   GET /api/trips/?service=…
  (stops, routes, trips,                                           GET /api/services/?search=…
   stop_times, shapes)                                             GET /stops.json?xmin…
                                                                   GET /services/{id}.json
```

## Why this exists

- **Commercial use is allowed.** BODS data is published under the
  [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/),
  which explicitly permits commercial exploitation (ad-funded apps included)
  with attribution. bustimes.org, by contrast, is a volunteer-run community
  site with no commercial licence — great for prototyping, wrong to build a
  business on.
- **Your own infrastructure.** No third-party goodwill in the request path.

## Setup

### 1. Register with BODS (free)

1. Create an account at <https://data.bus-data.dft.gov.uk/account/signup/>
2. Find your API key under **Account settings → API key**

### 2. Configure and run

```bash
cd Backend
cp .env.example .env        # then paste your BODS_API_KEY into .env
npm install
npm run import-gtfs         # downloads + imports the GTFS timetable archive (slow first time)
npm start                   # serves on :3000, starts the live position poller
```

`GTFS_REGION` in `.env` controls how much of the country you import.
Start with a region (e.g. `north_west`) — `all` is a multi-hundred-MB
download and a long import. Re-run `npm run import-gtfs` daily (cron)
to stay current; the import is atomic (builds a new SQLite file, then
swaps it in).

### 3. Point the app at it

In `BusPulse/App/BusPulseApp.swift`:

```swift
private let api: BusTimesAPIProviding =
    BusTimesAPI(baseURL: URL(string: "https://api.your-domain.com")!)
```

## Endpoints served (bustimes.org-compatible)

| Path | Backed by |
|---|---|
| `GET /vehicles.json?xmin&ymin&xmax&ymax` or `?service=ids` | GTFS-RT poller (in-memory) |
| `GET /stops.json?xmin&ymin&xmax&ymax` (GeoJSON) | GTFS `stops` + served-routes join |
| `GET /api/stops/?naptan_code__iexact=` / `?service=` | GTFS `stops` (`stop_code` = NaPTAN SMS code) |
| `GET /api/services/?search=` / `?stops=` | GTFS `routes` |
| `GET /api/trips/?service=&date=` | GTFS `trips` + `stop_times` + `calendar` |
| `GET /api/trips/{id}/` | same |
| `GET /services/{id}.json` | GTFS `shapes` → MultiLineString |
| `GET /health` | poller freshness + DB stats |

IDs: GTFS route/trip IDs are strings, the app expects integers — the
import assigns stable integer IDs (SQLite rowids) and keeps the mapping.

## Known gaps vs bustimes.org (by design, for now)

- **No livery colours / fleet details** — community data, not in BODS.
  The app's route pills fall back to the default colour.
- **`delay` is null** — needs the SIRI-VM feed or GTFS-RT trip updates
  matched against schedules; a good fast-follow.
- **England only** — Scotland/Wales/NI publish via Traveline; add later.

## Attribution you must ship (OGL v3)

Display in the app (Settings → About is fine):

> Contains public sector information licensed under the Open Government
> Licence v3.0. Bus data from the Department for Transport's
> Bus Open Data Service.

## Deploying

Any small VPS or container host works (the whole thing is one Node process
+ one SQLite file; ~£5–10/month). Put it behind HTTPS (Caddy/nginx or the
host's built-in TLS), set `BODS_API_KEY` as a secret, and add a daily cron
for `npm run import-gtfs`. Add a CDN/cache in front of `/api/trips/`
responses if traffic grows — timetables only change daily.
