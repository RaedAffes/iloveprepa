-- Collapse order states to in_progress, validated, cancelled.
-- pending_payment and payment_claimed become in_progress. rejected becomes cancelled.

CREATE TABLE orders_next (
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

INSERT INTO orders_next (
  id, user_id, plan_code, product_codes, amount_dt, payer_phone, status, created_at, updated_at, validated_by
)
SELECT
  id, user_id, plan_code, product_codes, amount_dt, payer_phone,
  CASE status
    WHEN 'validated' THEN 'validated'
    WHEN 'rejected' THEN 'cancelled'
    WHEN 'cancelled' THEN 'cancelled'
    ELSE 'in_progress'
  END,
  created_at, updated_at, validated_by
FROM orders;

DROP TABLE orders;
ALTER TABLE orders_next RENAME TO orders;

CREATE INDEX IF NOT EXISTS idx_orders_user ON orders (user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status, created_at);
