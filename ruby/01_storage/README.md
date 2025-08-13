# PostgreSQL Storage Deep Dive - Ruby Edition

This module provides a practical exploration of PostgreSQL's storage mechanisms using Ruby and ActiveRecord. For the language-agnostic version, see [Shared Storage Documentation](../../01_storage_README.md).

![img/01_storage.webp](../../img/01_storage.webp "A kawaii felt craft scene featuring a chubby felt elephant, representing the PostgreSQL mascot, wearing tiny librarian glasses. The scene is set in a cozy library with bookshelves and a cozy armchair.")

## Prerequisites

Before starting this module, ensure you understand:
- [ACID Properties](../../GLOSSARY.md#acid)
- [WAL (Write-Ahead Log)](../../GLOSSARY.md#wal)
- [TOAST](../../GLOSSARY.md#toast)
- Ruby and ActiveRecord basics

## Ruby-Specific Setup

### **Installation**
```bash
# Install dependencies
bundle install

# Set up database connection
export DATABASE_URL="postgres://username:password@localhost:5432/workshop_db"
```

### **Running Examples**
```bash
# Basic storage analysis
bundle exec ruby ruby/01_storage/practice_storage.rb

# Tuple analysis
bundle exec ruby ruby/01_storage/practice_tuple.rb

# WAL analysis
bundle exec ruby ruby/01_storage/practice_wal.rb
```

## Ruby-Specific Features

### **ActiveRecord Integration**
```ruby
class Document < ActiveRecord::Base
  def self.table_stats
    connection.execute(<<~SQL).first
      SELECT 
        n_live_tup as live_tuples,
        n_dead_tup as dead_tuples,
        n_tup_ins as inserts,
        n_tup_upd as updates,
        n_tup_del as deletes
      FROM pg_stat_user_tables
      WHERE relname = 'documents'
    SQL
  end

  def self.storage_sizes
    {
      total_size: connection.execute("SELECT pg_size_pretty(pg_total_relation_size('documents'))").first['pg_size_pretty'],
      table_size: connection.execute("SELECT pg_size_pretty(pg_relation_size('documents'))").first['pg_size_pretty'],
      index_size: connection.execute("SELECT pg_size_pretty(pg_indexes_size('documents'))").first['pg_size_pretty']
    }
  end
end
```

### **Ruby-Specific Analysis**
```ruby
# Analyze tuple size with Ruby
def analyze_tuple_size
  header_size = 23  # Standard tuple header size
  null_bitmap_size = (attributes.size + 7) / 8  # Round up to nearest byte
  
  total_theoretical_size = header_size + null_bitmap_size
  
  attributes.each do |name, value|
    size = case value
    when String
      value.bytesize
    when Integer
      4
    when TrueClass, FalseClass
      1
    # ... more type handling
    end
    
    total_theoretical_size += size
  end
  
  total_theoretical_size
end
```

## Learning Path

1. **Basic Storage Concepts** (practice_storage.rb)
   - Understanding 8KB pages
   - Basic tuple structure
   - Data type storage requirements
   - Simple storage examples

2. **Tuple Deep Dive** (practice_tuple.rb)
   - Detailed tuple analysis
   - NULL handling
   - Alignment requirements
   - Real-world tuple patterns

3. **TOAST Storage** (practice_storage.rb, practice_tuple.rb)
   - Large value handling
   - TOAST thresholds
   - Storage strategies
   - Compression options

4. **WAL and Performance** (practice_wal.rb)
   - Write-Ahead Log basics
   - Transaction impacts
   - Checkpoint behavior
   - Performance optimization

## Related Concepts

- [Query Planning](../03_queries/README.md#query-planning)
- [Transaction Management](../02_transactions/README.md#transaction-management)
- [Buffer Management](../../GLOSSARY.md#buffer-management)

## Database Structure

```mermaid
erDiagram
    employees {
        bigint id PK
        varchar name
        integer employee_id
        boolean active
        date hire_date
        decimal salary
        jsonb details
        binary photo
        timestamp created_at
        timestamp updated_at
    }
```

## Module Overview

In this module, you'll explore:
1. How PostgreSQL organizes data in tuples (rows)
2. How different data types affect storage and alignment
3. How PostgreSQL handles large values using TOAST
4. The relationship between theoretical and actual storage sizes

## Ruby vs SQL Comparison

### **Storage Analysis**
```ruby
# Ruby approach
Document.storage_sizes
# => { total_size: "64 kB", table_size: "8192 bytes", index_size: "16 kB" }
```

```sql
-- SQL approach
SELECT 
    pg_size_pretty(pg_total_relation_size('documents')) as total_size,
    pg_size_pretty(pg_relation_size('documents')) as table_size,
    pg_size_pretty(pg_indexes_size('documents')) as index_size;
```

### **Tuple Analysis**
```ruby
# Ruby approach
employee.analyze_tuple_size
# => Calculates theoretical vs actual tuple size
```

```sql
-- SQL approach
SELECT 
    pg_column_size(name) + pg_column_size(employee_id) + 
    pg_column_size(active) + pg_column_size(hire_date) as actual_size
FROM employees;
```

## Next Steps

After completing this module:
1. Move to [Transaction Management](../02_transactions/README.md) to understand concurrency
2. Explore [Query Optimization](../03_queries/README.md) for performance tuning
3. Learn about [TimescaleDB](../04_timescale/README.md) for time-series data
4. Review the [language-agnostic version](../../01_storage_README.md) for SQL examples

## Troubleshooting

If you encounter issues:
- Check your Ruby version: `ruby --version`
- Verify ActiveRecord connection: `rails console` or `bundle exec ruby -e "require 'active_record'"`
- Check database connection: `bundle exec ruby -e "puts ActiveRecord::Base.connection.execute('SELECT version()').first"`
- Review the [Troubleshooting Guide](../../TROUBLESHOOTING.md)