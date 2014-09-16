require 'spec_helper'

describe RecordCache::Strategy::UniqueIndexCache do

  it "should retrieve an Apple from the cache" do
    lambda{ Apple.find(1) }.should miss_cache(Apple).on(:id).times(1)
    lambda{ Apple.find(1) }.should hit_cache(Apple).on(:id).times(1)
  end

  it "should accept find_by_sql queries (can not use the cache though)" do
    apple2 = Apple.find(2) # prefill cache
    apples = []
    lambda{ apples = Apple.find_by_sql("select * from apples where id = 2") }.should_not use_cache(Apple).on(:id)
    apples.should == [apple2]
  end

  it "should accept parameterized find_by_sql queries (can not use the cache though)" do
    apple1 = Apple.find(1) # prefill cache
    apples = []
    lambda{ apples = Apple.find_by_sql(["select * from apples where id = ?", 1]) }.should_not use_cache(Apple).on(:id)
    apples.should == [apple1]
  end

  it "should retrieve cloned records" do
    @apple_1a = Apple.find(1)
    @apple_1b = Apple.find(1)
    @apple_1a.should == @apple_1b
    @apple_1a.object_id.should_not == @apple_1b.object_id
  end

  context "logging" do
    before(:each) do
      Apple.find(1)
    end

    it "should write full hits to the debug log" do
      lambda { Apple.find(1) }.should log(:debug, %(UniqueIndexCache on 'Apple.id' hit for ids 1))
    end

    it "should write full miss to the debug log" do
      lambda { Apple.find(2) }.should log(:debug, %(UniqueIndexCache on 'Apple.id' miss for ids 2))
    end
    
    it "should write partial hits to the debug log" do
      lambda { Apple.where(:id => [1,2]).all }.should log(:debug, %(UniqueIndexCache on 'Apple.id' partial hit for ids [1, 2]: missing [2]))
    end
  end

  context "cacheable?" do
    before(:each) do
      # fill cache
      @apple1 = Apple.find(1)
      @apple2 = Apple.find(2)
    end

    # @see https://github.com/orslumen/record-cache/issues/2
    it "should not use the cache when a lock is used" do
      lambda{ Apple.lock("any_lock").where(:id => 1).all }.should_not hit_cache(Apple)
    end

    it "should use the cache when a single id is requested" do
      lambda{ Apple.where(:id => 1).all }.should hit_cache(Apple).on(:id).times(1)
    end

    it "should use the cache when a multiple ids are requested" do
      lambda{ Apple.where(:id => [1, 2]).all }.should hit_cache(Apple).on(:id).times(2)
    end

    it "should use the cache when a single id is requested and the limit is 1" do
      lambda{ Apple.where(:id => 1).limit(1).all }.should hit_cache(Apple).on(:id).times(1)
    end

    it "should not use the cache when a single id is requested and the limit is > 1" do
      lambda{ Apple.where(:id => 1).limit(2).all }.should_not use_cache(Apple).on(:id)
    end

    it "should not use the cache when multiple ids are requested and the limit is 1" do
      lambda{ Apple.where(:id => [1, 2]).limit(1).all }.should_not use_cache(Apple).on(:id)
    end

    it "should use the cache when a single id is requested together with other where clauses" do
      lambda{ Apple.where(:id => 1).where(:name => "Adams Apple x").all }.should hit_cache(Apple).on(:id).times(1)
    end

    it "should use the cache when a multiple ids are requested together with other where clauses" do
      lambda{ Apple.where(:id => [1,2]).where(:name => "Adams Apple x").all }.should hit_cache(Apple).on(:id).times(2)
    end

    it "should use the cache when a single id is requested together with (simple) sort clauses" do
      lambda{ Apple.where(:id => 1).order("name ASC").all }.should hit_cache(Apple).on(:id).times(1)
    end

    it "should use the cache when a multiple ids are requested together with (simple) sort clauses" do
      lambda{ Apple.where(:id => [1,2]).order("name ASC").all }.should hit_cache(Apple).on(:id).times(2)
    end

    it "should not use the cache when a join clause is used" do
      lambda{ Apple.where(:id => [1,2]).joins(:store).all }.should_not use_cache(Apple).on(:id)
    end
  end
  
  context "record_change" do
    before(:each) do
      # fill cache
      @apple1 = Apple.find(1)
      @apple2 = Apple.find(2)
    end

    it "should invalidate destroyed records" do
      lambda{ Apple.where(:id => 1).all }.should hit_cache(Apple).on(:id).times(1)
      @apple1.destroy
      lambda{ @apples = Apple.where(:id => 1).all }.should miss_cache(Apple).on(:id).times(1)
      @apples.should == []
      # try again, to make sure the "missing record" is not cached
      lambda{ Apple.where(:id => 1).all }.should miss_cache(Apple).on(:id).times(1)
    end

    it "should add updated records directly to the cache" do
      @apple1.name = "Applejuice"
      @apple1.save!
      lambda{ @apple = Apple.find(1) }.should hit_cache(Apple).on(:id).times(1)
      @apple.name.should == "Applejuice"
    end

    it "should add created records directly to the cache" do
      @new_apple = Apple.create!(:name => "Fresh Apple", :store_id => 1)
      lambda{ @apple = Apple.find(@new_apple.id) }.should hit_cache(Apple).on(:id).times(1)
      @apple.name.should == "Fresh Apple"
    end

    it "should add updated records to the cache, also when multiple ids are queried" do
      @apple1.name = "Applejuice"
      @apple1.save!
      lambda{ @apples = Apple.where(:id => [1, 2]).order('id ASC').all }.should hit_cache(Apple).on(:id).times(2)
      @apples.map(&:name).should == ["Applejuice", "Adams Apple 2"]
    end

  end
  
  context "invalidate" do
    before(:each) do
      @apple1 = Apple.find(1)
      @apple2 = Apple.find(2)
    end

    it "should invalidate single records" do
      Apple.record_cache[:id].invalidate(1)
      lambda{ Apple.find(1) }.should miss_cache(Apple).on(:id).times(1)
    end

    it "should only miss the cache for the invalidated record when multiple ids are queried" do
      # miss on 1
      Apple.record_cache[:id].invalidate(1)
      lambda{ Apple.where(:id => [1, 2]).all }.should miss_cache(Apple).on(:id).times(1)
      # hit on 2
      Apple.record_cache[:id].invalidate(1)
      lambda{ Apple.where(:id => [1, 2]).all }.should hit_cache(Apple).on(:id).times(1)
      # nothing invalidated, both hit
      lambda{ Apple.where(:id => [1, 2]).all }.should hit_cache(Apple).on(:id).times(2)
    end

    it "should invalidate records when using update_all" do
      Apple.where(:id => [3,4,5]).all # fill id cache on all Adam Store apples
      lambda{ @apples = Apple.where(:id => [1, 2, 3, 4, 5]).order('id ASC').all }.should hit_cache(Apple).on(:id).times(5)
      @apples.map(&:name).should == ["Adams Apple 1", "Adams Apple 2", "Adams Apple 3", "Adams Apple 4", "Adams Apple 5"]
      # update 3 of the 5 apples in the Adam Store
      Apple.where(:id => [1,2,3]).update_all(:name => "Uniform Apple")
      lambda{ @apples = Apple.where(:id => [1, 2, 3, 4, 5]).order('id ASC').all }.should hit_cache(Apple).on(:id).times(2)
      @apples.map(&:name).should == ["Uniform Apple", "Uniform Apple", "Uniform Apple", "Adams Apple 4", "Adams Apple 5"]
    end

    it "should invalidate reflection indexes when a has_many relation is updated" do
      # assign different apples to store 2
      lambda{ Apple.where(:store_id => 1).all }.should hit_cache(Apple).on(:id).times(2)
      store2_apple_ids = Apple.where(:store_id => 2).map(&:id)
      store1 = Store.find(1)
      store1.apple_ids = store2_apple_ids
      store1.save!
      # the apples that used to belong to store 2 are now in store 1 (incremental update)
      lambda{ @apple1 = Apple.find(store2_apple_ids.first) }.should hit_cache(Apple).on(:id).times(1)
      @apple1.store_id.should == 1
      # the apples that used to belong to store 1 are now homeless (cache invalidated)
      lambda{ @homeless_apple = Apple.find(1) }.should miss_cache(Apple).on(:id).times(1)
      @homeless_apple.store_id.should == nil
    end

    it "should reload from the DB after invalidation" do
      @apple = Apple.last
      Apple.record_cache.invalidate(@apple.id)
      lambda{ Apple.find(@apple.id) }.should miss_cache(Apple).on(:id).times(1)
    end

  end

  context "transactions" do

    it "should update the cache once the transaction is committed" do
      apple1 = Apple.find(1)
      ActiveRecord::Base.transaction do
        apple1.name = "Committed Apple"
        apple1.save!

        # do not use the cache within a transaction
        lambda{ apple1 = Apple.find(1) }.should_not use_cache(Apple).on(:id)
        apple1.name.should == "Committed Apple"
      end

      # use the cache again once the transaction is over
      lambda{ apple1 = Apple.find(1) }.should use_cache(Apple).on(:id)
      apple1.name.should == "Committed Apple"
    end

    it "should not update the cache when the transaction is rolled back" do
      apple1 = Apple.find(1)
      ActiveRecord::Base.transaction do
        apple1.name = "Rollback Apple"
        apple1.save!

        # test to make sure appl1 is not retrieved 1:1 from the cache
        apple1.name = "Not saved apple"

        # do not use the cache within a transaction
        lambda{ apple1 = Apple.find(1) }.should_not use_cache(Apple).on(:id)
        apple1.name.should == "Rollback Apple"

        raise ActiveRecord::Rollback, "oops"
      end

      # use the cache again once the transaction is over
      lambda{ apple1 = Apple.find(1) }.should use_cache(Apple).on(:id)
      apple1.name.should == "Adams Apple 1"
    end

  end

  context "nested transactions" do

    it "should update the cache in case both transactions are committed" do
      apple1, apple2 = nil

      ActiveRecord::Base.transaction do
        apple1 = Apple.find(1)
        apple1.name = "Committed Apple 1"
        apple1.save!

        ActiveRecord::Base.transaction(requires_new: true) do
          apple2 = Apple.find(2)
          apple2.name = "Committed Apple 2"
          apple2.save!
        end
      end

      lambda{ apple1 = Apple.find(1) }.should use_cache(Apple).on(:id)
      apple1.name.should == "Committed Apple 1"

      lambda{ apple2 = Apple.find(2) }.should use_cache(Apple).on(:id)
      apple2.name.should == "Committed Apple 2"
    end

    [:implicitly, :explicitly].each do |inner_rollback_explicit_or_implicit|
      it "should not update the cache in case both transactions are #{inner_rollback_explicit_or_implicit} rolled back" do
        pending "nested transaction support by sqlite3"
        apple1, apple2 = nil

        ActiveRecord::Base.transaction do
          apple1 = Apple.find(1)
          apple1.name = "Rollback Apple 1"
          apple1.save!
          apple1.name = "Saved Apple 1"

          ActiveRecord::Base.transaction(requires_new: true) do
            apple2 = Apple.find(2)
            apple2.name = "Rollback Apple 2"
            apple2.save!
            apple1.name = "Saved Apple 2"

            raise ActiveRecord::Rollback, "oops" if inner_rollback_explicit_or_implicit == :explicitly
          end

          raise ActiveRecord::Rollback, "oops"
        end

        lambda{ apple1 = Apple.find(1) }.should use_cache(Apple).on(:id)
        apple1.name.should == "Adams Apple 1"

        lambda{ apple2 = Apple.find(2) }.should use_cache(Apple).on(:id)
        apple2.name.should == "Adams Apple 2"
      end
    end

    it "should not update the cache for the rolled back inner transaction" do
      pending "rails calls after_commit on records that are in a transaction that is rolled back"

      apple1, apple2 = nil

      ActiveRecord::Base.transaction do
        apple1 = Apple.find(1)
        apple1.name = "Committed Apple 1"
        apple1.save!

        ActiveRecord::Base.transaction(requires_new: true) do
          apple2 = Apple.find(2)
          apple2.name = "Rollback Apple 2"
          apple2.save!

          raise ActiveRecord::Rollback, "oops"
        end
      end

      lambda{ apple1 = Apple.find(1) }.should use_cache(Apple).on(:id)
      apple1.name.should == "Committed Apple 1"

      lambda{ apple2 = Apple.find(2) }.should use_cache(Apple).on(:id)
      apple2.name.should == "Adams Apple 2"
    end
  end
end
