# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::AnalyticsService do
  let(:website) { create(:pwb_website) }
  let(:service) { described_class.new(website, period: 30.days) }

  describe '#overview' do
    before do
      # Create visits with different visitor tokens
      create_list(:ahoy_visit, 5, website: website, visitor_token: 'unique1')
      create_list(:ahoy_visit, 3, website: website, visitor_token: 'unique2')

      # Create events
      visit = create(:ahoy_visit, website: website)
      create_list(:ahoy_event, 10, :page_view, website: website, visit: visit)
      create_list(:ahoy_event, 4, :property_view, website: website, visit: visit)
      create_list(:ahoy_event, 2, :inquiry, website: website, visit: visit)
      create_list(:ahoy_event, 3, :search, website: website, visit: visit)
    end

    it 'returns overview metrics' do
      overview = service.overview

      expect(overview[:total_visits]).to eq(9) # 5 + 3 + 1
      expect(overview[:unique_visitors]).to eq(3) # unique1, unique2, plus the one with events
      expect(overview[:total_pageviews]).to eq(10)
      expect(overview[:property_views]).to eq(4)
      expect(overview[:inquiries]).to eq(2)
      expect(overview[:searches]).to eq(3)
      expect(overview[:conversion_rate]).to be_a(Float)
    end
  end

  describe '#visits_by_day' do
    before do
      create(:ahoy_visit, website: website, started_at: 2.days.ago)
      create(:ahoy_visit, website: website, started_at: 2.days.ago)
      create(:ahoy_visit, website: website, started_at: 1.day.ago)
      create(:ahoy_visit, website: website, started_at: Time.current)
    end

    it 'groups visits by day' do
      result = service.visits_by_day

      expect(result).to be_a(Hash)
      expect(result.values.sum).to eq(4)
    end
  end

  describe '#top_properties' do
    before do
      visit = create(:ahoy_visit, website: website)

      # Property 1 viewed 5 times
      5.times { create(:ahoy_event, :property_view, website: website, visit: visit, properties: { property_id: '1' }) }
      # Property 2 viewed 3 times
      3.times { create(:ahoy_event, :property_view, website: website, visit: visit, properties: { property_id: '2' }) }
      # Property 3 viewed 1 time
      create(:ahoy_event, :property_view, website: website, visit: visit, properties: { property_id: '3' })
    end

    it 'returns properties ordered by view count' do
      result = service.top_properties(limit: 10)

      expect(result.keys.first).to include(id: 1)
      expect(result.values.first).to eq(5)
    end
  end

  describe '#traffic_sources' do
    before do
      create_list(:ahoy_visit, 5, website: website, referring_domain: 'google.com')
      create_list(:ahoy_visit, 3, website: website, referring_domain: 'facebook.com')
      create_list(:ahoy_visit, 2, website: website, referring_domain: nil)
    end

    it 'returns traffic sources with counts' do
      result = service.traffic_sources

      expect(result['google.com']).to eq(5)
      expect(result['facebook.com']).to eq(3)
      expect(result[nil]).to eq(2)
    end
  end

  describe '#traffic_by_source_type' do
    before do
      create_list(:ahoy_visit, 3, :from_google, website: website)
      create_list(:ahoy_visit, 2, :from_facebook, website: website)
      create_list(:ahoy_visit, 4, :direct, website: website)
      create(:ahoy_visit, website: website, referring_domain: 'somesite.com')
    end

    it 'categorizes traffic by source type' do
      result = service.traffic_by_source_type

      expect(result[:search]).to eq(3)
      expect(result[:social]).to eq(2)
      expect(result[:direct]).to eq(4)
      expect(result[:referral]).to eq(1)
    end
  end

  describe '#device_breakdown' do
    before do
      create_list(:ahoy_visit, 5, website: website, device_type: 'Desktop')
      create_list(:ahoy_visit, 3, website: website, device_type: 'Mobile')
      create(:ahoy_visit, website: website, device_type: 'Tablet')
    end

    it 'returns device type counts' do
      result = service.device_breakdown

      expect(result['Desktop']).to eq(5)
      expect(result['Mobile']).to eq(3)
      expect(result['Tablet']).to eq(1)
    end
  end

  describe '#inquiry_funnel' do
    before do
      visit1 = create(:ahoy_visit, website: website)
      visit2 = create(:ahoy_visit, website: website)
      create(:ahoy_visit, website: website)

      # Visit 1: Full funnel
      create(:ahoy_event, :property_view, website: website, visit: visit1)
      create(:ahoy_event, :contact_form_opened, website: website, visit: visit1)
      create(:ahoy_event, :inquiry, website: website, visit: visit1)

      # Visit 2: Viewed property but didn't inquire
      create(:ahoy_event, :property_view, website: website, visit: visit2)

      # Visit 3: Just visited, no property views
    end

    it 'returns funnel metrics' do
      result = service.inquiry_funnel

      expect(result[:visits]).to eq(3)
      expect(result[:property_views]).to eq(2)
      expect(result[:contact_opens]).to eq(1)
      expect(result[:inquiries]).to eq(1)
    end
  end

  describe '#real_time_visitors' do
    before do
      create(:ahoy_visit, website: website, started_at: 10.minutes.ago)
      create(:ahoy_visit, website: website, started_at: 20.minutes.ago)
      create(:ahoy_visit, website: website, started_at: 1.hour.ago) # Outside 30 min window
    end

    it 'counts visitors in the last 30 minutes' do
      expect(service.real_time_visitors).to eq(2)
    end
  end

  describe 'period filtering' do
    let!(:old_visit) { create(:ahoy_visit, website: website, started_at: 60.days.ago) }
    let!(:recent_visit) { create(:ahoy_visit, website: website, started_at: 10.days.ago) }

    it 'only includes data within the specified period' do
      overview = service.overview

      expect(overview[:total_visits]).to eq(1)
    end

    context 'with custom period' do
      let(:service) { described_class.new(website, period: 90.days) }

      it 'includes data within the longer period' do
        overview = service.overview

        expect(overview[:total_visits]).to eq(2)
      end
    end
  end
end
