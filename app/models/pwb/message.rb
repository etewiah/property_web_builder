module Pwb
  class Message < ApplicationRecord
    belongs_to :client
  end
end
