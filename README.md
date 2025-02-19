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
Dive into how PostgreSQL physically stores your data.

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

### 2. [Transaction Management](examples/02_transactions/README.md)
Master concurrency control and transaction isolation.

```ruby
Transaction.isolation_levels.each do |level|
  puts "Learn how #{level} affects your app! 🔒"
end
```

### 3. [Query Optimization](examples/03_queries/README.md)
Turn slow queries into speed demons! 🏎️

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

### 4. [TimescaleDB Extension](examples/04_timescale/README.md)
Level up your time-series data management!

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