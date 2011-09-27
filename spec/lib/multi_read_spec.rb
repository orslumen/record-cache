require 'spec_helper'

describe RecordCache::MultiRead do

  it "should not delegate to single reads when multi_read is supported" do
    class MultiReadSupported
      def read(key) "single" end
      def read_multi(*keys) "multi" end
    end
    store = RecordCache::MultiRead.test(MultiReadSupported.new)
    store.read_multi("key1", "key2").should == "multi"
  end

  it "should delegate to single reads when multi_read is explicitly disabled" do
    class ExplicitlyDisabled
      def read(key) "single" end
      def read_multi(*keys) "multi" end
    end
    RecordCache::MultiRead.disable(ExplicitlyDisabled)
    store = RecordCache::MultiRead.test(ExplicitlyDisabled.new)
    store.read_multi("key1", "key2").should == {"key1" => "single", "key2" => "single"}
  end

  it "should delegate to single reads when multi_read throws an error" do
    class MultiReadNotImplemented
      def read(key) "single" end
      def read_multi(*keys) raise NotImplementedError.new("multiread not implemented") end
    end
    store = RecordCache::MultiRead.test(MultiReadNotImplemented.new)
    store.read_multi("key1", "key2").should == {"key1" => "single", "key2" => "single"}
  end

  it "should delegate to single reads when multi_read is undefined" do
    class MultiReadNotDefined
      def read(key) "single" end
    end
    store = RecordCache::MultiRead.test(MultiReadNotDefined.new)
    store.read_multi("key1", "key2").should == {"key1" => "single", "key2" => "single"}
  end

  it "should have tested the Version Store" do
    RecordCache::MultiRead.instance_variable_get(:@tested).should include(RecordCache::Base.version_store.instance_variable_get(:@store))
  end

  it "should have tested all Record Stores" do
    tested_stores = RecordCache::MultiRead.instance_variable_get(:@tested)
    RecordCache::Base.stores.values.each do |record_store|
      tested_stores.should include(record_store)
    end
  end
end
