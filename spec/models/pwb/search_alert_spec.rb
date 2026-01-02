# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_search_alerts
#
#  id                  :bigint           not null, primary key
#  clicked_at          :datetime
#  delivered_at        :datetime
#  email_status        :string
#  error_message       :text
#  new_properties      :jsonb            not null
#  opened_at           :datetime
#  properties_count    :integer          default(0), not null
#  sent_at             :datetime
#  total_results_count :integer          default(0)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  saved_search_id     :bigint           not null
#
# Indexes
#
#  index_pwb_search_alerts_on_saved_search_id                 (saved_search_id)
#  index_pwb_search_alerts_on_saved_search_id_and_created_at  (saved_search_id,created_at)
#  index_pwb_search_alerts_on_sent_at                         (sent_at)
#
# Foreign Keys
#
#  fk_rails_...  (saved_search_id => pwb_saved_searches.id)
#
require "rails_helper"

RSpec.describe Pwb::SearchAlert, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:saved_search) }
  end

  describe "validations" do
    subject { build(:pwb_search_alert) }

    it { is_expected.to validate_numericality_of(:properties_count).is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    let(:saved_search) { create(:pwb_saved_search) }

    describe ".recent" do
      it "orders by created_at desc" do
        old = create(:pwb_search_alert, saved_search: saved_search, created_at: 2.days.ago)
        new_alert = create(:pwb_search_alert, saved_search: saved_search, created_at: 1.day.ago)

        expect(described_class.recent.first).to eq(new_alert)
        expect(described_class.recent.last).to eq(old)
      end
    end

    describe ".delivered" do
      it "returns only delivered alerts" do
        delivered = create(:pwb_search_alert, :delivered, saved_search: saved_search)
        create(:pwb_search_alert, saved_search: saved_search)

        expect(described_class.delivered).to contain_exactly(delivered)
      end
    end

    describe ".pending" do
      it "returns only pending alerts" do
        pending_alert = create(:pwb_search_alert, saved_search: saved_search)
        create(:pwb_search_alert, :delivered, saved_search: saved_search)

        expect(described_class.pending).to contain_exactly(pending_alert)
      end
    end

    describe ".failed" do
      it "returns only failed alerts" do
        failed = create(:pwb_search_alert, :failed, saved_search: saved_search)
        create(:pwb_search_alert, saved_search: saved_search)

        expect(described_class.failed).to contain_exactly(failed)
      end
    end
  end

  describe "instance methods" do
    describe "#mark_sent!" do
      it "marks alert as sent" do
        alert = create(:pwb_search_alert)
        alert.mark_sent!
        expect(alert.sent?).to be true
        expect(alert.sent_at).to be_present
        expect(alert.email_status).to eq("sent")
      end
    end

    describe "#mark_delivered!" do
      it "marks alert as delivered" do
        alert = create(:pwb_search_alert)
        alert.mark_delivered!
        expect(alert.delivered?).to be true
        expect(alert.delivered_at).to be_present
        expect(alert.email_status).to eq("delivered")
      end
    end

    describe "#mark_failed!" do
      it "records delivery error" do
        alert = create(:pwb_search_alert)
        alert.mark_failed!("Connection refused")
        expect(alert.error_message).to eq("Connection refused")
        expect(alert.email_status).to eq("failed")
      end
    end

    describe "#properties" do
      it "returns new_properties array" do
        alert = create(:pwb_search_alert)
        expect(alert.properties).to be_an(Array)
        expect(alert.properties.size).to eq(2)
      end

      it "returns empty array when nil" do
        alert = build(:pwb_search_alert, new_properties: nil)
        expect(alert.properties).to eq([])
      end
    end

    describe "#property_references" do
      it "extracts references from properties" do
        alert = create(:pwb_search_alert)
        expect(alert.property_references).to contain_exactly("REF001", "REF002")
      end
    end
  end

  describe "delegations" do
    it "delegates website to saved_search" do
      alert = create(:pwb_search_alert)
      expect(alert.website).to eq(alert.saved_search.website)
    end

    it "delegates email to saved_search" do
      alert = create(:pwb_search_alert)
      expect(alert.email).to eq(alert.saved_search.email)
    end
  end
end
