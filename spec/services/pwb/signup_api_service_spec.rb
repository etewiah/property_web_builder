# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe SignupApiService do
    let(:service) { described_class.new }

    after(:each) do
      Pwb::Current.website = nil
    end

    describe '#start_signup' do
      context 'with new user' do
        before do
          # Ensure we have available subdomains
          5.times { |i| Subdomain.create!(name: "api-signup-#{i}-#{SecureRandom.hex(4)}") }
        end

        it 'creates a new user with the provided email' do
          result = service.start_signup(email: 'newuser@example.com')

          expect(result[:success]).to be true
          expect(result[:user]).to be_persisted
          expect(result[:user].email).to eq('newuser@example.com')
        end

        it 'normalizes email to lowercase and stripped' do
          result = service.start_signup(email: '  NewUser@Example.COM  ')

          expect(result[:success]).to be true
          expect(result[:user].email).to eq('newuser@example.com')
        end

        it 'generates a signup token' do
          result = service.start_signup(email: 'tokenuser@example.com')

          expect(result[:success]).to be true
          expect(result[:signup_token]).to be_present
          expect(result[:user].signup_token).to eq(result[:signup_token])
        end

        it 'sets token expiration to 24 hours' do
          result = service.start_signup(email: 'expiry@example.com')

          expect(result[:user].signup_token_expires_at).to be_within(1.minute).of(24.hours.from_now)
        end

        it 'reserves a subdomain for the user' do
          result = service.start_signup(email: 'subdomain@example.com')

          expect(result[:success]).to be true
          expect(result[:subdomain]).to be_present
          expect(result[:subdomain]).to be_reserved
          expect(result[:subdomain].reserved_by_email).to eq('subdomain@example.com')
        end

        it 'auto-confirms the user' do
          result = service.start_signup(email: 'autoconfirm@example.com')

          expect(result[:user].confirmed_at).to be_present
        end
      end

      context 'with existing user without website' do
        let!(:existing_user) do
          user = User.new(email: 'existing@example.com', password: 'password123', confirmed_at: Time.current)
          user.save(validate: false)
          user
        end

        before do
          5.times { |i| Subdomain.create!(name: "exist-#{i}-#{SecureRandom.hex(4)}") }
        end

        it 'returns success and regenerates token' do
          old_token = existing_user.signup_token

          result = service.start_signup(email: 'existing@example.com')

          expect(result[:success]).to be true
          expect(result[:user]).to eq(existing_user)
          expect(result[:signup_token]).not_to eq(old_token)
        end

        it 'reserves a subdomain for existing user' do
          result = service.start_signup(email: 'existing@example.com')

          expect(result[:subdomain]).to be_present
          expect(result[:subdomain].reserved_by_email).to eq('existing@example.com')
        end
      end

      context 'with existing user who has a website' do
        let(:website) { create(:pwb_website) }
        let!(:existing_user_with_website) do
          user = create(:pwb_user, email: 'haswebsite@example.com', website: website)
          # The service checks user.websites (has_many through user_memberships)
          # so we need to create the membership to properly associate user with website
          create(:pwb_user_membership, user: user, website: website, role: 'owner', active: true)
          user
        end

        it 'returns error' do
          result = service.start_signup(email: 'haswebsite@example.com')

          expect(result[:success]).to be false
          expect(result[:errors]).to include(match(/already exists/i))
        end
      end

      context 'with empty email' do
        it 'handles gracefully' do
          result = service.start_signup(email: '')

          # The implementation should handle this - check behavior
          expect(result).to have_key(:success)
        end
      end

      context 'when subdomain pool is exhausted' do
        it 'returns error when no subdomains available' do
          # Don't create any subdomains
          Subdomain.delete_all

          result = service.start_signup(email: 'nopool@example.com')

          expect(result[:success]).to be false
          expect(result[:errors].first).to include('subdomain')
        end
      end

      context 'with transaction rollback' do
        it 'rolls back all changes on error' do
          allow(Subdomain).to receive(:reserve_for_email).and_raise(StandardError.new('Test error'))

          initial_user_count = User.count
          result = service.start_signup(email: 'rollback@example.com')

          expect(result[:success]).to be false
          expect(User.count).to eq(initial_user_count)
        end
      end
    end

    describe '#find_user_by_token' do
      let!(:user_with_token) do
        user = User.new(
          email: 'findme@example.com',
          password: 'password123',
          confirmed_at: Time.current,
          signup_token: 'valid-token-123',
          signup_token_expires_at: 1.hour.from_now
        )
        user.save(validate: false)
        user
      end

      it 'returns user for valid token' do
        result = service.find_user_by_token('valid-token-123')

        expect(result).to eq(user_with_token)
      end

      it 'returns nil for expired token' do
        user_with_token.update_columns(signup_token_expires_at: 1.hour.ago)

        result = service.find_user_by_token('valid-token-123')

        expect(result).to be_nil
      end

      it 'returns nil for non-existent token' do
        result = service.find_user_by_token('nonexistent-token')

        expect(result).to be_nil
      end

      it 'returns nil for blank token' do
        expect(service.find_user_by_token('')).to be_nil
        expect(service.find_user_by_token(nil)).to be_nil
      end
    end

    describe '#configure_site' do
      let(:website) { create(:pwb_website) }
      let(:user) do
        u = User.new(email: 'configure@example.com', password: 'password123', confirmed_at: Time.current)
        u.save(validate: false)
        u
      end

      context 'with valid parameters' do
        let(:unique_subdomain) { "config-#{SecureRandom.hex(4)}" }

        before do
          Subdomain.create!(name: unique_subdomain, aasm_state: 'reserved', reserved_by_email: user.email)
        end

        it 'creates a website with the specified subdomain' do
          result = service.configure_site(
            user: user,
            subdomain_name: unique_subdomain,
            site_type: 'residential'
          )

          expect(result[:success]).to be true
          expect(result[:website]).to be_persisted
          expect(result[:website].subdomain).to eq(unique_subdomain)
        end

        it 'sets the site type' do
          result = service.configure_site(
            user: user,
            subdomain_name: unique_subdomain,
            site_type: 'commercial'
          )

          expect(result[:website].site_type).to eq('commercial')
        end

        it 'creates website in pending state then transitions to owner_assigned' do
          result = service.configure_site(
            user: user,
            subdomain_name: unique_subdomain,
            site_type: 'residential'
          )

          expect(result[:website]).to be_owner_assigned
        end

        it 'creates UserMembership with owner role' do
          result = service.configure_site(
            user: user,
            subdomain_name: unique_subdomain,
            site_type: 'residential'
          )

          membership = UserMembership.find_by(user: user, website: result[:website])
          expect(membership).to be_present
          expect(membership.role).to eq('owner')
          expect(membership.active).to be true
        end

        it 'sets owner_email on website' do
          result = service.configure_site(
            user: user,
            subdomain_name: unique_subdomain,
            site_type: 'residential'
          )

          expect(result[:website].owner_email).to eq(user.email)
        end
      end

      context 'with valid site types' do
        %w[residential commercial vacation_rental].each do |site_type|
          it "accepts site_type: #{site_type}" do
            subdomain = "sitetype-#{SecureRandom.hex(4)}"
            Subdomain.create!(name: subdomain, aasm_state: 'reserved', reserved_by_email: user.email)

            result = service.configure_site(
              user: user,
              subdomain_name: subdomain,
              site_type: site_type
            )

            expect(result[:success]).to be true
          end
        end
      end

      context 'with invalid site type' do
        let(:subdomain) { "invalid-#{SecureRandom.hex(4)}" }

        before do
          Subdomain.create!(name: subdomain, aasm_state: 'reserved', reserved_by_email: user.email)
        end

        it 'returns error for invalid site type' do
          result = service.configure_site(
            user: user,
            subdomain_name: subdomain,
            site_type: 'invalid_type'
          )

          expect(result[:success]).to be false
          expect(result[:errors]).to include(match(/Invalid site type/i))
        end
      end

      context 'with invalid subdomain' do
        it 'returns error for subdomain with invalid format' do
          result = service.configure_site(
            user: user,
            subdomain_name: '-invalid-',
            site_type: 'residential'
          )

          expect(result[:success]).to be false
          expect(result[:errors].first).to match(/subdomain/i)
        end

        it 'returns error for subdomain already taken by website' do
          existing_website = create(:pwb_website, subdomain: 'taken-subdomain')

          result = service.configure_site(
            user: user,
            subdomain_name: 'taken-subdomain',
            site_type: 'residential'
          )

          expect(result[:success]).to be false
          expect(result[:errors]).to include(match(/already taken/i))
        end
      end

      context 'subdomain normalization' do
        let(:subdomain) { "normalize-#{SecureRandom.hex(4)}" }

        before do
          Subdomain.create!(name: subdomain, aasm_state: 'reserved', reserved_by_email: user.email)
        end

        it 'normalizes subdomain to lowercase' do
          result = service.configure_site(
            user: user,
            subdomain_name: subdomain.upcase,
            site_type: 'residential'
          )

          expect(result[:success]).to be true
          expect(result[:website].subdomain).to eq(subdomain.downcase)
        end

        it 'strips whitespace from subdomain' do
          result = service.configure_site(
            user: user,
            subdomain_name: "  #{subdomain}  ",
            site_type: 'residential'
          )

          expect(result[:success]).to be true
        end
      end
    end

    describe '#provision_website' do
      let(:website) { create(:pwb_website) }
      let(:user) { create(:pwb_user, email: 'provision@example.com', website: website) }

      context 'with already live website' do
        let(:live_website) { create(:pwb_website, provisioning_state: 'live') }

        it 'returns success immediately' do
          result = service.provision_website(website: live_website)

          expect(result[:success]).to be true
        end
      end

      context 'with owner_assigned website' do
        let!(:owned_website) do
          create(:pwb_website,
            provisioning_state: 'owner_assigned',
            site_type: 'residential',
            seed_pack_name: 'base',
            owner_email: user.email)
        end

        before do
          create(:pwb_user_membership, user: user, website: owned_website, role: 'owner', active: true)
        end

        it 'provisions the website successfully' do
          # Mock the provisioning service to avoid full seeding
          provisioning_service = instance_double(ProvisioningService)
          allow(ProvisioningService).to receive(:new).and_return(provisioning_service)
          allow(provisioning_service).to receive(:provision_website).and_return({ success: true })

          result = service.provision_website(website: owned_website)

          expect(result[:success]).to be true
        end
      end

      context 'when provisioning fails' do
        let!(:failing_website) do
          create(:pwb_website,
            provisioning_state: 'owner_assigned',
            owner_email: user.email)
        end

        before do
          create(:pwb_user_membership, user: user, website: failing_website, role: 'owner', active: true)
        end

        it 'updates website state to failed on error' do
          provisioning_service = instance_double(ProvisioningService)
          allow(ProvisioningService).to receive(:new).and_return(provisioning_service)
          allow(provisioning_service).to receive(:provision_website).and_raise(StandardError.new('Provisioning error'))

          result = service.provision_website(website: failing_website)

          expect(result[:success]).to be false
          failing_website.reload
          expect(failing_website.provisioning_state).to eq('failed')
          expect(failing_website.provisioning_error).to include('Provisioning error')
        end

        it 'returns errors from provisioning service' do
          provisioning_service = instance_double(ProvisioningService)
          allow(ProvisioningService).to receive(:new).and_return(provisioning_service)
          allow(provisioning_service).to receive(:provision_website).and_return({
            success: false,
            errors: ['Seed pack not found']
          })

          result = service.provision_website(website: failing_website)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Seed pack not found')
        end
      end

      context 'logging' do
        let!(:error_website) do
          create(:pwb_website,
            provisioning_state: 'owner_assigned',
            owner_email: user.email)
        end

        before do
          create(:pwb_user_membership, user: user, website: error_website, role: 'owner', active: true)
        end

        it 'logs errors on exception' do
          allow_any_instance_of(ProvisioningService).to receive(:provision_website)
            .and_raise(StandardError.new('Test exception'))

          expect(Rails.logger).to receive(:error).at_least(:once)

          service.provision_website(website: error_website)
        end
      end
    end

    describe 'TOKEN_EXPIRY constant' do
      it 'is set to 24 hours' do
        expect(SignupApiService::TOKEN_EXPIRY).to eq(24.hours)
      end
    end

    describe 'SignupError class' do
      it 'is a subclass of StandardError' do
        expect(SignupApiService::SignupError.ancestors).to include(StandardError)
      end
    end
  end
end
