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

# Example complex query for optimization
orders = Order.joins(:line_items, :customer)
  .where(created_at: 1.month.ago..Time.current)
  .group('customers.country')
  .select('customers.country,
          COUNT(DISTINCT orders.id) as order_count,
          SUM(line_items.quantity * line_items.price) as revenue')

puts "Analyzing query execution plan:"
puts QueryExplorer.analyze_query(orders.to_sql).to_a 