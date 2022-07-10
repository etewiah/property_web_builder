require 'rails_helper'

module Pwb
  RSpec.describe Translation, type: :model do
    let(:translation) { FactoryBot.create(:pwb_translation) }
    it 'has a valid factory' do
      expect(translation).to be_valid
    end
  end
end
