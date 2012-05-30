# Record Cache files
require "record_cache/version"
["query", "version_store", "multi_read",
 "strategy/util", "strategy/base", "strategy/request_cache", "strategy/unique_index_cache", "strategy/full_table_cache", "strategy/index_cache",
 "statistics", "dispatcher", "base"].each do |file|
  require File.dirname(__FILE__) + "/record_cache/#{file}.rb"
end

# Load Data Stores (currently only support for Active Record)
require File.dirname(__FILE__) + "/record_cache/datastore/active_record.rb"
