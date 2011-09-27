class Apple < ActiveRecord::Base
  
  cache_records :store => :shared, :key => "apl", :index => [:store_id, :person_id]

  belongs_to :store
  belongs_to :person
  
end
