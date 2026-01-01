# URL Scraping Feature - Implementation Plan

## Overview

Add functionality to site_admin that allows users to create a new property by pasting a URL from another property website. The system attempts to scrape the data automatically, and if scraping fails (due to Cloudflare, bot detection, etc.), presents a fallback form for manual HTML entry.

## User Flow

```
1. User clicks "Import URL" in site_admin (Properties page or Import/Export page)
2. User pastes property URL (e.g., from Rightmove, Zoopla, Idealista)
3. System attempts HTTP scrape
4. SUCCESS: Show preview of extracted data for review/edit
5. FAILURE (Cloudflare, etc.): Show form to paste raw HTML manually
6. User reviews extracted data, makes edits if needed
7. User confirms import
8. Property created (RealtyAsset + SaleListing + PropPhotos)
```

## Architecture Components

### 1. Database Model: `Pwb::ScrapedProperty`

Stores raw scraped content and extraction status for audit trail and reprocessing.

**Table: `pwb_scraped_properties`**
- `id` (uuid) - Primary key
- `website_id` (bigint) - FK to pwb_websites
- `realty_asset_id` (uuid, nullable) - FK to pwb_realty_assets (set after import)
- `source_url` (string) - Original URL
- `source_url_normalized` (string) - For deduplication
- `source_host` (string) - e.g., "rightmove.co.uk"
- `source_portal` (string) - e.g., "rightmove", "zoopla", "generic"
- `raw_html` (text) - Original HTML content
- `script_json` (text) - JSON extracted from script tags
- `extracted_data` (jsonb) - Parsed property data
- `extracted_images` (jsonb) - Array of image URLs
- `scrape_method` (string) - "auto" or "manual_html"
- `connector_used` (string) - "http" or "playwright"
- `scrape_successful` (boolean)
- `scrape_error_message` (string)
- `import_status` (string) - "pending", "previewing", "imported", "failed"
- `imported_at` (datetime)
- `timestamps`

### 2. Scraper Connectors

**Location:** `app/services/pwb/scraper_connectors/`

#### Base (`base.rb`)
- Abstract interface for connectors
- Common error classes: `ScrapeError`, `BlockedError`, `InvalidContentError`, `HttpError`
- Default HTTP headers (User-Agent, Accept, etc.)

#### HTTP (`http.rb`)
- Primary connector using Net::HTTP
- Handles redirects (up to 3)
- Detects Cloudflare blocking patterns
- Validates content length (min 1000 bytes)
- 30 second timeout

### 3. Pasarelas (Data Transformers)

**Location:** `app/services/pwb/pasarelas/`

Named after Spanish word for "gateway" - transforms portal-specific data into standardized format.

#### Base (`base.rb`)
- Common extraction helpers:
  - `extract_json_ld` - Schema.org structured data
  - `extract_next_data` - Next.js page data
  - `extract_og_tags` - Open Graph meta tags
  - `clean_price` - Parse price strings
  - `extract_all_images` - Find all images in page

#### Generic (`generic.rb`)
- Fallback for unknown portals
- Uses multiple extraction strategies:
  - JSON-LD structured data
  - Next.js `__NEXT_DATA__` script
  - Open Graph meta tags
  - Common CSS selectors for price, bedrooms, etc.
- Extracts: title, description, address, bedrooms, bathrooms, price, images

### 4. Orchestration Services

#### PropertyScraperService (`property_scraper_service.rb`)
- Coordinates scraping workflow
- Creates/finds ScrapedProperty record
- Selects appropriate connector
- Dispatches to correct pasarela based on portal
- Handles both auto and manual HTML flows

#### PropertyImportFromScrapeService (`property_import_from_scrape_service.rb`)
- Creates RealtyAsset from extracted data
- Creates SaleListing with price, title, description
- Imports images as PropPhoto records (external URLs)
- Updates ScrapedProperty with import status

### 5. Controller

**`SiteAdmin::PropertyUrlImportController`**

Actions:
- `new` - Show URL input form
- `create` - Attempt scrape, redirect to preview or show manual form
- `manual_html` - Process manually pasted HTML
- `preview` - Show extracted data for review
- `confirm_import` - Create the property
- `history` - Show past imports

### 6. Routes

```ruby
scope :property_url_import, controller: 'property_url_import', as: 'property_url_import' do
  get '/', action: :new
  post '/', action: :create
  post :manual_html, action: :manual_html
  get ':id/preview', action: :preview, as: :preview
  post ':id/confirm', action: :confirm_import, as: :confirm
  get :history, action: :history
end
```

### 7. Views

- `new.html.erb` - URL input form with supported sites info
- `manual_html_form.html.erb` - HTML paste form with instructions
- `preview.html.erb` - Review/edit extracted data before import
- `history.html.erb` - List of past imports

## Key Design Decisions

### Adapted from pwb-pro-be

| Aspect | pwb-pro-be | PropertyWebBuilder |
|--------|------------|-------------------|
| Scope | 20+ portals, production scraping | Simple import tool |
| Models | ScrapeItem + RealtyScrapedItem | Single ScrapedProperty |
| Connectors | Playwright primary | HTTP primary, manual fallback |
| Pasarelas | Portal-specific | Generic + portal-specific (future) |
| Storage | Separate content columns | Single raw_html + extracted_data |
| Flags | Bitmask for portals | Simple source_portal string |

### Why HTTP-first with Manual Fallback

1. **Simpler deployment** - No browser dependencies
2. **Works for most sites** - Many property portals don't require JS
3. **User empowerment** - Manual HTML entry as escape hatch
4. **Lower resource usage** - No Playwright/Chromium overhead

## Files Created

```
db/migrate/20260101125759_create_pwb_scraped_properties.rb
app/models/pwb/scraped_property.rb
app/services/pwb/scraper_connectors/base.rb
app/services/pwb/scraper_connectors/http.rb
app/services/pwb/pasarelas/base.rb
app/services/pwb/pasarelas/generic.rb
app/services/pwb/property_scraper_service.rb
app/services/pwb/property_import_from_scrape_service.rb
app/controllers/site_admin/property_url_import_controller.rb
app/views/site_admin/property_url_import/new.html.erb
app/views/site_admin/property_url_import/manual_html_form.html.erb
app/views/site_admin/property_url_import/preview.html.erb
app/views/site_admin/property_url_import/history.html.erb
config/routes.rb (updated)
app/views/site_admin/props/index.html.erb (updated - added Import URL button)
app/views/site_admin/property_import_export/index.html.erb (updated - added link)
```

## Future Enhancements

1. **Portal-specific pasarelas** - Copy from pwb-pro-be for better extraction:
   - `rightmove.rb` - Parse JSON from script tags
   - `zoopla.rb` - Handle Next.js data
   - `idealista.rb` - Parse Spanish portal format

2. **Playwright connector** - For JS-heavy sites that require browser rendering

3. **Image downloading** - Download images to ActiveStorage instead of external URLs

4. **Bulk URL import** - Import multiple URLs at once

5. **Scheduled re-scraping** - Update prices periodically
