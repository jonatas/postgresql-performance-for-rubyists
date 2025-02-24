# PostgreSQL Glossary 📚

This glossary provides definitions for key PostgreSQL concepts used throughout the workshop.

## A

### ACID
A set of properties that guarantee database transactions are processed reliably:
- **Atomicity**: Transactions are all-or-nothing
- **Consistency**: Only valid data is written to the database
- **Isolation**: Concurrent transactions don't interfere with each other
- **Durability**: Committed transactions are permanent

<details>
<summary>Detailed Explanation</summary>

![img/acid.webp](img/acid.webp "A kawaii felt craft scene showing four adorable cube characters representing ACID properties. An Atomicity cube wearing a referee outfit, a Consistency cube with a balance scale, an Isolation cube with headphones, and a Durability cube with a shield, all being conducted by a cute PostgreSQL elephant.")


- **Atomicity**: Transactions are all-or-nothing
  ```ruby
  # Example of atomicity
  ActiveRecord::Base.transaction do
    user.update!(balance: user.balance - 100)
    recipient.update!(balance: recipient.balance + 100)
  end # Either both updates succeed or neither does
  ```

- **Consistency**: Only valid data is written to the database
  ```ruby
  # Example of maintaining consistency
  class Account < ApplicationRecord
    validates :balance, numericality: { greater_than_or_equal_to: 0 }
    # Ensures account balance never goes negative
  end
  ```

- **Isolation**: Concurrent transactions don't interfere with each other
  ```ruby
  # Example of isolation levels
  Account.transaction(isolation: :serializable) do
    # Strongest isolation - prevents all concurrency anomalies
    balance = account.balance
    account.update!(balance: balance + 100)
  end
  ```

- **Durability**: Committed transactions are permanent
  ```sql
  -- PostgreSQL's WAL ensures durability
  SHOW synchronous_commit;  -- 'on' by default
  ```

**When to use**: Always! ACID properties are fundamental for data integrity.

**Tips**: 
- Think "ACID prevents data accidents"
- Remember: All Changes In Database
- Use transactions for related operations
</details>

### Aggregate Functions
Functions that operate on a set of rows to compute a single result (e.g., COUNT, SUM, AVG).

<details>
<summary>Detailed Explanation</summary>

**Common Functions**:
```sql
-- Basic aggregates
COUNT(*) -- Count rows
SUM(column) -- Sum values
AVG(column) -- Average value
MAX(column) -- Maximum value
MIN(column) -- Minimum value

-- Advanced aggregates
STRING_AGG(column, ',') -- Concatenate strings
ARRAY_AGG(column) -- Create array from values
JSON_AGG(column) -- Create JSON array
```

**Ruby/ActiveRecord Usage**:
```ruby
# Simple aggregation
Order.count
Order.sum(:total)
Order.average(:amount)

# Complex aggregation
Order.group(:status)
     .select('status, 
              COUNT(*) as count,
              AVG(total) as avg_total,
              STRING_AGG(DISTINCT customer_email, ",") as customers')
```

**When to use**: 
- Calculating summary statistics
- Generating reports
- Grouping related data
- Computing running totals

**Tips**:
- Use FILTER clause for conditional aggregation
- Consider window functions for running calculations
- Index columns used in GROUP BY for better performance
</details>

## B

### Buffer Management

PostgreSQL's memory management system for caching frequently accessed data.

<details>
<summary>Detailed Explanation</summary>

![img/buffers.webp](img/buffers.webp "A kawaii felt craft scene depicting memory management as a cozy library where a PostgreSQL elephant librarian organizes data pages in cute felt buffer pools. Frequently accessed pages are shown as books with happy faces in the front shelves.")

The buffer cache is a pool of memory that is used to cache frequently accessed data. It is a part of the PostgreSQL's memory management system.

**Buffer Cache**:
```
+----------------+
| Buffer Header  |  24 bytes
+----------------+
| Page Data      |  8KB
+----------------+
```

**Buffer Tuning**:

For some queries, you can try to adjust the buffer cache size.

```
-- Adjust shared_buffers
shared_buffers = 2GB

-- Monitor buffer usage
SELECT blks_read, blks_hit
FROM pg_stat_database
WHERE datname = 'mydb';
```

**When to consider**:
- Memory management
- Performance optimization
- Large working sets
- Disk I/O bottlenecks

**Tips**:
- Monitor buffer usage
- Adjust shared_buffers
- Consider work_mem
- Watch for buffer bloat
</details>

### BRIN Index (Block Range Index)
A small, summarized index type ideal for columns with natural ordering (e.g., timestamps).

<details>
<summary>Detailed Explanation</summary>

**Creation Syntax**:
```sql
-- Basic BRIN index
CREATE INDEX idx_timestamp_brin ON events 
USING brin(created_at);

-- With custom page range
CREATE INDEX idx_timestamp_brin ON events 
USING brin(created_at) WITH (pages_per_range = 128);
```

**Ruby Migration**:
```ruby
class AddBrinIndexToEvents < ActiveRecord::Migration[7.0]
  def change
    add_index :events, :created_at, 
              using: :brin, 
              name: 'idx_timestamp_brin'
  end
end
```

**When to use**:
- Time-series data
- Sequential numeric IDs
- Sensor readings
- Log data

**Advantages**:
- Very small index size (< 1% of table size)
- Good for append-only data
- Efficient for range queries
- Low maintenance overhead

**Tips**:
- Perfect for TimescaleDB hypertables
- Use for columns with natural ordering
- Consider for large tables (>1M rows)
- Great for time-based partitioned tables
</details>

### B-tree Index
The default index type in PostgreSQL, suitable for equality and range queries.

<details>
<summary>Detailed Explanation</summary>

**Creation Syntax**:
```sql
-- Basic B-tree index
CREATE INDEX idx_users_email ON users(email);

-- Compound B-tree index
CREATE INDEX idx_orders_composite ON orders(user_id, created_at);

-- Unique B-tree index
CREATE UNIQUE INDEX idx_users_unique_email ON users(email);
```

**Ruby Migration**:
```ruby
class AddBtreeIndexesToUsers < ActiveRecord::Migration[7.0]
  def change
    # Simple index
    add_index :users, :email

    # Compound index
    add_index :users, [:last_name, :first_name]

    # Unique index
    add_index :users, :email, unique: true
  end
end
```

**When to use**:
- Equality comparisons (=)
- Range queries (<, >, BETWEEN)
- Pattern matching (LIKE 'prefix%')
- ORDER BY operations
- Unique constraints

**Tips**:
- Most versatile index type
- Put most selective columns first in compound indexes
- Consider index-only scans for performance
- Monitor index size and usage
</details>

## C

### Continuous Aggregate
A TimescaleDB feature that automatically maintains materialized views of aggregate queries.

![img/continuous_aggregates.webp](img/continuous_aggregates.webp "A kawaii felt craft scene depicting continuous aggregates as cute calculator characters doing group hugs. Shows the PostgreSQL elephant orchestrating automatic updates while felt data points combine into summary hearts.")

<details>
<summary>Detailed Explanation</summary>

**Creation Example**:
```ruby
# In your model
class Deal < ApplicationRecord
  acts_as_hypertable time_column: 'time', segment_by: 'region'

  scope :avg_price, -> { avg(:price) }

  # Define continuous aggregates
  continuous_aggregates(
    scopes: [:avg_price],
    timeframes: [:hour, :day],
    refresh_policy: {
      hour: {
        start_offset: '3 hours',
        end_offset: '1 hour',
        schedule_interval: '1 hour'
      }
    }
  )
end
```

**SQL Equivalent**:
```sql
-- Create continuous aggregate
CREATE MATERIALIZED VIEW deal_avg_price_by_hour
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) as bucket,
       region,
       avg(price) as avg_price
FROM deals
GROUP BY bucket, region;

-- Set refresh policy
SELECT add_continuous_aggregate_policy('deal_avg_price_by_hour',
  start_offset => INTERVAL '3 hours',
  end_offset => INTERVAL '1 hour',
  schedule_interval => INTERVAL '1 hour');

CREATE MATERIALIZED VIEW deal_avg_price_by_day
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 day', time) as bucket,
       region,
       avg(price) as avg_price
FROM deal_avg_price_by_hour
GROUP BY bucket, region;
```

**When to use**:
- Frequent aggregate queries
- Real-time analytics
- Dashboard data
- Historical trend analysis

**Tips**:
- Choose appropriate refresh intervals
- Balance freshness vs. performance
- Monitor refresh overhead
- Use for common aggregate patterns
</details>

### COPY
A PostgreSQL command for efficient bulk data loading and unloading.

<details>
<summary>Detailed Explanation</summary>

**Basic Syntax**:
```sql
-- Import from CSV
COPY users(name, email) 
FROM '/path/to/users.csv' 
WITH (FORMAT csv, HEADER true);

-- Export to CSV
COPY (SELECT * FROM users WHERE active = true) 
TO '/path/to/active_users.csv' 
WITH (FORMAT csv, HEADER true);
```

**Ruby Implementation**:
```ruby
# Using ActiveRecord
require 'csv'

# Import
CSV.foreach('users.csv', headers: true) do |row|
  User.create!(row.to_h)
end

# Using pg_copy_from (faster)
conn = ActiveRecord::Base.connection.raw_connection
conn.copy_data "COPY users(name, email) FROM STDIN CSV" do
  File.read('users.csv')
end
```

**When to use**:
- Bulk data imports
- Database migrations
- Data exports
- ETL processes

**Tips**:
- Fastest way to load data
- Use FREEZE for new tables
- Consider temporary indexes
- Monitor disk space
</details>

## D

### Deadlock
A situation where two or more transactions are waiting for each other to release locks.

<details>
<summary>Detailed Explanation</summary>

**Classic Deadlock Example**:
```ruby
# Transaction 1
Account.transaction do
  account1.lock!
  sleep(1) # Simulate work
  account2.lock! # Might deadlock
  # Transfer money
end

# Transaction 2 (concurrent)
Account.transaction do
  account2.lock!
  sleep(1) # Simulate work
  account1.lock! # Deadlock!
  # Transfer money
end
```

**Prevention Strategy**:
```ruby
# Always lock in consistent order
def safe_transfer(from_account, to_account, amount)
  Account.transaction do
    # Sort by ID to ensure consistent order
    accounts = [from_account, to_account].sort_by(&:id)
    accounts.each(&:lock!)
    
    from_account.update!(balance: from_account.balance - amount)
    to_account.update!(balance: to_account.balance + amount)
  end
end
```

**Deadlock Detection**:
```sql
-- View current locks
SELECT blocked_locks.pid AS blocked_pid,
       blocking_locks.pid AS blocking_pid,
       blocked_activity.usename AS blocked_user,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_statement,
       blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_locks blocking_locks 
  ON blocking_locks.locktype = blocked_locks.locktype
  AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
  AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
  AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
  AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
  AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
  AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
  AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
  AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
  AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
  AND blocking_locks.pid != blocked_locks.pid;
```

**When to watch out**:
- Multiple transactions updating same records
- Complex transaction dependencies
- Long-running transactions
- Inconsistent lock ordering

**Tips**:
- Always lock records in the same order
- Keep transactions short
- Use timeouts for locks
- Implement retry logic
</details>

### DISTINCT
A clause that removes duplicate rows from a query result.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:
```sql
-- Simple DISTINCT
SELECT DISTINCT category FROM products;

-- Multiple columns
SELECT DISTINCT ON (category) category, name, price
FROM products
ORDER BY category, price DESC;
```

**Ruby/ActiveRecord Examples**:
```ruby
# Simple distinct
User.select(:role).distinct

# Complex distinct with conditions
User.select(:company_id, :role)
    .distinct
    .where('created_at > ?', 1.month.ago)
    .order(:company_id)

# Distinct count
User.select(:role).distinct.count
```

**Performance Considerations**:
```sql
-- Using GROUP BY instead of DISTINCT
SELECT category, COUNT(*) 
FROM products 
GROUP BY category;

-- vs DISTINCT (usually slower)
SELECT COUNT(*) 
FROM (SELECT DISTINCT category FROM products) subquery;
```

**When to use**:
- Removing duplicate values
- Unique combination of columns
- Aggregate calculations on unique values
- Data cleanup operations

**Tips**:
- Consider GROUP BY for better performance
- Index columns used in DISTINCT
- Use DISTINCT ON for row-level uniqueness
- Watch for unnecessary DISTINCT usage
</details>

## E

### EXPLAIN
A command that shows the execution plan of a query without running it.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:
```sql
-- Simple EXPLAIN
EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';

-- With execution statistics
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';

-- With buffers information
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM users WHERE email = 'test@example.com';
```

**Ruby/ActiveRecord Usage**:
```ruby
# Using to_sql
puts User.where(email: 'test@example.com').to_sql

# Using explain
puts User.where(email: 'test@example.com').explain

# Detailed analysis
puts User.where(email: 'test@example.com')
        .explain(analyze: true)
```

**Reading Query Plans**:
```
Seq Scan on users  (cost=0.00..1.14 rows=1 width=540)
│               │         │     │    │        └── Average row width in bytes
│               │         │     │    └── Estimated number of rows
│               │         │     └── Total cost
│               │         └── Startup cost
│               └── Operation type
└── Node type
```

**When to use**:
- Query optimization
- Performance troubleshooting
- Index verification
- Understanding query behavior

**Tips**:
- Always check actual vs. estimated rows
- Watch for sequential scans on large tables
- Look for unexpected nested loops
- Monitor buffer usage patterns
</details>

### EXPLAIN ANALYZE
A command that executes the query and shows actual timing and row counts.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:
```sql
-- Full analysis
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) 
SELECT * FROM orders 
JOIN users ON users.id = orders.user_id 
WHERE orders.status = 'pending';
```

**Common Patterns**:
```sql
-- Index Scan
Index Scan using index_users_on_email on users
  Index Cond: (email = 'test@example.com')
  
-- Sequential Scan
Seq Scan on large_table
  Filter: (status = 'active')
  
-- Hash Join
Hash Join
  Hash Cond: (orders.user_id = users.id)
```

**Performance Metrics**:
```
actual time=0.019..0.021 ms
│           └── Total time
└── Startup time

rows=1 loops=1
│    └── Number of iterations
└── Actual rows returned

Buffers: shared hit=4 read=0
         │         │      └── Physical reads
         │         └── Cache hits
         └── Buffer type
```

**When to use**:
- Detailed performance analysis
- Query optimization
- Identifying bottlenecks
- Verifying index usage

**Tips**:
- Compare estimated vs actual rows
- Watch for large time differences
- Monitor buffer usage
- Look for unexpected operations
</details>

## H

### Heap
The main storage area for a PostgreSQL table, containing the actual data rows.

<details>
<summary>Detailed Explanation</summary>

**Structure**:
```
Page Layout (8KB blocks):
+----------------+
| Page Header    |  24 bytes
+----------------+
| Item Pointers  |  4 bytes each
+----------------+
| Free Space     |  Variable
+----------------+
| Items (Tuples) |  Variable
+----------------+
| Special Space  |  Variable
+----------------+
```

**Tuple Structure**:
```sql
-- Example table
CREATE TABLE users (
  id bigint,
  name text,
  email text,
  created_at timestamp
);

-- Actual storage (simplified)
Header (23B) | Null Bitmap | Data | Alignment Padding
```

**Monitoring Heap Usage**:
```sql
-- Table size information
SELECT pg_size_pretty(pg_relation_size('users')) as heap_size,
       pg_size_pretty(pg_total_relation_size('users')) as total_size;
```

**When to consider**:
- Table design decisions
- Storage optimization
- VACUUM planning
- Performance tuning

**Tips**:
- Monitor table bloat
- Regular VACUUM
- Consider FILLFACTOR
- Watch for table growth
</details>

### Hypertable
A TimescaleDB abstraction that automatically partitions time-series data into chunks.

<details>
<summary>Detailed Explanation</summary>

**Creation Example**:
```ruby
# Using Ruby migration
class CreateMeasurements < ActiveRecord::Migration[7.0]
  def change
    create_table :measurements do |t|
      t.timestamp :time, null: false
      t.string :device_id, null: false
      t.float :temperature
      t.float :humidity
      t.timestamps
    end

    # Convert to hypertable
    execute <<-SQL
      SELECT create_hypertable('measurements', 'time',
        chunk_time_interval => INTERVAL '1 day');
    SQL
  end
end
```

**TimescaleDB Model**:
```ruby
class Measurement < ApplicationRecord
  acts_as_hypertable(
    time_column: 'time',
    chunk_time_interval: '1 day',
    compress_after: '7 days',
    compress_segmentby: ['device_id']
  )
end
```

**Chunk Management**:
```sql
-- View chunks
SELECT show_chunks('measurements');

-- Compress chunks
SELECT compress_chunk(chunk)
FROM show_chunks('measurements') AS chunk
WHERE chunk_completion_time < NOW() - INTERVAL '7 days';

-- Add retention policy
SELECT add_retention_policy('measurements', 
  INTERVAL '6 months');
```

**When to use**:
- Time-series data
- IoT applications
- Monitoring systems
- Log analytics

**Tips**:
- Choose appropriate chunk interval
- Use compression for old data
- Implement retention policies
- Consider replication strategy
</details>

## I

### Index
A data structure that improves query performance by providing quick access to rows.

<details>
<summary>Detailed Explanation</summary>

**Common Index Types**:
```sql
-- B-tree (default)
CREATE INDEX idx_users_email ON users(email);

-- BRIN (block range)
CREATE INDEX idx_events_time ON events USING brin(created_at);

-- GiST (geometric/geographic)
CREATE INDEX idx_locations_position 
ON locations USING gist(position);

-- GIN (full-text search)
CREATE INDEX idx_documents_content 
ON documents USING gin(to_tsvector('english', content));
```

**Ruby Migrations**:
```ruby
class AddIndexesToUsers < ActiveRecord::Migration[7.0]
  def change
    # Simple index
    add_index :users, :email

    # Multi-column index
    add_index :users, [:last_name, :first_name]

    # Unique index
    add_index :users, :username, unique: true

    # Partial index
    add_index :users, :email, 
      where: "deleted_at IS NULL"

    # Expression index
    add_index :users, "LOWER(email)"
  end
end
```

**Index Usage Analysis**:
```sql
-- Check index usage
SELECT schemaname, tablename, indexname, 
       idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes;

-- Find unused indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND idx_is_unique IS FALSE;
```

**When to use each type**:
- B-tree: General purpose, equality/range queries
- BRIN: Time-series, sequential data
- GiST: Geometric data, nearest neighbor
- GIN: Full-text search, array containment

**Tips**:
- Index selective columns
- Consider maintenance overhead
- Monitor index usage
- Remove unused indexes
</details>

### Isolation Level
The degree to which concurrent transactions are isolated from each other.

<details>
<summary>Detailed Explanation</summary>

**Levels and Phenomena**:
```ruby
# Read Committed (default)
Account.transaction do
  # Can see changes from other committed transactions
  balance = account.balance
  sleep(1) # Another transaction commits
  # Might see different balance here
end

# Repeatable Read
Account.transaction(isolation: :repeatable_read) do
  # Same data throughout transaction
  balance = account.balance
  sleep(1) # Another transaction commits
  # Still sees original balance
end

# Serializable
Account.transaction(isolation: :serializable) do
  # Strongest isolation, may need retries
  balance = account.balance
  # Prevents all anomalies but may fail
end
```

**Comparison Table**:
```
Level           | Dirty Read | Non-Repeatable Read | Phantom Read
----------------|------------|--------------------|--------------
Read Committed  | No         | Yes                | Yes
Repeatable Read | No         | No                 | No*
Serializable    | No         | No                 | No

* PostgreSQL prevents phantom reads in Repeatable Read
```

**Use Cases**:
```ruby
# Read Committed: Default, good for most cases
Order.transaction do
  order.update!(status: 'processing')
end

# Repeatable Read: Consistent calculations
Account.transaction(isolation: :repeatable_read) do
  total = accounts.sum(:balance)
  accounts.each { |a| a.update!(balance: a.balance * 2) }
end

# Serializable: Critical financial operations
Account.transaction(isolation: :serializable) do
  from_account.update!(balance: from_account.balance - amount)
  to_account.update!(balance: to_account.balance + amount)
end
```

**When to use each level**:
- Read Committed: Default, general purpose
- Repeatable Read: Reports, consistent reads
- Serializable: Financial transactions

**Tips**:
- Higher isolation = lower concurrency
- Implement retry logic for serializable
- Monitor deadlocks and conflicts
- Choose appropriate level for use case
</details>

## J

### JOIN
An operation that combines rows from two or more tables based on related columns.

<details>
<summary>Detailed Explanation</summary>

**Types of JOINs**:
```sql
-- INNER JOIN
SELECT users.*, orders.id as order_id
FROM users
INNER JOIN orders ON users.id = orders.user_id;

-- LEFT JOIN
SELECT users.*, COALESCE(COUNT(orders.id), 0) as order_count
FROM users
LEFT JOIN orders ON users.id = orders.user_id
GROUP BY users.id;

-- RIGHT JOIN
SELECT orders.*, users.email
FROM orders
RIGHT JOIN users ON users.id = orders.user_id;

-- FULL OUTER JOIN
SELECT *
FROM table1
FULL OUTER JOIN table2 ON table1.id = table2.ref_id;
```

**ActiveRecord Examples**:
```ruby
# INNER JOIN
User.joins(:orders)
    .select('users.*, COUNT(orders.id) as order_count')
    .group('users.id')

# LEFT JOIN (includes)
User.includes(:orders)
    .where(orders: { status: 'pending' })

# Complex joins
User.joins(:orders, :profile)
    .includes(:address)
    .where(orders: { status: 'completed' })
    .where(profiles: { verified: true })
```

**Performance Optimization**:
```ruby
# N+1 Problem
users = User.all
users.each { |u| puts u.orders.count } # Bad: N+1 queries

# Solution 1: includes
users = User.includes(:orders)
users.each { |u| puts u.orders.count } # Good: 2 queries

# Solution 2: joins with count
users = User.joins(:orders)
            .select('users.*, COUNT(orders.id) as order_count')
            .group('users.id')
users.each { |u| puts u.order_count } # Best: 1 query
```

**When to use each type**:
- INNER JOIN: When you need matching rows
- LEFT JOIN: When you need all records from first table
- RIGHT JOIN: Rarely used (use LEFT JOIN instead)
- FULL OUTER JOIN: When you need all records from both tables

**Tips**:
- Use appropriate indexes
- Consider join order
- Watch for cartesian products
- Use EXPLAIN to analyze performance
</details>

## M

### Materialized View
A table-like database object that contains the results of a query.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:
```sql
-- Create materialized view
CREATE MATERIALIZED VIEW daily_order_stats AS
SELECT DATE_TRUNC('day', created_at) as date,
       COUNT(*) as order_count,
       SUM(total) as total_sales
FROM orders
GROUP BY 1
WITH DATA;

-- Refresh materialized view
REFRESH MATERIALIZED VIEW daily_order_stats;

-- Create index on materialized view
CREATE INDEX idx_daily_stats_date 
ON daily_order_stats(date);
```

**Ruby Implementation**:
```ruby
# Using Scenic gem
class CreateDailyOrderStats < ActiveRecord::Migration[7.0]
  def change
    create_view :daily_order_stats, materialized: true
    
    add_index :daily_order_stats, :date, 
      name: 'index_daily_order_stats_on_date'
  end
end

# app/views/daily_order_stats.sql
SELECT DATE_TRUNC('day', created_at) as date,
       COUNT(*) as order_count,
       SUM(total) as total_sales
FROM orders
GROUP BY 1;

# app/models/daily_order_stat.rb
class DailyOrderStat < ApplicationRecord
  # Scenic model
  def self.refresh
    Scenic.database.refresh_materialized_view(
      :daily_order_stats,
      concurrently: true,
      cascade: false
    )
  end
end
```

**When to use**:
- Complex, expensive queries
- Frequently accessed reports
- Data warehouse scenarios
- Periodic analytics

**Tips**:
- Consider refresh frequency
- Use concurrent refresh when possible
- Index materialized views
- Monitor size and performance
</details>

To rollup partial refresh, also see [continuous aggregates](#continuous-aggregate).

### MVCC (Multi-Version Concurrency Control)

PostgreSQL's method for handling concurrent access to data.

<details>
<summary>Detailed Explanation</summary>

Imagine a table as a timeline of transactions. Each transaction has a unique id and a timestamp. The timestamp is the time when the transaction started.

* When a transaction updates a row, it creates a new version of the row. The new version is the row as it was before the transaction started.
* When a transaction reads a row, it sees the latest version of the row.
* When a transaction commits, it updates the row with the new values. The new version is the row as it was before the transaction started.
* When a transaction is rolled back, it deletes the new version of the row.

**Visual Representation**:
```ascii
Transaction Timeline and Row Versions
┌──────────────────────────────────────────────────────┐
│ Time ──────────────────────────────────────────────► │
│                                                      │
│ Txn 1    ┌──────┐ UPDATE row      COMMIT             │
│          │ Begin │────────┐───────────┐              │
│          └──────┘         │           │              │
│                          ┌▼─────────┐  │             │
│ Row      │ Version 1 │──►│Version 2 │◄─┘             │
│ Versions └──────────┘    └─────────┘                 │
│                          │                           │
│ Txn 2              ┌─────▼────┐        ┌─────┐       │
│                    │ SELECT   │────────►│ v1  │      │
│                    └──────────┘        └─────┘       │
└──────────────────────────────────────────────────────┘

Tuple Structure with MVCC Info
┌──────────────────────────────────────────┐
│              Tuple Header                │
├──────────┬──────────┬──────────┬─────────┤
│  xmin    │  xmax    │  command │ infomask│
│(creator) │(deleter) │   id     │         │
├──────────┴──────────┴──────────┴─────────┤
│             Tuple Data                   │
└──────────────────────────────────────────┘

MVCC Visibility Rules
┌─────────────────┐     ┌──────────────┐
│ Current Txn: 50 │     │ Snapshot     │
└────────┬────────┘     │ xmin: 45     │
         │              │ xmax: 50     │
         │              │ active: [48] │
         ▼              └──────────────┘
┌─────────────────────────────────────────┐
│ Row visible if:                         │
│ 1. xmin committed AND                   │
│ 2. xmin < snapshot.xmax AND             │
│ 3. xmax null OR xmax > snapshot.xmin OR │
│    xmax in active transactions          │
└─────────────────────────────────────────┘
```

</details>

## P

### Partition
A division of a large table into smaller physical pieces for better performance. That's it.

<details>
<summary>Detailed Explanation</summary>

Partitioning is a way to divide a large table into smaller physical pieces for better performance. The greatest part is that it also includes metadata and indexes on the partition. It makes all processing units smaller as they need to process only a part of the table.

  Here you can grasp the concept of partitioning and how the TimescaleDB hypertables works behind the scenes.

**Partition Types**:
```sql
-- Range Partitioning
CREATE TABLE events (
    id bigint,
    created_at timestamp,
    data jsonb
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2024_q1 
PARTITION OF events
FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

-- List Partitioning
CREATE TABLE orders (
    id bigint,
    status text,
    data jsonb
) PARTITION BY LIST (status);

CREATE TABLE orders_completed 
PARTITION OF orders
FOR VALUES IN ('completed');

-- Hash Partitioning
CREATE TABLE users (
    id bigint,
    email text,
    data jsonb
) PARTITION BY HASH (id);

CREATE TABLE users_0 
PARTITION OF users
FOR VALUES WITH (MODULUS 4, REMAINDER 0);
```

**Partition Management**:

The boring part of plain partitioning is maintenance. You need to attach, detach and move data between partitions.

```sql
-- Attach new partition
ALTER TABLE events 
ATTACH PARTITION events_2024_q2
FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

-- Detach partition
ALTER TABLE events 
DETACH PARTITION events_2023_q4;

-- Move data between partitions
WITH moved_rows AS (
    DELETE FROM events_2023_q4
    RETURNING *
)
INSERT INTO events_archive
SELECT * FROM moved_rows;
```

**Partitioning with TimescaleDB**:

You can use TimescaleDB extension to automatically create partitions on demand.

```sql
-- Automatically create partitions using TimescaleDB
select create_hypertable('events', by_range('created_at', INTERVAL '3 month'));
```

Timescale also allows to make partitions based on more than one dimension.

```sql
SELECT add_dimension('events', by_hash('user_id', 4));
```

**When to use partitioning**:

- Very large tables (>100GB)
- Time-based data retention
- Different storage policies
- Performance optimization

**Tips**:
- Choose appropriate partition key
- Plan for future growth
- Consider maintenance overhead
- Monitor partition usage

For more information, see [PostgreSQL Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html).

</details>

### Primary Key
A column or set of columns that uniquely identifies each row in a table.

<details>
<summary>Detailed Explanation</summary>

**Creation Examples**:
```sql
-- Single column primary key
CREATE TABLE users (
    id bigserial PRIMARY KEY,
    email text UNIQUE,
    name text
);

-- Composite primary key
CREATE TABLE order_items (
    order_id bigint,
    item_id bigint,
    quantity integer,
    PRIMARY KEY (order_id, item_id)
);
```

**Ruby Migration**:
```ruby
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.timestamps
      
      t.index :email, unique: true
    end
    
    # Composite primary key example
    create_table :order_items, id: false do |t|
      t.bigint :order_id, null: false
      t.bigint :item_id, null: false
      t.integer :quantity
      
      t.primary_key [:order_id, :item_id]
    end
  end
end
```

**Performance Considerations**:

If you have a primary key, it will be used to speed up the queries. But you need to consider that it will also slow down the inserts and updates.

```sql
-- Check primary key usage
SELECT schemaname, relname, indexrelname, 
       idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE indexrelname LIKE '%pkey';

-- Monitor sequential scans
SELECT schemaname, relname, seq_scan, seq_tup_read
FROM pg_stat_user_tables;
```

**When to use different types**:
- Auto-incrementing: General purpose
- UUID: Distributed systems
- Natural keys: Domain-specific requirements
- Composite keys: Complex relationships

**Tips**:
- Choose appropriate data type
- Consider clustering order
- Monitor index usage
- Plan for scalability
</details>

## Q

### Query Plan

The sequence of operations PostgreSQL will perform to execute a query. The planning works like a route calculator. Look at the query and determine the best way to execute it.

<details>
<summary>Detailed Explanation</summary>

**Planning Process**:

1. **Parsing**: Convert SQL into a parse tree
2. **Planning**: Convert parse tree into a query plan
3. **Execution**: Execute the query plan

**Query Plan Components**:

- **Planner**: Determines the best way to execute the query
- **Cost**: Estimated cost of executing the query
- **Operator**: The operation to execute
- **Subplan**: A subquery in the query

**Query Plan Example**: 

```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE id = 1;
``` 

**Query Plan Output**:

```sql
QUERY PLAN
Seq Scan on users (cost=0.00..1.00 rows=1 width=8) (actual time=0.016..0.016 rows=1 loops=1)
Filter: (id = 1)
Rows Removed by Filter: 999999
```

**Query Plan Analysis**:

- **Seq Scan**: Sequential scan of the table
- **Filter**: Filter the rows where id = 1
- **Rows Removed by Filter**: 999999 rows were removed by the filter  

**Query Plan Tips**:

- **Cost**: The cost of the query plan
- **Operator**: The operation to execute
- **Subplan**: A subquery in the query 

Extra resources:
- Use visual tools like [explain.depesz.com](https://explain.depesz.com/) to visually understand the query plan.
- [Explaining PostgreSQL Explain](https://www.timescale.com/learn/explaining-postgresql-explain)
- [PostgreSQL Query Plan Visualization](https://pganalyze.com/docs/query-plans)

</details>

## R

### REINDEX
A command to rebuild corrupted or outdated indexes.

### ROLLBACK

A command that undoes all changes made in the current transaction. Think about it like a time machine. It allows you to undo the changes you made in the current transaction.

The coolest part of it is that you can rollback to a specific point in time.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:

```sql
BEGIN;
UPDATE users SET balance = balance - 100 WHERE id = 1;
SELECT balance FROM users WHERE id = 1; -- 900
ROLLBACK;
SELECT balance FROM users WHERE id = 1; -- 1000
```

**When to use**:
- When you want to undo the changes you made in the current transaction
- When you want to rollback to a specific point in time
- When you want to undo the changes you made in the current transaction

**Tips**:
- Use `SAVEPOINT` to save a point in time
- Use `ROLLBACK TO SAVEPOINT` to rollback to a specific point in time
- Use `RELEASE SAVEPOINT` to release a savepoint

Example:
```sql
BEGIN;
UPDATE users SET balance = balance - 100 WHERE id = 1;
-- 900
SELECT balance FROM users WHERE id = 1; 
SAVEPOINT my_savepoint;
UPDATE users SET balance = balance + 100 WHERE id = 1;
-- 1000
SELECT balance FROM users WHERE id = 1; 
ROLLBACK TO SAVEPOINT my_savepoint;
-- 900
SELECT balance FROM users WHERE id = 1; 
RELEASE SAVEPOINT my_savepoint;
COMMIT;
-- 1000
SELECT balance FROM users WHERE id = 1; 
```

The main difference between `ROLLBACK` and `ROLLBACK TO SAVEPOINT` is that `ROLLBACK` undoes all changes made in the current transaction, while `ROLLBACK TO SAVEPOINT` undoes all changes made after the savepoint was created.

</details>

## S

### Sequence
A database object that generates unique numeric identifiers.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:
```sql
CREATE SEQUENCE users_id_seq;
SELECT nextval('users_id_seq'); -- 1
SELECT setval('users_id_seq', 100); -- update the sequence to 100
SELECT currval('users_id_seq'); -- 100
SELECT lastval(); -- 100
```

**Ruby Implementation**:
```ruby
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_sequence :users_id_seq
  end
end
```

**When to use**:
- When you need a unique numeric identifier
- When you need a unique identifier for a table
- When you need a unique identifier for a table

**Tips**:
- Use `nextval` to get the next value in the sequence
- Use `setval` to set the value of the sequence
- Use `currval` to get the current value of the sequence
- Use `lastval` to get the last value of the sequence

The shortest way to get a sequence is use `serial` in the migration.

```ruby
create_table :users do |t|
  t.serial :id
end
```

This will create a sequence called `users_id_seq` and a column `id` that will be an integer. The column will be auto-incremented.

</details>


### Statistics
Information about table contents used by the query planner. It's very important to understand that the query planner uses the statistics to determine the best way to execute the query.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:
```sql
ANALYZE users;
```

**Why statistics are important for performance**:

- The query planner uses the statistics to determine the best way to execute the query.
- The query planner uses the statistics to determine the best way to execute the query.

**Tips**:
- Use `ANALYZE` to update the statistics
- Use `VACUUM ANALYZE` to update the statistics and vacuum the table
- Use `VACUUM FULL ANALYZE` to update the statistics and vacuum the table

The difference of having  FULL ANALYZE is that it will rewrite the table.


</details>

## T

### TOAST (The Oversized-Attribute Storage Technique)
PostgreSQL's mechanism for handling large field values:
- Compresses large values
- Stores them in a separate table
- Transparent to users

### Transaction
A unit of work that must be completed entirely or not at all.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:
```ruby
# Simple transaction
Account.transaction do
  account1.update!(balance: account1.balance - 100)
  account2.update!(balance: account2.balance + 100)
end

# Nested transactions
Account.transaction do
  account1.update!(balance: account1.balance - 100)
  
  Account.transaction(requires_new: true) do
    # This transaction can rollback independently
    account2.update!(balance: account2.balance + 100)
  end
end

# Custom transaction options
Account.transaction(isolation: :serializable,
                   joinable: false,
                   retry_on: [PG::DeadlockDetected]) do
  # Transaction code
end
```

**Error Handling**:
```ruby
def transfer_money(from_account, to_account, amount)
  Account.transaction do
    from_account.with_lock do
      to_account.with_lock do
        from_account.update!(balance: from_account.balance - amount)
        to_account.update!(balance: to_account.balance + amount)
      end
    end
  rescue ActiveRecord::RecordInvalid
    # Handle validation errors
  rescue ActiveRecord::StaleObjectError
    # Handle optimistic locking failures
  rescue PG::DeadlockDetected
    # Handle deadlocks
  end
end
```

**When to use**:
- Related updates
- Data consistency
- Error handling
- Complex operations

**Tips**:
- Keep transactions short
- Handle errors properly
- Consider isolation levels
- Monitor transaction time

**Related Concepts**:
- See [ACID Properties](#acid) for transaction properties
- See [Isolation Level](#isolation-level) for transaction isolation
- See [Deadlock](#deadlock) for concurrency issues
- See [WAL](#wal-write-ahead-log) for durability
</details>

## V

### VACUUM
A process that reclaims storage from dead tuples.

<details>
<summary>Detailed Explanation</summary>

**Basic Commands**:
```sql
-- Simple VACUUM
VACUUM users;

-- VACUUM with analysis
VACUUM ANALYZE users;

-- VACUUM FULL (rewrites table)
VACUUM FULL users;

-- Monitor VACUUM
SELECT relname, 
       last_vacuum,
       last_autovacuum,
       vacuum_count
FROM pg_stat_user_tables;
```

**Ruby Implementation**:
```ruby
class VacuumUsers < ActiveRecord::Migration[7.0]
  def up
    execute "VACUUM ANALYZE users;"
  end
end

# Vacuum monitoring
module VacuumMonitor
  def self.check_tables
    results = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT schemaname,
             relname,
             n_dead_tup,
             n_live_tup,
             last_vacuum
      FROM pg_stat_user_tables
      WHERE n_dead_tup > n_live_tup * 0.2;
    SQL
    
    results.each do |row|
      puts "Table #{row['relname']} needs VACUUM"
    end
  end
end
```

**When to VACUUM**:
- High update/delete activity
- Table bloat
- Performance degradation
- Regular maintenance

**Tips**:
- Regular automated VACUUM
- Monitor dead tuples
- Use VACUUM ANALYZE
- Avoid VACUUM FULL in production

**Related Concepts**:
- See [MVCC](#mvcc) for version control
- See [Transaction](#transaction) for data consistency
- See [Statistics](#statistics) for data analysis
- See [Buffer Management](#buffer-management) for memory impact
</details>

### View
A stored query that can be treated like a virtual table.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:
```sql
-- Create view
CREATE VIEW active_users AS
SELECT *
FROM users
WHERE last_login > NOW() - INTERVAL '30 days';

-- Create view with check option
CREATE VIEW premium_users AS
SELECT *
FROM users
WHERE subscription_type = 'premium'
WITH CHECK OPTION;
```

**Ruby Implementation**:
```ruby
# Using Scenic gem
class CreateActiveUsersView < ActiveRecord::Migration[7.0]
  def change
    create_view :active_users
  end
end

# app/views/active_users.sql
SELECT *
FROM users
WHERE last_login > NOW() - INTERVAL '30 days';

# app/models/active_user.rb
class ActiveUser < ApplicationRecord
  # Read-only model for view
  def readonly?
    true
  end
end
```

**When to use**:
- Simplify complex queries
- Data access control
- Logical data organization
- Backward compatibility

**Tips**:
- Consider materialized views
- Index underlying tables
- Monitor view performance
- Use appropriate permissions

**Related Concepts**:
- See [Materialized View](#materialized-view) for cached views
- See [Query Plan](#query-plan) for optimization
- See [Statistics](#statistics) for performance
- See [Index](#index) for view performance
</details>

### WAL (Write-Ahead Log)
A mechanism ensuring data integrity by logging changes before they are written to data files.

<details>
<summary>Detailed Explanation</summary>

**Visual Representation**:
```ascii
WAL Write Process
┌─────────────────────────────────────────────────────┐
│                                                     │
│  Client   Transaction   WAL Buffer    WAL Files     │
│                                                     │
│  ┌────┐   ┌────────┐   ┌─────────┐  ┌──────────┐    │
│  │App │──►│BEGIN   │──►│ WAL Rec │─►│Segment 1 │    │
│  └────┘   │UPDATE  │   │ Buffer  │  └──────────┘    │
│           │COMMIT  │   └─────────┘  ┌──────────┐    │
│           └────────┘                │Segment 2 │    │
│                                     └──────────┘    │
└─────────────────────────────────────────────────────┘

WAL Record Structure
┌─────────────────────────────────────────────────┐
│                  WAL Record                     │
├────────┬─────────┬──────────┬──────────┬────────┤
│Header  │Resource │Previous  │Data      │CRC     │
│Info    │Manager  │LSN       │Block     │32      │
├────────┴─────────┴──────────┴──────────┴────────┤
│             Transaction Data                    │
└─────────────────────────────────────────────────┘

Checkpoint Process
┌────────────────────────────────────────────────┐
│                                                │
│ Memory        Disk         WAL                 │
│ ┌─────────┐  ┌─────────┐  ┌─────────┐          │
│ │Dirty    │  │         │  │         │ ──────►  │
│ │Buffers  │─►│Data     │  │Checkpoint│ Time    │
│ └─────────┘  │Files    │  │Record   │          │
│              └─────────┘  └─────────┘          │
│                                                │
└────────────────────────────────────────────────┘

Recovery Process
┌────────────────────────────────────────────┐
│           Recovery Timeline                │
│                                            │
│ Last Checkpoint    WAL Records    Current  │
│      ┌───┐          ┌───┐         ┌───┐    │
│ ─────►│   │─────────►│   │────────►│   │   │
│      └───┘          └───┘         └───┘    │
│        │              │             │      │
│     Restore        Replay         Ready    │
│     Snapshot       Changes        to Run   │
└────────────────────────────────────────────┘
```

</details>

### Window Function
A function that performs calculations across a set of rows related to the current row.

<details>
<summary>Detailed Explanation</summary>

**Basic Usage**:
```sql
-- Row number within partition
SELECT *,
       ROW_NUMBER() OVER (
         PARTITION BY department_id 
         ORDER BY salary DESC
       ) as salary_rank
FROM employees;

-- Running totals
SELECT *,
       SUM(amount) OVER (
         ORDER BY created_at
         ROWS BETWEEN UNBOUNDED PRECEDING 
         AND CURRENT ROW
       ) as running_total
FROM transactions;
```

**Ruby/ActiveRecord Usage**:
```ruby
# Using Arel for window functions
class Employee < ApplicationRecord
  def self.with_department_rank
    select(<<-SQL)
      employees.*,
      ROW_NUMBER() OVER (
        PARTITION BY department_id
        ORDER BY salary DESC
      ) as salary_rank
    SQL
  end
  
  def self.with_running_totals
    select(<<-SQL)
      employees.*,
      SUM(salary) OVER (
        ORDER BY hired_at
        ROWS BETWEEN UNBOUNDED PRECEDING 
        AND CURRENT ROW
      ) as running_total
    SQL
  end
end
```

**Common Functions**:
```sql
-- Ranking functions
ROW_NUMBER()
RANK()
DENSE_RANK()
NTILE(n)

-- Offset functions
LAG(column, offset)
LEAD(column, offset)
FIRST_VALUE(column)
LAST_VALUE(column)

-- Aggregate functions
SUM(column)
AVG(column)
COUNT(column)
```

**When to use**:
- Ranking calculations
- Running totals
- Moving averages
- Gap analysis

**Tips**:
- Consider performance impact
- Use appropriate frame clause
- Index ORDER BY columns
- Monitor memory usage

**Related Concepts**:
- See [Aggregate Functions](#aggregate-functions) for basic aggregation
- See [Query Plan](#query-plan) for optimization
- See [Index](#index) for performance
- See [Statistics](#statistics) for data analysis
</details>

## Related Documentation

- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Ruby on Rails Active Record Documentation](https://guides.rubyonrails.org/active_record_basics.html) 