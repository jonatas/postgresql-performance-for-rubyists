# PostgreSQL Performance Workshop

![img/intro.webp](img/intro.webp "A kawaii felt craft scene showing a cute PostgreSQL elephant wearing a graduation cap, surrounded by colorful felt data cubes and performance graphs, representing the learning journey ahead.")

## Jônatas Davi Paganini

* https://ideia.me  
* Staff Developer at BaxEnergy - A Yokogawa company
* ex-Timescale Dev Advocate

## Workshop Overview

* hands-on workshop
* essential concepts of PostgreSQL performance optimization
* from storage internals to advanced query optimization 

## What You'll Learn

* **Storage & Memory Management** - Understanding how PostgreSQL stores and manages data
* **Transaction Management** - ACID properties and concurrency control
* **Query Optimization** - Indexes, query plans, and performance tuning
* **TimescaleDB** - Time-series data optimization

## Workshop Structure

* **4 Main Modules** - Each with hands-on exercises
* **Interactive Polls** - Check your understanding
* **Real Examples** - Practical code and SQL
* **Performance Labs** - Hands-on optimization

## Role

> What's Your Role?

* Developer
* Database Admin/Specialist
* Student
* Other

## Experience

What's Your Experience Level?

* Beginner - Just getting started with PostgreSQL
* Intermediate - Some experience with databases
* Advanced - Regular PostgreSQL user
* Expert - Database administrator or performance specialist

# Setup

* First SQL Edition :tada:

## Requirements

* Docker Desktop (or Engine)
* psql (PostgreSQL client)
* Git

## Quick Start

```bash
git clone https://github.com/jonatas/postgresql-performance-workshops
cd postgresql-performance-workshops# Pull image (first run may take a few minutes)
docker pull timescale/timescaledb-ha:pg17# Run PostgreSQL (mapped to host port 5433)
docker run -d --rm -it \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DATABASE=workshop_db \
  -p 5433:5432 \
  timescale/timescaledb-ha:pg17
```

## Environment (.env)

```bash
cp env.example .env
```

Update `DATABASE_URL` to use the Docker port:

```
export DATABASE_URL=postgres://postgres:password@0.0.0.0:5433/workshop_db
```

## Verify Setup

```bash
# Using DATABASE_URL
psql "$DATABASE_URL" -c "SELECT version();"# Or run the full setup test
./setup/setup_sql.sh
```

## Troubleshooting

* Database does not exist:
```bash
psql postgres://postgres:password@0.0.0.0:5433/postgres -c "CREATE DATABASE workshop_db;"
```
* Port mismatch: ensure you connect on 5433
* Using fish shell: prefer `set VAR value` lines inside `.env`

# 1: Storage & Memory Management

![img/01_storage.webp](img/01_storage.webp "A kawaii felt craft scene depicting PostgreSQL storage as a cozy library where a cute elephant librarian organizes data pages in felt shelves, with TOAST storage shown as a separate felt storage room for oversized items.")


## Storage Fundamentals

PostgreSQL stores data in **pages** (8KB blocks) organized in **tablespaces**.

**Key Concepts**:
* **Heap** - Main storage area for table data
* **TOAST** - Storage for oversized values
* **Buffer Cache** - Memory management system
* **WAL** - Write-Ahead Log for durability

## TOAST (The Oversized-Attribute Storage Technique)

![img/toast.webp](img/toast.webp "A kawaii felt craft scene showing TOAST storage as a cute felt storage room where oversized data items are compressed and stored separately, with a PostgreSQL elephant managing the storage process.")

## What TOAST Does

* Compresses large field values
* Stores them in separate tables
* Transparent to users
* Automatic management

## Buffer Management

![img/buffers.webp](img/buffers.webp "A kawaii felt craft scene depicting memory management as a cozy library where a PostgreSQL elephant librarian organizes data pages in cute felt buffer pools. Frequently accessed pages are shown as books with happy faces in the front shelves.")

## Monitor buffer usage

```sql
SELECT blks_read, blks_hit
FROM pg_stat_database
WHERE datname = 'mydb';
```

## Buffer hit ratio

```sql
SELECT 
  round(100.0 * blks_hit / (blks_hit + blks_read), 2) as hit_ratio
FROM pg_stat_database;
```

## WAL (Write-Ahead Log)

* Ensures Data Durability
* Logs changes before writing to data files
* Enables crash recovery
* Supports replication
* Critical for ACID compliance

## Check WAL settings

```sql
SHOW wal_level;
SHOW synchronous_commit;
SHOW checkpoint_timeout;
```

# 2: Transaction Management

![img/02_transactions.webp](img/02_transactions.webp "A kawaii felt craft scene showing ACID properties as four adorable cube characters representing Atomicity, Consistency, Isolation, and Durability, all being conducted by a cute PostgreSQL elephant in a felt transaction environment.")

## Question

Which ACID property ensures that transactions are all-or-nothing?

* Atomicity
* Consistency  
* Isolation
* Durability

## ACID Properties Deep Dive

![img/acid.webp](img/acid.webp "A kawaii felt craft scene showing four adorable cube characters representing ACID properties. An Atomicity cube wearing a referee outfit, a Consistency cube with a balance scale, an Isolation cube with headphones, and a Durability cube with a shield, all being conducted by a cute PostgreSQL elephant.")

## ACID Breakdown

* **Atomicity** - All-or-nothing execution
* **Consistency** - Valid data only
* **Isolation** - Concurrent transactions don't interfere
* **Durability** - Committed changes are permanent

## Transaction Isolation Levels

* PostgreSQL Supports
* **Read Committed** (default)
* **Repeatable Read**
* **Serializable**

## Example: Read Committed (default)
```sql
BEGIN;
SELECT balance FROM accounts WHERE id = 1;  -- Can see other commits
SELECT pg_sleep(10); -- Simulate delay (in real scenario, another transaction commits here)
SELECT balance FROM accounts WHERE id = 1;  -- Balance might have changed!
COMMIT;
```
## Example: Repeatable Read
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE id = 1;  -- Consistent view
SELECT pg_sleep(10); -- Simulate delay (in real scenario, another transaction commits here)
SELECT balance FROM accounts WHERE id = 1;  -- Same balance throughout transaction
COMMIT;
```

## MVCC (Multi-Version Concurrency Control)

* Each transaction sees a consistent snapshot
* Updates create new row versions
* Old versions remain for other transactions
* Automatic cleanup via VACUUM

## MVCC Benefits

* No read locks needed
* High concurrency
* Consistent reads
* Automatic conflict resolution

# 3: Query Optimization

![img/03_queries.webp](img/03_queries.webp "A kawaii felt craft scene depicting query optimization as a cute felt detective elephant examining query plans with a magnifying glass, surrounded by colorful index structures and performance graphs.")

## Query Performance Experience

What's your level?

* Never - I just write queries
* Sometimes - When things are slow
* Regularly - Part of my routine
* Always - Performance is critical

## Index Types Overview

* **B-tree** - Default, equality and range queries
* **BRIN** - Block Range Index for time-series
* **GiST** - Geometric/geographic data
* **GIN** - Full-text search and arrays

## B-tree Indexes

```sql
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_composite ON orders(user_id, created_at);
CREATE UNIQUE INDEX idx_users_unique_email ON users(email);
```

**When to Use**:
* Equality comparisons (=)
* Range queries (<, >, BETWEEN)
* Pattern matching (LIKE 'prefix%')
* ORDER BY operations

## BRIN Indexes

```sql
CREATE INDEX idx_events_time
  ON events 
  USING brin(created_at);
```

BRIN with custom page range

```sql
CREATE INDEX idx_events_time_brin
  ON events 
  USING brin(created_at)
   WITH (pages_per_range = 128);
```

## BRIN Advantages

* Very small size (< 1% of table)
* Great for append-only data
* Efficient range queries
* Low maintenance overhead

# Query Plan Analysis

![img/query_plan.webp](img/query_plan.webp "A kawaii felt craft scene showing query plan analysis as a cute felt detective elephant examining a roadmap of database operations, with colorful felt nodes representing different query execution steps.")

## EXPLAIN `<your query>`

```sql
EXPLAIN
 SELECT * 
 FROM users 
 WHERE email = 'test@example.com';
```

> Does not run the query

## EXPLAIN ANALYZE `<your query>`

```sql
EXPLAIN ANALYZE
 SELECT * 
 FROM users
 WHERE email = 'test@example.com';
```
> Runs and add execution statistics

## EXPLAIN BUFFERS

```sql
EXPLAIN (ANALYZE, BUFFERS) 
 SELECT *
 FROM users
 WHERE email = 'test@example.com';
```

# 4: TimescaleDB

![img/04_timescaledb.webp](img/04_timescaledb.webp "A kawaii felt craft scene depicting TimescaleDB as a cute felt time machine with a PostgreSQL elephant, showing automatic partitioning and time-series optimization with colorful felt data chunks.")

## Timescaledb is a Postgresql Extension

```sql
CREATE EXTENSION IF NOT EXISTS timescaledb;
```

## TS Workload

> How much time-series data do you work with?

* None - Regular relational data only
* Some - Occasional time-based queries
* Lots - Time-series is important
* Everything - Pure time-series applications

## TimescaleDB Overview

* Built on PostgreSQL
* Automatic time-based partitioning
* Continuous aggregates
* SQL compatibility
* Time-series optimizations

## Hypertables

**Automatic Time Partitioning**:

```sql
SELECT create_hypertable(
  'measurements',
  'time',
   chunk_time_interval => INTERVAL '1 day');

SELECT show_chunks('measurements');

SELECT add_compression_policy('measurements', 
  INTERVAL '7 days');
```
# Continuous Aggregates

![img/continuous_aggregates.webp](img/continuous_aggregates.webp "A kawaii felt craft scene depicting continuous aggregates as cute calculator characters doing group hugs. Shows the PostgreSQL elephant orchestrating automatic updates while felt data points combine into summary hearts.")

## Materialized views

```sql
CREATE MATERIALIZED VIEW measurements_hourly
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) as bucket,
       device_id,
       avg(temperature) as avg_temp,
       max(temperature) as max_temp
FROM measurements
GROUP BY bucket, device_id;
```

## Partial refresh continuous aggregates

```sql
SELECT refresh_continuous_aggregates(
  'measurements_hourly',
   now() - INTERVAL '1 day',
   now() - INTERVAL '1 hour')
```

## Automatic refresh with policies

```sql
SELECT add_continuous_aggregate_policy('measurements_hourly',
  start_offset => INTERVAL '3 hours',
  end_offset => INTERVAL '1 hour',
  schedule_interval => INTERVAL '1 hour');
```

# Time-Series Queries

![img/time_series.webp](img/time_series.webp "A kawaii felt craft scene showing time-series analysis as a cute felt timeline with colorful data points, where a PostgreSQL elephant is analyzing trends and patterns in the felt data stream.")

## The `time_bucket` function

```sql
SELECT time_bucket('1 hour', time) as hour,
       avg(temperature) as avg_temp
FROM measurements
WHERE time > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour;
```### The `time_bucket_gapfill` function

```sql
SELECT time_bucket_gapfill('1 hour', time) as hour,
       avg(temperature) as avg_temp,
       count(*) as readings
FROM measurements
WHERE time > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour;
```

# Lab Setup

**What We'll Cover**:
* Storage optimization
* Index strategy
* Query tuning
* TimescaleDB features

## Exercise 1: Column Order

```sql
SELECT column_name, data_type,
       pg_column_size(column_name::text) as size
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;
```

## Exercise 2: TOAST Analysis

```sql
SELECT schemaname, tablename, attname,
       n_distinct, correlation
FROM pg_stats
WHERE tablename = 'users'
  AND attname LIKE '%data%';
```

## Exercise 3: Index Analysis
```sql
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND idx_is_unique IS FALSE;

 Check index usage
SELECT schemaname, tablename, indexname,
       idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

## Exercise 4: Query Plan Analysis

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT u.name, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2024-01-01'
GROUP BY u.id, u.name
HAVING COUNT(o.id) > 5
ORDER BY order_count DESC;
```

## Exercise 5: Hypertable Creation
```sql
CREATE TABLE sensor_data (
  time TIMESTAMPTZ NOT NULL,
  sensor_id TEXT NOT NULL,
  temperature DOUBLE PRECISION,
  humidity DOUBLE PRECISION
);

 Convert to hypertable
SELECT create_hypertable('sensor_data', 'time',
  chunk_time_interval => INTERVAL '1 day');

 Add compression
SELECT add_compression_policy('sensor_data',
  INTERVAL '7 days');
```

## Exercise 6: Continuous Aggregates

```sql
CREATE MATERIALIZED VIEW sensor_hourly
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) as bucket,
       sensor_id,
       avg(temperature) as avg_temp,
       avg(humidity) as avg_humidity
FROM sensor_data
GROUP BY bucket, sensor_id;

 Query the aggregate
SELECT bucket, sensor_id, avg_temp, avg_humidity
FROM sensor_hourly
WHERE bucket > NOW() - INTERVAL '24 hours'
ORDER BY bucket DESC;
```

# Performance Monitoring

**What to Monitor**:

* Query execution time
* Buffer hit ratio
* Index usage
* Lock contention
* Connection usage

## Monitoring Queries

```sql
SELECT datname, 
  xact_commit, xact_rollback,
  blks_read, blks_hit,
  tup_returned, tup_fetched,
  tup_inserted
FROM pg_stat_database
WHERE datname = current_database();
```

## Monitoring Table Statistics

```sql
SELECT schemaname, relname,
       seq_scan, seq_tup_read,
       idx_scan, idx_tup_fetch
FROM pg_stat_user_tables
ORDER BY seq_scan DESC;
```

## Monitoring Inddex Statistics

```sql
SELECT schemaname, tablename, indexname,
       idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```
## Storage and Memory Checklist

* [ ] Monitor buffer hit ratio (>95%)
* [ ] Check TOAST usage
* [ ] Review VACUUM frequency
* [ ] Optimize column order

## Indexes checklist

* [ ] Remove unused indexes
* [ ] Add missing indexes
* [ ] Consider BRIN for time-series
* [ ] Monitor index size

## Queries checklist

* [ ] Use EXPLAIN ANALYZE
* [ ] Avoid N+1 queries
* [ ] Optimize JOINs
* [ ] Use appropriate data types

## TimescaleDB

* [ ] Set chunk intervals
* [ ] Configure compression
* [ ] Use continuous aggregates
* [ ] Implement retention policies

# Advanced Topics

**When to Partition**:

* Tables > 100GB
* Time-based data retention
* Different storage policies
* Performance optimization

## Partition by `RANGE`

```sql
CREATE TABLE events (
  id BIGINT,
  created_at TIMESTAMP,
  data JSONB
) PARTITION BY RANGE (created_at);
```

## Partition by `LIST`

```sql
CREATE TABLE orders (
  id BIGINT,
  status TEXT,
  data JSONB
) PARTITION BY LIST (status);
```

## Hash partitioning

```sql
CREATE TABLE users (
  id BIGINT,
  email TEXT,
  data JSONB
) PARTITION BY HASH (id);
```

## Materialized Views

**When to Use**:
* Complex, expensive queries
* Frequently accessed reports
* Data warehouse scenarios
* Periodic analytics

## Example Materialized view

```sql
CREATE MATERIALIZED VIEW daily_order_stats AS
SELECT DATE_TRUNC('day', created_at) as date,
       COUNT(*) as order_count,
       SUM(total) as total_sales
FROM orders
GROUP BY 1
WITH DATA;
```

Then Refresh

```sql
REFRESH MATERIALIZED VIEW daily_order_stats;
```

## Window Functions

**Advanced Analytics**:
```sql
SELECT *,
       SUM(amount) OVER (
         ORDER BY created_at
         ROWS BETWEEN UNBOUNDED PRECEDING 
         AND CURRENT ROW
       ) as running_total
FROM transactions;
```

## Ranking within groups

```sql
SELECT *,
       ROW_NUMBER() OVER (
         PARTITION BY department_id 
         ORDER BY salary DESC
       ) as salary_rank
FROM employees;
```

# Workshop Wrap-Up 🎉

**What We Covered**:
* Storage internals and optimization
* Transaction management and ACID
* Query optimization and indexing
* TimescaleDB for time-series

## Performance Mindset

**Remember**:
* Measure before optimizing
* Understand the data
* Use appropriate tools
* Monitor continuously
* Test thoroughly

## Resources

**Learning Resources**:
* PostgreSQL Official Documentation
* TimescaleDB Documentation
* Database Performance Tuning

## Next Steps

**Practice Projects**:

* Build a monitoring dashboard
* Optimize existing queries
* Implement TimescaleDB
* Create performance benchmarks

## Last question

How do you feel about PostgreSQL performance optimization now?

* Beginner - I understand the concepts
* Intermediate - I can apply the techniques
* Advanced - I can optimize complex systems
* Expert - I can teach others

## Thank You 🫶🏼

* https://github.com/jonatas/postgresql-performance-workshops
* https://ideia.me
* https://www.linkedin.com/in/jonatasdp/

> Thanks **TigerData** for the support

## Bye

![img/intro.webp](img/intro.webp "A kawaii felt craft scene showing a cute PostgreSQL elephant wearing a graduation cap, surrounded by colorful felt data cubes and performance graphs, representing the successful completion of the learning journey.")
