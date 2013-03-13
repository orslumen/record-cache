# Make sure the version store can be reset to it's starting point after each test
# Usage:
#   require 'record_cache/test/resettable_version_store'
#   after(:each) { RecordCache::Base.version_store.reset! }
module RecordCache
  module Test

    module ResettableVersionStore

      def self.included(base)
        base.extend ClassMethods
        base.send(:include, InstanceMethods)
        base.instance_eval do
          alias_method_chain :increment, :reset
          alias_method_chain :renew, :reset
        end
      end

      module ClassMethods
      end

      module InstanceMethods

        def increment_with_reset(key)
          updated_version_keys << key
          increment_without_reset(key)
        end
        
        def renew_with_reset(key, opts = {})
          updated_version_keys << key
          renew_without_reset(key, opts)
        end

        def reset!
          RecordCache::Strategy::RequestCache.clear
          updated_version_keys.each { |key| delete(key) }
          updated_version_keys.clear
        end

        def updated_version_keys
          @updated_version_keys ||= []
        end
      end
    end

  end
end

RecordCache::VersionStore.send(:include, RecordCache::Test::ResettableVersionStore)
