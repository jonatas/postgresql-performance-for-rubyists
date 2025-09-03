-- TimescaleDB Setup (idempotent)
CREATE EXTENSION IF NOT EXISTS timescaledb;

DROP TABLE IF EXISTS measurements CASCADE;
CREATE TABLE measurements (
  time timestamptz NOT NULL,
  device_id text NOT NULL,
  temperature double precision,
  humidity double precision
);

SELECT create_hypertable('measurements', 'time', if_not_exists => TRUE);

INSERT INTO measurements (time, device_id, temperature, humidity)
SELECT now() - (g || ' minutes')::interval,
       'device-' || (1 + (random()*9)::int),
       15 + random()*10,
       30 + random()*20
FROM generate_series(0, 2000) g;

-- Continuous aggregate example
DROP MATERIALIZED VIEW IF EXISTS measurements_hourly;
CREATE MATERIALIZED VIEW measurements_hourly
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket,
       device_id,
       avg(temperature) AS avg_temp,
       max(temperature) AS max_temp
FROM measurements
GROUP BY bucket, device_id;

