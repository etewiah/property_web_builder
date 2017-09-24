module Pwb
  class Message < ApplicationRecord
    belongs_to :contact, optional: true
  end
end
