class Banana < ActiveRecord::Base

  cache_records :store => :local, :index => [:person_id]

  belongs_to :store
  belongs_to :person

  after_initialize :do_after_initialize
  after_find :do_after_find

  def logs
    @logs ||= []
  end

  private

    def do_after_initialize
      self.logs << "after_initialize"
    end

    def do_after_find
      self.logs << "after_find"
    end

end
