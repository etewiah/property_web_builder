require 'rails_helper'

module Pwb
  RSpec.describe Website, 'provisioning state machine', type: :model do
    let(:base_website) { FactoryBot.create(:pwb_website) }

    describe 'provisioning states' do
      it 'has valid SITE_TYPES constant' do
        expect(Website::SITE_TYPES).to eq(%w[residential commercial vacation_rental])
      end

      it 'validates site_type inclusion' do
        website = FactoryBot.build(:pwb_website, site_type: 'invalid_type')
        expect(website).not_to be_valid
        expect(website.errors[:site_type]).to be_present
      end

      it 'allows valid site_type' do
        website = FactoryBot.build(:pwb_website, site_type: 'residential')
        expect(website).to be_valid
      end

      it 'allows blank site_type' do
        website = FactoryBot.build(:pwb_website, site_type: nil)
        expect(website).to be_valid
      end
    end

    describe 'provisioning guards' do
      # Use :without_agency trait to avoid factory creating agency automatically
      let(:website) { FactoryBot.create(:pwb_website, :without_agency, provisioning_state: 'pending') }
      let(:user) { FactoryBot.create(:pwb_user, website: base_website) }

      describe '#has_owner?' do
        it 'returns false when no owner membership exists' do
          expect(website.has_owner?).to be false
        end

        it 'returns true when active owner membership exists' do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          expect(website.has_owner?).to be true
        end

        it 'returns false when owner membership is inactive' do
          UserMembership.create!(user: user, website: website, role: 'owner', active: false)
          expect(website.has_owner?).to be false
        end

        it 'returns false when membership is admin not owner' do
          UserMembership.create!(user: user, website: website, role: 'admin', active: true)
          expect(website.has_owner?).to be false
        end
      end

      describe '#has_agency?' do
        it 'returns false when no agency exists' do
          expect(website.has_agency?).to be false
        end

        it 'returns true when agency exists' do
          Agency.create!(website: website, display_name: 'Test Agency')
          expect(website.has_agency?).to be true
        end
      end

      describe '#has_links?' do
        it 'returns false when fewer than 3 links exist' do
          2.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          expect(website.has_links?).to be false
        end

        it 'returns true when 3 or more links exist' do
          3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          expect(website.has_links?).to be true
        end
      end

      describe '#has_field_keys?' do
        it 'returns false when fewer than 5 field keys exist' do
          4.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }
          expect(website.has_field_keys?).to be false
        end

        it 'returns true when 5 or more field keys exist' do
          5.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }
          expect(website.has_field_keys?).to be true
        end
      end

      describe '#provisioning_complete?' do
        it 'returns false when any required item is missing' do
          expect(website.provisioning_complete?).to be false
        end

        it 'returns true when all required items exist' do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          Agency.create!(website: website, display_name: 'Test Agency')
          3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          5.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }

          expect(website.provisioning_complete?).to be true
        end
      end

      describe '#can_go_live?' do
        it 'returns false when provisioning is incomplete' do
          expect(website.can_go_live?).to be false
        end

        it 'returns false when subdomain is blank' do
          website.subdomain = nil
          expect(website.can_go_live?).to be false
        end

        it 'returns true when complete and has subdomain' do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          Agency.create!(website: website, display_name: 'Test Agency')
          3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          5.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }

          expect(website.can_go_live?).to be true
        end
      end
    end

    describe 'state machine transitions with guards' do
      # Use :without_agency trait to avoid factory creating agency automatically
      let(:website) { FactoryBot.create(:pwb_website, :without_agency, provisioning_state: 'pending') }
      let(:user) { FactoryBot.create(:pwb_user, website: base_website) }

      describe '#assign_owner!' do
        it 'fails without owner membership' do
          expect { website.assign_owner! }.to raise_error(AASM::InvalidTransition)
        end

        it 'transitions when owner exists' do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          website.assign_owner!
          expect(website).to be_owner_assigned
          expect(website.provisioning_started_at).to be_present
        end
      end

      describe '#complete_agency!' do
        before do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          website.assign_owner!
        end

        it 'fails without agency' do
          expect { website.complete_agency! }.to raise_error(AASM::InvalidTransition)
        end

        it 'transitions when agency exists' do
          Agency.create!(website: website, display_name: 'Test Agency')
          website.complete_agency!
          expect(website).to be_agency_created
        end
      end

      describe '#complete_links!' do
        before do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          website.assign_owner!
          Agency.create!(website: website, display_name: 'Test Agency')
          website.complete_agency!
        end

        it 'fails with insufficient links' do
          2.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          expect { website.complete_links! }.to raise_error(AASM::InvalidTransition)
        end

        it 'transitions with sufficient links' do
          3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          website.complete_links!
          expect(website).to be_links_created
        end
      end

      describe '#complete_field_keys!' do
        before do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          website.assign_owner!
          Agency.create!(website: website, display_name: 'Test Agency')
          website.complete_agency!
          3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          website.complete_links!
        end

        it 'fails with insufficient field keys' do
          4.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }
          expect { website.complete_field_keys! }.to raise_error(AASM::InvalidTransition)
        end

        it 'transitions with sufficient field keys' do
          5.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }
          website.complete_field_keys!
          expect(website).to be_field_keys_created
        end
      end

      describe '#seed_properties! and #skip_properties!' do
        before do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          website.assign_owner!
          Agency.create!(website: website, display_name: 'Test Agency')
          website.complete_agency!
          3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          website.complete_links!
          5.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }
          website.complete_field_keys!
        end

        it 'transitions with seed_properties!' do
          website.seed_properties!
          expect(website).to be_properties_seeded
        end

        it 'transitions with skip_properties!' do
          website.skip_properties!
          expect(website).to be_properties_seeded
        end
      end

      describe '#mark_ready!' do
        before do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          website.assign_owner!
          Agency.create!(website: website, display_name: 'Test Agency')
          website.complete_agency!
          3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          website.complete_links!
          5.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }
          website.complete_field_keys!
          website.seed_properties!
        end

        it 'transitions when provisioning is complete' do
          website.mark_ready!
          expect(website).to be_ready
          expect(website.provisioning_completed_at).to be_present
        end
      end

      describe '#go_live!' do
        before do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          website.assign_owner!
          Agency.create!(website: website, display_name: 'Test Agency')
          website.complete_agency!
          3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          website.complete_links!
          5.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }
          website.complete_field_keys!
          website.seed_properties!
          website.mark_ready!
        end

        it 'transitions when can_go_live? is true' do
          website.go_live!
          expect(website).to be_live
        end
      end

      describe '#fail_provisioning!' do
        it 'can fail from pending' do
          website.fail_provisioning!('Test error')
          expect(website).to be_failed
          expect(website.provisioning_error).to eq('Test error')
          expect(website.provisioning_failed_at).to be_present
        end

        it 'can fail from owner_assigned' do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          website.assign_owner!
          website.fail_provisioning!('Agency error')
          expect(website).to be_failed
        end

        it 'can fail from agency_created' do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          website.assign_owner!
          Agency.create!(website: website, display_name: 'Test Agency')
          website.complete_agency!
          website.fail_provisioning!('Links error')
          expect(website).to be_failed
        end
      end

      describe '#retry_provisioning!' do
        before do
          website.fail_provisioning!('Test error')
        end

        it 'transitions from failed to pending' do
          website.retry_provisioning!
          expect(website).to be_pending
          expect(website.provisioning_error).to be_nil
          expect(website.provisioning_failed_at).to be_nil
        end
      end

      describe '#suspend!' do
        it 'can suspend from live' do
          website.update!(provisioning_state: 'live')
          website.suspend!
          expect(website).to be_suspended
        end

        it 'can suspend from ready' do
          website.update!(provisioning_state: 'ready')
          website.suspend!
          expect(website).to be_suspended
        end
      end

      describe '#reactivate!' do
        before { website.update!(provisioning_state: 'suspended') }

        it 'transitions from suspended to live' do
          website.reactivate!
          expect(website).to be_live
        end
      end

      describe '#terminate!' do
        it 'can terminate from suspended' do
          website.update!(provisioning_state: 'suspended')
          website.terminate!
          expect(website).to be_terminated
        end

        it 'can terminate from failed' do
          website.update!(provisioning_state: 'failed')
          website.terminate!
          expect(website).to be_terminated
        end
      end
    end

    describe 'helper methods' do
      let(:website) { FactoryBot.build(:pwb_website) }

      describe '#provisioning_progress' do
        it 'returns correct percentage for each state' do
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'pending').provisioning_progress).to eq(0)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'owner_assigned').provisioning_progress).to eq(15)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'agency_created').provisioning_progress).to eq(30)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'links_created').provisioning_progress).to eq(45)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'field_keys_created').provisioning_progress).to eq(60)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'properties_seeded').provisioning_progress).to eq(80)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'ready').provisioning_progress).to eq(90)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'locked_pending_email_verification').provisioning_progress).to eq(95)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'locked_pending_registration').provisioning_progress).to eq(98)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'live').provisioning_progress).to eq(100)
        end
      end

      describe '#provisioning_status_message' do
        it 'returns human-readable messages for each state' do
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'pending').provisioning_status_message).to eq('Waiting to start...')
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'owner_assigned').provisioning_status_message).to eq('Owner account created')
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'agency_created').provisioning_status_message).to eq('Agency information saved')
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'links_created').provisioning_status_message).to eq('Navigation links created')
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'field_keys_created').provisioning_status_message).to eq('Property fields configured')
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'properties_seeded').provisioning_status_message).to eq('Sample properties added')
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'live').provisioning_status_message).to eq('Your website is live!')
        end

        it 'includes error message when failed' do
          website = FactoryBot.build(:pwb_website, provisioning_state: 'failed', provisioning_error: 'Database error')
          expect(website.provisioning_status_message).to include('Database error')
        end
      end

      describe '#accessible?' do
        it 'returns true for live websites' do
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'live')).to be_accessible
        end

        it 'returns true for ready websites' do
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'ready')).to be_accessible
        end

        it 'returns false for pending websites' do
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'pending')).not_to be_accessible
        end
      end

      describe '#provisioning?' do
        it 'returns true for in-progress states' do
          %w[pending owner_assigned agency_created links_created field_keys_created properties_seeded].each do |state|
            expect(FactoryBot.build(:pwb_website, provisioning_state: state)).to be_provisioning
          end
        end

        it 'returns false for completed states' do
          %w[ready live failed suspended terminated].each do |state|
            expect(FactoryBot.build(:pwb_website, provisioning_state: state)).not_to be_provisioning
          end
        end
      end

      describe '#provisioning_checklist' do
        let(:website) { FactoryBot.create(:pwb_website, :without_agency, provisioning_state: 'pending') }

        it 'returns a hash with all checklist items' do
          checklist = website.provisioning_checklist

          expect(checklist).to have_key(:owner)
          expect(checklist).to have_key(:agency)
          expect(checklist).to have_key(:links)
          expect(checklist).to have_key(:field_keys)
          expect(checklist).to have_key(:properties)
          expect(checklist).to have_key(:subdomain)
        end

        it 'includes counts for links and field_keys' do
          checklist = website.provisioning_checklist

          expect(checklist[:links]).to have_key(:count)
          expect(checklist[:links]).to have_key(:minimum)
          expect(checklist[:field_keys]).to have_key(:count)
          expect(checklist[:field_keys]).to have_key(:minimum)
        end
      end

      describe '#provisioning_missing_items' do
        let(:website) { FactoryBot.create(:pwb_website, :without_agency, provisioning_state: 'pending') }
        let(:user) { FactoryBot.create(:pwb_user, website: base_website) }

        it 'returns array of missing items' do
          missing = website.provisioning_missing_items

          expect(missing).to include('owner membership')
          expect(missing).to include('agency')
          expect(missing).to include(match(/links/))
          expect(missing).to include(match(/field_keys/))
        end

        it 'returns empty array when all items complete' do
          UserMembership.create!(user: user, website: website, role: 'owner', active: true)
          Agency.create!(website: website, display_name: 'Test Agency')
          3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
          5.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }

          expect(website.provisioning_missing_items).to be_empty
        end
      end
    end

    # ===================
    # Email Verification
    # ===================

    describe 'email verification' do
      let(:website) { FactoryBot.create(:pwb_website, :without_agency, provisioning_state: 'locked_pending_email_verification', owner_email: 'test@example.com') }

      describe '#locked?' do
        it 'returns true for locked_pending_email_verification' do
          expect(website.locked?).to be true
        end

        it 'returns true for locked_pending_registration' do
          website.update!(provisioning_state: 'locked_pending_registration')
          expect(website.locked?).to be true
        end

        it 'returns false for live websites' do
          website.update!(provisioning_state: 'live')
          expect(website.locked?).to be false
        end

        it 'returns false for pending websites' do
          website.update!(provisioning_state: 'pending')
          expect(website.locked?).to be false
        end
      end

      describe '#locked_mode' do
        it 'returns :pending_email_verification for locked_pending_email_verification' do
          expect(website.locked_mode).to eq(:pending_email_verification)
        end

        it 'returns :pending_registration for locked_pending_registration' do
          website.update!(provisioning_state: 'locked_pending_registration')
          expect(website.locked_mode).to eq(:pending_registration)
        end

        it 'returns nil for non-locked states' do
          website.update!(provisioning_state: 'live')
          expect(website.locked_mode).to be_nil
        end
      end

      describe '#generate_email_verification_token!' do
        it 'generates a token' do
          website.generate_email_verification_token!
          expect(website.email_verification_token).to be_present
        end

        it 'sets expiry time' do
          website.generate_email_verification_token!
          expect(website.email_verification_token_expires_at).to be > Time.current
        end

        it 'sets expiry to configured duration' do
          website.generate_email_verification_token!
          expected_expiry = Pwb::Website::EMAIL_VERIFICATION_EXPIRY.from_now
          # Allow some wiggle room for test execution time
          expect(website.email_verification_token_expires_at).to be_within(5.seconds).of(expected_expiry)
        end
      end

      describe '#email_verification_valid?' do
        it 'returns false without token' do
          expect(website.email_verification_valid?).to be false
        end

        it 'returns true with valid token' do
          website.generate_email_verification_token!
          expect(website.email_verification_valid?).to be true
        end

        it 'returns false with expired token' do
          website.update!(
            email_verification_token: 'test-token',
            email_verification_token_expires_at: 1.day.ago
          )
          expect(website.email_verification_valid?).to be false
        end
      end

      describe '#email_verified?' do
        it 'returns false when email_verified_at is nil' do
          expect(website.email_verified?).to be false
        end

        it 'returns true when email_verified_at is set' do
          website.update!(email_verified_at: Time.current)
          expect(website.email_verified?).to be true
        end
      end

      describe '.find_by_verification_token' do
        it 'finds website by token' do
          website.generate_email_verification_token!
          found = Pwb::Website.find_by_verification_token(website.email_verification_token)
          expect(found).to eq(website)
        end

        it 'returns nil for blank token' do
          expect(Pwb::Website.find_by_verification_token('')).to be_nil
          expect(Pwb::Website.find_by_verification_token(nil)).to be_nil
        end

        it 'returns nil for non-existent token' do
          expect(Pwb::Website.find_by_verification_token('non-existent')).to be_nil
        end
      end
    end

    describe 'locked state transitions' do
      let(:base_website) { FactoryBot.create(:pwb_website) }
      let(:user) { FactoryBot.create(:pwb_user, website: base_website) }
      let(:website) { FactoryBot.create(:pwb_website, :without_agency, provisioning_state: 'ready', owner_email: 'test@example.com') }

      before do
        # Set up all required data for can_go_live?
        UserMembership.create!(user: user, website: website, role: 'owner', active: true)
        Agency.create!(website: website, display_name: 'Test Agency')
        3.times { |i| Link.create!(website: website, slug: "link-#{i}") }
        5.times { |i| FieldKey.create!(pwb_website_id: website.id, global_key: "key-#{i}", tag: 'test') }
      end

      describe '#enter_locked_state!' do
        it 'transitions from ready to locked_pending_email_verification' do
          website.enter_locked_state!
          expect(website).to be_locked_pending_email_verification
        end

        it 'generates verification token' do
          website.enter_locked_state!
          expect(website.email_verification_token).to be_present
        end
      end

      describe '#verify_owner_email!' do
        before do
          website.update!(provisioning_state: 'locked_pending_email_verification')
          website.generate_email_verification_token!
        end

        it 'transitions to locked_pending_registration' do
          website.verify_owner_email!
          expect(website).to be_locked_pending_registration
        end

        it 'sets email_verified_at' do
          website.verify_owner_email!
          expect(website.email_verified_at).to be_present
        end

        it 'fails with expired token' do
          website.update!(email_verification_token_expires_at: 1.day.ago)
          expect { website.verify_owner_email! }.to raise_error(AASM::InvalidTransition)
        end
      end

      describe '#complete_owner_registration!' do
        before do
          website.update!(provisioning_state: 'locked_pending_registration')
        end

        it 'transitions to live' do
          website.complete_owner_registration!
          expect(website).to be_live
        end
      end

      describe '#go_live!' do
        it 'can bypass locked states (for admin use)' do
          website.update!(provisioning_state: 'locked_pending_email_verification')
          website.go_live!
          expect(website).to be_live
        end
      end
    end
  end
end
