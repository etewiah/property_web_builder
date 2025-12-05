module Pwb
  class PropPhoto < ApplicationRecord
    has_one_attached :image
    # Both associations supported for backwards compatibility
    belongs_to :prop, optional: true
    belongs_to :realty_asset, optional: true
  end
end
