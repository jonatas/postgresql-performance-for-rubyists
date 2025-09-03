-- Transaction Lab (idempotent)
\echo 'Setting up accounts table...'
CREATE TABLE IF NOT EXISTS accounts (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE,
  balance numeric NOT NULL DEFAULT 0
);

TRUNCATE TABLE accounts RESTART IDENTITY;
INSERT INTO accounts (name, balance) VALUES
  ('Alice', 1000),
  ('Bob', 1000)
ON CONFLICT (name) DO UPDATE SET balance = excluded.balance;

\echo 'Initial state:'
TABLE accounts;

\echo 'Read Committed demo (open another psql session to observe concurrent update)'
BEGIN;
SELECT * FROM accounts ORDER BY id;
SELECT pg_sleep(2);
SELECT * FROM accounts ORDER BY id;
ROLLBACK;

\echo 'Repeatable Read snapshot demo'
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM accounts ORDER BY id;
SELECT pg_sleep(2);
SELECT * FROM accounts ORDER BY id;
ROLLBACK;

\echo 'Transfer with rollback'
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE name = 'Alice';
UPDATE accounts SET balance = balance + 100 WHERE name = 'Bob';
ROLLBACK;
\echo 'After rollback:'
TABLE accounts;

\echo 'Transfer with commit'
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE name = 'Alice';
UPDATE accounts SET balance = balance + 100 WHERE name = 'Bob';
COMMIT;
\echo 'Final state:'
TABLE accounts;

