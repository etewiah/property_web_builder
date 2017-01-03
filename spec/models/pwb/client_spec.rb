require 'rails_helper'

module Pwb
  RSpec.describe Client, type: :model do
    let(:client) { FactoryGirl.create(:pwb_client) }

    it 'has a valid factory' do
      expect(client).to be_valid
    end
  end
end
