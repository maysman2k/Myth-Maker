# Bricks in a Bag Studio 🧱

**Brick news, kit reviews, a mosaic maker and custom build requests — the Bricks in a Bag app.**

Bricks in a Bag Studio is a native iOS app (SwiftUI, iOS 17+) built from the product spec in this repo's design history. It is an independent fan/custom-model brand app — not an official LEGO® app (LEGO® is a trademark of the LEGO Group, which does not sponsor, authorise or endorse this app).

## What's in the app

### Today
The daily home screen: rotating hero card, quick actions, latest news carousel, featured review and product, mosaic and Brick Bar prompts, a Studio Lesson, and trending discussions.

### News
- Editorial and AI-assisted articles across 13 categories (New Sets, Rumours, Official Reveals, Retiring Soon, Deals, Stadium Builds…).
- Rumours are visually labelled and carry a "not officially confirmed" notice.
- Every article lists its sources, and AI-assisted pieces are disclosed ("Drafted with AI assistance and reviewed by Bricks in a Bag before publishing").
- Like, bookmark, share, related stories and full threaded comments.

### Reviews
- Kit reviews for LEGO® and compatible brick brands (CaDA, BlueBrixx, …) with brand/category filters.
- 5-star rating breakdown (build experience, display value, parts, accuracy, value, fun), pros/cons, verdict labels.
- Signed-in builders can add their own star rating with "I own / I built this set" flags.

### Create
- **Mosaic Maker** — pick a photo, choose style, size (32/48/64 studs) and colour mode (full colour, limited, black & white, sepia); the app samples the photo into a stud grid, snaps every cell to a real brick palette and renders a studded preview with brick count, colour count and difficulty. Save designs or send them straight to The Brick Bar. Photos stay on-device.
- **Studio Lessons** — design lessons (stadium scaling, mosaic colour mapping, display tips, techniques) with difficulty levels, completion tracking and comments.

### Shop
Native product cards for Bricks in a Bag builds (stadiums, mosaics, gifts, limited runs) with detail pages, external Buy Now links, save/share, and "Ask About This Build" which pre-fills a Brick Bar request.

### The Brick Bar
- Guided multi-step custom build request: build type → idea + reference photos → size & budget range → deadline → contact → review. Every step validates before continuing.
- Requests are tracked in the user's profile with status, workshop notes and quotes.

### Community & accounts
- Guest browsing everywhere; sign-in required to comment, like, bookmark, rate, save designs or submit requests.
- Comments with 2-level threading, 15-minute edit window, likes, reporting (3 reports auto-hides pending review) and moderation pre-checks for flagged terms and links from new accounts.
- Notifications for replies, comment likes, Brick Bar updates and quotes.
- Global search across news, reviews, shop and lessons with recent-search history.

### Admin panel (in-app, role-gated)
- Dashboard stats, **AI Draft Queue** (drafts never publish without editor/admin approval — with relevance scores and risk notes), comment moderation, Brick Bar request management (status changes + sending quotes), and article/product status management.
- The queue is fed live by the **[AI news scanner](../NewsScanner/README.md)** — a scheduled GitHub Actions worker that checks the approved source list every 6 hours, has Claude write original drafts of relevant stories, and scrapes candidate images. The draft review screen shows the suggested images with a licence warning; the editor picks one (or the branded graphic) at approval, and the chosen image becomes the published article's hero image. Requires the `ANTHROPIC_API_KEY` repo secret — see the scanner README for setup.
- Demo accounts (password `bricks123`): `admin@bricksinabag.com`, `editor@bricksinabag.com`, `moderator@bricksinabag.com`, `jess@example.com`.

## Running it

Open `BrickStudio.xcodeproj` in **Xcode 16+** and run the `BrickStudio` scheme on an iOS 17+ simulator or device. There is no backend to configure — the app is local-first with seeded content (articles, reviews, products, lessons, AI drafts and comments) and persists everything as JSON in the app's Documents directory.

Tests: the `BrickStudioTests` target covers the critical logic — mosaic colour mapping and estimates, comment policy (edit window, thread depth, report threshold, moderation pre-checks), search ranking and scoping, Brick Bar step validation, and app-model rules (guest gating, like idempotency, AI drafts requiring human approval, auth).

## Architecture

```
BrickStudio/
  App/            Entry point, root tab navigation, toast + auth sheet
  Core/
    DesignSystem/ "Brick Studio" tokens (colours/fonts/spacing) + components,
                  procedural BrickArtView (no scraped images — spec §10.8)
    Services/     MosaicRenderer (CoreGraphics sampling + stud rendering), ImageStore
    Utilities/    Dates, read-time, slugs
  Domain/
    Models/       Articles, reviews, products, lessons, comments, mosaics,
                  Brick Bar requests, AI drafts, engagement records
    Logic/        MosaicEngine, CommentPolicy, SearchEngine, RequestValidator (pure, tested)
  Data/           AppModel (@Observable), actions, JSON persistence, seed content
  Features/       Today, News, Reviews, Create, Shop, BrickBar, Lessons,
                  Comments, Search, Notifications, Auth, Profile, Admin, Onboarding
```

The spec's backend (Supabase) is deliberately out of scope for this native build: the service layer lives in `AppModel`/`AppModel+Actions` so a real API can replace `LocalStore` later without touching the views.
