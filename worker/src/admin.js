// Admin-only endpoints: search users and grant/revoke premium entitlements
// (one per semester product). Every call requires a valid session for a user
// whose `role` is 'admin' — checked on every request, never cached.

import { userFromRequest } from './auth.js';
import { grantOrder, publicOrder, rejectOrder, reopenOrder, unvalidateOrder } from './orders.js';
import { sendOrderConfirmation } from './mail.js';

const ADMIN_CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Cache-Control, Pragma, Authorization',
  'Access-Control-Max-Age': '86400',
  'Cache-Control': 'no-store',
  'Content-Type': 'application/json',
};

export const PRODUCT_CODES = new Set(['y1_s1', 'y1_s2', 'y2_s1', 'y2_s2']);

export async function handleAdmin(request, env, url) {
  try {
    const admin = await requireAdmin(request, env);
    if (admin.error) return adminJson({ error: admin.error }, admin.status);

    if (url.pathname === '/api/admin/users' && request.method === 'GET') {
      return listUsers(env, url);
    }
    if (url.pathname === '/api/admin/entitlements' && request.method === 'POST') {
      return setEntitlement(request, env, admin.user);
    }
    if (url.pathname === '/api/admin/orders' && request.method === 'GET') {
      return listOrders(env, url);
    }
    if (url.pathname === '/api/admin/orders/validate' && request.method === 'POST') {
      return validateOrder(request, env, admin.user);
    }
    if (url.pathname === '/api/admin/orders/reject' && request.method === 'POST') {
      return rejectAdminOrder(request, env, admin.user);
    }
    if (url.pathname === '/api/admin/orders/reopen' && request.method === 'POST') {
      return reopenAdminOrder(request, env);
    }
    if (url.pathname === '/api/admin/orders/unvalidate' && request.method === 'POST') {
      return unvalidateAdminOrder(request, env, admin.user);
    }
    if (url.pathname === '/api/admin/orders/resend-mail' && request.method === 'POST') {
      return resendOrderMail(request, env);
    }
    return adminJson({ error: 'Not found' }, 404);
  } catch (err) {
    console.error('admin request failed:', err && err.message ? err.message : err);
    return adminJson({ error: 'Admin request failed' }, 500);
  }
}

async function requireAdmin(request, env) {
  if (!env.iloveprepa_db) return { error: 'server', status: 503 };
  const user = await userFromRequest(request, env);
  if (!user) return { error: 'unauthorized', status: 401 };
  if (user.role !== 'admin') return { error: 'forbidden', status: 403 };
  return { user };
}

async function listUsers(env, url) {
  const db = env.iloveprepa_db;
  const q = (url.searchParams.get('q') || '').trim().toLowerCase();
  const limit = Math.min(
    Math.max(parseInt(url.searchParams.get('limit') || '100', 10) || 100, 1),
    100,
  );

  // Digits-only form so "20 123 456", "20123456" and "+21620123456" all match
  // the stored +216XXXXXXXX value.
  const digits = q.replace(/\D/g, '');
  const rows = q
    ? await db
        .prepare(
          `SELECT id, email, email_verified, name, given_name, family_name, faculty,
                  phone, role, created_at, last_login_at FROM users
           WHERE lower(email) LIKE ? OR lower(name) LIKE ?
              OR lower(COALESCE(phone, '')) LIKE ?
              OR (? != '' AND replace(COALESCE(phone, ''), '+', '') LIKE ?)
           ORDER BY created_at DESC LIMIT ?`,
        )
        .bind(`%${q}%`, `%${q}%`, `%${q}%`, digits, `%${digits}%`, limit)
        .all()
    : await db
        .prepare(
          `SELECT id, email, email_verified, name, given_name, family_name, faculty,
                  phone, role, created_at, last_login_at FROM users
           ORDER BY created_at DESC LIMIT ?`,
        )
        .bind(limit)
        .all();

  const users = rows.results || [];
  const entitlementsByUser = await loadEntitlements(
    db,
    users.map((u) => u.id),
  );

  return adminJson(
    {
      users: users.map((u) => ({
        id: u.id,
        email: u.email,
        emailVerified: u.email_verified === 1,
        name: u.name,
        givenName: u.given_name,
        familyName: u.family_name,
        faculty: u.faculty,
        phone: u.phone,
        role: u.role || 'free',
        createdAt: u.created_at,
        lastLoginAt: u.last_login_at,
        entitlements: entitlementsByUser[u.id] || [],
      })),
    },
    200,
  );
}

async function loadEntitlements(db, userIds) {
  const map = {};
  if (userIds.length === 0) return map;
  const placeholders = userIds.map(() => '?').join(',');
  const rows = await db
    .prepare(
      `SELECT user_id, product_code FROM entitlement_grants
       WHERE revoked_at IS NULL AND user_id IN (${placeholders})`,
    )
    .bind(...userIds)
    .all();
  for (const row of rows.results || []) {
    (map[row.user_id] ??= []).push(row.product_code);
  }
  return map;
}

async function setEntitlement(request, env, admin) {
  const db = env.iloveprepa_db;
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return adminJson({ error: 'invalid' }, 400);
  }
  const userId = String((body && body.userId) || '').trim();
  const productCode = String((body && body.productCode) || '').trim();
  const action = String((body && body.action) || '').trim();
  if (!userId || !PRODUCT_CODES.has(productCode) || !['grant', 'revoke'].includes(action)) {
    return adminJson({ error: 'invalid' }, 400);
  }

  const target = await db.prepare('SELECT id FROM users WHERE id = ?').bind(userId).first();
  if (!target) return adminJson({ error: 'user_not_found' }, 404);

  const now = new Date().toISOString();
  if (action === 'grant') {
    const existing = await db
      .prepare(
        `SELECT id FROM entitlement_grants
         WHERE user_id = ? AND product_code = ? AND revoked_at IS NULL`,
      )
      .bind(userId, productCode)
      .first();
    if (!existing) {
      await db
        .prepare(
          `INSERT INTO entitlement_grants (user_id, product_code, granted_by, granted_at)
           VALUES (?, ?, ?, ?)`,
        )
        .bind(userId, productCode, admin.id, now)
        .run();
    }
  } else {
    await db
      .prepare(
        `UPDATE entitlement_grants SET revoked_at = ?, revoked_by = ?
         WHERE user_id = ? AND product_code = ? AND revoked_at IS NULL`,
      )
      .bind(now, admin.id, userId, productCode)
      .run();
  }

  const entitlements = await loadEntitlements(db, [userId]);
  return adminJson({ ok: true, entitlements: entitlements[userId] || [] }, 200);
}

const ORDER_STATUSES = new Set(['in_progress', 'validated', 'cancelled', 'all']);

async function listOrders(env, url) {
  const raw = (url.searchParams.get('status') || 'in_progress').trim().toLowerCase();
  const aliases = {
    payment_claimed: 'in_progress',
    pending_payment: 'in_progress',
    pending: 'in_progress',
    en_cours: 'in_progress',
    rejected: 'cancelled',
  };
  const status = ORDER_STATUSES.has(aliases[raw] || raw) ? aliases[raw] || raw : 'in_progress';
  const q = (url.searchParams.get('q') || '').trim().toLowerCase();
  const digits = q.replace(/\D/g, '');
  const where = [];
  const binds = [];
  if (status !== 'all') {
    where.push('o.status = ?');
    binds.push(status);
  }
  if (q) {
    where.push(`(
      lower(COALESCE(u.name, '')) LIKE ? OR
      lower(COALESCE(u.email, '')) LIKE ? OR
      lower(o.id) LIKE ? OR
      (? != '' AND replace(o.payer_phone, '+', '') LIKE ?)
    )`);
    const like = `%${q}%`;
    binds.push(like, like, like, digits, `%${digits}%`);
  }
  const sql = `SELECT o.id, o.plan_code, o.product_codes, o.amount_dt, o.payer_phone, o.status,
              o.created_at, u.email, u.name
       FROM orders o JOIN users u ON u.id = o.user_id
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY o.created_at DESC LIMIT 100`;
  const statement = env.iloveprepa_db.prepare(sql);
  const rows = binds.length ? await statement.bind(...binds).all() : await statement.all();
  return adminJson({ orders: (rows.results || []).map(publicOrder) }, 200);
}

async function validateOrder(request, env, admin) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return adminJson({ error: 'invalid' }, 400);
  }
  const id = String((body && body.orderId) || '');
  const order = await env.iloveprepa_db
    .prepare('SELECT * FROM orders WHERE id = ?')
    .bind(id)
    .first();
  if (!order || (order.status !== 'in_progress' && order.status !== 'cancelled')) {
    return adminJson({ error: 'not_found' }, 404);
  }
  await grantOrder(env.iloveprepa_db, order, admin.id);
  return adminJson({ ok: true }, 200);
}

async function reopenAdminOrder(request, env) {
  const order = await loadOrder(request, env);
  if (!order) return adminJson({ error: 'not_found' }, 404);
  const ok = await reopenOrder(env.iloveprepa_db, order);
  if (!ok) return adminJson({ error: 'not_found' }, 404);
  return adminJson({ ok: true }, 200);
}

async function rejectAdminOrder(request, env, admin) {
  const order = await loadOrder(request, env);
  if (!order) return adminJson({ error: 'not_found' }, 404);
  const ok = await rejectOrder(env.iloveprepa_db, order, admin.id);
  if (!ok) return adminJson({ error: 'not_found' }, 404);
  return adminJson({ ok: true }, 200);
}

async function unvalidateAdminOrder(request, env, admin) {
  const order = await loadOrder(request, env);
  if (!order) return adminJson({ error: 'not_found' }, 404);
  const ok = await unvalidateOrder(env.iloveprepa_db, order, admin.id);
  if (!ok) return adminJson({ error: 'not_found' }, 404);
  return adminJson({ ok: true }, 200);
}

async function resendOrderMail(request, env) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return adminJson({ error: 'invalid' }, 400);
  }
  const id = String((body && body.orderId) || '');
  const row = await env.iloveprepa_db
    .prepare(
      `SELECT o.*, u.email, u.name, u.given_name
       FROM orders o JOIN users u ON u.id = o.user_id
       WHERE o.id = ?`,
    )
    .bind(id)
    .first();
  if (!row) return adminJson({ error: 'not_found' }, 404);
  const order = publicOrder(row);
  const result = await sendOrderConfirmation(env, {
    order,
    user: { email: row.email, name: row.name, givenName: row.given_name },
    force: true,
  });
  return adminJson(result, result.ok ? 200 : 502);
}

async function loadOrder(request, env) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return null;
  }
  const id = String((body && body.orderId) || '');
  if (!id) return null;
  return env.iloveprepa_db.prepare('SELECT * FROM orders WHERE id = ?').bind(id).first();
}

function adminJson(payload, status) {
  return new Response(JSON.stringify(payload), { status, headers: ADMIN_CORS });
}
