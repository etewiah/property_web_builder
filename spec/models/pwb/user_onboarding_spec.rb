require 'rails_helper'

module Pwb
  RSpec.describe User, 'onboarding state machine', type: :model do
    let(:website) { FactoryBot.create(:pwb_website) }
    let(:user) { FactoryBot.create(:pwb_user, website: website, onboarding_state: 'lead') }

    describe 'onboarding states' do
      describe '#register!' do
        it 'transitions from lead to registered' do
          user.register!
          expect(user).to be_registered
          expect(user.onboarding_started_at).to be_present
        end
      end

      describe '#verify_email!' do
        before { user.register! }

        it 'transitions from registered to email_verified' do
          user.verify_email!
          expect(user).to be_email_verified
        end
      end

      describe '#start_onboarding!' do
        it 'transitions from lead to onboarding' do
          user.start_onboarding!
          expect(user).to be_onboarding
          expect(user.onboarding_step).to eq(1)
          expect(user.onboarding_started_at).to be_present
        end

        it 'transitions from email_verified to onboarding' do
          user.register!
          user.verify_email!
          user.start_onboarding!
          expect(user).to be_onboarding
        end
      end

      describe '#complete_onboarding!' do
        before do
          user.start_onboarding!
        end

        it 'transitions from onboarding to active' do
          user.complete_onboarding!
          expect(user).to be_active
          expect(user.onboarding_completed_at).to be_present
        end
      end

      describe '#activate!' do
        it 'can activate from lead' do
          user.activate!
          expect(user).to be_active
          expect(user.onboarding_completed_at).to be_present
        end

        it 'can activate from registered' do
          user.register!
          user.activate!
          expect(user).to be_active
        end

        it 'can activate from email_verified' do
          user.register!
          user.verify_email!
          user.activate!
          expect(user).to be_active
        end

        it 'can activate from onboarding' do
          user.start_onboarding!
          user.activate!
          expect(user).to be_active
        end
      end

      describe '#mark_churned!' do
        it 'can churn from lead' do
          user.mark_churned!
          expect(user).to be_churned
        end

        it 'can churn from onboarding' do
          user.start_onboarding!
          user.mark_churned!
          expect(user).to be_churned
        end
      end

      describe '#reactivate!' do
        before do
          user.mark_churned!
        end

        it 'transitions from churned to lead' do
          user.reactivate!
          expect(user).to be_lead
        end
      end
    end

    describe 'helper methods' do
      describe '#onboarding_step_title' do
        it 'returns correct titles for each step' do
          expect(FactoryBot.build(:pwb_user, onboarding_step: 1).onboarding_step_title).to eq('Verify Email')
          expect(FactoryBot.build(:pwb_user, onboarding_step: 2).onboarding_step_title).to eq('Choose Subdomain')
          expect(FactoryBot.build(:pwb_user, onboarding_step: 3).onboarding_step_title).to eq('Select Site Type')
          expect(FactoryBot.build(:pwb_user, onboarding_step: 4).onboarding_step_title).to eq('Setup Complete')
        end

        it 'returns default for invalid step' do
          expect(FactoryBot.build(:pwb_user, onboarding_step: 99).onboarding_step_title).to eq('Getting Started')
        end
      end

      describe '#advance_onboarding_step!' do
        it 'increments the step' do
          user.update!(onboarding_step: 1)
          user.start_onboarding!
          user.advance_onboarding_step!
          expect(user.onboarding_step).to eq(2)
        end

        it 'completes onboarding when reaching max step' do
          user.start_onboarding!
          user.update!(onboarding_step: 3)
          user.advance_onboarding_step!
          expect(user).to be_active
          expect(user.onboarding_step).to eq(4)
        end
      end

      describe '#onboarding_progress_percentage' do
        it 'returns 100 for active users' do
          active_user = FactoryBot.build(:pwb_user, onboarding_state: 'active')
          expect(active_user.onboarding_progress_percentage).to eq(100)
        end

        it 'returns 0 for users with no step in non-active state' do
          expect(FactoryBot.build(:pwb_user, onboarding_step: 0, onboarding_state: 'lead').onboarding_progress_percentage).to eq(0)
        end

        it 'returns correct percentage for each step' do
          expect(FactoryBot.build(:pwb_user, onboarding_step: 1, onboarding_state: 'onboarding').onboarding_progress_percentage).to eq(25)
          expect(FactoryBot.build(:pwb_user, onboarding_step: 2, onboarding_state: 'onboarding').onboarding_progress_percentage).to eq(50)
          expect(FactoryBot.build(:pwb_user, onboarding_step: 3, onboarding_state: 'onboarding').onboarding_progress_percentage).to eq(75)
          expect(FactoryBot.build(:pwb_user, onboarding_step: 4, onboarding_state: 'onboarding').onboarding_progress_percentage).to eq(100)
        end
      end

      describe '#needs_onboarding?' do
        it 'returns true for pre-active states' do
          %w[lead registered email_verified onboarding].each do |state|
            user = FactoryBot.build(:pwb_user, onboarding_state: state)
            expect(user.needs_onboarding?).to be true
          end
        end

        it 'returns false for active and churned' do
          expect(FactoryBot.build(:pwb_user, onboarding_state: 'active').needs_onboarding?).to be false
          expect(FactoryBot.build(:pwb_user, onboarding_state: 'churned').needs_onboarding?).to be false
        end
      end
    end
  end
end
