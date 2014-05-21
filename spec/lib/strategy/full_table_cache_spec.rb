require 'spec_helper'

describe RecordCache::Strategy::FullTableCache do

  it "should retrieve a Language from the cache" do
    lambda{ Language.where(:locale => 'en-US').all }.should miss_cache(Language).on(:full_table).times(1)
    lambda{ Language.where(:locale => 'en-US').all }.should hit_cache(Language).on(:full_table).times(1)
  end

  it "should retrieve all Languages from cache" do
    lambda{ Language.all }.should miss_cache(Language).on(:full_table).times(1)
    lambda{ Language.all }.should hit_cache(Language).on(:full_table).times(1)
    Language.all.map(&:locale).sort.should == %w(du-NL en-GB en-US hu)
  end

  context "logging" do
    it "should write hit to the debug log" do
      Language.all
      lambda { Language.all }.should log(:debug, "FullTableCache hit for model Language")
    end

    it "should write miss to the debug log" do
      lambda { Language.all }.should log(:debug, "FullTableCache miss for model Language")
    end
  end

  context "cacheable?" do
    it "should always return true" do
      Language.record_cache[:full_table].cacheable?("any query").should == true
    end
  end
  
  context "record_change" do
    before(:each) do
      @Languages = Language.all
    end

    it "should invalidate the cache when a record is added" do
      lambda{ Language.where(:locale => 'en-US').all }.should hit_cache(Language).on(:full_table).times(1)
      Language.create!(:name => 'Deutsch', :locale => 'de')
      lambda{ Language.where(:locale => 'en-US').all }.should miss_cache(Language).on(:full_table).times(1)
    end

    it "should invalidate the cache when any record is deleted" do
      lambda{ Language.where(:locale => 'en-US').all }.should hit_cache(Language).on(:full_table).times(1)
      Language.where(:locale => 'hu').first.destroy
      lambda{ Language.where(:locale => 'en-US').all }.should miss_cache(Language).on(:full_table).times(1)
    end

    it "should invalidate the cache when any record is modified" do
      lambda{ Language.where(:locale => 'en-US').all }.should hit_cache(Language).on(:full_table).times(1)
      hungarian = Language.where(:locale => 'hu').first
      hungarian.name = 'Magyar (Magyarorszag)'
      hungarian.save!
      lambda{ Language.where(:locale => 'en-US').all }.should miss_cache(Language).on(:full_table).times(1)
    end
  end
  
  context "invalidate" do

    it "should invalidate the full cache" do
      Language.record_cache[:full_table].invalidate(-10) # any id
      lambda{ Language.where(:locale => 'en-US').all }.should miss_cache(Language).on(:full_table).times(1)
    end

  end

end
