class Person < ActiveRecord::Base
  
  cache_records :store => :shared, :key => "per", :unique_index => :name

  has_many :apples  # cached with index on person_id
  has_many :bananas # cached with index on person_id
  has_many :pears   # not cached

  has_and_belongs_to_many :stores

end
