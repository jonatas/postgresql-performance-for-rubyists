-- PostgreSQL Tuple Deep Dive - SQL Practice
-- This file demonstrates detailed tuple analysis using pure SQL

-- Create the employees table if it doesn't exist
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),           -- variable length, 4-byte aligned
    employee_id INTEGER,         -- 4 bytes, 4-byte aligned
    active BOOLEAN,              -- 1 byte, 1-byte aligned
    hire_date DATE,              -- 4 bytes, 4-byte aligned
    salary DECIMAL(10,2),        -- 8 bytes, 8-byte aligned
    details JSONB,               -- variable length, 4-byte aligned
    photo BYTEA,                 -- variable length, 4-byte aligned
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clean up existing records
TRUNCATE employees RESTART IDENTITY;

-- 1. Minimal Employee (mostly NULL values)
INSERT INTO employees (name, employee_id, active, hire_date, salary, details, photo) VALUES (
    'John Doe',
    1001,
    true,
    NULL,
    NULL,
    NULL,
    NULL
);

-- 2. Full Employee (all fields populated)
INSERT INTO employees (name, employee_id, active, hire_date, salary, details, photo) VALUES (
    'Jane Smith',
    1002,
    true,
    '2023-01-15',
    75000.00,
    '{"department": "Engineering", "skills": ["Ruby", "PostgreSQL"], "level": "Senior"}'::jsonb,
    'photo_data_here'::bytea
);

-- 3. Large Data Employee (TOAST candidate)
INSERT INTO employees (name, employee_id, active, hire_date, salary, details, photo) VALUES (
    'Bob Johnson',
    1003,
    false,
    '2022-06-20',
    85000.00,
    ('{"department": "Data Science", "skills": ["Python", "Machine Learning", "Statistics"], "projects": ["' || 
     repeat('Project A, ', 100) || 'Project Z"], "certifications": ["AWS", "Google Cloud", "Azure"]}')::jsonb,
    repeat('large_photo_data_', 1000)::bytea
);

-- Run VACUUM ANALYZE to update statistics
VACUUM ANALYZE employees;

-- Tuple Analysis Queries

-- 1. Basic Table Statistics
SELECT 
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes
FROM pg_stat_user_tables
WHERE relname = 'employees';

-- 2. Storage Sizes Analysis
SELECT 
    'Total Size' as size_type,
    pg_size_pretty(pg_total_relation_size('employees')) as size
UNION ALL
SELECT 
    'Table Size',
    pg_size_pretty(pg_relation_size('employees'))
UNION ALL
SELECT 
    'Index Size',
    pg_size_pretty(pg_indexes_size('employees'))
UNION ALL
SELECT 
    'TOAST Size',
    COALESCE(
        pg_size_pretty(pg_total_relation_size(reltoastrelid)), 
        'No TOAST table'
    )
FROM pg_class 
WHERE relname = 'employees' 
AND reltoastrelid != 0;

-- 3. Individual Tuple Size Analysis
SELECT 
    id,
    name,
    pg_column_size(name) as name_size,
    pg_column_size(employee_id) as employee_id_size,
    pg_column_size(active) as active_size,
    pg_column_size(hire_date) as hire_date_size,
    pg_column_size(salary) as salary_size,
    pg_column_size(details) as details_size,
    pg_column_size(photo) as photo_size,
    pg_column_size(created_at) as created_at_size,
    pg_column_size(updated_at) as updated_at_size,
    -- Calculate total tuple size
    pg_column_size(name) + 
    pg_column_size(employee_id) + 
    pg_column_size(active) + 
    pg_column_size(hire_date) + 
    pg_column_size(salary) + 
    pg_column_size(details) + 
    pg_column_size(photo) + 
    pg_column_size(created_at) + 
    pg_column_size(updated_at) as total_data_size
FROM employees
ORDER BY id;

-- 4. Theoretical vs Actual Size Analysis
WITH tuple_analysis AS (
    SELECT 
        id,
        name,
        -- Theoretical calculations
        23 as header_size,  -- Standard tuple header
        2 as null_bitmap_size,  -- 9 columns, rounded up to bytes
        -- Data type sizes (theoretical minimums)
        CASE 
            WHEN name IS NOT NULL THEN length(name)
            ELSE 0
        END as name_theoretical,
        4 as employee_id_theoretical,  -- INTEGER is always 4 bytes
        1 as active_theoretical,       -- BOOLEAN is always 1 byte
        CASE 
            WHEN hire_date IS NOT NULL THEN 4
            ELSE 0
        END as hire_date_theoretical,
        CASE 
            WHEN salary IS NOT NULL THEN 8
            ELSE 0
        END as salary_theoretical,
        CASE 
            WHEN details IS NOT NULL THEN length(details::text)
            ELSE 0
        END as details_theoretical,
        CASE 
            WHEN photo IS NOT NULL THEN length(photo)
            ELSE 0
        END as photo_theoretical,
        8 as created_at_theoretical,   -- TIMESTAMP is 8 bytes
        8 as updated_at_theoretical,   -- TIMESTAMP is 8 bytes
        -- Actual sizes
        pg_column_size(name) as name_actual,
        pg_column_size(employee_id) as employee_id_actual,
        pg_column_size(active) as active_actual,
        pg_column_size(hire_date) as hire_date_actual,
        pg_column_size(salary) as salary_actual,
        pg_column_size(details) as details_actual,
        pg_column_size(photo) as photo_actual,
        pg_column_size(created_at) as created_at_actual,
        pg_column_size(updated_at) as updated_at_actual
    FROM employees
)
SELECT 
    id,
    name,
    -- Theoretical total
    (header_size + null_bitmap_size + 
     name_theoretical + employee_id_theoretical + active_theoretical + 
     hire_date_theoretical + salary_theoretical + details_theoretical + 
     photo_theoretical + created_at_theoretical + updated_at_theoretical) as theoretical_size,
    -- Actual total
    (name_actual + employee_id_actual + active_actual + 
     hire_date_actual + salary_actual + details_actual + 
     photo_actual + created_at_actual + updated_at_actual) as actual_size,
    -- Difference (alignment padding + overhead)
    ((name_actual + employee_id_actual + active_actual + 
      hire_date_actual + salary_actual + details_actual + 
      photo_actual + created_at_actual + updated_at_actual) - 
     (header_size + null_bitmap_size + 
      name_theoretical + employee_id_theoretical + active_theoretical + 
      hire_date_theoretical + salary_theoretical + details_theoretical + 
      photo_theoretical + created_at_theoretical + updated_at_theoretical)) as overhead
FROM tuple_analysis
ORDER BY id;

-- 5. NULL Value Impact Analysis
SELECT 
    'NULL Values Analysis' as analysis_type,
    COUNT(*) as total_rows,
    COUNT(name) as non_null_names,
    COUNT(hire_date) as non_null_dates,
    COUNT(salary) as non_null_salaries,
    COUNT(details) as non_null_details,
    COUNT(photo) as non_null_photos,
    ROUND(AVG(pg_column_size(name)), 2) as avg_name_size,
    ROUND(AVG(pg_column_size(details)), 2) as avg_details_size,
    ROUND(AVG(pg_column_size(photo)), 2) as avg_photo_size
FROM employees;

-- 6. TOAST Analysis for Large Data
SELECT 
    c.relname as table_name,
    t.relname as toast_table_name,
    pg_size_pretty(pg_total_relation_size(t.oid)) as toast_size,
    pg_size_pretty(pg_relation_size(t.oid)) as toast_table_size,
    pg_size_pretty(pg_total_relation_size(t.oid) - pg_relation_size(t.oid)) as toast_index_size,
    -- Check if TOAST compression is being used
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_stat_user_tables 
            WHERE relname = t.relname 
            AND n_tup_ins > 0
        ) THEN 'Active'
        ELSE 'Inactive'
    END as toast_activity
FROM pg_class c
LEFT JOIN pg_class t ON c.reltoastrelid = t.oid
WHERE c.relname = 'employees';

-- 7. Column Alignment Analysis
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default,
    -- Alignment requirements
    CASE 
        WHEN data_type IN ('bigint', 'double precision', 'timestamp', 'timestamptz') THEN 8
        WHEN data_type IN ('integer', 'real', 'date', 'jsonb') THEN 4
        WHEN data_type IN ('smallint', 'boolean') THEN 2
        ELSE 1
    END as alignment_bytes,
    -- Storage notes
    CASE 
        WHEN data_type = 'jsonb' THEN 'Compressed JSON storage'
        WHEN data_type = 'bytea' THEN 'Binary data (TOAST candidate)'
        WHEN data_type = 'text' OR data_type LIKE 'varchar%' THEN 'Variable length'
        ELSE 'Fixed length'
    END as storage_notes
FROM information_schema.columns 
WHERE table_name = 'employees'
ORDER BY ordinal_position;

-- 8. Page-level Statistics
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation,
    most_common_vals,
    most_common_freqs,
    histogram_bounds
FROM pg_stats 
WHERE tablename = 'employees'
ORDER BY attname;

-- 9. Storage Efficiency Summary
SELECT 
    'Storage Efficiency Summary' as summary_type,
    pg_size_pretty(pg_total_relation_size('employees')) as total_size,
    pg_size_pretty(pg_relation_size('employees')) as table_size,
    ROUND(
        (pg_relation_size('employees')::numeric / pg_total_relation_size('employees')::numeric) * 100, 
        2
    ) as table_size_percentage,
    pg_size_pretty(pg_indexes_size('employees')) as index_size,
    ROUND(
        (pg_indexes_size('employees')::numeric / pg_total_relation_size('employees')::numeric) * 100, 
        2
    ) as index_size_percentage,
    COUNT(*) as total_rows,
    ROUND(pg_relation_size('employees')::numeric / COUNT(*), 2) as avg_bytes_per_row
FROM employees;
