require_relative '../../config/database'
require 'json'
require 'colorize'

class Customer < ActiveRecord::Base
  has_many :orders
end

class Order < ActiveRecord::Base
  belongs_to :customer
  has_many :line_items
end

class LineItem < ActiveRecord::Base
  belongs_to :order
end

# Create necessary tables if they don't exist
ActiveRecord::Base.connection.tap do |connection|
  unless connection.table_exists?('customers')
    connection.create_table :customers do |t|
      t.string :name
      t.string :country
      t.timestamps
    end
  end

  unless connection.table_exists?('orders')
    connection.create_table :orders do |t|
      t.references :customer
      t.decimal :total, precision: 10, scale: 2
      t.timestamps
    end
  end

  unless connection.table_exists?('line_items')
    connection.create_table :line_items do |t|
      t.references :order
      t.string :product_name
      t.integer :quantity
      t.decimal :price, precision: 10, scale: 2
      t.timestamps
    end
  end
end

class QueryExplorer
  class << self
    def analyze_query(sql)
      display_query(sql)
      
      begin
        # Get both TEXT and JSON format for different displays
        text_result = connection.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) #{sql}")
        json_result = connection.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) #{sql}")
        
        display_execution_plan(text_result)
        display_timing_stats(json_result)
        display_buffer_stats(json_result)
      rescue => e
        puts "\nError analyzing query: #{e.message}".colorize(:red)
        puts e.backtrace.first.colorize(:yellow)
      end
    end

    private

    def display_query(sql)
      puts "\n=== Query ===".colorize(:light_blue)
      formatted_sql = format_sql(sql)
      puts formatted_sql.colorize(:cyan)
    end

    def display_execution_plan(result)
      puts "\n=== Execution Plan ===".colorize(:light_blue)
      result.each do |row|
        # Split and indent nested plan steps
        plan_lines = row['QUERY PLAN'].to_s.lines.map do |line|
          indent = line[/^\s*/].length
          "  " * (indent / 2) + line.strip
        end
        puts plan_lines.join("\n").colorize(:cyan)
      end
    end

    def display_timing_stats(result)
      plan = result.first['QUERY PLAN'].first rescue nil
      return unless plan && plan['Planning Time'] && plan['Execution Time']

      puts "\n=== Timing Statistics ===".colorize(:light_blue)
      total_time = plan['Planning Time'] + plan['Execution Time']
      
      puts "Planning Time:  #{plan['Planning Time'].round(2)} ms (#{((plan['Planning Time'] / total_time) * 100).round(1)}%)".colorize(:yellow)
      puts "Execution Time: #{plan['Execution Time'].round(2)} ms (#{((plan['Execution Time'] / total_time) * 100).round(1)}%)".colorize(:yellow)
      puts "Total Time:     #{total_time.round(2)} ms".colorize(:light_blue)
    end

    def display_buffer_stats(result)
      plan = result.first['QUERY PLAN'].first['Plan'] rescue nil
      return unless plan && (plan['Shared Hit Blocks'] || plan['Shared Read Blocks'])

      puts "\n=== Buffer Usage ===".colorize(:light_blue)
      
      if plan['Shared Hit Blocks']
        puts "Cache Hits:   #{plan['Shared Hit Blocks']}".colorize(:yellow)
      end
      
      if plan['Shared Read Blocks']
        puts "Disk Reads:   #{plan['Shared Read Blocks']}".colorize(:yellow)
      end
      
      if plan['Shared Hit Blocks'] && plan['Shared Read Blocks']
        total = plan['Shared Hit Blocks'] + plan['Shared Read Blocks']
        hit_ratio = (plan['Shared Hit Blocks'].to_f / total * 100).round(1)
        color = hit_ratio >= 90 ? :green : :yellow
        puts "Cache Ratio:  #{hit_ratio}%".colorize(color)
      end
    end

    def format_sql(sql)
      # Enhanced SQL formatting with proper indentation
      formatted = sql.dup
      formatted.gsub!(/\s+/, ' ')
      
      # Add newlines before main SQL keywords
      keywords = %w(SELECT FROM WHERE GROUP\ BY HAVING ORDER\ BY LIMIT JOIN ON AND OR UNION\ ALL WITH RECURSIVE)
      pattern = /\b(#{keywords.join('|')})\b/i
      
      formatted = formatted.strip.gsub(pattern) do |match|
        "\n#{match.upcase}"
      end

      # Indent lines
      lines = formatted.lines.map(&:strip)
      base_indent = "  "
      indent_level = 0
      
      formatted_lines = lines.map do |line|
        if line.match?(/\b(FROM|WHERE|GROUP BY|HAVING|ORDER BY|LIMIT)\b/i)
          indent_level = 1
        elsif line.match?(/\b(JOIN|AND|OR|UNION ALL)\b/i)
          indent_level = 2
        end
        
        base_indent * indent_level + line
      end

      formatted_lines.join("\n") + "\n"
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end