-- Advanced Queries (idempotent)
\echo 'CTEs and window functions'
WITH order_totals AS (
  SELECT user_id, COUNT(*) AS order_count, SUM(total) AS total_spent
  FROM orders
  GROUP BY user_id
)
SELECT u.id, ot.order_count, ot.total_spent,
       RANK() OVER (ORDER BY ot.total_spent DESC) AS spender_rank
FROM users u
LEFT JOIN order_totals ot ON ot.user_id = u.id
ORDER BY spender_rank NULLS LAST
LIMIT 10;

\echo 'Pattern matching and partial indexes'
CREATE INDEX IF NOT EXISTS idx_users_email_prefix ON users (left(email, 5));
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM users WHERE email LIKE 'user1%';

