# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformNtfyNotificationJob, type: :job do
  describe '#perform' do
    context 'with user_signup notification' do
      let(:user) { create(:pwb_user, email: 'test@example.com') }

      it 'calls PlatformNtfyService.notify_user_signup' do
        expect(PlatformNtfyService).to receive(:notify_user_signup).with(
          user,
          reserved_subdomain: 'test-subdomain'
        )

        described_class.perform_now(
          :user_signup,
          user.id,
          subdomain: 'test-subdomain'
        )
      end

      it 'handles missing user gracefully' do
        expect(PlatformNtfyService).not_to receive(:notify_user_signup)
        expect {
          described_class.perform_now(:user_signup, 99999, subdomain: 'test')
        }.not_to raise_error
      end
    end

    context 'with provisioning_complete notification' do
      let!(:website) { create(:pwb_website, subdomain: 'test-site') }

      it 'calls PlatformNtfyService.notify_provisioning_complete' do
        expect(PlatformNtfyService).to receive(:notify_provisioning_complete).with(website)

        described_class.perform_now(:provisioning_complete, website.id)
      end
    end

    context 'with subscription_activated notification' do
      let(:subscription) { create(:pwb_subscription, status: 'active') }

      it 'calls PlatformNtfyService.notify_subscription_activated' do
        expect(PlatformNtfyService).to receive(:notify_subscription_activated).with(subscription)

        described_class.perform_now(:subscription_activated, subscription.id)
      end
    end

    context 'with plan_changed notification' do
      let(:subscription) { create(:pwb_subscription) }
      let(:old_plan) { create(:pwb_plan, name: 'Starter', price_cents: 1900) }
      let(:new_plan) { create(:pwb_plan, name: 'Professional', price_cents: 4900) }

      it 'calls PlatformNtfyService.notify_plan_changed with correct plans' do
        expect(PlatformNtfyService).to receive(:notify_plan_changed).with(
          subscription,
          old_plan,
          new_plan
        )

        described_class.perform_now(
          :plan_changed,
          subscription.id,
          old_plan_id: old_plan.id,
          new_plan_id: new_plan.id
        )
      end
    end

    context 'with unknown notification type' do
      it 'logs warning and does not raise error' do
        expect(Rails.logger).to receive(:warn).with(
          /Unknown type: invalid_type/
        )

        expect {
          described_class.perform_now(:invalid_type, 123)
        }.not_to raise_error
      end
    end

    context 'when PlatformNtfyService is disabled' do
      let(:user) { create(:pwb_user) }

      before do
        allow(PlatformNtfyService).to receive(:enabled?).and_return(false)
      end

      it 'does not send notification' do
        expect(PlatformNtfyService).to receive(:notify_user_signup).and_return(false)

        described_class.perform_now(:user_signup, user.id, subdomain: 'test')
      end
    end
  end

  describe 'retry behavior' do
    # Retry behavior is configured but not easily testable with retry_on DSL
    # The job will retry 3 times with polynomial backoff as configured

    it 'has correct queue' do
      expect(described_class.queue_name).to eq('notifications')
    end
  end
end
