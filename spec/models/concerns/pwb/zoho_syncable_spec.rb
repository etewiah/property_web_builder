# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::ZohoSyncable do
  let(:website) { create(:pwb_website) }

  # Create a test class that includes the concern
  let(:user_class) do
    Class.new(Pwb::User) do
      # Prevent table name issues in test
      self.table_name = 'pwb_users'
    end
  end

  describe 'automatic sync on user creation' do
    before do
      allow(Pwb::Zoho::SyncNewSignupJob).to receive(:perform_later)
    end

    context 'when user is in lead state' do
      it 'queues a Zoho sync job after creation' do
        expect(Pwb::Zoho::SyncNewSignupJob).to receive(:perform_later)
          .with(kind_of(Integer), kind_of(Hash))

        create(:pwb_user, website: website, onboarding_state: 'lead')
      end
    end

    context 'when user is in active state' do
      it 'does not queue a Zoho sync job' do
        expect(Pwb::Zoho::SyncNewSignupJob).not_to receive(:perform_later)

        create(:pwb_user, website: website, onboarding_state: 'active')
      end
    end
  end

  describe '.with_zoho_request_info' do
    it 'makes request info available during the block' do
      request_info = { ip: '192.168.1.1', utm_source: 'google' }

      Pwb::User.with_zoho_request_info(request_info) do
        expect(Thread.current[:zoho_request_info]).to eq(request_info)
      end

      expect(Thread.current[:zoho_request_info]).to be_nil
    end

    it 'clears request info even if block raises' do
      expect do
        Pwb::User.with_zoho_request_info({ ip: '1.2.3.4' }) do
          raise StandardError, 'test error'
        end
      end.to raise_error(StandardError)

      expect(Thread.current[:zoho_request_info]).to be_nil
    end
  end

  describe 'login activity tracking' do
    let(:user) { create(:pwb_user, website: website, onboarding_state: 'active', sign_in_count: 2) }

    before do
      allow(Pwb::Zoho::SyncActivityJob).to receive(:perform_later)
    end

    context 'on 3rd login' do
      it 'queues an activity sync job' do
        expect(Pwb::Zoho::SyncActivityJob).to receive(:perform_later)
          .with(user.id, 'login', hash_including(sign_in_count: 3))

        user.update!(sign_in_count: 3)
      end
    end

    context 'on 5th login' do
      it 'queues an activity sync job' do
        user.update!(sign_in_count: 4)
        expect(Pwb::Zoho::SyncActivityJob).to receive(:perform_later)
          .with(user.id, 'login', hash_including(sign_in_count: 5))

        user.update!(sign_in_count: 5)
      end
    end

    context 'on 10th login' do
      it 'queues an activity sync job' do
        user.update!(sign_in_count: 9)
        expect(Pwb::Zoho::SyncActivityJob).to receive(:perform_later)
          .with(user.id, 'login', hash_including(sign_in_count: 10))

        user.update!(sign_in_count: 10)
      end
    end

    context 'on other login counts' do
      it 'does not queue an activity sync job' do
        expect(Pwb::Zoho::SyncActivityJob).not_to receive(:perform_later)

        user.update!(sign_in_count: 4)
        user.update!(sign_in_count: 6)
      end
    end
  end

  describe '#sync_to_zoho!' do
    let(:user) { create(:pwb_user, website: website, metadata: {}) }

    before do
      allow(Pwb::Zoho::SyncNewSignupJob).to receive(:perform_later)
    end

    context 'when not already synced' do
      it 'queues a sync job' do
        expect(Pwb::Zoho::SyncNewSignupJob).to receive(:perform_later)
          .with(user.id, {})

        user.sync_to_zoho!
      end
    end

    context 'when already synced' do
      before do
        user.update!(metadata: { 'zoho_lead_id' => 'existing_lead' })
      end

      it 'does not queue a sync job' do
        expect(Pwb::Zoho::SyncNewSignupJob).not_to receive(:perform_later)

        user.sync_to_zoho!
      end
    end
  end

  describe '#zoho_synced?' do
    let(:user) { create(:pwb_user, website: website, metadata: {}) }

    context 'when Zoho lead ID is present' do
      before do
        user.update!(metadata: { 'zoho_lead_id' => 'lead_123' })
      end

      it 'returns true' do
        expect(user.zoho_synced?).to be true
      end
    end

    context 'when Zoho lead ID is not present' do
      it 'returns false' do
        expect(user.zoho_synced?).to be false
      end
    end
  end

  describe '#zoho_lead_id' do
    let(:user) { create(:pwb_user, website: website, metadata: {}) }

    context 'when synced' do
      before do
        user.update!(metadata: { 'zoho_lead_id' => 'lead_456' })
      end

      it 'returns the lead ID' do
        expect(user.zoho_lead_id).to eq('lead_456')
      end
    end

    context 'when not synced' do
      it 'returns nil' do
        expect(user.zoho_lead_id).to be_nil
      end
    end
  end

  describe '#zoho_converted?' do
    let(:user) { create(:pwb_user, website: website, metadata: {}) }

    context 'when contact ID is present' do
      before do
        user.update!(metadata: { 'zoho_contact_id' => 'contact_789' })
      end

      it 'returns true' do
        expect(user.zoho_converted?).to be true
      end
    end

    context 'when contact ID is not present' do
      it 'returns false' do
        expect(user.zoho_converted?).to be false
      end
    end
  end
end
