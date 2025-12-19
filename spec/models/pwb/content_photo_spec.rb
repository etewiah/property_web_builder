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
