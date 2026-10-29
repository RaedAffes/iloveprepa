#!/usr/bin/env node
/**
 * Crawls the public Google Drive folder and writes ../data/drive-tree.json.
 *
 * The folder is shared publicly, so no API key is needed: each folder is read
 * from Drive's embedded folder view, which returns plain HTML listing the
 * entries (name, type, last modified, file id).
 *
 * Usage: node scripts/gen-drive.mjs
 */

import { writeFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT_FOLDER_ID = "1hf4Gr4ykqOmLovlYsb6C_IiC7NODN5sS";
const CONCURRENCY = 6;
const MAX_DEPTH = 16;
const MAX_RETRIES = 3;

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT_FILE = join(HERE, "..", "data", "drive-tree.json");

function decodeEntities(text) {
  return text
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(parseInt(code, 16)));
}

function cleanText(html) {
  return decodeEntities(html.replace(/<[^>]*>/g, "")).replace(/\s+/g, " ").trim();
}

function fileIdFromHref(href) {
  if (!href) return null;
  const folder = /\/folders\/([A-Za-z0-9_-]{20,})/.exec(href);
  if (folder) return folder[1];
  const file = /\/file\/d\/([A-Za-z0-9_-]{20,})/.exec(href);
  if (file) return file[1];
  const open = /[?&]id=([A-Za-z0-9_-]{20,})/.exec(href);
  if (open) return open[1];
  return null;
}

/** Returns [{ id, name, kind: "folder" | "file", modified }] for one folder page. */
function parseFolderHtml(html) {
  const blocks = html.split('<div class="flip-entry"').slice(1);
  const entries = [];
  for (const block of blocks) {
    const href = (/href="([^"]+)"/.exec(block) || [])[1] ?? "";
    const id = fileIdFromHref(href);
    const name = (/flip-entry-title">([\s\S]*?)<\/div>/.exec(block) || [])[1];
    if (!id || name == null) continue;
    const modified = (/flip-entry-last-modified"><div>([\s\S]*?)<\/div>/.exec(block) || [])[1];
    entries.push({
      id,
      name: cleanText(name),
      kind: href.includes("/folders/") ? "folder" : "file",
      modified: modified ? cleanText(modified) : "",
    });
  }
  return entries;
}

async function fetchFolderPage(folderId) {
  const url = `https://drive.google.com/embeddedfolderview?id=${encodeURIComponent(folderId)}`;
  let lastError;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(url, {
        headers: { "accept-language": "en" },
        signal: AbortSignal.timeout(20000),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.text();
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 500 * attempt));
    }
  }
  throw new Error(`folder ${folderId}: ${lastError?.message ?? "unknown error"}`);
}

async function walk(rootId) {
  const files = [];
  const folders = [];
  const failed = [];
  const queue = [{ id: rootId, path: [], depth: 0 }];
  let active = 0;

  await new Promise((resolve) => {
    const pump = () => {
      if (queue.length === 0 && active === 0) {
        resolve();
        return;
      }
      while (active < CONCURRENCY && queue.length > 0) {
        const job = queue.shift();
        active++;
        fetchFolderPage(job.id)
          .then((html) => {
            const entries = parseFolderHtml(html);
            folders.push({ id: job.id, path: job.path, name: job.path[job.path.length - 1] ?? "" });
            for (const entry of entries) {
              if (entry.kind === "folder") {
                if (job.depth + 1 > MAX_DEPTH) {
                  failed.push({ id: entry.id, path: [...job.path, entry.name], reason: "max depth" });
                } else {
                  queue.push({ id: entry.id, path: [...job.path, entry.name], depth: job.depth + 1 });
                }
              } else {
                files.push({
                  id: entry.id,
                  path: [...job.path, entry.name],
                  modified: entry.modified,
                });
              }
            }
          })
          .catch((error) => {
            failed.push({ id: job.id, path: job.path, reason: error.message });
          })
          .finally(() => {
            active--;
            pump();
          });
      }
    };
    pump();
  });

  return { files, folders, failed };
}

const started = Date.now();
const { files, folders, failed } = await walk(ROOT_FOLDER_ID);

files.sort((a, b) => a.path.join("/").localeCompare(b.path.join("/"), undefined, { numeric: true }));

const payload = {
  folderId: ROOT_FOLDER_ID,
  generatedAt: new Date().toISOString(),
  stats: {
    folders: folders.length,
    files: files.length,
    failed: failed.length,
  },
  failed: failed.slice(0, 50),
  files,
};

await mkdir(dirname(OUT_FILE), { recursive: true });
await writeFile(OUT_FILE, JSON.stringify(payload), "utf8");

console.log(
  `drive-tree.json: ${payload.stats.files} files in ${payload.stats.folders} folders ` +
    `(${payload.stats.failed} failed) -> ${OUT_FILE} [${((Date.now() - started) / 1000).toFixed(1)}s]`,
);
if (payload.stats.failed > 0) {
  console.log("failed folders:", JSON.stringify(payload.failed.slice(0, 5), null, 2));
  process.exitCode = 1;
}
