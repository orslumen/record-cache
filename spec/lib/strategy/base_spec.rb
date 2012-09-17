# encoding: utf-8
require 'spec_helper'

describe RecordCache::Strategy::Base do
  
  it "should provide easy access to the Version Store" do
    Apple.record_cache[:id].send(:version_store).should == RecordCache::Base.version_store
  end

  it "should provide easy access to the Record Store" do
    Apple.record_cache[:id].send(:record_store).should == RecordCache::Base.stores[:shared]
    Banana.record_cache[:id].send(:record_store).should == RecordCache::Base.stores[:local]
  end

  it "should provide easy access to the statistics" do
    Apple.record_cache[:person_id].send(:statistics).should == RecordCache::Statistics.find(Apple, :person_id)
    Banana.record_cache[:id].send(:statistics).should == RecordCache::Statistics.find(Banana, :id)
  end

  it "should retrieve the cache key based on the :key option" do
    Apple.record_cache[:id].send(:cache_key, 1).should == "rc/apl/1"
  end

  it "should retrieve the cache key based on the model name" do
    Banana.record_cache[:id].send(:cache_key, 1).should == "rc/Banana/1"
  end

  it "should define the versioned key" do
    Banana.record_cache[:id].send(:versioned_key, "rc/Banana/1", 2312423).should == "rc/Banana/1v2312423"
  end

  context "filter" do
    it "should apply filter on :id cache hits" do
      lambda{ @apples = Apple.where(:id => [1,2]).where(:name => "Adams Apple 1").all }.should use_cache(Apple).on(:id)
      @apples.should == [Apple.find_by_name("Adams Apple 1")]
    end
    
    it "should apply filter on index cache hits" do
      lambda{ @apples = Apple.where(:store_id => 1).where(:name => "Adams Apple 1").all }.should use_cache(Apple).on(:store_id)
      @apples.should == [Apple.find_by_name("Adams Apple 1")]
    end

    it "should return empty array when filter does not match any record" do
      lambda{ @apples = Apple.where(:store_id => 1).where(:name => "Adams Apple Pie").all }.should use_cache(Apple).on(:store_id)
      @apples.should == []
    end

    it "should filter on text" do
      lambda{ @apples = Apple.where(:id => [1,2]).where(:name => "Adams Apple 1").all }.should use_cache(Apple).on(:id)
      @apples.should == [Apple.find_by_name("Adams Apple 1")]
    end

    it "should filter on integers" do
      lambda{ @apples = Apple.where(:id => [1,2,8,9]).where(:store_id => 2).all }.should use_cache(Apple).on(:id)
      @apples.map(&:id).sort.should == [8,9]
    end

    it "should filter on dates" do
      lambda{ @people = Person.where(:id => [1,2,3]).where(:birthday => Date.civil(1953,11,11)).all }.should use_cache(Person).on(:id)
      @people.size.should == 1
      @people.first.name.should == "Blue"
    end

    it "should filter on floats" do
      lambda{ @people = Person.where(:id => [1,2,3]).where(:height => 1.75).all }.should use_cache(Person).on(:id)
      @people.size.should == 2
      @people.map(&:name).sort.should == ["Blue", "Cris"]
    end

    it "should filter on arrays" do
      lambda{ @apples = Apple.where(:id => [1,2,8,9]).where(:store_id => [2, 4]).all }.should use_cache(Apple).on(:id)
      @apples.map(&:id).sort.should == [8,9]
    end
    
    it "should filter on multiple fields" do
      # make sure two apples exist with the same name
      @apple = Apple.find(8)
      @apple.name = Apple.find(9).name
      @apple.save!

      lambda{ @apples = Apple.where(:id => [1,2,3,8,9,10]).where(:store_id => 2).where(:name => @apple.name).all }.should use_cache(Apple).on(:id)
      @apples.size.should == 2
      @apples.map(&:name).should == [@apple.name, @apple.name]
      @apples.map(&:id).sort.should == [8,9]
    end

  end

  context "sort" do
    it "should apply sort on :id cache hits" do
      lambda{ @people = Person.where(:id => [1,2,3]).order("name DESC").all }.should use_cache(Person).on(:id)
      @people.map(&:name).should == ["Cris", "Blue", "Adam"]
    end

    it "should apply sort on index cache hits" do
      lambda{ @apples = Apple.where(:store_id => 1).order("person_id ASC").all }.should use_cache(Apple).on(:store_id)
      @apples.map(&:person_id).should == [nil, nil, 4, 4, 5]
    end
    
    it "should default to ASC" do
      lambda{ @apples = Apple.where(:store_id => 1).order("person_id").all }.should use_cache(Apple).on(:store_id)
      @apples.map(&:person_id).should == [nil, nil, 4, 4, 5]
    end

    it "should apply sort nil first for ASC" do
      lambda{ @apples = Apple.where(:store_id => 1).order("person_id ASC").all }.should use_cache(Apple).on(:store_id)
      @apples.map(&:person_id).should == [nil, nil, 4, 4, 5]
    end

    it "should apply sort nil last for DESC" do
      lambda{ @apples = Apple.where(:store_id => 1).order("person_id DESC").all }.should use_cache(Apple).on(:store_id)
      @apples.map(&:person_id).should == [5, 4, 4, nil, nil]
    end

    it "should sort ascending on text" do
      lambda{ @people = Person.where(:id => [1,2,3,4]).order("name ASC").all }.should use_cache(Person).on(:id)
      @people.map(&:name).should == ["Adam", "Blue", "Cris", "Fry"]
    end

    it "should sort descending on text" do
      lambda{ @people = Person.where(:id => [1,2,3,4]).order("name DESC").all }.should use_cache(Person).on(:id)
      @people.map(&:name).should == ["Fry", "Cris", "Blue", "Adam"]
    end

    it "should sort ascending on integers" do
      lambda{ @people = Person.where(:id => [1,2,3,4]).order("id ASC").all }.should use_cache(Person).on(:id)
      @people.map(&:id).should == [1,2,3,4]
    end

    it "should sort descending on integers" do
      lambda{ @people = Person.where(:id => [1,2,3,4]).order("id DESC").all }.should use_cache(Person).on(:id)
      @people.map(&:id).should == [4,3,2,1]
    end

    it "should sort ascending on dates" do
      lambda{ @people = Person.where(:id => [1,2,3,4]).order("birthday ASC").all }.should use_cache(Person).on(:id)
      @people.map(&:birthday).should == [Date.civil(1953,11,11), Date.civil(1975,03,20), Date.civil(1975,03,20), Date.civil(1985,01,20)]
    end

    it "should sort descending on dates" do
      lambda{ @people = Person.where(:id => [1,2,3,4]).order("birthday DESC").all }.should use_cache(Person).on(:id)
      @people.map(&:birthday).should == [Date.civil(1985,01,20), Date.civil(1975,03,20), Date.civil(1975,03,20), Date.civil(1953,11,11)]
    end

    it "should sort ascending on float" do
      lambda{ @people = Person.where(:id => [1,2,3,4]).order("height ASC").all }.should use_cache(Person).on(:id)
      @people.map(&:height).should == [1.69, 1.75, 1.75, 1.83]
    end

    it "should sort descending on float" do
      lambda{ @people = Person.where(:id => [1,2,3,4]).order("height DESC").all }.should use_cache(Person).on(:id)
      @people.map(&:height).should == [1.83, 1.75, 1.75, 1.69]
    end

    it "should sort on multiple fields (ASC + ASC)" do
      lambda{ @people = Person.where(:id => [2,3,4,5]).order("height ASC, id ASC").all }.should use_cache(Person).on(:id)
      @people.map(&:height).should == [1.69, 1.75, 1.75, 1.91]
      @people.map(&:id).should == [4, 2, 3, 5]
    end

    it "should sort on multiple fields (ASC + DESC)" do
      lambda{ @people = Person.where(:id => [2,3,4,5]).order("height ASC, id DESC").all }.should use_cache(Person).on(:id)
      @people.map(&:height).should == [1.69, 1.75, 1.75, 1.91]
      @people.map(&:id).should == [4, 3, 2, 5]
    end

    it "should sort on multiple fields (DESC + ASC)" do
      lambda{ @people = Person.where(:id => [2,3,4,5]).order("height DESC, id ASC").all }.should use_cache(Person).on(:id)
      @people.map(&:height).should == [1.91, 1.75, 1.75, 1.69]
      @people.map(&:id).should == [5, 2, 3, 4]
    end

    it "should sort on multiple fields (DESC + DESC)" do
      lambda{ @people = Person.where(:id => [2,3,4,5]).order("height DESC, id DESC").all }.should use_cache(Person).on(:id)
      @people.map(&:height).should == [1.91, 1.75, 1.75, 1.69]
      @people.map(&:id).should == [5, 3, 2, 4]
    end
    
    it "should use mysql style collation" do
      ids = []
      ids << Person.create!(:name => "ċedriĉ 3").id # latin other special
      ids << Person.create!(:name => "a cedric").id # first in ascending order
      ids << Person.create!(:name => "čedriĉ 4").id # latin another special
      ids << Person.create!(:name => "ćedriĉ Last").id # latin special lowercase
      ids << Person.create!(:name => "sedric 1").id # second to last latin in ascending order 
      ids << Person.create!(:name => "Cedric 2").id # ascii uppercase
      ids << Person.create!(:name => "čedriĉ คฉ Almost last cedric").id # latin special, with non-latin
      ids << Person.create!(:name => "Sedric 2").id # last latin in ascending order
      ids << Person.create!(:name => "1 cedric").id # numbers before characters
      ids << Person.create!(:name => "cedric 1").id # ascii lowercase
      ids << Person.create!(:name => "คฉ Really last").id # non-latin characters last in ascending order
      ids << Person.create!(:name => "čedriĉ ꜩ Last").id # latin special, with latin non-collateable

      names_asc = ["1 cedric", "a cedric", "cedric 1", "Cedric 2", "ċedriĉ 3", "čedriĉ 4", "ćedriĉ Last", "čedriĉ คฉ Almost last cedric", "čedriĉ ꜩ Last", "sedric 1", "Sedric 2",  "คฉ Really last"]
      lambda{ @people = Person.where(:id => ids).order("name ASC").all }.should hit_cache(Person).on(:id).times(ids.size)
      @people.map(&:name).should == names_asc

      lambda{ @people = Person.where(:id => ids).order("name DESC").all }.should hit_cache(Person).on(:id).times(ids.size)
      @people.map(&:name).should == names_asc.reverse
    end
  end

  it "should combine filter and sort" do
    lambda{ @people = Person.where(:id => [1,2,3]).where(:height => 1.75).order("name DESC").all }.should use_cache(Person).on(:id)
    @people.size.should == 2
    @people.map(&:name).should == ["Cris", "Blue"]

    lambda{ @people = Person.where(:id => [1,2,3]).where(:height => 1.75).order("name").all }.should hit_cache(Person).on(:id).times(3)
    @people.map(&:name).should == ["Blue", "Cris"]
  end
  
  context "NotImplementedError" do
    before(:each) do
      @invalid_strategy = RecordCache::Strategy::Base.new(Object, nil, nil, {:key => "key"})
    end

    it "should require record_change to be implemented" do
      lambda { @invalid_strategy.record_change(Object.new, 1) }.should raise_error(NotImplementedError)
    end

    it "should require cacheable? to be implemented" do
      lambda { @invalid_strategy.cacheable?(RecordCache::Query.new) }.should raise_error(NotImplementedError)
    end

    it "should require invalidate to be implemented" do
      lambda { @invalid_strategy.invalidate(1) }.should raise_error(NotImplementedError)
    end

    it "should fetch_records to be implemented" do
      lambda { @invalid_strategy.fetch(RecordCache::Query.new) }.should raise_error(NotImplementedError)
    end
  end
end
