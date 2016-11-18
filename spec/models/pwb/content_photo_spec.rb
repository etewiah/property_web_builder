require 'rails_helper'

module Pwb
  RSpec.describe ContentPhoto, type: :model do
    let(:content_photo) { FactoryGirl.create(:pwb_content_photo) }

    it "has a valid factory" do
      expect(content_photo).to be_valid
    end
  end
end
