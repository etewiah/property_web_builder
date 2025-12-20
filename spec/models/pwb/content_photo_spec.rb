# == Schema Information
#
# Table name: pwb_content_photos
#
#  id           :integer          not null, primary key
#  block_key    :string
#  description  :string
#  external_url :string
#  file_size    :integer
#  folder       :string
#  image        :string
#  sort_order   :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  content_id   :integer
#
# Indexes
#
#  index_pwb_content_photos_on_content_id  (content_id)
#
require 'rails_helper'

module Pwb
  RSpec.describe ContentPhoto, type: :model do
    let(:website) { FactoryBot.create(:pwb_website) }
    let(:content_photo) { FactoryBot.create(:pwb_content_photo) }

    # Set tenant context for specs that use factories
    around do |example|
      ActsAsTenant.with_tenant(website) do
        example.run
      end
    end

    it 'has a valid factory' do
      expect(content_photo).to be_valid
    end
  end
end
