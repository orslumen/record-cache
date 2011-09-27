class Banana < ActiveRecord::Base
  
  cache_records :store => :local, :index => [:person_id]

  belongs_to :store
  belongs_to :person
  
end
