# 🗄️ PostgreSQL Performance Workshop - SQL Edition

Welcome to the SQL edition of the PostgreSQL Performance Workshop! This version focuses on pure PostgreSQL optimization using SQL commands and `psql`. Perfect for database administrators, SQL developers, and anyone who wants to learn PostgreSQL optimization without language-specific frameworks.

![img/05_ruby.webp](../shared/img/05_ruby.webp "A kawaii felt craft scene featuring a chubby felt elephant wearing tiny developer glasses, surrounded by SQL code snippets and database symbols")

## 🎯 What You'll Learn

This SQL edition covers the same core PostgreSQL concepts as the Ruby version, but with a focus on:

- **Pure SQL commands** and `psql` usage
- **System administration** and monitoring
- **Database optimization** without ORM overhead
- **Performance tuning** using native PostgreSQL tools
- **TimescaleDB** administration and optimization

## 📚 Module Structure

### 1. [PostgreSQL Storage Deep Dive](01_storage/README.md)
- **Files**: `practice_storage.sql`, `practice_tuple.sql`, `practice_wal.sql`
- **Focus**: Understanding how PostgreSQL stores data
- **Key Concepts**: Pages, tuples, TOAST, WAL, alignment

### 2. [Transaction Management](02_transactions/README.md)
- **Files**: `transaction_lab.sql`, `exercises.sql`
- **Focus**: ACID properties, isolation levels, concurrency
- **Key Concepts**: Transactions, locks, deadlocks, MVCC

### 3. [Query Optimization](03_queries/README.md)
- **Files**: `practice_queries.sql`, `advanced_queries.sql`, `query_optimization_lab.sql`
- **Focus**: Query planning, indexing, performance tuning
- **Key Concepts**: EXPLAIN ANALYZE, indexes, statistics, joins

### 4. [TimescaleDB Extension](04_timescale/README.md)
- **Files**: `timescale_setup.sql`, `practice_timescale.sql`, `parallel_execution_test.sql`
- **Focus**: Time-series data optimization
- **Key Concepts**: Hypertables, chunks, continuous aggregates, compression

## 🛠 Setup Instructions

### Quick Setup
```bash
# Run the SQL setup script
./setup/setup_sql.sh
```

### Manual Setup
```bash
# 1. Ensure PostgreSQL is running
psql -h localhost -U postgres -c "SELECT version();"

# 2. Create workshop database
psql -h localhost -U postgres -c "CREATE DATABASE workshop_db;"

# 3. Test connection
psql -h localhost -U postgres -d workshop_db -c "SELECT 'Workshop ready!' as status;"
```

## 🚀 Getting Started

### Running Examples
```bash
# Connect to the workshop database
psql -h localhost -U postgres -d workshop_db

# Run a specific example
\i sql/01_storage/practice_storage.sql

# Or run from command line
psql -h localhost -U postgres -d workshop_db -f sql/01_storage/practice_storage.sql
```

### Interactive Learning
```sql
-- Start with storage analysis
\i sql/01_storage/practice_storage.sql

-- Explore tuple structure
\i sql/01_storage/practice_tuple.sql

-- Understand WAL behavior
\i sql/01_storage/practice_wal.sql
```

## 📊 Key SQL Commands You'll Master

### Storage Analysis
```sql
-- Table sizes
SELECT pg_size_pretty(pg_total_relation_size('table_name'));

-- TOAST analysis
SELECT c.relname, t.relname as toast_table
FROM pg_class c
JOIN pg_class t ON c.reltoastrelid = t.oid
WHERE c.relname = 'table_name';

-- Column sizes
SELECT column_name, pg_column_size(column_name::text)
FROM information_schema.columns
WHERE table_name = 'table_name';
```

### Performance Monitoring
```sql
-- Query statistics
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;

-- Table statistics
SELECT schemaname, tablename, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

### Transaction Analysis
```sql
-- Current transactions
SELECT pid, state, query_start, query
FROM pg_stat_activity
WHERE state != 'idle';

-- Lock information
SELECT l.pid, l.mode, l.granted, a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE NOT l.granted;
```

## 🎯 Learning Path

### Beginner Level
1. **Start with Storage**: Understand how PostgreSQL stores data
2. **Learn Transactions**: Master ACID properties and isolation
3. **Basic Queries**: Learn query planning and optimization

### Intermediate Level
1. **Advanced Storage**: Deep dive into TOAST and WAL
2. **Concurrency**: Handle complex transaction scenarios
3. **Indexing**: Master different index types and strategies

### Advanced Level
1. **TimescaleDB**: Optimize time-series data
2. **System Administration**: Monitor and maintain PostgreSQL
3. **Performance Tuning**: Advanced optimization techniques

## 🔧 Tools You'll Use

### PostgreSQL Built-in Tools
- **`psql`**: Command-line interface
- **`EXPLAIN ANALYZE`**: Query analysis
- **`pg_stat_*` views**: Performance monitoring
- **`pg_settings`**: Configuration management

### System Views
- **`pg_stat_user_tables`**: Table statistics
- **`pg_stat_user_indexes`**: Index usage
- **`pg_stat_activity`**: Current activity
- **`pg_locks`**: Lock information

### Performance Functions
- **`pg_size_pretty()`**: Human-readable sizes
- **`pg_relation_size()`**: Table sizes
- **`pg_column_size()`**: Column sizes
- **`pg_current_wal_lsn()`**: WAL position

## 🎮 Interactive Exercises

Each module includes hands-on exercises:

### Storage Module
- Create tables with different data types
- Analyze storage overhead
- Understand TOAST behavior
- Monitor WAL generation

### Transaction Module
- Test isolation levels
- Create deadlock scenarios
- Monitor transaction behavior
- Optimize concurrency

### Query Module
- Analyze query plans
- Create and test indexes
- Optimize joins
- Monitor query performance

### TimescaleDB Module
- Create hypertables
- Set up continuous aggregates
- Configure compression
- Monitor time-series performance

## 📈 Performance Best Practices

### Storage Optimization
- Choose appropriate data types
- Consider column order for alignment
- Monitor TOAST usage
- Regular VACUUM and ANALYZE

### Query Optimization
- Use EXPLAIN ANALYZE regularly
- Create appropriate indexes
- Monitor query statistics
- Optimize join strategies

### Transaction Management
- Choose appropriate isolation levels
- Minimize transaction duration
- Handle deadlocks gracefully
- Monitor lock contention

### System Administration
- Regular maintenance tasks
- Monitor system resources
- Configure appropriate settings
- Backup and recovery strategies

## 🤝 Contributing

We welcome contributions to the SQL edition:

- **Add new SQL examples**
- **Improve documentation**
- **Report bugs or issues**
- **Suggest new modules**

## 📚 Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [psql Reference](https://www.postgresql.org/docs/current/app-psql.html)
- [Performance Tuning Guide](https://www.postgresql.org/docs/current/performance.html)

## 🎉 Ready to Start?

Begin your PostgreSQL optimization journey with the SQL edition:

```bash
# Quick start
./setup/setup_sql.sh

# Or start with the first module
psql -d workshop_db -f sql/01_storage/practice_storage.sql
```

Happy learning! 🚀✨
