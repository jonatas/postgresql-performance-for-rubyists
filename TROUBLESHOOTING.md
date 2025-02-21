# 🔧 PostgreSQL Performance Workshop Troubleshooting Guide

This guide contains common issues, solutions, and performance comparisons you might encounter during the workshop. Use it as a reference when you run into problems or want to understand performance tradeoffs.

## Interactive Learning Tips

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

## Table of Contents
- [Storage Issues](#storage-issues)
- [Transaction Issues](#transaction-issues)
- [Query Performance Issues](#query-performance-issues)
- [TimescaleDB Issues](#timescaledb-issues)
- [ORM Performance Comparison](#orm-performance-comparison)
- [Memory Usage Patterns](#memory-usage-patterns)
- [Real-World Scenarios](#real-world-scenarios)

## Storage Issues

### TOAST Values Not Visible
```ruby
# Issue: TOAST values not visible in regular queries
# Solution: Use the following to see TOAST-ed values:
ActiveRecord::Base.connection.execute("""
  SELECT *, pg_column_size(large_field) as field_size 
  FROM my_table WHERE id = 1
""").first
```

### Large Value Storage
```ruby
# Issue: Inefficient storage of large text fields
# Solution: Use appropriate storage type and TOAST strategy
class CreateArticles < ActiveRecord::Migration[7.0]
  def change
    create_table :articles do |t|
      t.text :content, storage: :extended # Uses TOAST efficiently
    end
  end
end
```

## Transaction Issues

### Deadlock Detection
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

### Transaction Isolation
```ruby
# Issue: Inconsistent reads in concurrent transactions
# Solution: Use appropriate isolation level
Account.transaction(isolation: :repeatable_read) do
  # Your operations here
end
```

## Query Performance Issues

### Slow LIKE Queries
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

### N+1 Query Problems
```ruby
# Issue: N+1 queries in associations
# Solution: Use eager loading
# Bad
User.all.each { |user| puts user.posts.count }

# Good
User.includes(:posts).all.each { |user| puts user.posts.size }
```

## TimescaleDB Issues

### Chunk Creation Locks
```ruby
# Issue: Slow inserts with many chunks, returning all the data at once
Metric.insert_all(metrics_data) # bad 

# Solution: Use bulk inserts with appropriate time batching
metrics_data.group_by { |m| m[:time].beginning_of_hour }
  .each{ |_, batch| Metric.insert_all!( batch, returning: false )} # good
```

> The problem is that the insert is happening over multiple chunks, and two processes are competing to create new chunks. Grouping by hour makes sure no batches overlap with each other, reducing the time the transaction is locked.

### Continuous Aggregate Refresh
```ruby
# Issue: Slow continuous aggregate refresh
# Solution: Adjust refresh policy for better performance
continuous_aggregates scopes: [:avg_temperature],
  timeframes: [:hour],
  refresh_policy: {
    hour: {
      start_offset: '3 hours',
      end_offset: '1 hour',
      schedule_interval: '1 hour'
    }
  }
```



## Real-World Scenarios

### High-Traffic Blog Platform
```ruby
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

### E-commerce Order Processing
```ruby
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

## Performance Monitoring Tips

### Query Analysis
```ruby
# Enable query logging with execution time
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::DEBUG

# Use explain for query analysis
User.where(status: 'active').explain
```

### Connection Pool Monitoring
```ruby
# Check current pool status
ActiveRecord::Base.connection_pool.stat

# Adjust pool size based on load
ActiveRecord::Base.connection_pool.size = 25
```

Remember to check the specific module READMEs for more detailed troubleshooting information:
- [Storage Deep Dive](examples/01_storage/README.md)
- [Transaction Management](examples/02_transactions/README.md)
- [Query Optimization](examples/03_queries/README.md)
- [TimescaleDB Extension](examples/04_timescale/README.md)
- [Ruby Performance](examples/05_ruby/README.md)