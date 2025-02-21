require_relative '../../config/database'

class Document < ActiveRecord::Base
  def self.table_stats
    connection.execute(<<~SQL).first
      SELECT 
        n_live_tup as live_tuples,
        n_dead_tup as dead_tuples,
        n_tup_ins as inserts,
        n_tup_upd as updates,
        n_tup_del as deletes
      FROM pg_stat_user_tables
      WHERE relname = 'documents'
    SQL
  end

  def self.storage_sizes
    {
      total_size: connection.execute("SELECT pg_size_pretty(pg_total_relation_size('documents'))").first['pg_size_pretty'],
      table_size: connection.execute("SELECT pg_size_pretty(pg_relation_size('documents'))").first['pg_size_pretty'],
      index_size: connection.execute("SELECT pg_size_pretty(pg_indexes_size('documents'))").first['pg_size_pretty'],
      toast_size: connection.execute(<<~SQL).first['pg_size_pretty']
        SELECT pg_size_pretty(pg_total_relation_size(reltoastrelid)) 
        FROM pg_class 
        WHERE relname = 'documents' 
        AND reltoastrelid != 0
      SQL
    }
  end
end

# Create the documents table if it doesn't exist
if Document.table_exists?
  # Clean up existing records
  Document.delete_all
else
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
puts "\nStorage Sizes:"
puts JSON.pretty_generate(Document.storage_sizes)

puts "\nTable Statistics:"
puts JSON.pretty_generate(Document.table_stats)

puts "\nDocument Sizes:"
puts "Small document:"
puts "- Content: #{small_doc.content.length} bytes"
puts "- Metadata: #{small_doc.metadata.to_json.length} bytes"
puts "- Attachment: #{small_doc.attachment.length} bytes"

puts "\nLarge document:"
puts "- Content: #{large_doc.content.length} bytes"
puts "- Metadata: #{large_doc.metadata.to_json.length} bytes"
puts "- Attachment: #{large_doc.attachment.length} bytes"

Document.storage_sizes  # Get all storage-related sizes
Document.table_stats   # Get table statistics 