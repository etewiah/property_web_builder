module Pwb
  class PropPhoto < ApplicationRecord
    has_one_attached :image
    belongs_to :prop, optional: true
  end
end
