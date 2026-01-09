# frozen_string_literal: true

require "rails_helper"

module Pwb
  module ScraperConnectors
    RSpec.describe Http do
      let(:url) { "https://www.example.com/property/123" }
      let(:connector) { described_class.new(url) }

      describe "#initialize" do
        it "stores the url" do
          expect(connector.url).to eq(url)
        end

        it "strips whitespace from url" do
          conn = described_class.new("  #{url}  ")
          expect(conn.url).to eq(url)
        end

        it "accepts options hash" do
          conn = described_class.new(url, timeout: 60)
          expect(conn.options).to eq({ timeout: 60 })
        end
      end

      describe "#fetch" do
        # HTTP connector requires MIN_CONTENT_LENGTH of 1000 bytes
        let(:valid_html_content) do
          "<html><head><title>Test Property</title></head><body>" + ("x" * 1000) + "</body></html>"
        end

        context "when request succeeds" do
          let(:html_content) { valid_html_content }

          before do
            stub_request(:get, url)
              .to_return(
                status: 200,
                body: html_content,
                headers: { "Content-Type" => "text/html" }
              )
          end

          it "returns success: true" do
            result = connector.fetch
            expect(result[:success]).to be true
          end

          it "returns the HTML content" do
            result = connector.fetch
            expect(result[:html]).to eq(html_content)
          end

          it "returns the content type" do
            result = connector.fetch
            expect(result[:content_type]).to eq("text/html")
          end

          it "returns the final URL" do
            result = connector.fetch
            expect(result[:final_url]).to eq(url)
          end
        end

        context "when following redirects" do
          let(:redirect_url) { "https://www.example.com/property/123/details" }
          let(:redirect_html) { valid_html_content }

          before do
            stub_request(:get, url)
              .to_return(status: 302, headers: { "Location" => redirect_url })
            stub_request(:get, redirect_url)
              .to_return(status: 200, body: redirect_html)
          end

          it "follows the redirect" do
            result = connector.fetch
            expect(result[:success]).to be true
            expect(result[:html]).to eq(redirect_html)
          end
        end

        context "when too many redirects" do
          before do
            stub_request(:get, url)
              .to_return(status: 302, headers: { "Location" => "#{url}?r=1" })
            stub_request(:get, "#{url}?r=1")
              .to_return(status: 302, headers: { "Location" => "#{url}?r=2" })
            stub_request(:get, "#{url}?r=2")
              .to_return(status: 302, headers: { "Location" => "#{url}?r=3" })
            stub_request(:get, "#{url}?r=3")
              .to_return(status: 302, headers: { "Location" => "#{url}?r=4" })
          end

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
            expect(result[:error]).to include("Too many redirects")
          end
        end

        context "when blocked by Cloudflare" do
          let(:cloudflare_html) do
            <<~HTML
              <!DOCTYPE html>
              <html>
              <head><title>Just a moment...</title></head>
              <body>
              <h1>Checking your browser before accessing</h1>
              <p>Please wait while we verify your browser</p>
              <div id="cf-wrapper">Ray ID: abc123</div>
              </body>
              </html>
            HTML
          end

          before do
            stub_request(:get, url)
              .to_return(status: 200, body: cloudflare_html)
          end

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
          end

          it "indicates blocking in error message" do
            result = connector.fetch
            expect(result[:error]).to include("Cloudflare")
          end
        end

        context "when receiving 403 Forbidden" do
          before do
            stub_request(:get, url)
              .to_return(status: 403, body: "Forbidden")
          end

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
            expect(result[:error]).to include("Access blocked")
          end
        end

        context "when receiving 503 Service Unavailable" do
          before do
            stub_request(:get, url)
              .to_return(status: 503, body: "Service Unavailable")
          end

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
            expect(result[:error]).to include("Access blocked")
          end
        end

        context "when receiving 404 Not Found" do
          before do
            stub_request(:get, url)
              .to_return(status: 404, body: "Not Found")
          end

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
            expect(result[:error]).to include("Client error")
          end
        end

        context "when receiving 500 Server Error" do
          before do
            stub_request(:get, url)
              .to_return(status: 500, body: "Internal Server Error")
          end

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
            expect(result[:error]).to include("Server error")
          end
        end

        context "when content is too short" do
          before do
            stub_request(:get, url)
              .to_return(status: 200, body: "<html></html>")
          end

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
            expect(result[:error]).to include("Content too short")
          end
        end

        context "when connection times out" do
          before do
            stub_request(:get, url).to_timeout
          end

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
            expect(result[:error]).to include("Connection error")
          end
        end

        context "when SSL certificate error" do
          before do
            stub_request(:get, url)
              .to_raise(OpenSSL::SSL::SSLError.new("certificate verify failed"))
          end

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
            expect(result[:error]).to include("Connection error")
          end
        end

        context "when URL is invalid" do
          let(:connector) { described_class.new("not-a-valid-url") }

          it "returns an error" do
            result = connector.fetch
            expect(result[:success]).to be false
          end
        end
      end

      describe "headers" do
        before do
          stub_request(:get, url)
            .to_return(status: 200, body: "<html>" + ("x" * 2000) + "</html>")
        end

        it "sends a Chrome user agent" do
          connector.fetch

          expect(WebMock).to have_requested(:get, url)
            .with(headers: { "User-Agent" => /Chrome/ })
        end

        it "sends Accept header" do
          connector.fetch

          expect(WebMock).to have_requested(:get, url)
            .with(headers: { "Accept" => %r{text/html} })
        end

        it "sends Accept-Language header" do
          connector.fetch

          expect(WebMock).to have_requested(:get, url)
            .with(headers: { "Accept-Language" => /en/ })
        end
      end
    end
  end
end
