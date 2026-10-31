// D17 orders. The price is decided here, never by the client. Validating an
// order is what grants the semesters.

import { userFromRequest } from './auth.js';
import { sendOrderConfirmation } from './mail.js';

const ORDER_CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
  'Cache-Control': 'no-store',
  'Content-Type': 'application/json',
};

const SEMESTERS = {
  y1_s1: 'MP1 Semestre 1',
  y1_s2: 'MP1 Semestre 2',
  y2_s1: 'MP2 Semestre 1',
  y2_s2: 'MP2 Semestre 2',
};

const PLANS = {
  semester: { amount: 19, label: null },
  year1: { amount: 29, products: ['y1_s1', 'y1_s2'], label: 'MP Année 1' },
  year2: { amount: 29, products: ['y2_s1', 'y2_s2'], label: 'MP Année 2' },
  full: { amount: 50, products: ['y1_s1', 'y1_s2', 'y2_s1', 'y2_s2'], label: 'Accès complet' },
};

export async function handleOrders(request, env, url) {
  try {
    if (!env.iloveprepa_db) return orderJson({ error: 'server' }, 503);
    const user = await userFromRequest(request, env);
    if (!user) return orderJson({ error: 'unauthorized' }, 401);

    if (url.pathname === '/api/orders' && request.method === 'GET') {
      return listMine(env, user);
    }
    if (url.pathname === '/api/orders' && request.method === 'POST') {
      return createOrder(request, env, user);
    }
    if (url.pathname === '/api/orders/claim' && request.method === 'POST') {
      return claimPaid(request, env, user);
    }
    if (url.pathname === '/api/orders/cancel' && request.method === 'POST') {
      return cancelMine(request, env, user);
    }
    return orderJson({ error: 'Not found' }, 404);
  } catch (err) {
    console.error('order failed:', err && err.message ? err.message : err);
    return orderJson({ error: 'Order failed' }, 500);
  }
}

async function listMine(env, user) {
  const rows = await env.iloveprepa_db
    .prepare(
      `SELECT id, plan_code, product_codes, amount_dt, payer_phone, status, created_at
       FROM orders WHERE user_id = ? ORDER BY created_at DESC LIMIT 50`,
    )
    .bind(user.id)
    .all();
  return orderJson({ orders: (rows.results || []).map(publicOrder) }, 200);
}

async function createOrder(request, env, user) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return orderJson({ error: 'invalid' }, 400);
  }
  const planCode = String((body && body.planCode) || '');
  const plan = PLANS[planCode];
  if (!plan) return orderJson({ error: 'invalid' }, 400);

  let products;
  if (planCode === 'semester') {
    const code = String((body && body.productCode) || '');
    if (!SEMESTERS[code]) return orderJson({ error: 'invalid' }, 400);
    products = [code];
  } else {
    products = plan.products;
  }

  const phone = tunisianPhone(body && body.payerPhone);
  if (!phone) return orderJson({ error: 'phone' }, 400);

  const pending = await env.iloveprepa_db
    .prepare(`SELECT id FROM orders WHERE user_id = ? AND status = 'in_progress' LIMIT 1`)
    .bind(user.id)
    .first();
  if (pending) {
    return orderJson(
      {
        error:
          'Vous avez déjà une commande en cours. Annulez-la ou attendez qu’elle soit validée avant d’en passer une autre.',
      },
      409,
    );
  }

  const owned = new Set(user.entitlements || []);
  const overlap = products.filter((code) => owned.has(code));
  if (overlap.length) {
    const names = overlap.map((code) => SEMESTERS[code] || code);
    const list =
      names.length === 1 ? names[0] : `${names.slice(0, -1).join(', ')} et ${names[names.length - 1]}`;
    const error =
      names.length === 1
        ? `Vous avez déjà l’accès ${list}. Cette commande n’est pas possible.`
        : `Vous avez déjà les accès ${list}. Cette commande n’est pas possible.`;
    return orderJson({ error }, 409);
  }

  const now = new Date().toISOString();
  const id = randomId();
  await env.iloveprepa_db
    .prepare(
      `INSERT INTO orders (
         id, user_id, plan_code, product_codes, amount_dt, payer_phone, status, created_at, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
    .bind(
      id,
      user.id,
      planCode,
      JSON.stringify(products),
      plan.amount,
      phone,
      'in_progress',
      now,
      now,
    )
    .run();

  const row = await env.iloveprepa_db
    .prepare(
      `SELECT id, plan_code, product_codes, amount_dt, payer_phone, status, created_at
       FROM orders WHERE id = ?`,
    )
    .bind(id)
    .first();
  const order = publicOrder(row);
  // Mail failure must not block the order.
  await sendOrderConfirmation(env, { order, user });
  return orderJson({ order }, 201);
}

async function cancelMine(request, env, user) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return orderJson({ error: 'invalid' }, 400);
  }
  const id = String((body && body.orderId) || '');
  const current = await env.iloveprepa_db
    .prepare('SELECT status FROM orders WHERE id = ? AND user_id = ?')
    .bind(id, user.id)
    .first();
  if (!current || current.status !== 'in_progress') {
    return orderJson({ error: 'not_found' }, 404);
  }
  await env.iloveprepa_db
    .prepare(
      `UPDATE orders SET status = 'cancelled', updated_at = ?
       WHERE id = ? AND user_id = ? AND status = 'in_progress'`,
    )
    .bind(new Date().toISOString(), id, user.id)
    .run();
  return orderJson({ ok: true }, 200);
}

async function claimPaid(request, env, user) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return orderJson({ error: 'invalid' }, 400);
  }
  const id = String((body && body.orderId) || '');
  const current = await env.iloveprepa_db
    .prepare('SELECT status FROM orders WHERE id = ? AND user_id = ?')
    .bind(id, user.id)
    .first();
  if (!current || current.status !== 'in_progress') {
    return orderJson({ error: 'not_found' }, 404);
  }
  return orderJson({ ok: true }, 200);
}

export function publicOrder(row) {
  const products = JSON.parse(row.product_codes);
  const plan = PLANS[row.plan_code];
  const label =
    row.plan_code === 'semester' ? SEMESTERS[products[0]] || products[0] : plan.label;
  return {
    id: row.id,
    planCode: row.plan_code,
    label,
    productCodes: products,
    amountDt: row.amount_dt,
    payerPhone: row.payer_phone,
    status: row.status,
    createdAt: row.created_at,
    email: row.email || undefined,
    name: row.name || undefined,
  };
}

/// Puts a cancelled order back in progress. Access is not granted.
export async function reopenOrder(db, order) {
  if (order.status !== 'cancelled') return false;
  await db
    .prepare(
      `UPDATE orders SET status = 'in_progress', updated_at = ?
       WHERE id = ? AND status = 'cancelled'`,
    )
    .bind(new Date().toISOString(), order.id)
    .run();
  return true;
}

export async function rejectOrder(db, order, adminId) {
  if (order.status !== 'in_progress' && order.status !== 'validated') return false;
  const now = new Date().toISOString();
  if (order.status === 'validated') await revokeOrderAccess(db, order, adminId, now);
  await db
    .prepare(
      `UPDATE orders SET status = 'cancelled', validated_by = NULL, updated_at = ?
       WHERE id = ? AND status = ?`,
    )
    .bind(now, order.id, order.status)
    .run();
  return true;
}

/// Undoes a validation: access from that order is revoked, and the order
/// returns to "en cours".
export async function unvalidateOrder(db, order, adminId) {
  if (order.status !== 'validated') return false;
  const now = new Date().toISOString();
  await revokeOrderAccess(db, order, adminId, now);
  await db
    .prepare(
      `UPDATE orders SET status = 'in_progress', validated_by = NULL, updated_at = ?
       WHERE id = ? AND status = 'validated'`,
    )
    .bind(now, order.id)
    .run();
  return true;
}

/// Removes the semesters of this order. A semester stays if another validated
/// order for the same client still includes it.
async function revokeOrderAccess(db, order, adminId, now) {
  const products = orderProducts(order);
  const others = await db
    .prepare(
      `SELECT product_codes FROM orders
       WHERE user_id = ? AND status = 'validated' AND id != ?`,
    )
    .bind(order.user_id, order.id)
    .all();
  const covered = new Set();
  for (const row of others.results || []) {
    for (const code of JSON.parse(row.product_codes)) covered.add(code);
  }
  for (const code of products) {
    if (covered.has(code)) continue;
    await db
      .prepare(
        `UPDATE entitlement_grants
         SET revoked_at = ?, revoked_by = ?
         WHERE user_id = ? AND product_code = ? AND revoked_at IS NULL`,
      )
      .bind(now, adminId, order.user_id, code)
      .run();
  }
}

function orderProducts(order) {
  if (order.plan_code === 'semester') return JSON.parse(order.product_codes);
  const plan = PLANS[order.plan_code];
  return plan && plan.products ? plan.products : JSON.parse(order.product_codes);
}

export async function grantOrder(db, order, adminId) {
  const products = orderProducts(order);
  const now = new Date().toISOString();
  for (const code of products) {
    const existing = await db
      .prepare(
        `SELECT id FROM entitlement_grants
         WHERE user_id = ? AND product_code = ? AND revoked_at IS NULL`,
      )
      .bind(order.user_id, code)
      .first();
    if (!existing) {
      await db
        .prepare(
          `INSERT INTO entitlement_grants (user_id, product_code, granted_by, granted_at)
           VALUES (?, ?, ?, ?)`,
        )
        .bind(order.user_id, code, adminId, now)
        .run();
    }
  }
  await db
    .prepare(
      `UPDATE orders SET status = 'validated', validated_by = ?, updated_at = ?
       WHERE id = ? AND status IN ('in_progress', 'cancelled')`,
    )
    .bind(adminId, now, order.id)
    .run();
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

function randomId() {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  let hex = '';
  for (const byte of bytes) hex += byte.toString(16).padStart(2, '0');
  return hex;
}

function orderJson(payload, status) {
  return new Response(JSON.stringify(payload), { status, headers: ORDER_CORS });
}
