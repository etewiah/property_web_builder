# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_market_reports
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  ai_insights                :jsonb
#  branding                   :jsonb
#  city                       :string
#  comparable_properties      :jsonb
#  generated_at               :datetime
#  latitude                   :decimal(10, 7)
#  longitude                  :decimal(10, 7)
#  market_statistics          :jsonb
#  postal_code                :string
#  radius_km                  :decimal(5, 2)
#  reference_number           :string
#  region                     :string
#  report_type                :string           not null
#  share_token                :string
#  shared_at                  :datetime
#  status                     :string           default("draft")
#  subject_details            :jsonb
#  suggested_price_currency   :string           default("USD")
#  suggested_price_high_cents :integer
#  suggested_price_low_cents  :integer
#  title                      :string           not null
#  view_count                 :integer          default(0)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  ai_generation_request_id   :bigint
#  subject_property_id        :uuid
#  user_id                    :bigint
#  website_id                 :bigint           not null
#
# Indexes
#
#  index_pwb_market_reports_on_ai_generation_request_id    (ai_generation_request_id)
#  index_pwb_market_reports_on_share_token                 (share_token) UNIQUE WHERE (share_token IS NOT NULL)
#  index_pwb_market_reports_on_status                      (status)
#  index_pwb_market_reports_on_subject_property_id         (subject_property_id)
#  index_pwb_market_reports_on_user_id                     (user_id)
#  index_pwb_market_reports_on_website_id                  (website_id)
#  index_pwb_market_reports_on_website_id_and_report_type  (website_id,report_type)
#
# Foreign Keys
#
#  fk_rails_...  (ai_generation_request_id => pwb_ai_generation_requests.id)
#  fk_rails_...  (subject_property_id => pwb_realty_assets.id)
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

RSpec.describe Pwb::MarketReport, type: :model do
  let(:website) { create(:pwb_website) }

  describe 'associations' do
    it { is_expected.to belong_to(:website) }
    it { is_expected.to belong_to(:user).class_name('Pwb::User').optional }
    it { is_expected.to belong_to(:ai_generation_request).class_name('Pwb::AiGenerationRequest').optional }
    it { is_expected.to belong_to(:subject_property).class_name('Pwb::RealtyAsset').optional }
    it { is_expected.to have_one_attached(:pdf_file) }
  end

  describe 'validations' do
    subject { build(:pwb_market_report, website: website) }

    it { is_expected.to validate_presence_of(:report_type) }
    it { is_expected.to validate_inclusion_of(:report_type).in_array(Pwb::MarketReport::REPORT_TYPES) }
    it { is_expected.to validate_inclusion_of(:status).in_array(Pwb::MarketReport::STATUSES) }
    it { is_expected.to validate_presence_of(:title) }

    it 'validates uniqueness of share_token' do
      existing = create(:pwb_market_report, :shared, website: website)
      new_report = build(:pwb_market_report, website: website, share_token: existing.share_token)
      expect(new_report).not_to be_valid
      expect(new_report.errors[:share_token]).to include('has already been taken')
    end

    it 'allows nil share_token' do
      report = build(:pwb_market_report, website: website, share_token: nil)
      expect(report).to be_valid
    end
  end

  describe 'scopes' do
    before do
      create(:pwb_market_report, website: website, status: 'draft')
      create(:pwb_market_report, :completed, website: website)
      create(:pwb_market_report, :shared, website: website)
    end

    it '.completed returns completed reports' do
      expect(described_class.completed.count).to eq(1)
    end

    it '.shared returns shared reports' do
      expect(described_class.shared.count).to eq(1)
    end

    it '.drafts returns draft reports' do
      expect(described_class.drafts.count).to eq(1)
    end

    it '.cmas returns CMA reports' do
      expect(described_class.cmas.count).to eq(3)
    end

    it '.recent orders by created_at desc' do
      expect(described_class.recent.first.status).to eq('shared')
    end
  end

  describe 'callbacks' do
    describe '#generate_reference_number' do
      it 'generates a reference number on create' do
        report = create(:pwb_market_report, website: website)
        expect(report.reference_number).to match(/CMA-\d{8}-[A-Z0-9]{6}/)
      end

      it 'does not override existing reference number' do
        report = create(:pwb_market_report, website: website, reference_number: 'CUSTOM-123')
        expect(report.reference_number).to eq('CUSTOM-123')
      end
    end

    describe '#set_default_branding' do
      it 'sets default branding from website' do
        website.update!(company_display_name: 'Test Company', main_logo_url: 'https://example.com/logo.png')
        report = create(:pwb_market_report, website: website)

        expect(report.branding['company_name']).to eq('Test Company')
        expect(report.branding['company_logo_url']).to eq('https://example.com/logo.png')
      end

      it 'does not override existing branding' do
        report = create(:pwb_market_report, :with_branding, website: website)
        expect(report.branding['company_name']).to eq('Premier Realty')
      end
    end
  end

  describe 'state transitions' do
    let(:report) { create(:pwb_market_report, website: website) }

    describe '#mark_generating!' do
      it 'updates status to generating' do
        report.mark_generating!
        expect(report.reload.status).to eq('generating')
      end
    end

    describe '#mark_completed!' do
      it 'updates status to completed with data' do
        report.mark_completed!(
          insights: { executive_summary: 'Great property' },
          statistics: { average_price: 350_000 },
          comparables: [{ address: '123 Main St' }],
          suggested_price: { low_cents: 300_000_00, high_cents: 350_000_00, currency: 'USD' }
        )

        report.reload
        expect(report.status).to eq('completed')
        expect(report.generated_at).to be_present
        expect(report.ai_insights['executive_summary']).to eq('Great property')
        expect(report.market_statistics['average_price']).to eq(350_000)
        expect(report.comparable_properties.first['address']).to eq('123 Main St')
        expect(report.suggested_price_low_cents).to eq(300_000_00)
        expect(report.suggested_price_high_cents).to eq(350_000_00)
      end
    end

    describe '#mark_shared!' do
      it 'updates status to shared with token' do
        report.mark_shared!

        report.reload
        expect(report.status).to eq('shared')
        expect(report.shared_at).to be_present
        expect(report.share_token).to be_present
      end
    end
  end

  describe 'status helpers' do
    it '#draft? returns true for draft status' do
      report = build(:pwb_market_report, status: 'draft')
      expect(report.draft?).to be true
    end

    it '#generating? returns true for generating status' do
      report = build(:pwb_market_report, status: 'generating')
      expect(report.generating?).to be true
    end

    it '#completed? returns true for completed status' do
      report = build(:pwb_market_report, status: 'completed')
      expect(report.completed?).to be true
    end

    it '#shared? returns true for shared status' do
      report = build(:pwb_market_report, status: 'shared')
      expect(report.shared?).to be true
    end

    it '#cma? returns true for CMA report type' do
      report = build(:pwb_market_report, report_type: 'cma')
      expect(report.cma?).to be true
    end
  end

  describe '#record_view!' do
    it 'increments view count' do
      report = create(:pwb_market_report, :shared, website: website)
      expect { report.record_view! }.to change { report.reload.view_count }.by(1)
    end
  end

  describe 'JSONB accessors' do
    let(:report) { create(:pwb_market_report, :completed, website: website) }

    it 'returns AI insights fields' do
      expect(report.executive_summary).to eq('This property is competitively priced for the area.')
      expect(report.strengths).to include('Updated kitchen')
      expect(report.considerations).to include('Single bathroom')
    end

    it 'returns market statistics fields' do
      expect(report.average_price).to eq(375_000)
      expect(report.median_price).to eq(370_000)
      expect(report.price_per_sqft).to eq(250)
    end

    it 'returns branding fields' do
      report = create(:pwb_market_report, :with_branding, website: website)
      expect(report.agent_name).to eq('John Smith')
      expect(report.company_name).to eq('Premier Realty')
    end
  end

  describe '#suggested_price_range' do
    it 'returns formatted price range' do
      report = create(:pwb_market_report, :completed, website: website)
      range = report.suggested_price_range

      expect(range[:low]).to eq(350_000_00)
      expect(range[:high]).to eq(400_000_00)
      expect(range[:currency]).to eq('USD')
      expect(range[:formatted_low]).to eq('$350,000')
      expect(range[:formatted_high]).to eq('$400,000')
    end

    it 'returns nil when prices not set' do
      report = create(:pwb_market_report, website: website)
      expect(report.suggested_price_range).to be_nil
    end
  end

  describe '#pdf_ready?' do
    it 'returns true when PDF is attached' do
      report = create(:pwb_market_report, :with_pdf, website: website)
      expect(report.pdf_ready?).to be true
    end

    it 'returns false when PDF is not attached' do
      report = create(:pwb_market_report, website: website)
      expect(report.pdf_ready?).to be false
    end
  end

  describe '#pdf_filename' do
    it 'returns formatted filename' do
      report = build(:pwb_market_report, report_type: 'cma', reference_number: 'CMA-20240101-ABC123')
      expect(report.pdf_filename).to eq('cma_CMA-20240101-ABC123.pdf')
    end
  end

  describe 'multi-tenancy' do
    let(:other_website) { create(:pwb_website) }

    it 'is scoped by website_id' do
      report1 = create(:pwb_market_report, website: website)
      report2 = create(:pwb_market_report, website: other_website)

      expect(website.market_reports).to include(report1)
      expect(website.market_reports).not_to include(report2)
    end
  end
end
