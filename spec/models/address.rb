class Address < ActiveRecord::Base

  cache_records :store => :shared, :key => "add", :index => [:store_id]

  serialize :location, Hash

  belongs_to :store

end
