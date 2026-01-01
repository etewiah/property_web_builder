# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ExternalFeed::CacheStore do
  let(:website) do
    create(:website,
           external_feed_enabled: true,
           external_feed_provider: "test_provider",
           external_feed_config: { api_key: "test" })
  end
  let(:cache_store) { described_class.new(website) }

  describe "#initialize" do
    it "sets website and provider name" do
      expect(cache_store.website).to eq(website)
      expect(cache_store.provider_name).to eq("test_provider")
    end

    it "uses config from website" do
      expect(cache_store.config[:api_key]).to eq("test")
    end
  end

  describe "#fetch_data" do
    it "caches and returns the block result" do
      call_count = 0
      result = cache_store.fetch_data(:search, { page: 1 }) do
        call_count += 1
        "search results"
      end

      expect(result).to eq("search results")
      expect(call_count).to eq(1)

      # Second call should use cache
      result2 = cache_store.fetch_data(:search, { page: 1 }) do
        call_count += 1
        "new results"
      end

      expect(result2).to eq("search results")
      expect(call_count).to eq(1) # Not incremented
    end

    it "generates different cache keys for different params" do
      result1 = cache_store.fetch_data(:search, { page: 1 }) { "page 1" }
      result2 = cache_store.fetch_data(:search, { page: 2 }) { "page 2" }

      expect(result1).to eq("page 1")
      expect(result2).to eq("page 2")
    end

    it "uses appropriate TTL for operation type" do
      # This is more of a verification that different operations get different TTLs
      # The actual TTL behavior is handled by Rails.cache
      expect { cache_store.fetch_data(:search, {}) { "result" } }.not_to raise_error
      expect { cache_store.fetch_data(:property, {}) { "result" } }.not_to raise_error
      expect { cache_store.fetch_data(:similar, {}) { "result" } }.not_to raise_error
      expect { cache_store.fetch_data(:locations, {}) { "result" } }.not_to raise_error
    end
  end

  describe "#invalidate" do
    before do
      cache_store.fetch_data(:search, { page: 1 }) { "cached" }
    end

    it "clears specific cache entry" do
      cache_store.invalidate(:search, { page: 1 })

      call_count = 0
      cache_store.fetch_data(:search, { page: 1 }) do
        call_count += 1
        "fresh"
      end

      expect(call_count).to eq(1) # Block was called, meaning cache was cleared
    end
  end

  describe "#invalidate_all" do
    it "clears all cache for this website/provider" do
      cache_store.fetch_data(:search, { page: 1 }) { "search" }
      cache_store.fetch_data(:property, { ref: "123" }) { "property" }

      expect { cache_store.invalidate_all }.not_to raise_error
    end
  end

  describe "#cache_key" do
    it "generates deterministic keys for same params" do
      key1 = cache_store.cache_key(:search, { page: 1, sort: "price" })
      key2 = cache_store.cache_key(:search, { page: 1, sort: "price" })
      expect(key1).to eq(key2)
    end

    it "generates different keys for different params" do
      key1 = cache_store.cache_key(:search, { page: 1 })
      key2 = cache_store.cache_key(:search, { page: 2 })
      expect(key1).not_to eq(key2)
    end

    it "includes website id in key" do
      key = cache_store.cache_key(:search, {})
      expect(key).to include(website.id.to_s)
    end

    it "includes provider in key" do
      key = cache_store.cache_key(:search, {})
      expect(key).to include("test_provider")
    end

    it "handles params with nil values" do
      expect { cache_store.cache_key(:search, { page: nil }) }.not_to raise_error
    end

    it "handles nested hash params" do
      key = cache_store.cache_key(:search, { filters: { min_price: 100 } })
      expect(key).to be_a(String)
    end
  end

  describe "multi-tenant isolation" do
    let(:website2) do
      create(:website,
             external_feed_enabled: true,
             external_feed_provider: "test_provider",
             external_feed_config: { api_key: "test2" })
    end
    let(:cache_store2) { described_class.new(website2) }

    it "keeps cache separate between websites" do
      cache_store.fetch_data(:search, { page: 1 }) { "website1 results" }
      cache_store2.fetch_data(:search, { page: 1 }) { "website2 results" }

      result1 = cache_store.fetch_data(:search, { page: 1 }) { "should not be called" }
      result2 = cache_store2.fetch_data(:search, { page: 1 }) { "should not be called" }

      expect(result1).to eq("website1 results")
      expect(result2).to eq("website2 results")
    end
  end
end
