const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Cache-Control, Pragma',
  'Access-Control-Max-Age': '86400',
  'Cache-Control': 'no-store',
};

const LIST_CACHE_URL = 'https://r2files.internal/list';

// The assembled /api/files listing, cached in three layers so a cold open
// never has to walk the whole R2 bucket (a paginated Class A listing that
// takes ~2-3 s):
//   1. the edge Cache API copy (5-min TTL, like the browser/CDN header),
//   2. the KV snapshot below (survives edge eviction, rebuilt hourly + on
//      demand), serving in ~50-100 ms,
//   3. a live bucket walk only when both are empty.
const FILES_LIST_KEY = 'files:list:v1';
const FILES_REFRESH_LOCK_KEY = 'files:refresh:lock:v1';
const FILES_SNAPSHOT_TTL_MS = 5 * 60 * 1000; // matches Cache-Control max-age
const FILES_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Cache-Control, Pragma',
  'Access-Control-Max-Age': '86400',
  'Cache-Control': 'public, max-age=300, s-maxage=300',
};

// Cloudflare R2 free tier (per calendar month).
const STORAGE_LIMIT_BYTES = 10 * 1024 * 1024 * 1024; // 10 GiB
const CLASS_A_LIMIT = 1_000_000; // writes / lists
const CLASS_B_LIMIT = 10_000_000; // reads
const WORKER_DAILY_LIMIT = 100_000; // Cloudflare Workers free plan: 100k requests/day

// Lock the service at 90% of any free-tier limit so billing can never start.
const STOP_THRESHOLD = 0.9;
// Only auto-unlock when every metric drops below 75% (hysteresis).
const REARM_THRESHOLD = 0.75;

const STATE_KEY = 'usage:state';

const CLASS_A_ACTIONS = new Set([
  'ListBuckets', 'PutBucket', 'ListObjects', 'PutObject', 'CopyObject',
  'CompleteMultipartUpload', 'CreateMultipartUpload', 'ListMultipartUploads',
  'UploadPart', 'UploadPartCopy', 'ListParts', 'DeleteObject', 'DeleteBucket',
  'PutBucketEncryption', 'PutBucketCors', 'PutBucketLifecycleConfiguration',
]);

const CLASS_B_ACTIONS = new Set([
  'HeadBucket', 'HeadObject', 'GetObject', 'UsageSummary',
  'GetBucketEncryption', 'GetBucketLocation', 'GetBucketCors',
  'GetBucketLifecycleConfiguration',
]);

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    const url = new URL(request.url);

    if (url.pathname === '/api/status') {
      const state = await readState(env);
      return json({ state }, 200);
    }

    if (url.pathname === '/api/unlock') {
      const state = await readState(env);
      return handleUnlock(env, state, url);
    }

    if (url.pathname === '/api/stats') {
      return handleGetStats(env);
    }

    if (url.pathname === '/api/stats/increment' && request.method === 'POST') {
      return handleIncrementStats(env, request);
    }

    if (url.pathname === '/api/validate-email') {
      return handleValidateEmail(url, env);
    }

    // The KV read only gates the library operations below — the stats,
    // increment and email-validation endpoints above (and the OPTIONS
    // preflight) never touch the KV namespace, so the free KV read quota
    // stays reserved for /api/files and file serving.
    const state = await readState(env);
    if (state.locked) {
      return lockedResponse(state);
    }

    try {
      if (url.pathname === '/api/files') {
        const files = await listFilesCached(env, ctx);
        // Cache on the browser/CDN for 5 minutes (max-age / s-maxage). On the
        // server side the response is served from the edge Cache API or the KV
        // snapshot so a full R2 bucket walk (a Class A operation) happens only
        // when both are cold.
        return new Response(JSON.stringify({ files }), {
          status: 200,
          headers: FILES_HEADERS,
        });
      }

      if (url.pathname.startsWith('/api/view/')) {
        // Pretty view URL ending in the file name, so the browser tab shows
        // the file name instead of the generic "download" segment. `?f=` is
        // the exact R2 key, always sent by the app so duplicate names never
        // collide. Without `?f=` the segment is resolved through the URL index
        // when it is unambiguous.
        const exact = url.searchParams.get('f') || '';
        const name = decodeURIComponent(url.pathname.slice('/api/view/'.length));
        if (!name) return json({ error: 'Missing file parameter' }, 400);
        if (exact) return handleDownload(env, exact, false);
        const resolved = await resolveName(env, name);
        if (resolved.length === 0) {
          // Index not built yet: treat the segment as the full key (legacy).
          return handleDownload(env, name, false);
        }
        if (resolved.length === 1) {
          return handleDownload(env, resolved[0], false);
        }
        return json(
          {
            error: 'Plusieurs fichiers portent ce nom. Utilisez le lien complet.',
            name,
            files: resolved,
          },
          409,
        );
      }

      if (url.pathname === '/api/download') {
        const name = url.searchParams.get('file') || '';
        if (!name) return json({ error: 'Missing file parameter' }, 400);
        const forceDownload = url.searchParams.get('download') === '1';
        return handleDownload(env, name, forceDownload);
      }

      return json({ error: 'Not found' }, 404);
    } catch (err) {
      return json({ error: String((err && err.message) || err) }, 500);
    }
  },

  async scheduled(event, env) {
    try {
      await checkUsage(env);
    } catch (err) {
      console.error('R2 usage check failed:', err);
    }
    // Keep the /api/files snapshot warm every hour so first page loads never
    // cold-start a full bucket walk.
    try {
      await storeFilesSnapshot(env);
    } catch (err) {
      console.error('Files snapshot refresh failed:', err);
    }
  },
};

function json(payload, status) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

function lockedResponse(state) {
  return json(
    {
      error:
        'Service paused: R2 usage has reached 90% of the free tier. Operations are blocked to prevent Cloudflare billing.',
      locked: true,
      reason: state.lockReason || null,
      usage: state.usage || null,
    },
    503,
  );
}

async function readState(env) {
  if (!env.usage_kv) return {};
  try {
    const raw = await env.usage_kv.get(STATE_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch (err) {
    console.error('readState failed:', err);
    return {};
  }
}

// Validates a contact-form address in two steps:
//   1. Cheap local gate: the domain must have mail (MX) records, checked via
//      Cloudflare's public DNS-over-HTTPS JSON API (no API key needed).
//   2. If a ZB_API_KEY secret is configured, asks ZeroBounce to verify the
//      actual mailbox over SMTP (blocks addresses like a random @gmail.com
//      that Gmail reports as non-existent).
// Fails open everywhere: a DNS hiccup, a missing key, or a ZeroBounce
// outage never blocks a legitimate contact message.
async function handleValidateEmail(url, env) {
  const email = (url.searchParams.get('email') || '').trim().toLowerCase();
  const formatRe = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
  if (!formatRe.test(email)) {
    return json({ ok: false, reason: 'format' }, 200);
  }
  const domain = email.slice(email.lastIndexOf('@') + 1);

  const lookup = async (type) => {
    const res = await fetch(
      `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(domain)}&type=${type}`,
      { headers: { accept: 'application/dns-json' } },
    );
    if (!res.ok) throw new Error(`DNS ${res.status}`);
    const data = await res.json();
    return data && Array.isArray(data.Answer) ? data.Answer : [];
  };

  try {
    const mxRecords = await lookup('MX');
    const hasMx = mxRecords.some((r) => r.type === 15);
    if (!hasMx) {
      // RFC 5321: a host with no MX falls back to its A record.
      const aRecords = await lookup('A');
      const hasA = aRecords.some((r) => r.type === 1);
      if (!hasA) {
        return json({ ok: false, reason: 'no-mx' }, 200);
      }
    }
  } catch (err) {
    // DNS check failed — let ZeroBounce carry the verdict alone.
    console.error('DNS check failed:', err);
  }

  const apiKey = (env.ZB_API_KEY || '').trim();
  if (!apiKey) {
    return json({ ok: true, reason: 'mx-only' }, 200);
  }

  try {
    const res = await fetch(
      `https://api.zerobounce.net/v2/validate?api_key=${encodeURIComponent(apiKey)}&email=${encodeURIComponent(email)}`,
    );
    if (!res.ok) throw new Error(`ZeroBounce ${res.status}`);
    const data = await res.json();
    const status = String(data.status || 'unknown').toLowerCase();
    const blocked = new Set([
      'invalid',
      'spam_trap',
      'toxic',
      'do_not_mail',
      'disposable',
    ]);
    if (blocked.has(status)) {
      return json({ ok: false, reason: status }, 200);
    }
    // valid / catch-all / unknown / abort all pass — a catch-all server
    // (accepts any address) can't be probed, so rejecting would hurt real
    // users for no benefit.
    return json({ ok: true, reason: status }, 200);
  } catch (err) {
    console.error('ZeroBounce check failed:', err);
    return json({ ok: true, reason: 'fail-open' }, 200);
  }
}

// Keeps the running visits/downloads counters scoped to the current calendar
// month (UTC, key "YYYY-MM"). On the first request of a new month the finished
// month's totals are archived into `monthly_counts` and the running counters
// are reset to zero, so each month's numbers are preserved in D1.
async function ensureMonth(env) {
  const db = env.iloveprepa_db;
  if (!db) return;
  const now = new Date();
  const month = now.toISOString().slice(0, 7); // YYYY-MM
  const row = await db.prepare('SELECT month FROM counters WHERE id = 1').first();
  if (row && row.month === month) return;
  const nowIso = now.toISOString();
  if (row && row.month) {
    // A new month started: snapshot the finished month into the archive,
    // then reset the running counters for the fresh month.
    const prev = await db
      .prepare('SELECT visits, downloads FROM counters WHERE id = 1')
      .first();
    await db
      .prepare(
        `INSERT INTO monthly_counts (month, visits, downloads, updated_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(month) DO UPDATE SET
           visits = excluded.visits,
           downloads = excluded.downloads,
           updated_at = excluded.updated_at`,
      )
      .bind(row.month, prev.visits || 0, prev.downloads || 0, nowIso)
      .run();
    await db
      .prepare(
        'UPDATE counters SET visits = 0, downloads = 0, month = ?, updated_at = ? WHERE id = 1',
      )
      .bind(month, nowIso)
      .run();
  } else if (row) {
    // Migration: stamp the current month onto the pre-existing row without
    // clearing the counters accumulated so far.
    await db
      .prepare('UPDATE counters SET month = ?, updated_at = ? WHERE id = 1')
      .bind(month, nowIso)
      .run();
  } else {
    await db
      .prepare(
        'INSERT INTO counters (id, visits, downloads, month, updated_at) VALUES (1, 0, 0, ?, ?)',
      )
      .bind(month, nowIso)
      .run();
  }
}

async function handleGetStats(env) {
  try {
    await ensureMonth(env);
    const stmt = env.iloveprepa_db &&
      await env.iloveprepa_db.prepare('SELECT visits, downloads FROM counters WHERE id = 1').first();
    if (!stmt) {
      return cachedStats({ visits: 0, downloads: 0 });
    }
    return cachedStats(
      { visits: stmt.visits || 0, downloads: stmt.downloads || 0 },
      200,
    );
  } catch (err) {
    console.error('handleGetStats failed:', err);
    return json({ error: String((err && err.message) || err) }, 500);
  }
}

// Short-lived stats snapshot shared by every visitor. The edge CDN honours
// Cache-Control and serves /api/stats without invoking the Worker again, so
// the footer poller costs roughly one Worker request per 5 minutes per user
// pool instead of one per open tab — the 100k requests/day limit becomes
// unreachable. Counters drift by at most a few minutes, which nobody notices.
function cachedStats(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Cache-Control, Pragma',
      'Access-Control-Max-Age': '86400',
      'Cache-Control': 'public, max-age=300, s-maxage=300',
    },
  });
}

async function handleIncrementStats(env, request) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    body = {};
  }
  // Numeric counts so a batch of deferred increments can be flushed at once.
  const visits = Math.max(0, Math.floor(Number(body.visits) || 0));
  const downloads = Math.max(0, Math.floor(Number(body.downloads) || 0));
  if (visits === 0 && downloads === 0) {
    return json({ error: 'Nothing to increment' }, 400);
  }

  try {
    await ensureMonth(env);
    const set = [];
    if (visits) set.push(`visits = visits + ${visits}`);
    if (downloads) set.push(`downloads = downloads + ${downloads}`);
    await env.iloveprepa_db
      .prepare(`UPDATE counters SET ${set.join(', ')} WHERE id = 1`)
      .run();
    const stmt = await env.iloveprepa_db
      .prepare('SELECT visits, downloads FROM counters WHERE id = 1')
      .first();
    return json(
      { ok: true, visits: stmt ? stmt.visits || 0 : 0, downloads: stmt ? stmt.downloads || 0 : 0 },
      200,
    );
  } catch (err) {
    console.error('handleIncrementStats failed:', err);
    return json({ error: String((err && err.message) || err) }, 500);
  }
}

async function handleUnlock(env, state, url) {
  const token = url.searchParams.get('token') || '';
  if (!env.UNLOCK_TOKEN || token !== env.UNLOCK_TOKEN) {
    return json({ error: 'Invalid or missing token' }, 403);
  }
  if (!state.locked) {
    return json({ ok: true, alreadyUnlocked: true, state }, 200);
  }
  const next = {
    ...state,
    locked: false,
    unlockedAt: new Date().toISOString(),
    lockReason: null,
  };
  await env.usage_kv.put(STATE_KEY, JSON.stringify(next));
  return json({ ok: true, state: next }, 200);
}

// Merge fresh usage numbers into the stored state, decide whether to lock /
// unlock, persist it, and email on state transitions.
async function evaluate(env, usage) {
  const state = await readState(env);
  const merged = { ...(state.usage || {}), ...usage };

  const pct = {
    storageBytes: pctOf(merged.storageBytes, STORAGE_LIMIT_BYTES),
    classA: pctOf(merged.classA, CLASS_A_LIMIT),
    classB: pctOf(merged.classB, CLASS_B_LIMIT),
    workerRequests: pctOf(merged.workerRequests, WORKER_DAILY_LIMIT),
  };

  const breached = Object.entries(pct).find(([, v]) => v >= STOP_THRESHOLD);
  let locked = state.locked;
  if (breached) {
    locked = true;
  } else if (locked && Object.values(pct).every((v) => v < REARM_THRESHOLD)) {
    locked = false;
  }

  const now = new Date().toISOString();
  const next = {
    ...state,
    locked,
    lockReason: breached ? breached[0] : state.lockReason,
    lockedAt: locked && !state.locked ? now : state.lockedAt,
    unlockedAt: !locked && state.locked ? now : state.unlockedAt,
    usage: merged,
    pct,
    lastCheck: now,
  };

  await env.usage_kv.put(STATE_KEY, JSON.stringify(next));

  if (next.locked && !state.locked) {
    await sendAlert(env, next, 'limit');
  } else if (!next.locked && state.locked) {
    await sendAlert(env, next, 'recovered');
  }

  return next;
}

function pctOf(value, limit) {
  return typeof value === 'number' ? value / limit : undefined;
}

// Serves the /api/files listing from the cheapest warm source first:
//   1. edge Cache API (5-min TTL),
//   2. KV snapshot — when stale (older than 5 min) it is *still* served
//      immediately, and a rebuild is scheduled in the background, so the
//      caller never waits on an R2 walk,
//   3. live bucket walk, persisted to both layers before returning.
async function listFilesCached(env, ctx) {
  // 1) Edge cache.
  const cached = await caches.default.match(LIST_CACHE_URL);
  if (cached) {
    try {
      const json = await cached.clone().json();
      if (Array.isArray(json.files)) return json.files;
    } catch (_) {}
  }

  // 2) KV snapshot.
  if (env.usage_kv) {
    try {
      const raw = await env.usage_kv.get(FILES_LIST_KEY);
      if (raw) {
        const snapshot = JSON.parse(raw);
        const files = snapshot.files;
        if (Array.isArray(files) && files.length > 0) {
          const stale =
            Date.now() - (snapshot.at || 0) >= FILES_SNAPSHOT_TTL_MS;
          if (stale) {
            ctx.waitUntil(
              rebuildFilesSnapshot(env).catch((err) =>
                console.error('Background files refresh failed:', err),
              ),
            );
          }
          ctx.waitUntil(
            caches.default
              .put(LIST_CACHE_URL, fileListResponse(files))
              .catch(() => {}),
          );
          return files;
        }
      }
    } catch (err) {
      console.error('Files KV read failed:', err);
    }
  }

  // 3) Both layers cold: walk the bucket once, then persist.
  const files = await listFiles(env, ctx);
  ctx.waitUntil(
    storeFilesSnapshot(env, files).catch((err) =>
      console.error('Files snapshot write failed:', err),
    ),
  );
  return files;
}

function fileListResponse(files) {
  return new Response(JSON.stringify({ files }), {
    status: 200,
    headers: FILES_HEADERS,
  });
}

// Persists an assembled listing to KV + the edge cache. With no argument it
// walks R2 first (used by the hourly cron and background refreshes).
async function storeFilesSnapshot(env, files) {
  const listing = files || (await listFiles(env, null));
  if (env.usage_kv) {
    await env.usage_kv.put(
      FILES_LIST_KEY,
      JSON.stringify({ at: Date.now(), files: listing }),
    );
  }
  await caches.default.put(LIST_CACHE_URL, fileListResponse(listing));
  await refreshNameIndex(env, listing);
}

// One bucketed refresh at a time: the KV lock (5-min TTL) keeps concurrent
// stale serves from all triggering their own R2 walk.
async function rebuildFilesSnapshot(env) {
  if (!env.usage_kv) return;
  const lock = await env.usage_kv.get(FILES_REFRESH_LOCK_KEY);
  if (lock != null) return;
  await env.usage_kv.put(FILES_REFRESH_LOCK_KEY, '1', {
    expirationTtl: 300,
  });
  try {
    await storeFilesSnapshot(env);
  } finally {
    await env.usage_kv.delete(FILES_REFRESH_LOCK_KEY);
  }
}

async function listFiles(env, ctx) {
  const objects = [];
  let totalBytes = 0;
  let cursor;
  do {
    const page = await env.iloveprepa.list({
      limit: 1000,
      cursor,
    });
    for (const obj of page.objects) {
      totalBytes += obj.size;
      objects.push({
        name: obj.key,
        size: obj.size,
        uploadTimestamp: obj.uploaded.getTime(),
        contentType: obj.httpMetadata && obj.httpMetadata.contentType,
      });
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);

  // Fast path: storage is visible the moment the bucket is listed. Lock
  // immediately if it crosses 90% instead of waiting for the cron job.
  if (totalBytes >= STORAGE_LIMIT_BYTES * STOP_THRESHOLD) {
    const task = evaluate(env, { storageBytes: totalBytes }).catch((err) =>
      console.error('evaluate failed:', err),
    );
    if (ctx && typeof ctx.waitUntil === 'function') ctx.waitUntil(task);
  }

  return objects;
}

// Maps each file-name segment seen in the URL to every R2 key that ends with
// it. Refreshed behind the scenes on every /api/files listing, so pretty view
// URLs (/api/view/<nom>) can be resolved without a full bucket walk.
const NAME_INDEX_KEY = 'names:index';

async function refreshNameIndex(env, files) {
  if (!env.usage_kv) return;
  const index = {};
  for (const f of files) {
    const base = f.name.split('/').pop();
    if (base) (index[base] ??= []).push(f.name);
  }
  const json = JSON.stringify(index);
  // KV writes are counted against the daily free quota, so only write when
  // the index actually changed: identical content costs one read, no write.
  const current = await env.usage_kv.get(NAME_INDEX_KEY);
  if (current === json) return;
  await env.usage_kv.put(NAME_INDEX_KEY, json);
}

async function resolveName(env, name) {
  if (!env.usage_kv) return [];
  try {
    const raw = await env.usage_kv.get(NAME_INDEX_KEY);
    if (!raw) return [];
    const index = JSON.parse(raw);
    return Array.isArray(index[name]) ? index[name] : [];
  } catch (err) {
    console.error('resolveName failed:', err);
    return [];
  }
}

async function handleDownload(env, name, forceDownload) {
  // Serve repeated requests for the same PDF from Cloudflare's edge cache.
  const cache = caches.default;
  const cacheKey = 'https://r2file.internal/' +
    (forceDownload ? 'dl/' : 'view/') + name;
  const cached = await cache.match(cacheKey);
  if (cached) return cached;

  const object = await env.iloveprepa.get(name);
  if (!object) {
    return json({ error: 'File not found' }, 404);
  }

  const fileName = name.split('/').pop();
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('Content-Type', object.httpMetadata.contentType ||
    'application/pdf');
  headers.set('Access-Control-Allow-Origin', '*');
  if (forceDownload) {
    headers.set('Content-Disposition',
      `attachment; filename*=UTF-8''${encodeURIComponent(fileName)}`);
  } else {
    headers.set('Content-Disposition',
      `inline; filename*=UTF-8''${encodeURIComponent(fileName)}`);
  }
  headers.set('Cache-Control', 'public, max-age=86400');

  const response = new Response(object.body, { headers });
  await cache.put(cacheKey, response.clone());
  return response;
}

// Authoritative monthly check against Cloudflare's GraphQL analytics.
async function checkUsage(env) {
  if (!env.CF_API_TOKEN || !env.CF_ACCOUNT_ID) {
    console.error('checkUsage: CF_API_TOKEN / CF_ACCOUNT_ID not set');
    return;
  }

  const now = new Date();
  const startOfMonth = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1),
  );
  const day = (d) => d.toISOString().slice(0, 10);

  const [opsRes, storageRes, workersRes] = await Promise.all([
    fetchGraphQL(env, opsQuery(env.CF_ACCOUNT_ID, day(startOfMonth), day(now))),
    fetchGraphQL(
      env,
      storageQuery(env.CF_ACCOUNT_ID, startOfMonth.toISOString(), now.toISOString()),
    ),
    fetchGraphQL(env, workersQuery(env.CF_ACCOUNT_ID, day(now), day(now))),
  ]);

  // Operations are billed account-wide; any action not in the Class B list is
  // counted toward Class A (the smaller allowance) to stay conservative.
  let classA = 0;
  let classB = 0;
  const ops = opsRes?.data?.viewer?.accounts?.[0]?.r2OperationsAdaptiveGroups || [];
  for (const row of ops) {
    const action = row?.dimensions?.actionType;
    const requests = row?.sum?.requests || 0;
    if (CLASS_B_ACTIONS.has(action)) {
      classB += requests;
    } else {
      classA += requests;
    }
  }

  // Latest storage snapshot per bucket, summed across the whole account.
  const byBucket = new Map();
  const rows = storageRes?.data?.viewer?.accounts?.[0]?.r2StorageAdaptiveGroups || [];
  for (const row of rows) {
    const bucket = row?.dimensions?.bucketName || '';
    const size = (row?.max?.payloadSize || 0) + (row?.max?.metadataSize || 0);
    const prev = byBucket.get(bucket);
    if (prev === undefined || size > prev) byBucket.set(bucket, size);
  }
  const storageBytes = [...byBucket.values()].reduce((a, b) => a + b, 0);

  // Worker requests today (free plan cap is 100k/day).
  let workerRequests = 0;
  const wRows = workersRes?.data?.viewer?.accounts?.[0]?.workersInvocationsAdaptive || [];
  for (const row of wRows) {
    workerRequests += row?.sum?.requests || 0;
  }

  await evaluate(env, { storageBytes, classA, classB, workerRequests });
}

function opsQuery(accountId, start, end) {
  return `{
    viewer {
      accounts(filter: { accountTag: "${accountId}" }) {
        r2OperationsAdaptiveGroups(
          filter: { date_geq: "${start}", date_leq: "${end}" }
          limit: 10000
        ) {
          dimensions { actionType }
          sum { requests }
        }
      }
    }
  }`;
}

function storageQuery(accountId, start, end) {
  return `{
    viewer {
      accounts(filter: { accountTag: "${accountId}" }) {
        r2StorageAdaptiveGroups(
          filter: { datetime_geq: "${start}", datetime_leq: "${end}" }
          orderBy: [datetime_DESC]
          limit: 10000
        ) {
          max { objectCount payloadSize metadataSize }
          dimensions { datetime bucketName }
        }
      }
    }
  }`;
}

function workersQuery(accountId, start, end) {
  return `{
    viewer {
      accounts(filter: { accountTag: "${accountId}" }) {
        workersInvocationsAdaptive(
          filter: { date_geq: "${start}", date_leq: "${end}" }
          limit: 10000
        ) {
          dimensions { date }
          sum { requests }
        }
      }
    }
  }`;
}

async function fetchGraphQL(env, query) {
  const res = await fetch('https://api.cloudflare.com/client/v4/graphql', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${env.CF_API_TOKEN}`,
    },
    body: JSON.stringify({ query }),
  });
  if (!res.ok) throw new Error(`GraphQL ${res.status}: ${await res.text()}`);
  return res.json();
}

async function sendAlert(env, state, kind) {
  const apiKey = env.RESEND_API_KEY;
  const to = (env.ALERT_EMAIL || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (!apiKey || to.length === 0) return;

  const isLock = kind === 'limit';
  const subject = isLock
    ? '[iloveprepa] R2 hit 90% of free tier - service stopped'
    : '[iloveprepa] R2 recovered - service resumed';

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        from: env.ALERT_FROM || 'iloveprepa <onboarding@resend.dev>',
        to,
        subject,
        html: buildEmailHtml(state, isLock),
      }),
    });
    if (!res.ok) {
      console.error('sendAlert: Resend failed', res.status, await res.text());
    }
  } catch (err) {
    console.error('sendAlert error:', err);
  }
}

function buildEmailHtml(state, isLock) {
  const pct = state.pct || {};
  const u = state.usage || {};
  const fmtBytes = (b) => {
    if (typeof b !== 'number') return 'n/a';
    if (b >= 1024 * 1024 * 1024) {
      return (b / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
    }
    return (b / (1024 * 1024)).toFixed(1) + ' MB';
  };
  const fmtNum = (n) => (typeof n === 'number' ? n.toLocaleString('en-US') : 'n/a');
  const fmtPct = (v) => (typeof v === 'number' ? (v * 100).toFixed(1) + '%' : 'n/a');

  const rows = [
    ['Storage', fmtBytes(u.storageBytes), fmtPct(pct.storageBytes), '10 GB'],
    ['Class A operations (writes / lists)', fmtNum(u.classA), fmtPct(pct.classA), '1,000,000'],
    ['Class B operations (reads)', fmtNum(u.classB), fmtPct(pct.classB), '10,000,000'],
    ['Worker requests (today)', fmtNum(u.workerRequests), fmtPct(pct.workerRequests), '100,000/day'],
  ];

  const trs = rows
    .map(
      ([label, used, usedPct, free]) =>
        `<tr><td style="padding:8px 12px;border-bottom:1px solid #ececec">${label}</td>` +
        `<td style="padding:8px 12px;border-bottom:1px solid #ececec">${used}</td>` +
        `<td style="padding:8px 12px;border-bottom:1px solid #ececec">${usedPct}</td>` +
        `<td style="padding:8px 12px;border-bottom:1px solid #ececec">${free}</td></tr>`,
    )
    .join('');

  const title = isLock
    ? 'R2 usage reached 90% of the free tier - service stopped'
    : 'R2 usage recovered - service resumed';

  const body = isLock
    ? 'iloveprepa has automatically stopped so Cloudflare billing can never start. No files are being listed or served.'
    : 'All R2 usage is below the safety threshold again, so the service has been switched back on automatically.';

  const footer = isLock
    ? '<p style="font-size:13px;color:#666">To bring the service back: delete files from the Cloudflare dashboard (R2 &gt; iloveprepa bucket). It will resume automatically once usage is below 75%.</p>'
    : '';

  return `<div style="font-family:Arial,Helvetica,sans-serif;max-width:600px;margin:auto;padding:24px">
    <h2 style="color:#2563eb;margin:0 0 12px">${title}</h2>
    <p style="font-size:14px;color:#333;margin:0 0 16px">${body}</p>
    <table style="border-collapse:collapse;width:100%;font-size:13px">
      <tr>
        <th style="text-align:left;padding:8px 12px;border-bottom:2px solid #ccc">Metric</th>
        <th style="text-align:left;padding:8px 12px;border-bottom:2px solid #ccc">Used</th>
        <th style="text-align:left;padding:8px 12px;border-bottom:2px solid #ccc">% of free tier</th>
        <th style="text-align:left;padding:8px 12px;border-bottom:2px solid #ccc">Free limit</th>
      </tr>
      ${trs}
    </table>
    ${footer}
  </div>`;
}
