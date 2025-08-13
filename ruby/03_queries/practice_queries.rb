require_relative '../../config/database'
require_relative './query_explorer'

# Create sample data
unless Customer.exists?
  # Create customers
  5.times do |i|
    customer = Customer.create!(
      name: "Customer #{i}",
      country: ["USA", "Canada", "UK", "Brazil", "Japan"][i]
    )

    # Create orders for each customer
    3.times do |j|
      order = customer.orders.create!
      
      # Create line items for each order
      2.times do |k|
        order.line_items.create!(
          product_name: "Product #{k}",
          quantity: rand(1..5),
          price: rand(10.0..100.0).round(2)
        )
      end
    end
  end
end

puts "\n=== Basic Query Example ==="
# Example complex query for optimization
orders = Order.joins(:line_items, :customer)
  .where(created_at: 1.month.ago..Time.current)
  .group('customers.country')
  .select('customers.country,
          COUNT(DISTINCT orders.id) as order_count,
          SUM(line_items.quantity * line_items.price) as revenue')

puts "Analyzing query execution plan:"
puts QueryExplorer.analyze_query(orders.to_sql).to_a

puts "\n=== Memory/Disk Usage Example ==="
puts "This example demonstrates how PostgreSQL handles queries when memory is constrained."
puts "We'll:"
puts "1. Set work_mem to 64kB (very low) to force disk usage"
puts "2. Create a large dataset (~100k line items)"
puts "3. Run a complex query that requires sorting and aggregation"
puts "4. Analyze the execution plan to see disk operations\n"

# Create a larger dataset to force disk usage
unless Customer.count > 1000
  start_time = Time.now
  total_customers = 100
  orders_per_customer = 20
  items_per_order = 50
  total_line_items = total_customers * orders_per_customer * items_per_order
  
  puts "Creating dataset:"
  puts "- #{total_customers} customers"
  puts "- #{total_customers * orders_per_customer} orders"
  puts "- #{total_line_items} line items"
  puts "- Estimated total rows: #{total_line_items + total_customers * orders_per_customer + total_customers}"
  puts "\nThis may take a few minutes. Data will be inserted in batches of 10,000 records..."
  
  # Set a lower work_mem to force disk usage
  ActiveRecord::Base.connection.execute("SET work_mem = '64kB'")
  
  ActiveRecord::Base.transaction do
    # Create customers in batches
    customers_data = []
    100.times do |i|
      customers_data << {
        name: "Large Customer #{i}",
        country: ["USA", "Canada", "UK", "Brazil", "Japan"][i % 5],
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    puts "\nInserting customers..."
    Customer.insert_all(customers_data)
    
    # Create orders and line items in batches
    Customer.find_each do |customer|
      puts "Processing orders for customer #{customer.id}... (#{(customer.id * 100.0 / total_customers).round(1)}% complete)"
      
      orders_data = []
      20.times do |j|
        orders_data << {
          customer_id: customer.id,
          created_at: rand(1.year.ago..Time.current),
          updated_at: Time.current
        }
      end
      
      # Insert orders batch
      inserted_orders = Order.insert_all(orders_data)
      order_ids = Order.where(customer_id: customer.id).pluck(:id)
      
      # Create line items in batches of 10k
      line_items_data = []
      order_ids.each do |order_id|
        50.times do |k|
          line_items_data << {
            order_id: order_id,
            product_name: "Product #{k}",
            quantity: rand(1..10),
            price: rand(10.0..1000.0).round(2),
            created_at: Time.current,
            updated_at: Time.current
          }
          
          # Insert batch when it reaches 10k records
          if line_items_data.size >= 10_000
            LineItem.insert_all(line_items_data)
            line_items_data = []
          end
        end
      end
      
      # Insert remaining line items
      LineItem.insert_all(line_items_data) if line_items_data.any?
    end
  end
  
  end_time = Time.now
  duration = (end_time - start_time).round(2)
  
  puts "\nDataset creation completed in #{duration} seconds"
  puts "Final record counts:"
  puts "- Customers: #{Customer.count}"
  puts "- Orders: #{Order.count}"
  puts "- Line Items: #{LineItem.count}"
end

# Complex query that will require disk usage
puts "\nExecuting memory-intensive query..."
puts "This query will:"
puts "1. Join multiple large tables"
puts "2. Perform complex aggregations"
puts "3. Use string aggregation (memory intensive)"
puts "4. Group by multiple columns"
puts "5. Sort results"
puts "\nWatch for 'temp read/written' and 'Disk:' in the execution plan to see disk operations."

large_query = Order.joins(:line_items, :customer)
  .select('customers.country,
           DATE_TRUNC(\'month\', orders.created_at) as month,
           COUNT(DISTINCT orders.id) as order_count,
           SUM(line_items.quantity * line_items.price) as revenue,
           AVG(line_items.quantity * line_items.price) as avg_order_value,
           STRING_AGG(DISTINCT customers.name, \', \') as customer_names')
  .where(created_at: 1.year.ago..Time.current)
  .group('customers.country, DATE_TRUNC(\'month\', orders.created_at)')
  .having('COUNT(DISTINCT orders.id) > 5')
  .order('customers.country, month')

puts "\nAnalyzing query execution plan with disk usage:"
puts QueryExplorer.analyze_query(large_query.to_sql).to_a

# Reset work_mem to default
ActiveRecord::Base.connection.execute("RESET work_mem") 