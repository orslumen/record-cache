class Address < ActiveRecord::Base

  cache_records :store => :shared, :key => "add", :index => [:store_id]

  belongs_to :store

end
