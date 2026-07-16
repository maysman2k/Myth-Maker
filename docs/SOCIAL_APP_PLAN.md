# Brick Studio — Social App Development Plan

Goal: evolve Brick Studio from a local-first content app into a standalone
LEGO®-focused social platform (a mix of Facebook, Instagram and Reddit),
with real accounts, a server-authoritative social graph, and the safety
tooling Apple requires for user-generated content.

This plan is sequenced by dependency, not by excitement. Phases 1–3 are the
foundation everything else sits on; 4–6 are the social experience; 7 is
launch readiness. Each phase lists backend work, iOS work, and a
"definition of done" so we know when to move on.

Current architecture (for context):
- SwiftUI iOS 17+ app, `@Observable AppModel`, local JSON snapshot
  (`LocalStore`) seeded from `SeedFactory`, best-effort Supabase sync
  (`SupabaseService`, PostgREST REST calls).
- Auth: Supabase email/password when configured, with a local fallback that
  hashes passwords on device; demo accounts baked into the seed.
- Media: images stored on device only (`ImageStore`).
- Admin: role checks are client-side; news scanner drives a GitHub Actions
  workflow via a fine-grained PAT stored in Keychain.

---

## Phase 1 — Real identity (auth, sessions, accounts)

The gate to everything else. No social feature is meaningful until an
account exists on exactly one source of truth.

Backend (Supabase):
- [ ] Enable Supabase Auth as the only identity system. Email+password with
      mandatory email verification; password reset emails; magic link as a
      real OTP flow (it currently fakes success).
- [ ] Sign in with Apple (required by App Store 4.8 once any third-party
      login is offered). Google optional afterwards — or remove the button.
- [ ] `profiles` table keyed by `auth.uid()`: unique handle (citext),
      display name, avatar path, bio, birth year (never displayed), role.
      Handle rules: 3–20 chars, alnum + underscore, reserved-word list,
      profanity filter at the DB or edge-function level.
- [ ] RLS: user can select any public profile, update only their own row;
      role column writable only by service role.
- [ ] Age gate: block sign-up under 13 (date-of-birth picker, checked
      server-side in a sign-up edge function, not just in the client).

iOS:
- [ ] Delete the local-account fallback (`signUp`/`signIn` local paths in
      `AppModel+Actions`), `SeedFactory` demo accounts, and the demo
      credentials text in `AuthView`.
- [ ] Rebuild `AuthView`: sign in / create account / forgot password /
      Sign in with Apple; inline validation; loading + error states.
- [ ] Session storage in Keychain (access + refresh token), silent refresh
      on launch, sign-out revocation. Remove password hashes from the local
      snapshot entirely.
- [ ] Post-signup onboarding: pick handle → avatar → interests (LEGO themes)
      → suggested follows.
- [ ] Rebrand pass while we're in these screens: "Bricks in a Bag Studio"
      → "Brick Studio" in auth, News header, settings copy.

Done when: a fresh install can create a verified account, sign out, sign
back in, reset a password, and sign in with Apple — with no local accounts
left in the codebase.

## Phase 2 — Server-authoritative social data

Flip the data model: Postgres is the source of truth, the local snapshot
becomes a cache. Do it table by table, not big-bang.

Backend:
- [ ] Core tables with RLS: `posts` (kind: standard/event/ideas, title,
      body, image paths, challenge_id?), `comments` (post_id, parent_id for
      threading), `reactions` (post_id, user_id, type — unique per pair),
      `follows`, `blocks`, `challenge_votes`, `poll_votes`.
- [ ] RLS policies: insert only as yourself; update/delete only your rows;
      reads exclude content from users who blocked you / you blocked;
      everything else read-only published content.
- [ ] Media: Supabase Storage bucket for post images + avatars. Client
      uploads via signed URL. Limits enforced in policy (max size, MIME).
- [ ] Edge function or DB trigger to maintain denormalised counters
      (reaction counts, comment counts, follower counts).
- [ ] Cursor pagination RPCs for feed, comments, notifications
      (keyset on `created_at, id` — not offset).

iOS:
- [ ] `SupabaseService` grows typed endpoints for the tables above;
      `AppModel+Community` actions become write-through: optimistic local
      update → server write → reconcile/rollback on failure.
- [ ] Image upload pipeline: downscale to ~2048px, JPEG ~0.8, strip EXIF/GPS
      (re-encode via `UIGraphicsImageRenderer`), upload, store path not data.
- [ ] Feed reads become paginated queries; pull-to-refresh; infinite scroll;
      skeleton loaders; offline banner + retry on failure.
- [ ] The Feed splits into two scopes: **Following** and **Everyone**
      (segmented control at the top; remembers last choice).

Done when: two different accounts on two devices can post, see each other's
posts and images, react, comment, follow, and block — and blocking actually
hides content both ways.

## Phase 3 — Safety, moderation & App Store compliance

Apple guideline 1.2 items — a UGC app will be rejected without these.

Backend:
- [ ] `reports` table (content ref, reason, reporter, status) + moderator
      views. Bans: `banned_until`/`banned_reason` on profiles, enforced by
      RLS (banned users can read, not write).
- [ ] Image screening edge function on upload (NSFW/moderation API) —
      quarantine until it passes for new accounts; async re-check for
      established ones.
- [ ] Rate limits (per-user counters or pg function): posts/hour,
      comments/minute, reports/day; link caps for accounts < 7 days old.

iOS:
- [ ] Community guidelines + EULA acceptance screen at sign-up (stored
      acceptance timestamp); zero-tolerance language Apple looks for.
- [ ] Report flows already exist locally — wire them to `reports`; add
      "hide this post" client-side instantly on report.
- [ ] Admin panel: moderation queue (open reports, content preview,
      hide/delete/ban actions) — all actions hit service-role edge
      functions, never direct table writes from the client.
- [ ] In-app account deletion (5.1.1(v)) calling an edge function that
      erases auth user + content or anonymises it; plus a data-export
      request path (GDPR).
- [ ] Move the news-scanner GitHub PAT flow server-side (edge function with
      a stored secret) — remove the in-app token entry once done.

Done when: report → moderator sees it → action lands on another device;
a banned account cannot write; an account can delete itself from Settings.

## Phase 4 — Notifications & liveness

Retention infrastructure. Do immediately after 3 — the app feels dead
without it.

- [ ] APNs setup (key, entitlement); `device_tokens` table.
- [ ] Edge function fan-out on: reply to your post/comment, new follower,
      mention (@handle), challenge result, weekly leaderboard placement.
- [ ] Notification preferences in Settings (per-category toggles, stored
      server-side).
- [ ] Supabase Realtime subscriptions in-app: live new-comment/reaction
      updates on an open post; badge count on the bell.
- [ ] In-app inbox merges local notification history with server events.

Done when: replying on device A pings device B's lock screen within
seconds, and tapping the push deep-links to the right post.

## Phase 5 — The Reddit/Instagram layer

The differentiating social features, in impact order:

- [ ] **Communities ("Baseplates")**: topic groups per LEGO theme (City,
      Technic, Star Wars™, MOCs…). Tables: `communities`,
      `community_members`. Posts get an optional community; feed gains a
      community filter; each community has a page with About + rules.
      This is the Reddit mechanic and it fits the hobby perfectly.
- [ ] **Direct messages**: `conversations`, `messages` tables, Realtime
      channel per conversation, push on new message, requests inbox for
      non-follows, block integration, report-a-message. Text + single image
      first; no groups in v1.
- [ ] **Hashtags & mentions**: parse on post create (server-side), tag
      pages, @mention autocomplete from follows.
- [ ] **Reshare / quote-post** (`reposts` table, embedded original card).
- [ ] **Saved collections** (bookmarks already exist locally — move
      server-side, add named collections).
- [ ] Image carousels with pinch-zoom in post detail; video posts last
      (storage cost + moderation complexity — defer until there's traction).

Done when: a user can live in one community, DM a builder about a MOC, and
tag posts #modular — all with push notifications.

## Phase 6 — Growth & polish

- [ ] Universal links (`https://brickstudio.app/p/<id>`, `/u/<handle>`) +
      share sheets everywhere; App Clips optional later.
- [ ] Profile improvements: follower/following lists, grid/list toggle of a
      builder's posts, My Shelf front and centre, share-profile card.
- [ ] Feed ranking v1: recency + engagement + follow bonus (SQL function);
      "Rising" section reusing challenge/leaderboard energy.
- [ ] Search server-side: Postgres full-text over posts/profiles/
      communities with type-ahead.
- [ ] Accessibility audit (Dynamic Type, VoiceOver on games + feed),
      basic localisation scaffolding (en base, strings extracted).
- [ ] Analytics + crash reporting (privacy-respecting: aggregate funnels —
      signup completion, D1/D7 retention, posts per user) + MetricKit.

## Phase 7 — Launch readiness

- [ ] Privacy policy + terms hosted; App Privacy nutrition labels accurate
      (UGC, identifiers, diagnostics).
- [ ] App Review prep: demo reviewer account, moderation response SLA
      documented, age rating questionnaire (UGC ⇒ 12+ minimum, likely 12/13+).
- [ ] TestFlight beta with ~20 builders; feedback loop; crash triage.
- [ ] Load sanity: seed a few thousand posts, verify pagination and image
      CDN behaviour; RLS penetration pass (attempt cross-user writes with
      anon key from a script).
- [ ] Decide Brick Bar's fate for the standalone brand: keep as a
      "commissions" feature, spin off, or hide behind a remote flag.

---

## Sequencing & effort (working sessions, not calendar time)

| Phase | Scope | Rough effort |
|---|---|---|
| 1 | Auth + identity | 2–3 sessions |
| 2 | Server-authoritative social core | 4–6 sessions (largest) |
| 3 | Safety & compliance | 2–3 sessions |
| 4 | Push + realtime | 2 sessions |
| 5 | Communities, DMs, tags | 4–6 sessions |
| 6 | Growth & polish | 2–3 sessions |
| 7 | Launch | 1–2 sessions + beta time |

Rules we'll hold ourselves to:
1. **No phase-skipping on security items.** RLS lands with each table, not
   "at the end". Client role checks are UX, never enforcement.
2. **Optimistic UI everywhere** — write locally, sync, reconcile — so the
   app keeps its current instant feel.
3. **Migrations are additive** in `Backend/supabase_schema.sql` (numbered
   migration files from Phase 2 onward) so existing installs never break.
4. **Every phase ends with the two-device test**: two real accounts on two
   simulators/devices proving the loop works end to end.
