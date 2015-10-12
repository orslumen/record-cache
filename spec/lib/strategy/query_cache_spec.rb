require 'spec_helper'

# This describes the behaviour as expected when ActiveRecord::QueryCache is
# enabled. ActiveRecord::QueryCache is enabled by default in rails via a
# middleware. During the scope of a request that cache is used.
#
# In console mode (or within e.g. a cron job) QueryCache isn't enabled.
# You can still take advantage of this cache by executing
#
#   ActiveRecord::Base.cache do
#     # your queries
#   end
#
# Be aware that though that during the execution of the block if updates
# happen to records by another process, while you have already got
# references to that records in QueryCache, that you won't see the changes
# made by the other process.
RSpec.describe "QueryCache" do

  it "should retrieve a record from the QueryCache" do
    ActiveRecord::Base.cache do
      expect{ Store.find(1) }.to miss_cache(Store).on(:id).times(1)
      second_lookup = expect{ Store.find(1) }
      second_lookup.to miss_cache(Store).times(0)
      second_lookup.to hit_cache(Store).on(:id).times(0)
    end
  end

  it "should maintain object identity when the same query is used" do
    ActiveRecord::Base.cache do
      @store_1 = Store.find(1)
      @store_2 = Store.find(1)
      expect(@store_1).to eq(@store_2)
      expect(@store_1.object_id).to eq(@store_2.object_id)
    end
  end

  context "record_change" do
    it "should clear the query cache completely when a record is created" do
      ActiveRecord::Base.cache do
        init_query_cache
        expect{ Store.find(2) }.to hit_cache(Store).times(0)
        expect{ Apple.find(1) }.to hit_cache(Apple).times(0)
        Store.create!(:name => "New Apple Store")
        expect{ Store.find(2) }.to hit_cache(Store).times(1)
        expect{ Apple.find(1) }.to hit_cache(Apple).times(1)
      end
    end

    it "should clear the query cache completely when a record is updated" do
      ActiveRecord::Base.cache do
        init_query_cache
        expect{ Store.find(2) }.to hit_cache(Store).times(0)
        expect{ Apple.find(1) }.to hit_cache(Apple).times(0)
        @store1.name = "Store E"
        @store1.save!
        expect{ Store.find(2) }.to hit_cache(Store).times(1)
        expect{ Apple.find(1) }.to hit_cache(Apple).times(1)
      end
    end

    it "should clear the query cache completely when a record is destroyed" do
      ActiveRecord::Base.cache do
        init_query_cache
        expect{ Store.find(2) }.to hit_cache(Store).times(0)
        expect{ Apple.find(1) }.to hit_cache(Apple).times(0)
        @store1.destroy
        expect{ Store.find(2) }.to hit_cache(Store).times(1)
        expect{ Apple.find(1) }.to hit_cache(Apple).times(1)
      end
    end
  end

  private

    # Cache a few objects in QueryCache to test with
    def init_query_cache
      @store1 = Store.find(1)
      @store2 = Store.find(2)
      @apple1 = Apple.find(1)
    end

end
