module RecordCache
  module Strategy
    class Base
      
      # Parse the options and return (an array of) instances of this strategy.
      def self.parse(base, record_store, options)
        raise NotImplementedError
      end

      def initialize(base, attribute, record_store, options)
        @base = base
        @attribute = attribute
        @record_store = record_store
        @cache_key_prefix = "rc/#{options[:key] || @base.name}/"
      end
      
      # Retrieve the +attribute+ for this strategy (unique per model).
      # May be a non-existing attribute in case a cache is not based on a single attribute.
      def attribute
        @attribute
      end

      # Fetch all records and sort and filter locally
      def fetch(query)
        @table_version = (version_store.current(@cache_key_prefix) || version_store.renew(@cache_key_prefix))
        records = fetch_records(query)
        Util.filter!(records, query.wheres) if query.wheres.size > 0
        Util.sort!(records, query.sort_orders) if query.sorted?
        records = records[0..query.limit-1] if query.limit
        records
      end
      
      def invalidate_everything!
        new_version = version_store.increment(@cache_key_prefix)
        if new_version == 0
          version_store.renew(@cache_key_prefix)
        end
      end

      # Can the cache retrieve the records based on this query?
      def cacheable?(query)
        raise NotImplementedError
      end

      # Handle create/update/destroy (use record.previous_changes to find the old values in case of an update)
      def record_change(record, action)
        raise NotImplementedError
      end

      # Handle invalidation call
      def invalidate(id)
        raise NotImplementedError
      end

      protected
  
      def fetch_records(query)
        raise NotImplementedError
      end
  
      # ------------------------- Utility methods ----------------------------
  
      # retrieve the version store (unique store for the whole application)
      def version_store
        RecordCache::Base.version_store
      end
      
      # retrieve the record store (store for records for this cache strategy)
      def record_store
        @record_store
      end
      
      # find the statistics for this cache strategy
      def statistics
        @statistics ||= RecordCache::Statistics.find(@base, @attribute)
      end

      # retrieve the cache key for the given id, e.g. rc/person/14
      def cache_key(id)
        "#{@cache_key_prefix}#{@table_version}/#{id}"
      end

      # retrieve the versioned record key, e.g. rc/person/14v1
      def versioned_key(cache_key, version)
        "#{cache_key}v#{version.to_s}"
      end
  
    end
  end
end
