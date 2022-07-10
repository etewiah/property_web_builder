require 'rails_helper'

module Pwb
  RSpec.describe Address, type: :model do
    let(:address) { FactoryBot.create(:pwb_address) }

    it 'has a valid factory' do
      expect(address).to be_valid
    end
  end
end
