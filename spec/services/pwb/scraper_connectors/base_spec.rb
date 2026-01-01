# frozen_string_literal: true

require "rails_helper"

module Pwb
  module ScraperConnectors
    RSpec.describe Base do
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

        it "stores options" do
          conn = described_class.new(url, timeout: 60)
          expect(conn.options).to eq({ timeout: 60 })
        end

        it "defaults options to empty hash" do
          expect(connector.options).to eq({})
        end
      end

      describe "#fetch" do
        it "raises NotImplementedError" do
          expect { connector.fetch }.to raise_error(NotImplementedError)
        end
      end

      describe "error classes" do
        describe ScrapeError do
          it "is a StandardError" do
            expect(ScrapeError.new("test")).to be_a(StandardError)
          end
        end

        describe BlockedError do
          it "is a ScrapeError" do
            expect(BlockedError.new("test")).to be_a(ScrapeError)
          end
        end

        describe InvalidContentError do
          it "is a ScrapeError" do
            expect(InvalidContentError.new("test")).to be_a(ScrapeError)
          end
        end

        describe HttpError do
          it "is a ScrapeError" do
            expect(HttpError.new("test")).to be_a(ScrapeError)
          end

          it "stores status code" do
            error = HttpError.new("Not Found", 404)
            expect(error.status_code).to eq(404)
          end

          it "allows nil status code" do
            error = HttpError.new("Unknown error")
            expect(error.status_code).to be_nil
          end
        end
      end
    end
  end
end
