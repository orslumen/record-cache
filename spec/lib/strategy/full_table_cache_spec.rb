require 'spec_helper'

describe RecordCache::Strategy::FullTableCache do

  it "should retrieve a Language from the cache" do
    expect{ Language.where(:locale => 'en-US').all }.to miss_cache(Language).on(:full_table).times(1)
    expect{ Language.where(:locale => 'en-US').all }.to hit_cache(Language).on(:full_table).times(1)
  end

  it "should retrieve all Languages from cache" do
    expect{ Language.all }.to miss_cache(Language).on(:full_table).times(1)
    expect{ Language.all }.to hit_cache(Language).on(:full_table).times(1)
    expect(Language.all.map(&:locale).sort).to eq(%w(du-NL en-GB en-US hu))
  end

  context "logging" do
    it "should write hit to the debug log" do
      Language.all
      expect{ Language.all }.to log(:debug, "FullTableCache hit for model Language")
    end

    it "should write miss to the debug log" do
      expect{ Language.all }.to log(:debug, "FullTableCache miss for model Language")
    end
  end

  context "cacheable?" do
    it "should always return true" do
      expect(Language.record_cache[:full_table].cacheable?("any query")).to be_truthy
    end
  end
  
  context "record_change" do
    before(:each) do
      @Languages = Language.all
    end

    it "should invalidate the cache when a record is added" do
      expect{ Language.where(:locale => 'en-US').all }.to hit_cache(Language).on(:full_table).times(1)
      Language.create!(:name => 'Deutsch', :locale => 'de')
      expect{ Language.where(:locale => 'en-US').all }.to miss_cache(Language).on(:full_table).times(1)
    end

    it "should invalidate the cache when any record is deleted" do
      expect{ Language.where(:locale => 'en-US').all }.to hit_cache(Language).on(:full_table).times(1)
      Language.where(:locale => 'hu').first.destroy
      expect{ Language.where(:locale => 'en-US').all }.to miss_cache(Language).on(:full_table).times(1)
    end

    it "should invalidate the cache when any record is modified" do
      expect{ Language.where(:locale => 'en-US').all }.to hit_cache(Language).on(:full_table).times(1)
      hungarian = Language.where(:locale => 'hu').first
      hungarian.name = 'Magyar (Magyarorszag)'
      hungarian.save!
      expect{ Language.where(:locale => 'en-US').all }.to miss_cache(Language).on(:full_table).times(1)
    end
  end
  
  context "invalidate" do

    it "should invalidate the full cache" do
      Language.record_cache[:full_table].invalidate(-10) # any id
      expect{ Language.where(:locale => 'en-US').all }.to miss_cache(Language).on(:full_table).times(1)
    end

  end

end
