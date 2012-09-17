module RecordCache
  module ActiveRecord

    module Base
      class << self
        def included(klass)
          klass.extend ClassMethods
          klass.class_eval do
            class << self
              alias_method_chain :find_by_sql, :record_cache
            end
          end
          include InstanceMethods
        end
      end

      module ClassMethods

        # add cache invalidation hooks on initialization
        def record_cache_init
          after_commit :record_cache_create,  :on => :create
          after_commit :record_cache_update,  :on => :update
          after_commit :record_cache_destroy, :on => :destroy
        end
  
        # Retrieve the records, possibly from cache
        def find_by_sql_with_record_cache(*args)
           # no caching please
          return find_by_sql_without_record_cache(*args) unless record_cache?

          # check the piggy-back'd ActiveRelation record to see if the query can be retrieved from cache
          sql = args[0]
          arel = sql.instance_variable_get(:@arel)
          query = arel ? RecordCache::Arel::QueryVisitor.new.accept(arel.ast) : nil
          cacheable = query && record_cache.cacheable?(query)
          # log only in debug mode!
          RecordCache::Base.logger.debug{ "#{cacheable ? 'Fetch from cache' : 'Not cacheable'} (#{query}): SQL = #{sql}" }
          # retrieve the records from cache if the query is cacheable otherwise go straight to the DB
          cacheable ? record_cache.fetch(query) : find_by_sql_without_record_cache(*args)
        end
      end

      module InstanceMethods
      end
    end
  end

  module Arel

    # The method <ActiveRecord::Base>.find_by_sql is used to actually
    # retrieve the data from the DB.
    # Unfortunately the ActiveRelation record is not accessible from
    # there, so it is piggy-back'd in the SQL string.
    module TreeManager
      def self.included(klass)
        klass.extend ClassMethods
        klass.send(:include, InstanceMethods)
        klass.class_eval do
          alias_method_chain :to_sql, :record_cache
        end
      end

      module ClassMethods
      end
  
      module InstanceMethods
        def to_sql_with_record_cache
          sql = to_sql_without_record_cache
          sql.instance_variable_set(:@arel, self)
          sql
        end
      end
    end
    
    # Visitor for the ActiveRelation to extract a simple cache query
    # Only accepts single select queries with equality where statements
    # Rejects queries with grouping / having / offset / etc.
    class QueryVisitor < ::Arel::Visitors::Visitor
      def initialize
        super()
        @cacheable  = true
        @query = ::RecordCache::Query.new
      end

      def accept ast
        super
        @cacheable && !ast.lock ? @query : nil
      end

      private

      def not_cacheable o
        @cacheable = false
      end

      alias :visit_Arel_Nodes_Ordering :not_cacheable
      
      alias :visit_Arel_Nodes_TableAlias :not_cacheable

      alias :visit_Arel_Nodes_Lock :not_cacheable

      alias :visit_Arel_Nodes_Sum   :not_cacheable
      alias :visit_Arel_Nodes_Max   :not_cacheable
      alias :visit_Arel_Nodes_Avg   :not_cacheable
      alias :visit_Arel_Nodes_Count :not_cacheable

      alias :visit_Arel_Nodes_StringJoin :not_cacheable
      alias :visit_Arel_Nodes_InnerJoin  :not_cacheable
      alias :visit_Arel_Nodes_OuterJoin  :not_cacheable

      alias :visit_Arel_Nodes_DeleteStatement  :not_cacheable
      alias :visit_Arel_Nodes_InsertStatement  :not_cacheable
      alias :visit_Arel_Nodes_UpdateStatement  :not_cacheable


      alias :unary                              :not_cacheable
      alias :visit_Arel_Nodes_Group             :unary
      alias :visit_Arel_Nodes_Having            :unary
      alias :visit_Arel_Nodes_Not               :unary
      alias :visit_Arel_Nodes_On                :unary
      alias :visit_Arel_Nodes_UnqualifiedColumn :unary

      def visit_Arel_Nodes_Offset o
        @cacheable = false unless o.expr == 0
      end

      def visit_Arel_Nodes_Values o
        visit o.expressions if @cacheable
      end

      def visit_Arel_Nodes_Limit o
        @query.limit = o.expr
      end
      alias :visit_Arel_Nodes_Top :visit_Arel_Nodes_Limit

      def visit_Arel_Nodes_Grouping o
        return unless @cacheable
        # "`calendars`.account_id = 5"
        if @table_name && o.expr =~ /^`#{@table_name}`\.`?(\w*)`?\s*=\s*(\d+)$/
          @cacheable = @query.where($1, $2.to_i)
        # "`service_instances`.`id` IN (118,80,120,82)"
        elsif o.expr =~ /^`#{@table_name}`\.`?(\w*)`?\s*IN\s*\(([\d\s,]+)\)$/
          @cacheable = @query.where($1, $2.split(',').map(&:to_i))
        else
          @cacheable = false
        end
      end

      def visit_Arel_Nodes_SelectCore o
        @cacheable = false unless o.groups.empty?
        visit o.froms  if @cacheable
        visit o.wheres if @cacheable
        # skip o.projections
      end

      def visit_Arel_Nodes_SelectStatement o
        @cacheable = false if o.cores.size > 1
        if @cacheable
          visit o.offset
          o.orders.map { |x| handle_order_by(visit x) } if @cacheable && o.orders.size > 0
          visit o.limit
          visit o.cores
        end
      end
      
      def handle_order_by(order)
        order.to_s.split(",").each do |o|
          # simple sort order (+peope.id+ can be replaced by +id+, as joins are not allowed anyways)
          if o.match(/^\s*([\w\.]*)\s*(|ASC|DESC|)\s*$/)
            asc = $2 == "DESC" ? false : true
            @query.order_by($1.split('.').last, asc)
          else
            @cacheable = false
          end
        end
      end

      def visit_Arel_Table o
        @table_name = o.name
      end

      def visit_Arel_Nodes_Ordering o
        [visit(o.expr), o.descending]
      end

      def visit_Arel_Attributes_Attribute o
        o.name.to_sym
      end
      alias :visit_Arel_Attributes_Integer   :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Float     :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_String    :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Time      :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Boolean   :visit_Arel_Attributes_Attribute

      def visit_Arel_Nodes_Equality o
        key, value = visit(o.left), visit(o.right)
#        p "  =====> equality found: #{key.inspect}@#{key.class.name} => #{value.inspect}@#{value.class.name}"
        @query.where(key, value)
      end
      alias :visit_Arel_Nodes_In                 :visit_Arel_Nodes_Equality

      def visit_Arel_Nodes_And o
        visit(o.left)
        visit(o.right)
      end

      alias :visit_Arel_Nodes_Or                 :not_cacheable
      alias :visit_Arel_Nodes_NotEqual           :not_cacheable
      alias :visit_Arel_Nodes_GreaterThan        :not_cacheable
      alias :visit_Arel_Nodes_GreaterThanOrEqual :not_cacheable
      alias :visit_Arel_Nodes_Assignment         :not_cacheable
      alias :visit_Arel_Nodes_LessThan           :not_cacheable
      alias :visit_Arel_Nodes_LessThanOrEqual    :not_cacheable
      alias :visit_Arel_Nodes_Between            :not_cacheable
      alias :visit_Arel_Nodes_NotIn              :not_cacheable
      alias :visit_Arel_Nodes_DoesNotMatch       :not_cacheable
      alias :visit_Arel_Nodes_Matches            :not_cacheable

      def visit_Fixnum o
        o.to_i
      end
      alias :visit_Bignum :visit_Fixnum

      def visit_Symbol o
        o.to_sym
      end

      def visit_Object o
        o
      end
      alias :visit_Arel_Nodes_SqlLiteral :visit_Object
      alias :visit_Arel_SqlLiteral :visit_Object # This is deprecated
      alias :visit_String :visit_Object
      alias :visit_NilClass :visit_Object
      alias :visit_TrueClass :visit_Object
      alias :visit_FalseClass :visit_Object
      alias :visit_Arel_SqlLiteral :visit_Object
      alias :visit_BigDecimal :visit_Object
      alias :visit_Float :visit_Object
      alias :visit_Time :visit_Object
      alias :visit_Date :visit_Object
      alias :visit_DateTime :visit_Object
      alias :visit_Hash :visit_Object

      def visit_Array o
        o.map{ |x| visit x }
      end
    end
  end

end

module RecordCache
  
  # Patch ActiveRecord::Relation to make sure update_all will invalidate all referenced records
  module ActiveRecord
    module UpdateAll
      class << self
        def included(klass)
          klass.extend ClassMethods
          klass.send(:include, InstanceMethods)
          klass.class_eval do
            alias_method_chain :update_all, :record_cache
          end
        end
      end
  
      module ClassMethods
      end

      module InstanceMethods
        def update_all_with_record_cache(updates, conditions = nil, options = {})
          result = update_all_without_record_cache(updates, conditions, options)

          if record_cache?
            # when this condition is met, the arel.update method will be called on the current scope, see ActiveRecord::Relation#update_all
            unless conditions || options.present? || @limit_value.present? != @order_values.present?
              # get all attributes that contian a unique index for this model
              unique_index_attributes = RecordCache::Strategy::UniqueIndexCache.attributes(self)
              # go straight to SQL result (without instantiating records) for optimal performance
              connection.execute(select(unique_index_attributes.map(&:to_s).join(',')).to_sql).each do |row|
                # invalidate the unique index for all attributes
                unique_index_attributes.each_with_index do |attribute, index|
                  record_cache.invalidate(attribute, (row.is_a?(Hash) ? row[attribute.to_s] : row[index]) )
                end
              end
            end
          end

          result
        end
      end
    end
  end

  # Patch ActiveRecord::Associations::HasManyAssociation to make sure the index_cache is updated when records are
  # deleted from the collection
  module ActiveRecord
    module HasMany
      class << self
        def included(klass)
          klass.extend ClassMethods
          klass.send(:include, InstanceMethods)
          klass.class_eval do
            alias_method_chain :delete_records, :record_cache
          end
        end
      end

      module ClassMethods
      end

      module InstanceMethods
        def delete_records_with_record_cache(records)
          # invalidate :id cache for all records
          records.each{ |record| record.class.record_cache.invalidate(record.id) if record.class.record_cache? unless record.new_record? }
          # invalidate the referenced class for the attribute/value pair on the index cache
          @reflection.klass.record_cache.invalidate(@reflection.primary_key_name.to_sym, @owner.id) if @reflection.klass.record_cache?
          delete_records_without_record_cache(records)
        end
      end
    end
  end

end

ActiveRecord::Base.send(:include, RecordCache::ActiveRecord::Base)
Arel::TreeManager.send(:include, RecordCache::Arel::TreeManager)
ActiveRecord::Relation.send(:include, RecordCache::ActiveRecord::UpdateAll)
ActiveRecord::Associations::HasManyAssociation.send(:include, RecordCache::ActiveRecord::HasMany)
