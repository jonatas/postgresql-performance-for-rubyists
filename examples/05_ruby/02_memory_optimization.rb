require_relative 'setup'

# Setup fresh database and generate larger dataset
setup_database
generate_sample_data(users: 500, posts_per_user: 20, comments_per_post: 10)

puts "\n=== Memory Optimization Examples ==="

def print_memory_report(report, title)
  puts "\n#{title} Memory Profile:"
  puts "Total allocated: #{format_memory(report.total_allocated_memsize)}"
  puts "Total retained: #{format_memory(report.total_retained_memsize)}"
  puts "Allocated objects: #{format_number(report.total_allocated)}"
  puts "Retained objects: #{format_number(report.total_retained)}"
end

def format_memory(bytes)
  kb = bytes / 1024.0
  if kb >= 1024
    "%.2f MB" % (kb / 1024.0)
  else
    "%.2f KB" % kb
  end
end

def format_number(num)
  num.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
end

# Example 1: Standard ActiveRecord vs OccamsRecord
puts "\n1. ActiveRecord vs OccamsRecord Memory Usage"

report = MemoryProfiler.report do
  users_data = User.includes(:posts).map do |user|
    {
      name: user.name,
      email: user.email,
      post_count: user.posts.size,
      latest_post: user.posts.max_by(&:created_at)&.title
    }
  end
end
print_memory_report(report, "Standard ActiveRecord")

report = MemoryProfiler.report do
  users_data = OccamsRecord
    .query(User.all)
    .eager_load(:posts)
    .run
    .map do |user|
      {
        name: user.name,
        email: user.email,
        post_count: user.posts.size,
        latest_post: user.posts.max_by(&:created_at)&.title
      }
    end
end
print_memory_report(report, "OccamsRecord")

# Example 2: Pluck vs Select
puts "\n2. Pluck vs Select Memory Usage"

report = MemoryProfiler.report do
  user_emails = User.all.map(&:email)
end
print_memory_report(report, "Using map")

report = MemoryProfiler.report do
  user_emails = User.pluck(:email)
end
print_memory_report(report, "Using pluck")

# Example 3: Batch Processing Memory Impact
puts "\n3. Batch Processing Memory Impact"

report = MemoryProfiler.report do
  Post.all.each do |post|
    post.touch
  end
end
print_memory_report(report, "Processing all at once")

report = MemoryProfiler.report do
  Post.find_each(batch_size: 100) do |post|
    post.touch
  end
end
print_memory_report(report, "Processing in batches")

# Example 4: Complex Data Processing
puts "\n4. Complex Data Processing Memory Optimization"

# Memory-intensive version
report = MemoryProfiler.report do
  results = User.includes(posts: :comments).map do |user|
    {
      user: user.attributes,
      posts: user.posts.map do |post|
        post_data = post.attributes
        post_data[:comment_count] = post.comments.size
        post_data
      end
    }
  end
end
print_memory_report(report, "Memory-intensive processing")

# Memory-optimized version
report = MemoryProfiler.report do
  results = User
    .joins(posts: :comments)
    .select('users.*, COUNT(DISTINCT posts.id) as posts_count, COUNT(comments.id) as total_comments')
    .group('users.id')
    .map do |user|
      {
        user: user.attributes,
        posts_count: user.posts_count,
        total_comments: user.total_comments
      }
    end
end
print_memory_report(report, "Memory-optimized processing")

# Example 5: Streaming Results
puts "\n5. Streaming Large Results"
require 'csv'

report = MemoryProfiler.report do
  CSV.open("users_report.csv", "w") do |csv|
    csv << ["Name", "Email", "Posts Count"]
    User.find_each do |user|
      csv << [user.name, user.email, user.posts.count]
    end
  end
end
print_memory_report(report, "Streaming to CSV")

puts "\nKey Findings:"
puts "1. OccamsRecord significantly reduces memory allocation compared to ActiveRecord"
puts "2. Using pluck instead of map can greatly reduce memory usage"
puts "3. Batch processing helps maintain consistent memory usage"
puts "4. Moving calculations to the database reduces memory overhead"
puts "5. Streaming results prevents memory bloat with large datasets"

# Cleanup
File.delete("users_report.csv") if File.exist?("users_report.csv") 