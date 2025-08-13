-- PostgreSQL Storage Deep Dive - SQL Practice
-- This file demonstrates PostgreSQL storage concepts using pure SQL

-- Create the documents table if it doesn't exist
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    content TEXT,           -- Regular text
    metadata JSONB,         -- JSONB storage
    attachment BYTEA,       -- TOAST candidate
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clean up existing records
TRUNCATE documents RESTART IDENTITY;

-- Create small document
INSERT INTO documents (title, content, metadata, attachment) VALUES (
    'Small Document',
    'Small content',
    '{"tags": ["small"]}'::jsonb,
    'Small attachment'::bytea
);

-- Create large document
INSERT INTO documents (title, content, metadata, attachment) VALUES (
    'Large Document',
    repeat('A', 10000),  -- 10KB of content
    ('{"tags": ["large"], "description": "' || repeat('B', 1000) || '"}')::jsonb,
    repeat('Large binary content', 1000)::bytea
);

-- Run VACUUM ANALYZE to update statistics
VACUUM ANALYZE documents;

-- Storage Analysis Queries

-- 1. Table Statistics
SELECT 
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes
FROM pg_stat_user_tables
WHERE relname = 'documents';

-- 2. Storage Sizes
SELECT 
    'Total Size' as size_type,
    pg_size_pretty(pg_total_relation_size('documents')) as size
UNION ALL
SELECT 
    'Table Size',
    pg_size_pretty(pg_relation_size('documents'))
UNION ALL
SELECT 
    'Index Size',
    pg_size_pretty(pg_indexes_size('documents'))
UNION ALL
SELECT 
    'TOAST Size',
    COALESCE(
        pg_size_pretty(pg_total_relation_size(reltoastrelid)), 
        'No TOAST table'
    )
FROM pg_class 
WHERE relname = 'documents' 
AND reltoastrelid != 0;

-- 3. Detailed Storage Analysis
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation,
    pg_size_pretty(pg_column_size(attname::text)::bigint) as column_size
FROM pg_stats 
WHERE tablename = 'documents'
ORDER BY attname;

-- 4. Document Sizes Analysis
SELECT 
    id,
    title,
    pg_column_size(content) as content_size,
    pg_column_size(metadata) as metadata_size,
    pg_column_size(attachment) as attachment_size,
    pg_column_size(content) + pg_column_size(metadata) + pg_column_size(attachment) as total_data_size
FROM documents
ORDER BY id;

-- 5. TOAST Analysis
SELECT 
    c.relname as table_name,
    t.relname as toast_table_name,
    pg_size_pretty(pg_total_relation_size(t.oid)) as toast_size,
    pg_size_pretty(pg_relation_size(t.oid)) as toast_table_size,
    pg_size_pretty(pg_total_relation_size(t.oid) - pg_relation_size(t.oid)) as toast_index_size
FROM pg_class c
JOIN pg_class t ON c.reltoastrelid = t.oid
WHERE c.relname = 'documents';

-- 6. Page-level Analysis
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation,
    most_common_vals,
    most_common_freqs
FROM pg_stats 
WHERE tablename = 'documents'
AND n_distinct > 0
ORDER BY n_distinct DESC;

-- 7. Storage Efficiency Analysis
SELECT 
    'Storage Efficiency' as analysis_type,
    pg_size_pretty(pg_total_relation_size('documents')) as total_size,
    pg_size_pretty(pg_relation_size('documents')) as table_size,
    ROUND(
        (pg_relation_size('documents')::numeric / pg_total_relation_size('documents')::numeric) * 100, 
        2
    ) as table_size_percentage,
    pg_size_pretty(pg_indexes_size('documents')) as index_size,
    ROUND(
        (pg_indexes_size('documents')::numeric / pg_total_relation_size('documents')::numeric) * 100, 
        2
    ) as index_size_percentage;

-- 8. Column-level Storage Analysis
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    pg_size_pretty(pg_column_size(column_name::text)::bigint) as storage_size,
    CASE 
        WHEN data_type = 'jsonb' THEN 'Compressed JSON storage'
        WHEN data_type = 'text' THEN 'Variable length text'
        WHEN data_type = 'bytea' THEN 'Binary data (TOAST candidate)'
        ELSE 'Standard storage'
    END as storage_notes
FROM information_schema.columns 
WHERE table_name = 'documents'
ORDER BY ordinal_position;
