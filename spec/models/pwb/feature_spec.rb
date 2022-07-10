require 'rails_helper'

module Pwb
  RSpec.describe Feature, type: :model do
    let(:feature) { FactoryBot.create(:pwb_feature) }

    it 'has a valid factory' do
      expect(feature).to be_valid
    end
  end
end
