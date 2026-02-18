# 04 — Recommended Changes to PropertyWebScraper

This document details changes needed in the PropertyWebScraper project to support clean integration with PropertyWebBuilder.

---

## Change 1: Add `/api/v2/extract` Endpoint

**Priority:** High
**Effort:** Medium

### Rationale

The existing `/api/v1/listings` endpoint returns data in the `PwbListing` format, which requires transformation in PWB. A new v2 endpoint should return data pre-structured in PWB's `extracted_data` format (`asset_data` + `listing_data` + `images`).

### Implementation (Rails Engine)

Create `app/controllers/property_web_scraper/api/v2/extractions_controller.rb`:

```ruby
module PropertyWebScraper
  module Api
    module V2
      class ExtractionsController < ApplicationController
        before_action :authenticate_api_key!

        def create
          url = params[:url]&.strip
          html = extract_html_input

          return render_error("invalid_request", "url parameter is required", 400) if url.blank?

          validation = UrlValidator.call(url)
          unless validation.valid?
            return render_error(
              validation.error_code.to_s,
              validation.error_message,
              422,
              supported_portals: ImportHost.all.map(&:host)
            )
          end

          result = HtmlExtractor.call(
            html: html || fetch_html(url),
            source_url: url,
            scraper_mapping_name: validation.import_host.scraper_name
          )

          unless result[:success] && result[:properties]&.any?
            return render_error("extraction_failed", "Failed to extract data from HTML", 422)
          end

          raw = result[:properties].first
          sanitized = ScrapedContentSanitizer.call(raw)

          render json: {
            success: true,
            portal: validation.import_host.slug,
            extraction_rate: calculate_extraction_rate(sanitized),
            data: transform_to_pwb_format(sanitized, url)
          }
        end

        private

        def transform_to_pwb_format(props, source_url)
          {
            asset_data: {
              reference: props["reference"],
              street_address: props["street_address"],
              street_number: props["street_number"],
              street_name: props["street_name"],
              city: props["city"],
              region: props["region"].presence || props["province"],
              postal_code: props["postal_code"],
              country: props["country"],
              latitude: props["latitude"]&.to_f,
              longitude: props["longitude"]&.to_f,
              prop_type_key: normalize_property_type(props["property_type"]),
              count_bedrooms: props["count_bedrooms"]&.to_i || 0,
              count_bathrooms: props["count_bathrooms"]&.to_f || 0,
              count_garages: props["count_garages"]&.to_i || 0,
              constructed_area: props["constructed_area"]&.to_f || 0,
              plot_area: props["plot_area"]&.to_f || 0,
              year_construction: props["year_construction"]&.to_i || 0,
              energy_rating: props["energy_rating"],
              energy_performance: props["energy_performance"]
            },
            listing_data: {
              title: props["title"],
              description: props["description"],
              price_sale_current: props["for_sale"] ? props["price_float"]&.to_f : 0,
              price_rental_monthly: props["for_rent_long_term"] ? props["price_float"]&.to_f : 0,
              currency: props["currency"] || "EUR",
              listing_type: detect_listing_type(props, source_url),
              furnished: props["furnished"] || false,
              for_sale: props["for_sale"] || false,
              for_rent_long_term: props["for_rent_long_term"] || false,
              for_rent_short_term: props["for_rent_short_term"] || false,
              features: props["features"] || []
            },
            images: props["image_urls"] || []
          }
        end

        def detect_listing_type(props, url)
          return "rental" if props["for_rent_long_term"] || props["for_rent_short_term"]
          return "sale" if props["for_sale"]
          # Infer from URL patterns
          rental_keywords = %w[rent to-rent alquiler location affitto]
          return "rental" if rental_keywords.any? { |kw| url.downcase.include?(kw) }
          "sale"
        end

        def normalize_property_type(raw_type)
          # See mapping table in 02_DATA_MAPPING.md
          return "other" if raw_type.blank?
          PropertyTypeNormalizer.call(raw_type)
        end

        def calculate_extraction_rate(props)
          critical_fields = %w[title price_float count_bedrooms city country]
          populated = critical_fields.count { |f| props[f].present? }
          (populated.to_f / critical_fields.size).round(2)
        end

        def render_error(code, message, status, extra = {})
          render json: { success: false, error_code: code, error_message: message }.merge(extra),
                 status: status
        end
      end
    end
  end
end
```

### Routes Addition

```ruby
# config/routes.rb
namespace :api do
  namespace :v2 do
    post '/extract' => 'extractions#create'
    get  '/portals' => 'portals#index'
    get  '/health'  => 'health#show'
  end
end
```

---

## Change 2: Add Property Type Normalizer

**Priority:** High
**Effort:** Small

PWB requires a standardized `prop_type_key`. PWS extracts raw text like "Detached", "Flat", "Piso". A normalizer service bridges this gap.

### Implementation

Create `app/services/property_web_scraper/property_type_normalizer.rb`:

```ruby
module PropertyWebScraper
  class PropertyTypeNormalizer
    MAPPING = {
      # Apartments
      /\b(flat|apartment|piso|appartement|appartamento|wohnung|apt)\b/i => "apartment",
      # Houses
      /\b(house|detached|semi.?detached|terraced|bungalow|cottage|casa|maison|haus|townhouse|end.?of.?terrace|mid.?terrace|link.?detached)\b/i => "house",
      # Villas
      /\b(villa|chalet|finca)\b/i => "villa",
      # Studios
      /\b(studio|estudio|monolocale)\b/i => "studio",
      # Land
      /\b(land|plot|terreno|terrain|grundstuck|solar)\b/i => "land",
      # Commercial
      /\b(commercial|shop|retail|local|negocio|magasin)\b/i => "commercial",
      # Office
      /\b(office|oficina|bureau|ufficio|buro)\b/i => "office",
      # Garage
      /\b(garage|parking|garaje|box)\b/i => "garage",
      # Storage
      /\b(storage|trastero|magazzino|lager)\b/i => "storage"
    }.freeze

    def self.call(raw_type)
      return "other" if raw_type.blank?

      MAPPING.each do |pattern, key|
        return key if raw_type.match?(pattern)
      end

      "other"
    end
  end
end
```

---

## Change 3: Add `prop_type_key` to Scraper Mappings

**Priority:** Medium
**Effort:** Medium

Add a `property_type` text field extraction to scraper mappings that don't already have it. This gives the normalizer raw input to work with.

### Mappings to Update

Most mappings already extract a property type implicitly (from the title or a dedicated field). For mappings that don't, add:

```json
"textFields": {
  "property_type": {
    "cssLocator": ".property-type",
    "fallbacks": [
      { "cssLocator": "h1", "splitTextCharacter": " ", "splitTextArrayId": 0 }
    ]
  }
}
```

Check and update these mappings:
- `uk_rightmove.json` — extract from `propertyData.propertySubType` (in PAGE_MODEL)
- `uk_zoopla.json` — extract from listing type metadata
- `es_idealista.json` — extract from `typology` or breadcrumb
- `ie_daft.json` — extract from property type badge
- Other mappings — audit each for property type availability

---

## Change 4: Add `/api/v2/portals` Endpoint

**Priority:** Low
**Effort:** Small

Let PWB query which portals are supported so the UI can display this information.

```ruby
module PropertyWebScraper
  module Api
    module V2
      class PortalsController < ApplicationController
        before_action :authenticate_api_key!

        def index
          portals = ImportHost.all.map do |host|
            {
              name: host.slug,
              host: host.host,
              country: host.details&.dig("country") || infer_country(host.slug),
              example_urls: host.example_urls
            }
          end

          render json: { success: true, portals: portals }
        end

        private

        def infer_country(slug)
          prefix = slug.split("_").first
          { "uk" => "UK", "us" => "USA", "es" => "Spain", "ie" => "Ireland",
            "de" => "Germany", "fr" => "France", "au" => "Australia",
            "pt" => "Portugal", "in" => "India" }[prefix] || "Unknown"
        end
      end
    end
  end
end
```

---

## Change 5: Add `/api/v2/health` Endpoint

**Priority:** Low
**Effort:** Small

```ruby
module PropertyWebScraper
  module Api
    module V2
      class HealthController < ApplicationController
        # No auth required for health checks
        def show
          render json: {
            status: "ok",
            scrapers_loaded: ScraperMapping.count,
            version: PropertyWebScraper::VERSION
          }
        end
      end
    end
  end
end
```

---

## Change 6: Add `country` to ImportHost Details

**Priority:** Low
**Effort:** Small

Update `db/seeds/import_hosts.rb` to include country in each host's details hash:

```ruby
{ slug: 'uk_rightmove', host: 'www.rightmove.co.uk', scraper_name: 'uk_rightmove',
  details: { country: "UK" } }
```

This makes the `/api/v2/portals` endpoint more informative.

---

## Change 7: Ensure HTML-Only Mode Works Without Firestore

**Priority:** Medium
**Effort:** Small

When PWB sends HTML + URL to the v2 endpoint, the extraction should be purely functional — no Firestore reads or writes. The v2 controller should call `HtmlExtractor.call()` directly without going through `ListingRetriever` or `Scraper` (which create Firestore records).

This is already achievable since `HtmlExtractor` is a pure function. The v2 controller implementation above correctly bypasses persistence.

---

## Change Summary

| # | Change | Priority | Effort | PWS Component |
|---|--------|----------|--------|---------------|
| 1 | `/api/v2/extract` endpoint | High | Medium | Controller |
| 2 | `PropertyTypeNormalizer` service | High | Small | Service |
| 3 | Add `property_type` to scraper mappings | Medium | Medium | Config JSON |
| 4 | `/api/v2/portals` endpoint | Low | Small | Controller |
| 5 | `/api/v2/health` endpoint | Low | Small | Controller |
| 6 | Country in ImportHost details | Low | Small | Seed data |
| 7 | Stateless extraction mode | Medium | Small | Already supported |
