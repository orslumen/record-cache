module RecordCache
  
  # Every model that calls cache_records will receive an instance of this class
  # accessible through +<model>.record_cache+
  #
  # The dispatcher is responsible for dispatching queries, record_changes and invalidation calls
  # to the appropriate cache strategies.
  class Dispatcher
    
    # Retrieve all strategies ordered by fastest strategy first.
    #
    # Roll your own cache strategies by extending from +RecordCache::Strategy::Base+,
    # and registering it here +RecordCache::Dispatcher.strategy_classes << MyStrategy+
    def self.strategy_classes
      @strategy_classes ||= [RecordCache::Strategy::RequestCache, RecordCache::Strategy::UniqueIndexCache, RecordCache::Strategy::FullTableCache, RecordCache::Strategy::IndexCache]
    end

    def initialize(base)
      @base = base
      @strategy_by_attribute = {}
    end

    # Parse the options provided to the cache_records method and create the appropriate cache strategies.
    def parse(options)
      # find the record store, possibly based on the :store option
      store = record_store(options.delete(:store))
      # dispatch the parse call to all known strategies
      Dispatcher.strategy_classes.map{ |klass| klass.parse(@base, store, options) }.flatten.compact.each do |strategy|
        raise "Multiple record cache definitions found for '#{strategy.attribute}' on #{@base.name}" if @strategy_by_attribute[strategy.attribute]
        # and keep track of all strategies
        @strategy_by_attribute[strategy.attribute] = strategy
      end
      # make sure the strategies are ordered again on next call to +ordered_strategies+
      @ordered_strategies = nil
    end

    # Retrieve the caching strategy for the given attribute
    def [](attribute)
      @strategy_by_attribute[attribute]
    end

    # Can the cache retrieve the records based on this query?
    def cacheable?(query)
      !!first_cacheable_strategy(query)
    end

    # retrieve the record(s) based on the given query (check with cacheable?(query) first)
    def fetch(query)
      if request_cache
        # cache the query in the request
        request_cache.fetch(query) { fetch_from_first_cacheable_strategy(query) }
      else
        # fetch the results using the first strategy that accepts this query
        fetch_from_first_cacheable_strategy(query)
      end
    end

    # Update the version store and the record store (used by callbacks)
    # @param record the updated record (possibly with
    # @param action one of :create, :update or :destroy
    def record_change(record, action)
      # skip unless something has actually changed
      return if action == :update && record.previous_changes.empty?
      # dispatch the record change to all known strategies
      @strategy_by_attribute.values.each { |strategy| strategy.record_change(record, action) }
    end

    # Explicitly invalidate one or more records
    # @param: strategy: the id of the strategy to invalidate (defaults to +:id+)
    # @param: value: the value to send to the invalidate method of the chosen strategy
    def invalidate(strategy, value = nil)
      (value = strategy; strategy = :id) unless strategy.is_a?(Symbol)
      # call the invalidate method of the chosen strategy
      @strategy_by_attribute[strategy].invalidate(value) if @strategy_by_attribute[strategy]
      # always clear the request cache if invalidate is explicitly called for this class
      request_cache.try(:invalidate, value)
    end

    private
    
    # Find the cache store for the records (using the :store option)
    def record_store(store)
      store = RecordCache::Base.stores[store] || ActiveSupport::Cache.lookup_store(store) if store.is_a?(Symbol)
      store ||= Rails.cache if defined?(::Rails)
      store ||= ActiveSupport::Cache.lookup_store(:memory_store)
      RecordCache::MultiRead.test(store)
    end

    # Retrieve the data from the first strategy that can handle the query.
    def fetch_from_first_cacheable_strategy(query)
      first_cacheable_strategy(query).fetch(query)
    end

    # Find the first strategy that can handle this query.
    def first_cacheable_strategy(query)
      ordered_strategies.detect { |strategy| strategy.cacheable?(query) }
    end

    # Retrieve all strategies except :request_cache ordered by the fastest strategy first (currently :id, :unique, :index)
    def ordered_strategies
      @ordered_strategies ||= begin
        last_index = Dispatcher.strategy_classes.size
        # sort the strategies baed on the +strategy_classes+ index
        ordered = @strategy_by_attribute.values.sort{ |x,y| Dispatcher.strategy_classes.index(x.class) || last_index <=> Dispatcher.strategy_classes.index(y.class) || last_index }
        # and remove the RequestCache from the list
        ordered.delete(request_cache) if request_cache
        ordered
      end
    end

    # Retrieve the request cache strategy, or
    # +nil+ unless the +:request_cache => true+ option was provided.
    def request_cache
      @strategy_by_attribute[:request_cache]
    end

  end
end
