module Pwb
  class Message < ApplicationRecord
    belongs_to :contact, optional: true
    belongs_to :website, optional: true
  end
end
