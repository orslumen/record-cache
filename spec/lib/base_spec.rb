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

  it "should be possible to provide a different logger" do
    custom_logger = Logger.new(STDOUT)
    RecordCache::Base.logger = custom_logger
    RecordCache::Base.logger.should == custom_logger
    RecordCache::Base.logger = nil
    RecordCache::Base.logger.should == ::ActiveRecord::Base.logger
  end
end