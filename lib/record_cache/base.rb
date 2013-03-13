module RecordCache
  # Normal mode
  ENABLED  = 1
  # Do not fetch queries through the cache (but still update the cache after commit)
  NO_FETCH = 2
  # Completely disable the cache (may lead to stale results in case caching for other workers is not DISABLED)
  DISABLED = 3

  module Base
    class << self
      def included(klass)
        klass.class_eval do 
          extend ClassMethods
          include InstanceMethods
        end
      end

      # The logger instance (Rails.logger if present)
      def logger
        @logger ||= defined?(::Rails) ? ::Rails.logger : ::ActiveRecord::Base.logger
      end

      # Set the ActiveSupport::Cache::Store instance that contains the current record(group) versions.
      # Note that it must point to a single Store shared by all webservers (defaults to Rails.cache)
      def version_store=(store)
        @version_store = RecordCache::VersionStore.new(RecordCache::MultiRead.test(store))
      end

      # The ActiveSupport::Cache::Store instance that contains the current record(group) versions.
      # Note that it must point to a single Store shared by all webservers (defaults to Rails.cache)
      def version_store
        self.version_store = Rails.cache unless @version_store
        @version_store
      end

      # Register a cache store by id for future reference with the :store option for +cache_records+
      # e.g. RecordCache::Base.register_store(:server, ActiveSupport::Cache.lookup_store(:memory_store))
      def register_store(id, store)
        stores[id] = RecordCache::MultiRead.test(store)
      end

      # The hash of registered record stores (store_id => store)
      def stores
        @stores ||= {}
      end

      # To disable the record cache for all models:
      #   RecordCache::Base.disabled!
      # Enable again with:
      #   RecordCache::Base.enable
      def disable!
        @status = RecordCache::DISABLED
      end

      # Enable record cache
      def enable
        @status = RecordCache::ENABLED
      end

      # Executes the block with caching enabled.
      # Useful in testing scenarios.
      #
      #   RecordCache::Base.enabled do
      #     @foo = Article.find(1)
      #     @foo.update_attributes(:time_spent => 45)
      #     @foo = Article.find(1)
      #     @foo.time_spent.should be_nil
      #     TimeSpent.last.amount.should == 45
      #   end
      #
      def enabled(&block)
        previous_status = @status
        begin
          @status = RecordCache::ENABLED
          yield
        ensure
          @status = previous_status
        end
      end

      # Retrieve the current status
      def status
        @status ||= RecordCache::ENABLED
      end

      # execute block of code without using the records cache to fetch records
      # note that updates are still written to the cache, as otherwise other
      # workers may receive stale results.
      # To fully disable caching use +disable!+
      def without_record_cache(&block)
        old_status = status
        begin
          @status = RecordCache::NO_FETCH
          yield
        ensure
          @status = old_status
        end
      end
    end

    module ClassMethods
      # Cache the instances of this model
      # generic options:
      #   :store => the cache store for the instances, e.g. :memory_store, :dalli_store* (default: Rails.cache)
      #             or one of the store ids defined using +RecordCache::Base.register_store+
      #   :key   => provide a unique shorter key to limit the cache key length (default: model.name)
      # 
      # cache strategy specific options:
      #   :index => one or more attributes (Symbols) for which the ids are cached for the value of the attribute
      #   :request_cache => Set to true in case the exact same query is executed more than once during a single request
      #                     If set to true somewhere, make sure to add the following to your application controller:
      #                     prepend_before_filter { |c| RecordCache::Strategy::RequestCache.clear }
      #
      # Hints:
      #   - Dalli is a high performance pure Ruby client for accessing memcached servers, see https://github.com/mperham/dalli
      #   - use :store => :memory_store in case all records can easily fit in server memory
      #   - use :index => :account_id in case the records are (almost) always queried as a full set per account
      #   - use :index => :person_id for aggregated has_many associations
      def cache_records(options = {})
        unless @rc_dispatcher
          @rc_dispatcher = RecordCache::Dispatcher.new(self) 
          # Callback for Data Store specific initialization
          record_cache_init

          class << self
            alias_method_chain :inherited, :record_cache
          end
        end
        # parse the requested strategies from the given options
        @rc_dispatcher.parse(options)
      end

      # Returns true if record cache is defined and active for this class
      def record_cache?
        record_cache && record_cache.instance_variable_get('@base') == self && RecordCache::Base.status == RecordCache::ENABLED
      end

      # Returns the RecordCache (class) instance
      def record_cache
        @rc_dispatcher
      end

      def inherited_with_record_cache(subclass)
        class << subclass
          def record_cache
            self.superclass.record_cache
          end
        end
        inherited_without_record_cache(subclass)
      end
    end

    module InstanceMethods
      def record_cache_create
        self.class.record_cache.record_change(self, :create) unless RecordCache::Base.status == RecordCache::DISABLED
      end

      def record_cache_update
        self.class.record_cache.record_change(self, :update) unless RecordCache::Base.status == RecordCache::DISABLED
      end

      def record_cache_destroy
        self.class.record_cache.record_change(self, :destroy) unless RecordCache::Base.status == RecordCache::DISABLED
      end
    end

  end
end