# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_saved_properties
# Database name: primary
#
#  id                   :bigint           not null, primary key
#  current_price_cents  :integer
#  email                :string           not null
#  external_reference   :string           not null
#  manage_token         :string           not null
#  notes                :text
#  original_price_cents :integer
#  price_changed_at     :datetime
#  property_data        :jsonb            not null
#  provider             :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  website_id           :bigint           not null
#
# Indexes
#
#  index_pwb_saved_properties_on_email                 (email)
#  index_pwb_saved_properties_on_manage_token          (manage_token) UNIQUE
#  index_pwb_saved_properties_on_website_id            (website_id)
#  index_pwb_saved_properties_on_website_id_and_email  (website_id,email)
#  index_saved_properties_on_provider_ref              (website_id,provider,external_reference)
#  index_saved_properties_unique_per_email             (email,provider,external_reference) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require "rails_helper"

RSpec.describe Pwb::SavedProperty, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:website) }
  end

  describe "validations" do
    subject { create(:pwb_saved_property) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:external_reference) }
    it { is_expected.to validate_uniqueness_of(:manage_token) }

    it "validates email format" do
      saved_property = build(:pwb_saved_property, email: "invalid")
      expect(saved_property).not_to be_valid
    end

    it "validates uniqueness of external_reference scoped to email and provider" do
      website = create(:pwb_website)
      create(:pwb_saved_property,
             website: website,
             email: "user@example.com",
             provider: "resales_online",
             external_reference: "REF001")

      duplicate = build(:pwb_saved_property,
                        website: website,
                        email: "user@example.com",
                        provider: "resales_online",
                        external_reference: "REF001")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:external_reference]).to include("has already been saved")
    end

    it "allows same reference for different emails" do
      website = create(:pwb_website)
      create(:pwb_saved_property,
             website: website,
             email: "user1@example.com",
             provider: "resales_online",
             external_reference: "REF001")

      other = build(:pwb_saved_property,
                    website: website,
                    email: "user2@example.com",
                    provider: "resales_online",
                    external_reference: "REF001")

      expect(other).to be_valid
    end
  end

  describe "callbacks" do
    it "generates manage token on create" do
      saved_property = build(:pwb_saved_property, manage_token: nil)
      saved_property.save!
      expect(saved_property.manage_token).to be_present
    end

    it "normalizes email to lowercase" do
      saved_property = create(:pwb_saved_property, email: "USER@EXAMPLE.COM")
      expect(saved_property.email).to eq("user@example.com")
    end
  end

  describe "scopes" do
    let(:website) { create(:pwb_website) }

    describe ".for_email" do
      it "returns properties for a specific email" do
        prop1 = create(:pwb_saved_property, website: website, email: "user@example.com")
        create(:pwb_saved_property, website: website, email: "other@example.com")

        expect(described_class.for_email("user@example.com")).to contain_exactly(prop1)
      end
    end

    describe ".for_provider" do
      it "returns properties for a specific provider" do
        resales = create(:pwb_saved_property, website: website, provider: "resales_online")
        create(:pwb_saved_property, website: website, provider: "other_provider")

        expect(described_class.for_provider("resales_online")).to contain_exactly(resales)
      end
    end

    describe ".recent" do
      it "orders by created_at desc" do
        old = create(:pwb_saved_property, website: website, created_at: 2.days.ago)
        new = create(:pwb_saved_property, website: website, created_at: 1.day.ago)

        expect(described_class.recent.first).to eq(new)
        expect(described_class.recent.last).to eq(old)
      end
    end

    describe ".with_price_change" do
      it "returns properties with price changes" do
        changed = create(:pwb_saved_property, :price_reduced, website: website)
        create(:pwb_saved_property, website: website)

        expect(described_class.with_price_change).to contain_exactly(changed)
      end
    end
  end

  describe "instance methods" do
    describe "#property_data_hash" do
      it "returns symbolized hash" do
        saved_property = build(:pwb_saved_property, property_data: { "title" => "Villa" })
        expect(saved_property.property_data_hash[:title]).to eq("Villa")
      end
    end

    describe "#title" do
      it "returns title from property data" do
        saved_property = build(:pwb_saved_property)
        expect(saved_property.title).to eq("Beautiful Villa in Marbella")
      end

      it "falls back to reference when no title" do
        saved_property = build(:pwb_saved_property,
                               property_data: {},
                               external_reference: "REF123")
        expect(saved_property.title).to eq("Property REF123")
      end
    end

    describe "#price_formatted" do
      it "formats price with currency" do
        saved_property = build(:pwb_saved_property)
        expect(saved_property.price_formatted).to eq("EUR 450,000")
      end

      it "returns nil when no price" do
        saved_property = build(:pwb_saved_property, property_data: { title: "Test" })
        expect(saved_property.price_formatted).to be_nil
      end
    end

    describe "#price_changed?" do
      it "returns true when price changed" do
        saved_property = build(:pwb_saved_property, :price_reduced)
        expect(saved_property.price_changed?).to be true
      end

      it "returns false when price unchanged" do
        saved_property = build(:pwb_saved_property)
        expect(saved_property.price_changed?).to be false
      end
    end

    describe "#price_decreased?" do
      it "returns true when current price is lower" do
        saved_property = build(:pwb_saved_property, :price_reduced)
        expect(saved_property.price_decreased?).to be true
      end

      it "returns false when current price is higher" do
        saved_property = build(:pwb_saved_property, :price_increased)
        expect(saved_property.price_decreased?).to be false
      end
    end

    describe "#price_increased?" do
      it "returns true when current price is higher" do
        saved_property = build(:pwb_saved_property, :price_increased)
        expect(saved_property.price_increased?).to be true
      end
    end

    describe "#price_change_percentage" do
      it "calculates percentage decrease" do
        saved_property = build(:pwb_saved_property, :price_reduced)
        # 500_000 -> 450_000 = -10%
        expect(saved_property.price_change_percentage).to eq(-10.0)
      end

      it "calculates percentage increase" do
        saved_property = build(:pwb_saved_property, :price_increased)
        # 400_000 -> 450_000 = +12.5%
        expect(saved_property.price_change_percentage).to eq(12.5)
      end

      it "returns 0 when no change" do
        saved_property = build(:pwb_saved_property)
        expect(saved_property.price_change_percentage).to eq(0)
      end
    end

    describe "#main_image" do
      it "returns first image" do
        saved_property = build(:pwb_saved_property)
        expect(saved_property.main_image).to eq("https://example.com/image1.jpg")
      end

      it "returns nil when no images" do
        saved_property = build(:pwb_saved_property, :without_images)
        expect(saved_property.main_image).to be_nil
      end
    end

    describe "#manage_url" do
      it "generates correct URL" do
        saved_property = create(:pwb_saved_property)
        url = saved_property.manage_url(host: "https://example.com")
        expect(url).to eq("https://example.com/my/favorites?token=#{saved_property.manage_token}")
      end
    end
  end

  describe "class methods" do
    describe ".save_property!" do
      let(:website) { create(:pwb_website) }
      let(:property_data) do
        { title: "New Villa", price: 300_000, currency: "EUR" }
      end

      it "creates a new saved property" do
        expect do
          described_class.save_property!(
            website: website,
            email: "user@example.com",
            provider: "resales_online",
            reference: "NEW001",
            property_data: property_data
          )
        end.to change(described_class, :count).by(1)
      end

      it "returns existing property if already saved" do
        existing = described_class.save_property!(
          website: website,
          email: "user@example.com",
          provider: "resales_online",
          reference: "NEW001",
          property_data: property_data
        )

        result = described_class.save_property!(
          website: website,
          email: "user@example.com",
          provider: "resales_online",
          reference: "NEW001",
          property_data: { title: "Updated" }
        )

        expect(result.id).to eq(existing.id)
      end

      it "sets price tracking fields" do
        saved = described_class.save_property!(
          website: website,
          email: "user@example.com",
          provider: "resales_online",
          reference: "NEW001",
          property_data: property_data
        )

        expect(saved.original_price_cents).to eq(300_000)
        expect(saved.current_price_cents).to eq(300_000)
      end
    end
  end
end
