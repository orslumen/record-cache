# This class will delegate read_multi to sequential read calls in case read_multi is not supported.
#
# If a particular Store Class does support read_multi, but is somehow slower because of a bug,
# you can disable read_multi by calling:
#   RecordCache::MultiRead.disable(ActiveSupport::Cache::DalliStore)
#
# Important: Because of a bug in Dalli, read_multi is quite slow on some machines.
#            @see https://github.com/mperham/dalli/issues/106
require "set"

module RecordCache
  module MultiRead
    @tested = Set.new
    @disabled_klass_names = Set.new

    class << self
      
      # Disable multi_read for a particular Store, e.g.
      #   RecordCache::MultiRead.disable(ActiveSupport::Cache::DalliStore)
      def disable(klass)
        @disabled_klass_names << klass.name
      end

      # Test the store if it supports read_multi calls
      # If not, delegate multi_read calls to normal read calls
      def test(store)
        return store if @tested.include?(store)
        @tested << store
        override_read_multi(store) unless read_multi_supported?(store)
        store
      end

      private

      def read_multi_supported?(store)
        return false if @disabled_klass_names.include?(store.class.name)
        begin
          store.read_multi('a', 'b')
          true
        rescue Exception => ignore
          false
        end
      end

      # delegate read_multi to normal read calls
      def override_read_multi(store)
        def store.read_multi(*keys)
          keys.inject({}){ |h,key| h[key] = self.read(key); h}
        end
      end
    end
  end
end