require_relative 'setup'

# Setup fresh database and generate larger dataset
setup_database
generate_sample_data(users: 2000, posts_per_user: 15, comments_per_post: 8)

puts "\n=== Batch Processing and Query Optimization Examples ==="

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

# Example 1: Different Batch Processing Approaches
puts "\n1. Batch Processing Comparison"

measure_and_report("Processing all records at once") do
  Post.all.each do |post|
    post.update(title: "#{post.title} - Updated")
  end
end

measure_and_report("Using find_each with default batch size") do
  Post.find_each do |post|
    post.update(title: "#{post.title} - Updated")
  end
end

measure_and_report("Using find_each with custom batch size") do
  Post.find_each(batch_size: 1000) do |post|
    post.update(title: "#{post.title} - Updated")
  end
end

measure_and_report("Using update_all") do
  Post.update_all("title = CONCAT(title, ' - Bulk Updated')")
end

# Example 2: Batch Import Strategies
puts "\n2. Batch Import Performance"

new_users = 10_000.times.map do |i|
  {
    name: "Batch User #{i}",
    email: "batch_user_#{i}@example.com",
    created_at: Time.current,
    updated_at: Time.current
  }
end

measure_and_report("Individual inserts") do
  new_users.take(100).each do |user_data|
    User.create!(user_data)
  end
end

measure_and_report("Bulk insert with insert_all") do
  User.insert_all(new_users.take(100))
end

# Example 3: Query Optimization
puts "\n3. Query Optimization Techniques"

# Add indexes for testing
ActiveRecord::Base.connection.add_index :posts, :title unless ActiveRecord::Base.connection.index_exists?(:posts, :title)
ActiveRecord::Base.connection.add_index :posts, [:user_id, :created_at] unless ActiveRecord::Base.connection.index_exists?(:posts, [:user_id, :created_at])

measure_and_report("Query without index") do
  Post.where("content LIKE ?", "%Ruby%").to_a
end

measure_and_report("Query with index") do
  Post.where("title LIKE ?", "%Ruby%").to_a
end

measure_and_report("Complex query without optimization") do
  User.joins(:posts)
      .where(posts: { created_at: 1.week.ago..Time.current })
      .group("users.id")
      .having("COUNT(posts.id) > 5")
      .to_a
end

measure_and_report("Complex query with optimization") do
  User.joins(:posts)
      .where(posts: { created_at: 1.week.ago..Time.current })
      .select("users.*, COUNT(posts.id) as posts_count")
      .group("users.id")
      .having("COUNT(posts.id) > 5")
      .to_a
end

# Example 4: Efficient Data Updates
puts "\n4. Efficient Data Update Patterns"

measure_and_report("Individual updates") do
  User.find_each do |user|
    user.update(name: "#{user.name} - Updated")
  end
end

measure_and_report("Bulk update with update_all") do
  User.update_all("name = CONCAT(name, ' - Bulk Updated')")
end

measure_and_report("Conditional bulk update") do
  User.where("created_at < ?", 1.day.ago)
      .update_all("name = CONCAT(name, ' - Old User')")
end

# Example 5: Advanced Batch Processing
puts "\n5. Advanced Batch Processing"

measure_and_report("Processing with find_each and transaction") do
  ActiveRecord::Base.transaction do
    Post.find_each(batch_size: 1000) do |post|
      post.update(content: "#{post.content}\n\nUpdated at #{Time.current}")
    end
  end
end

measure_and_report("Parallel processing with in_batches") do
  Post.in_batches(of: 1000) do |batch|
    batch.update_all("content = CONCAT(content, '\n\nBatch updated at #{Time.current}')")
  end
end

puts "\nKey Findings:"
puts "1. Batch Processing:"
puts "   - find_each is memory-efficient for large datasets"
puts "   - Optimal batch size depends on record size and system resources"
puts "   - update_all is fastest but bypasses validations and callbacks"

puts "\n2. Batch Imports:"
puts "   - Bulk insert operations are significantly faster"
puts "   - insert_all bypasses validations but offers better performance"
puts "   - Consider using activerecord-import for complex scenarios"

puts "\n3. Query Optimization:"
puts "   - Proper indexes are crucial for performance"
puts "   - Complex queries benefit from careful select clause planning"
puts "   - Use explain to understand query execution plans"

puts "\n4. Update Strategies:"
puts "   - Bulk updates are faster but bypass ActiveRecord callbacks"
puts "   - Transactions can help maintain data consistency"
puts "   - Consider using update_all for simple updates"

puts "\n5. Advanced Techniques:"
puts "   - in_batches allows for parallel processing"
puts "   - Transactions can improve bulk operation performance"
puts "   - Balance between speed and ActiveRecord features"

# Example 6: Upsert Scenarios
puts "\n6. Upsert Performance Comparison"

# Prepare test data for upserts
upsert_users = 1000.times.map do |i|
  {
    email: "user_#{i}@example.com",
    name: "User #{i}",
    created_at: Time.current,
    updated_at: Time.current
  }
end

# Add some duplicates to test conflict resolution
upsert_users += 200.times.map do |i|
  {
    email: "user_#{i}@example.com",  # Duplicate emails
    name: "Updated User #{i}",       # New names
    created_at: Time.current,
    updated_at: Time.current
  }
end

measure_and_report("Individual find_or_create_by") do
  upsert_users.take(100).each do |user_data|
    User.find_or_create_by(email: user_data[:email]) do |user|
      user.assign_attributes(user_data)
    end
  end
end

measure_and_report("Bulk upsert with insert_all") do
  User.upsert_all(
    upsert_users.take(100),
    unique_by: :email,
    returning: false
  )
end

measure_and_report("Sequel upsert") do
  DB[:users].insert_conflict(
    target: :email,
    update: {
      name: Sequel[:excluded][:name],
      updated_at: Time.current
    }
  ).multi_insert(upsert_users.take(100))
end

puts "\nUpsert Key Findings:"
puts "1. Individual find_or_create_by: Safe but slower, with N queries"
puts "2. Bulk upsert_all: Fast, single query, but bypasses validations"
puts "3. Sequel upsert: Efficient with flexible conflict resolution"
puts "4. Consider unique constraints and data consistency needs"
puts "5. Balance between performance and ActiveRecord features" 