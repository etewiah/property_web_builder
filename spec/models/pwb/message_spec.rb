require 'rails_helper'

module Pwb
  RSpec.describe Message, type: :model do
    let(:message) { FactoryBot.create(:pwb_message) }

    it 'has a valid factory' do
      expect(message).to be_valid
    end
  end
end
