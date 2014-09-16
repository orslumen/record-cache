# encoding: utf-8
require 'spec_helper'

describe RecordCache::Base do

  it "should run a block in enabled mode" do
    RecordCache::Base.disable!
    RecordCache::Base.enabled do
      expect(RecordCache::Base.status).to eq(RecordCache::ENABLED)
    end
    expect(RecordCache::Base.status).to eq(RecordCache::DISABLED)
  end

  it "should be possible to provide a different logger" do
    custom_logger = Logger.new(STDOUT)
    RecordCache::Base.logger = custom_logger
    expect(RecordCache::Base.logger).to eq(custom_logger)
    RecordCache::Base.logger = nil
    expect(RecordCache::Base.logger).to eq(::ActiveRecord::Base.logger)
  end
end