module Pwb
  class Client < ApplicationRecord
    has_many :messages
  end
end
