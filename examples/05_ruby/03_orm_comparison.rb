require_relative 'setup'

# Setup fresh database and generate larger dataset
setup_database
generate_sample_data(users: 1000, posts_per_user: 10, comments_per_post: 5)

puts "\n=== ORM Comparison Examples ==="

# Example 1: Simple Queries
puts "\n1. Simple Query Performance"
Benchmark.ips do |x|
  x.config(time: 2, warmup: 1)

  x.report("ActiveRecord - all") do
    User.all.to_a
  end

  x.report("Sequel - all") do
    DB[:users].all
  end

  x.report("ActiveRecord - where") do
    User.where(created_at: 1.day.ago..Time.current).to_a
  end

  x.report("Sequel - where") do
    DB[:users].where(created_at: 1.day.ago..Time.current).all
  end

  x.compare!
end

# Example 2: Complex Joins
puts "\n2. Complex Join Performance"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("ActiveRecord - complex join") do
    User.joins(posts: :comments)
        .select('users.id, users.name, COUNT(DISTINCT posts.id) as posts_count, COUNT(comments.id) as comments_count')
        .group('users.id, users.name')
        .to_a
  end

  x.report("Sequel - complex join") do
    DB[:users]
      .join(:posts, user_id: :id)
      .join(:comments, post_id: Sequel[:posts][:id])
      .select(
        Sequel[:users][:id],
        Sequel[:users][:name],
        Sequel.lit('COUNT(DISTINCT posts.id) as posts_count'),
        Sequel.function(:count, Sequel[:comments][:id]).as(:comments_count)
      )
      .group(Sequel[:users][:id], Sequel[:users][:name])
      .all
  end

  x.compare!
end

# Example 3: Aggregations
puts "\n3. Aggregation Performance"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("ActiveRecord - aggregation") do
    Post.group(:user_id)
        .select('user_id, COUNT(*) as posts_count, AVG(LENGTH(content)) as avg_content_length')
        .having('COUNT(*) > 5')
        .to_a
  end

  x.report("Sequel - aggregation") do
    DB[:posts]
      .select(:user_id)
      .select_append { [
        count(id).as(:posts_count),
        avg(length(content)).as(:avg_content_length)
      ] }
      .group(:user_id)
      .having { count(id) > 5 }
      .all
  end

  x.compare!
end

# Example 4: Bulk Operations
puts "\n4. Bulk Operation Performance"

# Instead of using the original approach which leads to duplicate key errors,
# let's modify the benchmark to test a slightly different bulk operation
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2) # Increased warmup and run time

  x.report("ActiveRecord - bulk update") do
    # Update all users who were created before now
    User.where("created_at < ?", Time.current)
        .limit(100)
        .update_all(updated_at: Time.current)
  end

  x.report("Sequel - bulk update") do
    # Sequel doesn't support updates with limit, so we'll use a different approach
    # First get the ids of 100 users
    ids = DB[:users]
      .where(Sequel.lit("created_at < ?", Time.current))
      .limit(100)
      .select(:id)
      .map(:id)
    
    # Then update those specific users
    DB[:users]
      .where(id: ids)
      .update(updated_at: Time.current)
  end

  x.compare!
end

# Example 5: Query Building
puts "\n5. Query Building Approaches"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2) # Increased warmup and run time

  conditions = { created_at: 1.day.ago..Time.current }
  pattern = "%test%" # Trailing wildcard is better for index usage

  x.report("ActiveRecord - method chain") do
    User.where(conditions)
        .where("name LIKE ?", pattern)
        .order(created_at: :desc)
        .limit(100)
        .to_a
  end

  x.report("Sequel - method chain") do
    DB[:users]
      .where(conditions)
      .where(Sequel.like(:name, pattern))
      .order(Sequel.desc(:created_at))
      .limit(100)
      .all
  end

  x.compare!
end

# Example 6: Index-Friendly Queries
puts "\n6. Index-Friendly Query Performance"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  # Leading wildcard prevents index usage
  leading_wildcard = "%Ruby%"
  
  # No leading wildcard allows index usage
  trailing_wildcard = "Ruby%"

  x.report("ActiveRecord - leading wildcard (no index)") do
    User.where("name LIKE ?", leading_wildcard).to_a
  end

  x.report("ActiveRecord - trailing wildcard (index)") do
    User.where("name LIKE ?", trailing_wildcard).to_a
  end

  x.report("Sequel - leading wildcard (no index)") do
    DB[:users].where(Sequel.like(:name, leading_wildcard)).all
  end

  x.report("Sequel - trailing wildcard (index)") do
    DB[:users].where(Sequel.like(:name, trailing_wildcard)).all
  end

  x.compare!
end