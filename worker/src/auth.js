// Google sign-in for the Flutter app.
//
// The browser is sent to Google, then back to /api/auth/callback. The callback
// stores the Google profile in `users`, opens a session, and returns the raw
// session token in the URL fragment (never the query string, so it is not sent
// to the site host or to third parties via Referer). The app keeps that token
// and sends it as Authorization: Bearer.

const AUTH_CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Cache-Control, Pragma, Authorization',
  'Access-Control-Max-Age': '86400',
  'Cache-Control': 'no-store',
  'Content-Type': 'application/json',
};

const SESSION_MS = 30 * 24 * 60 * 60 * 1000;
const OAUTH_COOKIE = 'iprepa_oauth';
const OAUTH_TTL_SEC = 10 * 60;
const DEFAULT_RETURN = 'https://iprepa.tn/';

export async function handleAuth(request, env, url) {
  try {
    if (url.pathname === '/api/auth/google' && request.method === 'GET') {
      return startGoogle(request, env, url);
    }
    if (url.pathname === '/api/auth/callback' && request.method === 'GET') {
      return finishGoogle(request, env, url);
    }
    if (url.pathname === '/api/auth/firebase' && request.method === 'POST') {
      return signInWithFirebase(request, env);
    }
    if (url.pathname === '/api/auth/me' && request.method === 'GET') {
      return currentUser(request, env);
    }
    if (url.pathname === '/api/auth/logout' && request.method === 'POST') {
      return logout(request, env);
    }
    return authJson({ error: 'Not found' }, 404);
  } catch (err) {
    console.error('auth failed:', err && err.message ? err.message : err);
    return authJson({ error: 'Auth failed' }, 500);
  }
}

async function startGoogle(request, env, url) {
  const returnTo = safeReturnTo(url.searchParams.get('return_to'));
  if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET || !env.SESSION_SECRET) {
    return failRedirect(returnTo, 'not_configured');
  }

  const state = randomToken(16);
  const verifier = randomToken(32);
  const challenge = await sha256Base64Url(verifier);
  const payload = await signPayload(
    { state, verifier, returnTo, exp: Date.now() + OAUTH_TTL_SEC * 1000 },
    env.SESSION_SECRET,
  );

  const redirectUri = callbackUrl(request);
  const google = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  google.searchParams.set('client_id', env.GOOGLE_CLIENT_ID);
  google.searchParams.set('redirect_uri', redirectUri);
  google.searchParams.set('response_type', 'code');
  google.searchParams.set('scope', 'openid email profile');
  google.searchParams.set('state', state);
  google.searchParams.set('code_challenge', challenge);
  google.searchParams.set('code_challenge_method', 'S256');
  google.searchParams.set('prompt', 'select_account');

  const headers = new Headers();
  headers.set('Location', google.toString());
  headers.set('Cache-Control', 'no-store');
  headers.append('Set-Cookie', oauthCookie(payload, request));
  return new Response(null, { status: 302, headers });
}

async function finishGoogle(request, env, url) {
  const cookiePayload = await readOauthCookie(request, env.SESSION_SECRET);
  const returnTo = cookiePayload?.returnTo || safeReturnTo(null);
  const googleError = url.searchParams.get('error');
  if (googleError) {
    return failRedirect(
      returnTo,
      googleError === 'access_denied' ? 'access_denied' : 'token',
      request,
    );
  }
  if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET || !env.SESSION_SECRET) {
    return failRedirect(returnTo, 'not_configured', request);
  }
  if (!cookiePayload) return failRedirect(returnTo, 'invalid_state', request);

  const state = url.searchParams.get('state') || '';
  const code = url.searchParams.get('code') || '';
  if (!code || !(await fixedTimeEqual(state, cookiePayload.state))) {
    return failRedirect(returnTo, 'invalid_state', request);
  }

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: callbackUrl(request),
      grant_type: 'authorization_code',
      code_verifier: cookiePayload.verifier,
    }),
  });
  if (!tokenRes.ok) {
    console.error('Google token exchange failed:', tokenRes.status);
    return failRedirect(returnTo, 'token', request);
  }
  const tokens = await tokenRes.json();
  if (!tokens.access_token) return failRedirect(returnTo, 'token', request);

  const profileRes = await fetch('https://openidconnect.googleapis.com/v1/userinfo', {
    headers: { Authorization: `Bearer ${tokens.access_token}` },
  });
  if (!profileRes.ok) {
    console.error('Google userinfo failed:', profileRes.status);
    return failRedirect(returnTo, 'profile', request);
  }
  const profile = await profileRes.json();
  const email = String(profile.email || '').trim().toLowerCase();
  const sub = String(profile.sub || '');
  if (!sub || !email) return failRedirect(returnTo, 'profile', request);

  if (!env.iloveprepa_db) return failRedirect(returnTo, 'server', request);

  let rawToken;
  try {
    const session = await saveUserAndSession(env, {
      id: sub,
      email,
      emailVerified: profile.email_verified === true,
      name: textOrNull(profile.name),
      givenName: textOrNull(profile.given_name),
      familyName: textOrNull(profile.family_name),
      picture: textOrNull(profile.picture),
      locale: textOrNull(profile.locale),
    });
    rawToken = session.token;
  } catch (err) {
    console.error('user upsert failed:', err && err.message ? err.message : err);
    return failRedirect(returnTo, 'email_in_use', request);
  }

  const dest = new URL(returnTo);
  dest.hash = `auth_session=${rawToken}`;
  const headers = new Headers();
  headers.set('Location', dest.toString());
  headers.set('Cache-Control', 'no-store');
  headers.append('Set-Cookie', clearOauthCookie(request));
  return new Response(null, { status: 302, headers });
}

async function signInWithFirebase(request, env) {
  if (!env.FIREBASE_API_KEY || !env.iloveprepa_db) {
    return authJson({ error: 'not_configured' }, 503);
  }
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return authJson({ error: 'invalid' }, 400);
  }
  const idToken = String((body && body.idToken) || '').trim();
  if (!idToken) return authJson({ error: 'invalid' }, 400);

  const lookup = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_API_KEY)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken }),
    },
  );
  if (!lookup.ok) {
    console.error('Firebase token lookup failed:', lookup.status);
    return authJson({ error: 'token' }, 401);
  }
  const data = await lookup.json();
  const account = data && Array.isArray(data.users) ? data.users[0] : null;
  const email = String((account && account.email) || '').trim().toLowerCase();
  const id = String((account && account.localId) || '');
  if (!account || !id || !email) return authJson({ error: 'profile' }, 401);

  const display = textOrNull(account.displayName);
  const parts = display ? display.split(/\s+/) : [];
  const signup = body.signup === true;
  const givenName = textOrNull(body.givenName) || parts[0] || null;
  const familyName = textOrNull(body.familyName) || (parts.length > 1 ? parts.slice(1).join(' ') : null);
  const faculty = clip(textOrNull(body.faculty), 120);
  const phoneInput = textOrNull(body.phone);
  const phone = phoneInput ? tunisianPhone(body.phone) : null;
  if (signup && (!givenName || !familyName)) return authJson({ error: 'name' }, 400);
  if (phoneInput && !phone) return authJson({ error: 'phone' }, 400);
  const fullName = [givenName, familyName].filter(Boolean).join(' ') || display;
  const verified = account.emailVerified === true;
  try {
    const session = await saveUserAndSession(env, {
      id,
      email,
      emailVerified: verified,
      name: fullName,
      givenName,
      familyName,
      picture: textOrNull(account.photoUrl),
      locale: null,
      faculty,
      phone,
    }, { session: verified });
    if (!verified) return authJson({ error: 'email_unverified', email }, 403);
    return authJson(session, 200);
  } catch (err) {
    console.error('firebase user upsert failed:', err && err.message ? err.message : err);
    return authJson({ error: 'email_in_use' }, 409);
  }
}

async function saveUserAndSession(env, profile, options = {}) {
  const db = env.iloveprepa_db;
  const now = new Date();
  const nowIso = now.toISOString();
  await db
    .prepare(
      `INSERT INTO users (
         id, email, email_verified, name, given_name, family_name, picture, locale,
         faculty, phone, created_at, updated_at, last_login_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         email = excluded.email,
         email_verified = excluded.email_verified,
         name = COALESCE(excluded.name, users.name),
         given_name = COALESCE(excluded.given_name, users.given_name),
         family_name = COALESCE(excluded.family_name, users.family_name),
         picture = COALESCE(excluded.picture, users.picture),
         locale = COALESCE(excluded.locale, users.locale),
         faculty = COALESCE(excluded.faculty, users.faculty),
         phone = COALESCE(excluded.phone, users.phone),
         updated_at = excluded.updated_at,
         last_login_at = excluded.last_login_at`,
    )
    .bind(
      profile.id,
      profile.email,
      profile.emailVerified ? 1 : 0,
      profile.name,
      profile.givenName,
      profile.familyName,
      profile.picture,
      profile.locale,
      profile.faculty || null,
      profile.phone || null,
      nowIso,
      nowIso,
      nowIso,
    )
    .run();

  if (options.session === false) {
  const row = await db
    .prepare(
      `SELECT id, email, email_verified, name, given_name, family_name, picture, locale,
                faculty, phone, role, created_at, last_login_at
         FROM users WHERE id = ?`,
      )
      .bind(profile.id)
      .first();
    return { user: await hydrateUser(db, row) };
  }

  const rawToken = randomToken(32);
  const sessionId = await sha256Hex(rawToken);
  const expires = new Date(now.getTime() + SESSION_MS).toISOString();
  await db.prepare('DELETE FROM sessions WHERE expires_at <= ?').bind(nowIso).run();
  await db
    .prepare('INSERT INTO sessions (id, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
    .bind(sessionId, profile.id, expires, nowIso)
    .run();

  const row = await db
    .prepare(
      `SELECT id, email, email_verified, name, given_name, family_name, picture, locale,
              faculty, phone, role, created_at, last_login_at
       FROM users WHERE id = ?`,
    )
    .bind(profile.id)
    .first();
  return { token: rawToken, user: await hydrateUser(db, row) };
}

function publicUser(row) {
  return {
    id: row.id,
    email: row.email,
    emailVerified: row.email_verified === 1,
    name: row.name,
    givenName: row.given_name,
    familyName: row.family_name,
    picture: row.picture,
    locale: row.locale,
    faculty: row.faculty,
    phone: row.phone,
    role: row.role || 'free',
    createdAt: row.created_at,
    lastLoginAt: row.last_login_at,
  };
}

/// Attaches the user's currently active entitlements (premium semesters) to
/// the public user payload sent to the app.
export async function hydrateUser(db, row) {
  const user = publicUser(row);
  user.entitlements = await activeEntitlements(db, row.id);
  return user;
}

export async function activeEntitlements(db, userId) {
  const rows = await db
    .prepare(
      `SELECT DISTINCT product_code FROM entitlement_grants
       WHERE user_id = ? AND revoked_at IS NULL`,
    )
    .bind(userId)
    .all();
  return (rows.results || []).map((r) => r.product_code);
}

async function currentUser(request, env) {
  const user = await userFromRequest(request, env);
  if (!user) return authJson({ user: null }, 401);
  return authJson({ user }, 200);
}

async function logout(request, env) {
  const token = bearerToken(request);
  const db = env.iloveprepa_db;
  if (token && db) {
    const sessionId = await sha256Hex(token);
    await db.prepare('DELETE FROM sessions WHERE id = ?').bind(sessionId).run();
  }
  return authJson({ ok: true }, 200);
}

export async function userFromRequest(request, env) {
  const token = bearerToken(request);
  const db = env.iloveprepa_db;
  if (!token || !db) return null;
  const sessionId = await sha256Hex(token);
  const nowIso = new Date().toISOString();
  const row = await db
    .prepare(
      `SELECT u.id, u.email, u.email_verified, u.name, u.given_name, u.family_name,
              u.picture, u.locale, u.faculty, u.phone, u.role, u.created_at, u.last_login_at,
              s.expires_at
       FROM sessions s
       JOIN users u ON u.id = s.user_id
       WHERE s.id = ?`,
    )
    .bind(sessionId)
    .first();
  if (!row) return null;
  if (row.expires_at <= nowIso) {
    await db.prepare('DELETE FROM sessions WHERE id = ?').bind(sessionId).run();
    return null;
  }
  return hydrateUser(db, row);
}

function bearerToken(request) {
  const header = request.headers.get('Authorization') || '';
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  return match ? match[1] : '';
}

function callbackUrl(request) {
  const url = new URL(request.url);
  return `${url.origin}/api/auth/callback`;
}

function safeReturnTo(value) {
  if (value) {
    try {
      const url = new URL(value);
      if (isAllowedOrigin(url.origin)) {
        url.hash = '';
        return url.toString();
      }
    } catch (_) {
      /* fall through to the default site */
    }
  }
  return DEFAULT_RETURN;
}

function isAllowedOrigin(origin) {
  let url;
  try {
    url = new URL(origin);
  } catch (_) {
    return false;
  }
  const host = url.hostname;
  if (host === 'localhost' || host === '127.0.0.1') {
    return url.protocol === 'http:' || url.protocol === 'https:';
  }
  if (url.protocol !== 'https:') return false;
  return (
    host === 'iprepa.tn' ||
    host === 'www.iprepa.tn' ||
    host === 'iloveprepa.pages.dev' ||
    host.endsWith('.iloveprepa.pages.dev')
  );
}

function failRedirect(returnTo, code, request) {
  const dest = new URL(returnTo);
  dest.hash = `auth_error=${code}`;
  const headers = new Headers();
  headers.set('Location', dest.toString());
  headers.set('Cache-Control', 'no-store');
  if (request) headers.append('Set-Cookie', clearOauthCookie(request));
  return new Response(null, { status: 302, headers });
}

function oauthCookie(value, request) {
  const secure = new URL(request.url).protocol === 'https:';
  return [
    `${OAUTH_COOKIE}=${encodeURIComponent(value)}`,
    'HttpOnly',
    'Path=/',
    'SameSite=Lax',
    `Max-Age=${OAUTH_TTL_SEC}`,
    secure ? 'Secure' : '',
  ]
    .filter(Boolean)
    .join('; ');
}

function clearOauthCookie(request) {
  const secure = new URL(request.url).protocol === 'https:';
  return [
    `${OAUTH_COOKIE}=`,
    'HttpOnly',
    'Path=/',
    'SameSite=Lax',
    'Max-Age=0',
    secure ? 'Secure' : '',
  ]
    .filter(Boolean)
    .join('; ');
}

function readCookie(request, name) {
  const header = request.headers.get('Cookie') || '';
  for (const part of header.split(';')) {
    const trimmed = part.trim();
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    if (trimmed.slice(0, eq) === name) {
      return decodeURIComponent(trimmed.slice(eq + 1));
    }
  }
  return '';
}

async function readOauthCookie(request, secret) {
  if (!secret) return null;
  const raw = readCookie(request, OAUTH_COOKIE);
  if (!raw) return null;
  const payload = await verifyPayload(raw, secret);
  if (!payload || typeof payload.exp !== 'number' || payload.exp < Date.now()) return null;
  if (!payload.state || !payload.verifier || !payload.returnTo) return null;
  return payload;
}

async function signPayload(payload, secret) {
  const body = base64UrlEncode(new TextEncoder().encode(JSON.stringify(payload)));
  const key = await hmacKey(secret);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  return `${body}.${base64UrlEncode(new Uint8Array(sig))}`;
}

async function verifyPayload(value, secret) {
  const dot = value.lastIndexOf('.');
  if (dot <= 0) return null;
  const body = value.slice(0, dot);
  const sig = value.slice(dot + 1);
  const key = await hmacKey(secret);
  const expected = base64UrlEncode(
    new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body))),
  );
  if (!(await fixedTimeEqual(sig, expected))) return null;
  try {
    const json = new TextDecoder().decode(base64UrlDecode(body));
    return JSON.parse(json);
  } catch (_) {
    return null;
  }
}

async function hmacKey(secret) {
  return crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

async function fixedTimeEqual(a, b) {
  const encoder = new TextEncoder();
  const [left, right] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(String(a))),
    crypto.subtle.digest('SHA-256', encoder.encode(String(b))),
  ]);
  if (typeof crypto.subtle.timingSafeEqual === 'function') {
    return crypto.subtle.timingSafeEqual(left, right);
  }
  const x = new Uint8Array(left);
  const y = new Uint8Array(right);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

function randomToken(bytes) {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return base64UrlEncode(buf);
}

async function sha256Base64Url(value) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return base64UrlEncode(new Uint8Array(digest));
}

async function sha256Hex(value) {
  const digest = new Uint8Array(
    await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)),
  );
  let hex = '';
  for (const byte of digest) hex += byte.toString(16).padStart(2, '0');
  return hex;
}

function base64UrlEncode(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function base64UrlDecode(value) {
  const pad = (4 - (value.length % 4)) % 4;
  const binary = atob(value.replaceAll('-', '+').replaceAll('_', '/') + '='.repeat(pad));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function textOrNull(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function clip(value, max) {
  if (!value) return null;
  return value.length > max ? value.slice(0, max) : value;
}

function tunisianPhone(value) {
  if (typeof value !== 'string') return null;
  let digits = value.replace(/[^\d+]/g, '');
  if (digits.startsWith('+')) digits = digits.slice(1);
  if (digits.startsWith('00216')) digits = digits.slice(5);
  else if (digits.startsWith('216') && digits.length === 11) digits = digits.slice(3);
  if (!/^[234579]\d{7}$/.test(digits)) return null;
  return `+216${digits}`;
}

function authJson(payload, status) {
  return new Response(JSON.stringify(payload), { status, headers: AUTH_CORS });
}
