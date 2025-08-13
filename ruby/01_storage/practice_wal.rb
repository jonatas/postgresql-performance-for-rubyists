require_relative '../../config/database'
require 'benchmark'
require 'securerandom'

class WalAnalyzer
  def self.measure_wal_generation
    initial_stats = collect_stats
    initial_lsn = current_wal_lsn
    
    time = Benchmark.measure do
      yield
    end
    
    final_lsn = current_wal_lsn
    final_stats = collect_stats
    
    bytes_generated = wal_lsn_diff(final_lsn, initial_lsn)
    stats_diff = calculate_stats_diff(initial_stats, final_stats)
    
    {
      wal_bytes: bytes_generated,
      execution_time: time.real,
      stats_diff: stats_diff,
      bytes_per_second: bytes_generated / time.real
    }
  end

  def self.analyze_checkpoints
    # Get pre-checkpoint statistics
    pre_stats = collect_stats
    
    start_time = Time.now
    ActiveRecord::Base.connection.execute("CHECKPOINT")
    duration = Time.now - start_time
    
    # Get post-checkpoint statistics
    post_stats = collect_stats
    stats_diff = calculate_stats_diff(pre_stats, post_stats)
    
    # Get current bgwriter stats
    bgwriter_stats = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT 
        stats_reset,
        buffers_clean,
        maxwritten_clean,
        buffers_alloc
      FROM pg_stat_bgwriter
    SQL

    {
      duration: duration,
      stats: bgwriter_stats,
      diff: stats_diff
    }
  end

  def self.current_settings
    ActiveRecord::Base.connection.execute(<<~SQL).to_a
      SELECT name, setting, unit, context, short_desc
      FROM pg_settings
      WHERE name LIKE '%wal%' 
         OR name LIKE '%checkpoint%'
         OR name IN ('synchronous_commit', 'commit_delay', 'commit_siblings')
      ORDER BY name;
    SQL
  end

  def self.test_wal_compression
    # Enable WAL compression
    ActiveRecord::Base.connection.execute("ALTER SYSTEM SET wal_compression = on")
    ActiveRecord::Base.connection.execute("SELECT pg_reload_conf()")
    
    puts "\nTesting WAL Compression Impact"
    puts "-" * 50
    puts "With WAL Compression ON:"
    
    # Test with compressible data
    result = measure_wal_generation do
      WalTestRecord.create!(
        name: "Compression Test",
        description: "A" * 1000,  # Highly compressible
        metadata: { data: "B" * 1000 }
      )
    end
    puts "\nCompressible Data:"
    puts format_stats(result)
    
    # Test with random data
    result = measure_wal_generation do
      WalTestRecord.create!(
        name: "Compression Test",
        description: SecureRandom.hex(500),  # Random data
        metadata: { data: SecureRandom.hex(500) }
      )
    end
    puts "\nRandom Data:"
    puts format_stats(result)
    
    # Disable WAL compression
    ActiveRecord::Base.connection.execute("ALTER SYSTEM SET wal_compression = off")
    ActiveRecord::Base.connection.execute("SELECT pg_reload_conf()")
  end

  def self.test_mixed_transactions
    puts "\nTesting Mixed Transaction Types"
    puts "-" * 50
    
    result = measure_wal_generation do
      # Complex transaction with different operation types
      ActiveRecord::Base.transaction do
        # Batch insert
        records = 50.times.map do |i|
          {
            name: "Mixed Tx Record #{i}",
            description: "Test #{i}",
            metadata: { index: i }
          }
        end
        WalTestRecord.insert_all!(records)
        
        # Individual updates with conditions
        WalTestRecord.where("metadata->>'index' < ?", 25)
          .update_all(description: "Updated in mixed transaction")
        
        # Delete with condition
        WalTestRecord.where("metadata->>'index' > ?", 40).delete_all
        
        # Individual inserts
        5.times do |i|
          WalTestRecord.create!(
            name: "Post-batch Record #{i}",
            description: "Added after batch",
            metadata: { type: "post-batch" }
          )
        end
      end
    end
    puts format_stats(result)
  end

  def self.test_toast_impact
    puts "\nTesting TOAST Impact on WAL"
    puts "-" * 50
    
    sizes = [1000, 2000, 4000, 8000]  # Test different sizes
    
    sizes.each do |size|
      puts "\nTesting with #{size} bytes:"
      result = measure_wal_generation do
        WalTestRecord.create!(
          name: "TOAST Test #{size}",
          description: "X" * size,
          metadata: { size: size }
        )
      end
      puts format_stats(result)
    end
  end

  def self.test_concurrent_operations
    puts "\nTesting Concurrent Operations Impact"
    puts "-" * 50
    
    # Prepare some data
    WalTestRecord.insert_all!(
      10.times.map do |i|
        {
          name: "Concurrent Test #{i}",
          description: "Initial state",
          metadata: { index: i },
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    )
    
    result = measure_wal_generation do
      # Simulate concurrent operations using threads
      threads = []
      
      threads << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          WalTestRecord.where("metadata->>'index' < ?", 5)
            .update_all(description: "Updated by thread 1")
        end
      end
      
      threads << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          WalTestRecord.where("metadata->>'index' >= ?", 5)
            .update_all(description: "Updated by thread 2")
        end
      end
      
      threads << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          5.times do |i|
            WalTestRecord.create!(
              name: "Thread Insert #{i}",
              description: "Created concurrently",
              metadata: { thread: 3 }
            )
          end
        end
      end
      
      threads.each(&:join)
    end
    puts format_stats(result)
  end

  private

  def self.collect_stats
    stats = {}
    
    # WAL statistics
    stats[:wal_lsn] = current_wal_lsn
    
    # Transaction statistics
    stats[:xact] = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT 
        xact_commit,
        xact_rollback,
        blks_read,
        blks_hit,
        tup_returned,
        tup_fetched,
        tup_inserted,
        tup_updated,
        tup_deleted
      FROM pg_stat_database 
      WHERE datname = current_database()
    SQL

    # Buffer statistics
    stats[:buffers] = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT * FROM pg_stat_bgwriter
    SQL

    stats
  end

  def self.calculate_stats_diff(before, after)
    {
      transactions: {
        committed: after[:xact]['xact_commit'] - before[:xact]['xact_commit'],
        rolled_back: after[:xact]['xact_rollback'] - before[:xact]['xact_rollback']
      },
      tuples: {
        returned: after[:xact]['tup_returned'] - before[:xact]['tup_returned'],
        fetched: after[:xact]['tup_fetched'] - before[:xact]['tup_fetched'],
        inserted: after[:xact]['tup_inserted'] - before[:xact]['tup_inserted'],
        updated: after[:xact]['tup_updated'] - before[:xact]['tup_updated'],
        deleted: after[:xact]['tup_deleted'] - before[:xact]['tup_deleted']
      },
      io: {
        blocks_read: after[:xact]['blks_read'] - before[:xact]['blks_read'],
        blocks_hit: after[:xact]['blks_hit'] - before[:xact]['blks_hit'],
        hit_ratio: calculate_hit_ratio(
          after[:xact]['blks_hit'] - before[:xact]['blks_hit'],
          after[:xact]['blks_read'] - before[:xact]['blks_read']
        )
      }
    }
  end

  def self.calculate_hit_ratio(hits, reads)
    total = hits + reads
    total > 0 ? (hits.to_f / total * 100).round(2) : 100.0
  end

  def self.current_wal_lsn
    ActiveRecord::Base.connection.execute("SELECT pg_current_wal_lsn()").first['pg_current_wal_lsn']
  end

  def self.wal_lsn_diff(lsn1, lsn2)
    ActiveRecord::Base.connection.execute(
      "SELECT pg_wal_lsn_diff(#{ActiveRecord::Base.connection.quote(lsn1)}, #{ActiveRecord::Base.connection.quote(lsn2)})"
    ).first['pg_wal_lsn_diff']
  end

  def self.format_bytes(bytes)
    if bytes > 1_048_576 # 1MB
      "#{(bytes.to_f / 1_048_576).round(2)} MB"
    elsif bytes > 1024
      "#{(bytes.to_f / 1024).round(2)} KB"
    else
      "#{bytes} bytes"
    end
  end

  def self.format_stats(result)
    output = []
    output << "WAL bytes generated: #{format_bytes(result[:wal_bytes])}"
    output << "Execution time: #{result[:execution_time].round(3)} seconds"
    output << "WAL generation rate: #{format_bytes(result[:bytes_per_second])}/second"
    output << "\nTransaction Statistics:"
    output << "- Committed: #{result[:stats_diff][:transactions][:committed]}"
    output << "- Rolled back: #{result[:stats_diff][:transactions][:rolled_back]}"
    output << "\nTuple Operations:"
    output << "- Inserted: #{result[:stats_diff][:tuples][:inserted]}"
    output << "- Updated: #{result[:stats_diff][:tuples][:updated]}"
    output << "- Deleted: #{result[:stats_diff][:tuples][:deleted]}"
    output << "- Returned: #{result[:stats_diff][:tuples][:returned]}"
    output << "- Fetched: #{result[:stats_diff][:tuples][:fetched]}"
    output << "\nI/O Statistics:"
    output << "- Blocks read: #{result[:stats_diff][:io][:blocks_read]}"
    output << "- Blocks hit: #{result[:stats_diff][:io][:blocks_hit]}"
    output << "- Cache hit ratio: #{result[:stats_diff][:io][:hit_ratio]}%"
    output.join("\n")
  end
end

class WalTestRecord < ActiveRecord::Base
  self.table_name = 'wal_test_records'
end

# Create test table
unless ActiveRecord::Base.connection.table_exists?('wal_test_records')
  ActiveRecord::Base.connection.create_table :wal_test_records do |t|
    t.string :name
    t.text :description
    t.jsonb :metadata
    t.timestamps
  end
end

puts "\nCurrent WAL and Checkpoint Settings:"
puts "-" * 50
WalAnalyzer.current_settings.each do |setting|
  puts "#{setting['name']}: #{setting['setting']}#{setting['unit']}"
  puts "  #{setting['short_desc']}" if setting['short_desc']
  puts "  Context: #{setting['context']}"
  puts
end

puts "\nScenario 1: Single Row Insert"
puts "-" * 50
result = WalAnalyzer.measure_wal_generation do
  WalTestRecord.create!(
    name: "Test Record",
    description: "Simple test",
    metadata: { type: "test" }
  )
end
puts WalAnalyzer.format_stats(result)

puts "\nScenario 2: Batch Insert (100 rows)"
puts "-" * 50
result = WalAnalyzer.measure_wal_generation do
  WalTestRecord.insert_all!(
    100.times.map do |i|
      {
        name: "Batch Record #{i}",
        description: "Part of batch insert test",
        metadata: { type: "batch", index: i },
        created_at: Time.current,
        updated_at: Time.current
      }
    end
  )
end
puts WalAnalyzer.format_stats(result)

puts "\nScenario 3: Large Update"
puts "-" * 50
result = WalAnalyzer.measure_wal_generation do
  WalTestRecord.update_all(description: "Updated " + "X" * 1000)
end
puts WalAnalyzer.format_stats(result)

puts "\nScenario 4: Delete Operation"
puts "-" * 50
result = WalAnalyzer.measure_wal_generation do
  WalTestRecord.delete_all
end
puts WalAnalyzer.format_stats(result)

puts "\nScenario 5: Transaction with Multiple Operations"
puts "-" * 50
result = WalAnalyzer.measure_wal_generation do
  ActiveRecord::Base.transaction do
    10.times do |i|
      WalTestRecord.create!(
        name: "Transaction Record #{i}",
        description: "Created in transaction",
        metadata: { type: "transaction", index: i }
      )
    end
    
    WalTestRecord.where("name LIKE ?", "%Transaction%").
      update_all(description: "Updated in transaction")
      
    WalTestRecord.where("name LIKE ?", "%Transaction Record 5%").
      delete_all
  end
end
puts WalAnalyzer.format_stats(result)

puts "\nAnalyzing Checkpoint Behavior"
puts "-" * 50
checkpoint_info = WalAnalyzer.analyze_checkpoints
puts "Checkpoint Statistics:"
puts "- Duration: #{checkpoint_info[:duration].round(3)} seconds"
puts "- Buffers cleaned: #{checkpoint_info[:stats]['buffers_clean']}"
puts "- Background writer stops: #{checkpoint_info[:stats]['maxwritten_clean']}"
puts "- Buffers allocated: #{checkpoint_info[:stats]['buffers_alloc']}"
puts "- Stats reset time: #{checkpoint_info[:stats]['stats_reset']}"

puts "\nPerformance Impact Analysis:"
puts "1. WAL Generation Patterns:"
puts "   - Single row operations: Small, predictable WAL volume"
puts "   - Batch operations: More efficient WAL usage per row"
puts "   - Large updates: Significant WAL volume due to full row images"
puts "   - Transactions: Reduced WAL overhead through grouping"

puts "\n2. I/O Patterns:"
puts "   - Cache hit ratios indicate buffer efficiency"
puts "   - Checkpoint timing shows I/O impact"
puts "   - Background writer behavior affects performance"

puts "\n3. Optimization Opportunities:"
puts "   - Group small operations into batches"
puts "   - Use appropriate transaction sizes"
puts "   - Monitor and tune checkpoint frequency"
puts "   - Consider WAL compression for write-heavy workloads"

# Add new test scenarios after the existing ones
puts "\n=== Advanced WAL Analysis Scenarios ==="

WalAnalyzer.test_wal_compression
WalAnalyzer.test_mixed_transactions
WalAnalyzer.test_toast_impact
WalAnalyzer.test_concurrent_operations

puts "\nAdvanced Performance Impact Analysis:"
puts "1. WAL Compression Impact:"
puts "   - Compressible data benefits more from WAL compression"
puts "   - Random data shows minimal compression benefit"
puts "   - Compression overhead vs. space savings trade-off"

puts "\n2. Transaction Complexity:"
puts "   - Mixed operations benefit from transaction grouping"
puts "   - Batch operations remain most efficient"
puts "   - Operation order can affect WAL size"

puts "\n3. TOAST Considerations:"
puts "   - WAL size increases with TOAST threshold crossings"
puts "   - TOAST operations generate additional WAL records"
puts "   - Large value updates have higher WAL impact"

puts "\n4. Concurrency Patterns:"
puts "   - Concurrent transactions generate more WAL"
puts "   - Lock contention can affect WAL generation"
puts "   - Transaction isolation level impacts WAL size"
