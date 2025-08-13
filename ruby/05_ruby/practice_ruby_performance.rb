require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'activerecord'
  gem 'sequel'
  gem 'benchmark-ips'
  gem 'memory_profiler'
  gem 'occams-record'
  gem 'pry'
end

require 'active_record'
require 'sequel'
require 'benchmark/ips'
require 'memory_profiler'
require 'occams-record'

# Connect to database
ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
DB = Sequel.connect(ENV['DATABASE_URL'])

# Set up our test models
class Post < ActiveRecord::Base
  belongs_to :user
  has_many :comments
end

class User < ActiveRecord::Base
  has_many :posts
  has_many :comments, through: :posts
end

class Comment < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
end

# Create tables for our examples
ActiveRecord::Base.connection.instance_exec do
  drop_table :comments if table_exists?(:comments)
  drop_table :posts if table_exists?(:posts)
  drop_table :users if table_exists?(:users)

  create_table :users do |t|
    t.string :name
    t.string :email
    t.timestamps
  end

  create_table :posts do |t|
    t.string :title
    t.text :content
    t.references :user
    t.timestamps
  end

  create_table :comments do |t|
    t.text :content
    t.references :post
    t.references :user
    t.timestamps
  end
end

# Generate sample data
puts "\nGenerating sample data..."
100.times do |i|
  user = User.create!(
    name: "User #{i}",
    email: "user#{i}@example.com"
  )

  5.times do |j|
    post = user.posts.create!(
      title: "Post #{j} by User #{i}",
      content: "Content #{j} from User #{i}"
    )

    3.times do |k|
      post.comments.create!(
        content: "Comment #{k} on Post #{j} by User #{i}",
        user: User.offset(rand(User.count)).first
      )
    end
  end
end

puts "\n=== Ruby Performance Examples ==="

puts "\n1. N+1 Query Problem"
puts "\nBad approach (N+1 queries):"
time = Benchmark.realtime do
  User.all.each do |user|
    puts "User #{user.name} has #{user.posts.count} posts"
  end
end
puts "Time taken: #{time.round(2)} seconds"

puts "\nGood approach (eager loading):"
time = Benchmark.realtime do
  User.includes(:posts).each do |user|
    puts "User #{user.name} has #{user.posts.count} posts"
  end
end
puts "Time taken: #{time.round(2)} seconds"

puts "\n2. Memory Usage Comparison"
puts "\nStandard ActiveRecord:"
report = MemoryProfiler.report do
  User.includes(:posts).map do |user|
    { name: user.name, post_count: user.posts.size }
  end
end
puts "Memory allocated: #{report.total_allocated_memsize} bytes"

puts "\nOccamsRecord approach:"
report = MemoryProfiler.report do
  OccamsRecord
    .query(User.all)
    .eager_load(:posts)
    .run
    .map { |user| { name: user.name, post_count: user.posts.size } }
end
puts "Memory allocated: #{report.total_allocated_memsize} bytes"

puts "\n3. ORM Performance Comparison"
Benchmark.ips do |x|
  x.config(time: 1, warmup: 1)

  x.report("ActiveRecord") do
    User.where(created_at: 1.day.ago..Time.current).to_a
  end

  x.report("Sequel") do
    DB[:users].where(created_at: 1.day.ago..Time.current).all
  end

  x.compare!
end

puts "\n4. Batch Processing"
puts "\nProcessing all records at once:"
time = Benchmark.realtime do
  Post.all.each do |post|
    post.touch
  end
end
puts "Time taken: #{time.round(2)} seconds"

puts "\nProcessing in batches:"
time = Benchmark.realtime do
  Post.find_each(batch_size: 100) do |post|
    post.touch
  end
end
puts "Time taken: #{time.round(2)} seconds"

puts "\n5. Query Building Performance"
puts "\nMultiple where clauses:"
time = Benchmark.realtime do
  scope = User.where(created_at: 1.day.ago..Time.current)
  scope = scope.where.not(email: nil)
  scope = scope.where("name LIKE ?", "User%")
  scope.to_a
end
puts "Time taken: #{time.round(2)} seconds"

puts "\nSingle query building:"
time = Benchmark.realtime do
  User.where(created_at: 1.day.ago..Time.current)
      .where.not(email: nil)
      .where("name LIKE ?", "User%")
      .to_a
end
puts "Time taken: #{time.round(2)} seconds"

puts "\nDone! You can now explore more Ruby performance optimizations!" 