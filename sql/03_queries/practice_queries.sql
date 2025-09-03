-- Practice Queries (idempotent)
CREATE TABLE IF NOT EXISTS users (
  id serial PRIMARY KEY,
  email text UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  id serial PRIMARY KEY,
  user_id int REFERENCES users(id),
  total numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

TRUNCATE TABLE orders RESTART IDENTITY;
TRUNCATE TABLE users RESTART IDENTITY CASCADE;

INSERT INTO users (email) SELECT 'user'||g||'@example.com' FROM generate_series(1,1000) g;
INSERT INTO orders (user_id, total)
SELECT (random()*999 + 1)::int, (random()*100)::numeric
FROM generate_series(1,5000);

\echo 'Index and query examples'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM users WHERE email = 'user500@example.com';
CREATE INDEX IF NOT EXISTS idx_orders_user_id_created_at ON orders(user_id, created_at);
EXPLAIN (ANALYZE, BUFFERS)
SELECT u.id, COUNT(o.id) cnt
FROM users u LEFT JOIN orders o ON o.user_id = u.id
GROUP BY u.id
ORDER BY cnt DESC
LIMIT 10;

