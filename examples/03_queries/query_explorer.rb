require_relative '../../config/database'

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
      connection.execute(<<~SQL)
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        #{sql}
      SQL
    end

    private

    def connection
      ActiveRecord::Base.connection
    end
  end
end 