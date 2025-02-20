require_relative 'setup'

class BenchmarkRunner
  class << self
    def run_batch_processing_comparison
      puts PASTEL.bold("\n=== Batch Processing Comparison ===")
      
      results = []
      results << measure_and_report("Processing all records at once") do
        Post.all.each { |post| post.update(title: "#{post.title} - Updated") }
      end
      
      results << measure_and_report("Using find_each with default batch size") do
        Post.find_each { |post| post.update(title: "#{post.title} - Updated") }
      end
      
      results << measure_and_report("Using find_each with custom batch size") do
        Post.find_each(batch_size: 1000) { |post| post.update(title: "#{post.title} - Updated") }
      end
      
      results << measure_and_report("Using update_all") do
        Post.update_all("title = CONCAT(title, ' - Bulk Updated')")
      end
      
      display_comparison(results, "Batch Processing")
    end

    def run_batch_import_comparison
      puts PASTEL.bold("\n=== Batch Import Performance ===")
      
      new_users = 10_000.times.map do |i|
        {
          name: "Batch User #{i}",
          email: "batch_import_#{i}@example.com",
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      
      results = []
      results << measure_and_report("Individual inserts") do
        new_users.take(100).each { |user_data| User.create!(user_data) }
      end
      
      results << measure_and_report("Bulk insert with insert_all") do
        User.insert_all(new_users.take(100))
      end
      
      display_comparison(results, "Batch Import")
    end

    def run_query_optimization_comparison
      puts PASTEL.bold("\n=== Query Optimization Techniques ===")
      
      # Ensure indexes exist
      ActiveRecord::Base.connection.add_index :posts, :title unless ActiveRecord::Base.connection.index_exists?(:posts, :title)
      ActiveRecord::Base.connection.add_index :posts, [:user_id, :created_at] unless ActiveRecord::Base.connection.index_exists?(:posts, [:user_id, :created_at])
      
      results = []
      results << measure_and_report("Query without index") do
        Post.where("content LIKE ?", "%Ruby%").to_a
      end
      
      results << measure_and_report("Query with index") do
        Post.where("title LIKE ?", "%Ruby%").to_a
      end
      
      results << measure_and_report("Complex query without optimization") do
        User.joins(:posts)
            .where(posts: { created_at: 1.week.ago..Time.current })
            .group("users.id")
            .having("COUNT(posts.id) > 5")
            .to_a
      end
      
      results << measure_and_report("Complex query with optimization") do
        User.joins(:posts)
            .where(posts: { created_at: 1.week.ago..Time.current })
            .select("users.*, COUNT(posts.id) as posts_count")
            .group("users.id")
            .having("COUNT(posts.id) > 5")
            .to_a
      end
      
      display_comparison(results, "Query Optimization")
    end

    def run_upsert_comparison
      puts PASTEL.bold("\n=== Upsert Performance Comparison ===")
      
      # Prepare test data
      upsert_users = 1000.times.map do |i|
        {
          email: "user_#{i}@example.com",
          name: "User #{i}",
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      
      # Add duplicates
      upsert_users += 200.times.map do |i|
        {
          email: "user_#{i}@example.com",
          name: "Updated User #{i}",
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      
      results = []
      results << measure_and_report("Individual find_or_create_by") do
        upsert_users.take(100).each do |user_data|
          User.find_or_create_by(email: user_data[:email]) do |user|
            user.assign_attributes(user_data)
          end
        end
      end
      
      results << measure_and_report("Bulk upsert with insert_all") do
        User.upsert_all(
          upsert_users.take(100),
          unique_by: :email,
          returning: false
        )
      end
      
      results << measure_and_report("Sequel upsert") do
        DB[:users].insert_conflict(
          target: :email,
          update: {
            name: Sequel[:excluded][:name],
            updated_at: Time.current
          }
        ).multi_insert(upsert_users.take(100))
      end
      
      display_comparison(results, "Upsert")
    end

    private

    def display_comparison(results, title)
      puts "\n#{PASTEL.bold.magenta("#{title} Comparison:")}"
      
      # Find baseline (slowest) time for relative comparison
      baseline_time = results.map { |r| r[:time] }.max
      
      # Create comparison table
      headers = ['Operation', 'Time', 'Queries', 'Rate', 'Relative Speed']
      rows = results.map do |result|
        relative_speed = baseline_time / result[:time]
        speed_text = if relative_speed == 1
          "baseline"
        else
          "#{relative_speed.round(1)}x faster"
        end

        rate = if result[:operations]
          ops_per_sec = result[:operations] / result[:time]
          if ops_per_sec >= 1000
            "#{format_number((ops_per_sec / 1000.0).round(1))}k/s"
          else
            "#{format_number(ops_per_sec.round(1))}/s"
          end
        else
          "n/a"
        end
        
        [
          result[:title],
          format_duration(result[:time]),
          format_number(result[:queries]),
          PASTEL.cyan(rate),
          PASTEL.send(relative_speed == 1 ? :white : :green, speed_text)
        ]
      end
      
      table = TTY::Table.new(headers, rows)
      puts table.render(:unicode, padding: [0, 1], alignment: [:left, :right, :right, :right, :left])
      
      # Add summary of findings
      puts "\n#{PASTEL.yellow('Key Findings:')}"
      fastest = results.min_by { |r| r[:time] }
      slowest = results.max_by { |r| r[:time] }
      most_queries = results.max_by { |r| r[:queries] }
      least_queries = results.min_by { |r| r[:queries] }
      
      puts "• #{PASTEL.green('Fastest')}: #{fastest[:title]} (#{format_duration(fastest[:time])})"
      puts "• #{PASTEL.red('Slowest')}: #{slowest[:title]} (#{format_duration(slowest[:time])})"
      puts "• #{PASTEL.green('Most efficient')}: #{least_queries[:title]} (#{format_number(least_queries[:queries])} queries)"
      puts "• #{PASTEL.red('Least efficient')}: #{most_queries[:title]} (#{format_number(most_queries[:queries])} queries)"
    end

    def measure_and_report(title)
      puts "\n#{PASTEL.cyan(title)}:"
      queries_count = 0
      sequel_queries_count = 0
      memory_before = GetProcessMem.new.mb
      
      # Setup Sequel query logging
      original_logger = DB.loggers
      DB.loggers = [Logger.new(StringIO.new).tap { |logger|
        logger.define_singleton_method(:info) { |*| sequel_queries_count += 1 }
      }]
      
      time = Benchmark.realtime do
        ActiveSupport::Notifications.subscribed(-> (*) { queries_count += 1 }, "sql.active_record") do
          yield
        end
      end
      
      # Restore Sequel logger
      DB.loggers = original_logger
      
      # Calculate memory usage
      memory_after = GetProcessMem.new.mb
      memory_change = memory_after - memory_before
      
      # Use total queries (ActiveRecord + Sequel)
      total_queries = queries_count + sequel_queries_count
      
      # Determine operations count based on the benchmark type
      operations = case title
      when /Processing all records/, /find_each/, /update_all/
        Post.count
      when /Individual inserts/, /Bulk insert/, /upsert/
        100  # We're using take(100) in these cases
      else
        nil
      end
      
      # Calculate rates
      rate = operations ? (operations / time).round(2) : nil
      queries_per_sec = (total_queries / time).round(2)
      
      table = TTY::Table.new(
        [
          ["#{PASTEL.green('Time taken')}", format_duration(time)],
          ["#{PASTEL.green('Queries executed')}", format_number(total_queries)],
          ["#{PASTEL.green('Memory change')}", format_memory(memory_change)],
          ["#{PASTEL.green('Operations')}", operations ? format_number(operations) : "n/a"],
          ["#{PASTEL.green('Rate')}", rate ? "#{format_number(rate)}/s" : "n/a"],
          ["#{PASTEL.green('Queries/sec')}", format_number(queries_per_sec)]
        ]
      )
      
      puts table.render(:unicode, padding: [0, 1])
      {
        time: time,
        queries: total_queries,
        title: title,
        operations: operations,
        memory_change: memory_change,
        queries_per_sec: queries_per_sec
      }
    end

    def format_memory(mb)
      if mb >= 1024
        "%.1f GB" % (mb / 1024.0)
      else
        "%.1f MB" % mb
      end
    end
  end
end

# Interactive menu
def run_interactive_benchmarks
  setup_database
  spinner = TTY::Spinner.new("[:spinner] Generating sample data ...", format: :dots)
  spinner.auto_spin
  
  generate_sample_data(users: 2000, posts_per_user: 15, comments_per_post: 8)
  spinner.success(PASTEL.green("Done!"))

  loop do
    begin
      puts PASTEL.bold("\n=== Ruby PostgreSQL Performance Benchmarks ===\n")
      
      choice = PROMPT.select("Choose a benchmark to run:", per_page: 10, help: "(Press Ctrl+C to exit)") do |menu|
        menu.choice "Batch Processing Comparison", 1
        menu.choice "Batch Import Performance", 2
        menu.choice "Query Optimization Techniques", 3
        menu.choice "Upsert Performance Comparison", 4
        menu.choice "Run All Benchmarks", 5
        menu.choice "Exit", 6
      end

      case choice
      when 1
        BenchmarkRunner.run_batch_processing_comparison
      when 2
        BenchmarkRunner.run_batch_import_comparison
      when 3
        BenchmarkRunner.run_query_optimization_comparison
      when 4
        BenchmarkRunner.run_upsert_comparison
      when 5
        BenchmarkRunner.run_batch_processing_comparison
        BenchmarkRunner.run_batch_import_comparison
        BenchmarkRunner.run_query_optimization_comparison
        BenchmarkRunner.run_upsert_comparison
      when 6
        puts PASTEL.green("\nThank you for using the benchmark runner!")
        return
      end
    rescue TTY::Reader::InputInterrupt
      puts PASTEL.yellow("\nBenchmark runner interrupted. Exiting gracefully...")
      return
    rescue StandardError => e
      puts PASTEL.red("\nError: #{e.message}")
      puts PASTEL.red("Backtrace:\n#{e.backtrace.join("\n")}")
      return
    end
  end
end

# Run the interactive benchmarks
run_interactive_benchmarks 