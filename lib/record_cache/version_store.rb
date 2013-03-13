module RecordCache
  class VersionStore
    attr_accessor :store

    def initialize(store)
      [:increment, :write, :read, :read_multi, :delete].each do |method|
        raise "Store #{store.class.name} must respond to #{method}" unless store.respond_to?(method)
      end
      @store = store
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
    def renew(key, options = {})
      new_version = (Time.current.to_f * 10000).to_i
      options[:ttl] += (rand(options[:ttl] / 2) * [1, -1].random) if options[:ttl]
      @store.write(key, new_version, {:raw => true, :expires_in => options[:ttl]})
      RecordCache::Base.logger.debug("Version Store: renew #{key}: nil => #{new_version}") if RecordCache::Base.logger.debug?
      new_version
    end

    # Increment the current version for the given key, in case of record updates
    def increment(key)
      new_version = (Time.current.to_f * 10000).to_i
      version = @store.increment(key, 1, :initial => new_version)
      # renew key in case the version store already purged the key
      if version.nil? || version == 1
        version = renew(key)
      elsif version == new_version
        # only log statement in case the :initial option was supported by the cache store
        RecordCache::Base.logger.debug{ "Version Store: renew #{key}: nil => #{new_version}" }
      else
        RecordCache::Base.logger.debug{ "Version Store: incremented #{key}: #{version - 1} => #{version}" }
      end
      version
    end
    
    # Delete key from the version store (records cached in the Record Store belonging to this key will become unreachable)
    def delete(key)
      deleted = @store.delete(key)
      RecordCache::Base.logger.debug{ "Version Store: deleted #{key}" }
      deleted
    end

  end
end
