# Public API Changelog

All notable changes to the PropertyWebBuilder public API.

---

## [Unreleased]

### Added
- **Grouped Properties**: `group_by=sale_or_rental` parameter returns properties grouped by type
- **Client Config Includes**: `include=` parameter aggregates multiple data blocks
- **Locale Path Params**: Routes like `/api_public/v1/en/properties` for better CDN caching
- **Vary Headers**: `Vary: Accept-Language, X-Website-Slug` for proper edge caching

### Changed
- Properties endpoint now supports `per_group` parameter when using `group_by`

### Deprecated
- `?locale=en` query parameter (use path param `/en/` instead)

---

## [1.0.0] - 2025-01-01

### Added
- Initial public API release
- Properties search with pagination
- Site details endpoint
- Navigation links endpoint
- CMS pages endpoint
- Theme configuration endpoint
- Translations endpoint
- Testimonials endpoint
- Contact/enquiry form submissions
- Firebase authentication endpoint

### Caching
- `Cache-Control` headers on all GET endpoints
- ETag support via `Cacheable` concern

---

## Versioning Policy

This API follows semantic versioning:

- **MAJOR**: Breaking changes to response format or behavior
- **MINOR**: New features, new endpoints, new parameters
- **PATCH**: Bug fixes, documentation updates

### Deprecation Policy

1. Deprecated features will have `X-API-Deprecation` header
2. Deprecation period: minimum 3 months
3. Breaking changes only in major versions

---

## Migration Guides

### Migrating to Locale Path Parameters

**Before:**
```bash
GET /api_public/v1/properties?locale=en&sale_or_rental=sale
```

**After:**
```bash
GET /api_public/v1/en/properties?sale_or_rental=sale
```

**Why:** Better CDN caching - paths are cached separately.

### Using Grouped Properties

**Before:** (2 requests)
```bash
GET /api_public/v1/en/properties?sale_or_rental=sale&featured=true&per_page=3
GET /api_public/v1/en/properties?sale_or_rental=rental&featured=true&per_page=3
```

**After:** (1 request)
```bash
GET /api_public/v1/en/properties?group_by=sale_or_rental&per_group=3&featured=true
```

**Response:**
```json
{
  "sale": { "properties": [...], "meta": { "total": 5, "per_group": 3 } },
  "rental": { "properties": [...], "meta": { "total": 3, "per_group": 3 } }
}
```

### Using Client Config Includes

**Before:** (5+ requests)
```bash
GET /api_public/v1/en/client-config
GET /api_public/v1/en/links
GET /api_public/v1/en/site_details
GET /api_public/v1/en/translations
GET /api_public/v1/en/pages/by_slug/home
```

**After:** (1 request)
```bash
GET /api_public/v1/en/client-config?include=links,site_details,translations,homepage
```

**Response:**
```json
{
  "data": {
    "rendering_mode": "client",
    "theme": { ... },
    "links": [...],
    "site_details": { ... },
    "translations": { ... },
    "homepage": { ... }
  }
}
```
