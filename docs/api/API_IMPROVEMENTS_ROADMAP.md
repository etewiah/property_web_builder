# API Improvements Roadmap

This document outlines recommended improvements to the PropertyWebBuilder public API.

---

## 1. Response Envelope Standardization

### Current State
Endpoints return inconsistent response shapes:
- `/links` → `{ data: [...] }`
- `/testimonials` → `{ testimonials: [...] }` or `[...]`
- `/properties` → `{ data: [...], meta: {...}, map_markers: [...] }`

### Recommended Standard

All endpoints should return:

```json
{
  "data": { ... } | [...],
  "meta": {
    "total": 100,
    "page": 1,
    "per_page": 12,
    "total_pages": 9
  },
  "_links": {
    "self": "/api_public/v1/en/properties?page=1",
    "next": "/api_public/v1/en/properties?page=2",
    "prev": null
  },
  "_errors": []
}
```

### Implementation Steps

1. Create `ApiPublic::ResponseEnvelope` concern
2. Update all controllers to use `render_envelope(data:, meta:)`
3. Add `_links` for HATEOAS-style navigation
4. Frontend: Update response extractors in `site.ts` and `properties.ts`

### Priority: HIGH
Reduces frontend complexity and improves predictability.

---

## 2. Sparse Fieldsets (`fields` Parameter)

### Problem
Full property responses are ~2KB. Landing page only needs ~200 bytes per property.

### Solution

```bash
GET /api_public/v1/en/properties?fields=id,slug,title,primary_image_url,formatted_price
```

### Response

```json
{
  "data": [
    {
      "id": 1,
      "slug": "luxury-villa",
      "title": "Luxury Villa",
      "primary_image_url": "https://...",
      "formatted_price": "€500,000"
    }
  ]
}
```

### Implementation Steps

1. Add `allowed_fields` whitelist to each controller
2. Create `ApiPublic::SparseFieldsets` concern
3. Modify serialization to filter fields
4. Document allowed fields per endpoint

### Priority: MEDIUM
Significant bandwidth savings for listing pages.

---

## 3. Standardized Error Responses

### Current State

```json
{ "error": "Not found" }
```

### Recommended Format

```json
{
  "error": {
    "code": "PROPERTY_NOT_FOUND",
    "message": "Property with slug 'xyz' not found",
    "status": 404,
    "details": {
      "requested_slug": "xyz"
    }
  }
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `VALIDATION_FAILED` | 400 | Invalid request parameters |
| `NOT_FOUND` | 404 | Resource not found |
| `PROPERTY_NOT_FOUND` | 404 | Property doesn't exist |
| `PAGE_NOT_FOUND` | 404 | CMS page doesn't exist |
| `CLIENT_RENDERING_DISABLED` | 403 | Website uses Rails rendering |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Server error |

### Implementation Steps

1. Create `lib/api_public/errors.rb` with error classes
2. Add `rescue_from` handlers in `BaseController`
3. Create `ApiPublic::ErrorHandler` concern
4. Update frontend error handling

### Priority: HIGH
Enables better error handling and debugging.

---

## 4. Rate Limiting Headers

### Recommended Headers

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1642531200
```

### Implementation Options

1. **Rack::Attack** gem (recommended)
2. Custom Redis-based rate limiter
3. Cloudflare rate limiting (if using CF)

### Suggested Limits

| Endpoint Pattern | Limit |
|------------------|-------|
| `GET /properties` | 100/minute |
| `GET /client-config` | 60/minute |
| `POST /enquiries` | 10/minute |
| `POST /contact` | 5/minute |

### Priority: LOW
Important for production, but not critical initially.

---

## 5. ETag and Conditional GET

### Current State
`Cacheable` concern exists but not fully utilized.

### Improvements Needed

1. Ensure all GET endpoints return `ETag` header
2. Handle `If-None-Match` for 304 responses
3. Add `Last-Modified` headers where applicable

### Implementation

```ruby
# In controller
def show
  property = find_property
  set_etag(property)
  
  if stale?(property)
    render json: property_response(property)
  end
end
```

### Priority: MEDIUM
Reduces bandwidth and improves cache hit rates.

---

## 6. API Versioning Strategy

### Current State
Using `/api_public/v1/` prefix.

### Recommendations

1. **Keep v1 stable** - No breaking changes
2. **Deprecation warnings** - Add `X-API-Deprecation` header
3. **sunset dates** - Document when old features will be removed

### Deprecation Header Example

```http
X-API-Deprecation: locale query param; use path param instead
X-API-Sunset: 2026-06-01
```

### Priority: LOW
Important for long-term maintainability.

---

## 7. Batch Requests

### Problem
Multiple related requests add latency.

### Solution: Batch Endpoint

```bash
POST /api_public/v1/batch
```

```json
{
  "requests": [
    { "id": "config", "method": "GET", "path": "/en/client-config" },
    { "id": "props", "method": "GET", "path": "/en/properties?featured=true&per_page=6" }
  ]
}
```

### Response

```json
{
  "responses": {
    "config": { "status": 200, "body": { ... } },
    "props": { "status": 200, "body": { ... } }
  }
}
```

### Priority: LOW
The `include=` parameter on `/client-config` addresses most batch needs.

---

## Implementation Priority

| Improvement | Priority | Effort | Impact |
|-------------|----------|--------|--------|
| Response Standardization | HIGH | Medium | High |
| Error Responses | HIGH | Low | High |
| Sparse Fieldsets | MEDIUM | Medium | Medium |
| ETag/Conditional GET | MEDIUM | Low | Medium |
| Rate Limiting | LOW | Low | Low |
| API Versioning | LOW | Low | Low |
| Batch Requests | LOW | High | Low |

---

## Next Steps

1. Create implementation plan for top 2-3 priorities
2. Update OpenAPI spec with new response formats
3. Update frontend API modules
4. Add migration guide for any breaking changes
