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


def _repl(left, right, value):
    return lambda m: m.group(1) + left + value + right + m.group(2)


def apply_meta(html, title, desc, canonical):
    """Same replace(ment)s as functions/_middleware.js applyMeta()."""
    html = _TITLE.sub(lambda _: "<title>" + title + "</title>", html)
    html = _DESCRIPTION.sub(_repl("", "", desc), html)
    html = _OG_TITLE.sub(_repl("", "", title), html)
    html = _OG_DESC.sub(_repl("", "", desc), html)
    html = _OG_URL.sub(_repl("", "", canonical), html)
    if 'rel="canonical"' not in html:
        html = html.replace(
            '<meta property="og:url" content="' + canonical + '">',
            '<meta property="og:url" content="' + canonical + '">'
            + '\n  <link rel="canonical" href="' + canonical + '">',
        )
    return html


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
        path = out_root / slug / "index.html"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(out, encoding="utf-8")
        written += 1

    print(f"OK: prerendered {written} SEO pages under {out_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())