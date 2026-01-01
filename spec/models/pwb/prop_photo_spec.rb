# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_prop_photos
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
require 'rails_helper'

module Pwb
  RSpec.describe PropPhoto, type: :model do
    let(:prop_photo) { FactoryBot.create(:pwb_prop_photo) }

    it 'has a valid factory' do
      expect(prop_photo).to be_valid
    end
  end
end
