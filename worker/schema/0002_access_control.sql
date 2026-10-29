-- Access control: admin role + premium entitlements per product (semester).
--
-- Design: an append-only grant ledger (like how large SaaS products track
-- feature/seat entitlements) instead of a single mutable "is_premium" flag.
-- Every grant/revoke is its own row with who did it and when, so there is a
-- full audit trail (needed here since purchases are paid in cash and entered
-- manually by an admin). "Active" access for a product = a row for that user
-- + product_code with revoked_at IS NULL. Re-granting after a revoke just
-- inserts a new row; past rows are never deleted or edited.

ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'free';
-- role: 'free' | 'admin'

CREATE TABLE IF NOT EXISTS entitlement_grants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  product_code TEXT NOT NULL CHECK (product_code IN ('y1_s1', 'y1_s2', 'y2_s1', 'y2_s2')),
  granted_by TEXT NOT NULL,
  granted_at TEXT NOT NULL,
  revoked_by TEXT,
  revoked_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users (id),
  FOREIGN KEY (granted_by) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS idx_entitlements_user ON entitlement_grants (user_id);
-- Fast "does this user currently have product X" lookups.
CREATE INDEX IF NOT EXISTS idx_entitlements_active
  ON entitlement_grants (user_id, product_code)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_users_name ON users (name);
