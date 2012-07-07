module RecordCache
  class VersionStore
    attr_accessor :store

    def initialize(store)
	  if store.is_a?(ActiveSupport::Cache::Store) || store.is_a?(ActiveSupport::Cache::DalliStore)
        @store = store
      else 
        raise "Must be an ActiveSupport::Cache::Store"
      end
    end

    # Retrieve the current versions for the given key
    # @return nil in case the key is not known in the version store
    def current(key)
      @store.read(key)
    end

    # Retrieve the current versions for the given keys
    # @param id_key_map is a map with {id => cache_key}
    # @return a map with {id => current_version}
    # version nil for all keys unknown to the version store
    def current_multi(id_key_map)
      current_versions = @store.read_multi(*(id_key_map.values))
      Hash[id_key_map.map{ |id, key| [id, current_versions[key]] }]
    end

    # In case the version store did not have a key anymore, call this methods
    # to reset the key with a (unique) new version
    def renew(key)
      new_version = (Time.current.to_f * 10000).to_i
      @store.write(key, new_version, :raw => true)
      RecordCache::Base.logger.debug("Version Store: renew #{key}: nil => #{new_version}") if RecordCache::Base.logger.debug?
      new_version
    end

    # Increment the current version for the given key, in case of record updates
    def increment(key)
      version = @store.increment(key, 1)
      # renew key in case the version store already purged the key
      if version.nil? || version == 1
        version = renew(key)
      else
        RecordCache::Base.logger.debug("Version Store: incremented #{key}: #{version - 1} => #{version}") if RecordCache::Base.logger.debug?
      end
      version
    end
    
    # Delete key from the version store (records cached in the Record Store belonging to this key will become unreachable)
    def delete(key)
      deleted = @store.delete(key)
      RecordCache::Base.logger.debug("Version Store: deleted #{key}") if RecordCache::Base.logger.debug?
      deleted
    end

  end
end
