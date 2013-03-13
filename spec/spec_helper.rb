dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir + "/../lib"
$LOAD_PATH.unshift dir

require "rubygems"
require "test/unit"
require "rspec"
require 'rr'
require 'database_cleaner'
require "logger"
require "record_cache"
require "record_cache/test/resettable_version_store"

# spec support files
Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f}

# logging
Dir.mkdir(dir + "/log") unless File.exists?(dir + "/log")
ActiveRecord::Base.logger = Logger.new(dir + "/log/debug.log")
# ActiveRecord::Base.logger = Logger.new(STDOUT)

# SQL Lite
ActiveRecord::Base.configurations = YAML::load(IO.read(dir + "/db/database.yml"))
ActiveRecord::Base.establish_connection("sqlite3")

# Initializers + Model + Data
load(dir + "/initializers/record_cache.rb")
load(dir + "/db/schema.rb")
Dir["#{dir}/models/*.rb"].each {|f| load(f) }
load(dir + "/db/seeds.rb")

# Clear cache after each test
RSpec.configure do |config|
  config.mock_with :rr
  
  config.before(:each) do
    stub(RecordCache::Base).cache_writeable? {true}
    RecordCache::Base.enable
    DatabaseCleaner.start
  end
  
  config.after(:each) do
    DatabaseCleaner.clean
    RecordCache::Base.version_store.reset!
  end
end
