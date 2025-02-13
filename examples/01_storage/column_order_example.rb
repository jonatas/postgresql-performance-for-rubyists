require 'active_record'
require 'pg'
require 'benchmark'
require_relative '../../config/database'

class StorageAnalyzer

  def self.create_test_tables
    ActiveRecord::Schema.define do
      # Poor column ordering (worst possible alignment scenario)
      create_table :employees_unoptimized, force: true do |t|
        t.boolean :flag1              # 1 byte
        t.decimal :value1, precision: 15, scale: 2  # 8 bytes
        t.string :code1, limit: 1     # 1 byte
        t.float :score1              # 8 bytes (double)
        t.boolean :flag2             # 1 byte
        t.decimal :value2, precision: 15, scale: 2  # 8 bytes
        t.integer :tiny1, limit: 1    # 1 byte
        t.float :score2              # 8 bytes
        t.string :code2, limit: 1     # 1 byte
        t.decimal :value3, precision: 15, scale: 2  # 8 bytes
        t.boolean :flag3             # 1 byte
        t.float :score3              # 8 bytes
        t.integer :tiny2, limit: 1    # 1 byte
        t.decimal :value4, precision: 15, scale: 2  # 8 bytes
        t.string :code3, limit: 1     # 1 byte
        t.float :score4              # 8 bytes
        t.boolean :flag4             # 1 byte
        t.decimal :value5, precision: 15, scale: 2  # 8 bytes
        t.integer :tiny3, limit: 1    # 1 byte
        t.float :score5              # 8 bytes
        t.string :code4, limit: 1     # 1 byte
        t.decimal :value6, precision: 15, scale: 2  # 8 bytes
        t.boolean :flag5             # 1 byte
        t.float :score6              # 8 bytes
        t.integer :tiny4, limit: 1    # 1 byte
        t.decimal :value7, precision: 15, scale: 2  # 8 bytes
        t.string :code5, limit: 1     # 1 byte
        t.float :score7              # 8 bytes
        t.boolean :flag6             # 1 byte
        t.decimal :value8, precision: 15, scale: 2  # 8 bytes
      end

      # Optimized column ordering (perfect alignment)
      create_table :employees_optimized, force: true do |t|
        # 8-byte aligned columns together (doubles and decimals)
        t.decimal :value1, precision: 15, scale: 2
        t.decimal :value2, precision: 15, scale: 2
        t.decimal :value3, precision: 15, scale: 2
        t.decimal :value4, precision: 15, scale: 2
        t.decimal :value5, precision: 15, scale: 2
        t.decimal :value6, precision: 15, scale: 2
        t.decimal :value7, precision: 15, scale: 2
        t.decimal :value8, precision: 15, scale: 2
        t.float :score1
        t.float :score2
        t.float :score3
        t.float :score4
        t.float :score5
        t.float :score6
        t.float :score7
        # All 1-byte columns together (perfect packing)
        t.boolean :flag1
        t.boolean :flag2
        t.boolean :flag3
        t.boolean :flag4
        t.boolean :flag5
        t.boolean :flag6
        t.integer :tiny1, limit: 1
        t.integer :tiny2, limit: 1
        t.integer :tiny3, limit: 1
        t.integer :tiny4, limit: 1
        t.string :code1, limit: 1
        t.string :code2, limit: 1
        t.string :code3, limit: 1
        t.string :code4, limit: 1
        t.string :code5, limit: 1
      end
    end
  end

  def self.analyze_storage
    puts "Analyzing storage impact of column ordering..."
    puts "\nGenerating test data..."

    # Generate test data with values that force maximum storage
    test_data = 100_000.times.map do |i|
      {
        # Force all decimals to use full precision
        value1: 9999999.99 - (i * 0.01),
        value2: 8888888.88 - (i * 0.02),
        value3: 7777777.77 - (i * 0.03),
        value4: 6666666.66 - (i * 0.04),
        value5: 5555555.55 - (i * 0.05),
        value6: 4444444.44 - (i * 0.06),
        value7: 3333333.33 - (i * 0.07),
        value8: 2222222.22 - (i * 0.08),
        
        # Force floats to use full double precision
        score1: Math.sin(i) * 1000000.0,
        score2: Math.cos(i) * 1000000.0,
        score3: Math.tan(i) * 1000000.0,
        score4: Math.sin(i * 2) * 1000000.0,
        score5: Math.cos(i * 2) * 1000000.0,
        score6: Math.sin(i * 3) * 1000000.0,
        score7: Math.cos(i * 3) * 1000000.0,
        
        # Single byte values
        flag1: i % 2 == 0,
        flag2: i % 3 == 0,
        flag3: i % 4 == 0,
        flag4: i % 5 == 0,
        flag5: i % 6 == 0,
        flag6: i % 7 == 0,
        
        tiny1: i % 127,
        tiny2: (i + 31) % 127,
        tiny3: (i + 67) % 127,
        tiny4: (i + 89) % 127,
        
        code1: ((i % 26) + 65).chr,
        code2: ((i % 26) + 66).chr,
        code3: ((i % 26) + 67).chr,
        code4: ((i % 26) + 68).chr,
        code5: ((i % 26) + 69).chr
      }
    end

    # Insert into both tables
    ActiveRecord::Base.connection.execute("TRUNCATE employees_unoptimized, employees_optimized")
    
    puts "\nInserting data into unoptimized table..."
    UnoptimizedEmployee.insert_all!(test_data)
    
    puts "Inserting data into optimized table..."
    OptimizedEmployee.insert_all!(test_data)

    # Vacuum and analyze tables
    puts "\nVacuuming tables to optimize storage..."
    ActiveRecord::Base.connection.execute("VACUUM FULL employees_unoptimized")
    ActiveRecord::Base.connection.execute("VACUUM FULL employees_optimized")
    ActiveRecord::Base.connection.execute("ANALYZE employees_unoptimized, employees_optimized")

    # Get storage sizes
    unopt_size = get_table_size('employees_unoptimized')
    opt_size = get_table_size('employees_optimized')
    
    puts "\nStorage Analysis Results:"
    puts "----------------------------------------"
    puts "Unoptimized table size: #{format_bytes(unopt_size)}"
    puts "Optimized table size:   #{format_bytes(opt_size)}"
    puts "Storage saved:          #{format_bytes(unopt_size - opt_size)}"
    puts "Percentage saved:       #{((unopt_size - opt_size).to_f / unopt_size * 100).round(2)}%"
    
    # Analyze tuple sizes
    analyze_tuple_sizes
  end

  def self.analyze_tuple_sizes
    puts "\nAnalyzing individual tuple sizes..."
    puts "----------------------------------------"
    
    # Enhanced analysis query
    query = <<-SQL
      SELECT 
        avg(pg_column_size(t.*)) as avg_size,
        min(pg_column_size(t.*)) as min_size,
        max(pg_column_size(t.*)) as max_size,
        pg_size_pretty(sum(pg_column_size(t.*))) as total_raw_size,
        pg_size_pretty(pg_total_relation_size('%s')) as total_size_with_indexes,
        pg_size_pretty(pg_relation_size('%s')) as main_fork_size,
        pg_size_pretty(pg_total_relation_size('%s') - pg_relation_size('%s')) as index_size,
        pg_size_pretty((SELECT pg_total_relation_size(reltoastrelid) 
                       FROM pg_class WHERE relname = '%s')) as toast_size
      FROM %s t;
    SQL

    ['employees_unoptimized', 'employees_optimized'].each do |table|
      result = ActiveRecord::Base.connection.execute(
        sprintf(query, table, table, table, table, table, table)
      ).first
      
      puts "\n#{table.gsub('_', ' ').capitalize}:"
      puts "Average tuple size: #{result['avg_size'].to_i} bytes"
      puts "Minimum tuple size: #{result['min_size'].to_i} bytes"
      puts "Maximum tuple size: #{result['max_size'].to_i} bytes"
      puts "Total raw data size: #{result['total_raw_size']}"
      puts "Main fork size: #{result['main_fork_size']}"
      puts "TOAST size: #{result['toast_size']}"
      puts "Index size: #{result['index_size']}"
      puts "Total size with indexes: #{result['total_size_with_indexes']}"
    end

    # Add detailed column analysis
    puts "\nColumn-by-column Analysis (sorted by optimization impact)..."
    puts "--------------------------------------------------------------------------------"
    puts "Column Name            | Unoptimized               | Optimized                 | Bytes Saved"
    puts "--------------------------------------------------------------------------------"
    
    # Define column size query
    column_query = <<-SQL
      SELECT a.attname as column_name,
             pg_size_pretty(SUM(pg_column_size(
               CASE WHEN a.attname = '%s' THEN t.%s END
             ))) as total_size,
             AVG(pg_column_size(
               CASE WHEN a.attname = '%s' THEN t.%s END
             )) as avg_size
      FROM %s t
      CROSS JOIN (
        SELECT attname 
        FROM pg_attribute 
        WHERE attrelid = '%s'::regclass 
        AND attnum > 0 
        AND NOT attisdropped
      ) a
      GROUP BY a.attname
      ORDER BY avg_size DESC NULLS LAST;
    SQL
    
    # Get column data for both tables
    columns_data = {}
    ['employees_unoptimized', 'employees_optimized'].each do |table|
      columns_query = <<-SQL
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = '#{table}'
      SQL
      
      columns = ActiveRecord::Base.connection.execute(columns_query).map { |row| row['column_name'] }
      
      table_data = {}
      columns.each do |column|
        result = ActiveRecord::Base.connection.execute(
          sprintf(column_query, column, column, column, column, table, table)
        ).first
        
        next if result['avg_size'].nil?
        table_data[column] = {
          'avg_size' => result['avg_size'].to_i,
          'total_size' => result['total_size']
        }
      end
      columns_data[table] = table_data
    end

    # Calculate differences and sort by optimization impact
    comparison = columns_data['employees_unoptimized'].map do |column, unopt_data|
      opt_data = columns_data['employees_optimized'][column]
      difference = unopt_data['avg_size'] - opt_data['avg_size']
      {
        'column' => column,
        'unopt' => unopt_data,
        'opt' => opt_data,
        'difference' => difference
      }
    end

    comparison.sort_by { |item| -item['difference'].abs }.each do |item|
      column = item['column'].ljust(20)
      unopt = "avg: #{item['unopt']['avg_size']} bytes | #{item['unopt']['total_size']}".ljust(24)
      opt = "avg: #{item['opt']['avg_size']} bytes | #{item['opt']['total_size']}".ljust(24)
      diff = item['difference']
      
      diff_str = if diff != 0
        diff > 0 ? "#{diff} bytes saved" : "#{-diff} bytes increased"
      else
        "no change"
      end
      
      puts "#{column} | #{unopt} | #{opt} | #{diff_str}"
    end
  end

  private

  def self.get_table_size(table_name)
    result = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT 
        pg_total_relation_size('#{table_name}') as total_size,
        pg_relation_size('#{table_name}') as main_size,
        (SELECT pg_total_relation_size(reltoastrelid) 
         FROM pg_class WHERE relname = '#{table_name}') as toast_size
    SQL
    result.first['total_size'].to_i
  end

  def self.format_bytes(bytes)
    mb = bytes.to_f / (1024 * 1024)
    if mb >= 1
      return "#{mb.round(2)} MB"
    else
      return "#{(bytes.to_f / 1024).round(2)} KB"
    end
  end
end

# Model definitions for our test tables
class UnoptimizedEmployee < ActiveRecord::Base
  self.table_name = 'employees_unoptimized'
end

class OptimizedEmployee < ActiveRecord::Base
  self.table_name = 'employees_optimized'
end

# Run the example
if __FILE__ == $0
  StorageAnalyzer.create_test_tables
  StorageAnalyzer.analyze_storage
end 