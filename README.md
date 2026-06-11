> This repository contains two independent iOS apps:
> **Planr** (group event planning — below) and **[BusPulse](BusPulse/README.md)** (live UK bus tracking with offline timetables, in `BusPulse/`).

# Planr 🎉

**Plan great events without the group chat chaos.**

Planr is a native iOS app (SwiftUI, iOS 17+) for organising group events — nights out, weekend trips, stags and hens, concerts, family days. It pulls the deciding, organising, hyping and remembering into one place, built from the product brief in this repo's design history.

## What's in the app

### Decide
- **Date availability votes** — leader proposes days, everyone taps what works, Planr surfaces the best date with consensus labels ("Everyone can do this. That never happens.").
- **Location and freeform votes** with deadlines, live tallies, "who hasn't voted" nudges and leader confirmation. Confirmed date/location votes flow straight into the event details.

### Organise
- **Lockdown mode** — the leader locks the core plan with a heavy haptic and a "Locked in. No more chaos." banner. After lockdown, core details need a leader override.
- **Tasks** with assignees, due dates, overdue flags and a tap-to-advance status flow.
- **Payment tracking** (owed → says-it's-paid → confirmed). Planr never holds money — it just remembers who owes. The brief's future money-pot is deliberately out of scope.
- **Apple Calendar sync** (EventKit, write-only access) once a date is locked.
- **Invites** via share sheet, QR code and secure short codes, with leader revoke/rotate.
- **Local notifications** for vote deadlines and event kick-off.

### Hype
- **Event Pulse** — a weighted readiness score (decisions, tasks, money, replies) with a cheeky headline that names the blocker when there is one.
- **Event chat** with reactions and system moments ("Pete locked in Dublin as the destination.").
- **Phase-aware dashboard** — planning leads with the Pulse and next steps; the final two weeks switch to a countdown-led hype mode; live mode goes glanceable (today's plan, location, who's doing what).
- **Event Bingo** — everyone predicts what'll happen, the leader approves, cards get dealt (deterministic, seeded RNG), claims need sign-off, first full card wins.
- **Shame board** — opt-in per event, playful not punishing, and anyone can hide themselves globally from Profile → Safety.

### Remember
- **Memory Vault** of wrapped events.
- **Event Wrap** — stats, awards (Event MVP, Chat champion, Shutterbug, Last to pay, Bingo champion), the most-reacted quote, the photo strip, and a shareable recap.
- **Shared photo album** via the iOS Photos picker, with client-side JPEG compression, captions, reactions, owner-delete and leader moderation.

## Running it

Open `Planr.xcodeproj` in **Xcode 16+** and run the `Planr` scheme on an iOS 17+ simulator or device. There is no backend to configure — pick "Start with a sample event" during onboarding to land in a Dublin trip mid-planning (with a wrapped Newcastle night in the vault) and try the full leader flow: vote → confirm the date → Lock it in → live mode → wrap.

Tests: the `PlanrTests` target covers the business logic called out in the brief — vote winners and tie-breaks, date availability scoring, consensus levels, Event Pulse maths, lockdown rules, task overdue and payment states, bingo card generation and the wrap builder.

## Architecture

```
Planr/
  App/            Entry point, root tab navigation
  Core/
    DesignSystem/ Semantic tokens (PlanrColor, PlanrSpacing, PlanrFont) + components
    Services/     EventKit calendar sync, notifications, haptics, image store, invite codes
    Utilities/    AppError, date helpers, seeded RNG
  Domain/
    Models/       Codable value types (Event, Vote, EventTask, Payment, …)
    Logic/        Pure calculators: VoteCalculator, EventPulseCalculator,
                  LockdownPolicy, BingoCardGenerator, ShameBoardCalculator, EventWrapBuilder
  Data/           AppModel (observable source of truth), LocalStore (JSON persistence),
                  SeedFactory (sample data)
  Features/       One folder per screen group (Home, Events, Voting, Chat,
                  TasksMoney, Photos, Games, Memories, Profile, Onboarding)
PlanrTests/       XCTest unit tests for Domain/Logic
```

Key decisions, mapped to the brief:

- **Local-first MVP, cloud-ready seams.** The brief recommends Firebase; this build ships a fully working single-device MVP instead, with the seams in place: persistence goes through the `SnapshotPersisting` protocol (`LocalStore` today, a Firestore-backed store later), calendar access through `CalendarSyncing`, and `AppSnapshot` mirrors the brief's Firestore collection design one-to-one. Nothing leaves the device, which is also the honest privacy story until auth + security rules exist.
- **Observation framework, not MVVM boilerplate.** One `@MainActor @Observable AppModel` is the source of truth; mutations live in a single actions layer that persists and posts system chat moments. All decision-making logic is in pure, UI-free `Domain/Logic` enums — that's where the tests bite, and it's the code that ports to web/Android backends unchanged.
- **Design for intent.** The dashboard derives an `EventMode` (planning / lockdown / hype / live / memory) from phase + proximity and reorders itself accordingly.
- **Accessibility**: Dynamic Type throughout, VoiceOver labels on custom controls, Reduce Transparency fallback for glass surfaces, Reduce Motion respected on countdown transitions, 44pt tap targets, status never conveyed by colour alone.
- **Tone**: plain English, slightly cheeky, never corporate ("You're all settled up. Halo earned.").

## What's deliberately deferred

Matching the brief's MVP staging: cross-device sync and real invite joins (needs the backend + auth), push notifications (local only for now), stored money pot, AI assistant, itinerary builder, Prediction League / Wheel of Consequences, event map and Annual Wrapped. The join-with-code screen says exactly this to users rather than pretending.
