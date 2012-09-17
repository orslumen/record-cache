require 'spec_helper'

describe RecordCache::VersionStore do
  
  before(:each) do
    @version_store = RecordCache::Base.version_store
    @version_store.store.write("key1", 1000)
    @version_store.store.write("key2", 2000)
  end
  
  it "should only accept ActiveSupport cache stores" do
    lambda { RecordCache::VersionStore.new(Object.new) }.should raise_error("Store Object must respond to increment")
  end

  context "current" do
    it "should retrieve the current version" do
      @version_store.current("key1").should == 1000
    end
    
    it "should retrieve nil for unknown keys" do
      @version_store.current("unknown_key").should == nil
    end
  end

  context "current_multi" do
    it "should retrieve all versions" do
      @version_store.current_multi({:id1 => "key1", :id2 => "key2"}).should == {:id1 => 1000, :id2 => 2000}
    end
    
    it "should return nil for unknown keys" do
      @version_store.current_multi({:id1 => "key1", :key3 => "unknown_key"}).should == {:id1 => 1000, :key3 => nil}
    end

    it "should use read_multi on the underlying store" do
      mock(@version_store.store).read_multi(/key[12]/, /key[12]/) { {"key1" => 5, "key2" => 6} }
      @version_store.current_multi({:id1 => "key1", :id2 => "key2"}).should == {:id1 => 5, :id2 => 6}
    end
  end

  context "renew" do
    it "should renew the version" do
      @version_store.current("key1").should == 1000
      @version_store.renew("key1")
      @version_store.current("key1").should_not == 1000
    end

    it "should renew the version for unknown keys" do
      @version_store.current("unknown_key").should == nil
      @version_store.renew("unknown_key")
      @version_store.current("unknown_key").should_not == nil
    end
    
    it "should write to the debug log" do
      lambda { @version_store.renew("key1") }.should log(:debug, /Version Store: renew key1: nil => \d+/)
    end
  end

  context "increment" do
    it "should increment the version" do
      @version_store.current("key1").should == 1000
      @version_store.increment("key1")
      @version_store.current("key1").should == 1001
    end

    it "should renew the version on increment for unknown keys" do
      # do not use unknown_key as the version store retains the value after this spec
      @version_store.current("unknown_key").should == nil
      @version_store.renew("unknown_key")
      @version_store.current("unknown_key").should_not == nil
    end

    it "should write to the debug log" do
      lambda { @version_store.increment("key1") }.should log(:debug, %(Version Store: incremented key1: 1000 => 1001))
    end
  end

  context "delete" do
    it "should delete the version" do
      @version_store.current("key1").should == 1000
      @version_store.delete("key1").should == true
      @version_store.current("key1").should == nil
    end

    it "should not raise an error when deleting the version for unknown keys" do
      @version_store.current("unknown_key").should == nil
      @version_store.delete("unknown_key").should == false
      @version_store.current("unknown_key").should == nil
    end

    it "should write to the debug log" do
      lambda { @version_store.delete("key1") }.should log(:debug, %(Version Store: deleted key1))
    end
  end

end
