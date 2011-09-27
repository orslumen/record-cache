require 'spec_helper'

describe RecordCache::Statistics do
  before(:each) do
    # remove active setting from other tests
    RecordCache::Statistics.send(:remove_instance_variable, :@active) if RecordCache::Statistics.instance_variable_get(:@active)
  end

  context "active" do
    it "should default to false" do
      RecordCache::Statistics.active?.should == false
    end

    it "should be activated by start" do
      RecordCache::Statistics.start
      RecordCache::Statistics.active?.should == true
    end

    it "should be deactivated by stop" do
      RecordCache::Statistics.start
      RecordCache::Statistics.active?.should == true
      RecordCache::Statistics.stop
      RecordCache::Statistics.active?.should == false
    end

    it "should be toggleable" do
      RecordCache::Statistics.toggle
      RecordCache::Statistics.active?.should == true
      RecordCache::Statistics.toggle
      RecordCache::Statistics.active?.should == false
    end
  end
  
  context "find" do
    it "should return {} for unknown base classes" do
      class UnknownBase; end
      RecordCache::Statistics.find(UnknownBase).should == {}
    end

    it "should create a new counter for unknown strategies" do
      class UnknownBase; end
      counter = RecordCache::Statistics.find(UnknownBase, :strategy)
      counter.calls.should == 0
    end

    it "should retrieve all strategies if only the base is provided" do
      class KnownBase; end
      counter1 = RecordCache::Statistics.find(KnownBase, :strategy1)
      counter2 = RecordCache::Statistics.find(KnownBase, :strategy2)
      counters = RecordCache::Statistics.find(KnownBase)
      counters.size.should == 2
      counters[:strategy1].should == counter1
      counters[:strategy2].should == counter2
    end

    it "should retrieve the counter for an existing strategy" do
      class KnownBase; end
      counter1 = RecordCache::Statistics.find(KnownBase, :strategy1)
      RecordCache::Statistics.find(KnownBase, :strategy1).should == counter1
    end
  end
  
  context "reset!" do
    before(:each) do
      class BaseA; end
      @counter_a1 = RecordCache::Statistics.find(BaseA, :strategy1)
      @counter_a2 = RecordCache::Statistics.find(BaseA, :strategy2)
      class BaseB; end
      @counter_b1 = RecordCache::Statistics.find(BaseB, :strategy1)
    end
    
    it "should reset all counters for a specific base" do
      mock(@counter_a1).reset!
      mock(@counter_a2).reset!
      mock(@counter_b1).reset!.times(0)
      RecordCache::Statistics.reset!(BaseA)
    end

    it "should reset all counters" do
      mock(@counter_a1).reset!
      mock(@counter_a2).reset!
      mock(@counter_b1).reset!
      RecordCache::Statistics.reset!
    end
  end
  
  context "counter" do
    before(:each) do
      @counter = RecordCache::Statistics::Counter.new
    end
    
    it "should be empty by default" do
      [@counter.calls, @counter.hits, @counter.misses].should == [0, 0, 0]
    end
    
    it "should delegate active? to RecordCache::Statistics" do
      mock(RecordCache::Statistics).active?
      @counter.active?
    end
    
    it "should add hits and misses" do
      @counter.add(4, 3)
      [@counter.calls, @counter.hits, @counter.misses].should == [1, 3, 1]
    end

    it "should sum added hits and misses" do
      @counter.add(4, 3)
      @counter.add(1, 1)
      @counter.add(3, 2)
      [@counter.calls, @counter.hits, @counter.misses].should == [3, 6, 2]
    end

    it "should reset! hits and misses" do
      @counter.add(4, 3)
      @counter.add(1, 1)
      @counter.reset!
      [@counter.calls, @counter.hits, @counter.misses].should == [0, 0, 0]
    end

    it "should provide 0.0 percentage for empty counter" do
      @counter.percentage.should == 0.0
    end

    it "should provide percentage" do
      @counter.add(4, 3)
      @counter.percentage.should == 75.0
      @counter.add(1, 1)
      @counter.percentage.should == 80.0
      @counter.add(5, 2)
      @counter.percentage.should == 60.0
    end

    it "should pretty print on inspect" do
      @counter.add(4, 3)
      @counter.add(1, 1)
      @counter.add(5, 2)
      @counter.inspect.should == "60.0% (6/10)"
    end
  end
end
