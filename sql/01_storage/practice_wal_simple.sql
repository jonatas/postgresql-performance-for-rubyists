-- PostgreSQL WAL and Performance Analysis - Simplified SQL Practice
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
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) as total_wal_size;

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
    buffers_alloc
FROM pg_stat_bgwriter;

-- 4. Test WAL Generation with Different Operations
-- Small insert
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Small Test', 'Small content', '{"test": "small"}'::jsonb);

-- Large insert
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Large Test', repeat('A', 10000), ('{"data": "' || repeat('B', 1000) || '"}'::jsonb));

-- Update operation
UPDATE wal_test_records SET description = 'Updated content' WHERE name = 'Small Test';

-- Delete operation
DELETE FROM wal_test_records WHERE name = 'Large Test';

-- 5. Checkpoint Analysis
-- Get pre-checkpoint stats
SELECT 'Pre-checkpoint stats' as checkpoint_phase, 
       checkpoints_timed, 
       checkpoints_req, 
       buffers_checkpoint
FROM pg_stat_bgwriter;

-- Force checkpoint (this will take a moment)
SELECT pg_checkpoint();

-- Get post-checkpoint stats
SELECT 'Post-checkpoint stats' as checkpoint_phase, 
       checkpoints_timed, 
       checkpoints_req, 
       buffers_checkpoint
FROM pg_stat_bgwriter;

-- 6. WAL Compression Test
-- Enable WAL compression
ALTER SYSTEM SET wal_compression = on;
SELECT pg_reload_conf();

-- Test with compressible data
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Compression Test', repeat('A', 1000), ('{"data": "' || repeat('B', 1000) || '"}'::jsonb));

-- Test with random data
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Random Test', encode(gen_random_bytes(500), 'hex'), ('{"data": "' || encode(gen_random_bytes(500), 'hex') || '"}'::jsonb));

-- Disable WAL compression
ALTER SYSTEM SET wal_compression = off;
SELECT pg_reload_conf();

-- Test same operations without compression
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Compression Test 2', repeat('A', 1000), ('{"data": "' || repeat('B', 1000) || '"}'::jsonb));

INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Random Test 2', encode(gen_random_bytes(500), 'hex'), ('{"data": "' || encode(gen_random_bytes(500), 'hex') || '"}'::jsonb));

-- 7. Transaction WAL Analysis
-- Single record transaction
BEGIN;
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Single Transaction', 'Single record', '{"type": "single"}'::jsonb);
COMMIT;

-- Multiple records transaction
BEGIN;
INSERT INTO wal_test_records (name, description, metadata) 
SELECT 
    'Batch Record ' || i,
    'Batch content ' || i,
    ('{"batch": ' || i || '}'::jsonb)
FROM generate_series(1, 10) i;
COMMIT;

-- 8. WAL File Information
SELECT 
    'WAL Files Info' as info_type,
    pg_walfile_name(pg_current_wal_lsn()) as current_file,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) as total_wal_size,
    (SELECT setting FROM pg_settings WHERE name = 'wal_segment_size') as segment_size,
    (SELECT setting FROM pg_settings WHERE name = 'max_wal_size') as max_wal_size;

-- 9. Performance Impact Analysis
SELECT 
    'WAL Performance Summary' as summary_type,
    COUNT(*) as total_records,
    pg_size_pretty(pg_total_relation_size('wal_test_records')) as table_size,
    (SELECT setting FROM pg_settings WHERE name = 'wal_compression') as wal_compression_status
FROM wal_test_records;

-- 10. Cleanup
DROP TABLE IF EXISTS wal_test_records;
