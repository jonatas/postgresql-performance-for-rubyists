# ⏰ TimescaleDB - SQL Edition

This module demonstrates TimescaleDB features: hypertables, chunks, and continuous aggregates.

Ensure your Docker image is `timescale/timescaledb-ha:pg17` and extension is available.

## Running the scripts

```bash
psql -h 0.0.0.0 -p 5433 -U postgres -d workshop_db -f sql/04_timescale/timescale_setup.sql
psql -h 0.0.0.0 -p 5433 -U postgres -d workshop_db -f sql/04_timescale/practice_timescale.sql
psql -h 0.0.0.0 -p 5433 -U postgres -d workshop_db -f sql/04_timescale/parallel_execution_test.sql
```


