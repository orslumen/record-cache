module RecordCache
  module Strategy
    class IdCache < Base
  
      # Can the cache retrieve the records based on this query?
      def cacheable?(query)
        ids = query.where_ids(:id)
        ids && (query.limit.nil? || (query.limit == 1 && ids.size == 1))
      end
  
      # Update the version store and the record store
      def record_change(record, action)
        key = cache_key(record.id)
        if action == :destroy
          version_store.delete(key)
        else
          # update the version store and add the record to the cache
          new_version = version_store.increment(key)
          record_store.write(versioned_key(key, new_version), Util.serialize(record))
        end
      end

      # Handle invalidation call
      def invalidate(id)
        version_store.delete(cache_key(id))
      end
  
      protected
  
      # retrieve the record(s) with the given id(s) as an array
      def fetch_records(query)
        ids = query.where_ids(:id)
        query.wheres.delete(:id) # make sure CacheCase.filter! does not see this where anymore
        id_to_key_map = ids.inject({}){|h,id| h[id] = cache_key(id); h }
        # retrieve the current version of the records
        current_versions = version_store.current_multi(id_to_key_map)
        # get the keys for the records for which a current version was found
        id_to_version_key_map = Hash[id_to_key_map.map{ |id, key| current_versions[id] ? [id, versioned_key(key, current_versions[id])] : nil }]
        # retrieve the records from the cache
        records = id_to_version_key_map.size > 0 ? from_cache(id_to_version_key_map) : []
        # query the records with missing ids
        id_to_key_map.except!(*records.map(&:id))
        # logging (only in debug mode!) and statistics
        log_id_cache_hit(ids, id_to_key_map.keys) if RecordCache::Base.logger.debug?
        statistics.add(ids.size, records.size) if statistics.active?
        # retrieve records from DB in case there are some missing ids
        records += from_db(id_to_key_map, id_to_version_key_map) if id_to_key_map.size > 0
        # return the array
        records
      end
  
      private
  
      # ---------------------------- Querying ------------------------------------

      # retrieve the records from the cache with the given keys
      def from_cache(id_to_versioned_key_map)
        records = record_store.read_multi(*(id_to_versioned_key_map.values)).values.compact
        records.map{ |record| Util.deserialize(record) }
      end
    
      # retrieve the records with the given ids from the database
      def from_db(id_to_key_map, id_to_version_key_map)
        RecordCache::Base.without_record_cache do
          # retrieve the records from the database
          records = @base.where(:id => id_to_key_map.keys).to_a
          records.each do |record|
            versioned_key = id_to_version_key_map[record.id]
            unless versioned_key
              # renew the key in the version store in case it was missing
              key = id_to_key_map[record.id]
              versioned_key = versioned_key(key, version_store.renew(key))
            end
            # store the record based on the versioned key
            record_store.write(versioned_key, Util.serialize(record))
          end
          records
        end
      end
  
      # ------------------------- Utility methods ----------------------------
  
      # log cache hit/miss to debug log
      def log_id_cache_hit(ids, missing_ids)
        hit = missing_ids.empty? ? "hit" : ids.size == missing_ids.size ? "miss" : "partial hit"
        missing = missing_ids.empty? || ids.size == missing_ids.size ? "" : ": missing #{missing_ids.inspect}"
        msg = "IdCache #{hit} for ids #{ids.size == 1 ? ids.first : ids.inspect}#{missing}"
        RecordCache::Base.logger.debug(msg)
      end

    end
  end
end
