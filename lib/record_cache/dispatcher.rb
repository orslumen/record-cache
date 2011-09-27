module RecordCache
  
  # Every model that calls cache_records will receive an instance of this class
  # accessible through +<model>.record_cache+
  #
  # The dispatcher is responsible for dispatching queries, record_changes and invalidation calls
  # to the appropriate cache strategies.
  class Dispatcher
    def initialize(base)
      @base = base
      @strategy_by_id = {}
      # all strategies except :request_cache, with the :id stategy first (most used and best performing)
      @ordered_strategies = []
    end

    # Register a cache strategy for this model
    def register(strategy_id, strategy_klass, record_store, options)
      if @strategy_by_id.key?(strategy_id)
        return if strategy_id == :id
        raise "Multiple record cache definitions found for '#{strategy_id}' on #{@base.name}"
      end
      # Instantiate the cache strategy
      strategy = strategy_klass.new(@base, strategy_id, record_store, options)
      # Keep track of all strategies for this model
      @strategy_by_id[strategy_id] = strategy
      # Note that the :id strategy is always registered first
      @ordered_strategies << strategy unless strategy_id == :request_cache
    end

    # Retrieve the caching strategy for the given attribute
    def [](strategy_id)
      @strategy_by_id[strategy_id]
    end

    # Can the cache retrieve the records based on this query?
    def cacheable?(query)
      !!first_cacheable_strategy(query)
    end

    # retrieve the record(s) with the given id(s) as an array
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
      @strategy_by_id.values.each { |strategy| strategy.record_change(record, action) }
    end

    # Explicitly invalidate one or more records
    # @param: strategy: the strategy to invalidate
    # @param: value: the value to send to the invalidate method of the chosen strategy
    def invalidate(strategy, value = nil)
      (value = strategy; strategy = :id) unless strategy.is_a?(Symbol)
      # call the invalidate method of the chosen strategy
      @strategy_by_id[strategy].invalidate(value) if @strategy_by_id[strategy]
      # always clear the request cache if invalidate is explicitly called for this class
      request_cache.try(:invalidate, value)
    end

    private

    # retrieve the data from the first strategy that handle the query
    def fetch_from_first_cacheable_strategy(query)
      first_cacheable_strategy(query).fetch(query)
    end

    # find the first strategy that can handle this query
    def first_cacheable_strategy(query)
      @ordered_strategies.detect { |strategy| strategy.cacheable?(query) }
    end

    # retrieve the request cache strategy, if defined for this model
    def request_cache
      @strategy_by_id[:request_cache]
    end

  end
end
