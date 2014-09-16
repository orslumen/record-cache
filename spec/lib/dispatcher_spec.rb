require 'spec_helper'

describe RecordCache::Dispatcher do
  before(:each) do
    @apple_dispatcher = Apple.record_cache
  end

  it "should return the (ordered) strategy classes" do
    expect(RecordCache::Dispatcher.strategy_classes).to eq([RecordCache::Strategy::UniqueIndexCache, RecordCache::Strategy::FullTableCache, RecordCache::Strategy::IndexCache])
  end

  it "should be able to register a new strategy" do
    RecordCache::Dispatcher.strategy_classes << Integer
    expect(RecordCache::Dispatcher.strategy_classes).to include(Integer)
    RecordCache::Dispatcher.strategy_classes.delete(Integer)
  end

  context "parse" do
    it "should raise an error when the same index is added twice" do
      expect{ Apple.cache_records(:index => :store_id) }.to raise_error("Multiple record cache definitions found for 'store_id' on Apple")
    end
  end
  
  it "should return the Cache for the requested strategy" do
    expect(@apple_dispatcher[:id].class).to eq(RecordCache::Strategy::UniqueIndexCache)
    expect(@apple_dispatcher[:store_id].class).to eq(RecordCache::Strategy::IndexCache)
  end

  it "should return nil for unknown requested strategies" do
    expect(@apple_dispatcher[:unknown]).to be_nil
  end

  context "record_change" do
    it "should dispatch record_change to all strategies" do
      apple = Apple.first
      [:id, :store_id, :person_id].each do |strategy|
        expect(@apple_dispatcher[strategy]).to receive(:record_change).with(apple, :create)
      end
      @apple_dispatcher.record_change(apple, :create)
    end
  
    it "should not dispatch record_change for updates without changes" do
      apple = Apple.first
      [:id, :store_id, :person_id].each do |strategy|
        expect(@apple_dispatcher[strategy]).to_not receive(:record_change)
      end
      @apple_dispatcher.record_change(apple, :update)
    end
  end

  context "invalidate" do
    it "should default to the :id strategy" do
      expect(@apple_dispatcher[:id]).to receive(:invalidate).with(15)
      @apple_dispatcher.invalidate(15)
    end

    it "should delegate to given strategy" do
      expect(@apple_dispatcher[:id]).to receive(:invalidate).with(15)
      expect(@apple_dispatcher[:store_id]).to receive(:invalidate).with(31)
      @apple_dispatcher.invalidate(:id, 15)
      @apple_dispatcher.invalidate(:store_id, 31)
    end
  end
end
