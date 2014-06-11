require 'spec_helper'

describe RecordCache::Dispatcher do
  before(:each) do
    @apple_dispatcher = Apple.record_cache
  end

  it "should return the (ordered) strategy classes" do
    RecordCache::Dispatcher.strategy_classes.should == [RecordCache::Strategy::UniqueIndexCache, RecordCache::Strategy::FullTableCache, RecordCache::Strategy::IndexCache]
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
      [:id, :store_id, :person_id].each do |strategy|
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
  end
end
