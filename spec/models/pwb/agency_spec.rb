require 'rails_helper'

module Pwb
  RSpec.describe Agency, type: :model do
    let(:agency) { FactoryGirl.create(:pwb_agency) }

    it 'has a valid factory' do
      expect(agency).to be_valid
    end
  end
end
