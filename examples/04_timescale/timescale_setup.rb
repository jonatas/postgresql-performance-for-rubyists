require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'timescaledb', path: '../timescale-gem'
  gem 'pg'
  gem 'activerecord'
  gem 'pry'
  gem 'faker'
end

require 'timescaledb'
require 'active_record'
require 'pp'
require 'faker'

# Connect to database using command line argument
ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

# Define our IoT sensor measurement model
class Measurement < ActiveRecord::Base
  extend Timescaledb::ActsAsHypertable
  include Timescaledb::ContinuousAggregatesHelper

  acts_as_hypertable time_column: 'time',
    segment_by: 'device_id',
    value_column: 'temperature'

  scope :avg_temperature, -> { select('device_id, avg(temperature) as temperature').group('device_id') }
  scope :avg_humidity, -> { select('device_id, avg(humidity) as humidity').group('device_id') }
  scope :battery_stats, -> { select('device_id, min(battery_level) as min_battery, avg(battery_level) as battery_level').group('device_id') }

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

# Setup Hypertable (as you would in a migration)
ActiveRecord::Base.connection.instance_exec do
  # Enable logging
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  enable_extension('timescaledb')

  # Drop existing tables and aggregates
  Measurement.drop_continuous_aggregates rescue nil
  drop_table(:measurements, if_exists: true, cascade: true)

  # Create the measurements table as a hypertable
  hypertable_options = {
    time_column: 'time',
    chunk_time_interval: '1 day',
    compress_segmentby: 'device_id',
    compress_orderby: 'time DESC',
    compress_after: '7 days',
    # drop_after: '30 days' # Optional: delete chunks after 30 days
  }

  create_table(:measurements, id: false, hypertable: hypertable_options) do |t|
    t.timestamptz :time, null: false
    t.text :device_id, null: false
    t.float :temperature
    t.float :humidity
    t.float :battery_level
  end

  # Create continuous aggregates
  Measurement.create_continuous_aggregates
end

# Generate sample data
def generate_sample_data(total: 1000, time: 1.month.ago)
  devices = ['device1', 'device2', 'device3']
  
  # Initialize base values for each device
  device_states = devices.each_with_object({}) do |device, states|
    states[device] = {
      temperature: 25.0 + rand(-2.0..2.0),  # Start around 25°C with small variation
      humidity: 50.0 + rand(-5.0..5.0),     # Start around 50% with small variation
      battery_level: 100.0                   # Start with full battery
    }
  end
  
  total.times.map do
    time = time + rand(60).seconds
    device = devices.sample
    current_state = device_states[device]
    
    # Generate new values with small variations from previous values
    new_temp = current_state[:temperature] + rand(-0.5..0.5)  # Small temperature changes
    new_temp = [30.0, [20.0, new_temp].max].min              # Keep between 20-30°C
    
    new_humidity = current_state[:humidity] + rand(-1.0..1.0) # Small humidity changes
    new_humidity = [60.0, [40.0, new_humidity].max].min      # Keep between 40-60%
    
    new_battery = current_state[:battery_level] - rand(0.0..0.1) # Slow battery drain
    new_battery = [0.0, new_battery].max                         # Don't go below 0%
    
    # Update device state
    device_states[device] = {
      temperature: new_temp,
      humidity: new_humidity,
      battery_level: new_battery
    }
    
    # Return measurement
    {
      time: time,
      device_id: device,
      temperature: new_temp,
      humidity: new_humidity,
      battery_level: new_battery
    }
  end
end

# Insert sample data in batches
puts "Generating and inserting sample data..."
ActiveRecord::Base.logger = nil # Suppress logs during bulk insert
time = 1.month.ago
10.times do
  batch = generate_sample_data(total: 10_000, time: time)
  Measurement.insert_all(batch, returning: false)
  time = batch.last[:time] + 1.second
  print "."
end
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Refresh aggregates and show some example queries
puts "\nRefreshing continuous aggregates..."
Measurement.refresh_aggregates

puts "\nLast hour average temperature by device:"
pp Measurement.avg_temperature.last_hour.group(:device_id).map(&:attributes)

puts "\nCompressing old chunks..."
old_chunks = Measurement.chunks.where("range_end < ?", 7.days.ago)
old_chunks.each(&:compress!)

puts "\nHypertable size details:"
pp Measurement.hypertable.detailed_size

puts "\nCompression statistics:"
pp Measurement.hypertable.compression_stats 