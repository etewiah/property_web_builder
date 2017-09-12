require 'rails_helper'


module Pwb
  RSpec.describe Page, type: :model do
    let(:page) { FactoryGirl.create(:pwb_page) }

    it 'has a valid factory' do
      expect(page).to be_valid
    end

    it 'updates fragment correctly' do
      page.set_fragment_details "label", "en", {"blocks": {}}, "fragment_html"
      page.save!
      # byebug
      expect(page.details.to_json).to have_json_path("fragments")
      expect(page.details.to_json).to have_json_path("fragments/label/en/blocks")
    end

  end
end
