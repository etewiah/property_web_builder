module Pwb
  class Website < ApplicationRecord

    def self.unique_instance
      # there will be only one row, and its ID must be '1'
      begin
        find(1)
      rescue ActiveRecord::RecordNotFound
        # slight race condition here, but it will only happen once
        row = Website.new
        row.id = 1
        row.save!
        row
      end
    end
  end
end
