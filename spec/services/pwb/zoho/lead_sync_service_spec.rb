# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Zoho::LeadSyncService do
  let(:service) { described_class.new }
  let(:mock_client) { instance_double(Pwb::Zoho::Client) }
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user, website: website, metadata: {}) }

  before do
    allow(Pwb::Zoho::Client).to receive(:instance).and_return(mock_client)
    allow(mock_client).to receive(:configured?).and_return(true)
  end

  describe '#available?' do
    context 'when client is configured' do
      it 'returns true' do
        expect(service.available?).to be true
      end
    end

    context 'when client is not configured' do
      before do
        allow(mock_client).to receive(:configured?).and_return(false)
      end

      it 'returns false' do
        expect(service.available?).to be false
      end
    end
  end

  describe '#create_lead_from_signup' do
    let(:request_info) { { ip: '192.168.1.1', utm_source: 'google', utm_medium: 'cpc' } }

    context 'when successful' do
      before do
        allow(mock_client).to receive(:post).and_return({
                                                          'data' => [{ 'details' => { 'id' => 'zoho_lead_123' } }]
                                                        })
      end

      it 'creates a lead in Zoho CRM' do
        expect(mock_client).to receive(:post).with('/Leads', hash_including(:data))
        service.create_lead_from_signup(user, request_info: request_info)
      end

      it 'stores the Zoho lead ID in user metadata' do
        service.create_lead_from_signup(user, request_info: request_info)
        user.reload
        expect(user.metadata['zoho_lead_id']).to eq('zoho_lead_123')
      end

      it 'stores the sync timestamp' do
        service.create_lead_from_signup(user, request_info: request_info)
        user.reload
        expect(user.metadata['zoho_synced_at']).to be_present
      end

      it 'returns the Zoho lead ID' do
        result = service.create_lead_from_signup(user, request_info: request_info)
        expect(result).to eq('zoho_lead_123')
      end
    end

    context 'when Zoho returns an error' do
      before do
        allow(mock_client).to receive(:post).and_raise(Pwb::Zoho::ApiError.new('API Error'))
      end

      it 'raises the error (to be handled by job retry)' do
        expect { service.create_lead_from_signup(user, request_info: request_info) }
          .to raise_error(Pwb::Zoho::ApiError)
      end
    end

    context 'when Zoho is not configured' do
      before do
        allow(mock_client).to receive(:configured?).and_return(false)
      end

      it 'returns nil without making API calls' do
        expect(mock_client).not_to receive(:post)
        result = service.create_lead_from_signup(user)
        expect(result).to be_nil
      end
    end
  end

  describe '#update_lead_website_created' do
    let(:plan) { create(:pwb_plan, display_name: 'Professional', price_cents: 2990) }

    before do
      user.update!(metadata: { 'zoho_lead_id' => 'zoho_lead_123' })
      allow(mock_client).to receive(:put).and_return({ 'data' => [{ 'status' => 'success' }] })
    end

    it 'updates the lead with website and plan information' do
      expect(mock_client).to receive(:put).with('/Leads/zoho_lead_123', hash_including(:data))
      service.update_lead_website_created(user, website, plan)
    end

    it 'includes subdomain and plan details' do
      expect(mock_client).to receive(:put) do |_endpoint, payload|
        data = payload[:data].first
        expect(data[:PWB_Subdomain]).to eq(website.subdomain)
        expect(data[:Plan_Selected]).to eq('Professional')
        expect(data[:Lead_Status]).to eq('Configured')
        { 'data' => [{ 'status' => 'success' }] }
      end
      service.update_lead_website_created(user, website, plan)
    end

    context 'when user has no Zoho ID' do
      before do
        user.update!(metadata: {})
        allow(mock_client).to receive(:post).and_return({
                                                          'data' => [{ 'details' => { 'id' => 'new_lead_id' } }]
                                                        })
      end

      it 'creates a new lead first' do
        expect(mock_client).to receive(:post).with('/Leads', anything)
        service.update_lead_website_created(user, website, plan)
      end
    end
  end

  describe '#update_lead_website_live' do
    before do
      user.update!(metadata: { 'zoho_lead_id' => 'zoho_lead_123' })
      allow(mock_client).to receive(:put).and_return({ 'data' => [{ 'status' => 'success' }] })
    end

    it 'updates lead status to Active Trial' do
      expect(mock_client).to receive(:put) do |_endpoint, payload|
        data = payload[:data].first
        expect(data[:Lead_Status]).to eq('Active Trial')
        expect(data[:Email_Verified]).to be true
        { 'data' => [{ 'status' => 'success' }] }
      end
      service.update_lead_website_live(user, website)
    end
  end

  describe '#log_activity' do
    before do
      user.update!(metadata: { 'zoho_lead_id' => 'zoho_lead_123' })
      allow(mock_client).to receive(:post).and_return({ 'data' => [{ 'status' => 'success' }] })
      allow(mock_client).to receive(:get).and_return({ 'data' => [{ 'Lead_Score' => 20 }] })
      allow(mock_client).to receive(:put).and_return({ 'data' => [{ 'status' => 'success' }] })
    end

    it 'creates a note in Zoho' do
      expect(mock_client).to receive(:post).with('/Notes', hash_including(:data))
      service.log_activity(user, 'property_added', { title: 'Beach House' })
    end

    it 'updates lead engagement score' do
      expect(mock_client).to receive(:put).with('/Leads/zoho_lead_123', hash_including(:data))
      service.log_activity(user, 'first_property', { title: 'Beach House' })
    end

    context 'when user has no Zoho ID' do
      before do
        user.update!(metadata: {})
      end

      it 'does not make any API calls' do
        expect(mock_client).not_to receive(:post)
        service.log_activity(user, 'property_added', {})
      end
    end
  end

  describe '#update_trial_ending' do
    before do
      user.update!(metadata: { 'zoho_lead_id' => 'zoho_lead_123' })
      allow(mock_client).to receive(:put).and_return({ 'data' => [{ 'status' => 'success' }] })
    end

    it 'updates lead with trial ending status' do
      expect(mock_client).to receive(:put) do |_endpoint, payload|
        data = payload[:data].first
        expect(data[:Lead_Status]).to eq('Trial Ending')
        expect(data[:Trial_Days_Left]).to eq('3') # NOTE: service converts to string
        { 'data' => [{ 'status' => 'success' }] }
      end
      service.update_trial_ending(user, 3)
    end
  end

  describe '#convert_lead_to_customer' do
    let(:plan) { create(:pwb_plan, display_name: 'Professional', price_cents: 2990) }
    let(:subscription) { create(:pwb_subscription, website: website, plan: plan) }

    before do
      user.update!(metadata: { 'zoho_lead_id' => 'zoho_lead_123' })
      allow(mock_client).to receive(:post).and_return({
                                                        'data' => [{
                                                          'Contacts' => 'contact_123',
                                                          'Accounts' => 'account_123',
                                                          'Deals' => 'deal_123'
                                                        }]
                                                      })
    end

    it 'converts the lead to customer in Zoho' do
      expect(mock_client).to receive(:post).with('/Leads/zoho_lead_123/actions/convert', hash_including(:data))
      service.convert_lead_to_customer(user, subscription)
    end

    it 'stores the converted IDs in user metadata' do
      service.convert_lead_to_customer(user, subscription)
      user.reload
      expect(user.metadata['zoho_contact_id']).to eq('contact_123')
      expect(user.metadata['zoho_account_id']).to eq('account_123')
      expect(user.metadata['zoho_deal_id']).to eq('deal_123')
    end
  end

  describe '#mark_lead_lost' do
    before do
      user.update!(metadata: { 'zoho_lead_id' => 'zoho_lead_123' })
      allow(mock_client).to receive(:put).and_return({ 'data' => [{ 'status' => 'success' }] })
    end

    it 'updates the lead status to Lost' do
      expect(mock_client).to receive(:put) do |_endpoint, payload|
        data = payload[:data].first
        expect(data[:Lead_Status]).to eq('Lost')
        expect(data[:Lost_Reason]).to eq('Trial Expired')
        { 'data' => [{ 'status' => 'success' }] }
      end
      service.mark_lead_lost(user, 'Trial Expired')
    end
  end

  describe '#find_lead_by_email' do
    context 'when lead exists' do
      before do
        allow(mock_client).to receive(:get).and_return({
                                                         'data' => [{ 'id' => 'found_lead_123', 'Email' => 'test@example.com' }]
                                                       })
      end

      it 'returns the lead ID' do
        result = service.find_lead_by_email('test@example.com')
        expect(result).to eq('found_lead_123')
      end
    end

    context 'when lead does not exist' do
      before do
        allow(mock_client).to receive(:get).and_return({ 'data' => [] })
      end

      it 'returns nil' do
        result = service.find_lead_by_email('nonexistent@example.com')
        expect(result).to be_nil
      end
    end

    context 'when NotFoundError is raised' do
      before do
        allow(mock_client).to receive(:get).and_raise(Pwb::Zoho::NotFoundError)
      end

      it 'returns nil' do
        result = service.find_lead_by_email('test@example.com')
        expect(result).to be_nil
      end
    end
  end
end
