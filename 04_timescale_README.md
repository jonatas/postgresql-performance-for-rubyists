# TimescaleDB Workshop

This section focuses on understanding and leveraging TimescaleDB, a powerful time-series database extension for PostgreSQL. For definitions of terms used in this module, refer to our [Glossary](GLOSSARY.md).

![img/04_timescaledb.webp](img/04_timescaledb.webp "A kawaii felt craft scene showing the PostgreSQL elephant riding a cute felt clock with clock hands shaped like magic wands, surfing through waves of time-series data represented as adorable felt bubbles with timestamp faces. Tiny felt cubes (chunks) with sleepy faces stack themselves automatically into neat rows. A felt temperature chart in the background shows a line graph made of heart beats. Continuous aggregates are represented by felt calculator characters doing group hugs. The scene includes a kawaii vacuum cleaner with eyes cleaning up old data chunks. Style: Kawaii, Hello Kitty-inspired, handmade felt craft aesthetic, time-themed pastels")

## Prerequisites

Before starting this module, ensure you understand:
- [Query Plan](GLOSSARY.md#query-plan)
- [Partition](GLOSSARY.md#partition)
- [Materialized View](GLOSSARY.md#materialized-view)
- [Query Optimization](03_queries_README.md#query-optimization)

## Related Concepts

- [Index](GLOSSARY.md#index)
- [Statistics](GLOSSARY.md#statistics)
- [BRIN Index](GLOSSARY.md#brin-index)

## Introduction to Hypertables

[Hypertables](GLOSSARY.md#hypertable) are the foundation of TimescaleDB's time-series optimization. They automatically partition your data into chunks based on time intervals, providing several benefits:

![Hypertables example](https://assets.timescale.com/docs/images/getting-started/hypertables-chunks.webp)

1. **Automatic Partitioning**
   - Time-based chunking for efficient data management
   - Transparent query optimization
   - Automatic chunk creation and management

2. **Query Performance**
   - Chunk exclusion for faster time-range queries
   - Parallel query execution across chunks
   - Optimized index usage per chunk

3. **Data Management**
   - Efficient compression of older data
   - Automated retention policies
   - Easy backup and maintenance

## Learning Path

### 1. Understanding TimescaleDB Fundamentals
Start with setup to understand:
- Hypertable creation and configuration
- Continuous aggregate setup
- Compression policies
- Data retention strategies

### 2. TimescaleDB Features in Practice
Work through examples:
1. Execute time-bucket queries
2. Analyze query performance with EXPLAIN
3. Work with continuous aggregates
4. Manage chunks and compression
5. Implement advanced time-series analytics

## Key Features and Examples

### 1. Creating Hypertables

```sql
-- Create a regular table
CREATE TABLE measurements (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION
);

-- Convert to hypertable
SELECT create_hypertable('measurements', 'time');

-- Create hypertable with custom chunk interval
SELECT create_hypertable(
    'measurements', 
    'time', 
    chunk_time_interval => INTERVAL '1 day'
);

-- Create hypertable with partitioning
SELECT create_hypertable(
    'measurements', 
    'time', 
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);
```

### 2. Continuous Aggregates
```sql
-- Create a continuous aggregate
CREATE MATERIALIZED VIEW hourly_stats
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', time) AS bucket,
    device_id,
    AVG(temperature) as avg_temp,
    MAX(temperature) as max_temp,
    MIN(temperature) as min_temp,
    COUNT(*) as reading_count
FROM measurements
GROUP BY bucket, device_id;

-- Create with refresh policy
SELECT add_continuous_aggregate_policy('hourly_stats',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

### 3. Compression
```sql
-- Enable compression on hypertable
ALTER TABLE measurements SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Add compression policy
SELECT add_compression_policy('measurements', INTERVAL '7 days');

-- Check compression status
SELECT 
    hypertable_name,
    compression_enabled,
    uncompressed_total_size,
    compressed_total_size
FROM timescaledb_information.compression_settings;
```

## Time-Series Query Patterns

### **Time Bucketing**
```sql
-- Basic time bucketing
SELECT 
    time_bucket('1 hour', time) AS hour,
    device_id,
    AVG(temperature) as avg_temp
FROM measurements
WHERE time > NOW() - INTERVAL '24 hours'
GROUP BY hour, device_id
ORDER BY hour;

-- Custom time buckets
SELECT 
    time_bucket('15 minutes', time) AS bucket,
    device_id,
    COUNT(*) as readings
FROM measurements
WHERE time > NOW() - INTERVAL '1 day'
GROUP BY bucket, device_id
ORDER BY bucket;
```

### **Window Functions with Time**
```sql
-- Moving averages
SELECT 
    time,
    device_id,
    temperature,
    AVG(temperature) OVER (
        PARTITION BY device_id 
        ORDER BY time 
        ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    ) as moving_avg_5
FROM measurements
WHERE time > NOW() - INTERVAL '1 day'
ORDER BY device_id, time;

-- Time-based ranking
SELECT 
    time,
    device_id,
    temperature,
    ROW_NUMBER() OVER (
        PARTITION BY device_id 
        ORDER BY temperature DESC
    ) as temp_rank
FROM measurements
WHERE time > NOW() - INTERVAL '1 day';
```

### **Gap Filling**
```sql
-- Fill gaps in time series
SELECT 
    time_bucket('1 hour', time) AS bucket,
    device_id,
    AVG(temperature) as avg_temp,
    COUNT(*) as readings
FROM measurements
WHERE time > NOW() - INTERVAL '7 days'
GROUP BY bucket, device_id
ORDER BY bucket;

-- Use generate_series for complete time range
WITH time_series AS (
    SELECT generate_series(
        date_trunc('hour', NOW() - INTERVAL '7 days'),
        date_trunc('hour', NOW()),
        '1 hour'::interval
    ) AS bucket
)
SELECT 
    ts.bucket,
    m.device_id,
    AVG(m.temperature) as avg_temp
FROM time_series ts
LEFT JOIN measurements m ON time_bucket('1 hour', m.time) = ts.bucket
GROUP BY ts.bucket, m.device_id
ORDER BY ts.bucket;
```

## Chunk Management

### **Chunk Information**
```sql
-- View all chunks
SELECT 
    hypertable_name,
    chunk_name,
    range_start,
    range_end,
    is_compressed,
    chunk_size,
    index_size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'measurements'
ORDER BY range_start;

-- Chunk statistics
SELECT 
    chunk_name,
    pg_size_pretty(chunk_size) as size,
    pg_size_pretty(index_size) as index_size,
    is_compressed
FROM timescaledb_information.chunks
WHERE hypertable_name = 'measurements'
ORDER BY chunk_size DESC;
```

### **Chunk Operations**
```sql
-- Drop chunks older than 30 days
SELECT drop_chunks('measurements', older_than => INTERVAL '30 days');

-- Drop chunks in a specific time range
SELECT drop_chunks('measurements', 
    older_than => '2023-01-01'::timestamp,
    newer_than => '2023-02-01'::timestamp);

-- Compress chunks manually
SELECT compress_chunk(chunk_name)
FROM timescaledb_information.chunks
WHERE hypertable_name = 'measurements' 
  AND NOT is_compressed
  AND range_end < NOW() - INTERVAL '7 days';
```

## Continuous Aggregates

### **Creating and Managing**
```sql
-- Create continuous aggregate
CREATE MATERIALIZED VIEW daily_stats
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', time) AS day,
    device_id,
    AVG(temperature) as avg_temp,
    MAX(temperature) as max_temp,
    MIN(temperature) as min_temp,
    COUNT(*) as readings
FROM measurements
GROUP BY day, device_id;

-- Refresh continuous aggregate
CALL refresh_continuous_aggregate('daily_stats', '2023-01-01', '2023-01-31');

-- Add automatic refresh policy
SELECT add_continuous_aggregate_policy('daily_stats',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');
```

### **Querying Continuous Aggregates**
```sql
-- Query the continuous aggregate
SELECT 
    day,
    device_id,
    avg_temp,
    max_temp,
    min_temp,
    readings
FROM daily_stats
WHERE day > NOW() - INTERVAL '30 days'
ORDER BY day DESC;

-- Compare with raw data
SELECT 
    'raw' as source,
    COUNT(*) as count,
    AVG(temperature) as avg_temp
FROM measurements
WHERE time > NOW() - INTERVAL '7 days'
UNION ALL
SELECT 
    'aggregate' as source,
    COUNT(*) as count,
    AVG(avg_temp) as avg_temp
FROM daily_stats
WHERE day > NOW() - INTERVAL '7 days';
```

## Compression and Retention

### **Compression Configuration**
```sql
-- Enable compression with custom settings
ALTER TABLE measurements SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC',
    timescaledb.compress_chunk_time_interval = '7 days'
);

-- Check compression settings
SELECT 
    hypertable_name,
    compression_enabled,
    compress_segmentby,
    compress_orderby
FROM timescaledb_information.compression_settings;

-- Compression statistics
SELECT 
    chunk_name,
    pg_size_pretty(before_compression_total_bytes) as before_size,
    pg_size_pretty(after_compression_total_bytes) as after_size,
    compression_ratio
FROM timescaledb_information.compression_settings;
```

### **Retention Policies**
```sql
-- Add retention policy (drop data older than 90 days)
SELECT add_retention_policy('measurements', INTERVAL '90 days');

-- Add retention policy with cascade to continuous aggregates
SELECT add_retention_policy('measurements', INTERVAL '90 days', cascade_to_materializations => TRUE);

-- Check retention policies
SELECT 
    hypertable_name,
    retention_period,
    cascade_to_materializations
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_retention';
```

## Performance Optimization

### **Indexing Strategies**
```sql
-- Create time-based index
CREATE INDEX idx_measurements_time ON measurements (time DESC);

-- Create composite index for device queries
CREATE INDEX idx_measurements_device_time ON measurements (device_id, time DESC);

-- Create BRIN index for large time-series data
CREATE INDEX idx_measurements_time_brin ON measurements USING BRIN (time);

-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read
FROM pg_stat_user_indexes
WHERE tablename LIKE '%measurements%'
ORDER BY idx_scan DESC;
```

### **Query Performance Analysis**
```sql
-- Analyze query performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    time_bucket('1 hour', time) AS hour,
    device_id,
    AVG(temperature) as avg_temp
FROM measurements
WHERE time > NOW() - INTERVAL '24 hours'
GROUP BY hour, device_id
ORDER BY hour;

-- Compare with continuous aggregate
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    time_bucket('1 hour', day) AS hour,
    device_id,
    AVG(avg_temp) as avg_temp
FROM daily_stats
WHERE day > NOW() - INTERVAL '24 hours'
GROUP BY hour, device_id
ORDER BY hour;
```

## Monitoring and Maintenance

### **System Information**
```sql
-- Check TimescaleDB version
SELECT default_version, installed_version FROM pg_available_extensions WHERE name = 'timescaledb';

-- View all hypertables
SELECT 
    hypertable_schema,
    hypertable_name,
    num_dimensions,
    num_chunks,
    compression_enabled
FROM timescaledb_information.hypertables;

-- Check background jobs
SELECT 
    job_id,
    proc_name,
    schedule_interval,
    last_run_started_at,
    last_successful_finish
FROM timescaledb_information.jobs
ORDER BY last_run_started_at DESC;
```

### **Maintenance Tasks**
```sql
-- Run maintenance
SELECT run_job(job_id) 
FROM timescaledb_information.jobs 
WHERE proc_name = 'policy_compression';

-- Check for compression opportunities
SELECT 
    chunk_name,
    range_start,
    range_end,
    is_compressed
FROM timescaledb_information.chunks
WHERE hypertable_name = 'measurements'
  AND NOT is_compressed
  AND range_end < NOW() - INTERVAL '7 days'
ORDER BY range_start;
```

## Best Practices

### **Design Considerations**
1. **Choose appropriate chunk intervals**: Balance between query performance and maintenance overhead
2. **Use continuous aggregates**: Pre-compute common aggregations
3. **Implement compression**: Reduce storage costs for historical data
4. **Set up retention policies**: Automatically manage data lifecycle
5. **Monitor performance**: Use EXPLAIN ANALYZE regularly

### **Query Optimization**
```sql
-- Use time-based WHERE clauses
SELECT * FROM measurements 
WHERE time > NOW() - INTERVAL '1 day'  -- Good: uses time index
  AND device_id = 'sensor_001';

-- Avoid scanning all chunks
SELECT * FROM measurements 
WHERE temperature > 25;  -- Bad: scans all chunks

-- Use continuous aggregates for historical data
SELECT * FROM daily_stats 
WHERE day > NOW() - INTERVAL '30 days';  -- Good: uses pre-computed data
```

## Next Steps

After completing this module:
1. Review [Query Optimization](03_queries_README.md) for general performance tuning
2. Explore [Transaction Management](02_transactions_README.md) for concurrency
3. Understand [Storage Layout](01_storage_README.md) for deeper optimization

## Troubleshooting

If you encounter issues:
- Check TimescaleDB extension: `SELECT * FROM pg_extension WHERE extname = 'timescaledb';`
- Verify hypertable creation: `SELECT * FROM timescaledb_information.hypertables;`
- Monitor background jobs: `SELECT * FROM timescaledb_information.jobs;`
- Review the [Troubleshooting Guide](TROUBLESHOOTING.md)
