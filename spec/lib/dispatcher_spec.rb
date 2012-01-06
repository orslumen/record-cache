require 'spec_helper'

describe RecordCache::Dispatcher do
  before(:each) do
    @apple_dispatcher = Apple.record_cache
  end

  it "should return the (ordered) strategy classes" do
    RecordCache::Dispatcher.strategy_classes.should == [RecordCache::Strategy::RequestCache, RecordCache::Strategy::UniqueIndexCache, RecordCache::Strategy::FullTableCache, RecordCache::Strategy::IndexCache]
  end

  it "should be able to register a new strategy" do
    RecordCache::Dispatcher.strategy_classes << Integer
    RecordCache::Dispatcher.strategy_classes.should include(Integer)
    RecordCache::Dispatcher.strategy_classes.delete(Integer)
  end

  context "parse" do
    it "should raise an error when the same index is added twice" do
      lambda { Apple.cache_records(:index => :store_id) }.should raise_error("Multiple record cache definitions found for 'store_id' on Apple")
    end
  end
  
  it "should return the Cache for the requested strategy" do
    @apple_dispatcher[:id].class.should == RecordCache::Strategy::UniqueIndexCache
    @apple_dispatcher[:store_id].class.should == RecordCache::Strategy::IndexCache
  end

  it "should return nil for unknown requested strategies" do
    @apple_dispatcher[:unknown].should == nil
  end

  it "should return cacheable? true if there is a cacheable strategy that accepts the query" do
    query = RecordCache::Query.new
    mock(@apple_dispatcher).first_cacheable_strategy(query) { Object.new }
    @apple_dispatcher.cacheable?(query).should == true
  end

  context "fetch" do
    it "should delegate fetch to the Request Cache if present" do
      query = RecordCache::Query.new
      mock(@apple_dispatcher[:request_cache]).fetch(query)
      @apple_dispatcher.fetch(query)
    end

    it "should delegate fetch to the first cacheable strategy if Request Cache is not present" do
      query = RecordCache::Query.new
      banana_dispatcher = Banana.record_cache
      banana_dispatcher[:request_cache].should == nil
      mock(banana_dispatcher).first_cacheable_strategy(query) { mock(Object.new).fetch(query) }
      banana_dispatcher.fetch(query)
    end
  end
  
  context "record_change" do
    it "should dispatch record_change to all strategies" do
      apple = Apple.first
      [:id, :store_id, :person_id].each do |strategy|
        mock(@apple_dispatcher[strategy]).record_change(apple, :create)
      end
      @apple_dispatcher.record_change(apple, :create)
    end
  
    it "should not dispatch record_change for updates without changes" do
      apple = Apple.first
      [:request_cache, :id, :store_id, :person_id].each do |strategy|
        mock(@apple_dispatcher[strategy]).record_change(anything, anything).times(0)
      end
      @apple_dispatcher.record_change(apple, :update)
    end
  end

  context "invalidate" do
    it "should default to the :id strategy" do
      mock(@apple_dispatcher[:id]).invalidate(15)
      @apple_dispatcher.invalidate(15)
    end

    it "should delegate to given strategy" do
      mock(@apple_dispatcher[:id]).invalidate(15)
      mock(@apple_dispatcher[:store_id]).invalidate(31)
      @apple_dispatcher.invalidate(:id, 15)
      @apple_dispatcher.invalidate(:store_id, 31)
    end

    it "should invalidate the request cache" do
      store_dispatcher = Store.record_cache
      mock(store_dispatcher[:request_cache]).invalidate(15)
      store_dispatcher.invalidate(:id, 15)
    end

    it "should even invalidate the request cache if the given strategy is not known" do
      store_dispatcher = Store.record_cache
      mock(store_dispatcher[:request_cache]).invalidate(31)
      store_dispatcher.invalidate(:unknown_id, 31)
    end
  end
end
