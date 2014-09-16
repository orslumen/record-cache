require 'spec_helper'

describe RecordCache::Statistics do
  before(:each) do
    # remove active setting from other tests
    RecordCache::Statistics.send(:remove_instance_variable, :@active) if RecordCache::Statistics.instance_variable_get(:@active)
  end

  context "active" do
    it "should default to false" do
      expect(RecordCache::Statistics.active?).to be_falsey
    end

    it "should be activated by start" do
      RecordCache::Statistics.start
      expect(RecordCache::Statistics.active?).to be_truthy
    end

    it "should be deactivated by stop" do
      RecordCache::Statistics.start
      expect(RecordCache::Statistics.active?).to be_truthy
      RecordCache::Statistics.stop
      expect(RecordCache::Statistics.active?).to be_falsey
    end

    it "should be toggleable" do
      RecordCache::Statistics.toggle
      expect(RecordCache::Statistics.active?).to be_truthy
      RecordCache::Statistics.toggle
      expect(RecordCache::Statistics.active?).to be_falsey
    end
  end
  
  context "find" do
    it "should return {} for unknown base classes" do
      class UnknownBase; end
      expect(RecordCache::Statistics.find(UnknownBase)).to eq({})
    end

    it "should create a new counter for unknown strategies" do
      class UnknownBase; end
      counter = RecordCache::Statistics.find(UnknownBase, :strategy)
      expect(counter.calls).to eq(0)
    end

    it "should retrieve all strategies if only the base is provided" do
      class KnownBase; end
      counter1 = RecordCache::Statistics.find(KnownBase, :strategy1)
      counter2 = RecordCache::Statistics.find(KnownBase, :strategy2)
      counters = RecordCache::Statistics.find(KnownBase)
      expect(counters.size).to eq(2)
      expect(counters[:strategy1]).to eq(counter1)
      expect(counters[:strategy2]).to eq(counter2)
    end

    it "should retrieve the counter for an existing strategy" do
      class KnownBase; end
      counter1 = RecordCache::Statistics.find(KnownBase, :strategy1)
      expect(RecordCache::Statistics.find(KnownBase, :strategy1)).to eq(counter1)
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
      expect(@counter_a1).to receive(:reset!)
      expect(@counter_a2).to receive(:reset!)
      expect(@counter_b1).to_not receive(:reset!)
      RecordCache::Statistics.reset!(BaseA)
    end

    it "should reset all counters" do
      expect(@counter_a1).to receive(:reset!)
      expect(@counter_a2).to receive(:reset!)
      expect(@counter_b1).to receive(:reset!)
      RecordCache::Statistics.reset!
    end
  end
  
  context "counter" do
    before(:each) do
      @counter = RecordCache::Statistics::Counter.new
    end
    
    it "should be empty by default" do
      expect([@counter.calls, @counter.hits, @counter.misses]).to eq([0, 0, 0])
    end
    
    it "should delegate active? to RecordCache::Statistics" do
      expect(RecordCache::Statistics).to receive(:active?)
      @counter.active?
    end
    
    it "should add hits and misses" do
      @counter.add(4, 3)
      expect([@counter.calls, @counter.hits, @counter.misses]).to eq([1, 3, 1])
    end

    it "should sum added hits and misses" do
      @counter.add(4, 3)
      @counter.add(1, 1)
      @counter.add(3, 2)
      expect([@counter.calls, @counter.hits, @counter.misses]).to eq([3, 6, 2])
    end

    it "should reset! hits and misses" do
      @counter.add(4, 3)
      @counter.add(1, 1)
      @counter.reset!
      expect([@counter.calls, @counter.hits, @counter.misses]).to eq([0, 0, 0])
    end

    it "should provide 0.0 percentage for empty counter" do
      expect(@counter.percentage).to eq(0.0)
    end

    it "should provide percentage" do
      @counter.add(4, 3)
      expect(@counter.percentage).to eq(75.0)
      @counter.add(1, 1)
      expect(@counter.percentage).to eq(80.0)
      @counter.add(5, 2)
      expect(@counter.percentage).to eq(60.0)
    end

    it "should pretty print on inspect" do
      @counter.add(4, 3)
      @counter.add(1, 1)
      @counter.add(5, 2)
      expect(@counter.inspect).to eq("60.0% (6/10)")
    end
  end
end
