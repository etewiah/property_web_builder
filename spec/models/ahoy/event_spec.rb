# frozen_string_literal: true

# == Schema Information
#
# Table name: ahoy_events
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  properties :jsonb
#  time       :datetime         not null
#  visit_id   :bigint
#  website_id :bigint           not null
#
# Indexes
#
#  index_ahoy_events_on_properties                    (properties) USING gin
#  index_ahoy_events_on_visit_id                      (visit_id)
#  index_ahoy_events_on_website_id                    (website_id)
#  index_ahoy_events_on_website_id_and_name_and_time  (website_id,name,time)
#  index_ahoy_events_on_website_id_and_time           (website_id,time)
#
# Foreign Keys
#
#  fk_rails_...  (visit_id => ahoy_visits.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

RSpec.describe Ahoy::Event, type: :model do
  let(:website) { create(:pwb_website) }
  let(:visit) { create(:ahoy_visit, website: website) }

  describe 'associations' do
    it { is_expected.to belong_to(:website).class_name('Pwb::Website') }
    it { is_expected.to belong_to(:visit).class_name('Ahoy::Visit').optional }
  end

  describe 'scopes' do
    let!(:page_view) { create(:ahoy_event, website: website, visit: visit, name: 'page_viewed') }
    let!(:property_view) { create(:ahoy_event, website: website, visit: visit, name: 'property_viewed', properties: { property_id: 123 }) }
    let!(:inquiry) { create(:ahoy_event, website: website, visit: visit, name: 'inquiry_submitted') }
    let!(:search) { create(:ahoy_event, website: website, visit: visit, name: 'property_searched') }
    let!(:other_website_event) { create(:ahoy_event, name: 'page_viewed') }

    describe '.for_website' do
      it 'returns only events for the specified website' do
        expect(described_class.for_website(website)).to contain_exactly(
          page_view, property_view, inquiry, search
        )
      end
    end

    describe '.by_name' do
      it 'filters events by name' do
        expect(described_class.for_website(website).by_name('property_viewed')).to contain_exactly(property_view)
      end
    end

    describe '.page_views' do
      it 'returns page view events' do
        expect(described_class.for_website(website).page_views).to contain_exactly(page_view)
      end
    end

    describe '.property_views' do
      it 'returns property view events' do
        expect(described_class.for_website(website).property_views).to contain_exactly(property_view)
      end
    end

    describe '.inquiries' do
      it 'returns inquiry events' do
        expect(described_class.for_website(website).inquiries).to contain_exactly(inquiry)
      end
    end

    describe '.searches' do
      it 'returns search events' do
        expect(described_class.for_website(website).searches).to contain_exactly(search)
      end
    end
  end

  describe '.count_by_name' do
    before do
      create_list(:ahoy_event, 3, website: website, name: 'page_viewed')
      create_list(:ahoy_event, 2, website: website, name: 'property_viewed')
      create(:ahoy_event, website: website, name: 'inquiry_submitted')
    end

    it 'returns counts grouped by event name' do
      counts = described_class.for_website(website).count_by_name
      expect(counts['page_viewed']).to eq(3)
      expect(counts['property_viewed']).to eq(2)
      expect(counts['inquiry_submitted']).to eq(1)
    end
  end

  describe '.with_property' do
    let!(:event_with_prop) { create(:ahoy_event, website: website, name: 'property_viewed', properties: { property_id: '123' }) }
    let!(:event_other_prop) { create(:ahoy_event, website: website, name: 'property_viewed', properties: { property_id: '456' }) }

    it 'filters events by property value' do
      expect(described_class.for_website(website).with_property('property_id', '123')).to contain_exactly(event_with_prop)
    end
  end
end
