-- All-time visits/downloads totals served by /api/stats. They are never reset:
-- each increment just adds to them. `month` (UTC key "YYYY-MM") is only the
-- stamp of the month whose share is currently accumulating, and
-- counters.visits/downloads == SUM(monthly_counts) at all times.
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

-- Monthly breakdown: one row per calendar month (UTC key "YYYY-MM") with that
-- month's own visits/downloads. The row of the in-progress month is kept in sync
-- at the monthly rollover, where its own slice is archived and the stamp moves
-- forward. Sum of the table always equals the all-time counters.
CREATE TABLE IF NOT EXISTS monthly_counts (
  month TEXT PRIMARY KEY,
  visits INTEGER NOT NULL DEFAULT 0,
  downloads INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT
);

-- Migration from the old per-month counters to the all-time ones: archive the
-- current month (whose counters are still that month's running totals), then
-- fold every archived month into the counters. Idempotent — safe to re-run.
INSERT INTO monthly_counts (month, visits, downloads, updated_at)
SELECT month, visits, downloads, datetime('now')
FROM counters WHERE id = 1 AND month IS NOT NULL
ON CONFLICT(month) DO UPDATE SET
  visits = excluded.visits,
  downloads = excluded.downloads,
  updated_at = excluded.updated_at;

UPDATE counters SET
  visits = COALESCE((SELECT SUM(visits) FROM monthly_counts), 0),
  downloads = COALESCE((SELECT SUM(downloads) FROM monthly_counts), 0)
WHERE id = 1;