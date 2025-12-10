module Pwb
  class PropPhoto < ApplicationRecord
    include ExternalImageSupport

    has_one_attached :image, dependent: :purge_later
    # Both associations supported for backwards compatibility
    belongs_to :prop, optional: true
    belongs_to :realty_asset, optional: true

    # Check if website is in external image mode
    def external_image_mode?
      prop&.website&.external_image_mode || false
    end
  end
end
