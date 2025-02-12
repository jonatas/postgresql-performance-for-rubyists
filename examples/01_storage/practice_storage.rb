require_relative '../../config/database'
require_relative './storage_explorer'

class Document < ActiveRecord::Base
end

# Clean up existing records
Document.delete_all

# Create the documents table if it doesn't exist
unless ActiveRecord::Base.connection.table_exists?('documents')
  ActiveRecord::Base.connection.create_table :documents do |t|
    t.string :title
    t.text :content    # Regular text
    t.jsonb :metadata  # JSONB storage
    t.binary :attachment  # TOAST candidate
    t.timestamps
  end
end

puts "\nCreating small document..."
small_doc = Document.create!(
  title: "Small Document",
  content: "Small content",
  metadata: { tags: ["small"] },
  attachment: "Small attachment"
)

puts "Creating large document..."
large_doc = Document.create!(
  title: "Large Document",
  content: "A" * 10_000,
  metadata: { tags: ["large"], description: "B" * 1000 },
  attachment: "Large binary content" * 1000
)

ActiveRecord::Base.connection.execute('VACUUM ANALYZE documents;')

puts "\nStorage Analysis:"
stats = StorageExplorer.analyze_detailed_storage('documents').first
puts JSON.pretty_generate(stats)

puts "\nDocument Sizes:"
puts "Small document:"
puts "- Content: #{small_doc.content.length} bytes"
puts "- Metadata: #{small_doc.metadata.to_json.length} bytes"
puts "- Attachment: #{small_doc.attachment.length} bytes"

puts "\nLarge document:"
puts "- Content: #{large_doc.content.length} bytes"
puts "- Metadata: #{large_doc.metadata.to_json.length} bytes"
puts "- Attachment: #{large_doc.attachment.length} bytes" 