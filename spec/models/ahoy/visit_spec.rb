# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ahoy::Visit, type: :model do
  let(:website) { create(:website) }

  describe 'associations' do
    it { is_expected.to belong_to(:website).class_name('Pwb::Website') }
    it { is_expected.to belong_to(:user).class_name('Pwb::User').optional }
    it { is_expected.to have_many(:events).class_name('Ahoy::Event').dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:visit_today) { create(:ahoy_visit, website: website, started_at: Time.current) }
    let!(:visit_yesterday) { create(:ahoy_visit, website: website, started_at: 1.day.ago) }
    let!(:visit_last_week) { create(:ahoy_visit, website: website, started_at: 8.days.ago) }
    let!(:other_website_visit) { create(:ahoy_visit, started_at: Time.current) }

    describe '.for_website' do
      it 'returns only visits for the specified website' do
        expect(described_class.for_website(website)).to contain_exactly(
          visit_today, visit_yesterday, visit_last_week
        )
      end
    end

    describe '.today' do
      it 'returns only visits from today' do
        expect(described_class.for_website(website).today).to contain_exactly(visit_today)
      end
    end

    describe '.this_week' do
      it 'returns visits from the last week' do
        expect(described_class.for_website(website).this_week).to contain_exactly(
          visit_today, visit_yesterday
        )
      end
    end

    describe '.last_n_days' do
      it 'returns visits from the last n days' do
        expect(described_class.for_website(website).last_n_days(2)).to contain_exactly(
          visit_today, visit_yesterday
        )
      end
    end
  end

  describe '.unique_visitors' do
    let!(:visit1) { create(:ahoy_visit, website: website, visitor_token: 'abc123') }
    let!(:visit2) { create(:ahoy_visit, website: website, visitor_token: 'abc123') }
    let!(:visit3) { create(:ahoy_visit, website: website, visitor_token: 'def456') }

    it 'counts unique visitor tokens' do
      expect(described_class.for_website(website).unique_visitors).to eq(2)
    end
  end

  describe 'traffic source scopes' do
    let!(:google_visit) { create(:ahoy_visit, website: website, referring_domain: 'google.com') }
    let!(:facebook_visit) { create(:ahoy_visit, website: website, referring_domain: 'facebook.com') }
    let!(:direct_visit) { create(:ahoy_visit, website: website, referring_domain: nil) }

    describe '.from_search' do
      it 'returns visits from search engines' do
        expect(described_class.for_website(website).from_search).to contain_exactly(google_visit)
      end
    end

    describe '.from_social' do
      it 'returns visits from social media' do
        expect(described_class.for_website(website).from_social).to contain_exactly(facebook_visit)
      end
    end

    describe '.direct' do
      it 'returns direct visits' do
        expect(described_class.for_website(website).direct).to contain_exactly(direct_visit)
      end
    end
  end
end
