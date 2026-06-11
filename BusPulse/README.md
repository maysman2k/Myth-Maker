# BusPulse 🚌

**Every bus in the UK, live — with timetables that work when your signal doesn't.**

BusPulse is a native iOS app (SwiftUI, iOS 17+) built on the public data behind [bustimes.org](https://bustimes.org), the community-run tracker of every UK bus stop, route and live vehicle. It reimagines that site as a modern mobile experience and adds the things an app can do that a website can't: offline timetables, one-tap live-bus sharing, favourites, and location-aware stop discovery.

## How bustimes.org works (and how BusPulse uses it)

bustimes.org aggregates the Department for Transport's **Bus Open Data Service** (timetables in TransXChange, live positions in SIRI-VM) and NaPTAN stop data, then exposes clean JSON. BusPulse was built by reading the site's [open source](https://github.com/jclgoodwin/bustimes.org) to integrate with exactly what's there:

| App feature | Endpoint |
|---|---|
| Live map vehicles | `/vehicles.json?xmin&ymin&xmax&ymax` (or `?service=`) — positions, heading, destination, delay, livery CSS |
| Stops near you / on the map | `/stops.json` (GeoJSON, bbox area-capped at 0.15 deg² — the client clamps) |
| Stop code lookup | `/api/stops/?naptan_code__iexact=` — the SMS code printed on every stop flag |
| Routes calling at a stop | `/api/services/?stops={atco}` |
| Route search | `/api/services/?search=` |
| Stops along a route | `/api/stops/?service={id}` |
| **Offline timetables** | `/api/trips/?service={id}&date=` (cursor-paginated; downloaded and stored on device) |
| Journey calling points | `/api/trips/{id}/` |
| Route line on the map | `/services/{id}.json` |

## What's in the app

- **Live map** — every bus in the visible area, polling on a user-configurable interval with exponential backoff, markers coloured to match the real operator livery (parsed from the feed's CSS), heading arrows, and a stops layer that appears as you zoom in.
- **Vehicle sheet** — tap any bus: destination, fleet details, punctuality chip (on time / late / early), the journey's remaining calling points, **Follow mode** (camera tracks the bus), and **Share live bus** via the system share sheet with a tracking link.
- **Stops** — nearby (sorted by distance), favourites, and lookup by the code on the stop flag. Stop detail shows live buses on its routes with distance-away, the routes calling there, and a **departure board computed entirely offline** from saved timetables.
- **Routes** — search by number or destination; route detail has a live mini-map with the route line drawn, the stop list, and the offline download.
- **Saved timetables** — the headline offline feature. Download a route's full day of journeys (~tens of KB), browse every trip and calling point with zero signal, refresh or delete per route, see storage used. Past-midnight night buses (24:xx/25:xx times) are handled correctly.
- **Offline awareness** — a network monitor switches the app's tone when disconnected: banner up top, live sections explain themselves, saved data keeps working.

## Running it

Open `BusPulse.xcodeproj` in Xcode 16+, run on iOS 17+. No keys or config needed — the data source is public. Note the app talks to production bustimes.org: it identifies itself with a proper User-Agent, follows the documented bbox limits, paginates politely with hard page caps, and defaults to a 15-second refresh.

Tests (`BusPulseTests`, ⌘U) cover the logic that matters: timetable time parsing including past-midnight times, the offline departure calculator (wrap-around, interleaving, limits), bounding-box clamping to the API's area cap, livery colour extraction from CSS, delay thresholds, and DTO decoding against realistic feed fixtures (including heading-as-string and sparse records).

## Architecture

```
BusPulse/
  App/             Entry, tabs, environment wiring
  Core/
    DesignSystem/  Tokens + components (RoutePill, LiveBadge, DelayChip…)
    Utilities/     LocationProvider, NetworkMonitor
  Domain/
    Models/        Stop, Service, VehiclePosition, CachedTimetable…
    Logic/         TimeOfDay, DepartureCalculator, BoundingBox,
                   DelayStatus, LiveryColor — pure and unit-tested
  Data/
    API/           BusTimesAPIProviding protocol + bustimes.org client,
                   tolerant DTOs
    LiveVehiclesModel   Polling engine (watch query, backoff, pause)
    TimetableStore      Offline timetable persistence
    FavoritesStore, SettingsStore
  Features/        LiveMap, Stops, Services, Timetables, Settings
BusPulseTests/
```

The API sits behind `BusTimesAPIProviding`, so the backend can move to BODS directly (or a caching proxy of your own) without touching feature code — the right move before any wide release, both for resilience and out of respect for a community-run service.

## Honest caveats & next steps

- **Be a good citizen**: bustimes.org is one person's labour of love, not a commercial API. For anything beyond personal use, get in touch with the maintainer and/or stand up your own BODS-backed proxy.
- Departure boards are **scheduled times** from saved timetables; live per-stop predictions would come next (SIRI stop monitoring via BODS).
- Worth adding later: a Lock Screen **Live Activity** while following a bus, widgets for favourite stops, day-picker for timetable downloads, and trip progress shown on the journey list.
