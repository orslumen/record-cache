require 'spec_helper'

describe RecordCache::Strategy::RequestCache do

  it "should retrieve a record from the Request Cache" do
    lambda{ Store.find(1) }.should miss_cache(Store)
    lambda{ Store.find(1) }.should hit_cache(Store).on(:request_cache).times(1)
  end

  it "should retrieve the same record when the same query is used" do
    @store_1 = Store.find(1)
    @store_2 = Store.find(1)
    @store_1.should == @store_2
    @store_1.object_id.should == @store_2.object_id
  end

  context "logging" do
    before(:each) do
      Store.find(1)
    end

    it "should write hit to the debug log" do
      lambda { Store.find(1) }.should log(:debug, %(RequestCache hit for 1?id=1))
    end

    it "should write miss to the debug log" do
      lambda { Store.find(2) }.should log(:debug, %(RequestCache miss for 1?id=2))
    end
  end

  context "record_change" do
    before(:each) do
      # cache query in request cache
      @store1 = Store.find(1)
      @store2 = Store.find(2)
    end

    it "should remove all records from the cache for a specific model when one record is destroyed" do
      lambda{ Store.find(1) }.should hit_cache(Store).on(:request_cache).times(1)
      lambda{ Store.find(2) }.should hit_cache(Store).on(:request_cache).times(1)
      @store1.destroy
      lambda{ Store.find(2) }.should miss_cache(Store).on(:request_cache).times(1)
    end

    it "should remove all records from the cache for a specific model when one record is updated" do
      lambda{ Store.find(1) }.should hit_cache(Store).on(:request_cache).times(1)
      lambda{ Store.find(2) }.should hit_cache(Store).on(:request_cache).times(1)
      @store1.name = "Store E"
      @store1.save!
      lambda{ Store.find(1) }.should miss_cache(Store).on(:request_cache).times(1)
      lambda{ Store.find(2) }.should miss_cache(Store).on(:request_cache).times(1)
    end

    it "should remove all records from the cache for a specific model when one record is created" do
      lambda{ Store.find(1) }.should hit_cache(Store).on(:request_cache).times(1)
      lambda{ Store.find(2) }.should hit_cache(Store).on(:request_cache).times(1)
      Store.create!(:name => "New Apple Store")
      lambda{ Store.find(1) }.should miss_cache(Store).on(:request_cache).times(1)
      lambda{ Store.find(2) }.should miss_cache(Store).on(:request_cache).times(1)
    end

  end

  context "invalidate" do
    before(:each) do
      # cache query in request cache
      @store1 = Store.find(1)
      @store2 = Store.find(2)
    end

    it "should remove all records from the cache when clear is explicitly called" do
      lambda{ Store.find(1) }.should hit_cache(Store).on(:request_cache).times(1)
      RecordCache::Strategy::RequestCache.clear
      lambda{ Store.find(1) }.should miss_cache(Store).on(:request_cache).times(1)
    end

    it "should remove all records from the cache when invalidate is called" do
      lambda{ Store.find(1) }.should hit_cache(Store).on(:request_cache).times(1)
      Store.record_cache.invalidate(:request_cache, @store2)
      lambda{ Store.find(1) }.should miss_cache(Store).on(:request_cache).times(1)
    end
  end
end
