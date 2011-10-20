module RecordCache

  # Container for the Query parameters
  class Query
    attr_reader :wheres, :sort_orders, :limit

    def initialize(equality = nil)
      @wheres = equality || {}
      @sort_orders = []
      @limit = nil
      @where_ids = {}
    end

    # Set equality of an attribute (usually found in where clause)
    def where(attribute, values)
      @wheres[attribute.to_sym] = values if attribute
    end

    # Retrieve the ids (array of positive integers) for the given attribute from the where statements
    # Returns nil if no the attribute is not present
    def where_ids(attribute)
      return @where_ids[attribute] if @where_ids.key?(attribute)
      @where_ids[attribute] ||= array_of_positive_integers(@wheres[attribute])
    end

    # Retrieve the single id (positive integer) for the given attribute from the where statements
    # Returns nil if no the attribute is not present, or if it contains an array
    def where_id(attribute)
      ids = where_ids(attribute)
      return nil unless ids && ids.size == 1
      ids.first
    end

    # Add a sort order to the query
    def order_by(attribute, ascending = true)
      @sort_orders << [attribute.to_s, ascending]
    end

    def sorted?
      @sort_orders.size > 0
    end

    def limit=(limit)
      @limit = limit.to_i
    end

    # retrieve a unique key for this Query (used in RequestCache)
    def cache_key
      @cache_key ||= generate_key
    end

    def to_s
      s = "SELECT "
      s << @wheres.map{|k,v| "#{k} = #{v.inspect}"}.join(" AND ")
      if @sort_orders.size > 0
        order_by = @sort_orders.map{|attr,asc| "#{attr} #{asc ? 'ASC' : 'DESC'}"}.join(', ')
        s << " ORDER_BY #{order_by}"
      end
      s << " LIMIT #{@limit}" if @limit
      s
    end

    private

    def generate_key
      key = @wheres.map{|k,v| "#{k}=#{v.inspect}"}.join("&")
      if @sort_orders
        order_by = @sort_orders.map{|attr,asc| "#{attr}=#{asc ? 'A' : 'D'}"}.join('-')
        key << ".#{order_by}"
      end
      key << "L#{@limit}" if @limit
      key
    end
    
    def array_of_positive_integers(values)
      return nil unless values
      values = [values] unless values.is_a?(Array)
      values = values.map{|value| value.to_i} unless values.first.is_a?(Fixnum)
      return nil unless values.all?{ |value| value > 0 } # all values must be positive integers
      values
    end

  end
end
