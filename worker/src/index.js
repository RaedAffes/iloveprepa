const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Cache-Control': 'no-store',
};

const LIST_CACHE_URL = 'https://r2files.internal/list';

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
    const state = await readState(env);

    if (url.pathname === '/api/status') {
      return json({ state }, 200);
    }

    if (url.pathname === '/api/unlock') {
      return handleUnlock(env, state, url);
    }

    if (state.locked) {
      return lockedResponse(state);
    }

    try {
      if (url.pathname === '/api/files') {
        const files = await listFiles(env, ctx);
        return json({ files }, 200);
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

async function listFiles(env, ctx) {
  const cache = caches.default;
  const cached = await cache.match(LIST_CACHE_URL);
  if (cached) return cached.json();

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

  await cache.put(
    LIST_CACHE_URL,
    new Response(JSON.stringify(objects), {
      headers: { 'Cache-Control': 'max-age=60' },
    }),
  );

  // Fast path: storage is visible the moment the bucket is listed. Lock
  // immediately if it crosses 90% instead of waiting for the cron job.
  if (totalBytes >= STORAGE_LIMIT_BYTES * STOP_THRESHOLD) {
    ctx.waitUntil(
      evaluate(env, { storageBytes: totalBytes }).catch((err) =>
        console.error('evaluate failed:', err),
      ),
    );
  }

  return objects;
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
