# frozen_string_literal: true

require "rails_helper"

module Pwb
  RSpec.describe ExternalScraperClient do
    let(:pws_url) { "https://pws.example.com" }
    let(:pws_api_key) { "test-api-key-123" }
    let(:listing_url) { "https://www.rightmove.co.uk/properties/123456" }
    let(:html) { "<html><body>Property content</body></html>" }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PWS_API_URL").and_return(pws_url)
      allow(ENV).to receive(:[]).with("PWS_API_KEY").and_return(pws_api_key)
      allow(ENV).to receive(:[]).with("PWS_TIMEOUT").and_return(nil)
      allow(ENV).to receive(:[]).with("PWS_ENABLED").and_return(nil)
    end

    describe ".enabled?" do
      it "returns true when PWS_API_URL is set" do
        expect(described_class.enabled?).to be true
      end

      it "returns false when PWS_API_URL is not set" do
        allow(ENV).to receive(:[]).with("PWS_API_URL").and_return(nil)
        expect(described_class.enabled?).to be false
      end

      it "returns false when PWS_ENABLED is 'false'" do
        allow(ENV).to receive(:[]).with("PWS_ENABLED").and_return("false")
        expect(described_class.enabled?).to be false
      end

      it "returns true when PWS_ENABLED is 'true'" do
        allow(ENV).to receive(:[]).with("PWS_ENABLED").and_return("true")
        expect(described_class.enabled?).to be true
      end
    end

    describe ".healthy?" do
      it "returns true when health endpoint responds 200" do
        stub_request(:get, "#{pws_url}/public_api/v1/health")
          .to_return(status: 200, body: '{"status":"ok"}', headers: { "Content-Type" => "application/json" })

        expect(described_class.healthy?).to be true
      end

      it "returns false when health endpoint responds non-200" do
        stub_request(:get, "#{pws_url}/public_api/v1/health")
          .to_return(status: 503, body: '{"status":"down"}', headers: { "Content-Type" => "application/json" })

        expect(described_class.healthy?).to be false
      end

      it "returns false when connection fails" do
        stub_request(:get, "#{pws_url}/public_api/v1/health")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

        expect(described_class.healthy?).to be false
      end

      it "returns false when PWS is not enabled" do
        allow(ENV).to receive(:[]).with("PWS_API_URL").and_return(nil)
        expect(described_class.healthy?).to be false
      end
    end

    describe ".supported_portals" do
      it "returns list of portals from PWS" do
        stub_request(:get, "#{pws_url}/public_api/v1/supported_sites")
          .to_return(
            status: 200,
            body: '{"portals":["uk_rightmove","uk_zoopla","es_idealista"]}',
            headers: { "Content-Type" => "application/json" }
          )

        expect(described_class.supported_portals).to eq(%w[uk_rightmove uk_zoopla es_idealista])
      end

      it "returns empty array on connection error" do
        stub_request(:get, "#{pws_url}/public_api/v1/supported_sites")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

        expect(described_class.supported_portals).to eq([])
      end

      it "returns empty array when PWS is not enabled" do
        allow(ENV).to receive(:[]).with("PWS_API_URL").and_return(nil)
        expect(described_class.supported_portals).to eq([])
      end
    end

    describe "#call" do
      subject(:client) { described_class.new(url: listing_url, html: html) }

      context "when extraction succeeds" do
        before do
          stub_request(:post, "#{pws_url}/public_api/v1/listings?format=pwb")
            .with(
              body: { url: listing_url, html: html }.to_json,
              headers: { "X-Api-Key" => pws_api_key, "Content-Type" => "application/json" }
            )
            .to_return(
              status: 200,
              body: {
                success: true,
                portal: "uk_rightmove",
                extraction_rate: 0.85,
                data: {
                  asset_data: { count_bedrooms: 3, city: "London" },
                  listing_data: { title: "Beautiful flat", price_sale_current: 450_000 },
                  images: ["https://example.com/img1.jpg", "https://example.com/img2.jpg"]
                }
              }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
        end

        it "returns a successful Result" do
          result = client.call
          expect(result.success).to be true
        end

        it "extracts asset_data and listing_data" do
          result = client.call
          expect(result.extracted_data["asset_data"]["count_bedrooms"]).to eq(3)
          expect(result.extracted_data["listing_data"]["title"]).to eq("Beautiful flat")
        end

        it "extracts images" do
          result = client.call
          expect(result.extracted_images).to eq(["https://example.com/img1.jpg", "https://example.com/img2.jpg"])
        end

        it "includes portal name" do
          result = client.call
          expect(result.portal).to eq("uk_rightmove")
        end

        it "includes extraction_rate" do
          result = client.call
          expect(result.extraction_rate).to eq(0.85)
        end
      end

      context "when portal is unsupported" do
        before do
          stub_request(:post, "#{pws_url}/public_api/v1/listings?format=pwb")
            .to_return(
              status: 200,
              body: {
                success: false,
                error: { code: "UNSUPPORTED_HOST", message: "Host not supported: www.unknown-realty.com" }
              }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
        end

        it "raises UnsupportedPortalError" do
          expect { client.call }.to raise_error(
            ExternalScraperClient::UnsupportedPortalError,
            "Host not supported: www.unknown-realty.com"
          )
        end
      end

      context "when extraction fails" do
        before do
          stub_request(:post, "#{pws_url}/public_api/v1/listings?format=pwb")
            .to_return(
              status: 200,
              body: {
                success: false,
                error: { code: "EXTRACTION_FAILED", message: "Could not parse listing data" }
              }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
        end

        it "raises ExtractionFailedError" do
          expect { client.call }.to raise_error(
            ExternalScraperClient::ExtractionFailedError,
            "Could not parse listing data"
          )
        end
      end

      context "when an unknown error code is returned" do
        before do
          stub_request(:post, "#{pws_url}/public_api/v1/listings?format=pwb")
            .to_return(
              status: 200,
              body: {
                success: false,
                error: { code: "INTERNAL_ERROR", message: "Something broke" }
              }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
        end

        it "raises base Error" do
          expect { client.call }.to raise_error(ExternalScraperClient::Error, "Something broke")
        end
      end

      context "when connection times out" do
        before do
          stub_request(:post, "#{pws_url}/public_api/v1/listings?format=pwb")
            .to_raise(Faraday::TimeoutError.new("execution expired"))
        end

        it "raises ConnectionError" do
          expect { client.call }.to raise_error(
            ExternalScraperClient::ConnectionError,
            /timed out/
          )
        end
      end

      context "when connection fails" do
        before do
          stub_request(:post, "#{pws_url}/public_api/v1/listings?format=pwb")
            .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
        end

        it "raises ConnectionError" do
          expect { client.call }.to raise_error(
            ExternalScraperClient::ConnectionError,
            /connection failed/
          )
        end
      end
    end
  end
end
