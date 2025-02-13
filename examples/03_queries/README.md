# PostgreSQL Query Optimization Workshop

This section focuses on understanding and optimizing PostgreSQL queries through practical examples and real-world scenarios.

## Files Overview

1. `query_explorer.rb`: Core utility for analyzing query execution plans
2. `practice_queries.rb`: Basic examples for getting started
3. `query_optimization_lab.rb`: Structured exercises with sample data
4. `advanced_queries.rb`: Complex query patterns and optimizations

## Basic PostgreSQL Concepts

### Relations
In PostgreSQL, a relation is a fundamental database object that represents a set of data. The two main types of relations are:

1. **Tables**: Persistent relations that store data in rows and columns
2. **Views**: Virtual relations defined by a query
3. **Materialized Views**: Cached result sets of a query that can be periodically refreshed

### Operators
PostgreSQL provides several types of operators:

1. **Comparison Operators**:
   - `=`, `<>`, `<`, `>`, `<=`, `>=`
   - `BETWEEN`, `IN`, `LIKE`, `ILIKE`

2. **Logical Operators**:
   - `AND`, `OR`, `NOT`

3. **Mathematical Operators**:
   - `+`, `-`, `*`, `/`, `%`
   - `^`, `|`, `&`, `<<`, `>>`

4. **Set Operators**:
   - `UNION`, `INTERSECT`, `EXCEPT`

### JOIN Operations
JOINs are fundamental operations in relational databases that combine rows from two or more tables based on a related column between them.

1. **INNER JOIN**:
   - Returns only the matching rows between tables
   - Most common type of join
   - Example: `SELECT * FROM orders JOIN customers ON orders.customer_id = customers.id`

2. **LEFT (OUTER) JOIN**:
   - Returns all rows from the left table and matching rows from the right table
   - Non-matching rows filled with NULL
   - Example: `SELECT * FROM customers LEFT JOIN orders ON customers.id = orders.customer_id`

3. **RIGHT (OUTER) JOIN**:
   - Returns all rows from the right table and matching rows from the left table
   - Non-matching rows filled with NULL
   - Example: `SELECT * FROM orders RIGHT JOIN customers ON orders.customer_id = customers.id`

4. **FULL (OUTER) JOIN**:
   - Returns all rows from both tables
   - Non-matching rows filled with NULL
   - Example: `SELECT * FROM orders FULL JOIN customers ON orders.customer_id = customers.id`

5. **CROSS JOIN**:
   - Returns Cartesian product of both tables
   - Every row from first table paired with every row from second table
   - Example: `SELECT * FROM sizes CROSS JOIN colors`

6. **NATURAL JOIN**:
   - Automatically joins tables using columns with the same name
   - Implicitly matches ALL columns with same names
   - Eliminates duplicate columns in the output
   - Example: `SELECT * FROM orders NATURAL JOIN order_items`
   - ⚠️ Warning: Use with caution as it can lead to unexpected results if:
     - Column names change
     - New columns with same names are added
     - Tables have multiple common column names

### Data Types

1. **Numeric Types**:
   - `INTEGER`, `BIGINT`, `SMALLINT`
   - `DECIMAL`, `NUMERIC`, `REAL`, `DOUBLE PRECISION`

2. **Character Types**:
   - `CHAR`, `VARCHAR`, `TEXT`

3. **Date/Time Types**:
   - `DATE`, `TIME`, `TIMESTAMP`
   - `INTERVAL`

4. **Special Types**:
   - `BOOLEAN`
   - `UUID`
   - `JSON`, `JSONB`
   - `ARRAY`

### Schema Objects

1. **Tables**: Basic structure for data storage
2. **Indexes**: Improve query performance
3. **Constraints**: Enforce data integrity
   - PRIMARY KEY
   - FOREIGN KEY
   - UNIQUE
   - CHECK
   - NOT NULL

### Transaction Properties (ACID)

1. **Atomicity**: All operations in a transaction succeed or all fail
2. **Consistency**: Database remains in a valid state
3. **Isolation**: Concurrent transactions don't interfere
4. **Durability**: Committed changes are permanent

## Visual Query Workflows

### Query Processing Pipeline
```mermaid
flowchart LR
    A[SQL Query] --> B[Parser]
    B --> C[Rewriter]
    C --> D[Optimizer]
    D --> E[Executor]
    E --> F[Results]

    subgraph "1. Parsing"
        B --> B1[Syntax Check]
        B1 --> B2[Create Parse Tree]
    end

    subgraph "2. Rewriting"
        C --> C1[View Expansion]
        C1 --> C2[Rule Application]
    end

    subgraph "3. Optimization"
        D --> D1[Generate Plans]
        D1 --> D2[Cost Estimation]
        D2 --> D3[Plan Selection]
    end
```

### JOIN Visualization
```mermaid
flowchart TD
    subgraph "INNER JOIN"
        A((Table A)) --> C{JOIN}
        B((Table B)) --> C
        C --> D[Matching Rows Only]
    end

    subgraph "LEFT JOIN"
        E((Table A)) --> G{JOIN}
        F((Table B)) --> G
        G --> H[All A + Matching B]
    end

    subgraph "FULL JOIN"
        I((Table A)) --> K{JOIN}
        J((Table B)) --> K
        K --> L[All Rows + NULLs]
    end
```

### Query Plan Tree
```mermaid
flowchart TD
    A[Hash Join] --> B[Hash]
    A --> C[Seq Scan orders]
    B --> D[Seq Scan customers]
    
    style A fill:#f9f,stroke:#333
    style B fill:#bbf,stroke:#333
    style C fill:#bfb,stroke:#333
    style D fill:#bfb,stroke:#333
```

### Data Flow Through Joins
```mermaid
flowchart LR
    subgraph "Nested Loop Join"
        A[Outer Table] --> B[For each row]
        B --> C[Scan Inner]
        C --> D[Match?]
        D -->|Yes| E[Output Row]
        D -->|No| B
    end

    subgraph "Hash Join"
        F[Build Table] --> G[Create Hash Table]
        H[Probe Table] --> I[Hash Lookup]
        G --> I
        I --> J[Match?]
        J -->|Yes| K[Output Row]
    end
```

### Index Usage Patterns
```mermaid
flowchart TD
    A[Query with WHERE] --> B{Index Available?}
    B -->|Yes| C{Selective?}
    B -->|No| D[Sequential Scan]
    C -->|Yes| E[Index Scan]
    C -->|No| D
    
    style D fill:#f99,stroke:#333
    style E fill:#9f9,stroke:#333
```

## Query Execution Flow

```mermaid
flowchart TD
    A[SQL Query] --> B[Parser]
    B --> C[Rewriter]
    C --> D[Planner/Optimizer]
    D --> E[Executor]
    E --> F[Results]
    
    subgraph Planning
    D --> D1[Generate Plans]
    D1 --> D2[Cost Estimation]
    D2 --> D3[Plan Selection]
    end
```

## EXPLAIN ANALYZE Workflow

```mermaid
flowchart LR
    A[Query] --> B[EXPLAIN ANALYZE]
    B --> C{Node Types}
    C --> D[Seq Scan]
    C --> E[Index Scan]
    C --> F[Hash Join]
    C --> G[Nested Loop]
    
    subgraph Metrics
    M1[Cost] --> M2[Actual Time]
    M2 --> M3[Rows]
    M3 --> M4[Buffers]
    end
```

## Learning Path

### 1. Understanding EXPLAIN ANALYZE Basics

Think of EXPLAIN ANALYZE as PostgreSQL's built-in GPS navigation system for your queries. Just like a GPS calculates multiple routes and picks the optimal path based on traffic, distance, and road conditions, EXPLAIN ANALYZE:

- Evaluates multiple possible execution paths for your query
- Estimates the "cost" of each path based on table statistics, indexes, and data distribution
- Chooses the path it believes will be fastest
- Actually executes the query and shows you real timing data

Key benefits:
- Helps identify slow queries and bottlenecks
- Shows exactly how PostgreSQL executes your query
- Provides actual vs. estimated statistics to improve query planning
- Reveals opportunities for adding indexes or restructuring queries

Interactive example:

#### 1.1 Simple Query Analysis

```sql
SELECT * FROM customers WHERE country = 'USA';

-- EXPLAIN output components:
Seq Scan on customers  (cost=0.00..2.62 rows=10 width=8)
  Filter: ((country)::text = 'USA'::text)
  Rows Removed by Filter: 40
```

Key components to understand:
- **Node Type** (e.g., `Seq Scan`): How PostgreSQL accesses the data
- **Cost**: Estimated processing cost (first number is startup, second is total)
- **Rows**: Estimated number of rows to be processed
- **Width**: Estimated average width of rows in bytes

#### 1.2 Reading Execution Statistics

```sql
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM customers WHERE country = 'USA';

-- Output includes:
Seq Scan on customers (cost=0.00..2.62 rows=10 width=8) (actual time=0.004..0.007 rows=10 loops=1)
  Filter: ((country)::text = 'USA'::text)
  Rows Removed by Filter: 40
  Buffers: shared hit=2
```

Additional metrics:
- **actual time**: Real execution time (ms) - startup time..total time
- **rows**: Actual number of rows processed
- **loops**: Number of times this node was executed
- **Buffers**: Memory/disk page access statistics

### 2. Common Access Methods

```mermaid
flowchart TD
    A[Table Access Methods] --> B[Sequential Scan]
    A --> C[Index Scan]
    A --> D[Index Only Scan]
    
    B --> B1[Full Table Scan]
    C --> C1[B-tree Index]
    C --> C2[Hash Index]
    D --> D1[Covering Index]
```

#### 2.1 Sequential Scan

A sequential scan reads the entire table from start to finish by scanning each page sequentially. While this seems inefficient, it's actually optimal when:
- Reading a large portion of the table (>5-10% of rows)
- The table is small enough to fit in memory
- No suitable indexes exist

#### 2.2 Index Scan

An index scan uses an index to quickly locate the rows that match the query conditions. It's efficient when:
- The query filters on indexed columns
- The index covers the columns needed in the query

#### 2.3 Index Only Scan

An index only scan uses an index to quickly locate the rows that match the query conditions. It's efficient when:  
- The query filters on indexed columns
- The index includes all needed columns 

#### 2.4 Bitmap Index Scan

A bitmap index scan uses a bitmap to quickly locate the rows that match the query conditions. It's efficient when:
- The query filters on indexed columns
- The index includes all needed columns

### 3. Join Operations

```mermaid
flowchart LR
    A[Join Types] --> B[Nested Loop]
    A --> C[Hash Join]
    A --> D[Merge Join]
    
    B --> B1[Small Tables]
    C --> C1[Large Tables]
    D --> D1[Sorted Data]
```

#### 3.1 Nested Loop Join
```sql
-- Good for small tables or when joining with highly selective conditions
SELECT c.name, o.id 
FROM customers c 
JOIN orders o ON c.id = o.customer_id 
WHERE c.country = 'USA';
```

Example plan:
```
Nested Loop  (cost=0.28..16.32 rows=10 width=24)
  ->  Seq Scan on customers c  (cost=0.00..2.62 rows=10 width=16)
        Filter: (country = 'USA'::text)
  ->  Index Scan using idx_orders_customer_id on orders o  (cost=0.28..1.37 rows=1 width=16)
        Index Cond: (customer_id = c.id)
```

#### 3.2 Hash Join
```sql
-- Better for larger tables when joining on equality conditions
SELECT c.name, o.id, li.product_name
FROM customers c 
JOIN orders o ON c.id = o.customer_id
JOIN line_items li ON o.id = li.order_id;
```

Example plan:
```
Hash Join  (cost=33.90..125.60 rows=2564 width=37)
  Hash Cond: (orders.customer_id = customers.id)
  ->  Hash Join  (cost=30.77..115.17 rows=2564 width=26)
        Hash Cond: (line_items.order_id = orders.id)
        ->  Seq Scan on line_items
        ->  Hash
            ->  Seq Scan on orders
  ->  Hash
      ->  Seq Scan on customers
```

### 4. Advanced Operations

```mermaid
flowchart TD
    A[Advanced Features] --> B[Window Functions]
    A --> C[CTEs]
    A --> D[Lateral Joins]
    
    B --> B1[ROW_NUMBER]
    B --> B2[Running Totals]
    C --> C1[Recursive]
    C --> C2[Non-Recursive]
    D --> D1[Top-N per Group]
```

#### 4.1 Window Functions
From `advanced_queries.rb`:
```sql
SELECT 
  orders.*, 
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at) as order_sequence
FROM orders;
```

Key components in plan:
- WindowAgg node
- Sorting operations for PARTITION BY and ORDER BY
- Memory usage for window frame

#### 4.2 Recursive CTEs
From `advanced_queries.rb`:
```sql
WITH RECURSIVE order_chain AS (
  -- Base case
  SELECT o.id, o.customer_id, o.created_at, 1 as chain_length
  FROM orders o
  JOIN customers c ON c.id = o.customer_id
  WHERE c.country = 'USA'
  
  UNION ALL
  
  -- Recursive case
  SELECT o.id, o.customer_id, o.created_at, oc.chain_length + 1
  FROM orders o
  JOIN order_chain oc ON o.customer_id = oc.customer_id
  WHERE o.created_at BETWEEN oc.created_at AND oc.created_at + INTERVAL '7 days'
    AND o.id > oc.id
)
SELECT customer_id, MAX(chain_length) as longest_chain
FROM order_chain
GROUP BY customer_id
HAVING MAX(chain_length) > 1;
```

### 5. Performance Optimization Tips

```mermaid
flowchart TD
    A[Optimization Areas] --> B[Indexes]
    A --> C[Query Structure]
    A --> D[Data Access]
    
    B --> B1[B-tree]
    B --> B2[Hash]
    B --> B3[GiST]
    
    C --> C1[Join Order]
    C --> C2[Predicate Push-down]
    
    D --> D1[Buffer Cache]
    D --> D2[Sequential vs Random]
```

#### 5.1 Index Usage
From `query_optimization_lab.rb`:
```ruby
def create_indexes
  connection = ActiveRecord::Base.connection
  
  # Add indexes if they don't exist
  unless index_exists?(:customers, :country)
    connection.add_index :customers, :country
  end

  unless index_exists?(:orders, :customer_id)
    connection.add_index :orders, :customer_id
  end
end
```

#### 5.2 Join Optimization
From `query_optimization_lab.rb`:
```ruby
def exercise_2_join_optimization
  # Query 1: Simple JOIN
  query1 = Order.joins(:customer)
    .where(customers: { country: 'USA' })
  
  # Query 2: Multiple JOINs with optimization
  query2 = Order.joins(:customer, :line_items)
    .where(customers: { country: 'USA' })
    .group('orders.id')
    .select('orders.*, COUNT(line_items.id) as items_count')
end
```

## Running the Examples

1. Setup Database:
```bash
bundle install
rake db:setup
```

2. Run Basic Examples:
```bash
ruby examples/03_queries/practice_queries.rb
```

3. Run Optimization Lab:
```bash
ruby examples/03_queries/query_optimization_lab.rb
```

4. Run Advanced Queries:
```bash
ruby examples/03_queries/advanced_queries.rb
```

## Additional Resources

1. [PostgreSQL Official Documentation - Using EXPLAIN](https://www.postgresql.org/docs/current/using-explain.html)
2. [PostgreSQL Official Documentation - Performance Tips](https://www.postgresql.org/docs/current/performance-tips.html)
3. [Understanding EXPLAIN ANALYZE Output](https://www.postgresql.org/docs/current/using-explain.html#USING-EXPLAIN-ANALYZE)
4. [Index Types](https://www.postgresql.org/docs/current/indexes-types.html) 