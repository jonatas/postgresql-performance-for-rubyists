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
  gem 'faker'
  gem 'tty-prompt'
  gem 'tty-table'
  gem 'tty-spinner'
  gem 'pastel'
  gem 'io-console'
  gem 'get_process_mem'
end

require 'active_record'
require 'sequel'
require 'benchmark/ips'
require 'memory_profiler'
require 'occams-record'
require 'faker'
require 'tty-prompt'
require 'tty-table'
require 'tty-spinner'
require 'pastel'
require 'io/console'
require 'get_process_mem'

# Initialize TTY toolkit
PROMPT = TTY::Prompt.new
PASTEL = Pastel.new

def format_duration(seconds)
  if seconds < 0.001
    "%.3f ms" % (seconds * 1000)
  else
    "%.3f s" % seconds
  end
end

def format_number(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

# Improved measure_and_report method
def measure_and_report(title)
  puts "\n#{PASTEL.cyan(title)}:"
  queries_count = 0
  time = Benchmark.realtime do
    ActiveSupport::Notifications.subscribed(-> (*) { queries_count += 1 }, "sql.active_record") do
      yield
    end
  end
  
  table = TTY::Table.new(
    [
      ["#{PASTEL.green('Time taken')}", format_duration(time)],
      ["#{PASTEL.green('Queries executed')}", format_number(queries_count)]
    ]
  )
  
  puts table.render(:unicode, padding: [0, 1])
  {time: time, queries: queries_count}
end

# Connect to database
ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
DB = Sequel.connect(ENV['DATABASE_URL'])

# Set up our test models
class Post < ActiveRecord::Base
  belongs_to :user, counter_cache: true
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

# Helper method to setup database tables
def setup_database
  ActiveRecord::Base.connection.instance_exec do
    drop_table :comments if table_exists?(:comments)
    drop_table :posts if table_exists?(:posts)
    drop_table :users if table_exists?(:users)

    create_table :users do |t|
      t.string :name
      t.string :email
      t.integer :posts_count, default: 0
      t.timestamps
      t.index :email, unique: true
    end

    create_table :posts do |t|
      t.string :title
      t.text :content
      t.references :user, index: true
      t.timestamps
      t.index :created_at
    end

    create_table :comments do |t|
      t.text :content
      t.references :post, index: true
      t.references :user, index: true
      t.timestamps
      t.index :created_at
    end
  end
end

# Helper method to generate sample data with more realistic content
def generate_sample_data(users: 100, posts_per_user: 5, comments_per_post: 3)
  spinner = TTY::Spinner.new("[:spinner] Generating sample data ...", format: :dots)
  spinner.auto_spin

  # Generate users in batches
  user_batches = []
  users.times do |i|
    user_batches << {
      name: Faker::Name.name,
      email: Faker::Internet.unique.email,
      created_at: Time.current,
      updated_at: Time.current
    }
    
    if (i + 1) % 100 == 0 || i == users - 1
      User.insert_all(user_batches)
      user_batches = []
      spinner.spin
    end
  end

  # Get all user IDs
  user_ids = User.pluck(:id)
  
  # Generate posts in batches
  post_batches = []
  users.times do |i|
    user_id = user_ids[i]
    posts_per_user.times do |j|
      post_batches << {
        title: Faker::Lorem.sentence(word_count: 5),
        content: Faker::Lorem.paragraphs(number: 3).join("\n\n"),
        user_id: user_id,
        created_at: Time.current,
        updated_at: Time.current
      }
      
      if post_batches.size >= 100
        Post.insert_all(post_batches)
        post_batches = []
        spinner.spin
      end
    end
  end
  Post.insert_all(post_batches) unless post_batches.empty?

  # Get all post IDs
  post_ids = Post.pluck(:id)
  
  # Generate comments in batches
  comment_batches = []
  post_ids.each do |post_id|
    comments_per_post.times do
      comment_batches << {
        content: Faker::Lorem.paragraph,
        post_id: post_id,
        user_id: user_ids.sample,
        created_at: Time.current,
        updated_at: Time.current
      }
      
      if comment_batches.size >= 1000
        Comment.insert_all(comment_batches)
        comment_batches = []
        spinner.spin
      end
    end
  end
  Comment.insert_all(comment_batches) unless comment_batches.empty?

  # Update counter caches in batches
  User.find_each(batch_size: 100) do |user|
    User.where(id: user.id).update_all(
      posts_count: user.posts.count
    )
    spinner.spin
  end

  spinner.success(PASTEL.green("Done!"))
  
  puts PASTEL.cyan("\nGenerated:")
  table = TTY::Table.new(
    [
      ["Users", format_number(User.count)],
      ["Posts", format_number(Post.count)],
      ["Comments", format_number(Comment.count)]
    ]
  )
  puts table.render(:unicode, padding: [0, 1])
end 