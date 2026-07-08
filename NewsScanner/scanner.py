#!/usr/bin/env python3
"""AI news scanner for Bricks in a Bag Studio.

Implements the spec's AI news workflow (section 10): check the approved
source list, detect new stories, score relevance, have Claude write an
original draft, and store everything in drafts.json for the app's admin
AI Draft Queue. Nothing here publishes anything — a human approves or
rejects every draft in the app.

Zero third-party dependencies: stdlib only, so it runs anywhere Python
3.10+ does (designed for the scheduled GitHub Actions workflow in
.github/workflows/news-scanner.yml).

Environment:
  ANTHROPIC_API_KEY   required — Claude API key
  SCANNER_MODEL       optional — defaults to claude-sonnet-5
  SCANNER_MAX_DRAFTS  optional — max new drafts per run (default 5)
"""

import html
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.abspath(__file__))
SOURCES_PATH = os.path.join(ROOT, "sources.json")
DRAFTS_PATH = os.path.join(ROOT, "drafts.json")
SEEN_PATH = os.path.join(ROOT, "seen.json")

API_URL = "https://api.anthropic.com/v1/messages"
API_VERSION = "2023-06-01"
MODEL = os.environ.get("SCANNER_MODEL", "claude-sonnet-5")
MAX_DRAFTS_PER_RUN = int(os.environ.get("SCANNER_MAX_DRAFTS", "5"))
MIN_RELEVANCE = 61  # spec section 10.4: draft-worthy threshold
# Bump when the drafting prompt changes materially so re-scanned stories get
# fresh IDs — the app never re-imports an ID it has already seen.
DRAFT_ID_VERSION = "v2"
MAX_STORED_DRAFTS = 50
MAX_SEEN_ENTRIES = 2000
MAX_ITEMS_PER_SOURCE = 10
USER_AGENT = "BricksInABagScanner/1.0 (+https://bricksinabag.com)"

# Must match ArticleCategory raw values in the iOS app.
CATEGORIES = [
    "New Sets", "Rumours", "Official Reveals", "Retiring Soon", "Deals",
    "Events", "Ideas", "Stadium Builds", "Brick Culture",
    "Bricks in a Bag Updates", "Compatible Brick Brands", "Collectors",
    "Display Builds",
]

PROMPT_TEMPLATE = """You are writing for Bricks in a Bag, an independent brick-building fan and custom model brand.

Write an original, mobile-first news article based only on the provided source notes and links.

Voice - this matters as much as the facts:
- Fun, excitable and a little cheeky: write like a builder mate who just heard the news and can't wait to tell you, not like a press office.
- Short punchy sentences. The odd exclamation. A wry aside or brick pun is welcome (one or two, not a panto script).
- Talk TO the reader ("you", "your shelf", "your wallet").
- Never stiff phrases like "It is worth noting" or "This announcement confirms". Never corporate filler.
- Cheeky is fine; clickbait, sarcasm at fans' expense, or made-up hype is not.

Accuracy rules:
- Do not copy source wording.
- Do not invent facts.
- INCLUDE THE CONCRETE DETAILS FANS ACTUALLY WANT: set names, set numbers, piece counts, prices, minifigure counts and release dates - whenever the source text provides them, list them (a short markdown bullet list is perfect). Only say "details to come" if the source genuinely doesn't have them.
- Clearly label rumours.
- Mention when something is official only if the source confirms it.
- Include a short "Why it matters" section.
- Use UK English.
- Do not imply Bricks in a Bag is affiliated with LEGO Group.

First score the story's relevance from 0-100 for a UK audience of brick fans, collectors, stadium-build fans and custom model customers (LEGO set news, compatible brick brands, stadium/model building, collecting, display and building techniques all score highly; generic toy-industry or off-topic news scores low).

Return ONLY a JSON object, no other text, with exactly these keys:
{{
  "relevanceScore": <integer 0-100>,
  "title": "<headline, no clickbait>",
  "summary": "<1-2 sentence standfirst>",
  "bodyMarkdown": "<article body using '## What happened', '## Why it matters' and optionally '## What to watch next' sections. Do NOT include a Sources section - the app renders sources separately.>",
  "category": <one of {categories}>,
  "tags": ["<3-5 kebab-case tags>"],
  "isRumour": <true|false>,
  "riskNotes": "<one or two sentences: anything an editor should verify before approving>"
}}

Source name: {source_name}
Story title: {story_title}
Story link: {story_link}
Feed summary: {story_summary}

Page text excerpt (may be messy):
{page_text}
"""


def log(message):
    print(f"[scanner] {message}", flush=True)


def fetch_bytes(url, timeout=20):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def load_json(path, fallback):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return fallback


def save_json(path, payload):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def strip_html(text):
    text = re.sub(r"<script[\s\S]*?</script>", " ", text, flags=re.I)
    text = re.sub(r"<style[\s\S]*?</style>", " ", text, flags=re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def local_name(tag):
    return tag.rsplit("}", 1)[-1].lower()


def parse_feed(xml_bytes):
    """Parse RSS 2.0 or Atom into a list of story dicts."""
    items = []
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return items

    def child_text(node, *names):
        for candidate in node:
            if local_name(candidate.tag) in names and candidate.text:
                return candidate.text.strip()
        return ""

    def feed_image(node):
        for candidate in node:
            name = local_name(candidate.tag)
            if name in ("content", "thumbnail", "enclosure"):
                url = candidate.get("url") or candidate.get("href") or ""
                mime = candidate.get("type", "")
                if url and (name != "enclosure" or mime.startswith("image")):
                    return url
        return ""

    for node in root.iter():
        name = local_name(node.tag)
        if name not in ("item", "entry"):
            continue
        title = child_text(node, "title")
        link = child_text(node, "link")
        if not link:  # Atom links live in href attributes
            for candidate in node:
                if local_name(candidate.tag) == "link" and candidate.get("href"):
                    if candidate.get("rel") in (None, "alternate"):
                        link = candidate.get("href")
                        break
        summary = strip_html(child_text(node, "description", "summary", "content"))
        if title and link:
            items.append({
                "title": title,
                "link": link,
                "summary": summary[:600],
                "image": feed_image(node),
            })
    return items


META_IMAGE_PATTERNS = [
    r'<meta[^>]+(?:property|name)=["\'](?:og:image|twitter:image)["\'][^>]+content=["\']([^"\']+)["\']',
    r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\'](?:og:image|twitter:image)["\']',
]

IMG_TAG_PATTERN = r'<img[^>]+src=["\'](https?://[^"\']+)["\']'
IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")
IMAGE_URL_STOPWORDS = ("logo", "icon", "avatar", "badge", "banner-ad", "sprite",
                       "placeholder", "gravatar", "emoji", "button", "pixel")
MAX_IMAGES_PER_DRAFT = 6
PAGE_TEXT_LIMIT = 6000


def looks_like_content_image(url):
    lowered = url.lower()
    path = lowered.split("?", 1)[0]
    if not path.endswith(IMAGE_EXTENSIONS):
        return False
    return not any(word in lowered for word in IMAGE_URL_STOPWORDS)


def scrape_page(url):
    """Return (text_excerpt, image_urls) from the story page.

    Prefers the <article> element's text so Claude sees the actual story
    (set numbers, prices, dates) rather than navigation and boilerplate.
    Collects social-meta images first, then in-content <img> photos.
    """
    try:
        raw = fetch_bytes(url).decode("utf-8", errors="replace")
    except Exception as error:  # noqa: BLE001 - any fetch failure just means no page data
        log(f"  page fetch failed for {url}: {error}")
        return "", []

    images = []
    for pattern in META_IMAGE_PATTERNS:
        for match in re.findall(pattern, raw, flags=re.I):
            if match.startswith("http") and match not in images:
                images.append(match)

    # Scope text and inline images to the article body when the page has one.
    article_match = re.search(r"<article[\s\S]*?</article>", raw, flags=re.I)
    content_html = article_match.group(0) if article_match else raw
    for match in re.findall(IMG_TAG_PATTERN, content_html, flags=re.I):
        if match not in images and looks_like_content_image(match):
            images.append(match)

    return strip_html(content_html)[:PAGE_TEXT_LIMIT], images[:MAX_IMAGES_PER_DRAFT]


def call_claude(prompt):
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    payload = json.dumps({
        "model": MODEL,
        "max_tokens": 2500,
        "messages": [{"role": "user", "content": prompt}],
    }).encode("utf-8")
    request = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": API_VERSION,
        },
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        body = json.loads(response.read())
    text = "".join(block.get("text", "") for block in body.get("content", []))
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("no JSON object in model response")
    return json.loads(text[start:end + 1])


def normalise_title(title):
    return set(re.sub(r"[^a-z0-9 ]", "", title.lower()).split())


def is_duplicate_title(title, existing_titles):
    tokens = normalise_title(title)
    if not tokens:
        return False
    for existing in existing_titles:
        other = normalise_title(existing)
        if not other:
            continue
        overlap = len(tokens & other) / len(tokens | other)
        if overlap > 0.6:
            return True
    return False


def build_draft(result, story, source, images):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    category = result.get("category", "")
    if category not in CATEGORIES:
        category = "Brick Culture"
    risk_notes = str(result.get("riskNotes", "")).strip()
    if images:
        risk_notes = (risk_notes + " " if risk_notes else "") + (
            "Suggested images were scraped from the source page - licence unknown; "
            "check rights before publishing with an image (spec 10.8)."
        )
    return {
        "id": str(uuid.uuid5(uuid.NAMESPACE_URL, story["link"] + "#" + DRAFT_ID_VERSION)),
        "title": str(result.get("title", story["title"]))[:200],
        "summary": str(result.get("summary", ""))[:500],
        "bodyMarkdown": str(result.get("bodyMarkdown", "")),
        "category": category,
        "tags": [str(t)[:40] for t in result.get("tags", [])][:6],
        "sourceLinks": [{
            "id": str(uuid.uuid5(uuid.NAMESPACE_URL, story["link"] + "#source")),
            "name": source["name"],
            "url": story["link"],
        }],
        "isRumour": bool(result.get("isRumour", False)),
        "relevanceScore": max(0, min(100, int(result.get("relevanceScore", 0)))),
        "riskNotes": risk_notes or "Automated draft - verify facts and sources before approving.",
        "status": "needs_review",
        "foundAt": now,
        "suggestedImageURLs": images,
    }


def main():
    if not os.environ.get("ANTHROPIC_API_KEY"):
        log("ANTHROPIC_API_KEY is not set - add it as a repository secret.")
        return 1

    sources = load_json(SOURCES_PATH, [])
    drafts = load_json(DRAFTS_PATH, [])
    seen = load_json(SEEN_PATH, {})
    existing_titles = [d.get("title", "") for d in drafts]
    existing_ids = {d.get("id") for d in drafts}
    created = 0

    for source in sources:
        if not source.get("enabled", True):
            continue
        if created >= MAX_DRAFTS_PER_RUN:
            break
        log(f"checking {source['name']} ({source['rssUrl']})")
        try:
            stories = parse_feed(fetch_bytes(source["rssUrl"]))
        except Exception as error:  # noqa: BLE001 - a broken feed must not kill the run
            log(f"  feed failed: {error}")
            continue

        for story in stories[:MAX_ITEMS_PER_SOURCE]:
            if created >= MAX_DRAFTS_PER_RUN:
                break
            link = story["link"]
            if link in seen:
                continue
            draft_id = str(uuid.uuid5(uuid.NAMESPACE_URL, link + "#" + DRAFT_ID_VERSION))
            if draft_id in existing_ids or is_duplicate_title(story["title"], existing_titles):
                seen[link] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                continue

            page_text, page_images = scrape_page(link)
            images = []
            for candidate in [story.get("image", "")] + page_images:
                if candidate and candidate.startswith("http") and candidate not in images:
                    images.append(candidate)
            prompt = PROMPT_TEMPLATE.format(
                categories=json.dumps(CATEGORIES),
                source_name=source["name"],
                story_title=story["title"],
                story_link=link,
                story_summary=story["summary"] or "(no feed summary)",
                page_text=page_text or "(page text unavailable - draft from the feed summary only)",
            )
            try:
                result = call_claude(prompt)
            except Exception as error:  # noqa: BLE001 - skip the story, keep the run alive
                log(f"  draft failed for '{story['title']}': {error}")
                continue

            seen[link] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            score = int(result.get("relevanceScore", 0))
            if score < MIN_RELEVANCE:
                log(f"  skipped (relevance {score}): {story['title']}")
                continue

            draft = build_draft(result, story, source, images[:MAX_IMAGES_PER_DRAFT])
            drafts.append(draft)
            existing_titles.append(draft["title"])
            existing_ids.add(draft["id"])
            created += 1
            log(f"  drafted (relevance {score}): {draft['title']}")

    drafts.sort(key=lambda d: d.get("foundAt", ""), reverse=True)
    save_json(DRAFTS_PATH, drafts[:MAX_STORED_DRAFTS])
    if len(seen) > MAX_SEEN_ENTRIES:
        seen = dict(sorted(seen.items(), key=lambda kv: kv[1], reverse=True)[:MAX_SEEN_ENTRIES])
    save_json(SEEN_PATH, seen)
    log(f"done - {created} new draft(s), {len(drafts[:MAX_STORED_DRAFTS])} in feed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
