class Apple < ActiveRecord::Base
  cache_records :store => :shared, :key => "apl", :index => [:store_id, :person_id], :ttl => 300

  belongs_to :store
  belongs_to :person

end
