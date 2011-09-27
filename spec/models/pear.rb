class Pear < ActiveRecord::Base
  
  belongs_to :store
  belongs_to :person
  
end
