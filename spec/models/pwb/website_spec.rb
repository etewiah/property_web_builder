require 'rails_helper'

module Pwb
  RSpec.describe Website, type: :model do
    let(:website) { Website.unique_instance || FactoryGirl.create(:pwb_website) }
    # let(:website2) { FactoryGirl.create(:pwb_website) }

    it 'has correct unique_instance' do
      expect(Website.unique_instance.id).to eq(1)
    end

    # not a useful test (and will be wrong if seed data is used)
    # it 'has correct defaults' do
    #   expect(Website.unique_instance.supported_locales).to eq(["en-UK"])
    # end

    it 'has a valid factory' do
      expect(website).to be_valid
    end

    it 'sets theme_name to default if invalid_name is provided' do
      current_theme_name = website.theme_name
      website.theme_name = "invalid_name"
      website.save!
      expect(website.theme_name).to eq(current_theme_name)
    end

    it 'sets theme_name correctly if valid_name is provided' do
      website.theme_name = "berlin"
      website.save!
      expect(website.theme_name).to eq("berlin")
    end
  end
end
