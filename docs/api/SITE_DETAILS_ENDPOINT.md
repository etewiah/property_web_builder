# Site Details Endpoint

The Site Details endpoint retrieves essential configuration and metadata for the property website. It is designed to be the first call a frontend client makes to bootstrap the application.

## Endpoint

`GET /api_public/v1/:locale/site_details`

### Parameters

| Name | Type | Description |
|Data Type| String | Required? |
|---|---|---|
| `locale` | string | **Required** (in path). The 2-letter locale code (e.g., `en`, `es`, `fr`). |

### Backward Compatibility

For backward compatibility with older clients, the legacy route is also supported:

`GET /api_public/v1/site_details?locale=:locale`

However, using the locale-scoped route (`/api_public/v1/:locale/site_details`) is **strongly recommended** for better edge caching and performance.

---

## Response Structure

The response is a JSON object containing website configuration, SEO metadata, and analytics keys.

### Example Response

```json
{
  "company_display_name": "My Real Estate Agency",
  "theme_name": "default",
  "default_area_unit": "sqmt",
  "default_client_locale": "en",
  "available_currencies": ["EUR", "USD", "GBP"],
  "default_currency": "EUR",
  "supported_locales": ["en", "es"],
  "dark_mode_setting": "light_only",
  
  // Requester Context
  "requester_locale": "en",
  "requester_hostname": "www.example.com",
  
  // Caching
  "last_modified": "2026-01-22T16:30:00Z",
  "etag": "\"12345abcde...\"",
  "cache_control": "public, max-age=3600",
  
  // SEO Default Metadata
  "title": "My Real Estate Agency",
  "meta_description": "Find your dream property with us.",
  "meta_keywords": null,
  
  // Open Graph (Facebook, LinkedIn, etc.)
  "og": {
    "og:title": "My Real Estate Agency",
    "og:description": "Find your dream property with us.",
    "og:type": "website",
    "og:site_name": "My Real Estate Agency",
    "og:url": "https://www.example.com/",
    "og:image": "https://www.example.com/assets/logo.png"
  },
  
  // Twitter Card
  "twitter": {
    "twitter:card": "summary_large_image",
    "twitter:title": "My Real Estate Agency",
    "twitter:description": "Find your dream property with us.",
    "twitter:image": "https://www.example.com/assets/logo.png"
  },
  
  // JSON-LD Structured Data (Schema.org)
  "json_ld": {
    "@context": "https://schema.org",
    "@type": "WebSite",
    "name": "My Real Estate Agency",
    "url": "https://www.example.com/",
    "inLanguage": "en",
    "publisher": {
      "@type": "Organization",
      "name": "My Real Estate Agency",
      "logo": {
        "@type": "ImageObject",
        "url": "https://www.example.com/assets/logo.png"
      }
    }
  },
  
  // Analytics Configuration
  "analytics": {
    "ga4_id": "G-XXXXXXXXXX",
    "gtm_id": "GTM-XXXXXX",
    "posthog_key": "phc_...",
    "posthog_host": "https://app.posthog.com"
  },
  
  // Additional Data
  "logo_url": "https://www.example.com/assets/logo.png",
  "favicon_url": "https://www.example.com/assets/favicon.ico",
  "contact_info": { ... },
  "social_links": { ... },
  "top_nav_links": [ ... ],
  "footer_links": [ ... ],
  "agency": { ... }
}
```

---

## Fields Description

| Field | Type | Description |
|---|---|---|
| `requester_locale` | string | The locale actually used for the response (may differ from requested if fallback occurred). |
| `requester_hostname` | string | The hostname found in the request. |
| `cache_control` | string | Recommended `Cache-Control` header value for the client/CDN. |
| `etag` | string | Unique identifier for this version of the resource. |
| `og` | object | Open Graph meta tags for social sharing. |
| `twitter` | object | Twitter Card meta tags. |
| `json_ld` | object | Schema.org structured data for the `WebSite` entity. |
| `analytics` | object | Keys for configured analytics services (GA4, GTM, PostHog). |

## Usage

This endpoint should be called immediately upon application load. The data returned should be used to:

1.  Initialize the application state (currency, locale, theme).
2.  Set the document `<head>` metadata (title, meta tags).
3.  Hydrate the initial UI (navigation, footer, logos).
4.  Initialize analytics trackers using the provided keys.

## Caching Strategy

The response includes `Cache-Control: public, max-age=3600`, indicating it can be cached for up to 1 hour. Clients should assume this data is relatively static but should respect the `ETag` for re-validation if they cache it longer.
