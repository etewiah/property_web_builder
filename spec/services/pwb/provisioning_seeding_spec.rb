# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe "Provisioning and Seeding Integration", type: :service do
    let(:service) { ProvisioningService.new }

    # Clean up after each test
    after(:each) do
      Pwb::Current.website = nil
    end

    # Ensure subdomain pool has available subdomains
    before(:each) do
      Pwb::Subdomain.delete_all
      10.times do |i|
        Pwb::Subdomain.create!(name: "testpool-#{i.to_s.rjust(4, '0')}", aasm_state: 'available')
      end
    end

    describe "Full provisioning workflow" do
      it "creates all required resources for a website" do
        unique_id = SecureRandom.hex(4)
        email = "full-flow-#{unique_id}@example.com"

        # Step 1: Start signup - this creates user and reserves a subdomain
        result = service.start_signup(email: email)
        expect(result[:success]).to be true
        user = result[:user]
        reserved_subdomain = result[:subdomain]
        expect(user).to be_persisted
        expect(reserved_subdomain).to be_present

        # Step 2: Configure site using the reserved subdomain
        result = service.configure_site(
          user: user,
          subdomain_name: reserved_subdomain.name,
          site_type: 'residential'
        )
        expect(result[:success]).to be true
        website = result[:website]
        expect(website).to be_owner_assigned

        # Step 3: Provision website
        result = service.provision_website(website: website)
        expect(result[:success]).to be true

        website.reload

        # Verify all resources were created
        expect(website.agency).to be_present
        expect(website.links.count).to be >= 3
        expect(website.field_keys.count).to be >= 5
        expect(website.pages.count).to be >= 1
        expect(website).to be_locked_pending_email_verification
      end
    end

    describe "Individual provisioning steps" do
      let(:website) do
        FactoryBot.create(:pwb_website,
          provisioning_state: 'owner_assigned',
          site_type: 'residential',
          seed_pack_name: 'base')
      end

      let(:user) do
        user = FactoryBot.create(:pwb_user,
          email: "step-test-#{SecureRandom.hex(4)}@example.com",
          onboarding_state: 'onboarding')
        FactoryBot.create(:pwb_user_membership,
          user: user,
          website: website,
          role: 'owner',
          active: true)
        user
      end

      before do
        website.update!(owner_email: user.email)
      end

      describe "Agency creation" do
        it "creates agency via seed pack" do
          service.send(:create_agency_for_website, website)

          expect(website.agency).to be_present
          expect(website.agency.display_name).to be_present
        end

        it "creates fallback agency when seed pack fails" do
          # Use a non-existent pack
          website.update!(seed_pack_name: 'nonexistent')

          service.send(:create_agency_for_website, website)

          expect(website.agency).to be_present
        end
      end

      describe "Links creation" do
        it "creates navigation links" do
          service.send(:create_links_for_website, website)

          expect(website.links.count).to be >= 3
        end

        it "creates fallback links when seed pack has none" do
          website.update!(seed_pack_name: 'nonexistent')

          service.send(:create_links_for_website, website)

          expect(website.links.count).to be >= 3
          # Fallback links use top_nav_ prefix and include link_path for proper rendering
          expect(website.links.pluck(:slug)).to include('top_nav_home', 'top_nav_buy', 'top_nav_rent')
          expect(website.links.first.link_path).to be_present
        end
      end

      describe "Field keys creation" do
        it "creates field keys" do
          service.send(:create_field_keys_for_website, website)

          expect(website.field_keys.count).to be >= 5
        end

        it "creates fallback field keys when seed pack has none" do
          website.update!(seed_pack_name: 'nonexistent')

          service.send(:create_field_keys_for_website, website)

          expect(website.field_keys.count).to be >= 5
        end
      end

      describe "Pages creation" do
        it "creates pages and page parts" do
          service.send(:create_pages_for_website, website)

          expect(website.pages.count).to be >= 1
        end

        it "creates fallback pages when seed pack has none" do
          website.update!(seed_pack_name: 'nonexistent')

          service.send(:create_pages_for_website, website)

          # Should use PagesSeeder fallback
          expect(website.pages.count).to be >= 1
        end
      end

      describe "Properties seeding" do
        it "does not fail when no properties are seeded" do
          # Properties are optional
          expect {
            service.send(:seed_properties_for_website, website)
          }.not_to raise_error
        end
      end
    end

    describe "SeedPack integration" do
      let(:website) do
        FactoryBot.create(:pwb_website,
          provisioning_state: 'owner_assigned',
          site_type: 'residential')
      end

      context "with base seed pack" do
        let(:seed_pack) { Pwb::SeedPack.find('base') }

        it "exists and is valid" do
          expect(seed_pack).to be_present
          expect(seed_pack.name).to eq('base')
        end

        it "can seed links to a website" do
          seed_pack.seed_links!(website: website)
          expect(website.links.count).to be >= 3
        end

        it "can seed field keys to a website" do
          seed_pack.seed_field_keys!(website: website)
          expect(website.field_keys.count).to be >= 5
        end

        it "can seed pages to a website" do
          seed_pack.seed_pages!(website: website)
          # Base pack may not have pages directory, so this might not create any
          # But it should not raise an error
        end

        it "can seed page parts to a website" do
          # This will use the fallback PagesSeeder if no page_parts directory exists
          seed_pack.seed_page_parts!(website: website)
        end
      end
    end

    describe "Progress reporting" do
      let(:website) do
        w = FactoryBot.create(:pwb_website,
          provisioning_state: 'owner_assigned',
          site_type: 'residential',
          seed_pack_name: 'base')
        user = FactoryBot.create(:pwb_user,
          email: "progress-#{SecureRandom.hex(4)}@example.com",
          onboarding_state: 'onboarding')
        FactoryBot.create(:pwb_user_membership,
          user: user,
          website: w,
          role: 'owner',
          active: true)
        w.update!(owner_email: user.email)
        w
      end

      it "reports progress during provisioning" do
        progress_updates = []

        service.provision_website(website: website) do |progress|
          progress_updates << progress
        end

        expect(progress_updates).not_to be_empty
        expect(progress_updates.first[:percentage]).to be_a(Integer)
        expect(progress_updates.last[:percentage]).to be >= 80
      end
    end

    describe "Error handling" do
      it "handles missing owner gracefully" do
        website = FactoryBot.create(:pwb_website, provisioning_state: 'pending')
        # No owner membership

        result = service.provision_website(website: website)

        expect(result[:success]).to be false
        expect(result[:errors]).to include(match(/owner/i))
      end

      it "handles invalid starting state" do
        website = FactoryBot.create(:pwb_website, provisioning_state: 'live')

        result = service.provision_website(website: website)

        expect(result[:success]).to be false
        expect(result[:errors]).to include(match(/state/i))
      end
    end

    describe "Idempotency" do
      let(:website) do
        w = FactoryBot.create(:pwb_website,
          provisioning_state: 'owner_assigned',
          site_type: 'residential',
          seed_pack_name: 'base')
        user = FactoryBot.create(:pwb_user,
          email: "idempotent-#{SecureRandom.hex(4)}@example.com",
          onboarding_state: 'onboarding')
        FactoryBot.create(:pwb_user_membership,
          user: user,
          website: w,
          role: 'owner',
          active: true)
        w.update!(owner_email: user.email)
        w
      end

      it "does not duplicate resources when called multiple times" do
        # First create resources
        service.send(:create_agency_for_website, website)
        service.send(:create_links_for_website, website)
        service.send(:create_field_keys_for_website, website)
        service.send(:create_pages_for_website, website)

        initial_agency_id = website.agency&.id
        initial_links_count = website.links.count
        initial_field_keys_count = website.field_keys.count
        initial_pages_count = website.pages.count

        # Call again - should be idempotent
        service.send(:create_agency_for_website, website)
        service.send(:create_links_for_website, website)
        service.send(:create_field_keys_for_website, website)
        service.send(:create_pages_for_website, website)

        website.reload
        expect(website.agency&.id).to eq(initial_agency_id)
        expect(website.links.count).to eq(initial_links_count)
        expect(website.field_keys.count).to eq(initial_field_keys_count)
        expect(website.pages.count).to eq(initial_pages_count)
      end
    end
  end
end
