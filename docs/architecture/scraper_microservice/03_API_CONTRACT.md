# 03 — API Contract

## Current PWS Endpoints (Existing)

PWS currently exposes two relevant endpoints:

### 1. `GET/POST /api/v1/listings` (Rails Engine)

**Auth:** `X-Api-Key` header or `api_key` query param

**Request:**
```
POST /api/v1/listings
X-Api-Key: <key>
Content-Type: multipart/form-data

url=https://www.rightmove.co.uk/properties/123456
html=<optional raw HTML string>
html_file=<optional file upload>
```

**Response (success):**
```json
{
  "success": true,
  "retry_duration": 0,
  "urls_remaining": 0,
  "listings": [
    {
      "reference": "123456",
      "title": "3 bedroom semi-detached house for sale",
      "description": "A beautiful property...",
      "count_bedrooms": 3,
      "count_bathrooms": 2,
      "count_toilets": 0,
      "count_garages": 1,
      "constructed_area": 120.0,
      "plot_area": 0.0,
      "area_unit": "sqft",
      "currency": "GBP",
      "street_number": "",
      "street_name": "",
      "street_address": "Oak Lane, London",
      "postal_code": "SW1A 1AA",
      "city": "London",
      "province": "Greater London",
      "region": "",
      "country": "UK",
      "longitude": -0.1278,
      "latitude": 51.5074,
      "for_sale": true,
      "for_rent_long_term": false,
      "for_rent_short_term": false,
      "features": ["Garden", "Parking", "Central Heating"],
      "property_photos": [
        { "url": "https://media.rightmove.co.uk/photo1.jpg" },
        { "url": "https://media.rightmove.co.uk/photo2.jpg" }
      ],
      "price_sale_current": 450000.0,
      "price_rental_monthly_current": 0.0,
      "locale_code": "en"
    }
  ]
}
```

**Response (error):**
```json
{
  "success": false,
  "error_message": "Sorry, the url provided is currently not supported"
}
```

### 2. `GET/POST /retriever/as_json` (Rails Engine)

Returns raw `Listing` JSON (not PwbListing format). Less suitable for PWB integration but useful for debugging.

### 3. Astro App Endpoints

The Astro app has admin/API endpoints but no direct equivalent of `/api/v1/listings` designed for external consumption yet. See PWS Changes document for recommendations.

---

## Recommended New PWS Endpoint

### `POST /api/v2/extract`

A new, clean endpoint purpose-built for PWB integration. Returns data already structured as `asset_data` + `listing_data` + `images`, eliminating the need for PWB-side transformation.

**Why a new endpoint instead of using v1:**
1. The v1 response format requires transformation in PWB (field renames, nested restructuring)
2. v1 wraps response in `listings[]` array (always single element — misleading)
3. v1 includes PWS-internal fields (`retry_duration`, `urls_remaining`) that PWB doesn't need
4. v1 lacks `prop_type_key` normalization
5. A v2 endpoint can return data exactly matching PWB's `extracted_data` schema

**Request:**
```
POST /api/v2/extract
X-Api-Key: <key>
Content-Type: application/json

{
  "url": "https://www.rightmove.co.uk/properties/123456",
  "html": "<html>...</html>"
}
```

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `url` | Yes | string | Property listing URL (used for portal detection and relative URL resolution) |
| `html` | No | string | Pre-rendered HTML. If omitted, PWS may attempt to fetch (not recommended) |

**Response (success):**
```json
{
  "success": true,
  "portal": "rightmove",
  "extraction_rate": 0.85,
  "data": {
    "asset_data": {
      "reference": "123456",
      "street_address": "Oak Lane, London",
      "street_number": "",
      "street_name": "Oak Lane",
      "city": "London",
      "region": "Greater London",
      "postal_code": "SW1A 1AA",
      "country": "UK",
      "latitude": 51.5074,
      "longitude": -0.1278,
      "prop_type_key": "house",
      "count_bedrooms": 3,
      "count_bathrooms": 2,
      "count_garages": 1,
      "constructed_area": 120.0,
      "plot_area": 0.0,
      "year_construction": 0,
      "energy_rating": null,
      "energy_performance": null
    },
    "listing_data": {
      "title": "3 bedroom semi-detached house for sale",
      "description": "A beautiful property...",
      "price_sale_current": 450000.0,
      "price_rental_monthly": 0.0,
      "currency": "GBP",
      "listing_type": "sale",
      "furnished": false,
      "for_sale": true,
      "for_rent_long_term": false,
      "for_rent_short_term": false,
      "features": ["Garden", "Parking", "Central Heating"]
    },
    "images": [
      "https://media.rightmove.co.uk/photo1.jpg",
      "https://media.rightmove.co.uk/photo2.jpg"
    ]
  }
}
```

**Response (unsupported portal):**
```json
{
  "success": false,
  "error_code": "unsupported_portal",
  "error_message": "No scraper mapping found for host: www.example.com",
  "supported_portals": ["rightmove.co.uk", "zoopla.co.uk", "idealista.com", "..."]
}
```

**Response (extraction failure):**
```json
{
  "success": false,
  "error_code": "extraction_failed",
  "error_message": "Failed to extract data: no fields matched"
}
```

**Response (invalid input):**
```json
{
  "success": false,
  "error_code": "invalid_request",
  "error_message": "url parameter is required"
}
```

### `GET /api/v2/portals`

Returns the list of supported portals so PWB can show the user which sites are supported.

**Request:**
```
GET /api/v2/portals
X-Api-Key: <key>
```

**Response:**
```json
{
  "success": true,
  "portals": [
    {
      "name": "uk_rightmove",
      "host": "www.rightmove.co.uk",
      "country": "UK",
      "example_urls": [
        "https://www.rightmove.co.uk/properties/123456"
      ]
    },
    {
      "name": "es_idealista",
      "host": "www.idealista.com",
      "country": "Spain",
      "example_urls": [
        "https://www.idealista.com/inmueble/12345678/"
      ]
    }
  ]
}
```

### `GET /api/v2/health`

Simple health check for PWB to verify PWS is reachable.

**Request:**
```
GET /api/v2/health
```

**Response:**
```json
{
  "status": "ok",
  "scrapers_loaded": 18,
  "version": "2.0.0"
}
```

No auth required.

---

## Error Codes Reference

| Code | HTTP Status | Meaning | PWB Action |
|------|-------------|---------|------------|
| `unsupported_portal` | 422 | Host not in portal registry | Fall back to local Pasarela |
| `extraction_failed` | 422 | Mapping matched but extraction yielded no data | Fall back to local Pasarela |
| `invalid_request` | 400 | Missing/malformed parameters | Show error to user |
| `unauthorized` | 401 | Invalid or missing API key | Log error, don't retry |
| `rate_limited` | 429 | Too many requests | Retry after `Retry-After` header |
| `server_error` | 500 | Internal PWS error | Fall back to local Pasarela |

## HTTP Client Configuration (PWB Side)

```ruby
# Recommended Faraday configuration
connection = Faraday.new(url: ENV["PWS_API_URL"]) do |f|
  f.request :json
  f.response :json
  f.request :timeout, open: 5, read: Integer(ENV.fetch("PWS_TIMEOUT", 15))
  f.request :retry, max: 1, interval: 0.5, exceptions: [Faraday::TimeoutError]
  f.adapter Faraday.default_adapter
end
```
