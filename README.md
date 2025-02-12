# PostgreSQL Performance Workshop


This is a 3 hour workshop for ruby developers who want to understand how to optimize their queries and use TimescaleDB.

The workshop is split into 4 phases:

1. PostgreSQL Internals (55 minutes)
2. Transaction Management (55 minutes)
3. Query Optimization (55 minutes)
4. TimescaleDB Extension (55 minutes)

## 1: PostgreSQL Internals (55 minutes)
**Objective**: Understand PostgreSQL's physical storage and system catalogs

**Schedule**:
- Theoretical introduction to storage concepts (15 mins)
- Code walkthrough of storage analysis tools (15 mins)
- Hands-on storage exploration exercise (20 mins)
- Q&A and troubleshooting (5 mins)

### Setup File: `01_storage_explorer.rb`
```ruby
require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'activerecord'
  gem 'pry'
end

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

class StorageExplorer
  def self.analyze_table_storage(table_name)
    connection.execute(<<~SQL)
      SELECT pg_size_pretty(pg_total_relation_size('#{table_name}')),
             pg_size_pretty(pg_relation_size('#{table_name}')),
             pg_size_pretty(pg_indexes_size('#{table_name}'))
    SQL
  end

  def self.analyze_toast_storage(table_name)
    connection.execute(<<~SQL)
      SELECT pg_size_pretty(pg_total_relation_size(reltoastrelid))
      FROM pg_class
      WHERE relname = '#{table_name}'
      AND reltoastrelid != 0
    SQL
  end
end
```

### Exercise File: `01_practice_storage.rb`
```ruby
# Create tables with different characteristics
create_table :documents do |t|
  t.string :title
  t.text :content    # Regular text
  t.jsonb :metadata  # JSONB storage
  t.binary :attachment  # TOAST candidate
end

# Insert sample data with varying sizes
Document.create!(
  title: "Large Document",
  content: "A" * 10000,  # Force TOAST storage
  metadata: { tags: ["large", "test"] },
  attachment: File.read("sample.pdf")
)
```

## 2: Transaction Management (55 minutes)
**Objective**: Master transaction isolation levels and deadlock handling

### Setup File: `02_transaction_lab.rb`

```ruby
require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'activerecord'
  gem 'pry'
end

class TransactionLab
  def self.simulate_deadlock
    Thread.new do
      Account.transaction do
        account1.lock!
        sleep(1) # Force deadlock
        account2.update!(balance: 100)
      end
    end

    Account.transaction do
      account2.lock!
      account1.update!(balance: 200)
    end
  end
end
```

### Exercise File: `02_practice_transactions.rb`

```ruby
# Test different isolation levels
Account.transaction(isolation: :repeatable_read) do
  account = Account.find(1)
  initial_balance = account.balance
  
  # Concurrent modification in another session
  Account.find(1).update!(balance: 500)
  
  # Check if we see the change
  account.reload
  puts "Balance changed? #{account.balance != initial_balance}"
end
```

## 3: Query Optimization (55 minutes)
**Objective**: Master query planning and execution

**Schedule**:
- Theoretical introduction to query planning (15 mins)
- Code walkthrough of EXPLAIN and optimization techniques (15 mins)
- Hands-on query optimization exercise (20 mins)
- Q&A and troubleshooting (5 mins)

### Setup File: `03_query_explorer.rb`
```ruby
class QueryExplorer
  def self.analyze_query(sql)
    connection.execute(<<~SQL)
      EXPLAIN (ANALYZE, BUFFERS)
      #{sql}
    SQL
  end
end

class Order < ApplicationRecord
  belongs_to :customer
  has_many :line_items
end
```

### Exercise File: `03_practice_queries.rb`
```ruby
# Complex query for optimization
orders = Order.joins(:line_items, :customer)
  .where(created_at: 1.month.ago..Time.current)
  .group('customers.country')
  .select('customers.country,
          COUNT(DISTINCT orders.id) as order_count,
          SUM(line_items.quantity * line_items.price) as revenue')

puts QueryExplorer.analyze_query(orders.to_sql)
```

## 4: TimescaleDB Integration (55 minutes)
**Objective**: Implement time-series data management with TimescaleDB

**Schedule**:
- Theoretical introduction to TimescaleDB concepts (15 mins)
- Code walkthrough of TimescaleDB features (15 mins)
- Hands-on TimescaleDB implementation exercise (20 mins)
- Q&A and troubleshooting (5 mins)

### Setup File: `04_timescale_setup.rb`
```