# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ExternalFeed::NormalizedProperty do
  # Note: Prices are stored in cents (e.g., 50_000_000 cents = EUR 500,000)
  describe "#initialize" do
    it "accepts all standard attributes" do
      property = described_class.new(
        reference: "REF123",
        title: "Beautiful Villa",
        price: 50_000_000, # EUR 500,000 in cents
        currency: "EUR",
        bedrooms: 4,
        bathrooms: 3,
        built_area: 250,
        listing_type: :sale
      )

      expect(property.reference).to eq("REF123")
      expect(property.title).to eq("Beautiful Villa")
      expect(property.price).to eq(50_000_000)
      expect(property.currency).to eq("EUR")
      expect(property.bedrooms).to eq(4)
      expect(property.bathrooms).to eq(3)
      expect(property.built_area).to eq(250)
      expect(property.listing_type).to eq(:sale)
    end

    it "defaults listing_type to :sale" do
      property = described_class.new(reference: "REF123")
      expect(property.listing_type).to eq(:sale)
    end

    it "defaults currency to EUR" do
      property = described_class.new(reference: "REF123")
      expect(property.currency).to eq("EUR")
    end

    it "defaults images to empty array" do
      property = described_class.new(reference: "REF123")
      expect(property.images).to eq([])
    end

    it "defaults features to empty array" do
      property = described_class.new(reference: "REF123")
      expect(property.features).to eq([])
    end
  end

  describe "#formatted_price" do
    it "formats price with currency symbol" do
      # 50_000_000 cents = EUR 500,000
      property = described_class.new(reference: "REF123", price: 50_000_000, currency: "EUR")
      expect(property.formatted_price).to eq("EUR 500,000")
    end

    it "returns nil when price is nil" do
      property = described_class.new(reference: "REF123", price: nil)
      expect(property.formatted_price).to be_nil
    end

    it "handles zero price" do
      property = described_class.new(reference: "REF123", price: 0)
      expect(property.formatted_price).to include("0")
    end
  end

  describe "#main_image" do
    it "returns first image url when images present" do
      property = described_class.new(
        reference: "REF123",
        images: [
          { url: "http://example.com/img1.jpg" },
          { url: "http://example.com/img2.jpg" }
        ]
      )
      expect(property.main_image).to eq("http://example.com/img1.jpg")
    end

    it "returns nil when no images" do
      property = described_class.new(reference: "REF123", images: [])
      expect(property.main_image).to be_nil
    end
  end

  describe "#available?" do
    it "returns true for available status" do
      property = described_class.new(reference: "REF123", status: :available)
      expect(property.available?).to be true
    end

    it "returns false for sold status" do
      property = described_class.new(reference: "REF123", status: :sold)
      expect(property.available?).to be false
    end

    it "returns false for rented status" do
      property = described_class.new(reference: "REF123", status: :rented)
      expect(property.available?).to be false
    end

    it "returns true when status is nil" do
      property = described_class.new(reference: "REF123", status: nil)
      expect(property.available?).to be true
    end
  end

  describe "#price_reduced?" do
    it "returns true when original_price is higher than price" do
      property = described_class.new(
        reference: "REF123",
        price: 40_000_000, # EUR 400,000 in cents
        original_price: 50_000_000 # EUR 500,000 in cents
      )
      expect(property.price_reduced?).to be true
    end

    it "returns false when no original_price" do
      property = described_class.new(reference: "REF123", price: 40_000_000)
      expect(property.price_reduced?).to be false
    end

    it "returns false when original_price equals price" do
      property = described_class.new(
        reference: "REF123",
        price: 40_000_000,
        original_price: 40_000_000
      )
      expect(property.price_reduced?).to be false
    end
  end

  describe "#summary" do
    it "builds summary hash from bedrooms, bathrooms, and area" do
      property = described_class.new(
        reference: "REF123",
        bedrooms: 3,
        bathrooms: 2,
        built_area: 150
      )
      summary = property.summary
      expect(summary).to be_a(Hash)
      expect(summary[:bedrooms]).to eq(3)
      expect(summary[:bathrooms]).to eq(2)
      expect(summary[:built_area]).to eq(150)
    end

    it "handles missing values gracefully" do
      property = described_class.new(reference: "REF123", bedrooms: 3)
      summary = property.summary
      expect(summary[:bedrooms]).to eq(3)
      expect(summary[:bathrooms]).to be_nil
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      property = described_class.new(
        reference: "REF123",
        title: "Test Property",
        price: 30_000_000 # EUR 300,000 in cents
      )
      hash = property.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:reference]).to eq("REF123")
      expect(hash[:title]).to eq("Test Property")
      expect(hash[:price]).to eq(30_000_000)
    end
  end

  describe "#price_in_units" do
    it "returns price per square meter for built area" do
      # 30_000_000 cents = EUR 300,000, area = 150 m2
      # Price per m2 = 300,000 / 150 = 2000 EUR/m2
      property = described_class.new(
        reference: "REF123",
        price: 30_000_000, # EUR 300,000 in cents
        built_area: 150
      )
      expect(property.price_in_units(:built)).to eq(2000)
    end

    it "returns price per square meter for plot area" do
      # 30_000_000 cents = EUR 300,000, area = 500 m2
      # Price per m2 = 300,000 / 500 = 600 EUR/m2
      property = described_class.new(
        reference: "REF123",
        price: 30_000_000, # EUR 300,000 in cents
        plot_area: 500
      )
      expect(property.price_in_units(:plot)).to eq(600)
    end

    it "returns nil when area is zero" do
      property = described_class.new(reference: "REF123", price: 30_000_000, built_area: 0)
      expect(property.price_in_units(:built)).to be_nil
    end

    it "returns nil when price is nil" do
      property = described_class.new(reference: "REF123", built_area: 150)
      expect(property.price_in_units(:built)).to be_nil
    end
  end
end
