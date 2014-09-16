require "spec_helper"

describe RecordCache::Strategy::UniqueIndexCache do

  it "should retrieve an Person from the cache" do
    expect{ Person.find_by_name("Fry") }.to miss_cache(Person).on(:name).times(1)
    expect{ Person.find_by_name("Fry") }.to hit_cache(Person).on(:name).times(1)
  end

  it "should retrieve cloned records" do
    @fry_a = Person.find_by_name("Fry")
    @fry_b = Person.find_by_name("Fry")
    expect(@fry_a).to eq(@fry_b)
    expect(@fry_a.object_id).to_not eq(@fry_b.object_id)
  end

  context "logging" do
    before(:each) do
      Person.find_by_name("Fry")
    end

    it "should write full hits to the debug log" do
      expect{ Person.find_by_name("Fry") }.to log(:debug, %(UniqueIndexCache on 'Person.name' hit for ids "Fry"))
    end

    it "should write full miss to the debug log" do
      expect{ Person.find_by_name("Chase") }.to log(:debug, %(UniqueIndexCache on 'Person.name' miss for ids "Chase"))
    end

    it "should write partial hits to the debug log" do
      expect{ Person.where(:name => ["Fry", "Chase"]).all }.to log(:debug, %(UniqueIndexCache on 'Person.name' partial hit for ids ["Fry", "Chase"]: missing ["Chase"]))
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
      expect{ Person.lock("any_lock").where(:name => "Fry").all }.to_not hit_cache(Person)
    end

    it "should use the cache when a single id is requested" do
      expect{ Person.where(:name => "Fry").all }.to hit_cache(Person).on(:name).times(1)
    end

    it "should use the cache when a multiple ids are requested" do
      expect{ Person.where(:name => ["Fry", "Chase"]).all }.to hit_cache(Person).on(:name).times(2)
    end

    it "should use the cache when a single id is requested and the limit is 1" do
      expect{ Person.where(:name => "Fry").limit(1).all }.to hit_cache(Person).on(:name).times(1)
    end

    it "should not use the cache when a single id is requested and the limit is > 1" do
      expect{ Person.where(:name => "Fry").limit(2).all }.to_not use_cache(Person).on(:name)
    end

    it "should not use the cache when multiple ids are requested and the limit is 1" do
      expect{ Person.where(:name => ["Fry", "Chase"]).limit(1).all }.to_not use_cache(Person).on(:name)
    end

    it "should use the cache when a single id is requested together with other where clauses" do
      expect{ Person.where(:name => "Fry").where(:height => 1.67).all }.to hit_cache(Person).on(:name).times(1)
    end

    it "should use the cache when a multiple ids are requested together with other where clauses" do
      expect{ Person.where(:name => ["Fry", "Chase"]).where(:height => 1.67).all }.to hit_cache(Person).on(:name).times(2)
    end

    it "should use the cache when a single id is requested together with (simple) sort clauses" do
      expect{ Person.where(:name => "Fry").order("name ASC").all }.to hit_cache(Person).on(:name).times(1)
    end

    it "should use the cache when a single id is requested together with (simple) case insensitive sort clauses" do
      expect{ Person.where(:name => "Fry").order("name desc").all }.to hit_cache(Person).on(:name).times(1)
    end

    it "should use the cache when a single id is requested together with (simple) sort clauses with table prefix" do
      expect{ Person.where(:name => "Fry").order("people.name desc").all }.to hit_cache(Person).on(:name).times(1)
    end

    it "should not use the cache when a single id is requested together with an unknown sort clause" do
      expect{ Person.where(:name => "Fry").order("lower(people.name) desc").all }.to_not hit_cache(Person).on(:name).times(1)
    end

    it "should use the cache when a multiple ids are requested together with (simple) sort clauses" do
      expect{ Person.where(:name => ["Fry", "Chase"]).order("name ASC").all }.to hit_cache(Person).on(:name).times(2)
    end
  end
  
  context "record_change" do
    before(:each) do
      # fill cache
      @fry = Person.find_by_name("Fry")
      @chase = Person.find_by_name("Chase")
    end

    it "should invalidate destroyed records" do
      expect{ Person.where(:name => "Fry").all }.to hit_cache(Person).on(:name).times(1)
      @fry.destroy
      expect{ @people = Person.where(:name => "Fry").all }.to miss_cache(Person).on(:name).times(1)
      expect(@people).to be_empty
      # try again, to make sure the "missing record" is not cached
      expect{ Person.where(:name => "Fry").all }.to miss_cache(Person).on(:name).times(1)
    end

    it "should add updated records directly to the cache" do
      @fry.height = 1.71
      @fry.save!
      expect{ @person = Person.find_by_name("Fry") }.to hit_cache(Person).on(:name).times(1)
      expect(@person.height).to eq(1.71)
    end

    it "should add created records directly to the cache" do
      Person.create!(:name => "Flower", :birthday => Date.civil(1990,07,29), :height => 1.80)
      expect{ @person = Person.find_by_name("Flower") }.to hit_cache(Person).on(:name).times(1)
      expect(@person.height).to eq(1.80)
    end

    it "should add updated records to the cache, also when multiple ids are queried" do
      @fry.height = 1.71
      @fry.save!
      expect{ @people = Person.where(:name => ["Fry", "Chase"]).order("id ASC").all }.to hit_cache(Person).on(:name).times(2)
      expect(@people.map(&:height)).to eq([1.71, 1.91])
    end
    
  end
  
  context "invalidate" do
    before(:each) do
      @fry = Person.find_by_name("Fry")
      @chase = Person.find_by_name("Chase")
    end

    it "should invalidate single records" do
      Person.record_cache[:name].invalidate("Fry")
      expect{ Person.find_by_name("Fry") }.to miss_cache(Person).on(:name).times(1)
    end

    it "should only miss the cache for the invalidated record when multiple ids are queried" do
      # miss on 1
      Person.record_cache[:name].invalidate("Fry")
      expect{ Person.where(:name => ["Fry", "Chase"]).all }.to miss_cache(Person).on(:name).times(1)
      # hit on 2
      Person.record_cache[:name].invalidate("Fry")
      expect{ Person.where(:name => ["Fry", "Chase"]).all }.to hit_cache(Person).on(:name).times(1)
      # nothing invalidated, both hit
      expect{ Person.where(:name => ["Fry", "Chase"]).all }.to hit_cache(Person).on(:name).times(2)
    end

    it "should invalidate records when using update_all" do
      Person.where(:id => ["Fry", "Chase", "Penny"]).all # fill id cache on all Adam Store apples
      expect{ @people = Person.where(:name => ["Fry", "Chase", "Penny"]).order("name ASC").all }.to hit_cache(Person).on(:name).times(2)
      expect(@people.map(&:name)).to eq(["Chase", "Fry", "Penny"])
      # update 2 of the 3 People
      Person.where(:name => ["Fry", "Penny"]).update_all(:height => 1.21)
      expect{ @people = Person.where(:name => ["Fry", "Chase", "Penny"]).order("height ASC").all }.to hit_cache(Person).on(:name).times(1)
      expect(@people.map(&:height)).to eq([1.21, 1.21, 1.91])
    end

  end
  
end
