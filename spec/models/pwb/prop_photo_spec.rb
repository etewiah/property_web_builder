require 'rails_helper'

module Pwb
  RSpec.describe PropPhoto, type: :model do
    let(:prop_photo) { FactoryGirl.create(:pwb_prop_photo) }

    it 'has a valid factory' do
      expect(prop_photo).to be_valid
    end
  end
end
