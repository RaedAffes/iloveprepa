# -*- coding: utf-8 -*-
"""Builds the folder SEO map + sitemap for IlovePrepa.

Reads the live R2 listing (/api/files), rebuilds the exact same tree the
Dart app builds (see buildLibraryTree in lib/models/library_folder.dart),
then writes:
  - webapp/functions/folder_meta.js  ES module: URL slug -> {title, desc, path}
  - webapp/web/sitemap.xml           root + 47 keyword URLs + every folder URL

Each folder URL gets:
  - title  = the folder's own name (the text after the last "/")
  - desc   = the real content of the folder (sub-folder names + file names)
  - path   = the real R2 folder path (used by the app for deep-linking)

If the API is unreachable the previous generated files are kept untouched,
so a downtime never breaks a deploy.
"""

import html
import json
import re
import sys
import unicodedata
import urllib.request
from datetime import date
from pathlib import Path

API_URL = "https://iloveprepa-r2.ilovepreparatoire.workers.dev/api/files"
WEBAPP = Path(__file__).resolve().parent.parent
FUNCTIONS_DIR = WEBAPP / "functions"
WEB_DIR = WEBAPP / "web"
JS_OUT = FUNCTIONS_DIR / "folder_meta.js"
SITEMAP_OUT = WEB_DIR / "sitemap.xml"
ROUTES_OUT = WEB_DIR / "folder_routes.json"
REDIRECTS = WEB_DIR / "_redirects"

# Explicit top-level folder names -> clean SEO slug ("1. Math" is ugly as an URL).
TOP_SLUG_MAP = {
    "1. Math": "mathematiques",
    "2. Physique": "physique",
    "3. Chimie": "chimie",
    "4. Informatique": "informatique",
    "5. STA": "sta",
    "6. Langues": "langues",
    "Resumes": "resumes",
}

# Any plural/accent variants of the 7 roots ("Résumés", "Math", ...).
_ROOT_ALIASES = {
    "Mathematiques": "mathematiques",
    "Mathematique": "mathematiques",
    "Math": "mathematiques",
    "Physique": "physique",
    "Chimie": "chimie",
    "Informatique": "informatique",
    "STA": "sta",
    "Langues": "langues",
    "Langue": "langues",
    "Resumes": "resumes",
    "Résumés": "resumes",
    "Résumé": "resumes",
}

DESC_LIMIT = 150


def fetch_keys():
    try:
        req = urllib.request.Request(
            API_URL,
            headers={
                "User-Agent": "Mozilla/5.0 (IlovePrepa deploy builder)",
                "Accept": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.load(r)
        keys = [f.get("name", "") for f in data.get("files", []) if f.get("name")]
        if not keys or not any(not k.strip().endswith("/") for k in keys):
            raise ValueError("empty listing")
        return keys
    except Exception as e:
        print("WARN: API unreachable - keeping previous generated files.", file=sys.stderr)
        print(f"      ({e})", file=sys.stderr)
        return None


class Folder:
    def __init__(self, name):
        self.name = name
        self.files = []
        self.children = {}

    @property
    def has_content(self):
        return self.files or any(c.has_content for c in self.children.values())

    def forge(self, parts, is_folder):
        node = self
        segs = parts if is_folder else parts[:-1]
        for seg in segs:
            node = node.children.setdefault(seg, Folder(seg))
        if not is_folder:
            node.files.append(parts[-1])

    def walk(self, prefix=()):
        for name, child in self.children.items():
            path = prefix + (name,)
            yield path, child
            yield from child.walk(path)


def build_tree(keys):
    root = Folder("Library")
    for raw in keys:
        raw = raw.strip()
        if not raw:
            continue
        is_folder = raw.endswith("/")
        parts = [p.strip() for p in raw.split("/") if p.strip()]
        if parts:
            root.forge(parts, is_folder)
    return root


def slugify(segment, is_top):
    seg = segment.strip()
    if is_top and seg in TOP_SLUG_MAP:
        return TOP_SLUG_MAP[seg]
    s = seg.lower().replace("&", " et ")
    s = "".join(
        ch for ch in unicodedata.normalize("NFD", s)
        if unicodedata.category(ch) != "Mn"
    )
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s or "dossier"


def clean_label(name):
    label = re.sub(r"^\s*\d+[\.\-)]?\s*", "", name).strip()
    return label or name.strip()


def display_name(raw):
    base = raw.split("/")[-1]
    dot = base.rfind(".")
    if dot > 0:
        base = base[:dot]
    base = re.sub(r"[-_]+", " ", base)
    base = re.sub(r"\s+", " ", base).strip()
    return base


def build_desc(node):
    items = []
    children = sorted(node.children.values(), key=lambda c: c.name.lower())
    for child in children:
        items.append(clean_label(child.name))
    files = []
    for raw in node.files:
        d = display_name(raw)
        if d:
            files.append(d)
    items.extend(sorted(files, key=str.lower))
    seen = set()
    unique = []
    for item in items:
        key = item.lower()
        if item and key not in seen:
            seen.add(key)
            unique.append(item)
    text = ", ".join(unique)
    if len(text) > DESC_LIMIT:
        cut = text[:DESC_LIMIT]
        idx = cut.rfind(",")
        if idx > 60:
            text = cut[:idx] + ", ..."
        else:
            text = cut.rstrip(" ,") + "..."
    return text


def keyword_slugs():
    slugs = []
    if REDIRECTS.exists():
        for line in REDIRECTS.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                parts = line.split()
                if len(parts) >= 2 and parts[1] == "/":
                    slugs.append(parts[0].strip("/"))
    return slugs


def generate():
    print("Fetching R2 listing...")
    keys = fetch_keys()
    if keys is None:
        return 1
    root = build_tree(keys)

    slugs = set()
    entries = {}
    raw_paths = []

    nodes = list(root.walk())
    content_nodes = [(path, node) for path, node in nodes if node.has_content]
    content_nodes.sort(key=lambda pn: pn[0])

    print(f"Building slugs for {len(content_nodes)} folders...")
    routes = []
    for path, node in content_nodes:
        segs = []
        for i, seg in enumerate(path):
            segs.append(slugify(seg, is_top=(i == 0)))
        slug = "/".join(segs)
        base, n = slug, 2
        while slug in slugs:
            slug = f"{base}-{n}"
            n += 1
        slugs.add(slug)
        real = "/".join(path)
        entries[slug] = {
            "title": html.escape(clean_label(path[-1]), quote=True),
            "desc": html.escape(build_desc(node), quote=True),
            "path": html.escape(real, quote=True),
        }
        routes.append({"path": real, "slug": slug})
        raw_paths.append(path)

    js = [
        "// AUTO-GENERATED by tools/generate_folder_meta.py - do not edit.",
        "// Rebuilt on every deploy. Maps URL slug -> folder name (title),",
        "// real content (description) and the real R2 folder path.",
        "export const FOLDER_META = {",
    ]
    for slug in sorted(entries):
        js.append(f"  {json.dumps(slug)}: {json.dumps(entries[slug], ensure_ascii=False)},")
    js.append("};")
    js.append(f"export const FOLDER_COUNT = {len(entries)};")
    FUNCTIONS_DIR.mkdir(parents=True, exist_ok=True)
    JS_OUT.write_text("\n".join(js) + "\n", encoding="utf-8")
    print(f"OK: {JS_OUT.relative_to(WEBAPP)} ({len(entries)} folders)")

    ROUTES_OUT.write_text(
        json.dumps({"routes": routes}, ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"OK: {ROUTES_OUT.relative_to(WEBAPP)} ({len(routes)} path->slug routes)")

    kw = keyword_slugs()
    today = date.today().isoformat()
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    for url, priority in [("https://iprepa.tn/", "1.0")] + [
        (f"https://iprepa.tn/{s}/", "0.7") for s in kw
    ] + [(f"https://iprepa.tn/{s}/", "0.6") for s in sorted(entries)]:
        lines.append("  <url>")
        lines.append(f"    <loc>{url}</loc>")
        lines.append(f"    <lastmod>{today}</lastmod>")
        lines.append("    <changefreq>weekly</changefreq>")
        lines.append(f"    <priority>{priority}</priority>")
        lines.append("  </url>")
    lines.append("</urlset>")
    SITEMAP_OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"OK: {SITEMAP_OUT.relative_to(WEBAPP)} "
          f"({1 + len(kw) + len(entries)} URLs: 1 root + {len(kw)} keywords + {len(entries)} folders)")

    for slug in ["mathematiques/mme-nedra-moalla", "mathematiques", "physique/td-ipeiem"]:
        if slug in entries:
            e = entries[slug]
            print(f'SAMPLE {slug}: title="{e["title"]}" desc="{e["desc"][:80]}..." path="{e["path"]}"')
    return 0


if __name__ == "__main__":
    raise SystemExit(generate())