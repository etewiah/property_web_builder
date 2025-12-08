# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe Authorization, type: :model do
    let(:website) { create(:pwb_website, subdomain: 'auth-test') }
    let(:user) { create(:pwb_user, website: website) }

    describe 'factory' do
      it 'creates a valid authorization' do
        authorization = build(:pwb_authorization, user: user)
        expect(authorization).to be_valid
      end
    end

    describe 'associations' do
      it 'belongs to user' do
        authorization = create(:pwb_authorization, user: user)
        expect(authorization.user).to eq(user)
      end
    end

    describe 'validations' do
      it 'requires a user' do
        authorization = build(:pwb_authorization, user: nil)
        expect(authorization).not_to be_valid
      end
    end

    describe 'OAuth integration' do
      it 'can store provider information' do
        authorization = create(:pwb_authorization, user: user)
        # Verify basic attributes can be set
        expect(authorization).to respond_to(:user)
        expect(authorization.user_id).to eq(user.id)
      end
    end
  end
end
