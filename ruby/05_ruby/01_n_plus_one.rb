require_relative 'setup'

# Set up fresh database and generate sample data
setup_database
generate_sample_data(users: 1000, posts_per_user: 10, comments_per_post: 5)

puts "\n=== N+1 Query Examples ===\n"

def measure_and_report(title)
  puts "\n#{title}:"
  queries_count = 0
  time = Benchmark.realtime do
    ActiveSupport::Notifications.subscribed(-> (*) { queries_count += 1 }, "sql.active_record") do
      yield
    end
  end
  puts "Time taken: #{time.round(2)} seconds"
  puts "Queries executed: #{queries_count}"
end

# 1. Basic N+1 Problem
puts "\n1. Basic N+1 Problem\n"

puts "\nBad approach (N+1 queries):"
measure_and_report("Bad approach (N+1 queries)") do
  User.limit(50).each do |user|
    puts "User #{user.name} has #{user.posts.count} posts"
  end
end

puts "\nGood approach (with includes):"
measure_and_report("Good approach (with includes)") do
  User.includes(:posts).limit(50).each do |user|
    puts "User #{user.name} has #{user.posts.length} posts"
  end
end

# 2. Nested N+1 Problem
puts "\n2. Nested N+1 Problem\n"

puts "\nBad approach (nested N+1):"
measure_and_report("Bad approach (nested N+1)") do
  Post.limit(150).each do |post|
    puts "Post '#{post.title}' has #{post.comments.count} comments"
  end
end

puts "\nGood approach (nested includes):"
measure_and_report("Good approach (nested includes)") do
  Post.includes(:comments).limit(150).each do |post|
    puts "Post '#{post.title}' has #{post.comments.length} comments"
  end
end

# 3. Counter Cache Benefits
puts "\n3. Counter Cache Benefits\n"

puts "\nWithout counter cache (counting posts):"
measure_and_report("Without counter cache") do
  User.limit(50).each do |user|
    puts "User #{user.name} has #{user.posts.count} posts"
  end
end

puts "\nWith counter cache (using cached count):"
measure_and_report("With counter cache") do
  User.limit(50).each do |user|
    puts "User #{user.name} has #{user.posts_count} posts"
  end
end

# 4. Different Eager Loading Strategies
puts "\n4. Different Eager Loading Strategies\n"

puts "\nUsing preload (separate queries):"
measure_and_report("Using preload") do
  users = User.preload(:posts).limit(50)
  users.each do |user|
    puts "User #{user.name} has posts: #{user.posts.map(&:title).join(', ')}"
  end
end

puts "\nUsing eager_load (LEFT OUTER JOIN):"
measure_and_report("Using eager_load") do
  users = User.eager_load(:posts).limit(50)
  users.each do |user|
    puts "User #{user.name} has posts: #{user.posts.map(&:title).join(', ')}"
  end
end

puts "\nUsing includes (lets ActiveRecord decide):"
measure_and_report("Using includes") do
  users = User.includes(:posts).limit(50)
  users.each do |user|
    puts "User #{user.name} has posts: #{user.posts.map(&:title).join(', ')}"
  end
end

puts "\nKey Findings:"
puts "1. N+1 queries can significantly impact performance with larger datasets"
puts "2. Nested N+1 problems compound the performance impact"
puts "3. Counter caches are effective for frequently accessed counts"
puts "4. Different eager loading strategies have varying performance characteristics:"
puts "   - preload: Separate queries, good for simple associations"
puts "   - eager_load: LEFT OUTER JOIN, good for filtering"
puts "   - includes: Automatically chooses between preload and eager_load" 