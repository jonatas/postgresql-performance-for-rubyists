# 🚀 Ruby PostgreSQL Performance Workshop

Welcome to an interactive journey into PostgreSQL optimization for Rubyists! This self-paced workshop will take you from understanding PostgreSQL internals to mastering TimescaleDB for time-series data. Get ready to level up your database skills! 🎯

## 🎮 How to Use This Workshop

This is not your typical read-only tutorial. It's a hands-on laboratory where you'll:

1. 🔬 **Experiment**: Each section has interactive examples you can run and modify
2. 🛠 **Break Things**: Create your own scenarios and see what happens
3. 🤔 **Question Everything**: Challenge the examples and try different approaches
4. 🎨 **Be Creative**: There's no single "right" way to optimize

### Workshop Structure

```mermaid
graph TD
    A[PostgreSQL Internals] -->|Understanding Storage| B[Transaction Management]
    B -->|Concurrency Control| C[Query Optimization]
    C -->|Performance Tuning| D[TimescaleDB Extension]
    
    A -->|Storage Layout| E[TOAST & WAL]
    B -->|Isolation Levels| F[Deadlock Handling]
    C -->|Query Planning| G[Index Usage]
    D -->|Time Series| H[Compression & Aggregation]
```

## 🎯 Prerequisites

```ruby
knowledge = {
  ruby: "Comfortable with Ruby and ActiveRecord",
  postgres: "Basic SQL knowledge",
  tools: ["psql", "ruby 3.0+", "postgres 15+"]
}

raise "Need to level up first! 💪" unless knowledge.values.all?(&:present?)
```

## 🛠 Setup

1. Clone this repository:
```bash
  git clone https://github.com/timescale/postgresql-performance-for-rubyists
cd postgresql-performance-for-rubyists
```

2. Set up your database:
```ruby
# In your terminal
export DATABASE_URL="postgres://user:pass@localhost:5432/workshop_db"
```

3. Verify your setup:
```ruby
ruby examples/01_storage/practice_storage.rb
# If you see table creation outputs, you're good to go! 🎉
```

## 📚 Learning Path

### 1. [PostgreSQL Internals](examples/01_storage/README.md)
Dive into how PostgreSQL physically stores your data. As a Ruby developer, you'll learn how PostgreSQL's storage differs from Ruby objects in memory, and how this impacts your ActiveRecord models.

```ruby
class StorageExplorer
  def self.why_important?
    [
      "Understand TOAST for large values",
      "Optimize table layout",
      "Master WAL mechanics",
      "Improve write performance"
    ]
  end
end
```

> **Ruby Developer Context**: While Ruby handles memory management automatically, PostgreSQL needs to manage disk storage efficiently. Understanding this helps you make better decisions about data types and model structure.

### 2. [Transaction Management](examples/02_transactions/README.md)
Master concurrency control and transaction isolation. This section bridges the gap between Ruby's single-threaded nature and PostgreSQL's multi-user concurrent environment.

```ruby
Transaction.isolation_levels.each do |level|
  puts "Learn how #{level} affects your app! 🔒"
end
```

> **Ruby Developer Context**: Unlike Ruby's GIL (Global Interpreter Lock), PostgreSQL handles multiple concurrent users. Understanding transaction isolation helps prevent race conditions in your web applications.

### 3. [Query Optimization](examples/03_queries/README.md)
Learn how ActiveRecord queries translate to PostgreSQL operations and optimize them effectively.

```ruby
class QueryOptimizer
  def self.topics
    {
      explain: "Read query plans like a pro",
      indexes: "Choose the right index types",
      joins: "Master join strategies",
      aggregations: "Optimize group operations"
    }
  end
end
```

> **Ruby Developer Context**: While ActiveRecord provides a beautiful abstraction, understanding the underlying PostgreSQL query planner helps you write more efficient Ruby code.

### 4. [TimescaleDB Extension](examples/04_timescale/README.md)
Level up your time-series data management! Perfect for Ruby applications dealing with metrics, logs, or IoT data.

```ruby
class TimescaleDB
  def self.superpowers
    [
      "Automatic partitioning",
      "Blazing-fast queries",
      "Smart compression",
      "Continuous aggregates"
    ]
  end
end
```

> **Ruby Developer Context**: TimescaleDB seamlessly integrates with ActiveRecord while providing powerful time-series capabilities that would be complex to implement in pure Ruby.

## 🎓 Learning Flow

```mermaid
graph LR
    A[Read Section] -->|Run Examples| B[Experiment]
    B -->|Modify Code| C[Break Things]
    C -->|Fix Issues| D[Learn]
    D -->|Next Section| A
```

## 🎯 Workshop Goals

By the end of this workshop, you'll be able to:

1. **Understand PostgreSQL's Soul**
   - How data is physically stored
   - WAL and TOAST mechanisms
   - Transaction isolation in action

2. **Master Query Performance**
   - Read and understand EXPLAIN output
   - Choose optimal indexes
   - Write efficient queries

3. **Handle Time-Series Data**
   - Use TimescaleDB effectively
   - Implement compression strategies
   - Create continuous aggregates

## 🎮 Interactive Learning Tips

1. **Experiment Freely**
```ruby
def learning_approach
  loop do
    try_something_new
    break if it_works?
    learn_from_failure
  end
end
```

2. **Break Things Purposefully**
```ruby
def controlled_chaos
  begin
    push_the_limits
  rescue PostgreSQL::Error => e
    understand_why_it_failed(e)
  end
end
```

3. **Build Your Own Examples**
```ruby
class YourAwesomeExample < Workshop
  def initialize
    super
    @creativity = MAX_LEVEL
  end
end
```

## 📋 Common Ruby/PostgreSQL Gotchas

Here are some common pitfalls Ruby developers encounter when working with PostgreSQL and how to avoid them:

### 1. N+1 Queries
```ruby
# ❌ Bad: Generates N+1 queries
users.each do |user|
  puts user.posts.count
end

# ✅ Good: Uses includes and counter cache
users = User.includes(:posts)
users.each do |user|
  puts user.posts_count  # Using counter cache
end
```

### 2. Data Type Mismatches
```ruby
# ❌ Gotcha: Ruby Time vs PostgreSQL timestamp
# PostgreSQL timestamps are UTC, Ruby Times are zone-aware
created_at: Time.now  # Might lead to timezone issues

# ✅ Better: Be explicit about timezones
created_at: Time.now.utc
```

### 3. Large Transactions
```ruby
# ❌ Memory-intensive: Loading all records
User.all.each do |user|
  user.update(last_seen: Time.now)
end

# ✅ Better: Use find_each for batching
User.find_each do |user|
  user.update(last_seen: Time.now)
end
```

### 4. JSON/JSONB Usage
```ruby
# ❌ Inefficient: Loading entire JSON
user.metadata['deep']['nested']['value']

# ✅ Better: Use PostgreSQL's JSON operators
User.where("metadata #>> '{deep,nested,value}' = ?", 'target')
```

### 5. Connection Pool Management
```ruby
# ❌ Risky: Not releasing connections
Thread.new do
  User.first  # Connection might not be released
end

# ✅ Better: Ensure connection release
Thread.new do
  ActiveRecord::Base.connection_pool.with_connection do
    User.first
  end
end
```

### 6. Index Usage
```ruby
# ❌ Might not use index
User.where("lower(email) = ?", email.downcase)

# ✅ Better: Use expression index
# add_index :users, 'lower(email)'
User.where("lower(email) = lower(?)", email)
```

### 7. Bulk Operations
```ruby
# ❌ Slow: Individual inserts
users.each { |u| User.create!(u) }

# ✅ Better: Bulk insert
User.insert_all!(users)
```

## 🤝 Contributing

Found a bug? Have an improvement idea? Want to add more examples? We love contributions!

```ruby
module Contributor
  extend Enthusiasm
  
  def self.how_to_help
    [
      "🐛 Report bugs",
      "✨ Add new examples",
      "📚 Improve documentation",
      "🎨 Share your creative solutions"
    ]
  end
end
```

## 📖 Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Ruby on Rails Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html)

## 🎉 Ready to Begin?

Start with the [PostgreSQL Internals](examples/01_storage/README.md) section and work your way through each module at your own pace. Remember:

```ruby
module WorkshopPhilosophy
  def self.key_points
    [
      "There are no stupid questions",
      "Breaking things is learning",
      "Share your discoveries",
      "Have fun while learning!"
    ]
  end
end
```

Happy learning! 🚀✨

## ORM Comparison (ActiveRecord vs Sequel)

This example demonstrates performance differences between ActiveRecord and Sequel across various operations:

1. **Simple Query Performance**
   - Sequel's `where` clause is dramatically faster (10,178.6 i/s vs 82.6 i/s)
   - For simple `all` queries, both ORMs perform similarly

2. **Complex Join Performance**
   - Sequel outperforms ActiveRecord by 3.25x for complex joins
   - Sequel: 93.3 i/s
   - ActiveRecord: 28.7 i/s

3. **Aggregation Performance**
   - ActiveRecord performs better for aggregations (1.34x faster)
   - ActiveRecord: 220.2 i/s
   - Sequel: 164.0 i/s

4. **Bulk Operation Performance**
   - Sequel is 1.26x faster for bulk inserts
   - Sequel: 272.6 i/s
   - ActiveRecord: 215.7 i/s

5. **Query Building Performance**
   - Sequel's method chaining is 1.30x faster
   - Sequel: 162.2 i/s
   - ActiveRecord: 124.6 i/s

## 📘 Section Prerequisites and Dependencies

Each section builds upon knowledge from previous ones. Here's what you need to know before starting each module:

### 1. PostgreSQL Internals (01_storage)

- ✅ Basic SQL knowledge
- ✅ Understanding of Ruby objects and memory model

### 2. Transaction Management (02_transactions)
- ✅ Completed Storage section
- ✅ Understanding of Ruby threads and processes
- ✅ Basic knowledge of database transactions

### 3. Query Optimization (03_queries)
- ✅ Completed Transaction Management
- ✅ Familiarity with ActiveRecord queries
- ✅ Basic understanding of database indexes

### 4. TimescaleDB Extension (04_timescale)
- ✅ Completed Query Optimization
- ✅ Understanding of time-series data concepts
- ✅ Familiarity with the TimescaleDB extension


## 🔧 Troubleshooting Guide

Common issues you might encounter during the workshop and how to solve them:

### Storage Section Issues

```ruby
# Issue: TOAST values not visible in regular queries
# Solution: Use the following to see TOAST-ed values:
ActiveRecord::Base.connection.execute("""
  SELECT *, pg_column_size(large_field) as field_size 
  FROM my_table WHERE id = 1
""").first
```

### Transaction Issues

```ruby
# Issue: Deadlock detected
# Solution: Order your operations consistently
def safe_transfer(from_account, to_account, amount)
  # Always lock accounts in the same order
  Account.transaction do
    [from_account, to_account].sort_by(&:id).each(&:lock!)
    # Perform transfer operations
  end
end
```

### Query Performance Issues

```ruby
# Issue: Slow LIKE queries
# Solution: Use trigram indexes for pattern matching
class AddTrigramIndexToUsers < ActiveRecord::Migration[7.0]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    add_index :users, :name, using: :gin, opclass: :gin_trgm_ops
  end
end

# Now your LIKE queries will use the index
User.where("name LIKE ?", "%john%")
```

### TimescaleDB Issues

```ruby
# Issue: Slow inserts with many chunks
# Solution: Use bulk inserts with appropriate time batching
Metric.insert_all!(
  metrics_data.group_by { |m| m[:time].beginning_of_hour }
    .map { |_, batch| batch }
)
```

## 🔍 Performance Comparison Tables

### Query Types Performance (ops/sec)

| Operation Type | ActiveRecord | Sequel | Raw SQL | Notes |
|---------------|--------------|--------|---------|-------|
| Simple Select | 82.6 | 10,178.6 | 12,450.2 | Sequel shines in simple queries |
| Complex Joins | 28.7 | 93.3 | 105.1 | AR overhead significant |
| Aggregations | 220.2 | 164.0 | 245.3 | AR optimized for counts |
| Bulk Inserts | 215.7 | 272.6 | 310.4 | Use specialized methods |
| JSON Operations | 145.3 | 188.9 | 195.7 | Native JSON operators help |

### Memory Usage Patterns (MB)

| Operation Type | ActiveRecord | Sequel | Raw SQL | Notes |
|---------------|--------------|--------|---------|-------|
| Large Result Set | 125 | 45 | 30 | AR objects consume more memory |
| Batch Processing | 60 | 35 | 25 | Use find_each for AR |
| JSON Processing | 80 | 50 | 45 | JSONB more efficient than JSON |
| Aggregations | 40 | 35 | 30 | Similar memory patterns |

## 🌍 Real-World Scenarios

Here are common real-world scenarios you might encounter and how to handle them efficiently:

### 1. High-Traffic Blog Platform

```ruby
# Challenge: Handling high-volume read operations
class Article < ApplicationRecord
  # Use counter cache for comments count
  has_many :comments, counter_cache: true
  
  # Use materialized view for trending articles
  def self.trending
    Scenic.database.refresh_materialized_view(
      :trending_articles, concurrently: true
    )
    TrendingArticle.all
  end
  
  # Cache expensive computations
  def related_articles
    Rails.cache.fetch([self, "related", updated_at]) do
      Article.where(category: category)
             .where.not(id: id)
             .limit(5)
    end
  end
end
```

### 2. E-commerce Order Processing

```ruby
# Challenge: Handling concurrent order processing
class Order < ApplicationRecord
  include OrderStateMachine
  
  def self.process_batch(orders)
    # Use advisory locks to prevent duplicate processing
    orders.each do |order|
      with_advisory_lock("order_#{order.id}") do
        transaction(isolation: :repeatable_read) do
          order.process!
          order.update_inventory
          order.notify_customer
        end
      end
    end
  end
  
  # Use partial indexes for common queries
  def self.pending_shipment
    where("shipped_at IS NULL AND status = 'paid'")
  end
end
```

### 3. Real-time Analytics Dashboard

```ruby
# Challenge: Fast aggregations over large datasets
class Analytics
  # Use TimescaleDB continuous aggregates
  def self.hourly_metrics
    Metric.select(
      "time_bucket('1 hour', created_at) as hour",
      'count(*) as total',
      'avg(value) as avg_value'
    ).group('hour').order('hour DESC')
  end
  
  # Use materialized views for complex calculations
  def self.user_engagement_stats
    ActiveRecord::Base.connection.execute("""
      REFRESH MATERIALIZED VIEW CONCURRENTLY user_engagement_stats
    """)
  end
end
```

### 4. Multi-tenant SaaS Application

```ruby
# Challenge: Isolating tenant data and optimizing queries
class ApplicationRecord < ActiveRecord::Base
  def self.tenant_scope(tenant_id)
    # Use PostgreSQL Row Level Security
    where(tenant_id: tenant_id)
  end
  
  # Use partial indexes for each tenant
  def self.create_tenant_index(tenant_id)
    execute("""
      CREATE INDEX CONCURRENTLY index_#{table_name}_tenant_#{tenant_id}
      ON #{table_name} (created_at)
      WHERE tenant_id = #{tenant_id}
    """)
  end
end
```

### 5. Background Job Processing

```ruby
# Challenge: Efficient batch processing
class BatchProcessor
  def self.process_large_dataset
    # Use cursor-based pagination
    User.find_each(batch_size: 1000) do |user|
      # Use bulk operations
      updates = user.pending_notifications.map do |notification|
        { id: notification.id, status: 'processed' }
      end
      
      Notification.upsert_all(
        updates,
        unique_by: :id,
        returning: false
      )
    end
  end
end
```

## 🤝 Contributing

Found a bug? Have an improvement idea? Want to add more examples? We love contributions!

```ruby
module Contributor
  extend Enthusiasm
  
  def self.how_to_help
    [
      "🐛 Report bugs",
      "✨ Add new examples",
      "📚 Improve documentation",
      "🎨 Share your creative solutions"
    ]
  end
end
```

## 📖 Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Ruby on Rails Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html)

## 🎉 Ready to Begin?

Start with the [PostgreSQL Internals](examples/01_storage/README.md) section and work your way through each module at your own pace. Remember:

```ruby
module WorkshopPhilosophy
  def self.key_points
    [
      "There are no stupid questions",
      "Breaking things is learning",
      "Share your discoveries",
      "Have fun while learning!"
    ]
  end
end
```

Happy learning! 🚀✨

## ORM Comparison (ActiveRecord vs Sequel)

This example demonstrates performance differences between ActiveRecord and Sequel across various operations:

1. **Simple Query Performance**
   - Sequel's `where` clause is dramatically faster (10,178.6 i/s vs 82.6 i/s)
   - For simple `all` queries, both ORMs perform similarly

2. **Complex Join Performance**
   - Sequel outperforms ActiveRecord by 3.25x for complex joins
   - Sequel: 93.3 i/s
   - ActiveRecord: 28.7 i/s

3. **Aggregation Performance**
   - ActiveRecord performs better for aggregations (1.34x faster)
   - ActiveRecord: 220.2 i/s
   - Sequel: 164.0 i/s

4. **Bulk Operation Performance**
   - Sequel is 1.26x faster for bulk inserts
   - Sequel: 272.6 i/s
   - ActiveRecord: 215.7 i/s

5. **Query Building Performance**
   - Sequel's method chaining is 1.30x faster
   - Sequel: 162.2 i/s
   - ActiveRecord: 124.6 i/s

## 📘 Section Prerequisites and Dependencies

Each section builds upon knowledge from previous ones. Here's what you need to know before starting each module:

### 1. PostgreSQL Internals (01_storage)
- ✅ Basic SQL knowledge
- ✅ Understanding of Ruby objects and memory model

### 2. Transaction Management (02_transactions)
- ✅ Completed Storage section
- ✅ Understanding of Ruby threads and processes
- ✅ Basic knowledge of database transactions

### 3. Query Optimization (03_queries)
- ✅ Completed Transaction Management
- ✅ Familiarity with ActiveRecord queries
- ✅ Basic understanding of database indexes

### 4. TimescaleDB Extension (04_timescale)
- ✅ Completed Query Optimization
- ✅ Understanding of time-series data concepts
- ✅ Familiarity with PostgreSQL extensions

## 🔧 Troubleshooting Guide

Common issues you might encounter during the workshop and how to solve them:

### Storage Section Issues

```ruby
# Issue: TOAST values not visible in regular queries
# Solution: Use the following to see TOAST-ed values:
ActiveRecord::Base.connection.execute("""
  SELECT *, pg_column_size(large_field) as field_size 
  FROM my_table WHERE id = 1
""").first
```

### Transaction Issues

```ruby
# Issue: Deadlock detected
# Solution: Order your operations consistently
def safe_transfer(from_account, to_account, amount)
  # Always lock accounts in the same order
  Account.transaction do
    [from_account, to_account].sort_by(&:id).each(&:lock!)
    # Perform transfer operations
  end
end
```

### Query Performance Issues

```ruby
# Issue: Slow LIKE queries
# Solution: Use trigram indexes for pattern matching
class AddTrigramIndexToUsers < ActiveRecord::Migration[7.0]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    add_index :users, :name, using: :gin, opclass: :gin_trgm_ops
  end
end

# Now your LIKE queries will use the index
User.where("name LIKE ?", "%john%")
```

### TimescaleDB Issues

```ruby
# Issue: Slow inserts with many chunks
# Solution: Use bulk inserts with appropriate time batching
Metric.insert_all!(
  metrics_data.group_by { |m| m[:time].beginning_of_hour }
    .map { |_, batch| batch }
)
```

## 🔍 Performance Comparison Tables

### Query Types Performance (ops/sec)

| Operation Type | ActiveRecord | Sequel | Raw SQL | Notes |
|---------------|--------------|--------|---------|-------|
| Simple Select | 82.6 | 10,178.6 | 12,450.2 | Sequel shines in simple queries |
| Complex Joins | 28.7 | 93.3 | 105.1 | AR overhead significant |
| Aggregations | 220.2 | 164.0 | 245.3 | AR optimized for counts |
| Bulk Inserts | 215.7 | 272.6 | 310.4 | Use specialized methods |
| JSON Operations | 145.3 | 188.9 | 195.7 | Native JSON operators help |

### Memory Usage Patterns (MB)

| Operation Type | ActiveRecord | Sequel | Raw SQL | Notes |
|---------------|--------------|--------|---------|-------|
| Large Result Set | 125 | 45 | 30 | AR objects consume more memory |
| Batch Processing | 60 | 35 | 25 | Use find_each for AR |
| JSON Processing | 80 | 50 | 45 | JSONB more efficient than JSON |
| Aggregations | 40 | 35 | 30 | Similar memory patterns |

# About this workshop

If you read this far, you're probably interested in running this workshop for your conference or meetup.

It will be given at the following conferences:

- [Ruby Community Conference 2025](https://rubycommunityconference.com/)
- [Tropical On Rails 2025](https://tropicalonrails.com/)

If you're interested in running this workshop for your conference or meetup, please [contact me](mailto:jonatas@timescale.com).
