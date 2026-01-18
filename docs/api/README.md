# Public API Documentation

PropertyWebBuilder provides a RESTful JSON API for headless frontend clients (Astro, React, etc.).

## Base URL

All API endpoints are relative to the tenant subdomain:

```
https://{tenant}.propertywebbuilder.com/api_public/v1/
```

For local development:
```
http://localhost:3000/api_public/v1/
```

## Locale-Prefixed Paths (Preferred)

For better CDN caching, locale can be placed in the URL path:

```
https://{tenant}.propertywebbuilder.com/api_public/v1/en/properties
```

The legacy `?locale=` query parameter still works but is deprecated.

## OpenAPI Specification

The complete API specification is available at:
- **File**: `docs/api/openapi.yaml`
- **Format**: OpenAPI 3.1

You can view the spec interactively using:
- [Swagger Editor](https://editor.swagger.io/) - Paste the YAML content
- [Redoc](https://redocly.github.io/redoc/) - Host locally

## Endpoints

### Theme Configuration

#### `GET /theme`

Returns complete theme data including colors, fonts, and CSS variables.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `locale` | string | Locale code (e.g., "en", "es") |
| `palette_id` | string | Override palette for preview |

**Response:**
```json
{
  "theme": {
    "name": "brisbane",
    "palette_id": "ocean_blue",
    "colors": {
      "primary_color": "#3B82F6",
      "secondary_color": "#10B981"
    },
    "fonts": {
      "heading": "Playfair Display",
      "body": "Inter"
    },
    "dark_mode": {
      "enabled": true,
      "setting": "auto"
    },
    "css_variables": ":root { --pwb-primary-color: #3B82F6; ... }"
  }
}
```

---

### Client Configuration

#### `GET /client-config`

Returns configuration for client-rendered (Astro) sites.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `include` | string | Comma-separated includes: `links`, `site_details`, `translations`, `homepage`, `testimonials`, `featured_properties` |
| `locale` | string | Locale for translations (if not using locale-prefixed path) |
| `testimonials_limit` | integer | Max testimonials when `include=testimonials` |
| `properties_per_group` | integer | Max properties per group when `include=featured_properties` |

**Response:**
```json
{
  "data": {
    "rendering_mode": "client",
    "theme": {
      "name": "brisbane",
      "friendly_name": "Brisbane"
    },
    "config": { /* theme config */ },
    "css_variables": { /* CSS vars as object */ },
    "website": {
      "id": 1,
      "subdomain": "demo",
      "company_display_name": "Demo Agency",
      "default_locale": "en",
      "supported_locales": ["en", "es"]
    }
  }
}
```

**Error (200):**
```json
{
  "data": { ... },
  "error": {
    "message": "Client rendering not enabled for this website",
    "rendering_mode": "rails"
  }
}
```

---

### Site Details

#### `GET /site-details`

Returns website metadata, locales, and analytics configuration.

**Response:**
```json
{
  "id": 1,
  "company_display_name": "Demo Agency",
  "default_client_locale": "en",
  "supported_locales": ["en", "es"],
  "currency": "EUR",
  "analytics": {
    "ga4_id": "G-XXXXXXXXXX",
    "gtm_id": "GTM-XXXXXXX",
    "posthog_key": "phc_xxxxx"
  }
}
```

---

### Properties

#### `GET /properties`

Search and filter property listings with pagination.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `locale` | string | "en" | Locale for translations |
| `sale_or_rental` | string | "sale" | "sale" or "rental" |
| `property_type` | string | - | Property type filter |
| `bedrooms_from` | integer | - | Minimum bedrooms |
| `bathrooms_from` | integer | - | Minimum bathrooms |
| `for_sale_price_from` | integer | - | Min sale price (cents) |
| `for_sale_price_till` | integer | - | Max sale price (cents) |
| `highlighted` | boolean | - | Featured properties only |
| `featured` | boolean | - | Featured properties only (alias of `highlighted`) |
| `sort_by` | string | - | "price-asc", "price-desc", "newest" |
| `page` | integer | 1 | Page number |
| `per_page` | integer | 12 | Results per page |
| `group_by` | string | - | Use `sale_or_rental` to group results |
| `per_group` | integer | 3 | Results per group when using `group_by` |

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "slug": "luxury-villa",
      "title": "Luxury Villa with Pool",
      "price_sale_current_cents": 50000000,
      "formatted_price": "€500,000",
      "count_bedrooms": 4,
      "count_bathrooms": 3,
      "primary_image_url": "https://..."
    }
  ],
  "map_markers": [
    {
      "id": 1,
      "slug": "luxury-villa",
      "lat": 36.5,
      "lng": -4.9,
      "title": "Luxury Villa",
      "price": "€500,000"
    }
  ],
  "meta": {
    "total": 50,
    "page": 1,
    "per_page": 12,
    "total_pages": 5
  }
}
```

---

#### Grouped Results

Use `group_by=sale_or_rental` to fetch sale and rental listings in one request:

```bash
GET /api_public/v1/en/properties?group_by=sale_or_rental&per_group=3&featured=true
```

```json
{
  "sale": { "properties": [...], "meta": { "total": 5, "per_group": 3 } },
  "rental": { "properties": [...], "meta": { "total": 3, "per_group": 3 } }
}
```

---

#### `GET /properties/{slug}`

Returns full property details by slug or ID.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `locale` | string | Locale for translations |
| `include_images` | string | Set to "variants" for image variants |

**Response:**
```json
{
  "id": 1,
  "slug": "luxury-villa",
  "title": "Luxury Villa with Pool",
  "description": "Beautiful villa...",
  "price_sale_current_cents": 50000000,
  "currency": "EUR",
  "count_bedrooms": 4,
  "count_bathrooms": 3,
  "count_garages": 2,
  "constructed_area": 350,
  "area_unit": "sqm",
  "for_sale": true,
  "for_rent": false,
  "highlighted": true,
  "latitude": 36.5,
  "longitude": -4.9,
  "prop_photos": [
    { "url": "https://...", "image": "https://..." }
  ]
}
```

---

### Pages

#### `GET /pages/{slug}`

Returns CMS page content by slug.

**Response:**
```json
{
  "id": 1,
  "slug": "about-us",
  "title": "About Us",
  "page_contents": [
    {
      "content_page_part_key": "heroes/hero_centered",
      "content": {
        "title": { "en": "About Our Agency" },
        "subtitle": { "en": "Your trusted partner..." }
      }
    }
  ]
}
```

---

## Caching

The API uses HTTP caching headers for optimal performance:

| Endpoint | Cache Duration | Headers |
|----------|----------------|---------|
| `/theme` | 1 hour | `Cache-Control: max-age=3600`, `ETag` |
| `/site-details` | 1 hour | `Cache-Control: max-age=3600`, `ETag` |
| `/properties` | 2 minutes | `Cache-Control: max-age=120` |
| `/properties/:slug` | 5 minutes | `Cache-Control: max-age=300`, `ETag` |

Clients should respect `ETag` headers for conditional requests.

## Error Handling

All errors return a consistent format:

```json
{
  "error": "Error message here"
}
```

| Status Code | Meaning |
|-------------|---------|
| 200 | Success |
| 404 | Resource not found |
| 500 | Server error |

## Authentication

Most endpoints are public and do not require authentication.

For tenant identification, the API uses:
1. **Subdomain**: Automatically detected from request host
2. **Header**: `X-Website-Slug` (for proxy/SSR scenarios)
