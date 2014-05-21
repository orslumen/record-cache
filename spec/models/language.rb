class Language < ActiveRecord::Base

  cache_records :store => :local, :full_table => true

end
