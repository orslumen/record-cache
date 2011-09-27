# Record Cache shared files
["query", "version_store", "multi_read",
 "strategy/base", "strategy/id_cache", "strategy/index_cache", "strategy/request_cache",
 "statistics", "dispatcher", "base"].each do |file|
  require File.dirname(__FILE__) + "/record_cache/#{file}.rb"
end

# Support for Active Record
require 'active_record'
ActiveRecord::Base.send(:include, RecordCache::Base)
require File.dirname(__FILE__) + "/record_cache/active_record.rb"
