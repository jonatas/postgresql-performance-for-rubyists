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

# Check if database URL is provided
unless ARGV.last
  puts "Usage: ruby #{$0} postgres://user:pass@host:port/db_name"
  puts "or set DATABASE_URL in your environment"
  exit 1
end

# Connect to database using command line argument
ActiveRecord::Base.establish_connection(ARGV.last || ENV['DATABASE_URL'])

puts "\n=== TimescaleDB Practice Examples ==="
class Measurement < ActiveRecord::Base
    extend Timescaledb::ContinuousAggregatesHypertable
    include Timescaledb::ActsAsHypertable
    acts_as_hypertable time_column: 'time',
      value_column: 'temperature',
      segment_by: 'device_id'

    scope :avg_temperature, -> { select('avg(temperature) as temperature').group('device_id') }
    continuous_aggregate scopes: [:avg_temperature],
      timeframes: [:minute, :hour, :day]

end

ActiveRecord::Base.logger = Logger.new(STDOUT)
# 1. Getting started with basic time-bucket queries
puts "\n1. Going to Raw data with average temperature by hour for the last day:"
pp Measurement.avg_temperature.last_day.map(&:attributes)
# 2. Let's look at explain analyze
pp Measurement.avg_temperature.last_day.explain_analyze

# Refresh continuous aggregates
Measurement.refresh_aggregates
# 3. Using continuous aggregates
puts "\n3. Using continuous aggregates - Daily averages:"
pp Measurement::AvgTemperaturePerDay.last_week.map(&:attributes)


# 4. Working with chunks
puts "\n4. Chunk information:"
puts "Total chunks: #{Measurement.chunks.count}"
puts "Compressed chunks: #{Measurement.chunks.compressed.count}"
puts "Uncompressed chunks: #{Measurement.chunks.uncompressed.count}"

# 4. Advanced time-series analytics
puts "\n4. Moving average of temperature:"
result = ActiveRecord::Base.connection.execute(<<~SQL)
  SELECT time_bucket('1 hour', time) AS hour,
         device_id,
         avg(temperature) as avg_temp,
         avg(temperature) OVER (
           PARTITION BY device_id
           ORDER BY time_bucket('1 hour', time)
           ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
         ) as moving_avg_temp
  FROM measurements
  WHERE time > NOW() - INTERVAL '1 day'
  GROUP BY hour, device_id
  ORDER BY hour DESC, device_id
  LIMIT 10;
SQL
pp result.to_a

# 5. Retention policy example
puts "\n5. Data retention policy:"
puts "To set up a retention policy, you would execute:"
puts "SELECT add_retention_policy('measurements', INTERVAL '3 months');"

# 6. Compression policy status
puts "\n6. Compression policy status:"
result = ActiveRecord::Base.connection.execute(<<~SQL)
  SELECT * FROM timescaledb_information.compression_settings
  WHERE hypertable_name = 'measurements';
SQL
pp result.to_a

puts "\nDone! You can now explore the TimescaleDB features interactively:"
puts "- Run queries on the measurements table"
puts "- Check continuous aggregates with Measurement::AvgTemperaturePerHour"
puts "- Explore chunk management with Measurement.chunks"
puts "- Monitor compression with Measurement.hypertable.compression_stats" 