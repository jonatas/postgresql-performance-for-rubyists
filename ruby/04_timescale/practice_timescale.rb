require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'timescaledb', path: '../timescale-gem'
  gem 'pg'
  gem 'activerecord'
  gem 'pry'
end

require 'timescaledb'
require 'active_record'
require 'pp'

# Get database URL from command line argument or environment variable
database_url = ARGV.last || ENV['DATABASE_URL']

# Check if database URL is provided
unless database_url
  puts "Usage: ruby #{$0} postgres://user:pass@host:port/db_name"
  puts "or set DATABASE_URL in your environment"
  exit 1
end

# Connect to database
ActiveSupport.on_load(:active_record) do
  extend Timescaledb::ActsAsHypertable
  include Timescaledb::ContinuousAggregatesHelper
end

ActiveRecord::Base.establish_connection(database_url)

puts "\n=== TimescaleDB Practice Examples ==="
class Measurement < ActiveRecord::Base
    acts_as_hypertable time_column: 'time',
      value_column: 'temperature',
      segment_by: 'device_id'

    scope :avg_temperature, -> { select('device_id, avg(temperature) as temperature').group('device_id') }
    scope :avg_humidity, -> { select('device_id, avg(humidity) as humidity').group('device_id') }
    scope :battery_stats, -> { select('device_id, min(battery_level) as min_battery, avg(battery_level) as battery_level').group('device_id') }

    scope :last_week, -> { where(time: 1.week.ago..Time.current) }
    scope :today, -> { where(time: Time.current.beginning_of_day..Time.current.end_of_day) }

    continuous_aggregates scopes: [:avg_temperature, :avg_humidity, :battery_stats],
      timeframes: [:hour, :day],
      refresh_policy: {
        hour: {
          start_offset: '3 hours',
          end_offset: '1 hour',
          schedule_interval: '1 hour'
        },
        day: {
          start_offset: '3 days',
          end_offset: '1 day',
          schedule_interval: '1 day'
        }
      }
end

ActiveRecord::Base.logger = Logger.new(STDOUT)
# 1. Getting started with basic time-bucket queries
puts "\n1. Going to Raw data with average temperature by hour for the last day:"
pp Measurement.today.avg_temperature.map(&:attributes)
# 2. Let's look at explain analyze
pp Measurement.today.avg_temperature.explain

# Refresh continuous aggregates
Measurement.refresh_aggregates
# 3. Using continuous aggregates
puts "\n3. Using continuous aggregates - Daily averages:"
pp Measurement.where(time: 1.week.ago..Time.current).avg_temperature.map(&:attributes)
# Let's look at explain
pp Measurement.where(time: 1.week.ago..Time.current).avg_temperature.explain


# 4. Working with chunks
puts "\n4. Chunk information:"
puts "Total chunks: #{Measurement.chunks.count}"
puts "Compressed chunks: #{Measurement.chunks.compressed.count}"
puts "Uncompressed chunks: #{Measurement.chunks.uncompressed.count}"

# 4. Advanced time-series analytics
puts "\n4. Moving average of temperature:"
moving_avg = Measurement.today.avg_temperature.map(&:attributes)
pp moving_avg

# 5. Retention policy example
puts "\n5. Data retention policy:"
puts "To set up a retention policy, you would execute:"
puts "SELECT add_retention_policy('measurements', INTERVAL '3 months');"
puts "or tweak the `drop_after` option in the hypertable definition."

# 6. Compression policy status
puts "\n6. Compression policy status:"
pp Measurement.hypertable.compression_stats

puts "\n=== Query Analysis and Partitioning Insights ==="

# 1. Basic time-bucket query with explain
puts "\n1. Time-bucket query analysis:"
query = Measurement.today.avg_temperature
puts "\nQuery SQL:"
puts query.to_sql
puts "\nQuery Plan:"
pp query.explain

# 2. Demonstrate chunk exclusion
puts "\n2. Chunk exclusion effectiveness:"
old_query = Measurement.where(time: 6.months.ago..5.months.ago).avg_temperature
recent_query = Measurement.where(time: 1.day.ago..Time.current).avg_temperature

puts "\nOld data query SQL:"
puts old_query.to_sql
puts "\nOld data query plan:"
pp old_query.explain

puts "\nRecent data query SQL:"
puts recent_query.to_sql
puts "\nRecent data query plan:"
pp recent_query.explain

# 3. Demonstrate device_id partitioning benefits
puts "\n3. Device-specific query analysis:"
device_query = Measurement.where(device_id: 'device1')
  .where(time: 1.week.ago..Time.current)
  .avg_temperature

puts "\nDevice-specific query SQL:"
puts device_query.to_sql
puts "\nDevice-specific query plan:"
pp device_query.explain

# 4. Continuous aggregate performance
puts "\n4. Continuous aggregate vs raw data performance:"
raw_query = Measurement.where(time: 1.month.ago..Time.current)
  .avg_temperature

puts "\nRaw data query SQL:"
puts raw_query.to_sql
puts "\nRaw data query plan:"
pp raw_query.explain

puts "\nPartitioning Benefits in TimescaleDB:"
puts "1. Chunk Exclusion: TimescaleDB automatically excludes irrelevant chunks based on time ranges"
puts "2. Parallel Query: Each chunk can be processed in parallel"
puts "3. Device-based Segmentation: Using segment_by improves queries filtered by device_id"
puts "4. Efficient Data Management:"
puts "   - Automatic chunk creation based on time intervals"
puts "   - Selective compression of older chunks"
puts "   - Easy retention policy management"
puts "\nBest Practices:"
puts "1. Choose appropriate chunk intervals based on your query patterns"
puts "2. Use segment_by for frequently filtered dimensions"
puts "3. Set up continuous aggregates for common aggregate queries"
puts "4. Implement compression for older data"
puts "5. Configure retention policies based on data lifecycle"

puts "\n=== Advanced TimescaleDB Optimization Examples ==="

# 1. Time Bucket Window Functions
puts "\n1. Moving Average with Time Buckets:"
window_query = Measurement.select(
  "bucket, 
   device_id,
   avg_temp,
   avg(avg_temp) OVER (
     PARTITION BY device_id
     ORDER BY bucket
     ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
   ) as moving_avg"
).from(
  Measurement.select(
    "time_bucket('1 hour', time) as bucket,
     device_id,
     avg(temperature) as avg_temp"
  ).where(time: 1.day.ago..Time.current)
   .group('bucket, device_id')
   .order('bucket DESC')
   .arel.as('hourly_stats')
)

puts "\nWindow Function SQL:"
puts window_query.to_sql
puts "\nWindow Function Plan:"
pp window_query.explain

# 2. Materialized Views vs Continuous Aggregates
puts "\n2. Materialized View vs Continuous Aggregate Performance:"
puts "\nMaterialized View Query:"
materialized_query = "
  SELECT time_bucket('1 hour', time) as bucket,
         avg(temperature) as avg_temp
  FROM measurements
  WHERE time > NOW() - INTERVAL '1 day'
  GROUP BY bucket
  ORDER BY bucket DESC
  LIMIT 24"

puts materialized_query
puts "\nContinuous Aggregate Query:"
continuous_query = "
  SELECT time, avg_temperature
  FROM avg_temperature_per_hour
  WHERE time > NOW() - INTERVAL '1 day'
  ORDER BY time DESC
  LIMIT 24"

puts continuous_query

# 3. Multi-dimensional Partitioning
puts "\n3. Multi-dimensional Query Optimization:"
multi_dim_query = Measurement.where(
  device_id: ['device1', 'device2'],
  time: 1.week.ago..Time.current
).select(
  "time_bucket('1 hour', time) as hour,
   device_id,
   avg(temperature) as avg_temp,
   avg(humidity) as avg_humidity"
).group('hour, device_id')

puts "\nMulti-dimensional Query SQL:"
puts multi_dim_query.to_sql
puts "\nMulti-dimensional Query Plan:"
pp multi_dim_query.explain

# 4. Compression Strategy Analysis:
puts "\n4. Compression Strategy Analysis:"
puts "\nCompression Information by Chunk:"
Measurement.chunks.each do |chunk|
  puts "Chunk #{chunk.chunk_name}:"
  puts "  Range: #{chunk.range_start} to #{chunk.range_end}"
  puts "  Compressed: #{chunk.is_compressed?}"
end

puts "\nOverall Compression Statistics:"
compression_stats = Measurement.hypertable.compression_stats
puts "Total chunks: #{compression_stats.total_chunks}"
puts "Compressed chunks: #{compression_stats.number_compressed_chunks}"
puts "Before compression:"
puts "  Table bytes: #{compression_stats.before_compression_table_bytes}"
puts "  Index bytes: #{compression_stats.before_compression_index_bytes}"
puts "  Toast bytes: #{compression_stats.before_compression_toast_bytes}"
puts "  Total bytes: #{compression_stats.before_compression_total_bytes}"
puts "After compression:"
puts "  Table bytes: #{compression_stats.after_compression_table_bytes}"
puts "  Index bytes: #{compression_stats.after_compression_index_bytes}"
puts "  Toast bytes: #{compression_stats.after_compression_toast_bytes}"
puts "  Total bytes: #{compression_stats.after_compression_total_bytes}"
compression_ratio = (1 - compression_stats.after_compression_total_bytes.to_f / compression_stats.before_compression_total_bytes) * 100
puts "Compression ratio: #{compression_ratio.round(2)}% space savings"

# 5. Refresh Strategies for Continuous Aggregates
puts "\n5. Continuous Aggregate Refresh Analysis:"
puts "\nRefresh Policies:"
refresh_policies_query = "
SELECT view_name,
       refresh_interval,
       start_offset,
       end_offset
FROM timescaledb_information.continuous_aggregate_policies"
puts refresh_policies_query

# 6. Advanced Time Series Functions
puts "\n6. Advanced Time Series Analytics:"
interpolation_query = "
WITH interpolated AS (
  SELECT time_bucket('5 minutes', time) AS five_min,
         device_id,
         locf(avg(temperature)) AS interpolated_temp
  FROM measurements
  WHERE time > NOW() - INTERVAL '1 day'
  GROUP BY five_min, device_id
  ORDER BY five_min
)
SELECT five_min,
       device_id,
       interpolated_temp,
       avg(interpolated_temp) OVER (
         PARTITION BY device_id
         ORDER BY five_min
         ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
       ) as rolling_avg
FROM interpolated"

puts "\nAdvanced Time Series SQL:"
puts interpolation_query

# 7. Hypertable Partitioning Analysis
puts "\n7. Hypertable Partitioning Details:"
puts "\nChunk Distribution:"
chunk_analysis_query = "
SELECT chunk_schema || '.' || chunk_name as chunk_full_name,
       range_start,
       range_end,
       is_compressed,
       pg_size_pretty(total_bytes) as total_size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'measurements'
ORDER BY range_start DESC"

puts chunk_analysis_query

puts "\nOptimization Best Practices:"
puts "1. Time Bucket Selection:"
puts "   - Choose time buckets based on query patterns"
puts "   - Consider data retention requirements"
puts "   - Balance between granularity and performance"

puts "\n2. Continuous Aggregate Strategy:"
puts "   - Create aggregates for common time windows"
puts "   - Set refresh policies based on data update frequency"
puts "   - Use real-time aggregation when needed"

puts "\n3. Compression Configuration:"
puts "   - Compress older chunks for storage efficiency"
puts "   - Choose appropriate segmentby columns"
puts "   - Set orderby for query optimization"

puts "\n4. Partitioning Strategy:"
puts "   - Select chunk interval based on data volume"
puts "   - Use dimension partitioning for high-cardinality columns"
puts "   - Consider query patterns when setting intervals"

puts "\n5. Query Optimization:"
puts "   - Leverage time bucket functions"
puts "   - Use continuous aggregates for repeated queries"
puts "   - Implement efficient indexes"
puts "   - Consider parallel query execution"

puts "\nDone! You can now explore the TimescaleDB features interactively:"
puts "- Run queries on the measurements table"
puts "- Check continuous aggregates with Measurement::AvgTemperaturePerHour"
puts "- Explore chunk management with Measurement.chunks"
puts "- Monitor compression with Measurement.hypertable.compression_stats" 