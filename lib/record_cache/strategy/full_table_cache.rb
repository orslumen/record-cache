module RecordCache
  module Strategy
    class FullTableCache < Base
      FULL_TABLE = 'full-table'

      # parse the options and return (an array of) instances of this strategy
      def self.parse(base, record_store, options)
        return nil unless options[:full_table]
        return nil unless base.table_exists?
        
        FulltableCache.new(base, :full_table, record_store, options)
      end

      # Can the cache retrieve the records based on this query?
      def cacheable?(query)
        true
      end

      # Clear the cache on any record change
      def record_change(record, action)
        version_store.delete(cache_key(FULL_TABLE))
      end

      # Handle invalidation call
      def invalidate(id)
        version_store.delete(cache_key(FULL_TABLE))
      end
  
      protected
  
      # retrieve the record(s) with the given id(s) as an array
      def fetch_records(query)
        key = cache_key(FULL_TABLE)
        # retrieve the current version of the records
        current_version = version_store.current(key)
        # get the records from the cache if there is a current version
        records = current_version ? from_cache(key, current_version) : nil
        # logging (only in debug mode!) and statistics
        log_full_table_cache_hit(key, records) if RecordCache::Base.logger.debug?
        statistics.add(1, records ? 1 : 0) if statistics.active?
        # no records found?
        unless records
          # renew the version in case the version was not known
          current_version = version_store.renew(key) unless current_version
          # retrieve all records from the DB
          records = from_db(key, current_version)
        end
        # return the array
        records
      end
  
      private
  
      # ---------------------------- Querying ------------------------------------

      # retrieve the records from the cache with the given keys
      def from_cache(key, version)
        records = record_store.read(versioned_key(key, version))
        records.map{ |record| Util.deserialize(record) } if records
      end
    
      # retrieve the records with the given ids from the database
      def from_db(key, version)
        RecordCache::Base.without_record_cache do
          # retrieve the records from the database
          records = @base.all.to_a
          # write all records to the cache
          record_store.write(versioned_key(key, version), records.map{ |record| Util.serialize(record) })
          records
        end
      end
  
      # ------------------------- Utility methods ----------------------------
  
      # log cache hit/miss to debug log
      def log_full_table_cache_hit(key, records)
        RecordCache::Base.logger.debug{ "FullTableCache #{records ? 'hit' : 'miss'} for model #{@base.name}" }
      end

    end
  end
end
