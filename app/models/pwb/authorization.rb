module Pwb
  class Authorization < ApplicationRecord
    belongs_to :user
  end
end
