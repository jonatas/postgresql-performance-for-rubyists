require_relative '../../config/database'
require_relative './query_explorer'
require_relative './query_optimization_lab'

class AdvancedQueries
  class << self
    def window_function_examples
      puts "\n=== Window Function Examples ==="

      # Example 1: Row number per customer's orders
      query1 = Order.select(
        'orders.*, customers.name,
         ROW_NUMBER() OVER (PARTITION BY orders.customer_id ORDER BY orders.created_at) as order_sequence'
      ).joins(:customer)
      
      puts "\nQuery 1 - Row numbers for customer orders:"
      query1.to_a  # Execute the query
      puts QueryExplorer.analyze_query(query1.to_sql)

      # Example 2: Running total of order amounts
      query2 = Order.joins(:line_items)
        .select(
          'orders.*, 
           SUM(line_items.quantity * line_items.price) OVER (PARTITION BY orders.customer_id ORDER BY orders.created_at) as running_total'
        )
      
      puts "\nQuery 2 - Running totals:"
      query2.to_a  # Execute the query
      puts QueryExplorer.analyze_query(query2.to_sql)
    end

    def complex_aggregation_examples
      puts "\n=== Complex Aggregation Examples ==="

      # Example 1: Customer order statistics with multiple aggregations
      query1 = Order.joins(:customer, :line_items)
        .group('customers.id, customers.name')
        .select(
          'customers.name,
           COUNT(DISTINCT orders.id) as total_orders,
           AVG(line_items.quantity * line_items.price) as avg_order_value,
           MAX(line_items.quantity * line_items.price) as highest_order_value'
        )
      
      puts "\nQuery 1 - Customer statistics:"
      query1.to_a  # Execute the query
      puts QueryExplorer.analyze_query(query1.to_sql)

      # Example 2: Time-based aggregation
      query2 = Order.joins(:line_items)
        .group("DATE_TRUNC('month', orders.created_at)")
        .select(
          "DATE_TRUNC('month', orders.created_at) as month,
           COUNT(DISTINCT orders.id) as order_count,
           SUM(line_items.quantity * line_items.price) as monthly_revenue"
        )
      
      puts "\nQuery 2 - Monthly statistics:"
      query2.to_a  # Execute the query
      puts QueryExplorer.analyze_query(query2.to_sql)
    end

    def recursive_cte_example
      puts "\n=== Recursive CTE Example ==="

      # Example: Finding order chains (orders made within 7 days of each other by the same customer)
      query = <<-SQL
        WITH RECURSIVE order_chain AS (
          -- Base case: first order
          SELECT o.id, o.customer_id, o.created_at, 1 as chain_length
          FROM orders o
          JOIN customers c ON c.id = o.customer_id
          WHERE c.country = 'USA'
          
          UNION ALL
          
          -- Recursive case: subsequent orders within 7 days
          SELECT o.id, o.customer_id, o.created_at, oc.chain_length + 1
          FROM orders o
          INNER JOIN order_chain oc ON o.customer_id = oc.customer_id
          WHERE o.created_at BETWEEN oc.created_at AND oc.created_at + INTERVAL '7 days'
          AND o.id > oc.id
        )
        SELECT customer_id, MAX(chain_length) as longest_chain
        FROM order_chain
        GROUP BY customer_id
        HAVING MAX(chain_length) > 1
      SQL

      puts "\nQuery - Finding order chains:"
      connection.execute(query)  # Execute the query
      puts QueryExplorer.analyze_query(query)
    end

    def lateral_join_example
      puts "\n=== LATERAL JOIN Example ==="

      # Example: For each customer, find their top 3 highest-value orders
      query = <<-SQL
        SELECT c.name, c.country, o.*
        FROM customers c
        CROSS JOIN LATERAL (
          SELECT o.id, o.created_at,
                 SUM(li.quantity * li.price) as order_total
          FROM orders o
          JOIN line_items li ON li.order_id = o.id
          WHERE o.customer_id = c.id
          GROUP BY o.id, o.created_at
          ORDER BY order_total DESC
          LIMIT 3
        ) o
      SQL

      puts "\nQuery - Top 3 orders per customer:"
      connection.execute(query)  # Execute the query
      puts QueryExplorer.analyze_query(query)
    end

    private

    def connection
      ActiveRecord::Base.connection
    end
  end
end

# Run the examples
if __FILE__ == $0
  QueryOptimizationLab.setup_sample_data
  AdvancedQueries.window_function_examples
  AdvancedQueries.complex_aggregation_examples
  AdvancedQueries.recursive_cte_example
  AdvancedQueries.lateral_join_example
end 