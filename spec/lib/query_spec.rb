require 'spec_helper'

describe RecordCache::Query do
  before(:each) do
    @query = RecordCache::Query.new
  end

  context "wheres" do
    it "should be an empty hash by default" do
      @query.wheres.should == {}
    end

    it "should fill wheres on instantiation" do
      @query = RecordCache::Query.new({:id => 1})
      @query.wheres.should == {:id => 1}
    end

    it "should keep track of where clauses" do
      @query.where(:name, "My name")
      @query.where(:id, [1, 2, 3])
      @query.where(:height, 1.75)
      @query.wheres.should == {:name => "My name", :id => [1, 2, 3], :height => 1.75}
    end

    context "where_values" do
      it "should return nil if the attribute is not defined" do
        @query.where(:idx, 15)
        @query.where_values(:id).should == nil
      end

      it "should return nil if one the value is nil" do
        @query.where(:id, nil)
        @query.where_values(:id).should == nil
      end

      it "should return nil if one of the values is < 1" do
        @query.where(:id, [2, 0, 8])
        @query.where_values(:id).should == nil
      end

      it "should return nil if one of the values is nil" do
        @query.where(:id, ["1", nil, "3"])
        @query.where_values(:id).should == nil
      end

      it "should retrieve an array of integers when a single integer is provided" do
        @query.where(:id, 15)
        @query.where_values(:id).should == [15]
      end

      it "should retrieve an array of integers when a multiple integers are provided" do
        @query.where(:id, [2, 4, 8])
        @query.where_values(:id).should == [2, 4, 8]
      end

      it "should retrieve an array of integers when a single string is provided" do
        @query.where(:id, "15")
        @query.where_values(:id).should == [15]
      end

      it "should retrieve an array of integers when a multiple strings are provided" do
        @query.where(:id, ["2", "4", "8"])
        @query.where_values(:id).should == [2, 4, 8]
      end

      it "should cache the array of values" do
        @query.where(:id, ["2", "4", "8"])
        ids1 = @query.where_values(:id)
        ids2 = @query.where_values(:id)
        ids1.object_id.should == ids2.object_id
      end
    end

    context "where_value" do
      it "should return nil when multiple integers are provided" do
        @query.where(:id, [2, 4, 8])
        @query.where_value(:id).should == nil
      end

      it "should return the id when a single integer is provided" do
        @query.where(:id, 4)
        @query.where_value(:id).should == 4
      end

      it "should return the id when a single string is provided" do
        @query.where(:id, ["4"])
        @query.where_value(:id).should == 4
      end
    end
  end

  context "sort" do
    it "should be an empty array by default" do
      @query.sort_orders.should == []
    end

    it "should keep track of sort orders" do
      @query.order_by("name", true)
      @query.order_by("id", false)
      @query.sort_orders.should == [ ["name", true], ["id", false] ]
    end

    it "should convert attribute to string" do
      @query.order_by(:name, true)
      @query.sort_orders.should == [ ["name", true] ]
    end

    it "should define sorted?" do
      @query.sorted?.should == false
      @query.order_by("name", true)
      @query.sorted?.should == true
    end
  end

  context "limit" do
    it "should be +nil+ by default" do
      @query.limit.should == nil
    end

    it "should keep track of limit" do
      @query.limit = 4
      @query.limit.should == 4
    end

    it "should convert limit to integer" do
      @query.limit = "4"
      @query.limit.should == 4
    end
  end

  context "utility" do
    before(:each) do
      @query.where(:name, "My name & co")
      @query.where(:id, [1, 2, 3])
      @query.order_by("name", true)
      @query.limit = "4"
    end

    it "should generate a unique key for (request) caching purposes" do
      @query.cache_key.should == '4+name?name="My name & co"&id=[1, 2, 3]'
    end

    it "should generate a pretty formatted query" do
      @query.to_s.should == 'SELECT name = "My name & co" AND id = [1, 2, 3] ORDER_BY name ASC LIMIT 4'
    end
  end

end
