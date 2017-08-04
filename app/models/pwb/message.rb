module Pwb
  class Message < ApplicationRecord
    belongs_to :client, optional: true
  end
end
