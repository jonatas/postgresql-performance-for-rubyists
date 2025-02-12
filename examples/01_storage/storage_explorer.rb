require_relative '../../config/database'

class StorageExplorer
  class << self
    def analyze_table_storage(table_name)
      connection.execute(<<~SQL)
        SELECT pg_size_pretty(pg_total_relation_size('#{table_name}')) as total_size,
               pg_size_pretty(pg_relation_size('#{table_name}')) as table_size,
               pg_size_pretty(pg_indexes_size('#{table_name}')) as index_size
      SQL
    end

    def analyze_toast_storage(table_name)
      connection.execute(<<~SQL)
        SELECT pg_size_pretty(pg_total_relation_size(reltoastrelid)) as toast_size
        FROM pg_class
        WHERE relname = '#{table_name}'
        AND reltoastrelid != 0
      SQL
    end

    def analyze_detailed_storage(table_name)
      connection.execute(<<~SQL)
        WITH table_info AS (
          SELECT c.oid,
                 c.reltoastrelid,
                 pg_total_relation_size('#{table_name}') as total_bytes,
                 pg_relation_size('#{table_name}') as table_bytes,
                 pg_indexes_size('#{table_name}') as index_bytes,
                 (SELECT count(*) FROM pg_attribute 
                  WHERE attrelid = c.oid AND attlen = -1) as toast_column_count
          FROM pg_class c
          WHERE c.relname = '#{table_name}'
        ),
        table_stats AS (
          SELECT n_live_tup,
                 n_dead_tup,
                 n_tup_ins as inserts,
                 n_tup_upd as updates,
                 n_tup_del as deletes
          FROM pg_stat_user_tables
          WHERE relname = '#{table_name}'
        )
        SELECT 
          pg_size_pretty(table_info.table_bytes) as table_size,
          table_info.table_bytes,
          pg_size_pretty(table_info.index_bytes) as index_size,
          table_info.index_bytes,
          pg_size_pretty(table_info.total_bytes) as total_size,
          table_info.total_bytes,
          table_info.toast_column_count,
          table_stats.n_live_tup as live_tuples,
          table_stats.n_dead_tup as dead_tuples,
          table_stats.inserts,
          table_stats.updates,
          table_stats.deletes
        FROM table_info, table_stats;
      SQL
    end

    private

    def connection
      ActiveRecord::Base.connection
    end
  end
end 