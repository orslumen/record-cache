require 'spec_helper'

describe RecordCache::VersionStore do
  
  before(:each) do
    @version_store = RecordCache::Base.version_store
    @version_store.store.write("key1", 1000)
    @version_store.store.write("key2", 2000)
  end
  
  it "should only accept ActiveSupport cache stores" do
    expect{ RecordCache::VersionStore.new(Object.new) }.to raise_error("Store Object must respond to write")
  end

  context "current" do
    it "should retrieve the current version" do
      expect(@version_store.current("key1")).to eq(1000)
    end
    
    it "should retrieve nil for unknown keys" do
      expect(@version_store.current("unknown_key")).to be_nil
    end
  end

  context "current_multi" do
    it "should retrieve all versions" do
      expect(@version_store.current_multi({:id1 => "key1", :id2 => "key2"})).to eq({:id1 => 1000, :id2 => 2000})
    end
    
    it "should return nil for unknown keys" do
      expect(@version_store.current_multi({:id1 => "key1", :key3 => "unknown_key"})).to eq({:id1 => 1000, :key3 => nil})
    end

    it "should use read_multi on the underlying store" do
      allow(@version_store.store).to receive(:read_multi).with(/key[12]/, /key[12]/) { {"key1" => 5, "key2" => 6} }
      expect(@version_store.current_multi({:id1 => "key1", :id2 => "key2"})).to eq({:id1 => 5, :id2 => 6})
    end
  end

  context "renew" do
    it "should renew the version" do
      expect(@version_store.current("key1")).to eq(1000)
      @version_store.renew("key1")
      expect(@version_store.current("key1")).to_not eq(1000)
    end

    it "should renew the version for unknown keys" do
      expect(@version_store.current("unknown_key")).to be_nil
      @version_store.renew("unknown_key")
      expect(@version_store.current("unknown_key")).to_not be_nil
    end
    
    it "should write to the debug log" do
      expect{ @version_store.renew("key1") }.to log(:debug, /Version Store: renew key1: nil => \d+/)
    end
  end

  # deprecated
  context "increment" do

    it "should write to the debug log" do
      expect{ @version_store.increment("key1") }.to log(:debug, /increment is deprecated, use renew instead/)
    end

  end

  context "delete" do
    it "should delete the version" do
      expect(@version_store.current("key1")).to eq(1000)
      expect(@version_store.delete("key1")).to be_truthy
      expect(@version_store.current("key1")).to be_nil
    end

    it "should not raise an error when deleting the version for unknown keys" do
      expect(@version_store.current("unknown_key")).to be_nil
      expect(@version_store.delete("unknown_key")).to be_falsey
      expect(@version_store.current("unknown_key")).to be_nil
    end

    it "should write to the debug log" do
      expect{ @version_store.delete("key1") }.to log(:debug, %(Version Store: deleted key1))
    end
  end

end
