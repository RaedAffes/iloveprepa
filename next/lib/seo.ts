import { manifest } from "./manifest";

/**
 * Small SEO helpers shared by the folder pages (/[...fpath]) and the document
 * pages (/doc/...): canonical URLs are emitted without a trailing slash because
 * Next serves those (the slashed form answers 308), and every page gets a
 * breadcrumb trail for both the rendered markup and BreadcrumbList JSON-LD.
 */

const SLUG_BY_PATH = new Map(
  Object.entries(manifest.folders).map(([slug, folder]) => [folder.path, slug]),
);

export interface Crumb {
  name: string;
  /** Undefined when the item is the current page or has no page of its own. */
  url?: string;
}

/** "3. Chimie" -> "Chimie", matching the page titles generated for folders. */
export function segmentLabel(segment: string): string {
  return segment.replace(/^\s*\d+[.\-)]?\s*/, "").trim() || segment.trim();
}

/** App-relative URL of a folder page, or null when that folder has none. */
export function folderHref(path: string[]): string | null {
  const slug = SLUG_BY_PATH.get(path.join("/"));
  return slug ? `/${slug}` : null;
}

/** Absolute URL of a folder's page, or null when that folder has none. */
export function folderUrl(path: string[]): string | null {
  const href = folderHref(path);
  return href ? `${manifest.canonicalBase}${href}` : null;
}

/** Reverse lookup: URL pathname -> folder path segments (null when unknown). */
export function folderPathForHref(pathname: string): string[] | null {
  const slug = pathname.replace(/^\/+|\/+$/g, "");
  const path = SLUG_BY_PATH.get(slug);
  return path ? path.split("/") : null;
}

function encodePath(path: string[]): string {
  return path.map((segment) => encodeURIComponent(segment)).join("/");
}

/**
 * Next delivers dynamic-route segments still percent-encoded ("1.%20Math"),
 * while the Drive listing stores them decoded - normalise before comparing.
 */
export function decodePathSegments(segments: string[]): string[] {
  return segments.map((segment) => {
    try {
      return decodeURIComponent(segment);
    } catch {
      return segment;
    }
  });
}

/** Absolute URL of a document page. */
export function docUrl(path: string[]): string {
  return `${manifest.canonicalBase}/doc/${encodePath(path)}`;
}

/** App-relative version of the document URL, for internal links. */
export function docHref(path: string[]): string {
  return `/doc/${encodePath(path)}`;
}

/** Breadcrumb for a folder page: home, ancestors, then the folder itself. */
export function folderBreadcrumbs(path: string[]): Crumb[] {
  const crumbs: Crumb[] = [{ name: "iPrepa", url: `${manifest.canonicalBase}/` }];
  path.forEach((segment, index) => {
    const partial = path.slice(0, index + 1);
    const isCurrent = index === path.length - 1;
    crumbs.push({
      name: segmentLabel(segment),
      url: isCurrent ? undefined : folderUrl(partial) ?? undefined,
    });
  });
  return crumbs;
}

/** Breadcrumb for a document page: home, ancestor folders, then the file. */
export function documentBreadcrumbs(path: string[]): Crumb[] {
  const folders = path.slice(0, -1);
  const crumbs: Crumb[] = [{ name: "iPrepa", url: `${manifest.canonicalBase}/` }];
  folders.forEach((segment, index) => {
    crumbs.push({ name: segmentLabel(segment), url: folderUrl(path.slice(0, index + 1)) ?? undefined });
  });
  crumbs.push({ name: path[path.length - 1] });
  return crumbs;
}

/** BreadcrumbList structured data for a trail built above. */
export function breadcrumbJsonLd(crumbs: Crumb[]): Record<string, unknown> {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: crumbs.map((crumb, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: crumb.name,
      ...(crumb.url ? { item: crumb.url } : {}),
    })),
  };
}
