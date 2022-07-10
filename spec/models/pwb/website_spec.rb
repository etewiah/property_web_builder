require 'rails_helper'

module Pwb
  RSpec.describe Website, type: :model do
    let(:website) { Website.unique_instance || FactoryBot.create(:pwb_website) }
    # let(:website2) { FactoryBot.create(:pwb_website) }

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

    it 'gets element class' do
      element_class = website.get_element_class "page_top_strip_color"
      expect(element_class).to be_present
    end

    it 'gets style variable' do
      style_var = website.get_style_var "primary-color"
      expect(style_var).to be_present
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
