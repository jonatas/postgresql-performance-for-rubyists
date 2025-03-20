require_relative 'setup'

# Setup fresh database and generate larger dataset
setup_database

# Define test parameters as variables
TOTAL_USERS = 1000
POSTS_PER_USER = 10
COMMENTS_PER_POST = 5
TOTAL_POSTS = TOTAL_USERS * POSTS_PER_USER
TOTAL_COMMENTS = TOTAL_POSTS * COMMENTS_PER_POST
QUERY_LIMIT = 100
MIN_POST_COUNT = 5
LIKE_PATTERN = "%test%"
DATE_RANGE = 1.day.ago..Time.current

generate_sample_data(users: TOTAL_USERS, posts_per_user: POSTS_PER_USER, comments_per_post: COMMENTS_PER_POST)

puts "\n=== ORM Comparison Examples (Significant Differences >10%) ==="
puts "Dataset: #{TOTAL_USERS} users, #{TOTAL_POSTS} posts, #{TOTAL_COMMENTS} comments"

# Example 1: Simple Queries - Significant difference observed
puts "\n1. Simple Query Performance (#{TOTAL_USERS} users, limit: #{QUERY_LIMIT})"
puts "Query: WHERE created_at < current_time LIMIT #{QUERY_LIMIT}"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("ActiveRecord - simple query") do
    User.where("created_at < ?", Time.current).limit(QUERY_LIMIT).to_a
  end

  x.report("Sequel - simple query") do
    DB[:users].where(Sequel.lit("created_at < ?", Time.current)).limit(QUERY_LIMIT).all
  end

  x.compare!
end

# Example 2: Aggregations - Shows >10% difference
puts "\n2. Aggregation Performance (#{TOTAL_POSTS} posts)"
puts "Query: GROUP BY user_id HAVING COUNT(*) > #{MIN_POST_COUNT}"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("ActiveRecord - aggregation with HAVING") do
    Post.group(:user_id)
        .select('user_id, COUNT(*) as posts_count, AVG(LENGTH(content)) as avg_content_length')
        .having("COUNT(*) > #{MIN_POST_COUNT}")
        .to_a
  end

  x.report("Sequel - aggregation with HAVING") do
    DB[:posts]
      .select(:user_id)
      .select_append { [
        count(id).as(:posts_count),
        avg(length(content)).as(:avg_content_length)
      ] }
      .group(:user_id)
      .having { count(id) > MIN_POST_COUNT }
      .all
  end

  x.compare!
end

# Example 3: Query Building - Shows significant difference
puts "\n3. Query Building Approaches (#{TOTAL_USERS} users, limit: #{QUERY_LIMIT})"
puts "Query: Complex conditions with LIKE pattern '#{LIKE_PATTERN}', date range, order by created_at desc"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  conditions = { created_at: DATE_RANGE }

  x.report("ActiveRecord - method chain") do
    User.where(conditions)
        .where("name LIKE ?", LIKE_PATTERN)
        .order(created_at: :desc)
        .limit(QUERY_LIMIT)
        .to_a
  end

  x.report("Sequel - method chain") do
    DB[:users]
      .where(conditions)
      .where(Sequel.like(:name, LIKE_PATTERN))
      .order(Sequel.desc(:created_at))
      .limit(QUERY_LIMIT)
      .all
  end

  x.compare!
end