module RecordCache
  module Strategy
    class Base
      CLASS_KEY = :c
      ATTRIBUTES_KEY = :a

      def initialize(base, strategy_id, record_store, options)
        @base = base
        @strategy_id = strategy_id
        @record_store = record_store
        @cache_key_prefix = "rc/#{options[:key] || @base.name}/".freeze
      end

      # Fetch all records and sort and filter locally
      def fetch(query)
        records = fetch_records(query)
        filter!(records, query.wheres) if query.wheres.size > 0
        sort!(records, query.sort_orders) if query.sorted?
        records
      end

      # Handle create/update/destroy (use record.previous_changes to find the old values in case of an update)
      def record_change(record, action)
        raise NotImplementedError
      end

      # Can the cache retrieve the records based on this query?
      def cacheable?(query)
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
        @statistics ||= RecordCache::Statistics.find(@base, @strategy_id)
      end

      # retrieve the cache key for the given id, e.g. rc/person/14
      def cache_key(id)
        "#{@cache_key_prefix}#{id}".freeze
      end
  
      # retrieve the versioned record key, e.g. rc/person/14v1
      def versioned_key(cache_key, version)
        "#{cache_key}v#{version.to_s}".freeze
      end
  
      # serialize one record before adding it to the cache
      # creates a shallow clone with a version and without associations
      def serialize(record)
        {CLASS_KEY => record.class.name,
         ATTRIBUTES_KEY => record.instance_variable_get(:@attributes)}.freeze
      end
  
      # deserialize a cached record
      def deserialize(serialized)
        record = serialized[CLASS_KEY].constantize.new
        attributes = serialized[ATTRIBUTES_KEY]
        record.instance_variable_set(:@attributes, Hash[attributes])
        record.instance_variable_set(:@new_record, false)
        record.instance_variable_set(:@changed_attributes, {})
        record.instance_variable_set(:@previously_changed, {})
        record
      end

      private

      # Filter the cached records in memory
      # only simple x = y or x IN (a,b,c) can be handled 
      def filter!(records, wheres)
        wheres.each_pair do |attr, value|
          if value.is_a?(Array)
            records.reject! { |record| !value.include?(record.send(attr)) }
          else
            records.reject! { |record| record.send(attr) != value }
          end
        end
      end
  
      # Sort the cached records in memory
      def sort!(records, sort_orders)
        records.sort!(&sort_proc(sort_orders))
        Collator.clear
        records
      end
  
      # Retrieve the Proc based on the order by attributes
      # Note: Case insensitive sorting with collation is used for Strings
      def sort_proc(sort_orders)
        # [['(COLLATER.collate(x.name) || NIL_COMES_FIRST)', 'COLLATER.collate(y.name)'], ['(y.updated_at || NIL_COMES_FIRST)', 'x.updated_at']]
        sort = sort_orders.map do |attr, asc|
          lr = ["x.", "y."]
          lr.reverse! unless asc
          lr.each{ |s| s << attr }
          lr.each{ |s| s.replace("Collator.collate(#{s})") } if @base.columns_hash[attr].type == :string
          lr[0].replace("(#{lr[0]} || NIL_COMES_FIRST)")
          lr
        end
        # ['[(COLLATER.collate(x.name) || NIL_COMES_FIRST), (y.updated_at || NIL_COMES_FIRST)]', '[COLLATER.collate(y.name), x.updated_at]']
        sort = sort.transpose.map{|s| s.size == 1 ? s.first : "[#{s.join(',')}]"}
        # Proc.new{ |x,y| { ([(COLLATER.collate(x.name) || NIL_COMES_FIRST), (y.updated_at || NIL_COMES_FIRST)] <=> [COLLATER.collate(y.name), x.updated_at]) || 1 }
        eval("Proc.new{ |x,y| (#{sort[0]} <=> #{sort[1]}) || 1 }")
      end
  
      # If +x.nil?+ this class will return -1 for +x <=> y+
      NIL_COMES_FIRST = ((class NilComesFirst; def <=>(y); -1; end; end); NilComesFirst.new)
  
      # StringCollator uses the Rails transliterate method for collation
      module Collator
        @collated = []
  
        def self.clear
          @collated.each { |string| string.send(:remove_instance_variable, :@rc_collated) }
          @collated.clear
        end
  
        def self.collate(string)
          collated = string.instance_variable_get(:@rc_collated)
          return collated if collated
          normalized = ActiveSupport::Multibyte::Unicode.normalize(ActiveSupport::Multibyte::Unicode.tidy_bytes(string), :c).mb_chars
          collated = I18n.transliterate(normalized).downcase.mb_chars
          # transliterate will replace ignored/unknown chars with ? the following line replaces ? with the original character
          collated.chars.each_with_index{ |c, i| collated[i] = normalized[i] if c == '?' } if collated.index('?')
          # puts "collation: #{string} => #{collated.to_s}"
          string.instance_variable_set(:@rc_collated, collated)
          @collated << string
          collated
        end
      end
    end
  end
end
