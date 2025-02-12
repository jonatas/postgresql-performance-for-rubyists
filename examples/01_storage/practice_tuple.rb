require_relative '../../config/database'
require_relative './storage_explorer'

class Employee < ActiveRecord::Base
end

# Create the employees table if it doesn't exist
ActiveRecord::Base.connection.create_table :employees, force: true do |t|
  # Demonstrating different data types and their alignment requirements
  t.string  :name          # variable length, 4-byte aligned
  t.integer :employee_id   # 4 bytes, 4-byte aligned
  t.boolean :active        # 1 byte, 1-byte aligned
  t.date    :hire_date     # 4 bytes, 4-byte aligned
  t.decimal :salary        # 8 bytes, 8-byte aligned
  t.jsonb   :details       # variable length, 4-byte aligned
  t.binary  :photo         # variable length, 4-byte aligned
  t.timestamps             # 2 x 8 bytes, 8-byte aligned
end

# Clean up existing records after ensuring table exists
Employee.delete_all

def analyze_tuple_size(record)
  # Calculate theoretical minimum size without alignment padding
  header_size = 23  # Standard tuple header size
  null_bitmap_size = (record.attributes.size + 7) / 8  # Round up to nearest byte

  puts "\nAnalyzing tuple for Employee #{record.name}:"
  puts "1. Header size: #{header_size} bytes"
  puts "2. Null bitmap size: #{null_bitmap_size} bytes"
  puts "\nColumn sizes and alignment:"
  
  total_theoretical_size = header_size + null_bitmap_size
  
  record.attributes.each do |name, value|
    next if name == "id"  # Skip primary key as it's handled differently
    
    size = case value
    when String
      value.bytesize
    when Integer
      4
    when TrueClass, FalseClass
      1
    when Date
      4
    when BigDecimal
      8
    when Hash
      value.to_json.bytesize
    when Time
      8
    else
      value.nil? ? 0 : value.to_s.bytesize
    end
    
    total_theoretical_size += size
    
    puts "- #{name}: #{size} bytes #{value.nil? ? '(NULL)' : ''} #{value.is_a?(String) || value.is_a?(Hash) ? '(variable)' : '(fixed)'}"
  end
  
  puts "\nTheoretical minimum size: #{total_theoretical_size} bytes"
end

# Create employees with different tuple storage patterns
puts "\n1. Minimal Employee (mostly NULL values)..."
minimal_employee = Employee.create!(
  name: "John Doe",
  employee_id: 1001,
  active: true,
  hire_date: nil,
  salary: nil,
  details: nil,
  photo: nil
)

puts "\n2. Typical Employee (mixed data types, moderate sizes)..."
typical_employee = Employee.create!(
  name: "Jane Smith",
  employee_id: 1002,
  active: true,
  hire_date: Date.today,
  salary: 75000.00,
  details: {
    department: "Engineering",
    title: "Senior Developer"
  },
  photo: nil
)

puts "\n3. Detailed Employee (large variable-length fields)..."
detailed_employee = Employee.create!(
  name: "Bob Wilson" + (" " * 50),  # Padded name
  employee_id: 1003,
  active: true,
  hire_date: Date.today,
  salary: 95000.50,
  details: {
    department: "Engineering",
    skills: ["Ruby", "PostgreSQL", "Rails", "JavaScript", "React"] * 10,
    projects: ["Project A", "Project B", "Project C"] * 5,
    certifications: ["AWS", "GCP", "Azure"] * 3,
    biography: "A" * 500  # Large text in JSON
  },
  photo: "B" * 1000  # 1KB photo
)

puts "\n4. Compact Employee (small fixed-length fields)..."
compact_employee = Employee.create!(
  name: "Eva Chen",
  employee_id: 1004,
  active: true,
  hire_date: Date.today,
  salary: 60000.00,
  details: { department: "HR" },
  photo: nil
)

puts "\n5. Mixed Employee (mix of NULL, small and medium fields)..."
mixed_employee = Employee.create!(
  name: "Alex Kumar",
  employee_id: 1005,
  active: false,
  hire_date: Date.today,
  salary: 82000.00,
  details: {
    department: "Marketing",
    skills: ["Content", "SEO", "Analytics"],
    notes: "B" * 200  # Medium-sized notes
  },
  photo: "C" * 500  # Medium-sized photo
)

# Analyze all tuples
[
  ["MINIMAL EMPLOYEE (mostly nulls)", minimal_employee],
  ["TYPICAL EMPLOYEE (balanced)", typical_employee],
  ["DETAILED EMPLOYEE (large fields)", detailed_employee],
  ["COMPACT EMPLOYEE (small fields)", compact_employee],
  ["MIXED EMPLOYEE (varied sizes)", mixed_employee]
].each do |label, employee|
  puts "\n#{'-' * 50}"
  puts label
  puts "-" * 50
  analyze_tuple_size(employee)
end

# Get actual storage statistics
ActiveRecord::Base.connection.execute('VACUUM ANALYZE employees;')

puts "\n#{'-' * 50}"
puts "ACTUAL STORAGE ANALYSIS"
puts "-" * 50
stats = StorageExplorer.analyze_detailed_storage('employees').first
puts JSON.pretty_generate(stats)

puts "\nKey Observations:"
puts "1. NULL values only consume space in the null bitmap"
puts "2. Variable-length fields have overhead for length"
puts "3. Alignment padding adds to theoretical size"
puts "4. TOAST may be used for large values (> 2KB)"
puts "5. Actual size includes page overhead and alignment" 