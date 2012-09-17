require "spec_helper"

describe RecordCache::Strategy::UniqueIndexCache do

  it "should retrieve an Person from the cache" do
    lambda{ Person.find_by_name("Fry") }.should miss_cache(Person).on(:name).times(1)
    lambda{ Person.find_by_name("Fry") }.should hit_cache(Person).on(:name).times(1)
  end

  it "should retrieve cloned records" do
    @fry_a = Person.find_by_name("Fry")
    @fry_b = Person.find_by_name("Fry")
    @fry_a.should == @fry_b
    @fry_a.object_id.should_not == @fry_b.object_id
  end

  context "logging" do
    before(:each) do
      Person.find_by_name("Fry")
    end

    it "should write full hits to the debug log" do
      lambda { Person.find_by_name("Fry") }.should log(:debug, %(UniqueIndexCache on 'name' hit for ids "Fry"))
    end

    it "should write full miss to the debug log" do
      lambda { Person.find_by_name("Chase") }.should log(:debug, %(UniqueIndexCache on 'name' miss for ids "Chase"))
    end

    it "should write partial hits to the debug log" do
      lambda { Person.where(:name => ["Fry", "Chase"]).all }.should log(:debug, %(UniqueIndexCache on 'name' partial hit for ids ["Fry", "Chase"]: missing ["Chase"]))
    end
  end

  context "cacheable?" do
    before(:each) do
      # fill cache
      @fry = Person.find_by_name("Fry")
      @chase = Person.find_by_name("Chase")
    end

    # @see https://github.com/orslumen/record-cache/issues/2
    it "should not use the cache when a lock is used" do
      lambda{ Person.lock("any_lock").where(:name => "Fry").all }.should_not hit_cache(Person)
    end

    it "should use the cache when a single id is requested" do
      lambda{ Person.where(:name => "Fry").all }.should hit_cache(Person).on(:name).times(1)
    end

    it "should use the cache when a multiple ids are requested" do
      lambda{ Person.where(:name => ["Fry", "Chase"]).all }.should hit_cache(Person).on(:name).times(2)
    end

    it "should use the cache when a single id is requested and the limit is 1" do
      lambda{ Person.where(:name => "Fry").limit(1).all }.should hit_cache(Person).on(:name).times(1)
    end

    it "should not use the cache when a single id is requested and the limit is > 1" do
      lambda{ Person.where(:name => "Fry").limit(2).all }.should_not use_cache(Person).on(:name)
    end

    it "should not use the cache when multiple ids are requested and the limit is 1" do
      lambda{ Person.where(:name => ["Fry", "Chase"]).limit(1).all }.should_not use_cache(Person).on(:name)
    end

    it "should use the cache when a single id is requested together with other where clauses" do
      lambda{ Person.where(:name => "Fry").where(:height => 1.67).all }.should hit_cache(Person).on(:name).times(1)
    end

    it "should use the cache when a multiple ids are requested together with other where clauses" do
      lambda{ Person.where(:name => ["Fry", "Chase"]).where(:height => 1.67).all }.should hit_cache(Person).on(:name).times(2)
    end

    it "should use the cache when a single id is requested together with (simple) sort clauses" do
      lambda{ Person.where(:name => "Fry").order("name ASC").all }.should hit_cache(Person).on(:name).times(1)
    end

    it "should use the cache when a multiple ids are requested together with (simple) sort clauses" do
      lambda{ Person.where(:name => ["Fry", "Chase"]).order("name ASC").all }.should hit_cache(Person).on(:name).times(2)
    end
  end
  
  context "record_change" do
    before(:each) do
      # fill cache
      @fry = Person.find_by_name("Fry")
      @chase = Person.find_by_name("Chase")
    end

    it "should invalidate destroyed records" do
      lambda{ Person.where(:name => "Fry").all }.should hit_cache(Person).on(:name).times(1)
      @fry.destroy
      lambda{ @people = Person.where(:name => "Fry").all }.should miss_cache(Person).on(:name).times(1)
      @people.should == []
      # try again, to make sure the "missing record" is not cached
      lambda{ Person.where(:name => "Fry").all }.should miss_cache(Person).on(:name).times(1)
    end

    it "should add updated records directly to the cache" do
      @fry.height = 1.71
      @fry.save!
      lambda{ @person = Person.find_by_name("Fry") }.should hit_cache(Person).on(:name).times(1)
      @person.height.should == 1.71
    end

    it "should add created records directly to the cache" do
      Person.create!(:name => "Flower", :birthday => Date.civil(1990,07,29), :height => 1.80)
      lambda{ @person = Person.find_by_name("Flower") }.should hit_cache(Person).on(:name).times(1)
      @person.height.should == 1.80
    end

    it "should add updated records to the cache, also when multiple ids are queried" do
      @fry.height = 1.71
      @fry.save!
      lambda{ @people = Person.where(:name => ["Fry", "Chase"]).order("id ASC").all }.should hit_cache(Person).on(:name).times(2)
      @people.map(&:height).should == [1.71, 1.91]
    end
    
  end
  
  context "invalidate" do
    before(:each) do
      @fry = Person.find_by_name("Fry")
      @chase = Person.find_by_name("Chase")
    end

    it "should invalidate single records" do
      Person.record_cache[:name].invalidate("Fry")
      lambda{ Person.find_by_name("Fry") }.should miss_cache(Person).on(:name).times(1)
    end

    it "should only miss the cache for the invalidated record when multiple ids are queried" do
      # miss on 1
      Person.record_cache[:name].invalidate("Fry")
      lambda{ Person.where(:name => ["Fry", "Chase"]).all }.should miss_cache(Person).on(:name).times(1)
      # hit on 2
      Person.record_cache[:name].invalidate("Fry")
      lambda{ Person.where(:name => ["Fry", "Chase"]).all }.should hit_cache(Person).on(:name).times(1)
      # nothing invalidated, both hit
      lambda{ Person.where(:name => ["Fry", "Chase"]).all }.should hit_cache(Person).on(:name).times(2)
    end

    it "should invalidate records when using update_all" do
      Person.where(:id => ["Fry", "Chase", "Penny"]).all # fill id cache on all Adam Store apples
      lambda{ @people = Person.where(:name => ["Fry", "Chase", "Penny"]).order("name ASC").all }.should hit_cache(Person).on(:name).times(2)
      @people.map(&:name).should == ["Chase", "Fry", "Penny"]
      # update 2 of the 3 People
      Person.where(:name => ["Fry", "Penny"]).update_all(:height => 1.21)
      lambda{ @people = Person.where(:name => ["Fry", "Chase", "Penny"]).order("height ASC").all }.should hit_cache(Person).on(:name).times(1)
      @people.map(&:height).should == [1.21, 1.21, 1.91]
    end

  end
  
end
