require_relative '../../config/database'
require_relative './query_explorer'

class QueryOptimizationLab
  class << self
    def setup_sample_data
      cleanup_tables
      create_sample_data
      create_indexes
    end

    def exercise_1_basic_query_analysis
      # Exercise 1: Analyze a simple query with different conditions
      puts "\n=== Exercise 1: Basic Query Analysis ==="
      
      # Query 1: Simple WHERE clause
      query1 = Customer.where(country: 'USA').to_sql
      puts "\nQuery 1 - Simple WHERE:"
      puts QueryExplorer.analyze_query(query1)

      # Query 2: Same query with OR condition
      query2 = Customer.where(country: ['USA', 'Canada']).to_sql
      puts "\nQuery 2 - OR condition:"
      puts QueryExplorer.analyze_query(query2)
    end

    def exercise_2_join_optimization
      puts "\n=== Exercise 2: JOIN Optimization ==="
      
      # Query 1: Simple JOIN
      query1 = Order.joins(:customer)
        .where(customers: { country: 'USA' })
        .to_sql
      puts "\nQuery 1 - Simple JOIN:"
      puts QueryExplorer.analyze_query(query1)

      # Query 2: Multiple JOINs
      query2 = Order.joins(:customer, :line_items)
        .where(customers: { country: 'USA' })
        .group('orders.id')
        .select('orders.*, COUNT(line_items.id) as items_count')
        .to_sql
      puts "\nQuery 2 - Multiple JOINs:"
      puts QueryExplorer.analyze_query(query2)
    end

    def exercise_3_aggregation_optimization
      puts "\n=== Exercise 3: Aggregation Optimization ==="
      
      # Query 1: Simple aggregation
      query1 = Order.group(:customer_id)
        .select('customer_id, COUNT(*) as order_count')
        .to_sql
      puts "\nQuery 1 - Simple aggregation:"
      puts QueryExplorer.analyze_query(query1)

      # Query 2: Complex aggregation with conditions
      query2 = Order.joins(:line_items)
        .group(:customer_id)
        .having('SUM(line_items.quantity * line_items.price) > ?', 1000)
        .select('customer_id, 
                COUNT(DISTINCT orders.id) as order_count,
                SUM(line_items.quantity * line_items.price) as total_revenue')
        .to_sql
      puts "\nQuery 2 - Complex aggregation:"
      puts QueryExplorer.analyze_query(query2)
    end

    def exercise_4_subquery_optimization
      puts "\n=== Exercise 4: Subquery Optimization ==="
      
      # Query 1: Subquery in WHERE
      query1 = Customer.where(
        id: Order.select(:customer_id)
          .joins(:line_items)
          .group(:customer_id)
          .having('COUNT(*) > ?', 5)
      ).to_sql
      puts "\nQuery 1 - Subquery in WHERE:"
      puts QueryExplorer.analyze_query(query1)

      # Query 2: Same query with JOIN
      query2 = Customer.joins(:orders)
        .group('customers.id')
        .having('COUNT(orders.id) > ?', 5)
        .to_sql
      puts "\nQuery 2 - Using JOIN instead:"
      puts QueryExplorer.analyze_query(query2)
    end

    private

    def cleanup_tables
      LineItem.delete_all
      Order.delete_all
      Customer.delete_all
    end

    def create_sample_data
      # Create customers with different countries
      countries = ["USA", "Canada", "UK", "Brazil", "Japan"]
      50.times do |i|
        customer = Customer.create!(
          name: "Customer #{i}",
          country: countries[i % countries.length],
          created_at: rand(1.year.ago..Time.current)
        )

        # Create varying numbers of orders per customer
        rand(5..15).times do |j|
          order = customer.orders.create!(
            created_at: rand(6.months.ago..Time.current)
          )
          
          # Create varying numbers of line items per order
          rand(2..8).times do |k|
            order.line_items.create!(
              product_name: "Product #{k}",
              quantity: rand(1..10),
              price: rand(10.0..1000.0).round(2),
              created_at: order.created_at + rand(1..24).hours
            )
          end
        end
      end

      puts "Created #{Customer.count} customers"
      puts "Created #{Order.count} orders"
      puts "Created #{LineItem.count} line items"
    end

    def create_indexes
      connection = ActiveRecord::Base.connection
      
      # Add indexes if they don't exist
      unless index_exists?(:customers, :country)
        connection.add_index :customers, :country
      end

      unless index_exists?(:orders, :customer_id)
        connection.add_index :orders, :customer_id
      end

      unless index_exists?(:orders, :created_at)
        connection.add_index :orders, :created_at
      end

      unless index_exists?(:line_items, :order_id)
        connection.add_index :line_items, :order_id
      end
    end

    def index_exists?(table, column)
      connection = ActiveRecord::Base.connection
      connection.index_exists?(table, column)
    end
  end
end

# Run the exercises
if __FILE__ == $0
  QueryOptimizationLab.setup_sample_data
  QueryOptimizationLab.exercise_1_basic_query_analysis
  QueryOptimizationLab.exercise_2_join_optimization
  QueryOptimizationLab.exercise_3_aggregation_optimization
  QueryOptimizationLab.exercise_4_subquery_optimization
end 