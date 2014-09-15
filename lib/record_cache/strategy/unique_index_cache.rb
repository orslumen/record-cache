module RecordCache
  module Strategy
    class UniqueIndexCache < Base

      # All attributes with a unique index for the given model
      def self.attributes(base)
        (@attributes ||= {})[base.name] ||= []
      end

      # parse the options and return (an array of) instances of this strategy
      def self.parse(base, record_store, options)
        return nil unless base.table_exists?
        
        attributes = [options[:unique_index]].flatten.compact
        # add unique index for :id by default
        attributes << :id if base.columns_hash['id'] unless base.record_cache[:id]
        attributes.uniq! # in development mode, do not keep adding 'id' to the list of unique index attributes
        return nil if attributes.empty?
        attributes.map do |attribute|
          type = base.columns_hash[attribute.to_s].try(:type)
          raise "No column found for unique index '#{index}' on #{base.name}." unless type
          raise "Incorrect type (expected string or integer, found #{type}) for unique index '#{attribute}' on #{base.name}." unless type == :string || type == :integer
          UniqueIndexCache.new(base, attribute, record_store, options, type)
        end
      end

      def initialize(base, attribute, record_store, options, type)
        super(base, attribute, record_store, options)
        # remember the attributes with a unique index
        UniqueIndexCache.attributes(base) << attribute
        # for unique indexes that are not on the :id column, use key: rc/<key or model name>/<attribute>:
        @cache_key_prefix << "#{attribute}:" unless attribute == :id
        @type = type
      end

      # Can the cache retrieve the records based on this query?
      def cacheable?(query)
        values = query.where_values(@attribute, @type)
        values && (query.limit.nil? || (query.limit == 1 && values.size == 1))
      end

      # Update the version store and the record store
      def record_change(record, action)
        key = cache_key(record.send(@attribute))
        if action == :destroy
          version_store.delete(key)
        else
          # update the version store and add the record to the cache
          new_version = version_store.renew(key, version_opts)
          record_store.write(versioned_key(key, new_version), Util.serialize(record))
        end
      end

      protected

      # retrieve the record(s) with the given id(s) as an array
      def fetch_records(query)
        ids = query.where_values(@attribute, @type)
        query.wheres.delete(@attribute) # make sure CacheCase.filter! does not see this where anymore
        id_to_key_map = ids.inject({}){|h,id| h[id] = cache_key(id); h }
        # retrieve the current version of the records
        current_versions = version_store.current_multi(id_to_key_map)
        # get the keys for the records for which a current version was found
        id_to_version_key_map = Hash[id_to_key_map.map{ |id, key| current_versions[id] ? [id, versioned_key(key, current_versions[id])] : nil }.compact]
        # retrieve the records from the cache
        records = id_to_version_key_map.size > 0 ? from_cache(id_to_version_key_map) : []
        # query the records with missing ids
        id_to_key_map.except!(*records.map(&@attribute))
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
        records.map do |record|
          record = Util.deserialize(record)
          record.becomes(self.instance_variable_get('@base'))
        end
      end

      # retrieve the records with the given ids from the database
      def from_db(id_to_key_map, id_to_version_key_map)
        # skip record cache itself
        RecordCache::Base.without_record_cache do
          # set version store in multi-mode
          RecordCache::Base.version_store.multi do
            # set record store in multi-mode
            record_store.multi do
              # retrieve the records from the database
              records = @base.where(@attribute => id_to_key_map.keys).to_a
              records.each do |record|
                versioned_key = id_to_version_key_map[record.send(@attribute)]
                unless versioned_key
                  # renew the key in the version store in case it was missing
                  key = id_to_key_map[record.send(@attribute)]
                  versioned_key = versioned_key(key, version_store.renew(key, version_opts))
                end
                # store the record based on the versioned key
                record_store.write(versioned_key, Util.serialize(record))
              end
              records
            end
          end
        end
      end

      # ------------------------- Utility methods ----------------------------

      # log cache hit/miss to debug log
      def log_id_cache_hit(ids, missing_ids)
        hit = missing_ids.empty? ? "hit" : ids.size == missing_ids.size ? "miss" : "partial hit"
        missing = missing_ids.empty? || ids.size == missing_ids.size ? "" : ": missing #{missing_ids.inspect}"
        msg = "UniqueIndexCache on '#{@base.name}.#{@attribute}' #{hit} for ids #{ids.size == 1 ? ids.first.inspect : ids.inspect}#{missing}"
        RecordCache::Base.logger.debug{ msg }
      end

    end
  end
end
