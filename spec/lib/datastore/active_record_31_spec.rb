require 'spec_helper'

describe RecordCache::ActiveRecord do

  it "paramterized find_by_sql should work" do
    Apple.find_by_sql("select * from apples where id = 1").should == [Apple.find(1)]
    Apple.find_by_sql(["select * from apples where id = ?", 2]).should == [Apple.find(2)]
  end

end