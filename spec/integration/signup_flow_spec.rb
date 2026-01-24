# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Signup Flow Integration', type: :request do
  let(:signup_service) { Pwb::SignupApiService.new }

  # Ensure subdomain pool has available subdomains
  before do
    10.times { |i| Pwb::Subdomain.create!(name: "signup-flow-#{i}-#{SecureRandom.hex(4)}") }
  end

  after(:each) do
    Pwb::Current.website = nil
  end

  describe 'Complete Signup Flow' do
    it 'completes full signup: start -> configure -> provision' do
      # Step 1: Start signup
      start_result = signup_service.start_signup(email: 'complete-flow@example.com')

      expect(start_result[:success]).to be true
      user = start_result[:user]
      expect(user).to be_persisted
      expect(user.signup_token).to be_present
      expect(start_result[:subdomain]).to be_reserved

      # Step 2: Find user by token (simulating API flow)
      found_user = signup_service.find_user_by_token(start_result[:signup_token])
      expect(found_user).to eq(user)

      # Step 3: Configure site - use the reserved subdomain from start_signup
      # The start_signup already reserved a subdomain for this email
      reserved_subdomain = start_result[:subdomain]

      configure_result = signup_service.configure_site(
        user: user,
        subdomain_name: reserved_subdomain.name,
        site_type: 'residential'
      )

      expect(configure_result[:success]).to be true
      website = configure_result[:website]
      expect(website).to be_persisted
      expect(website.subdomain).to eq(reserved_subdomain.name)
      expect(website.site_type).to eq('residential')
      expect(website).to be_owner_assigned

      # Step 4: Verify user membership
      membership = Pwb::UserMembership.find_by(user: user, website: website)
      expect(membership).to be_present
      expect(membership.role).to eq('owner')
      expect(membership).to be_active
    end
  end

  describe 'Step 1: Start Signup' do
    context 'with new user' do
      it 'creates user and reserves subdomain' do
        result = signup_service.start_signup(email: 'newuser@signup.test')

        expect(result[:success]).to be true
        expect(result[:user].email).to eq('newuser@signup.test')
        expect(result[:user].confirmed_at).to be_present
        expect(result[:subdomain]).to be_present
        expect(result[:signup_token]).to be_present
      end

      it 'token expires in 24 hours' do
        result = signup_service.start_signup(email: 'expiry@test.com')

        expect(result[:user].signup_token_expires_at).to be_within(1.minute).of(24.hours.from_now)
      end
    end

    context 'with existing user' do
      let!(:existing_user) do
        user = Pwb::User.new(email: 'existing@signup.test', password: 'password123', confirmed_at: Time.current)
        user.save(validate: false)
        user
      end

      it 'returns success and generates new token for user without website' do
        result = signup_service.start_signup(email: 'existing@signup.test')

        expect(result[:success]).to be true
        expect(result[:user]).to eq(existing_user)
        expect(result[:signup_token]).to be_present
      end

      it 'returns error for user with existing website' do
        website = create(:pwb_website)
        # The service checks user.websites (has_many through user_memberships)
        # so we need to create a membership, not just set website_id
        create(:pwb_user_membership, user: existing_user, website: website, role: 'owner', active: true)

        result = signup_service.start_signup(email: 'existing@signup.test')

        expect(result[:success]).to be false
        expect(result[:errors].first).to include('already exists')
      end
    end
  end

  describe 'Step 2: Token Verification' do
    # Use let! to ensure user is created before the test runs
    let!(:user) do
      u = Pwb::User.new(
        email: 'token@test.com',
        password: 'password123',
        confirmed_at: Time.current,
        signup_token: 'valid-token',
        signup_token_expires_at: 1.hour.from_now
      )
      u.save(validate: false)
      u
    end

    it 'finds user by valid token' do
      found = signup_service.find_user_by_token('valid-token')
      expect(found).to eq(user)
    end

    it 'returns nil for expired token' do
      user.update_columns(signup_token_expires_at: 1.hour.ago)

      found = signup_service.find_user_by_token('valid-token')
      expect(found).to be_nil
    end

    it 'returns nil for invalid token' do
      found = signup_service.find_user_by_token('invalid-token')
      expect(found).to be_nil
    end

    it 'returns nil for blank token' do
      expect(signup_service.find_user_by_token('')).to be_nil
      expect(signup_service.find_user_by_token(nil)).to be_nil
    end
  end

  describe 'Step 3: Site Configuration' do
    let(:user) do
      u = Pwb::User.new(email: 'config@test.com', password: 'password123', confirmed_at: Time.current)
      u.save(validate: false)
      u
    end

    it 'creates website with valid configuration' do
      subdomain = "site-#{SecureRandom.hex(4)}"
      Pwb::Subdomain.create!(name: subdomain, aasm_state: 'reserved', reserved_by_email: user.email)

      result = signup_service.configure_site(
        user: user,
        subdomain_name: subdomain,
        site_type: 'commercial'
      )

      expect(result[:success]).to be true
      expect(result[:website].subdomain).to eq(subdomain)
      expect(result[:website].site_type).to eq('commercial')
    end

    it 'rejects invalid site type' do
      subdomain = "invalid-#{SecureRandom.hex(4)}"
      Pwb::Subdomain.create!(name: subdomain, aasm_state: 'reserved', reserved_by_email: user.email)

      result = signup_service.configure_site(
        user: user,
        subdomain_name: subdomain,
        site_type: 'invalid_type'
      )

      expect(result[:success]).to be false
      expect(result[:errors].first).to include('Invalid site type')
    end

    it 'rejects already taken subdomain' do
      create(:pwb_website, subdomain: 'taken-subdomain')

      result = signup_service.configure_site(
        user: user,
        subdomain_name: 'taken-subdomain',
        site_type: 'residential'
      )

      expect(result[:success]).to be false
      expect(result[:errors].first).to include('already taken')
    end

    context 'subdomain allocation' do
      it 'allocates reserved subdomain to website' do
        subdomain = "reserved-#{SecureRandom.hex(4)}"
        reservation = Pwb::Subdomain.create!(
          name: subdomain,
          aasm_state: 'reserved',
          reserved_by_email: user.email
        )

        result = signup_service.configure_site(
          user: user,
          subdomain_name: subdomain,
          site_type: 'residential'
        )

        expect(result[:success]).to be true
        reservation.reload
        expect(reservation.aasm_state).to eq('allocated')
        expect(reservation.website).to eq(result[:website])
      end

      it 'releases old reservation when choosing different subdomain' do
        old_subdomain = "old-#{SecureRandom.hex(4)}"
        Pwb::Subdomain.create!(
          name: old_subdomain,
          aasm_state: 'reserved',
          reserved_by_email: user.email
        )

        new_subdomain = "new-#{SecureRandom.hex(4)}"
        # New subdomain doesn't need to be in pool for custom names

        result = signup_service.configure_site(
          user: user,
          subdomain_name: new_subdomain,
          site_type: 'residential'
        )

        expect(result[:success]).to be true
        old_reservation = Pwb::Subdomain.find_by(name: old_subdomain)
        expect(old_reservation&.aasm_state).to eq('available')
      end
    end
  end

  describe 'Error Handling' do
    it 'handles database errors gracefully' do
      allow(Pwb::User).to receive(:find_by).and_raise(ActiveRecord::ConnectionNotEstablished)

      result = signup_service.start_signup(email: 'error@test.com')

      expect(result[:success]).to be false
      expect(result[:errors]).to be_present
    end

    it 'handles subdomain pool exhaustion' do
      Pwb::Subdomain.delete_all

      result = signup_service.start_signup(email: 'nopool@test.com')

      expect(result[:success]).to be false
      expect(result[:errors].first).to include('subdomain')
    end
  end

  describe 'Email Normalization' do
    it 'normalizes email to lowercase' do
      result = signup_service.start_signup(email: 'UPPERCASE@EXAMPLE.COM')

      expect(result[:success]).to be true
      expect(result[:user].email).to eq('uppercase@example.com')
    end

    it 'strips whitespace from email' do
      result = signup_service.start_signup(email: '  spaces@example.com  ')

      expect(result[:success]).to be true
      expect(result[:user].email).to eq('spaces@example.com')
    end
  end

  describe 'Concurrent Signup Handling' do
    it 'handles duplicate email attempts gracefully' do
      # First signup
      result1 = signup_service.start_signup(email: 'concurrent@test.com')
      expect(result1[:success]).to be true

      # Second signup with same email (user without website)
      result2 = signup_service.start_signup(email: 'concurrent@test.com')
      expect(result2[:success]).to be true
      expect(result2[:user]).to eq(result1[:user])
    end
  end
end
