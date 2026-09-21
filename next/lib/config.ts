export const API_BASE = "https://iloveprepa-r2.ilovepreparatoire.workers.dev";

export const EMAIL_JS_SERVICE_ID = "iloveprepa";
export const EMAIL_JS_TEMPLATE_ID = "template_q8mygrz";
export const EMAIL_JS_PUBLIC_KEY = "aUr1ndO6jKpSWwcfq";

export const kD17Number = "25680686";

export function viewUrlFor(itemName: string): string {
  const base = /[^/]+$/.exec(itemName)?.[0] ?? itemName;
  return `${API_BASE}/api/view/${encodeURIComponent(base)}?f=${encodeURIComponent(itemName)}`;
}

export function downloadUrlFor(itemName: string): string {
  return `${API_BASE}/api/download?file=${encodeURIComponent(itemName)}&download=1`;
}