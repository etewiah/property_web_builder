require 'rails_helper'

module Pwb
  RSpec.describe Prop, type: :model do
    let(:prop) { FactoryGirl.create(:pwb_prop) }

    it 'has a valid factory' do
      expect(prop).to be_valid
    end
  end
end
