import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const NEXT_ROOT = path.resolve(__dirname, "..");
const DATA_DIR = path.join(NEXT_ROOT, "data");
const SEO_MANIFEST = path.join(DATA_DIR, "seo-manifest.json");
const KEYWORD_META = path.join(DATA_DIR, "keyword_meta.json");

const API_URL = "https://iloveprepa-r2.ilovepreparatoire.workers.dev/api/files";
const VIEW_BASE = "https://iprepa.tn/view/";
const DESC_LIMIT = 150;

const TOP_SLUG_MAP = {
  "1. Math": "mathematiques",
  "2. Physique": "physique",
  "3. Chimie": "chimie",
  "4. Informatique": "informatique",
  "5. STA": "sta",
  "6. Langues": "langues",
  Resumes: "resumes",
};

function slugify(segment, isTop) {
  const seg = String(segment).trim();
  if (isTop && TOP_SLUG_MAP[seg]) return TOP_SLUG_MAP[seg];
  let s = seg.toLowerCase().replace(/&/g, " et ");
  s = s.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  s = s.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  return s || "dossier";
}

function cleanLabel(name) {
  const label = String(name).replace(/^\s*\d+[.\-)]?\s*/, "").trim();
  return label || String(name).trim();
}

function displayName(raw) {
  let base = String(raw).split("/").pop();
  const dot = base.lastIndexOf(".");
  if (dot > 0) base = base.slice(0, dot);
  base = base.replace(/[-_]+/g, " ");
  base = base.replace(/\s+/g, " ").trim();
  return base;
}

class Folder {
  constructor(name) {
    this.name = name;
    this.files = [];
    this.children = new Map();
  }

  get hasContent() {
    return this.files.length > 0 || [...this.children.values()].some((c) => c.hasContent);
  }

  forge(parts, isFolder) {
    const segs = isFolder ? parts : parts.slice(0, -1);
    const [head, ...tail] = segs;
    if (head === undefined) return;
    const child = this.children.get(head) ?? new Folder(head);
    this.children.set(head, child);
    if (tail.length > 0) {
      child.forge(tail, isFolder);
    } else if (!isFolder) {
      child.files.push(parts[parts.length - 1]);
    }
  }

  *walk(prefix = []) {
    for (const [name, child] of this.children) {
      const p = [...prefix, name];
      yield [p, child];
      yield* child.walk(p);
    }
  }
}

function buildTree(keys) {
  const root = new Folder("Library");
  for (const raw of keys) {
    const r = String(raw).trim();
    if (!r) continue;
    const isFolder = r.endsWith("/");
    const parts = r.split("/").map((s) => s.trim()).filter(Boolean);
    if (parts.length) root.forge(parts, isFolder);
  }
  return root;
}

function buildDesc(node) {
  const items = [];
  const children = [...node.children.values()].sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
  for (const child of children) items.push(cleanLabel(child.name));
  const files = [];
  for (const raw of node.files) {
    const d = displayName(raw);
    if (d) files.push(d);
  }
  files.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
  items.push(...files);
  const seen = new Set();
  const unique = [];
  for (const item of items) {
    const key = item.toLowerCase();
    if (item && !seen.has(key)) {
      seen.add(key);
      unique.push(item);
    }
  }
  let text = unique.join(", ");
  if (text.length > DESC_LIMIT) {
    const cut = text.slice(0, DESC_LIMIT);
    const idx = cut.lastIndexOf(",");
    if (idx > 60) text = cut.slice(0, idx) + ", ...";
    else text = cut.replace(/[ ,]+$/, "") + "...";
  }
  return text;
}

function docLinks(node, prefix) {
  const rootKey = prefix.join("/");
  const docs = [];
  const sorted = [...node.files].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
  for (const raw of sorted) {
    const title = displayName(raw);
    if (!title) continue;
    const key = rootKey ? `${rootKey}/${raw}` : raw;
    docs.push({ title, url: VIEW_BASE + encodeURIComponent(key) });
  }
  return docs;
}

async function fetchKeys() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 30000);
  try {
    const res = await fetch(API_URL, {
      signal: controller.signal,
      headers: {
        "User-Agent": "Mozilla/5.0 (IlovePrepa deploy builder)",
        Accept: "application/json",
      },
    });
    const data = await res.json();
    const keys = (data.files || [])
      .map((f) => (f && typeof f.name === "string" ? f.name : ""))
      .filter((n) => n);
    if (!keys.length || !keys.some((k) => !k.trim().endsWith("/"))) {
      throw new Error("empty listing");
    }
    return keys;
  } catch (e) {
    console.warn("WARN: API unreachable - keeping previous generated files.");
    console.warn(`      (${e.message || e})`);
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function generate() {
  console.log("Fetching R2 listing...");
  const keys = await fetchKeys();
  if (keys === null) return 0;

  const root = buildTree(keys);
  const slugs = new Set();
  const entries = {};

  const contentNodes = [...root.walk()]
    .filter(([, node]) => node.hasContent)
    .sort((a, b) => (a[0].join("/") < b[0].join("/") ? -1 : 1));

  console.log(`Building slugs for ${contentNodes.length} folders...`);
  for (const [pathArr, node] of contentNodes) {
    const segs = pathArr.map((seg, i) => slugify(seg, i === 0));
    let slug = segs.join("/");
    const base = slug;
    let n = 2;
    while (slugs.has(slug)) slug = `${base}-${n++}`;
    slugs.add(slug);
    entries[slug] = {
      title: cleanLabel(pathArr[pathArr.length - 1]),
      desc: buildDesc(node),
      path: pathArr.join("/"),
      docs: docLinks(node, pathArr),
    };
  }

  const kwMeta = JSON.parse(fs.readFileSync(KEYWORD_META, "utf8"));
  const payload = {
    canonicalBase: "https://iprepa.tn",
    keywords: Object.fromEntries(
      Object.keys(kwMeta)
        .sort()
        .map((slug) => [slug, { title: kwMeta[slug].title, desc: kwMeta[slug].desc }]),
    ),
    folders: Object.fromEntries(Object.keys(entries).sort().map((slug) => [slug, entries[slug]])),
  };
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(SEO_MANIFEST, JSON.stringify(payload, null, 1));
  console.log(`OK: data/seo-manifest.json (${Object.keys(payload.keywords).length} keywords + ${Object.keys(payload.folders).length} folders)`);
  return 0;
}

process.exitCode = await generate();