# Remembers the queries performed during a single Request.
# If the same query is requested again the result is provided straight from local memory.
#
# Records are invalidated per model-klass, when any record is created, updated or destroyed.
module RecordCache
  module Strategy
    
    class RequestCache < Base
      @@request_store = {}

      # parse the options and return (an array of) instances of this strategy
      def self.parse(base, record_store, options)
        return nil unless options[:request_cache]
        RequestCache.new(base, :request_cache, record_store, options)
      end

      # call before each request: in application_controller.rb
      # prepend_before_filter { |c| RecordCache::Strategy::RequestCache.clear }
      def self.clear
        @@request_store.clear
      end

      # Handle record change
      def record_change(record, action)
        @@request_store.delete(@base.name)
      end

      # Handle invalidation call
      def invalidate(value)
        @@request_store.delete(@base.name)
      end

      # return the records from the request cache, execute block in case
      # this is the first time this query is performed during this request
      def fetch(query, &block)
        klass_store = (@@request_store[@base.name] ||= {})
        key = query.cache_key
        # logging (only in debug mode!) and statistics
        log_cache_hit(key, klass_store.key?(key)) if RecordCache::Base.logger.debug?
        statistics.add(1, klass_store.key?(key) ? 1 : 0) if statistics.active?
        klass_store[key] ||= yield
      end

      private

      # ------------------------- Utility methods ----------------------------
  
      # log cache hit/miss to debug log
      def log_cache_hit(key, hit)
        RecordCache::Base.logger.debug{ "RequestCache #{hit ? 'hit' : 'miss'} for #{key}" }
      end

    end
  end
end
