import { userFromRequest } from './auth.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

// First semester of année 1 unlocks MP1/DS1 and MP1/Examen1, and so on.
const ACCESS = {
  y1_s1: [['mp1', 'ds1'], ['mp1', 'examen1']],
  y1_s2: [['mp1', 'ds2'], ['mp1', 'examen2']],
  y2_s1: [['mp2', 'ds1'], ['mp2', 'examen1']],
  y2_s2: [['mp2', 'ds2'], ['mp2', 'examen2']],
};

export async function handlePremium(request, env, url) {
  const user = await userFromRequest(request, env);
  if (!user) return json({ error: 'Connectez-vous.' }, 401);
  if (!env.premium) return json({ error: 'Espace premium indisponible.' }, 503);

  if (url.pathname === '/api/premium/files' && request.method === 'GET') {
    const files = await listAllowed(env, user);
    return json({ files }, 200);
  }

  if (url.pathname === '/api/premium/file' && request.method === 'GET') {
    const key = url.searchParams.get('file') || '';
    if (!fileAllowed(key, user)) return json({ error: 'Accès refusé.' }, 403);
    return serveObject(env, key);
  }

  return json({ error: 'Not found' }, 404);
}

async function listAllowed(env, user) {
  const objects = [];
  let cursor;
  do {
    const page = await env.premium.list({ limit: 1000, cursor });
    for (const obj of page.objects) {
      if (!fileAllowed(obj.key, user)) continue;
      objects.push({
        name: obj.key,
        size: obj.size,
        uploadTimestamp: obj.uploaded.getTime(),
        contentType: obj.httpMetadata && obj.httpMetadata.contentType,
      });
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
  return objects;
}

function fileAllowed(key, user) {
  if (!key || key.includes('..') || key.startsWith('/')) return false;
  if (user.role === 'admin') return true;
  const parts = key.split('/').filter((part) => part.trim());
  if (parts.length < 2) return false;
  const year = norm(parts[0]);
  const section = norm(parts[1]);
  const codes = Array.isArray(user.entitlements) ? user.entitlements : [];
  return codes.some((code) =>
    (ACCESS[code] || []).some(([y, s]) => y === year && s === section),
  );
}

function norm(value) {
  return String(value || '').trim().toLowerCase().replace(/\s+/g, '');
}

async function serveObject(env, key) {
  const object = await env.premium.get(key);
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
