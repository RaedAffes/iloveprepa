import { userFromRequest } from './auth.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

// Each bought semester reads one private bucket. Bindings use underscores;
// the R2 names are mp1-s1, mp1-s2, mp2-s1 and mp2-s2. The label is the folder
// the app shows.
const SEMESTER_BUCKETS = {
  y1_s1: { binding: 'mp1_s1', label: 'MP1 Semestre 1' },
  y1_s2: { binding: 'mp1_s2', label: 'MP1 Semestre 2' },
  y2_s1: { binding: 'mp2_s1', label: 'MP2 Semestre 1' },
  y2_s2: { binding: 'mp2_s2', label: 'MP2 Semestre 2' },
};

const BINDING_BY_LABEL = new Map(
  Object.values(SEMESTER_BUCKETS).map((item) => [item.label, item.binding]),
);

export async function handlePremium(request, env, url) {
  const user = await userFromRequest(request, env);
  if (!user) return json({ error: 'Connectez-vous.' }, 401);
  if (!hasBuckets(env)) return json({ error: 'Espace premium indisponible.' }, 503);

  if (url.pathname === '/api/premium/files' && request.method === 'GET') {
    const files = await listAllowed(env, user);
    return json({ files }, 200);
  }

  if (url.pathname === '/api/premium/file' && request.method === 'GET') {
    const located = locate(url.searchParams.get('file') || '', user);
    if (!located) return json({ error: 'Accès refusé.' }, 403);
    return serveObject(env, located.binding, located.key);
  }

  return json({ error: 'Not found' }, 404);
}

function hasBuckets(env) {
  return Object.values(SEMESTER_BUCKETS).some((item) => env[item.binding]);
}

function allowedSemesters(user) {
  const codes = Array.isArray(user.entitlements) ? user.entitlements : [];
  return codes.map((code) => SEMESTER_BUCKETS[code]).filter(Boolean);
}

async function listAllowed(env, user) {
  const objects = [];
  for (const item of allowedSemesters(user)) {
    const bucket = env[item.binding];
    if (!bucket) continue;
    let cursor;
    do {
      const page = await bucket.list({ limit: 1000, cursor });
      for (const obj of page.objects) {
        if (!obj.key || obj.key.endsWith('/')) continue;
        objects.push({
          name: `${item.label}/${obj.key}`,
          size: obj.size,
          uploadTimestamp: obj.uploaded.getTime(),
          contentType: obj.httpMetadata && obj.httpMetadata.contentType,
        });
      }
      cursor = page.truncated ? page.cursor : undefined;
    } while (cursor);
  }
  return objects;
}

function locate(file, user) {
  if (!file || file.includes('..') || file.startsWith('/')) return null;
  const slash = file.indexOf('/');
  if (slash <= 0) return null;
  const label = file.slice(0, slash);
  const key = file.slice(slash + 1);
  if (!key || key.startsWith('/') || key.includes('..')) return null;
  const binding = BINDING_BY_LABEL.get(label);
  if (!binding) return null;
  const allowed = allowedSemesters(user).some((item) => item.binding === binding);
  if (!allowed) return null;
  return { binding, key };
}

async function serveObject(env, binding, key) {
  const bucket = env[binding];
  if (!bucket) return json({ error: 'Espace premium indisponible.' }, 503);
  const object = await bucket.get(key);
  if (!object) return json({ error: 'File not found' }, 404);
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('Content-Type', object.httpMetadata?.contentType || 'application/pdf');
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Cache-Control', 'private, no-store');
  return new Response(object.body, { headers });
}

function json(payload, status) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...CORS },
  });
}
