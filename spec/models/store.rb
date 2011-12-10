class Store < ActiveRecord::Base

  cache_records :store => :local, :key => "st", :request_cache => true

  belongs_to :owner, :class_name => "Person"

  has_many :apples, :autosave => true  # cached with index on store
  has_many :bananas # cached without index on store
  has_many :pears   # not cached
  has_one :address, :autosave => true

  has_and_belongs_to_many :customers, :class_name => "Person"

end
