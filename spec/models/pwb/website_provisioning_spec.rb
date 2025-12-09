require 'rails_helper'

module Pwb
  RSpec.describe Website, 'provisioning state machine', type: :model do
    let(:website) { FactoryBot.create(:pwb_website, provisioning_state: 'pending') }

    describe 'provisioning states' do
      it 'has valid SITE_TYPES constant' do
        expect(Website::SITE_TYPES).to eq(%w[residential commercial vacation_rental])
      end

      it 'validates site_type inclusion' do
        website.site_type = 'invalid_type'
        expect(website).not_to be_valid
        expect(website.errors[:site_type]).to be_present
      end

      it 'allows valid site_type' do
        website.site_type = 'residential'
        expect(website).to be_valid
      end

      it 'allows blank site_type' do
        website.site_type = nil
        expect(website).to be_valid
      end
    end

    describe 'state machine transitions' do
      let(:pending_website) { FactoryBot.create(:pwb_website, provisioning_state: 'pending') }

      describe '#allocate_subdomain!' do
        it 'transitions from pending to subdomain_allocated' do
          pending_website.allocate_subdomain!
          expect(pending_website).to be_subdomain_allocated
          expect(pending_website.provisioning_started_at).to be_present
        end

        it 'sets provisioning_started_at only once' do
          original_time = 1.hour.ago
          pending_website.update!(provisioning_started_at: original_time)
          pending_website.allocate_subdomain!
          expect(pending_website.provisioning_started_at).to eq(original_time)
        end
      end

      describe '#start_configuring!' do
        before { pending_website.allocate_subdomain! }

        it 'transitions from subdomain_allocated to configuring' do
          pending_website.start_configuring!
          expect(pending_website).to be_configuring
        end
      end

      describe '#start_seeding!' do
        before do
          pending_website.allocate_subdomain!
          pending_website.start_configuring!
        end

        it 'transitions from configuring to seeding' do
          pending_website.start_seeding!
          expect(pending_website).to be_seeding
        end
      end

      describe '#mark_ready!' do
        before do
          pending_website.allocate_subdomain!
          pending_website.start_configuring!
          pending_website.start_seeding!
        end

        it 'transitions from seeding to ready' do
          pending_website.mark_ready!
          expect(pending_website).to be_ready
          expect(pending_website.provisioning_completed_at).to be_present
        end
      end

      describe '#go_live!' do
        before do
          pending_website.allocate_subdomain!
          pending_website.start_configuring!
          pending_website.start_seeding!
          pending_website.mark_ready!
        end

        it 'transitions from ready to live' do
          pending_website.go_live!
          expect(pending_website).to be_live
        end
      end

      describe '#fail_provisioning!' do
        it 'can fail from pending' do
          pending_website.fail_provisioning!('Test error')
          expect(pending_website).to be_failed
          expect(pending_website.provisioning_error).to eq('Test error')
        end

        it 'can fail from configuring' do
          pending_website.allocate_subdomain!
          pending_website.start_configuring!
          pending_website.fail_provisioning!('Config error')
          expect(pending_website).to be_failed
        end

        it 'can fail from seeding' do
          pending_website.allocate_subdomain!
          pending_website.start_configuring!
          pending_website.start_seeding!
          pending_website.fail_provisioning!('Seeding error')
          expect(pending_website).to be_failed
        end
      end

      describe '#retry_provisioning!' do
        before do
          pending_website.fail_provisioning!('Test error')
        end

        it 'transitions from failed to pending' do
          pending_website.retry_provisioning!
          expect(pending_website).to be_pending
          expect(pending_website.provisioning_error).to be_nil
        end
      end

      describe '#suspend!' do
        it 'can suspend from live' do
          pending_website.update!(provisioning_state: 'live')
          pending_website.suspend!
          expect(pending_website).to be_suspended
        end

        it 'can suspend from ready' do
          pending_website.update!(provisioning_state: 'ready')
          pending_website.suspend!
          expect(pending_website).to be_suspended
        end
      end

      describe '#reactivate!' do
        before { pending_website.update!(provisioning_state: 'suspended') }

        it 'transitions from suspended to live' do
          pending_website.reactivate!
          expect(pending_website).to be_live
        end
      end

      describe '#terminate!' do
        it 'can terminate from suspended' do
          pending_website.update!(provisioning_state: 'suspended')
          pending_website.terminate!
          expect(pending_website).to be_terminated
        end

        it 'can terminate from failed' do
          pending_website.update!(provisioning_state: 'failed')
          pending_website.terminate!
          expect(pending_website).to be_terminated
        end
      end
    end

    describe 'helper methods' do
      describe '#provisioning_progress' do
        it 'returns correct percentage for each state' do
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'pending').provisioning_progress).to eq(0)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'subdomain_allocated').provisioning_progress).to eq(20)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'configuring').provisioning_progress).to eq(40)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'seeding').provisioning_progress).to eq(70)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'ready').provisioning_progress).to eq(95)
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'live').provisioning_progress).to eq(100)
        end
      end

      describe '#provisioning_status_message' do
        it 'returns human-readable messages' do
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'pending').provisioning_status_message).to eq('Waiting to start...')
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'configuring').provisioning_status_message).to eq('Setting up your website...')
          expect(FactoryBot.build(:pwb_website, provisioning_state: 'seeding').provisioning_status_message).to eq('Adding sample properties...')
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
          %w[pending subdomain_allocated configuring seeding].each do |state|
            expect(FactoryBot.build(:pwb_website, provisioning_state: state)).to be_provisioning
          end
        end

        it 'returns false for completed states' do
          %w[ready live failed suspended terminated].each do |state|
            expect(FactoryBot.build(:pwb_website, provisioning_state: state)).not_to be_provisioning
          end
        end
      end
    end
  end
end
