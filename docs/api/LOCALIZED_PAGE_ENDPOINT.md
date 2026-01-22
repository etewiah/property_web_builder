# API Documentation: Localized Page Meta Data Endpoint

## Endpoint

`GET /api_public/v1/:locale/localized_page/by_slug/:page_slug`

### Description

Returns comprehensive metadata and content for a specific page, localized to the requested language. This includes SEO meta tags, Open Graph, Twitter Cards, JSON-LD structured data, caching headers, navigation info, and localized UI labels.

All text fields are automatically localized using Mobility translations stored in the page's `translations` JSONB column.

---

## Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `locale` | string | Yes | Language code (e.g., `en`, `es`, `fr`) |
| `page_slug` | string | Yes | Unique slug for the page (e.g., `privacy`, `about-us`) |

---

## Example Request

```
GET /api_public/v1/es/localized_page/by_slug/privacy
```

Returns the privacy page metadata and content in Spanish.

---

## Response Structure

```json
{
  "id": 8,
  "slug": "privacy",
  "locale": "es",
  "hostname": "example.com",
  "title": "Política de Privacidad",
  "meta_description": "Descripción para SEO y compartir en redes sociales.",
  "meta_keywords": "privacidad, política, inmobiliaria",
  "canonical_url": "https://example.com/es/p/privacy",
  "last_modified": "2026-01-22T12:34:56Z",
  "etag": "\"abc123etagvalue\"",
  "cache_control": "public, max-age=3600",
  "og": {
    "og:title": "Política de Privacidad",
    "og:description": "Descripción para compartir en redes sociales.",
    "og:type": "website",
    "og:url": "https://example.com/es/p/privacy",
    "og:image": "https://example.com/images/privacy-og.jpg",
    "og:site_name": "Example Real Estate"
  },
  "twitter": {
    "twitter:card": "summary_large_image",
    "twitter:title": "Política de Privacidad",
    "twitter:description": "Descripción para tarjeta de Twitter.",
    "twitter:image": "https://example.com/images/privacy-twitter.jpg"
  },
  "json_ld": {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "Política de Privacidad",
    "description": "Descripción para datos estructurados.",
    "url": "https://example.com/es/p/privacy",
    "inLanguage": "es",
    "datePublished": "2024-01-01",
    "dateModified": "2026-01-22",
    "publisher": {
      "@type": "Organization",
      "name": "Example Real Estate",
      "logo": {
        "@type": "ImageObject",
        "url": "https://example.com/logo.png"
      }
    }
  },
  "breadcrumbs": [
    { "name": "Inicio", "url": "/es/" },
    { "name": "Política de Privacidad", "url": "/es/p/privacy" }
  ],
  "alternate_locales": [
    { "locale": "en", "url": "https://example.com/p/privacy" },
    { "locale": "fr", "url": "https://example.com/fr/p/privacy" }
  ],
  "html_elements": [
    {
      "element_class_id": "page_title",
      "element_label": "Política de Privacidad"
    },
    {
      "element_class_id": "submit_button",
      "element_label": "Enviar"
    }
  ],
  "sort_order_top_nav": 0,
  "show_in_top_nav": false,
  "sort_order_footer": 0,
  "show_in_footer": false,
  "visible": true,
  "page_contents": [
    {
      "page_part_key": "content_html",
      "sort_order": 1,
      "visible": true,
      "is_rails_part": false,
      "rendered_html": "<section class=\"content-html-section\">...</section>",
      "label": null
    }
  ]
}
```

---

## Field Descriptions

### Basic Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Page ID |
| `slug` | string | URL-friendly page identifier |
| `locale` | string | Requested locale |
| `hostname` | string | Hostname of the request |
| `title` | string | Localized page title (from `seo_title` or `page_title`) |
| `meta_description` | string | Localized meta description for SEO |
| `meta_keywords` | string | Localized meta keywords for SEO |
| `canonical_url` | string | Full canonical URL with locale prefix (if non-default locale) |

### Caching Fields

| Field | Type | Description |
|-------|------|-------------|
| `last_modified` | string | ISO 8601 timestamp of last modification |
| `etag` | string | ETag for cache validation (includes locale in hash) |
| `cache_control` | string | Recommended cache control header value |

### SEO/Social Fields

| Field | Type | Description |
|-------|------|-------------|
| `og` | object | Open Graph meta tags (all localized) |
| `twitter` | object | Twitter Card meta tags (all localized) |
| `json_ld` | object | JSON-LD structured data with `inLanguage` set to requested locale |

### Navigation Fields

| Field | Type | Description |
|-------|------|-------------|
| `breadcrumbs` | array | Breadcrumb trail with localized URLs |
| `alternate_locales` | array | Links to other language versions (excludes current locale) |
| `sort_order_top_nav` | integer | Position in top navigation |
| `show_in_top_nav` | boolean | Whether to show in top navigation |
| `sort_order_footer` | integer | Position in footer navigation |
| `show_in_footer` | boolean | Whether to show in footer |
| `visible` | boolean | Page visibility status |

### UI Elements

| Field | Type | Description |
|-------|------|-------------|
| `html_elements` | array | UI labels for the requested locale only |

Each element contains:
- `element_class_id`: Identifier for the UI element
- `element_label`: Translated string for the requested locale

### Content Fields

| Field | Type | Description |
|-------|------|-------------|
| `page_contents` | array | Rendered page content blocks with localized URLs |

Each content block contains:
- `page_part_key`: Template identifier
- `sort_order`: Display order
- `visible`: Visibility status
- `is_rails_part`: Whether this is a Rails partial (no pre-rendered HTML)
- `rendered_html`: Pre-rendered HTML with localized internal URLs
- `label`: Optional label for admin purposes

---

## Localization Details

### How Translations Work

All text fields (`title`, `meta_description`, `meta_keywords`, `seo_title`, `page_title`) are stored in the page's `translations` JSONB column using Mobility. When you request a specific locale:

1. Mobility automatically returns the translation for that locale
2. If no translation exists, it falls back to English (configured in `mobility.rb`)
3. URLs in `rendered_html` are automatically prefixed with the locale

### Canonical URL Generation

- **Default locale (e.g., `en`)**: `/p/privacy`
- **Non-default locales (e.g., `es`)**: `/es/p/privacy`

This ensures proper SEO with distinct URLs per language.

### Alternate Locales

The `alternate_locales` array helps search engines discover all language versions:
- Only includes locales the website supports (`website.supported_locales`)
- Excludes the current request's locale
- URLs follow the same pattern as `canonical_url`

---

## Caching

### HTTP Headers

The endpoint sets proper HTTP cache headers:
- `Cache-Control: public, max-age=3600`
- `ETag`: Unique per page + locale combination
- Supports conditional GET (304 Not Modified)

### ETags

ETags are generated from:
- Page ID
- Page updated_at timestamp
- Current locale

This ensures cache invalidation when:
- Page content changes
- Requesting a different locale

---

## Error Handling

### 404 Not Found

**Page not found:**
```json
{
  "error": "Page not found",
  "code": "PAGE_NOT_FOUND"
}
```

**Website not provisioned:**
```json
{
  "error": "Website not provisioned",
  "message": "The website has not been provisioned with any pages.",
  "code": "WEBSITE_NOT_PROVISIONED"
}
```

---

## Implementation Notes

### Adding Translations

To add translations for a page:

```ruby
page = Pwb::Page.find_by(slug: 'about-us')

Mobility.with_locale(:es) do
  page.seo_title = "Sobre Nosotros"
  page.meta_description = "Conozca más sobre nuestra empresa."
  page.meta_keywords = "sobre nosotros, inmobiliaria"
  page.save!
end
```

### Model Configuration

The `Pwb::Page` model declares these Mobility-translated fields:

```ruby
translates :raw_html, :page_title, :link_title,
           :seo_title, :meta_description, :meta_keywords
```

All translations are stored in the `translations` JSONB column.

---

## Testing

See `spec/requests/api_public/v1/localized_pages_spec.rb` for comprehensive test coverage including:

- Locale-specific translations
- Canonical URL generation
- Open Graph metadata
- Twitter Card metadata
- JSON-LD structured data
- Breadcrumbs with localized URLs
- Alternate locales
- HTML element translations
- Cache header validation
- Error handling
- Locale fallback behavior

---

## Authors

PropertyWebBuilder Team
