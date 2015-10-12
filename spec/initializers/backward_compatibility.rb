if ActiveRecord::VERSION::MAJOR < 4

  module ActiveRecord
    class Base
      class << self
        # generic find_by introduced in Rails 4
        def find_by(*args)
          where(*args).first
        rescue RangeError
          nil
        end unless method_defined? :find_by
      end
    end
  end

  module ActiveSupport
    module Dependencies
      module Loadable
        # load without arguments in Rails 4 is similar to +to_a+ in Rails 3
        def load_with_default(*args)
          if self.respond_to?(:to_a)
            self.to_a
          else
            self.load_without_default(*args)
          end
        end
        alias_method_chain :load, :default
      end
    end
  end

end