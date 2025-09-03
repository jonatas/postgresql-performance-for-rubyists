-- Transactions Exercises (idempotent)
\echo 'Setup: creating table tasks...'
CREATE TABLE IF NOT EXISTS tasks (
  id serial PRIMARY KEY,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  updated_at timestamptz NOT NULL DEFAULT now()
);

TRUNCATE TABLE tasks RESTART IDENTITY;
INSERT INTO tasks (title, status) VALUES
  ('Write docs', 'pending'),
  ('Review PR', 'pending');

\echo 'Exercise 1: Deadlock scenario (run in two sessions)'
\echo 'Session A:'
\echo 'BEGIN; UPDATE tasks SET status = ''in_progress'' WHERE id = 1;'
\echo 'Session B:'
\echo 'BEGIN; UPDATE tasks SET status = ''in_review'' WHERE id = 2;'
\echo 'Then: Session A -> UPDATE tasks SET status = ''done'' WHERE id = 2;'
\echo 'And:  Session B -> UPDATE tasks SET status = ''done'' WHERE id = 1;'
\echo 'Finally: ROLLBACK both sessions'

\echo 'Exercise 2: Explicit locking'
BEGIN;
SELECT * FROM tasks WHERE id = 1 FOR UPDATE;
SELECT pg_sleep(1);
UPDATE tasks SET status = 'done', updated_at = now() WHERE id = 1;
COMMIT;

\echo 'State after exercises:'
TABLE tasks;

