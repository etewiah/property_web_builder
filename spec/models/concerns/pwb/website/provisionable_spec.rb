# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::WebsiteProvisionable, type: :model do
  let(:website) { create(:pwb_website, provisioning_state: 'pending') }

  describe 'AASM states' do
    it 'starts in pending state' do
      expect(website).to be_pending
    end

    it 'defines all expected states' do
      expected_states = %w[
        pending owner_assigned agency_created links_created
        field_keys_created properties_seeded ready
        locked_pending_email_verification locked_pending_registration
        live failed suspended terminated
      ]
      expect(Pwb::Website.aasm.states.map(&:name).map(&:to_s)).to match_array(expected_states)
    end
  end

  describe 'provisioning guards' do
    describe '#has_owner?' do
      it 'returns false when no owner membership exists' do
        expect(website.has_owner?).to be false
      end

      it 'returns true when active owner membership exists' do
        create(:pwb_user_membership, website: website, role: 'owner', active: true)
        expect(website.has_owner?).to be true
      end

      it 'returns false when owner membership is inactive' do
        create(:pwb_user_membership, website: website, role: 'owner', active: false)
        expect(website.has_owner?).to be false
      end
    end

    describe '#has_agency?' do
      it 'returns false when no agency exists' do
        expect(website.has_agency?).to be false
      end

      it 'returns true when agency exists' do
        create(:pwb_agency, website: website)
        expect(website.has_agency?).to be true
      end
    end

    describe '#has_links?' do
      it 'returns false when less than 3 links exist' do
        create_list(:pwb_link, 2, website: website)
        expect(website.has_links?).to be false
      end

      it 'returns true when 3 or more links exist' do
        create_list(:pwb_link, 3, website: website)
        expect(website.has_links?).to be true
      end
    end

    describe '#has_field_keys?' do
      it 'returns false when less than 5 field keys exist' do
        create_list(:pwb_field_key, 4, website: website)
        expect(website.has_field_keys?).to be false
      end

      it 'returns true when 5 or more field keys exist' do
        create_list(:pwb_field_key, 5, website: website)
        expect(website.has_field_keys?).to be true
      end
    end

    describe '#provisioning_complete?' do
      it 'returns false when any requirement is missing' do
        expect(website.provisioning_complete?).to be false
      end

      it 'returns true when all requirements are met' do
        create(:pwb_user_membership, website: website, role: 'owner', active: true)
        create(:pwb_agency, website: website)
        create_list(:pwb_link, 3, website: website)
        create_list(:pwb_field_key, 5, website: website)
        expect(website.provisioning_complete?).to be true
      end
    end

    describe '#can_go_live?' do
      it 'returns false when provisioning is incomplete' do
        website.subdomain = 'test-site'
        expect(website.can_go_live?).to be false
      end

      it 'returns false when subdomain is missing' do
        website.subdomain = nil
        expect(website.can_go_live?).to be false
      end
    end
  end

  describe 'state transitions' do
    before do
      # Set up all requirements for full provisioning
      create(:pwb_user_membership, website: website, role: 'owner', active: true)
      create(:pwb_agency, website: website)
      create_list(:pwb_link, 3, website: website)
      create_list(:pwb_field_key, 5, website: website)
      website.update!(subdomain: 'test-site')
    end

    it 'transitions through provisioning steps' do
      expect(website).to be_pending

      website.assign_owner!
      expect(website).to be_owner_assigned

      website.complete_agency!
      expect(website).to be_agency_created

      website.complete_links!
      expect(website).to be_links_created

      website.complete_field_keys!
      expect(website).to be_field_keys_created

      website.seed_properties!
      expect(website).to be_properties_seeded

      website.mark_ready!
      expect(website).to be_ready

      website.go_live!
      expect(website).to be_live
    end

    it 'can skip properties seeding' do
      website.assign_owner!
      website.complete_agency!
      website.complete_links!
      website.complete_field_keys!
      website.skip_properties!
      expect(website).to be_properties_seeded
    end
  end

  describe 'email verification' do
    describe '#generate_email_verification_token!' do
      it 'generates a token and sets expiry' do
        website.generate_email_verification_token!
        expect(website.email_verification_token).to be_present
        expect(website.email_verification_token_expires_at).to be > Time.current
      end
    end

    describe '#email_verification_valid?' do
      it 'returns false when token is blank' do
        expect(website.email_verification_valid?).to be false
      end

      it 'returns false when token is expired' do
        website.update!(
          email_verification_token: 'test-token',
          email_verification_token_expires_at: 1.day.ago
        )
        expect(website.email_verification_valid?).to be false
      end

      it 'returns true when token is valid and not expired' do
        website.generate_email_verification_token!
        expect(website.email_verification_valid?).to be true
      end
    end

    describe '#locked?' do
      it 'returns true for locked_pending_email_verification state' do
        website.update!(provisioning_state: 'locked_pending_email_verification')
        expect(website.locked?).to be true
      end

      it 'returns true for locked_pending_registration state' do
        website.update!(provisioning_state: 'locked_pending_registration')
        expect(website.locked?).to be true
      end

      it 'returns false for other states' do
        website.update!(provisioning_state: 'live')
        expect(website.locked?).to be false
      end
    end
  end

  describe 'provisioning status' do
    describe '#provisioning_progress' do
      it 'returns correct progress for each state' do
        expectations = {
          'pending' => 0,
          'owner_assigned' => 15,
          'agency_created' => 30,
          'links_created' => 45,
          'field_keys_created' => 60,
          'properties_seeded' => 80,
          'ready' => 90,
          'locked_pending_email_verification' => 95,
          'locked_pending_registration' => 98,
          'live' => 100
        }

        expectations.each do |state, expected_progress|
          website.update!(provisioning_state: state)
          expect(website.provisioning_progress).to eq(expected_progress),
            "Expected #{expected_progress}% for state '#{state}', got #{website.provisioning_progress}%"
        end
      end
    end

    describe '#provisioning_status_message' do
      it 'returns human-readable message for live state' do
        website.update!(provisioning_state: 'live')
        expect(website.provisioning_status_message).to eq('Your website is live!')
      end

      it 'returns error message for failed state' do
        website.update!(provisioning_state: 'failed', provisioning_error: 'Database error')
        expect(website.provisioning_status_message).to include('Database error')
      end
    end

    describe '#accessible?' do
      it 'returns true for live websites' do
        website.update!(provisioning_state: 'live')
        expect(website.accessible?).to be true
      end

      it 'returns true for ready websites' do
        website.update!(provisioning_state: 'ready')
        expect(website.accessible?).to be true
      end

      it 'returns false for pending websites' do
        expect(website.accessible?).to be false
      end
    end

    describe '#provisioning?' do
      it 'returns true for provisioning states' do
        %w[pending owner_assigned agency_created links_created field_keys_created properties_seeded].each do |state|
          website.update!(provisioning_state: state)
          expect(website.provisioning?).to be true
        end
      end

      it 'returns false for non-provisioning states' do
        %w[ready live failed suspended].each do |state|
          website.update!(provisioning_state: state)
          expect(website.provisioning?).to be false
        end
      end
    end
  end
end
