-- Query Optimization Lab (idempotent)
\echo 'Setup: ensuring data exists'
-- Reuse users/orders from practice_queries.sql
-- Create missing index for selective predicate
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);

\echo 'Lab 1: Compare sequential vs index scan'
SET enable_seqscan = on;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE created_at > now() - interval '1 day';
SET enable_seqscan = off;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE created_at > now() - interval '1 day';
SET enable_seqscan = on;

\echo 'Lab 2: Composite index usage'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 1 ORDER BY created_at DESC LIMIT 50;

\echo 'Lab 3: Join order and statistics'
ANALYZE;
EXPLAIN (ANALYZE, BUFFERS)
SELECT u.email, o.total
FROM orders o JOIN users u ON u.id = o.user_id
WHERE o.total > 50
ORDER BY o.created_at DESC
LIMIT 20;

