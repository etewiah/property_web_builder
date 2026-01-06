# frozen_string_literal: true

# == Schema Information
#
# Table name: ahoy_visits
# Database name: primary
#
#  id               :bigint           not null, primary key
#  browser          :string
#  city             :string
#  country          :string
#  device_type      :string
#  landing_page     :text
#  os               :string
#  referrer         :text
#  referring_domain :string
#  region           :string
#  started_at       :datetime
#  utm_campaign     :string
#  utm_content      :string
#  utm_medium       :string
#  utm_source       :string
#  utm_term         :string
#  visit_token      :string
#  visitor_token    :string
#  user_id          :bigint
#  website_id       :bigint           not null
#
# Indexes
#
#  index_ahoy_visits_on_user_id                    (user_id)
#  index_ahoy_visits_on_visit_token                (visit_token) UNIQUE
#  index_ahoy_visits_on_visitor_token              (visitor_token)
#  index_ahoy_visits_on_website_id                 (website_id)
#  index_ahoy_visits_on_website_id_and_started_at  (website_id,started_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

RSpec.describe Ahoy::Visit, type: :model do
  let(:website) { create(:pwb_website) }

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
