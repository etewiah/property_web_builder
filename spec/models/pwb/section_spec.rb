require 'rails_helper'

module Pwb
  RSpec.describe Section, type: :model do
    let(:section) { FactoryGirl.create(:pwb_section) }

    it 'has a valid factory' do
      expect(section).to be_valid
    end
  end
end
