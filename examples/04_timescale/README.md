# TimescaleDB Workshop

This section focuses on understanding and leveraging TimescaleDB, a powerful time-series database extension for PostgreSQL, through practical examples using IoT sensor data scenarios.

## Introduction to Hypertables

Hypertables are the foundation of TimescaleDB's time-series optimization. They automatically partition your data into chunks based on time intervals, providing several benefits:

1. **Automatic Partitioning**
   - Time-based chunking for efficient data management
   - Transparent query optimization
   - Automatic chunk creation and management

2. **Query Performance**
   - Chunk exclusion for faster time-range queries
   - Parallel query execution across chunks
   - Optimized index usage per chunk

3. **Data Management**
   - Efficient compression of older data
   - Automated retention policies
   - Easy backup and maintenance

## Workshop Files

This workshop consists of the following files:

1. [`timescale_setup.rb`](timescale_setup.rb)
   - Sets up TimescaleDB extension and tables
   - Creates hypertables and continuous aggregates
   - Generates sample IoT sensor data
   - Implements compression and retention policies

2. [`practice_timescale.rb`](practice_timescale.rb)
   - Time-bucket query examples
   - Continuous aggregate demonstrations
   - Chunk management and compression
   - Query performance analysis

## Learning Path

### 1. Understanding TimescaleDB Fundamentals
Start with [`timescale_setup.rb`](timescale_setup.rb) to understand:
- Hypertable creation and configuration
- Continuous aggregate setup
- Compression policies
- Data retention strategies

### 2. TimescaleDB Features in Practice
Work through [`practice_timescale.rb`](practice_timescale.rb):
1. Execute time-bucket queries
2. Analyze query performance with EXPLAIN
3. Work with continuous aggregates
4. Manage chunks and compression
5. Implement advanced time-series analytics

## Key Features and Examples

### 1. Creating Hypertables
```ruby
class Measurement < ActiveRecord::Base
  acts_as_hypertable time_column: 'time',
    value_column: 'temperature',
    segment_by: 'device_id',
    chunk_time_interval: '1 day'
end
```

Key configuration options:
- `time_column`: Primary time dimension
- `segment_by`: Additional partitioning dimension
- `chunk_time_interval`: Time interval for chunks
- `compress_after`: When to compress older chunks

### 2. Continuous Aggregates
```ruby
continuous_aggregates scopes: [:avg_temperature],
  timeframes: [:hour, :day],
  refresh_policy: {
    hour: {
      start_offset: '3 hours',
      end_offset: '1 hour',
      schedule_interval: '1 hour'
    }
  }
```

Benefits:
- Pre-computed aggregates for faster queries
- Automatic refresh policies
- Materialized view-like functionality
- Efficient memory usage

### 3. Time-Bucket Queries
```ruby
# Basic time bucketing
Measurement.today.avg_temperature

# Advanced time series analytics
Measurement.where(time: 1.week.ago..Time.current)
  .avg_temperature
```

Features:
- Automatic chunk exclusion
- Parallel query execution
- Efficient index usage
- Time-based optimization

### 4. Compression and Retention
```ruby
# Compression configuration
hypertable_options = {
  compress_segmentby: 'device_id',
  compress_orderby: 'time DESC',
  compress_after: '7 days'
}

# Retention policy
SELECT add_retention_policy('measurements', INTERVAL '3 months');
```

Benefits:
- Significant storage savings
- Automated data lifecycle management
- Maintained query performance
- Efficient resource utilization

### 5. Compression Optimization
```ruby
# Compression Configuration
hypertable_options = {
  compress_segmentby: 'device_id',
  compress_orderby: 'time DESC',
  compress_after: '7 days'
}

# Compression Analysis
compression_stats = Measurement.hypertable.compression_stats
puts "Compression ratio: #{compression_stats.compression_ratio}%"
```

Performance Results:
- Table size reduction: 92.6% (5.3MB → 393KB)
- Index size reduction: 87.5% (3.1MB → 393KB)
- Overall space savings: 55.7% (8.6MB → 3.8MB)

Key Factors for Optimal Compression:
1. **Data Patterns**
   - Gradual changes in measurements (e.g., ±0.5°C temperature changes)
   - Consistent value ranges (e.g., 20-30°C for temperature)
   - Monotonic changes (e.g., battery level decreasing)

2. **Chunk Management**
   - Default chunk interval: 1 day
   - Compression threshold: 7 days
   - Automatic chunk creation and compression

3. **Optimization Strategies**
   - Segment by high-cardinality columns (device_id)
   - Order by time for efficient time-series queries
   - Balance between compression ratio and query performance

4. **Real-world Performance**
   - Higher compression ratios with larger datasets
   - Better pattern recognition at scale
   - Efficient handling of time-series characteristics

Example Configuration:
```ruby
def generate_sample_data(total: 10_000)
  # Initialize device states
  device_states = {
    'device1' => { temperature: 25.0, humidity: 50.0, battery: 100.0 },
    'device2' => { temperature: 25.0, humidity: 50.0, battery: 100.0 },
    'device3' => { temperature: 25.0, humidity: 50.0, battery: 100.0 }
  }
  
  # Generate data with small variations
  total.times.map do
    device = devices.sample
    state = device_states[device]
    
    # Small variations for better compression
    new_temp = state[:temperature] + rand(-0.5..0.5)
    new_humidity = state[:humidity] + rand(-1.0..1.0)
    new_battery = state[:battery] - rand(0.0..0.1)
    
    # Update state and return measurement
    device_states[device] = {
      temperature: new_temp,
      humidity: new_humidity,
      battery: new_battery
    }
    
    { time: time, device_id: device, ... }
  end
end
```

Best Practices:
1. **Data Generation**
   - Use realistic value ranges
   - Implement gradual changes
   - Maintain data patterns per device
   - Consider seasonal or cyclic patterns

2. **Compression Settings**
   - Choose appropriate segment columns
   - Set optimal compression threshold
   - Monitor compression ratios
   - Balance with query needs

3. **Performance Monitoring**
   - Track compression ratios
   - Monitor chunk statistics
   - Analyze query performance
   - Adjust settings as needed

### 6. Refresh Strategy Optimization
```sql
-- Refresh Policy Analysis
SELECT view_name,
       refresh_interval,
       start_offset,
       end_offset
FROM timescaledb_information.continuous_aggregate_policies

-- Manual Refresh
CALL refresh_continuous_aggregate('avg_temperature_per_hour', NULL, NULL);
```

Considerations:
- Real-time vs. batch updates
- Resource utilization
- Data freshness requirements
- Query performance impact

### 7. Chunk Management
```sql
-- Chunk Analysis
SELECT chunk_schema || '.' || chunk_name as chunk_full_name,
       range_start,
       range_end,
       is_compressed,
       pg_size_pretty(total_bytes) as total_size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'measurements'
```

Optimization Areas:
- Chunk interval selection
- Compression timing
- Retention policies
- Space management

## Performance Tuning Guidelines

### 1. Time Bucket Selection
- Match common query intervals
- Consider data retention needs
- Balance storage vs. query speed

### 2. Compression Strategy
- Compress older chunks
- Choose effective segment columns
- Monitor compression ratios
- Optimize compression timing

### 3. Continuous Aggregate Design
- Identify common aggregations
- Set appropriate refresh intervals
- Use real-time aggregation when needed
- Monitor refresh performance

### 4. Query Optimization
- Leverage chunk exclusion
- Use appropriate indexes
- Implement efficient partitioning
- Monitor query patterns

### 5. Resource Management
- Balance memory usage
- Monitor disk space
- Optimize parallel execution
- Manage background workers

## Best Practices

### 1. Data Model Design
- Choose appropriate time columns
- Select effective segmentation columns
- Plan compression strategies
- Design efficient indexes

### 2. Query Patterns
- Use time-bucket functions effectively
- Leverage continuous aggregates
- Implement proper retention policies
- Monitor and optimize query performance

### 3. Maintenance
- Regular compression checks
- Continuous aggregate refresh monitoring
- Performance metric tracking
- Capacity planning

## Common Use Cases

### 1. IoT and Sensor Data
- High-frequency data collection
- Real-time analytics
- Historical trend analysis
- Device-specific queries

### 2. Monitoring and Metrics
- System performance data
- Application metrics
- User activity logs
- Resource utilization tracking

### 3. Financial Data
- Time-series market data
- Trading analytics
- Performance metrics
- Historical analysis

## Troubleshooting Guide

### Common Issues

1. **Query Performance**
   - Check chunk interval size
   - Verify continuous aggregate usage
   - Monitor compression status
   - Analyze query patterns

2. **Resource Usage**
   - Review chunk size
   - Check compression settings
   - Monitor aggregate refreshes
   - Optimize memory configuration

3. **Data Management**
   - Implement retention policies
   - Monitor compression ratios
   - Track chunk growth
   - Plan capacity needs

## Additional Resources

1. [TimescaleDB Documentation](https://docs.timescale.com/)
2. [Continuous Aggregates Guide](https://docs.timescale.com/use-timescale/latest/continuous-aggregates/about-continuous-aggregates/)
3. [Compression Documentation](https://docs.timescale.com/use-timescale/latest/compression/about-compression/)
4. [Query Optimization Tips](https://docs.timescale.com/use-timescale/latest/query-data/query-optimization/) 