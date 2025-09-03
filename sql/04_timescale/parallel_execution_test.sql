-- Parallel execution test
SET max_parallel_workers_per_gather = 4;
EXPLAIN (ANALYZE, BUFFERS)
SELECT device_id, count(*)
FROM measurements
GROUP BY device_id;

