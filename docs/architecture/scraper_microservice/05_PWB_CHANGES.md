# 05 — Changes Needed in PropertyWebBuilder

This document details all changes needed in PropertyWebBuilder to integrate with the PWS microservice.

---

## Change 1: Create `ExternalScraperClient` Service

**Priority:** High
**Effort:** Medium

A new service that calls PWS's `/api/v2/extract` endpoint and returns data in the format `PropertyImportFromScrapeService` expects.

### File: `app/services/pwb/external_scraper_client.rb`

```ruby
module Pwb
  class ExternalScraperClient
    class Error < StandardError; end
    class UnsupportedPortalError < Error; end
    class ExtractionFailedError < Error; end
    class ConnectionError < Error; end

    Result = Struct.new(:success, :extracted_data, :extracted_images, :portal, :error, keyword_init: true)

    def initialize(url:, html: nil)
      @url = url
      @html = html
    end

    def call
      return Result.new(success: false, error: "PWS integration disabled") unless self.class.enabled?

      response = send_request
      body = response.body

      unless body.is_a?(Hash) && body["success"]
        error_msg = body.is_a?(Hash) ? body["error_message"] : "Invalid response from scraper service"
        error_code = body.is_a?(Hash) ? body["error_code"] : "unknown"

        raise UnsupportedPortalError, error_msg if error_code == "unsupported_portal"
        raise ExtractionFailedError, error_msg if error_code == "extraction_failed"
        raise Error, error_msg
      end

      data = body["data"]
      Result.new(
        success: true,
        extracted_data: {
          "asset_data" => data["asset_data"],
          "listing_data" => data["listing_data"]
        },
        extracted_images: data["images"] || [],
        portal: body["portal"]
      )
    rescue Faraday::Error => e
      raise ConnectionError, "Failed to connect to scraper service: #{e.message}"
    end

    def self.enabled?
      ENV["PWS_ENABLED"] != "false" && ENV["PWS_API_URL"].present?
    end

    def self.healthy?
      return false unless enabled?

      conn = build_connection
      response = conn.get("/api/v2/health")
      response.success? && response.body.is_a?(Hash) && response.body["status"] == "ok"
    rescue Faraday::Error
      false
    end

    def self.supported_portals
      return [] unless enabled?

      conn = build_connection
      response = conn.get("/api/v2/portals")
      return [] unless response.success?

      response.body["portals"] || []
    rescue Faraday::Error
      []
    end

    private

    def send_request
      conn = self.class.build_connection
      conn.post("/api/v2/extract") do |req|
        req.body = { url: @url, html: @html }.compact
      end
    end

    def self.build_connection
      Faraday.new(url: ENV.fetch("PWS_API_URL")) do |f|
        f.request :json
        f.response :json
        f.request :timeout,
                  open: 5,
                  read: Integer(ENV.fetch("PWS_TIMEOUT", "15"))
        f.headers["X-Api-Key"] = ENV["PWS_API_KEY"] if ENV["PWS_API_KEY"].present?
        f.adapter Faraday.default_adapter
      end
    end
  end
end
```

---

## Change 2: Modify `PropertyScraperService` to Use External Extractor

**Priority:** High
**Effort:** Medium

Update the orchestrator to try PWS first, fall back to local Pasarelas.

### Current flow:
```
fetch HTML → select Pasarela → extract locally
```

### New flow:
```
fetch HTML → try ExternalScraperClient → on failure → fall back to local Pasarela
```

### Modifications to `app/services/pwb/property_scraper_service.rb`:

Add a new method and modify the extraction step:

```ruby
# After fetching raw HTML, replace the pasarela call with:

def extract_data(scraped_property)
  if ExternalScraperClient.enabled?
    begin
      result = ExternalScraperClient.new(
        url: scraped_property.source_url,
        html: scraped_property.raw_html
      ).call

      if result.success
        scraped_property.update!(
          extracted_data: result.extracted_data,
          extracted_images: result.extracted_images,
          extraction_source: "external"
        )
        return scraped_property
      end
    rescue ExternalScraperClient::UnsupportedPortalError => e
      Rails.logger.info("[Scraper] PWS does not support #{scraped_property.source_host}, falling back to local: #{e.message}")
    rescue ExternalScraperClient::Error => e
      Rails.logger.warn("[Scraper] PWS extraction failed, falling back to local: #{e.message}")
    end
  end

  # Fallback to local pasarela
  extract_with_pasarela(scraped_property)
end

def extract_with_pasarela(scraped_property)
  pasarela = select_pasarela
  pasarela.call
  scraped_property.reload
  scraped_property.update!(extraction_source: "local") if scraped_property.extracted_data.present?
  scraped_property
end
```

The key principle: **fetch HTML locally (PWB controls this), extract remotely (PWS handles parsing), fall back locally (Pasarelas remain as safety net)**.

---

## Change 3: Add `extraction_source` Column to `ScrapedProperty`

**Priority:** Medium
**Effort:** Small

Track which extraction method was used for observability.

### Migration

```ruby
class AddExtractionSourceToScrapedProperties < ActiveRecord::Migration[7.2]
  def change
    add_column :pwb_scraped_properties, :extraction_source, :string
    # Values: "external" (PWS), "local" (Pasarela), "manual" (user pasted HTML)
  end
end
```

---

## Change 4: Update Batch Import to Support External Extraction

**Priority:** Medium
**Effort:** Small

`BatchUrlImportService` delegates to `PropertyScraperService`, which will automatically use the new external extraction path. No changes needed to `BatchUrlImportService` itself — the change propagates through the orchestrator.

However, consider adding a check for PWS health before starting a large batch:

```ruby
# In BatchUrlImportService#call, before processing:
if Pwb::ExternalScraperClient.enabled? && !Pwb::ExternalScraperClient.healthy?
  Rails.logger.warn("[BatchImport] PWS is unreachable, will use local extraction only")
end
```

---

## Change 5: Update Import Controller to Show Extraction Source

**Priority:** Low
**Effort:** Small

Show users whether data came from the external service or local parser in the preview page.

### In `app/controllers/site_admin/property_url_import_controller.rb`:

The preview action already renders `@scraped_property`, which will now include `extraction_source`. Update the preview template to display this info.

### In the preview view:

```erb
<% if @scraped_property.extraction_source == "external" %>
  <span class="text-sm text-green-600">Extracted via PropertyWebScraper</span>
<% elsif @scraped_property.extraction_source == "local" %>
  <span class="text-sm text-blue-600">Extracted locally</span>
<% end %>
```

---

## Change 6: Add Supported Portals Display

**Priority:** Low
**Effort:** Small

Show users which portals are supported (from PWS) in the URL import form.

### In the `new` action:

```ruby
def new
  @supported_portals = Pwb::ExternalScraperClient.supported_portals if Pwb::ExternalScraperClient.enabled?
end
```

### In the view:

```erb
<% if @supported_portals&.any? %>
  <details class="mt-4">
    <summary class="text-sm text-gray-500 cursor-pointer">Supported property portals</summary>
    <ul class="mt-2 text-sm">
      <% @supported_portals.each do |portal| %>
        <li><%= portal["host"] %> (<%= portal["country"] %>)</li>
      <% end %>
    </ul>
  </details>
<% end %>
```

---

## Change 7: Configuration

**Priority:** High
**Effort:** Small

Add environment variables to the deployment configuration.

### Required ENV vars:

```bash
# .env or deployment config
PWS_API_URL=https://scraper.yourdomain.com   # Base URL of PWS instance
PWS_API_KEY=your-secure-api-key              # Must match PWS's PROPERTY_SCRAPER_API_KEY
PWS_TIMEOUT=15                                # Optional, default 15 seconds
PWS_ENABLED=true                              # Optional, default true if PWS_API_URL is set
```

### Credential-based alternative:

```ruby
# config/credentials.yml.enc
pws:
  api_url: https://scraper.yourdomain.com
  api_key: your-secure-api-key
  timeout: 15
```

Then in the client:

```ruby
def self.config
  @config ||= Rails.application.credentials.pws || {}
end
```

---

## Change 8: Add Tests

**Priority:** High
**Effort:** Medium

### Tests for `ExternalScraperClient`

```ruby
# spec/services/pwb/external_scraper_client_spec.rb

RSpec.describe Pwb::ExternalScraperClient do
  describe "#call" do
    context "when PWS returns success" do
      before do
        stub_request(:post, "#{ENV['PWS_API_URL']}/api/v2/extract")
          .to_return(status: 200, body: {
            success: true,
            portal: "rightmove",
            data: {
              asset_data: { city: "London", count_bedrooms: 3 },
              listing_data: { title: "Nice house", price_sale_current: 450000 },
              images: ["https://example.com/photo1.jpg"]
            }
          }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns a successful result with extracted data" do
        result = described_class.new(url: "https://www.rightmove.co.uk/properties/123", html: "<html>...</html>").call
        expect(result.success).to be true
        expect(result.extracted_data["asset_data"]["city"]).to eq("London")
        expect(result.extracted_images).to eq(["https://example.com/photo1.jpg"])
      end
    end

    context "when PWS returns unsupported portal" do
      before do
        stub_request(:post, "#{ENV['PWS_API_URL']}/api/v2/extract")
          .to_return(status: 422, body: {
            success: false, error_code: "unsupported_portal",
            error_message: "Not supported"
          }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "raises UnsupportedPortalError" do
        client = described_class.new(url: "https://unknown.com/123", html: "<html/>")
        expect { client.call }.to raise_error(described_class::UnsupportedPortalError)
      end
    end

    context "when PWS is unreachable" do
      before do
        stub_request(:post, "#{ENV['PWS_API_URL']}/api/v2/extract")
          .to_timeout
      end

      it "raises ConnectionError" do
        client = described_class.new(url: "https://www.rightmove.co.uk/123", html: "<html/>")
        expect { client.call }.to raise_error(described_class::ConnectionError)
      end
    end
  end
end
```

### Integration test for fallback behavior

```ruby
# spec/services/pwb/property_scraper_service_external_spec.rb

RSpec.describe "PropertyScraperService with external extraction" do
  context "when PWS is available and supports the portal" do
    it "uses external extraction" do
      # stub PWS success
      # verify scraped_property.extraction_source == "external"
    end
  end

  context "when PWS does not support the portal" do
    it "falls back to local pasarela" do
      # stub PWS 422 unsupported_portal
      # verify scraped_property.extraction_source == "local"
    end
  end

  context "when PWS is down" do
    it "falls back to local pasarela" do
      # stub PWS timeout
      # verify scraped_property.extraction_source == "local"
    end
  end
end
```

---

## Change Summary

| # | Change | Priority | Effort | Files Affected |
|---|--------|----------|--------|----------------|
| 1 | `ExternalScraperClient` service | High | Medium | New: `app/services/pwb/external_scraper_client.rb` |
| 2 | Modify `PropertyScraperService` | High | Medium | Edit: `app/services/pwb/property_scraper_service.rb` |
| 3 | `extraction_source` column | Medium | Small | New migration |
| 4 | Batch import health check | Medium | Small | Edit: `app/services/pwb/batch_url_import_service.rb` |
| 5 | Show extraction source in UI | Low | Small | Edit: preview view template |
| 6 | Supported portals display | Low | Small | Edit: controller + view |
| 7 | Configuration (ENV vars) | High | Small | `.env` / credentials |
| 8 | Tests | High | Medium | New spec files |
