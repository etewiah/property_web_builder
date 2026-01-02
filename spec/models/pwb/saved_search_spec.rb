# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_saved_searches
#
#  id                 :bigint           not null, primary key
#  alert_frequency    :integer          default("none"), not null
#  email              :string           not null
#  email_verified     :boolean          default(FALSE), not null
#  enabled            :boolean          default(TRUE), not null
#  last_result_count  :integer          default(0)
#  last_run_at        :datetime
#  manage_token       :string           not null
#  name               :string
#  search_criteria    :jsonb            not null
#  seen_property_refs :jsonb            not null
#  unsubscribe_token  :string           not null
#  verification_token :string
#  verified_at        :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  website_id         :bigint           not null
#
# Indexes
#
#  index_pwb_saved_searches_on_email                 (email)
#  index_pwb_saved_searches_on_manage_token          (manage_token) UNIQUE
#  index_pwb_saved_searches_on_unsubscribe_token     (unsubscribe_token) UNIQUE
#  index_pwb_saved_searches_on_verification_token    (verification_token) UNIQUE
#  index_pwb_saved_searches_on_website_id            (website_id)
#  index_pwb_saved_searches_on_website_id_and_email  (website_id,email)
#  index_saved_searches_for_alerts                   (website_id,enabled,alert_frequency)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require "rails_helper"

RSpec.describe Pwb::SavedSearch, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:website) }
    it { is_expected.to have_many(:alerts).dependent(:destroy) }
  end

  describe "validations" do
    subject { create(:pwb_saved_search) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:search_criteria) }
    it { is_expected.to validate_uniqueness_of(:unsubscribe_token) }
    it { is_expected.to validate_uniqueness_of(:manage_token) }

    it "validates email format" do
      saved_search = build(:pwb_saved_search, email: "invalid-email")
      expect(saved_search).not_to be_valid
      expect(saved_search.errors[:email]).to be_present
    end

    it "accepts valid email" do
      saved_search = build(:pwb_saved_search, email: "user@example.com")
      expect(saved_search).to be_valid
    end
  end

  describe "callbacks" do
    it "generates tokens on create" do
      saved_search = build(:pwb_saved_search, unsubscribe_token: nil, manage_token: nil)
      saved_search.save!
      expect(saved_search.unsubscribe_token).to be_present
      expect(saved_search.manage_token).to be_present
    end

    it "generates a name from criteria if not provided" do
      saved_search = create(:pwb_saved_search, name: nil, search_criteria: { listing_type: "sale", location: "Marbella" })
      expect(saved_search.name).to include("Marbella")
    end

    it "normalizes email to lowercase" do
      saved_search = create(:pwb_saved_search, email: "USER@EXAMPLE.COM")
      expect(saved_search.email).to eq("user@example.com")
    end
  end

  describe "enums" do
    it "defines alert_frequency enum" do
      expect(described_class.alert_frequencies).to eq(
        "none" => 0,
        "daily" => 1,
        "weekly" => 2
      )
    end
  end

  describe "scopes" do
    let(:website) { create(:pwb_website) }

    describe ".enabled" do
      it "returns only enabled searches" do
        enabled = create(:pwb_saved_search, website: website, enabled: true)
        create(:pwb_saved_search, :disabled, website: website)

        expect(described_class.enabled).to contain_exactly(enabled)
      end
    end

    describe ".daily_alerts" do
      it "returns enabled searches with daily frequency" do
        daily = create(:pwb_saved_search, website: website, alert_frequency: :daily)
        create(:pwb_saved_search, :weekly, website: website)
        create(:pwb_saved_search, :disabled, website: website, alert_frequency: :daily)

        expect(described_class.daily_alerts).to contain_exactly(daily)
      end
    end

    describe ".weekly_alerts" do
      it "returns enabled searches with weekly frequency" do
        weekly = create(:pwb_saved_search, :weekly, website: website)
        create(:pwb_saved_search, website: website, alert_frequency: :daily)

        expect(described_class.weekly_alerts).to contain_exactly(weekly)
      end
    end

    describe ".for_email" do
      it "returns searches for a specific email" do
        search1 = create(:pwb_saved_search, website: website, email: "user@example.com")
        create(:pwb_saved_search, website: website, email: "other@example.com")

        expect(described_class.for_email("user@example.com")).to contain_exactly(search1)
      end

      it "is case insensitive" do
        search = create(:pwb_saved_search, website: website, email: "user@example.com")
        expect(described_class.for_email("USER@EXAMPLE.COM")).to contain_exactly(search)
      end
    end

    describe ".needs_run" do
      it "returns searches that need daily run" do
        needs_run = create(:pwb_saved_search, :needs_daily_run, website: website)
        create(:pwb_saved_search, :ran_recently, website: website)

        expect(described_class.needs_run(:daily)).to contain_exactly(needs_run)
      end

      it "returns searches that never ran" do
        never_ran = create(:pwb_saved_search, website: website, last_run_at: nil)
        expect(described_class.needs_run(:daily)).to contain_exactly(never_ran)
      end
    end
  end

  describe "instance methods" do
    describe "#search_criteria_hash" do
      it "returns symbolized hash" do
        saved_search = build(:pwb_saved_search, search_criteria: { "listing_type" => "sale" })
        expect(saved_search.search_criteria_hash).to eq(listing_type: "sale")
      end

      it "returns empty hash when nil" do
        saved_search = build(:pwb_saved_search, search_criteria: nil)
        # Override the validation for this test
        saved_search.instance_variable_set(:@skip_validation, true)
        expect(saved_search.search_criteria_hash).to eq({})
      end
    end

    describe "#criteria_summary" do
      it "builds summary from criteria" do
        saved_search = build(:pwb_saved_search, :complex_search)
        summary = saved_search.criteria_summary
        expect(summary).to include("Sale")
        expect(summary).to include("marbella")
      end
    end

    describe "#find_new_properties" do
      it "returns references not in seen list" do
        saved_search = create(:pwb_saved_search, :with_seen_properties)
        new_refs = saved_search.find_new_properties(["REF001", "REF004", "REF005"])
        expect(new_refs).to contain_exactly("REF004", "REF005")
      end

      it "returns all when none seen" do
        saved_search = create(:pwb_saved_search, seen_property_refs: [])
        new_refs = saved_search.find_new_properties(["REF001", "REF002"])
        expect(new_refs).to contain_exactly("REF001", "REF002")
      end
    end

    describe "#record_new_properties!" do
      it "adds new references to seen list" do
        saved_search = create(:pwb_saved_search, seen_property_refs: ["REF001"])
        saved_search.record_new_properties!(["REF002", "REF003"])
        expect(saved_search.reload.seen_property_refs).to include("REF001", "REF002", "REF003")
      end

      it "does not duplicate existing refs" do
        saved_search = create(:pwb_saved_search, seen_property_refs: ["REF001"])
        saved_search.record_new_properties!(["REF001", "REF002"])
        expect(saved_search.reload.seen_property_refs.count("REF001")).to eq(1)
      end
    end

    describe "#unsubscribe!" do
      it "disables the search and sets frequency to none" do
        saved_search = create(:pwb_saved_search, enabled: true, alert_frequency: :daily)
        saved_search.unsubscribe!
        expect(saved_search.enabled).to be false
        expect(saved_search.alert_frequency).to eq("none")
      end
    end

    describe "#verify_email!" do
      it "marks email as verified" do
        saved_search = create(:pwb_saved_search, :unverified)
        saved_search.verify_email!
        expect(saved_search.email_verified).to be true
        expect(saved_search.verified_at).to be_present
        expect(saved_search.verification_token).to be_nil
      end
    end

    describe "#manage_url" do
      it "generates correct URL" do
        saved_search = create(:pwb_saved_search)
        url = saved_search.manage_url(host: "https://example.com")
        expect(url).to eq("https://example.com/my/saved_searches?token=#{saved_search.manage_token}")
      end
    end

    describe "#unsubscribe_url" do
      it "generates correct URL" do
        saved_search = create(:pwb_saved_search)
        url = saved_search.unsubscribe_url(host: "https://example.com")
        expect(url).to eq("https://example.com/my/saved_searches/unsubscribe?token=#{saved_search.unsubscribe_token}")
      end
    end
  end

  describe "class methods" do
    describe ".frequency_cutoff" do
      it "returns 23 hours ago for daily" do
        cutoff = described_class.frequency_cutoff(:daily)
        expect(cutoff).to be_within(1.minute).of(23.hours.ago)
      end

      it "returns 6 days ago for weekly" do
        cutoff = described_class.frequency_cutoff(:weekly)
        expect(cutoff).to be_within(1.minute).of(6.days.ago)
      end
    end
  end
end
