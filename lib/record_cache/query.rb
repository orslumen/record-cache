module RecordCache

  # Container for the Query parameters
  class Query
    attr_reader :wheres, :sort_orders, :limit

    def initialize(equality = nil)
      @wheres = equality || {}
      @sort_orders = []
      @limit = nil
      @where_values = {}
    end

    # Set equality of an attribute (usually found in where clause)
    def where(attribute, values)
      @wheres[attribute.to_sym] = values if attribute
    end

    # Retrieve the values for the given attribute from the where statements
    # Returns nil if no the attribute is not present
    # @param attribute: the attribute name
    # @param type: the type to be retrieved, :integer or :string (defaults to :integer)
    def where_values(attribute, type = :integer)
      return @where_values[attribute] if @where_values.key?(attribute)
      @where_values[attribute] ||= array_of_values(@wheres[attribute], type)
    end

    # Retrieve the single value for the given attribute from the where statements
    # Returns nil if the attribute is not present, or if it contains multiple values
    # @param attribute: the attribute name
    # @param type: the type to be retrieved, :integer or :string (defaults to :integer)
    def where_value(attribute, type = :integer)
      values = where_values(attribute, type)
      return nil unless values && values.size == 1
      values.first
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
      if sorted?
        order_by_clause = @sort_orders.map{|attr,asc| "#{attr} #{asc ? 'ASC' : 'DESC'}"}.join(', ')
        s << " ORDER_BY #{order_by_clause}"
      end
      s << " LIMIT #{@limit}" if @limit
      s
    end

    private

    def generate_key
      key = ""
      key << @limit.to_s if @limit
      key << @sort_orders.map{|attr,asc| "#{asc ? '+' : '-'}#{attr}"}.join if sorted?
      if @wheres.any?
        key << "?"
        key << @wheres.map{|k,v| "#{k}=#{v.inspect}"}.join("&")
      end
      key
    end

    def array_of_values(values, type)
      return nil unless values
      values = [values] unless values.is_a?(Array)
      if type == :integer
        values = values.map{|value| value.to_i} unless values.first.is_a?(Fixnum)
        return nil unless values.all?{ |value| value > 0 } # all values must be positive integers
      elsif type == :string
        values = values.map{|value| value.to_s} unless values.first.is_a?(String)
      end
      values
    end

  end
end
