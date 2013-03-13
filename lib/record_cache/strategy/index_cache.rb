module RecordCache
  module Strategy
    class IndexCache < Base
  
      # parse the options and return (an array of) instances of this strategy
      def self.parse(base, record_store, options)
        return nil unless options[:index]
        return nil unless base.table_exists?
        
        raise "Index cache '#{options[:index].inspect}' on #{base.name} is redundant as index cache queries are handled by the full table cache." if options[:full_table]
        raise ":index => #{options[:index].inspect} option cannot be used unless 'id' is present on #{base.name}" unless base.columns_hash['id']
        [options[:index]].flatten.compact.map do |attribute|
          type = base.columns_hash[attribute.to_s].try(:type)
          raise "No column found for index '#{attribute}' on #{base.name}." unless type
          raise "Incorrect type (expected integer, found #{type}) for index '#{attribute}' on #{base.name}." unless type == :integer
          IndexCache.new(base, attribute, record_store, options)
        end
      end

      def initialize(base, attribute, record_store, options)
        super
        @index_cache_key_prefix = cache_key(attribute) # "/rc/<model>/<attribute>"
      end

      # Can the cache retrieve the records based on this query?
      def cacheable?(query)
        # allow limit of 1 for has_one
        query.where_value(@attribute) && (query.limit.nil? || (query.limit == 1 && !query.sorted?))
      end

      # Handle create/update/destroy (use record.previous_changes to find the old values in case of an update)
      def record_change(record, action)
        if action == :destroy
          remove_from_index(record.send(@attribute), record.id)
        elsif action == :create
          add_to_index(record.send(@attribute), record.id)
        else
          index_change = record.previous_changes[@attribute.to_s]
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
        value = query.where_value(@attribute)
        # make sure CacheCase.filter! does not see this where clause anymore
        query.wheres.delete(@attribute)
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
          sql = @base.select('id').where(@attribute => value).to_sql
          ids = []; @base.connection.execute(sql).each{ |row| ids << (row.is_a?(Hash) ? row['id'] : row.first).to_i }
          if RecordCache::Base.cache_writeable?
            record_store.write(versioned_key, ids)
          end
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
        RecordCache::Base.logger.debug{ "IndexCache #{ids ? 'hit' : 'miss'} for #{key}: found #{ids ? ids.size : 'no'} ids" }
      end
    end
  end
end
