# AI News Scanner

The backend half of the spec's AI news workflow (§10): a scheduled worker
that checks the approved source list, has Claude write **original** drafts
of relevant stories (with relevance scoring, rumour labelling and risk
notes), scrapes candidate images from the source pages, and publishes
everything to `drafts.json`. The iOS app's **admin AI Draft Queue** fetches
that feed — a human approves or rejects every draft before it ever reaches
readers. Nothing auto-publishes.

## How it works

```
sources.json ──▶ scanner.py ──▶ Claude API ──▶ drafts.json ──▶ app AI Draft Queue
 (your feeds)    every 6 hrs    (rewrite +      (committed      (editor approves,
                 via Actions     score)          to repo)        picks image, publishes)
```

- **Relevance gate** — Claude scores each story 0–100; only ≥61
  ("draft-worthy" per §10.4) becomes a draft. Everything checked is
  remembered in `seen.json` so stories are never processed twice.
- **Duplicate detection** — URL matching plus title-similarity against
  existing drafts (§10.5).
- **Images** — the scanner collects the feed's media image and the story
  page's `og:image`/`twitter:image` URLs as *suggestions*. Every draft
  with scraped images carries a licence warning in its risk notes; the
  editor chooses an image (or the branded graphic) at approval time.
- **Cost control** — max 5 new drafts per run (`SCANNER_MAX_DRAFTS`), one
  Claude call per candidate story, feed capped at the latest 50 drafts.

## Setup (one-time)

1. **Add the API key**: repo → Settings → Secrets and variables → Actions →
   *New repository secret* → name `ANTHROPIC_API_KEY`, value from
   https://console.anthropic.com/.
2. **Merge to `main`** — GitHub only runs scheduled workflows from the
   default branch.
3. That's it. It runs every 6 hours; you can also trigger it manually from
   the Actions tab → *AI News Scanner* → *Run workflow*.

## Managing sources

The easiest way: in the app, **Admin panel → News Sources** — list, edit,
pause, add and remove sources; changes commit straight back to this file
on `main` and apply from the next scan. This needs the in-app GitHub
token to have **Contents: Read and write** as well as **Actions: Read
and write** (Admin panel → GitHub connection has step-by-step setup and
a Test Connection button).

You can also edit `sources.json` by hand — each entry has `name`,
`rssUrl`, `enabled` and `notes`. Set `"enabled": false` to pause a
source. The scanner needs an RSS/Atom feed URL, not a homepage; if a
feed errors in the Actions log, correct its URL (the scanner skips
broken feeds without failing the run).

## Running locally

```bash
export ANTHROPIC_API_KEY=sk-ant-...
python3 NewsScanner/scanner.py
```

Python 3.10+, no dependencies to install. Optional env vars:
`SCANNER_MODEL` (default `claude-sonnet-5`), `SCANNER_MAX_DRAFTS`
(default `5`).

## The app side

`BrickStudio/Core/Services/DraftFeedService.swift` fetches the raw
`drafts.json` from GitHub. The admin **AI Draft Queue** pulls it on open
(and on pull-to-refresh), merging only unseen drafts — approved and
rejected drafts never reappear. On the draft review screen the editor sees
the suggested images with the licence warning and picks one (or none)
before approving; the chosen image becomes the published article's hero
image.
