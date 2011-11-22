# coding: utf-8
ActiveRecord::Schema.define :version => 1 do
  
  # Make sure that at the beginning of the tests, NOTHING is known to Record Cache
  RecordCache::Base.disable!
  
  @adam = Person.create!(:name => "Adam", :birthday => Date.civil(1975,03,20), :height => 1.83)
  @blue = Person.create!(:name => "Blue", :birthday => Date.civil(1953,11,11), :height => 1.75)
  @cris = Person.create!(:name => "Cris", :birthday => Date.civil(1975,03,20), :height => 1.75)

  @adam_apples = Store.create!(:name => "Adams Apple Store", :owner => @adam)
  @blue_fruits = Store.create!(:name => "Blue Fruits", :owner => @blue)
  @cris_bananas = Store.create!(:name => "Chris Bananas", :owner => @cris)

  @adam_apples_address = Address.create!(:name => "101 1st street", :store => @adam_apples)
  @blue_fruits_address = Address.create!(:name => "102 1st street", :store => @blue_fruits)
  @cris_bananas_address = Address.create!(:name => "103 1st street", :store => @cris_bananas)

  @fry = Person.create!(:name => "Fry", :birthday => Date.civil(1985,01,20), :height => 1.69)
  @chase = Person.create!(:name => "Chase", :birthday => Date.civil(1970,07,03), :height => 1.91)
  @penny = Person.create!(:name => "Penny", :birthday => Date.civil(1958,04,16), :height => 1.61)

  Apple.create!(:name => "Adams Apple 1", :store => @adam_apples)
  Apple.create!(:name => "Adams Apple 2", :store => @adam_apples)
  Apple.create!(:name => "Adams Apple 3", :store => @adam_apples, :person => @fry)
  Apple.create!(:name => "Adams Apple 4", :store => @adam_apples, :person => @fry)
  Apple.create!(:name => "Adams Apple 5", :store => @adam_apples, :person => @chase)
  Apple.create!(:name => "Blue Apple 1", :store => @blue_fruits, :person => @fry)
  Apple.create!(:name => "Blue Apple 2", :store => @blue_fruits, :person => @fry)
  Apple.create!(:name => "Blue Apple 3", :store => @blue_fruits, :person => @chase)
  Apple.create!(:name => "Blue Apple 4", :store => @blue_fruits, :person => @chase)

  Banana.create!(:name => "Blue Banana 1", :store => @blue_fruits, :person => @fry)
  Banana.create!(:name => "Blue Banana 2", :store => @blue_fruits, :person => @chase)
  Banana.create!(:name => "Blue Banana 3", :store => @blue_fruits, :person => @chase)
  Banana.create!(:name => "Cris Banana 1", :store => @cris_bananas, :person => @fry)
  Banana.create!(:name => "Cris Banana 2", :store => @cris_bananas, :person => @chase)

  Pear.create!(:name => "Blue Pear 1", :store => @blue_fruits)
  Pear.create!(:name => "Blue Pear 2", :store => @blue_fruits, :person => @fry)
  Pear.create!(:name => "Blue Pear 3", :store => @blue_fruits, :person => @chase)
  Pear.create!(:name => "Blue Pear 4", :store => @blue_fruits, :person => @chase)

  RecordCache::Base.enable
end
