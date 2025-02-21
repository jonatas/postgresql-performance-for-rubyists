#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_record'
require 'benchmark'
require 'logger'
require 'timescaledb'
require_relative '../../config/database'

# Configure logging
ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord::Base.logger.level = :info

# Model definition
class Measurement < ActiveRecord::Base
  extend Timescaledb::ActsAsHypertable

  acts_as_hypertable(
    time_column: 'time',
    compress_segmentby: 'device_id',
    compress_orderby: 'time DESC'
  )

  # Scope for parallel query testing
  scope :temperature_analysis, lambda {
    select('device_id, 
            time_bucket(\'1 hour\', time) as hour,
            avg(temperature) as avg_temp,
            stddev(temperature) as std_temp,
            count(*) as measurements')
      .group('device_id, hour')
      .order('device_id, hour')
  }
end

class ParallelExecutionTest
  CHUNK_INTERVALS = {
    'daily' => '1 day',
    'weekly' => '1 week',
    'monthly' => '1 month'
  }

  class << self
    def run_all_tests
      CHUNK_INTERVALS.each do |interval_name, interval|
        puts "\n#{'='*50}"
        puts "Testing with #{interval_name} chunks"
        puts "#{'='*50}"
        
        setup_database(interval)
        generate_test_data
        run_performance_test
        cleanup_test_data
      end
    end

    private

    def setup_database(chunk_interval)
      puts "Setting up database with #{chunk_interval} chunks..."
      
      # Drop existing table if it exists
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS measurements CASCADE;")
      
      # Create the new table
      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE TABLE measurements (
          time TIMESTAMPTZ NOT NULL,
          device_id TEXT NOT NULL,
          temperature FLOAT,
          humidity FLOAT
        );
      SQL
      
      # Convert to hypertable with specified chunk interval
      ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT create_hypertable('measurements', 'time', 
          chunk_time_interval => interval '#{chunk_interval}');
      SQL

      # Enable parallel query execution
      ActiveRecord::Base.connection.execute(<<~SQL)
        ALTER DATABASE #{ActiveRecord::Base.connection.current_database}
        SET max_parallel_workers_per_gather = 8;
        
        ALTER DATABASE #{ActiveRecord::Base.connection.current_database}
        SET max_parallel_workers = 8;

        -- Set work_mem for better hash aggregation
        SET work_mem = '256MB';
      SQL

      puts "Database configured for parallel execution"
    end


    def generate_test_data
      puts "Generating test data..."
      
      # Generate 1 year of data for 100 devices using generate_series
      # This will create data points every minute
      execute_sql(<<~SQL)
        INSERT INTO measurements (time, device_id, temperature, humidity)
        SELECT
          time,
          'device_' || device_id,
          -- Temperature varies between 10 and 40 with some seasonality
          25 + 15 * sin((extract(doy from time)::float / 365) * 2 * pi()) + 
          -- Daily variation of ±5 degrees
          5 * sin((extract(hour from time)::float / 24) * 2 * pi()) +
          -- Random noise
          random() * 2 - 1,
          -- Humidity varies between 30 and 80 with inverse correlation to temperature
          55 + 25 * sin((extract(doy from time)::float / 365) * 2 * pi() + pi()) +
          random() * 5
        FROM
          generate_series(
            now() - interval '1 year',
            now(),
            interval '1 minute'
          ) as time,
          generate_series(1, 100) as device_id;
      SQL
      
      # Get statistics about the data
      count = execute_sql("SELECT count(*) FROM measurements;")
      puts "Generated #{count.first['count']} records"
      
      chunks = execute_sql("SELECT count(*) FROM timescaledb_information.chunks WHERE hypertable_name = 'measurements';")
      puts "Data spread across #{chunks.first['count']} chunks"
    end

    def run_performance_test
      puts "\nRunning performance tests..."
      
      # Test queries with optimized parallel settings
      # We'll skip 2 workers as it often doesn't provide significant benefits
      test_scenarios = {
        'Baseline (no parallelization)' => {
          'setting' => 'SET max_parallel_workers_per_gather = 0;',
          'description' => 'Sequential scan baseline for comparison'
        },
        '4 workers' => {
          'setting' => "SET max_parallel_workers_per_gather = 4;\n" \
                      "SET parallel_tuple_cost = 0.1;\n" \
                      "SET parallel_setup_cost = 10.0;",
          'description' => 'Balanced parallelization for medium-sized chunks'
        },
        '8 workers' => {
          'setting' => "SET max_parallel_workers_per_gather = 8;\n" \
                      "SET parallel_tuple_cost = 0.1;\n" \
                      "SET parallel_setup_cost = 10.0;\n" \
                      "SET work_mem = '512MB';",
          'description' => 'Maximum parallelization for large chunks'
        }
      }

      results = {}
      
      test_scenarios.each do |scenario, config|
        puts "\nTesting: #{scenario}"
        puts "Description: #{config['description']}"
        execute_sql(config['setting'])
        
        # Run the test query and capture execution plan
        puts "\nExecution plan:"
        plan = execute_sql(<<~SQL)
          EXPLAIN ANALYZE
          SELECT device_id,
                 time_bucket('1 day', time) as day,
                 avg(temperature) as avg_temp,
                 stddev(temperature) as std_temp,
                 min(temperature) as min_temp,
                 max(temperature) as max_temp,
                 count(*) as measurements
          FROM measurements
          WHERE time >= now() - INTERVAL '1 year'
          GROUP BY device_id, day
          ORDER BY device_id, day;
        SQL
        
        puts plan.map { |row| row['QUERY PLAN'] }.grep(/\sTime:/).join("\n")

        # Measure actual query performance with multiple runs
        times = 3.times.map do |i|
          print "Run #{i+1}: "
          time = Benchmark.measure do
            Measurement.where(time: 1.year.ago..Time.current)
                      .temperature_analysis
                      .load
          end
          puts "#{time.real.round(2)} seconds"
          time.real
        end
        
        # Calculate statistics
        avg_time = (times.sum / times.size).round(2)
        std_dev = Math.sqrt(times.map { |t| (t - avg_time) ** 2 }.sum / times.size).round(2)
        
        results[scenario] = {
          'average' => avg_time,
          'std_dev' => std_dev
        }
      end

      # Print comprehensive summary
      puts "\nPerformance Summary:"
      puts "===================="
      results.each do |scenario, metrics|
        puts "\n#{scenario}:"
        puts "  Average query time: #{metrics['average']} seconds (±#{metrics['std_dev']})"
        
        if scenario != 'Baseline (no parallelization)'
          speedup = (results['Baseline (no parallelization)']['average'] / metrics['average']).round(2)
          puts "  Speedup over baseline: #{speedup}x"
        end
      end

      # Print recommendations
      puts "\nRecommendations:"
      puts "================"
      
      best_scenario = results.min_by { |_, metrics| metrics['average'] }
      worst_scenario = results.max_by { |_, metrics| metrics['average'] }
      
      puts "- Best performing configuration: #{best_scenario[0]}"
      puts "- Worst performing configuration: #{worst_scenario[0]}"
      
      if best_scenario[1]['average'] < 0.8 * worst_scenario[1]['average']
        puts "- Significant performance improvement observed with parallelization"
        puts "  * Best configuration is #{best_scenario[1]['average'] / worst_scenario[1]['average']}x faster than worst"
      else
        puts "- Limited benefit from parallelization, consider:"
        puts "  * Reviewing chunk size configuration"
        puts "  * Analyzing data distribution"
        puts "  * Checking for I/O bottlenecks"
      end
    end

    def cleanup_test_data
      puts "\nCleaning up test data..."
      execute_sql("DROP TABLE IF EXISTS measurements;")
      puts "Cleanup completed"
    end

    def execute_sql(sql)
      ActiveRecord::Base.connection.execute(sql).to_a
    end
  end
end

# Run the tests
if __FILE__ == $PROGRAM_NAME
  begin
    ParallelExecutionTest.run_all_tests
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace
  end
end 