import type { FolderSeoEntry, KeywordSeoEntry, SeoManifest } from "./manifest-types";
import manifestJson from "../data/seo-manifest.json";

const manifest = manifestJson as SeoManifest;

export { manifest, type FolderSeoEntry, type KeywordSeoEntry, type SeoManifest };

const FOLDER_BASE = "/api/view/";

export function manifestFolderBySlug(slug: string): FolderSeoEntry | undefined {
  return manifest.folders[slug];
}

export function manifestKeywordBySlug(slug: string): KeywordSeoEntry | undefined {
  return manifest.keywords[slug];
}

export function viewRedirectUrl(encoded: string): string {
  return `${FOLDER_BASE}${encoded}`;
}