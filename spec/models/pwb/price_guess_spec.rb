# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_price_guesses
#
#  id                     :uuid             not null, primary key
#  actual_price_cents     :bigint           not null
#  actual_price_currency  :string           default("EUR")
#  guessed_price_cents    :bigint           not null
#  guessed_price_currency :string           default("EUR")
#  listing_type           :string           not null
#  percentage_diff        :decimal(8, 2)
#  score                  :integer          default(0)
#  visitor_token          :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  listing_id             :uuid             not null
#  website_id             :bigint           not null
#
# Indexes
#
#  index_price_guesses_on_listing_and_score    (listing_type,listing_id,score)
#  index_price_guesses_on_listing_and_visitor  (listing_type,listing_id,visitor_token) UNIQUE
#  index_pwb_price_guesses_on_listing          (listing_type,listing_id)
#  index_pwb_price_guesses_on_website_id       (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require "rails_helper"

RSpec.describe Pwb::PriceGuess, type: :model do
  let(:website) { create(:pwb_website) }
  let(:realty_asset) { create(:pwb_realty_asset, website: website) }
  let(:sale_listing) do
    create(:pwb_sale_listing,
           realty_asset: realty_asset,
           price_sale_current_cents: 300_000_00,
           price_sale_current_currency: "EUR")
  end

  describe "validations" do
    it "is valid with valid attributes" do
      guess = described_class.new(
        listing: sale_listing,
        website: website,
        visitor_token: SecureRandom.urlsafe_base64(16),
        guessed_price_cents: 280_000_00,
        guessed_price_currency: "EUR"
      )
      expect(guess).to be_valid
    end

    it "requires visitor_token" do
      guess = described_class.new(
        listing: sale_listing,
        website: website,
        guessed_price_cents: 280_000_00
      )
      expect(guess).not_to be_valid
      expect(guess.errors[:visitor_token]).to be_present
    end

    it "requires guessed_price_cents to be positive" do
      guess = described_class.new(
        listing: sale_listing,
        website: website,
        visitor_token: SecureRandom.urlsafe_base64(16),
        guessed_price_cents: 0
      )
      expect(guess).not_to be_valid
    end

    it "enforces one guess per visitor per listing" do
      visitor_token = SecureRandom.urlsafe_base64(16)

      first_guess = described_class.create!(
        listing: sale_listing,
        website: website,
        visitor_token: visitor_token,
        guessed_price_cents: 280_000_00
      )

      duplicate_guess = described_class.new(
        listing: sale_listing,
        website: website,
        visitor_token: visitor_token,
        guessed_price_cents: 350_000_00
      )

      expect(duplicate_guess).not_to be_valid
      expect(duplicate_guess.errors[:visitor_token]).to be_present
    end
  end

  describe "callbacks" do
    it "sets actual price from listing on create" do
      guess = described_class.create!(
        listing: sale_listing,
        website: website,
        visitor_token: SecureRandom.urlsafe_base64(16),
        guessed_price_cents: 280_000_00
      )

      expect(guess.actual_price_cents).to eq(300_000_00)
      expect(guess.actual_price_currency).to eq("EUR")
    end

    it "calculates score on create" do
      guess = described_class.create!(
        listing: sale_listing,
        website: website,
        visitor_token: SecureRandom.urlsafe_base64(16),
        guessed_price_cents: 280_000_00  # ~7% off
      )

      expect(guess.score).to be_between(80, 100)
      expect(guess.percentage_diff).to be_present
    end
  end

  describe "scopes" do
    before do
      3.times do |i|
        described_class.create!(
          listing: sale_listing,
          website: website,
          visitor_token: "visitor_#{i}",
          guessed_price_cents: (280_000 + i * 10_000) * 100  # 280k, 290k, 300k
        )
      end
    end

    describe ".top_scores" do
      it "orders by score descending" do
        guesses = described_class.top_scores
        scores = guesses.pluck(:score)
        expect(scores).to eq(scores.sort.reverse)
      end
    end

    describe ".leaderboard" do
      it "limits results" do
        expect(described_class.leaderboard(2).count).to eq(2)
      end
    end
  end

  describe "#formatted_guessed_price" do
    it "returns formatted price" do
      guess = described_class.new(
        guessed_price_cents: 280_000_00,
        guessed_price_currency: "EUR"
      )
      expect(guess.formatted_guessed_price).to include("280")
    end
  end

  describe "#feedback_message" do
    it "returns feedback message" do
      guess = described_class.create!(
        listing: sale_listing,
        website: website,
        visitor_token: SecureRandom.urlsafe_base64(16),
        guessed_price_cents: 280_000_00
      )

      expect(guess.feedback_message).to be_present
    end
  end

  describe "#emoji" do
    it "returns an emoji" do
      guess = described_class.create!(
        listing: sale_listing,
        website: website,
        visitor_token: SecureRandom.urlsafe_base64(16),
        guessed_price_cents: 300_000_00
      )

      expect(guess.emoji).to be_present
    end
  end
end
