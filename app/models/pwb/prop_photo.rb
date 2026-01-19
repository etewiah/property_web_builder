# == Schema Information
#
# Table name: pwb_prop_photos
# Database name: primary
#
#  id              :integer          not null, primary key
#  description     :string
#  external_url    :string
#  file_size       :integer
#  folder          :string
#  image           :string
#  sort_order      :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  prop_id         :integer
#  realty_asset_id :uuid
#
# Indexes
#
#  index_pwb_prop_photos_on_prop_id          (prop_id)
#  index_pwb_prop_photos_on_realty_asset_id  (realty_asset_id)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#
module Pwb
  class PropPhoto < ApplicationRecord
    include ExternalImageSupport
    include ResponsiveVariantSupport

    has_one_attached :image, dependent: :purge_later
    # Both associations supported for backwards compatibility
    belongs_to :prop, optional: true
    belongs_to :realty_asset, optional: true, counter_cache: :prop_photos_count

    # Check if website is in external image mode
    def external_image_mode?
      prop&.website&.external_image_mode || false
    end
  end
end
