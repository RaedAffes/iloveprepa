-- Cash / D17 orders. Access is not granted on creation. An admin validates
-- the payment, which writes the entitlement rows.
-- status: in_progress | validated | cancelled

CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plan_code TEXT NOT NULL CHECK (plan_code IN ('semester', 'year1', 'year2', 'full')),
  product_codes TEXT NOT NULL,
  amount_dt INTEGER NOT NULL,
  payer_phone TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('in_progress', 'validated', 'cancelled')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  validated_by TEXT,
  FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS idx_orders_user ON orders (user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status, created_at);
