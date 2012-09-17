# encoding: utf-8
require 'spec_helper'

describe RecordCache::Base do

  it "should run a block in enabled mode" do
    RecordCache::Base.disable!
    RecordCache::Base.enabled do
      RecordCache::Base.status.should == RecordCache::ENABLED
    end
    RecordCache::Base.status.should == RecordCache::DISABLED
  end

end