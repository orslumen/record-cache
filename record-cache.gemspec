# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "record_cache/version"

Gem::Specification.new do |s|
  s.name        = "record-cache"
  s.version     = RecordCache::Version::STRING
  s.authors     = ["Orslumen"]
  s.email       = "orslumen@gmail.com"
  s.homepage    = "https://github.com/orslumen/record-cache"
  s.summary     = "Record Cache v#{RecordCache::Version::STRING} transparantly stores Records in a Cache Store and retrieve those Records from the store when queried (by ID) using Active Model."
  s.description = "Record Cache for Rails 3"

  s.files            = `git ls-files -- lib/*`.split("\n")
  s.test_files       = `git ls-files -- spec/*`.split("\n")
  s.rdoc_options     = ["--charset=UTF-8"]
  s.require_path     = "lib"

  s.add_runtime_dependency "rails", [">= 3.0"] # add ,"< 3.1" when testing active_record_30 code

  s.add_development_dependency "activerecord", [">= 3.0"] # add ,"< 3.1" when testing active_record_30 code
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rake"
  s.add_development_dependency "rcov"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rr"
  s.add_development_dependency "database_cleaner"
  s.add_development_dependency "rdoc"

end
