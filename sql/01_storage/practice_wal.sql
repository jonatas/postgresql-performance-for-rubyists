-- PostgreSQL WAL and Performance Analysis - SQL Practice
-- This file demonstrates WAL (Write-Ahead Log) analysis using pure SQL

-- Create test table for WAL analysis
CREATE TABLE IF NOT EXISTS wal_test_records (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    description TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clean up existing records
TRUNCATE wal_test_records RESTART IDENTITY;

-- WAL Analysis Functions and Queries

-- 1. Current WAL Settings
SELECT 
    name, 
    setting, 
    unit, 
    context, 
    short_desc
FROM pg_settings
WHERE name LIKE '%wal%' 
   OR name LIKE '%checkpoint%'
   OR name IN ('synchronous_commit', 'commit_delay', 'commit_siblings')
ORDER BY name;

-- 2. Current WAL Statistics
SELECT 
    'WAL Statistics' as info_type,
    pg_current_wal_lsn() as current_lsn,
    pg_walfile_name(pg_current_wal_lsn()) as current_wal_file,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) as total_wal_size
UNION ALL
SELECT 
    'Checkpoint Info',
    pg_control_checkpoint()::text,
    pg_walfile_name(pg_control_checkpoint()),
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), pg_control_checkpoint()));

-- 3. Background Writer Statistics
SELECT 
    stats_reset,
    checkpoints_timed,
    checkpoints_req,
    checkpoint_write_time,
    checkpoint_sync_time,
    buffers_checkpoint,
    buffers_clean,
    maxwritten_clean,
    buffers_backend,
    buffers_backend_fsync,
    buffers_alloc,
    stats_reset
FROM pg_stat_bgwriter;

-- 4. WAL Generation Measurement Function
CREATE OR REPLACE FUNCTION measure_wal_generation(
    operation_name TEXT,
    operation_sql TEXT
) RETURNS TABLE(
    operation_name TEXT,
    wal_bytes BIGINT,
    execution_time_ms NUMERIC,
    bytes_per_second NUMERIC,
    wal_file_name TEXT
) AS $$
DECLARE
    start_lsn pg_lsn;
    end_lsn pg_lsn;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    wal_bytes BIGINT;
    execution_time_ms NUMERIC;
BEGIN
    -- Record starting state
    start_lsn := pg_current_wal_lsn();
    start_time := clock_timestamp();
    
    -- Execute the operation
    EXECUTE operation_sql;
    
    -- Record ending state
    end_lsn := pg_current_wal_lsn();
    end_time := clock_timestamp();
    
    -- Calculate differences
    wal_bytes := pg_wal_lsn_diff(end_lsn, start_lsn);
    execution_time_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
    
    RETURN QUERY SELECT 
        operation_name,
        wal_bytes,
        execution_time_ms,
        CASE 
            WHEN execution_time_ms > 0 THEN (wal_bytes::NUMERIC / (execution_time_ms / 1000))
            ELSE 0
        END,
        pg_walfile_name(end_lsn);
END;
$$ LANGUAGE plpgsql;

-- 5. Test WAL Generation with Different Operations
-- Small insert
SELECT * FROM measure_wal_generation(
    'Small Insert',
    'INSERT INTO wal_test_records (name, description, metadata) VALUES (''Small Test'', ''Small content'', ''{"test": "small"}''::jsonb)'
);

-- Large insert
SELECT * FROM measure_wal_generation(
    'Large Insert',
    'INSERT INTO wal_test_records (name, description, metadata) VALUES (''Large Test'', repeat(''A'', 10000), (''{"data": "'' || repeat(''B'', 1000) || ''"}''::jsonb))'
);

-- Update operation
SELECT * FROM measure_wal_generation(
    'Update Operation',
    'UPDATE wal_test_records SET description = ''Updated content'' WHERE name = ''Small Test'''
);

-- Delete operation
SELECT * FROM measure_wal_generation(
    'Delete Operation',
    'DELETE FROM wal_test_records WHERE name = ''Large Test'''
);

-- 6. Checkpoint Analysis
CREATE OR REPLACE FUNCTION analyze_checkpoint() RETURNS TABLE(
    checkpoint_type TEXT,
    duration_ms NUMERIC,
    buffers_written BIGINT,
    buffers_alloc BIGINT,
    maxwritten_clean BIGINT
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    pre_stats RECORD;
    post_stats RECORD;
BEGIN
    -- Get pre-checkpoint stats
    SELECT * INTO pre_stats FROM pg_stat_bgwriter;
    start_time := clock_timestamp();
    
    -- Force checkpoint
    PERFORM pg_checkpoint();
    
    end_time := clock_timestamp();
    
    -- Get post-checkpoint stats
    SELECT * INTO post_stats FROM pg_stat_bgwriter;
    
    RETURN QUERY SELECT 
        'Manual Checkpoint'::TEXT,
        EXTRACT(EPOCH FROM (end_time - start_time)) * 1000,
        post_stats.buffers_checkpoint - pre_stats.buffers_checkpoint,
        post_stats.buffers_alloc - pre_stats.buffers_alloc,
        post_stats.maxwritten_clean - pre_stats.maxwritten_clean;
END;
$$ LANGUAGE plpgsql;

-- Run checkpoint analysis
SELECT * FROM analyze_checkpoint();

-- 7. WAL Compression Test
-- Enable WAL compression
ALTER SYSTEM SET wal_compression = on;
SELECT pg_reload_conf();

-- Test with compressible data
SELECT * FROM measure_wal_generation(
    'Compressible Data (WAL Compression ON)',
    'INSERT INTO wal_test_records (name, description, metadata) VALUES (''Compression Test'', repeat(''A'', 1000), (''{"data": "'' || repeat(''B'', 1000) || ''"}''::jsonb))'
);

-- Test with random data
SELECT * FROM measure_wal_generation(
    'Random Data (WAL Compression ON)',
    'INSERT INTO wal_test_records (name, description, metadata) VALUES (''Random Test'', encode(gen_random_bytes(500), ''hex''), (''{"data": "'' || encode(gen_random_bytes(500), ''hex'') || ''"}''::jsonb))'
);

-- Disable WAL compression
ALTER SYSTEM SET wal_compression = off;
SELECT pg_reload_conf();

-- Test same operations without compression
SELECT * FROM measure_wal_generation(
    'Compressible Data (WAL Compression OFF)',
    'INSERT INTO wal_test_records (name, description, metadata) VALUES (''Compression Test 2'', repeat(''A'', 1000), (''{"data": "'' || repeat(''B'', 1000) || ''"}''::jsonb))'
);

SELECT * FROM measure_wal_generation(
    'Random Data (WAL Compression OFF)',
    'INSERT INTO wal_test_records (name, description, metadata) VALUES (''Random Test 2'', encode(gen_random_bytes(500), ''hex''), (''{"data": "'' || encode(gen_random_bytes(500), ''hex'') || ''"}''::jsonb))'
);

-- 8. Transaction WAL Analysis
CREATE OR REPLACE FUNCTION analyze_transaction_wal() RETURNS TABLE(
    transaction_type TEXT,
    wal_bytes BIGINT,
    records_affected INTEGER,
    avg_wal_per_record NUMERIC
) AS $$
DECLARE
    start_lsn pg_lsn;
    end_lsn pg_lsn;
    record_count INTEGER;
BEGIN
    -- Single record transaction
    start_lsn := pg_current_wal_lsn();
    BEGIN
        INSERT INTO wal_test_records (name, description, metadata) 
        VALUES ('Single Transaction', 'Single record', '{"type": "single"}'::jsonb);
        GET DIAGNOSTICS record_count = ROW_COUNT;
    END;
    end_lsn := pg_current_wal_lsn();
    
    RETURN QUERY SELECT 
        'Single Record Transaction',
        pg_wal_lsn_diff(end_lsn, start_lsn),
        record_count,
        pg_wal_lsn_diff(end_lsn, start_lsn)::NUMERIC / record_count;
    
    -- Multiple records transaction
    start_lsn := pg_current_wal_lsn();
    BEGIN
        INSERT INTO wal_test_records (name, description, metadata) 
        SELECT 
            'Batch Record ' || i,
            'Batch content ' || i,
            ('{"batch": ' || i || '}'::jsonb)
        FROM generate_series(1, 10) i;
        GET DIAGNOSTICS record_count = ROW_COUNT;
    END;
    end_lsn := pg_current_wal_lsn();
    
    RETURN QUERY SELECT 
        'Batch Transaction (10 records)',
        pg_wal_lsn_diff(end_lsn, start_lsn),
        record_count,
        pg_wal_lsn_diff(end_lsn, start_lsn)::NUMERIC / record_count;
END;
$$ LANGUAGE plpgsql;

-- Run transaction analysis
SELECT * FROM analyze_transaction_wal();

-- 9. WAL File Information
SELECT 
    'WAL Files Info' as info_type,
    pg_walfile_name(pg_current_wal_lsn()) as current_file,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) as total_wal_size,
    (SELECT setting FROM pg_settings WHERE name = 'wal_segment_size') as segment_size,
    (SELECT setting FROM pg_settings WHERE name = 'max_wal_size') as max_wal_size
UNION ALL
SELECT 
    'Checkpoint Info',
    pg_walfile_name(pg_control_checkpoint()),
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), pg_control_checkpoint())),
    (SELECT setting FROM pg_settings WHERE name = 'checkpoint_timeout'),
    (SELECT setting FROM pg_settings WHERE name = 'checkpoint_completion_target');

-- 10. Performance Impact Analysis
WITH wal_stats AS (
    SELECT 
        operation_name,
        wal_bytes,
        execution_time_ms,
        bytes_per_second,
        ROUND(wal_bytes::NUMERIC / 1024, 2) as wal_kb,
        ROUND(execution_time_ms, 2) as time_ms
    FROM (
        SELECT * FROM measure_wal_generation('Test Operation', 'SELECT 1')
    ) t
)
SELECT 
    'WAL Performance Summary' as summary_type,
    COUNT(*) as total_operations,
    ROUND(AVG(wal_kb), 2) as avg_wal_kb,
    ROUND(AVG(time_ms), 2) as avg_time_ms,
    ROUND(AVG(bytes_per_second), 2) as avg_bytes_per_second,
    ROUND(SUM(wal_kb), 2) as total_wal_kb
FROM wal_stats;

-- 11. Cleanup
DROP FUNCTION IF EXISTS measure_wal_generation(TEXT, TEXT);
DROP FUNCTION IF EXISTS analyze_checkpoint();
DROP FUNCTION IF EXISTS analyze_transaction_wal();
