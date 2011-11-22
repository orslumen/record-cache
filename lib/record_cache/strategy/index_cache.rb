module RecordCache
  module Strategy
    class IndexCache < Base
  
      def initialize(base, strategy_id, record_store, options)
        super
        @index = options[:index]
        # check the index
        type = @base.columns_hash[@index.to_s].try(:type)
        raise "No column found for index '#{@index}' on #{@base.name}." unless type
        raise "Incorrect type (expected integer, found #{type}) for index '#{@index}' on #{@base.name}." unless type == :integer
        @index_cache_key_prefix = cache_key(@index) # "/rc/<model>/<index>"
      end

      # Can the cache retrieve the records based on this query?
      def cacheable?(query)
        # allow limit of 1 for has_one
        query.where_id(@index) && (query.limit.nil? || (query.limit == 1 && !query.sorted?))
      end

      # Handle create/update/destroy (use record.previous_changes to find the old values in case of an update)
      def record_change(record, action)
        if action == :destroy
          remove_from_index(record.send(@index), record.id)
        elsif action == :create
          add_to_index(record.send(@index), record.id)
        else
          index_change = record.previous_changes[@index.to_s]
          return unless index_change
          remove_from_index(index_change[0], record.id)
          add_to_index(index_change[1], record.id)
        end
      end

      # Explicitly invalidate the record cache for the given value
      def invalidate(value)
        version_store.increment(index_cache_key(value))
      end

      protected

      # retrieve the record(s) based on the given query
      def fetch_records(query)
        value = query.where_id(@index)
        # make sure CacheCase.filter! does not see this where clause anymore
        query.wheres.delete(@index)
        # retrieve the cache key for this index and value
        key = index_cache_key(value)
        # retrieve the current version of the ids list
        current_version = version_store.current(key)
        # create the versioned key, renew the version in case it was missing in the version store
        versioned_key = versioned_key(key, current_version || version_store.renew(key))
        # retrieve the ids from the local cache based on the current version from the version store
        ids = current_version ? fetch_ids_from_cache(versioned_key) : nil
        # logging (only in debug mode!) and statistics
        log_cache_hit(versioned_key, ids) if RecordCache::Base.logger.debug?
        statistics.add(1, ids ? 1 : 0) if statistics.active?
        # retrieve the ids from the DB if the result was not fresh
        ids = fetch_ids_from_db(versioned_key, value) unless ids
        # use the IdCache to retrieve the records based on the ids
        records = @base.record_cache[:id].send(:fetch_records, ::RecordCache::Query.new({:id => ids}))
        records = records[0, query.limit] unless query.limit.nil? || records.nil?
        records
      end
  
      private
  
      # ---------------------------- Querying ------------------------------------
  
      # key to retrieve the ids for a given value
      def index_cache_key(value)
        "#{@index_cache_key_prefix}=#{value}"
      end
  
      # Retrieve the ids from the local cache
      def fetch_ids_from_cache(versioned_key)
        record_store.read(versioned_key)
      end
  
      # retrieve the ids from the database and update the local cache
      def fetch_ids_from_db(versioned_key, value)
        RecordCache::Base.without_record_cache do
          # go straight to SQL result for optimal performance
          sql = @base.select('id').where(@index => value).to_sql
          ids = []; @base.connection.execute(sql).each{ |row| ids << (row.is_a?(Hash) ? row['id'] : row.first).to_i }
          record_store.write(versioned_key, ids)
          ids
        end
      end
  
      # ---------------------------- Local Record Changes ---------------------------------
  
      # add one record(id) to the index with the given value
      def add_to_index(value, id)
        increment_version(value.to_i) { |ids| ids << id } if value
      end

      # remove one record(id) from the index with the given value
      def remove_from_index(value, id)
        increment_version(value.to_i) { |ids| ids.delete(id) } if value
      end

      # increment the version store and update the local store
      def increment_version(value, &block)
        # retrieve local version and increment version store
        key = index_cache_key(value)
        version = version_store.increment(key)
        # try to update the ids list based on the last version
        ids = fetch_ids_from_cache(versioned_key(key, version - 1))
        if ids
          ids = Array.new(ids)
          yield ids
          record_store.write(versioned_key(key, version), ids)
        end
      end
  
      # ------------------------- Utility methods ----------------------------
  
      # log cache hit/miss to debug log
      def log_cache_hit(key, ids)
        RecordCache::Base.logger.debug("IndexCache #{ids ? 'hit' : 'miss'} for #{key}: found #{ids ? ids.size : 'no'} ids")
      end
    end
  end
end
