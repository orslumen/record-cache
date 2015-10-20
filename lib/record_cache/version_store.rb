module RecordCache
  class VersionStore
    attr_accessor :store

    def initialize(store)
      [:write, :read, :read_multi, :delete].each do |method|
        raise "Store #{store.class.name} must respond to #{method}" unless store.respond_to?(method)
      end
      @store = store
    end

    def on_write_failure(&blk)
      @on_write_failure = blk
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

    def renew_for_read(key, options = {})
      renew(key, false, options)
    end

    # Call this method to reset the key to a new (unique) version
    def renew(key, write = true, options = {})
      new_version = (Time.current.to_f * 10000).to_i
      seconds = options[:ttl] ? options[:ttl] + (rand(options[:ttl] / 2) * [1, -1].sample) : nil
      written = @store.write(key, new_version, {:expires_in => seconds})
      @on_write_failure.call(key) if !written && write && @on_write_failure
      RecordCache::Base.logger.debug{ "Version Store: renew #{key}: nil => #{new_version}" }
      new_version
    end

    # perform several actions on the version store in one go
    # Dalli: Turn on quiet aka noreply support. All relevant operations within this block will be effectively pipelined using 'quiet' operations where possible.
    #        Currently supports the set, add, replace and delete operations for Dalli cache.
    def multi(&block)
      if @store.respond_to?(:multi)
        @store.multi(&block)
      else
        yield
      end
    end

    # @deprecated: use renew instead
    def increment(key)
      RecordCache::Base.logger.debug{ "increment is deprecated, use renew instead. Called from: #{caller[0]}" }
      renew(key, true)
    end

    # Delete key from the version store (records cached in the Record Store belonging to this key will become unreachable)
    def delete(key)
      deleted = @store.delete(key)
      @on_write_failure.call(key) if !deleted && @on_write_failure
      RecordCache::Base.logger.debug{ "Version Store: deleted #{key}" }
      deleted
    end

  end
end
