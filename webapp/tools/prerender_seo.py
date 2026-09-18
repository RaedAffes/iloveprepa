# -*- coding: utf-8 -*-
"""Bakes the SEO meta directly into per-folder / per-keyword static HTML.

Reads build/web/index.html + build/web/seo_meta.json (the latter is written
by generate_folder_meta.py into web/ and copied into the build by Flutter),
then writes one build/web/<slug>/index.html per keyword and folder URL:

  - title / description / og:title / og:description / og:url / canonical
  - keywords      -> https://iprepa.tn/<slug>/
  - folder URLs   -> <meta name="iloveprepa-folder" content="<real R2 path>">
                     so the Flutter app deep-links into the right folder

These static pages replicate exactly what functions/_middleware.js used to
serve (same applyMeta replacements), but they are plain CDN-cacheable assets:
Pages no longer runs a Function on any request.

Run AFTER `flutter build web` (and after the flutter_bootstrap.js engine
switch in deploy.bat); the app shell index.html is required as the template.
"""

import html
import json
import re
import sys
from pathlib import Path

BUILD_DIR = Path(__file__).resolve().parent.parent / "build" / "web"
SEO_META = "seo_meta.json"

_DESCRIPTION = re.compile(r'(<meta name="description" content=")[^"]*(")')
_OG_TITLE = re.compile(r'(<meta property="og:title" content=")[^"]*(")')
_OG_DESC = re.compile(r'(<meta property="og:description" content=")[^"]*(")')
_OG_URL = re.compile(r'(<meta property="og:url" content=")[^"]*(")')
_TITLE = re.compile(r"<title>[\s\S]*?</title>")

# Visually-hidden but real, crawlable content (standard sr-only pattern):
# non-JS crawlers (ChatGPT/Google) read the folder's documents straight from
# the static HTML; human eyes never see it — the Flutter app covers the page.
_DOC_CSS = (
    "\n      .seo-docs{position:absolute;width:1px;height:1px;margin:-1px;"
    "overflow:hidden;clip-path:inset(50%);white-space:nowrap}\n"
)


def _repl(left, right, value):
    return lambda m: m.group(1) + left + value + right + m.group(2)


def inject_docs(html_doc, docs, canonical):
    """Adds the folder's document list as plain HTML links + ItemList JSON-LD
    so search-engine and AI crawlers that don't run the Flutter app still see
    every file (title + direct view URL), as if the list were a normal page."""
    if not docs:
        return html_doc

    items = "\n            ".join(
        f'<li><a rel="nofollow" href="{d["url"]}">'
        f"{html.escape(d['title'], quote=True)}"
        "</a></li>"
        for d in docs
    )
    section = (
        '<div class="seo-docs">\n'
        "            <h2>Documents disponibles</h2>\n"
        "            <ul>\n            "
        + items
        + "\n            </ul>\n"
        "          </div>\n"
    )

    item_list = {
        "@context": "https://schema.org",
        "@type": "ItemList",
        "name": "Documents disponibles",
        "url": canonical,
        "itemListElement": [
            {
                "@type": "ListItem",
                "position": i + 1,
                "name": html.escape(d["title"], quote=True),
                "url": d["url"],
            }
            for i, d in enumerate(docs)
        ],
    }
    jsonld = (
        '<script type="application/ld+json">'
        + json.dumps(item_list, ensure_ascii=False)
        + "</script>\n"
    )

    if ".seo-docs" not in html_doc:
        html_doc = html_doc.replace("<style>", "<style>" + _DOC_CSS)

    html_doc = html_doc.replace("</head>", jsonld + "  </head>")
    return html_doc.replace(
        '<div id="boot-preview"', section + '  <div id="boot-preview"'
    )


def apply_meta(html_doc, title, desc, canonical):
    """Same replace(ment)s as functions/_middleware.js applyMeta()."""
    html_doc = _TITLE.sub(lambda _: "<title>" + title + "</title>", html_doc)
    html_doc = _DESCRIPTION.sub(_repl("", "", desc), html_doc)
    html_doc = _OG_TITLE.sub(_repl("", "", title), html_doc)
    html_doc = _OG_DESC.sub(_repl("", "", desc), html_doc)
    html_doc = _OG_URL.sub(_repl("", "", canonical), html_doc)
    if 'rel="canonical"' not in html_doc:
        html_doc = html_doc.replace(
            '<meta property="og:url" content="' + canonical + '">',
            '<meta property="og:url" content="' + canonical + '">'
            + '\n  <link rel="canonical" href="' + canonical + '">',
        )
    return html_doc


def main():
    build_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else BUILD_DIR
    index = build_dir / "index.html"
    seo_meta = build_dir / SEO_META
    if not index.exists():
        print(f"ERROR: no {index} - run flutter build web first.", file=sys.stderr)
        return 1
    if not seo_meta.exists():
        print(f"ERROR: no {seo_meta} - generate_folder_meta.py must run before the build.",
              file=sys.stderr)
        return 1

    html = index.read_text(encoding="utf-8")
    with open(seo_meta, encoding="utf-8") as f:
        meta = json.load(f)
    base = meta["canonicalBase"]

    out_root = build_dir
    written = 0
    for slug, entry in meta.get("keywords", {}).items():
        canonical = base + "/" + slug + "/"
        out = apply_meta(html, entry["title"], entry["desc"], canonical)
        path = out_root / slug / "index.html"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(out, encoding="utf-8")
        written += 1

    for slug, entry in meta.get("folders", {}).items():
        canonical = base + "/" + slug + "/"
        deep_link = '<meta name="iloveprepa-folder" content="' + entry["path"] + '">\n'
        out = apply_meta(html, entry["title"], entry["desc"], canonical)
        out = out.replace("</head>", deep_link + "</head>")
        out = inject_docs(out, entry.get("docs", []), canonical)
        path = out_root / slug / "index.html"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(out, encoding="utf-8")
        written += 1

    print(f"OK: prerendered {written} SEO pages under {out_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())