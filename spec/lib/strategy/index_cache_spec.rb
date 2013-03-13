require 'spec_helper'

describe RecordCache::Strategy::IndexCache do

  context "initialize" do
    it "should only accept index cache on DB columns" do
      lambda { Apple.send(:cache_records, :index => :unknown_column) }.should raise_error("No column found for index 'unknown_column' on Apple.")
    end
  
    it "should only accept index cache on integer columns" do
      lambda { Apple.send(:cache_records, :index => :name) }.should raise_error("Incorrect type (expected integer, found string) for index 'name' on Apple.")
    end
  end

  it "should use the id cache to retrieve the actual records" do
    lambda { @apples = Apple.where(:store_id => 1).all }.should miss_cache(Apple).on(:store_id).times(1)
    lambda { Apple.where(:store_id => 1).all }.should hit_cache(Apple).on(:store_id).times(1)
    lambda { Apple.where(:store_id => 1).all }.should hit_cache(Apple).on(:id).times(@apples.size)
  end

  context "logging" do
    before(:each) do
      Apple.where(:store_id => 1).all
    end

    it "should write hit to the debug log" do
      lambda { Apple.where(:store_id => 1).all }.should log(:debug, /IndexCache hit for rc\/apl\/store_id=1v\d+: found 5 ids/)
    end

    it "should write miss to the debug log" do
      lambda { Apple.where(:store_id => 2).all }.should log(:debug, /IndexCache miss for rc\/apl\/store_id=2v\d+: found no ids/)
    end
  end

  context "cacheable?" do
    before(:each) do
      @store1_apples = Apple.where(:store_id => 1).all
      @store2_apples = Apple.where(:store_id => 2).all
    end

    it "should hit the cache for a single index id" do
      lambda { Apple.where(:store_id => 1).all }.should hit_cache(Apple).on(:store_id).times(1)
    end

    it "should hit the cache for a single index id with other where clauses" do
      lambda { Apple.where(:store_id => 1).where(:name => "applegate").all }.should hit_cache(Apple).on(:store_id).times(1)
    end

    it "should hit the cache for a single index id with (simple) sort clauses" do
      lambda { Apple.where(:store_id => 1).order("name ASC").all }.should hit_cache(Apple).on(:store_id).times(1)
    end

    #Allow limit == 1 by filtering records after cache hit.  Needed for has_one
    it "should not hit the cache for a single index id with limit > 0" do
      lambda { Apple.where(:store_id => 1).limit(2).all }.should_not hit_cache(Apple).on(:store_id)
    end

    it "should not hit the cache when an :id where clause is defined" do
      # this query should make use of the :id cache, which is faster
      lambda { Apple.where(:store_id => 1).where(:id => 1).all }.should_not hit_cache(Apple).on(:store_id)
    end
  end
  
  context "record_change" do
    before(:each) do
      @store1_apples = Apple.where(:store_id => 1).order('id ASC').all
      @store2_apples = Apple.where(:store_id => 2).order('id ASC').all
    end

    [false, true].each do |fresh|
      it "should #{fresh ? 'update' : 'invalidate'} the index when a record in the index is destroyed and the current index is #{fresh ? '' : 'not '}fresh" do
        # make sure the index is no longer fresh
        Apple.record_cache.invalidate(:store_id, 1) unless fresh
        # destroy an apple
        @destroyed = @store1_apples.last
        @destroyed.destroy
        # check the cache hit/miss on the index that contained that apple
        if fresh
          lambda { @apples = Apple.where(:store_id => 1).order('id ASC').all }.should hit_cache(Apple).on(:store_id).times(1)
        else
          lambda { @apples = Apple.where(:store_id => 1).order('id ASC').all }.should miss_cache(Apple).on(:store_id).times(1)
        end
        @apples.size.should == @store1_apples.size - 1
        @apples.map(&:id).should == @store1_apples.map(&:id) - [@destroyed.id]
        # and the index should be cached again
        lambda { Apple.where(:store_id => 1).all }.should hit_cache(Apple).on(:store_id).times(1)
      end

      it "should #{fresh ? 'update' : 'invalidate'} the index when a record in the index is created and the current index is #{fresh ? '' : 'not '}fresh" do
        # make sure the index is no longer fresh
        Apple.record_cache.invalidate(:store_id, 1) unless fresh
        # create an apple
        @new_apple_in_store1 = Apple.create!(:name => "Fresh Apple", :store_id => 1)
        # check the cache hit/miss on the index that contains that apple
        if fresh
          lambda { @apples = Apple.where(:store_id => 1).order('id ASC').all }.should hit_cache(Apple).on(:store_id).times(1)
        else
          lambda { @apples = Apple.where(:store_id => 1).order('id ASC').all }.should miss_cache(Apple).on(:store_id).times(1)
        end
        @apples.size.should == @store1_apples.size + 1
        @apples.map(&:id).should == @store1_apples.map(&:id) + [@new_apple_in_store1.id]
        # and the index should be cached again
        lambda { Apple.where(:store_id => 1).all }.should hit_cache(Apple).on(:store_id).times(1)
      end

      it "should #{fresh ? 'update' : 'invalidate'} two indexes when the indexed value is updated and the current index is #{fresh ? '' : 'not '}fresh" do
        # make sure both indexes are no longer fresh
        Apple.record_cache.invalidate(:store_id, 1) unless fresh
        Apple.record_cache.invalidate(:store_id, 2) unless fresh
        # move one apple from store 1 to store 2
        @apple_moved_from_store1_to_store2 = @store1_apples.last
        @apple_moved_from_store1_to_store2.store_id = 2
        @apple_moved_from_store1_to_store2.save!
        # check the cache hit/miss on the indexes that contained/contains that apple
        if fresh
          lambda { @apples1 = Apple.where(:store_id => 1).order('id ASC').all }.should hit_cache(Apple).on(:store_id).times(1)
          lambda { @apples2 = Apple.where(:store_id => 2).order('id ASC').all }.should hit_cache(Apple).on(:store_id).times(1)
        else
          lambda { @apples1 = Apple.where(:store_id => 1).order('id ASC').all }.should miss_cache(Apple).on(:store_id).times(1)
          lambda { @apples2 = Apple.where(:store_id => 2).order('id ASC').all }.should miss_cache(Apple).on(:store_id).times(1)
        end
        @apples1.size.should == @store1_apples.size - 1
        @apples2.size.should == @store2_apples.size + 1
        @apples1.map(&:id).should == @store1_apples.map(&:id) - [@apple_moved_from_store1_to_store2.id]
        @apples2.map(&:id).should == [@apple_moved_from_store1_to_store2.id] + @store2_apples.map(&:id)
        # and the index should be cached again
        lambda { Apple.where(:store_id => 1).all }.should hit_cache(Apple).on(:store_id).times(1)
        lambda { Apple.where(:store_id => 2).all }.should hit_cache(Apple).on(:store_id).times(1)
      end

      it "should #{fresh ? 'update' : 'invalidate'} multiple indexes when several values on different indexed attributes are updated at once and one of the indexes is #{fresh ? '' : 'not '}fresh" do
        # find the apples for person 1 and 5 (Chase)
        @person4_apples = Apple.where(:person_id => 4).all # Fry's Apples
        @person5_apples = Apple.where(:person_id => 5).all # Chases' Apples
        # make sure person indexes are no longer fresh
        Apple.record_cache.invalidate(:person_id, 4) unless fresh
        Apple.record_cache.invalidate(:person_id, 5) unless fresh
        # move one apple from store 1 to store 2
        @apple_moved_from_s1to2_p5to4 = @store1_apples.last # the last apple belongs to person Chase (id 5)
        @apple_moved_from_s1to2_p5to4.store_id = 2
        @apple_moved_from_s1to2_p5to4.person_id = 4
        @apple_moved_from_s1to2_p5to4.save!
        # check the cache hit/miss on the indexes that contained/contains that apple
        lambda { @apples_s1 = Apple.where(:store_id => 1).order('id ASC').all }.should hit_cache(Apple).on(:store_id).times(1)
        lambda { @apples_s2 = Apple.where(:store_id => 2).order('id ASC').all }.should hit_cache(Apple).on(:store_id).times(1)
        if fresh
          lambda { @apples_p1 = Apple.where(:person_id => 4).order('id ASC').all }.should hit_cache(Apple).on(:person_id).times(1)
          lambda { @apples_p2 = Apple.where(:person_id => 5).order('id ASC').all }.should hit_cache(Apple).on(:person_id).times(1)
        else
          lambda { @apples_p1 = Apple.where(:person_id => 4).order('id ASC').all }.should miss_cache(Apple).on(:person_id).times(1)
          lambda { @apples_p2 = Apple.where(:person_id => 5).order('id ASC').all }.should miss_cache(Apple).on(:person_id).times(1)
        end
        @apples_s1.size.should == @store1_apples.size - 1
        @apples_s2.size.should == @store2_apples.size + 1
        @apples_p1.size.should == @person4_apples.size + 1
        @apples_p2.size.should == @person5_apples.size - 1
        @apples_s1.map(&:id).should == @store1_apples.map(&:id) - [@apple_moved_from_s1to2_p5to4.id]
        @apples_s2.map(&:id).should == [@apple_moved_from_s1to2_p5to4.id] + @store2_apples.map(&:id)
        @apples_p1.map(&:id).should == ([@apple_moved_from_s1to2_p5to4.id] + @person4_apples.map(&:id)).sort
        @apples_p2.map(&:id).should ==  (@person5_apples.map(&:id) - [@apple_moved_from_s1to2_p5to4.id]).sort
        # and the index should be cached again
        lambda { Apple.where(:store_id => 1).all }.should hit_cache(Apple).on(:store_id).times(1)
        lambda { Apple.where(:store_id => 2).all }.should hit_cache(Apple).on(:store_id).times(1)
        lambda { Apple.where(:person_id => 4).all }.should hit_cache(Apple).on(:person_id).times(1)
        lambda { Apple.where(:person_id => 5).all }.should hit_cache(Apple).on(:person_id).times(1)
      end
    end

    it "should leave the index alone when a record outside the index is destroyed" do
      # destroy an apple of store 2
      @store2_apples.first.destroy
      # index of apples of store 1 are not affected
      lambda { @apples = Apple.where(:store_id => 1).order('id ASC').all }.should hit_cache(Apple).on(:store_id).times(1)
    end

    it "should leave the index alone when a record outside the index is created" do
      # create an apple for store 2
      Apple.create!(:name => "Fresh Apple", :store_id => 2)
      # index of apples of store 1 are not affected
      lambda { @apples = Apple.where(:store_id => 1).order('id ASC').all }.should hit_cache(Apple).on(:store_id).times(1)
    end
  end
  
  context "invalidate" do
    before(:each) do
      @store1_apples = Apple.where(:store_id => 1).all
      @store2_apples = Apple.where(:store_id => 2).all
      @address_1 = Address.where(:store_id => 1).all
      @address_2 = Address.where(:store_id => 2).all
    end

    it "should invalidate single index" do
      Apple.record_cache[:store_id].invalidate(1)
      lambda{ Apple.where(:store_id => 1).all }.should miss_cache(Apple).on(:store_id).times(1)
    end

    it "should invalidate indexes when using update_all" do
      pending "is there a performant way to invalidate index caches within update_all? only the new value is available, so we should query the old values..." do
        # update 2 apples for index values store 1 and store 2
        Apple.where(:id => [@store1_apples.first.id, @store2_apples.first.id]).update_all(:store_id => 3)
        lambda{ @apples_1 = Apple.where(:store_id => 1).all }.should miss_cache(Apple).on(:store_id).times(1)
        lambda{ @apples_2 = Apple.where(:store_id => 2).all }.should miss_cache(Apple).on(:store_id).times(1)
        @apples_1.map(&:id).sort.should == @store1_apples[1..-1].sort
        @apples_2.map(&:id).sort.should == @store2_apples[1..-1].sort
      end
    end

    it "should invalidate reflection indexes when a has_many relation is updated" do
      # assign different apples to store 2
      lambda{ Apple.where(:store_id => 1).first }.should hit_cache(Apple).on(:store_id).times(1)
      store2_apple_ids = @store2_apples.map(&:id).sort
      store1 = Store.find(1)
      store1.apple_ids = store2_apple_ids
      store1.save!
      # apples in Store 1 should be all (only) the apples that were in Store 2 (cache invalidated)
      lambda{ @apples_1 = Apple.where(:store_id => 1).all }.should miss_cache(Apple).on(:store_id).times(1)
      @apples_1.map(&:id).sort.should == store2_apple_ids
      # there are no apples in Store 2 anymore (incremental cache update, as each apples in store 2 was saved separately)
      lambda{ @apples_2 = Apple.where(:store_id => 2).all }.should hit_cache(Apple).on(:store_id).times(1)
      @apples_2.should == []
    end

    it "should invalidate reflection indexes when a has_one relation is updated" do
      # assign different address to store 2
      lambda{ Address.where(:store_id => 1).limit(1).first }.should hit_cache(Address).on(:store_id).times(1)
      store2 = Store.find(2)
      store2_address = store2.address
      Address.where(:store_id => 1).first.id == 1
      store1 = Store.find(1)
      store1.address = store2_address
      store1.save!
      Address.where(:store_id => 1).first.id == 2
      # address for Store 1 should be the address that was for Store 2 (cache invalidated)
      lambda{ @address_1 = Address.where(:store_id => 1).first }.should hit_cache(Address).on(:store_id).times(1)
      @address_1.id.should == store2_address.id
      # there are no address in Store 2 anymore (incremental cache update, as address for store 2 was saved separately)
      lambda{ @address_2 = Address.where(:store_id => 2).first }.should hit_cache(Address).on(:store_id).times(1)
      @address_2.should be_nil
    end
  end

  context 'subclassing' do
    class RedDelicious < Apple; end
    apple = Apple.find(1)
    delicious = RedDelicious.find(1)
    store_id = apple.store_id
    delicious.store_id = 100
    delicious.save
    apple = Apple.find(1)
    apple.store_id.should_not == store_id
    apple.store_id = store_id
    apple.save
  end

end
