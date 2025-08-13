-- PostgreSQL WAL (Write-Ahead Log) Analysis
-- This script demonstrates WAL behavior and performance characteristics

-- 1. Create test table
CREATE TABLE IF NOT EXISTS wal_test_records (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    description TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clear existing data
TRUNCATE TABLE wal_test_records;

-- 2. WAL Settings Analysis
-- Show current WAL configuration
SELECT 
    name,
    setting,
    unit,
    context,
    short_desc
FROM pg_settings 
WHERE name LIKE 'wal%' OR name LIKE 'checkpoint%'
ORDER BY name;

-- 3. Current WAL Statistics
SELECT 
    'WAL Statistics' as info_type,
    pg_current_wal_lsn() as current_lsn,
    pg_walfile_name(pg_current_wal_lsn()) as current_wal_file,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) as total_wal_size;

-- 4. Background Writer Statistics (available columns only)
SELECT 
    'Background Writer Stats' as info_type,
    buffers_clean,
    maxwritten_clean,
    buffers_alloc,
    stats_reset
FROM pg_stat_bgwriter;

-- 5. Test WAL Generation with Different Operations
-- Small insert
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Small Test', 'Small content', '{"test": "small"}'::jsonb);

-- Large insert
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Large Test', repeat('A', 10000), '{"data": "large_content"}'::jsonb);

-- Update operation
UPDATE wal_test_records SET description = 'Updated content' WHERE name = 'Small Test';

-- Delete operation
DELETE FROM wal_test_records WHERE name = 'Large Test';

-- 6. WAL Compression Test
-- Enable WAL compression
ALTER SYSTEM SET wal_compression = on;
SELECT pg_reload_conf();

-- Test with compressible data
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Compression Test', repeat('A', 1000), '{"data": "compressible"}'::jsonb);

-- Test with random-like data
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Random Test', repeat('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 20), '{"data": "random_like"}'::jsonb);

-- Disable WAL compression
ALTER SYSTEM SET wal_compression = off;
SELECT pg_reload_conf();

-- Test same operations without compression
INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Compression Test 2', repeat('A', 1000), '{"data": "compressible_2"}'::jsonb);

INSERT INTO wal_test_records (name, description, metadata) 
VALUES ('Random Test 2', repeat('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 20), '{"data": "random_like_2"}'::jsonb);

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
    'Batch Record ' || i::text,
    'Batch content ' || i::text,
    jsonb_build_object('batch', i)
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

-- 10. Table Statistics After WAL Operations
SELECT 
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes
FROM pg_stat_user_tables
WHERE relname = 'wal_test_records';

-- 11. Final Storage Analysis
SELECT 
    'Storage Analysis' as analysis_type,
    pg_size_pretty(pg_total_relation_size('wal_test_records')) as total_size,
    pg_size_pretty(pg_relation_size('wal_test_records')) as table_size,
    pg_size_pretty(pg_indexes_size('wal_test_records')) as index_size;

-- 12. Cleanup
DROP TABLE IF EXISTS wal_test_records;
