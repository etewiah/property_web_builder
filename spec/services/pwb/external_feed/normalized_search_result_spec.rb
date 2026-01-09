# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ExternalFeed::NormalizedSearchResult do
  let(:properties) do
    [
      Pwb::ExternalFeed::NormalizedProperty.new(reference: "REF1", title: "Property 1"),
      Pwb::ExternalFeed::NormalizedProperty.new(reference: "REF2", title: "Property 2"),
      Pwb::ExternalFeed::NormalizedProperty.new(reference: "REF3", title: "Property 3")
    ]
  end

  describe "#initialize" do
    it "accepts properties array" do
      result = described_class.new(properties: properties)
      expect(result.properties).to eq(properties)
    end

    it "uses provided total_count" do
      result = described_class.new(properties: properties, total_count: 100)
      expect(result.total_count).to eq(100)
    end

    it "defaults to page 1" do
      result = described_class.new(properties: properties)
      expect(result.page).to eq(1)
    end

    it "defaults per_page to 24" do
      result = described_class.new(properties: properties)
      expect(result.per_page).to eq(24)
    end

    it "defaults error to false" do
      result = described_class.new(properties: properties)
      expect(result.error?).to be false
    end
  end

  describe "#total_pages" do
    it "calculates total pages correctly" do
      result = described_class.new(properties: properties, total_count: 100, per_page: 20)
      expect(result.total_pages).to eq(5)
    end

    it "rounds up for partial pages" do
      result = described_class.new(properties: properties, total_count: 21, per_page: 20)
      expect(result.total_pages).to eq(2)
    end

    it "returns 1 for empty results" do
      result = described_class.new(properties: [], total_count: 0)
      expect(result.total_pages).to eq(0)
    end

    it "handles single page" do
      result = described_class.new(properties: properties, total_count: 3, per_page: 20)
      expect(result.total_pages).to eq(1)
    end
  end

  describe "#next_page" do
    it "returns next page number when not on last page" do
      result = described_class.new(
        properties: properties,
        total_count: 100,
        page: 2,
        per_page: 20
      )
      expect(result.next_page).to eq(3)
    end

    it "returns nil on last page" do
      result = described_class.new(
        properties: properties,
        total_count: 100,
        page: 5,
        per_page: 20
      )
      expect(result.next_page).to be_nil
    end
  end

  describe "#prev_page" do
    it "returns previous page number when not on first page" do
      result = described_class.new(
        properties: properties,
        total_count: 100,
        page: 3,
        per_page: 20
      )
      expect(result.prev_page).to eq(2)
    end

    it "returns nil on first page" do
      result = described_class.new(
        properties: properties,
        total_count: 100,
        page: 1
      )
      expect(result.prev_page).to be_nil
    end
  end

  describe "#results_range" do
    it "returns correct range for first page" do
      result = described_class.new(
        properties: properties,
        total_count: 100,
        page: 1,
        per_page: 20
      )
      expect(result.results_range).to eq("1-20 of 100")
    end

    it "returns correct range for middle page" do
      result = described_class.new(
        properties: properties,
        total_count: 100,
        page: 2,
        per_page: 20
      )
      expect(result.results_range).to eq("21-40 of 100")
    end
  end

  describe "#any?" do
    it "returns true when properties present" do
      result = described_class.new(properties: properties)
      expect(result.any?).to be true
    end

    it "returns false when no properties" do
      result = described_class.new(properties: [])
      expect(result.any?).to be false
    end
  end

  describe "#empty?" do
    it "returns false when properties present" do
      result = described_class.new(properties: properties)
      expect(result.empty?).to be false
    end

    it "returns true when no properties" do
      result = described_class.new(properties: [])
      expect(result.empty?).to be true
    end
  end

  describe "#error?" do
    it "returns false by default" do
      result = described_class.new(properties: properties)
      expect(result.error?).to be false
    end

    it "returns true when error is set" do
      result = described_class.new(properties: [], error: true, error_message: "API Error")
      expect(result.error?).to be true
    end
  end

  describe "#each" do
    it "yields each property" do
      result = described_class.new(properties: properties)
      refs = result.map(&:reference)
      expect(refs).to eq(%w[REF1 REF2 REF3])
    end

    it "returns enumerator when no block given" do
      result = described_class.new(properties: properties)
      expect(result.each).to be_an(Enumerator)
    end
  end

  describe "#map" do
    it "maps over properties" do
      result = described_class.new(properties: properties)
      refs = result.map(&:reference)
      expect(refs).to eq(%w[REF1 REF2 REF3])
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      result = described_class.new(
        properties: properties,
        total_count: 100,
        page: 2,
        per_page: 20
      )
      hash = result.to_h

      expect(hash[:properties]).to be_an(Array)
      expect(hash[:total_count]).to eq(100)
      expect(hash[:page]).to eq(2)
      expect(hash[:per_page]).to eq(20)
      expect(hash[:total_pages]).to eq(5)
    end
  end
end
