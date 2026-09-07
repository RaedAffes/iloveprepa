CREATE TABLE IF NOT EXISTS counters (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  visits INTEGER NOT NULL DEFAULT 0,
  downloads INTEGER NOT NULL DEFAULT 0,
  month TEXT,
  updated_at TEXT
);

INSERT INTO counters (id, visits, downloads)
SELECT 1, 0, 0
WHERE NOT EXISTS (SELECT 1 FROM counters WHERE id = 1);

-- Monthly archives: one row per calendar month (UTC key "YYYY-MM") with that
-- month's final visits/downloads totals, captured at the monthly rollover.
CREATE TABLE IF NOT EXISTS monthly_counts (
  month TEXT PRIMARY KEY,
  visits INTEGER NOT NULL DEFAULT 0,
  downloads INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT
);