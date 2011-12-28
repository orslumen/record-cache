module RecordCache
  
  # Collect cache hit/miss statistics for each cache strategy
  module Statistics
    
    class << self

      # returns +true+ if statistics need to be collected
      def active?
        !!@active
      end

      # start statistics collection
      def start
        @active = true
      end

      # stop statistics collection
      def stop
        @active = false
      end

      # toggle statistics collection
      def toggle
        @active = !@active
      end

      # reset all statistics
      def reset!(base = nil)
        stats = find(base).values
        stats = stats.map(&:values).flatten unless base # flatten hash of hashes in case base was nil
        stats.each{ |s| s.reset! }
      end

      # Retrieve the statistics for the given base and attribute
      # Returns a hash {<attribute> => <statistics} for a model if no strategy is provided
      # Returns a hash of hashes { <model_name> => {<attribute> => <statistics} } if no parameter is provided
      def find(base = nil, attribute = nil)
        stats = (@stats ||= {})
        stats = (stats[base.name] ||= {}) if base
        stats = (stats[attribute] ||= Counter.new) if attribute
        stats
      end
    end

    class Counter
      attr_accessor :calls, :hits, :misses

      def initialize
        reset!
      end

      # add hit statatistics for the given cache strategy
      # @param queried: nr of ids queried
      # @param found: nr of records found in the cache
      def add(queried, found)
        @calls += 1
        @hits += found
        @misses += (queried - found)
      end

      def reset!
        @hits = 0
        @misses = 0
        @calls = 0
      end

      def active?
        RecordCache::Statistics.active?
      end

      def percentage
        return 0.0 if @hits == 0
        (@hits.to_f / (@hits + @misses)) * 100
      end

      def inspect
        "#{percentage}% (#{@hits}/#{@hits + @misses})"
      end
    end
  end
end
