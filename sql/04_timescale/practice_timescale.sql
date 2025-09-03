-- Timescale practice
\echo 'Hypertable info'
SELECT * FROM timescaledb_information.hypertables;

\echo 'Show chunks'
SELECT show_chunks('measurements') LIMIT 10;

\echo 'Aggregate over time'
SELECT time_bucket('1 hour', time) AS hour, avg(temperature) AS avg_temp
FROM measurements
WHERE time > now() - interval '1 day'
GROUP BY hour
ORDER BY hour;

