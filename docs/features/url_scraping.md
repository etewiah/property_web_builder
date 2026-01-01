# URL Scraping Feature

Import properties into your website by pasting a URL from another property listing site.

## Overview

The URL scraping feature allows site administrators to quickly import properties from external real estate portals (e.g., Rightmove, Zoopla, Idealista) by simply pasting the property URL. The system automatically extracts property data, images, and listing details.

## User Guide

### Accessing the Feature

Navigate to the URL import from either:
- **Properties page**: Click "Import URL" button in the header
- **Import/Export page**: Click "Import from URL" button

### Import Workflow

1. **Enter URL**: Paste the property listing URL from another website
2. **Automatic Scraping**: The system attempts to fetch and parse the page
3. **Manual Fallback**: If scraping fails (due to Cloudflare, etc.), paste the HTML source manually
4. **Review Data**: Edit extracted property details before importing
5. **Create Property**: Confirm to create the property in your website

### Manual HTML Entry

When automatic scraping is blocked:

1. Open the property page in your browser
2. Right-click and select "View Page Source" (or Ctrl+U / Cmd+Option+U)
3. Select all (Ctrl+A / Cmd+A) and copy (Ctrl+C / Cmd+C)
4. Paste the HTML into the form
5. Click "Parse HTML"

### Supported Property Portals

The system includes optimized support for:
- Rightmove (UK)
- Zoopla (UK)
- OnTheMarket (UK)
- Idealista (Spain)
- Zillow (USA)
- Redfin (USA)
- Realtor.com (USA)
- Trulia (USA)
- Daft.ie (Ireland)
- Domain (Australia)

Other websites use generic extraction that works with most property listing pages.

### Extracted Data

The system attempts to extract:
- **Property Details**: Bedrooms, bathrooms, area, property type
- **Location**: Address, city, region, postal code, country
- **Pricing**: Sale price, currency
- **Content**: Title, description
- **Images**: Property photos (up to 20)

### Import History

View previously imported properties at `/site_admin/property_url_import/history`:
- See status of past imports
- Re-review pending imports
- Access imported properties

## Technical Documentation

### Architecture

```
URL Input → HTTP Connector → Pasarela (Parser) → ScrapedProperty → Import Service → RealtyAsset + SaleListing
                ↓
         [On Failure]
                ↓
         Manual HTML Entry
```

### Components

#### ScrapedProperty Model

Stores raw scraped content and extraction status.

```ruby
Pwb::ScrapedProperty
  - source_url          # Original URL
  - source_url_normalized # For deduplication
  - source_host         # e.g., "rightmove.co.uk"
  - source_portal       # e.g., "rightmove", "generic"
  - raw_html            # Original HTML content
  - extracted_data      # Parsed property data (JSONB)
  - extracted_images    # Array of image URLs (JSONB)
  - scrape_method       # "auto" or "manual_html"
  - scrape_successful   # Boolean
  - import_status       # "pending", "previewing", "imported", "failed"
  - realty_asset_id     # FK to imported property
```

#### Scraper Connectors

Located in `app/services/pwb/scraper_connectors/`

- **Base**: Abstract interface with common headers and error classes
- **Http**: Primary connector using Net::HTTP with redirect handling and Cloudflare detection

```ruby
# Usage
connector = Pwb::ScraperConnectors::Http.new(url)
result = connector.fetch
# => { success: true, html: "...", final_url: "..." }
# => { success: false, error: "...", error_class: "..." }
```

#### Pasarelas (Data Transformers)

Located in `app/services/pwb/pasarelas/`

Named after Spanish word for "gateway" - transforms portal-specific data into standardized format.

- **Base**: Common extraction helpers (JSON-LD, Open Graph, etc.)
- **Generic**: Fallback for unknown portals using multiple extraction strategies

```ruby
# Usage
pasarela = Pwb::Pasarelas::Generic.new(scraped_property)
data = pasarela.call
# => { asset_data: {...}, listing_data: {...}, images: [...] }
```

Extraction strategies (in priority order):
1. JSON-LD structured data (Schema.org)
2. Next.js `__NEXT_DATA__` script
3. Open Graph meta tags
4. CSS selectors for common patterns

#### Services

**PropertyScraperService**: Orchestrates the scraping workflow

```ruby
service = Pwb::PropertyScraperService.new(url, website: current_website)
scraped_property = service.call

# For manual HTML
scraped_property = service.import_from_manual_html(html)
```

**PropertyImportFromScrapeService**: Creates property from scraped data

```ruby
service = Pwb::PropertyImportFromScrapeService.new(scraped_property, overrides: params)
result = service.call
# => #<Result success: true, realty_asset: #<RealtyAsset...>>
```

### Routes

```ruby
# GET  /site_admin/property_url_import          - URL input form
# POST /site_admin/property_url_import          - Attempt scrape
# POST /site_admin/property_url_import/manual_html - Process manual HTML
# GET  /site_admin/property_url_import/:id/preview - Review extracted data
# POST /site_admin/property_url_import/:id/confirm - Create property
# GET  /site_admin/property_url_import/history  - Import history
```

### Error Handling

The system handles several failure scenarios:

1. **Invalid URL**: Validates URL format before attempting scrape
2. **Connection Errors**: Network timeouts, SSL issues
3. **Cloudflare/Bot Protection**: Detects blocking patterns, offers manual fallback
4. **Content Too Short**: Validates minimum content length
5. **HTTP Errors**: 4xx/5xx responses with appropriate messages

### Multi-Tenancy

All scraped properties are scoped to the current website:
- `website_id` foreign key on `pwb_scraped_properties`
- Controller verifies ownership before preview/import
- Queries always scoped to `current_website`

### Deduplication

Same URL won't be re-scraped if already successfully processed:
- Uses `source_url_normalized` for comparison
- Returns existing `ScrapedProperty` if available and successful

## Future Enhancements

1. **Portal-specific pasarelas**: Better extraction for major portals
2. **Playwright connector**: For JavaScript-heavy sites
3. **Image downloading**: Store images in ActiveStorage instead of external URLs
4. **Bulk URL import**: Import multiple URLs at once
5. **Scheduled re-scraping**: Update prices periodically
