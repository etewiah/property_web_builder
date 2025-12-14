require 'rails_helper'

module Pwb
  RSpec.describe ProvisioningService do
    let(:service) { ProvisioningService.new }

    after(:each) do
      Pwb::Current.website = nil
    end

    describe '#start_signup' do
      it 'creates a lead user and reserves a subdomain' do
        # Create available subdomains for this test
        5.times { |i| Subdomain.create!(name: "signup-test-#{i}-#{rand(1000..9999)}") }

        result = service.start_signup(email: 'newuser@example.com')

        expect(result[:success]).to be true
        expect(result[:user]).to be_persisted
        expect(result[:user].email).to eq('newuser@example.com')
        expect(result[:user].onboarding_state).to eq('lead')
        expect(result[:subdomain]).to be_present
        expect(result[:subdomain]).to be_reserved
        expect(result[:subdomain].reserved_by_email).to eq('newuser@example.com')
      end
    end

    describe '#start_signup with empty email' do
      it 'returns failure for empty email' do
        result = service.start_signup(email: '')
        expect(result[:success]).to be false
      end
    end

    describe '#check_subdomain_availability' do
      it 'returns valid for available subdomains' do
        result = service.check_subdomain_availability('brand-new-subdomain')
        expect(result[:valid]).to be true
      end

      it 'returns invalid for taken subdomains' do
        FactoryBot.create(:pwb_website, subdomain: 'taken-one')
        result = service.check_subdomain_availability('taken-one')
        expect(result[:valid]).to be false
      end
    end

    describe '#suggest_subdomain' do
      it 'returns a valid subdomain suggestion' do
        suggestion = service.suggest_subdomain
        expect(suggestion).to match(/\A[a-z]+-[a-z]+-\d{2}\z/)
      end
    end

    describe '#configure_site' do
      it 'creates a website with the specified subdomain, site type, and owner membership' do
        # Use unique names per test to avoid conflicts
        unique_suffix = SecureRandom.hex(4)
        subdomain_name = "config-#{unique_suffix}"

        website = FactoryBot.create(:pwb_website)
        user = FactoryBot.create(:pwb_user, email: "config-#{unique_suffix}@example.com", website: website, onboarding_state: 'lead')
        Subdomain.create!(name: subdomain_name, aasm_state: 'reserved', reserved_by_email: "config-#{unique_suffix}@example.com")

        result = service.configure_site(
          user: user,
          subdomain_name: subdomain_name,
          site_type: 'residential'
        )

        expect(result[:success]).to be true
        expect(result[:website]).to be_persisted
        expect(result[:website].subdomain).to eq(subdomain_name)
        expect(result[:website].site_type).to eq('residential')
        # New state machine: configure_site transitions to owner_assigned
        expect(result[:website]).to be_owner_assigned
        expect(result[:membership]).to be_persisted
        expect(result[:membership].role).to eq('owner')
      end

      it 'fails for invalid site type' do
        unique_suffix = SecureRandom.hex(4)
        subdomain_name = "invalid-#{unique_suffix}"

        website = FactoryBot.create(:pwb_website)
        user = FactoryBot.create(:pwb_user, email: "invalid-#{unique_suffix}@example.com", website: website, onboarding_state: 'lead')
        Subdomain.create!(name: subdomain_name, aasm_state: 'reserved', reserved_by_email: "invalid-#{unique_suffix}@example.com")

        result = service.configure_site(
          user: user,
          subdomain_name: subdomain_name,
          site_type: 'invalid_type'
        )

        expect(result[:success]).to be false
        expect(result[:errors]).to include(match(/Invalid site type/))
      end
    end

    describe '#provision_website' do
      it 'provisions the website to locked_pending_email_verification state (awaiting email verification)' do
        # Use unique email to avoid test pollution
        unique_suffix = SecureRandom.hex(4)
        base_website = FactoryBot.create(:pwb_website)
        user = FactoryBot.create(:pwb_user,
          email: "provision-#{unique_suffix}@example.com",
          website: base_website,
          onboarding_state: 'onboarding')
        # New state machine: provisioning starts from owner_assigned (after configure_site)
        website = FactoryBot.create(:pwb_website,
          provisioning_state: 'owner_assigned',
          site_type: 'residential',
          seed_pack_name: 'base',
          owner_email: "provision-#{unique_suffix}@example.com")
        FactoryBot.create(:pwb_user_membership,
          user: user,
          website: website,
          role: 'owner',
          active: true)

        result = service.provision_website(website: website)

        expect(result[:success]).to be true
        website.reload
        # Provisioning now ends at locked_pending_email_verification (awaiting email verification)
        expect(website).to be_locked_pending_email_verification
        expect(website.provisioning_completed_at).to be_present
        expect(website.email_verification_token).to be_present
        # User onboarding is NOT completed during provisioning anymore - it happens after registration
      end
    end

    describe '#retry_provisioning' do
      let(:failed_website) do
        FactoryBot.create(:pwb_website,
          provisioning_state: 'failed',
          provisioning_error: 'Previous error')
      end

      it 'fails for non-failed websites' do
        live_website = FactoryBot.create(:pwb_website, provisioning_state: 'live')

        result = service.retry_provisioning(website: live_website)

        expect(result[:success]).to be false
        expect(result[:errors]).to include(match(/not in failed state/))
      end
    end
  end
end
