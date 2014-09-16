# encoding: utf-8
require 'spec_helper'

describe RecordCache::Strategy::Base do

  it "should force implementation of self.parse method" do
    module RecordCache
      module Strategy
        class MissingParseCache < Base
        end
      end
    end
    expect{ RecordCache::Strategy::MissingParseCache.parse(1,2,3) }.to raise_error(NotImplementedError)
  end

  it "should provide easy access to the Version Store" do
    expect(Apple.record_cache[:id].send(:version_store)).to eq(RecordCache::Base.version_store)
  end

  it "should provide easy access to the Record Store" do
    expect(Apple.record_cache[:id].send(:record_store)).to eq(RecordCache::Base.stores[:shared])
    expect(Banana.record_cache[:id].send(:record_store)).to eq(RecordCache::Base.stores[:local])
  end

  it "should provide easy access to the statistics" do
    expect(Apple.record_cache[:person_id].send(:statistics)).to eq(RecordCache::Statistics.find(Apple, :person_id))
    expect(Banana.record_cache[:id].send(:statistics)).to eq(RecordCache::Statistics.find(Banana, :id))
  end

  it "should retrieve the cache key based on the :key option" do
    expect(Apple.record_cache[:id].send(:cache_key, 1)).to eq("rc/apl/1")
  end

  it "should retrieve the cache key based on the model name" do
    expect(Banana.record_cache[:id].send(:cache_key, 1)).to eq("rc/Banana/1")
  end

  it "should define the versioned key" do
    expect(Banana.record_cache[:id].send(:versioned_key, "rc/Banana/1", 2312423)).to eq("rc/Banana/1v2312423")
  end

  it "should provide the version_opts" do
    expect(Apple.record_cache[:id].send(:version_opts)).to eq({:ttl => 300})
    expect(Banana.record_cache[:id].send(:version_opts)).to eq({})
  end

  context "filter" do
    it "should apply filter on :id cache hits" do
      expect{ @apples = Apple.where(:id => [1,2]).where(:name => "Adams Apple 1").all }.to use_cache(Apple).on(:id)
      expect(@apples).to eq([Apple.find_by_name("Adams Apple 1")])
    end
    
    it "should apply filter on index cache hits" do
      expect{ @apples = Apple.where(:store_id => 1).where(:name => "Adams Apple 1").all }.to use_cache(Apple).on(:store_id)
      expect(@apples).to eq([Apple.find_by_name("Adams Apple 1")])
    end

    it "should return empty array when filter does not match any record" do
      expect{ @apples = Apple.where(:store_id => 1).where(:name => "Adams Apple Pie").all }.to use_cache(Apple).on(:store_id)
      expect(@apples).to be_empty
    end

    it "should filter on text" do
      expect{ @apples = Apple.where(:id => [1,2]).where(:name => "Adams Apple 1").all }.to use_cache(Apple).on(:id)
      expect(@apples).to eq([Apple.find_by_name("Adams Apple 1")])
    end

    it "should filter on integers" do
      expect{ @apples = Apple.where(:id => [1,2,8,9]).where(:store_id => 2).all }.to use_cache(Apple).on(:id)
      expect(@apples.map(&:id).sort).to eq([8,9])
    end

    it "should filter on dates" do
      expect{ @people = Person.where(:id => [1,2,3]).where(:birthday => Date.civil(1953,11,11)).all }.to use_cache(Person).on(:id)
      expect(@people.size).to eq(1)
      expect(@people.first.name).to eq("Blue")
    end

    it "should filter on floats" do
      expect{ @people = Person.where(:id => [1,2,3]).where(:height => 1.75).all }.to use_cache(Person).on(:id)
      expect(@people.size).to eq(2)
      expect(@people.map(&:name).sort).to eq(["Blue", "Cris"])
    end

    it "should filter on arrays" do
      expect{ @apples = Apple.where(:id => [1,2,8,9]).where(:store_id => [2, 4]).all }.to use_cache(Apple).on(:id)
      expect(@apples.map(&:id).sort).to eq([8,9])
    end
    
    it "should filter on multiple fields" do
      # make sure two apples exist with the same name
      @apple = Apple.find(8)
      @apple.name = Apple.find(9).name
      @apple.save!

      expect{ @apples = Apple.where(:id => [1,2,3,8,9,10]).where(:store_id => 2).where(:name => @apple.name).all }.to use_cache(Apple).on(:id)
      expect(@apples.size).to eq(2)
      expect(@apples.map(&:name)).to eq([@apple.name, @apple.name])
      expect(@apples.map(&:id).sort).to eq([8,9])
    end

  end

  context "sort" do
    it "should apply sort on :id cache hits" do
      expect{ @people = Person.where(:id => [1,2,3]).order("name DESC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:name)).to eq(["Cris", "Blue", "Adam"])
    end

    it "should apply sort on index cache hits" do
      expect{ @apples = Apple.where(:store_id => 1).order("person_id ASC").all }.to use_cache(Apple).on(:store_id)
      expect(@apples.map(&:person_id)).to eq([nil, nil, 4, 4, 5])
    end
    
    it "should default to ASC" do
      expect{ @apples = Apple.where(:store_id => 1).order("person_id").all }.to use_cache(Apple).on(:store_id)
      expect(@apples.map(&:person_id)).to eq([nil, nil, 4, 4, 5])
    end

    it "should apply sort nil first for ASC" do
      expect{ @apples = Apple.where(:store_id => 1).order("person_id ASC").all }.to use_cache(Apple).on(:store_id)
      expect(@apples.map(&:person_id)).to eq([nil, nil, 4, 4, 5])
    end

    it "should apply sort nil last for DESC" do
      expect{ @apples = Apple.where(:store_id => 1).order("person_id DESC").all }.to use_cache(Apple).on(:store_id)
      expect(@apples.map(&:person_id)).to eq([5, 4, 4, nil, nil])
    end

    it "should sort ascending on text" do
      expect{ @people = Person.where(:id => [1,2,3,4]).order("name ASC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:name)).to eq(["Adam", "Blue", "Cris", "Fry"])
    end

    it "should sort descending on text" do
      expect{ @people = Person.where(:id => [1,2,3,4]).order("name DESC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:name)).to eq(["Fry", "Cris", "Blue", "Adam"])
    end

    it "should sort ascending on integers" do
      expect{ @people = Person.where(:id => [1,2,3,4]).order("id ASC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:id)).to eq([1,2,3,4])
    end

    it "should sort descending on integers" do
      expect{ @people = Person.where(:id => [1,2,3,4]).order("id DESC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:id)).to eq([4,3,2,1])
    end

    it "should sort ascending on dates" do
      expect{ @people = Person.where(:id => [1,2,3,4]).order("birthday ASC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:birthday)).to eq([Date.civil(1953,11,11), Date.civil(1975,03,20), Date.civil(1975,03,20), Date.civil(1985,01,20)])
    end

    it "should sort descending on dates" do
      expect{ @people = Person.where(:id => [1,2,3,4]).order("birthday DESC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:birthday)).to eq([Date.civil(1985,01,20), Date.civil(1975,03,20), Date.civil(1975,03,20), Date.civil(1953,11,11)])
    end

    it "should sort ascending on float" do
      expect{ @people = Person.where(:id => [1,2,3,4]).order("height ASC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:height)).to eq([1.69, 1.75, 1.75, 1.83])
    end

    it "should sort descending on float" do
      expect{ @people = Person.where(:id => [1,2,3,4]).order("height DESC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:height)).to eq([1.83, 1.75, 1.75, 1.69])
    end

    it "should sort on multiple fields (ASC + ASC)" do
      expect{ @people = Person.where(:id => [2,3,4,5]).order("height ASC, id ASC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:height)).to eq([1.69, 1.75, 1.75, 1.91])
      expect(@people.map(&:id)).to eq([4, 2, 3, 5])
    end

    it "should sort on multiple fields (ASC + DESC)" do
      expect{ @people = Person.where(:id => [2,3,4,5]).order("height ASC, id DESC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:height)).to eq([1.69, 1.75, 1.75, 1.91])
      expect(@people.map(&:id)).to eq([4, 3, 2, 5])
    end

    it "should sort on multiple fields (DESC + ASC)" do
      expect{ @people = Person.where(:id => [2,3,4,5]).order("height DESC, id ASC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:height)).to eq([1.91, 1.75, 1.75, 1.69])
      expect(@people.map(&:id)).to eq([5, 2, 3, 4])
    end

    it "should sort on multiple fields (DESC + DESC)" do
      expect{ @people = Person.where(:id => [2,3,4,5]).order("height DESC, id DESC").all }.to use_cache(Person).on(:id)
      expect(@people.map(&:height)).to eq([1.91, 1.75, 1.75, 1.69])
      expect(@people.map(&:id)).to eq([5, 3, 2, 4])
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
      expect{ @people = Person.where(:id => ids).order("name ASC").all }.to hit_cache(Person).on(:id).times(ids.size)
      expect(@people.map(&:name)).to eq(names_asc)

      expect{ @people = Person.where(:id => ids).order("name DESC").all }.to hit_cache(Person).on(:id).times(ids.size)
      expect(@people.map(&:name)).to eq(names_asc.reverse)
    end
  end

  it "should combine filter and sort" do
    expect{ @people = Person.where(:id => [1,2,3]).where(:height => 1.75).order("name DESC").all }.to use_cache(Person).on(:id)
    expect(@people.size).to eq(2)
    expect(@people.map(&:name)).to eq(["Cris", "Blue"])

    expect{ @people = Person.where(:id => [1,2,3]).where(:height => 1.75).order("name").all }.to hit_cache(Person).on(:id).times(3)
    expect(@people.map(&:name)).to eq(["Blue", "Cris"])
  end
  
  context "NotImplementedError" do
    before(:each) do
      @invalid_strategy = RecordCache::Strategy::Base.new(Object, nil, nil, {:key => "key"})
    end

    it "should require record_change to be implemented" do
      expect{ @invalid_strategy.record_change(Object.new, 1) }.to raise_error(NotImplementedError)
    end

    it "should require cacheable? to be implemented" do
      expect{ @invalid_strategy.cacheable?(RecordCache::Query.new) }.to raise_error(NotImplementedError)
    end

    it "should fetch_records to be implemented" do
      expect{ @invalid_strategy.fetch(RecordCache::Query.new) }.to raise_error(NotImplementedError)
    end
  end
end
