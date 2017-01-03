require 'rails_helper'

module Pwb
  RSpec.describe User, type: :model do
    let(:user) { FactoryGirl.create(:pwb_user, email: "user@example.org", password: "very-secret", admin:true) }
    it 'has a valid factory' do
      expect(user).to be_valid
    end
  end
end
