# Caching Strategy Guide

This document explains the caching architecture for the PropertyWebBuilder API.

---

## Overview

The API uses a multi-layer caching strategy:

1. **Edge Cache (CDN)** - Cloudflare, Fastly, or similar
2. **Application Cache** - Rails HTTP caching
3. **Client Cache** - Browser and in-memory caching

---

## HTTP Cache Headers

### Cache-Control

| Endpoint | Max-Age | Scope |
|----------|---------|-------|
| `/client-config` | 5 minutes | public |
| `/theme` | 1 hour | public |
| `/site_details` | 1 hour | public |
| `/translations` | 1 hour | public |
| `/links` | 30 minutes | public |
| `/properties` (search) | 2 minutes | public |
| `/properties/:slug` | 5 minutes | public |
| `/pages/:slug` | 5 minutes | public |
| `/testimonials` | 5 minutes | public |

### Response Headers

```http
Cache-Control: max-age=300, public
ETag: "5d8c72a5edda8d6a..."
Vary: Accept-Language, X-Website-Slug
```

---

## Vary Header for Multi-Tenancy

The API returns different content based on:
- **Tenant**: Identified by subdomain or `X-Website-Slug` header
- **Locale**: Language preference

```http
Vary: Accept-Language, X-Website-Slug
```

This ensures CDN caches separate entries for:
- `demo.example.com/en/properties`
- `demo.example.com/es/properties`
- `acme.example.com/en/properties`

---

## Locale in URL Path

### Why Path Params Are Better

| Approach | URL | CDN Behavior |
|----------|-----|--------------|
| Query param | `/properties?locale=en` | May not cache by query |
| Path param | `/en/properties` | Caches per path ✓ |

### Recommended Pattern

```
/api_public/v1/{locale}/properties
/api_public/v1/{locale}/translations
/api_public/v1/{locale}/client-config
```

---

## ETag and Conditional Requests

### Server Response

```http
HTTP/1.1 200 OK
ETag: "a1b2c3d4e5f6"
Cache-Control: max-age=300, public
```

### Client Request (Conditional GET)

```http
GET /api_public/v1/en/properties/luxury-villa HTTP/1.1
If-None-Match: "a1b2c3d4e5f6"
```

### Server Response (Not Modified)

```http
HTTP/1.1 304 Not Modified
ETag: "a1b2c3d4e5f6"
```

---

## Frontend Caching

### In-Memory Cache (Astro)

```typescript
import { withCache, getCacheKey, CacheTTL } from '@/lib/utils/cache';

export async function getSiteDetails(apiUrl?: string): Promise<SiteDetails> {
  const cacheKey = getCacheKey(apiUrl || 'default', 'site_details');
  
  return withCache(
    cacheKey,
    () => client.get('/site_details'),
    { ttl: CacheTTL.SITE_DETAILS }
  );
}
```

### Cache TTL Constants

```typescript
export const CacheTTL = {
  CLIENT_CONFIG: 5 * 60 * 1000,      // 5 minutes
  SITE_DETAILS: 60 * 60 * 1000,       // 1 hour
  NAVIGATION: 30 * 60 * 1000,         // 30 minutes
  TRANSLATIONS: 60 * 60 * 1000,       // 1 hour
  THEME: 60 * 60 * 1000,              // 1 hour
  PROPERTIES_SEARCH: 2 * 60 * 1000,   // 2 minutes
  PROPERTY_DETAIL: 5 * 60 * 1000,     // 5 minutes
};
```

### Per-Request Deduplication

Use `Astro.locals` to avoid duplicate API calls within a single request:

```typescript
export async function getSharedSiteDetails(Astro: AstroGlobal): Promise<SiteDetails> {
  const locals = Astro.locals as Record<string, unknown>;
  
  if (!locals._siteDetails) {
    locals._siteDetails = getSiteDetails(getApiUrl(Astro));
  }
  
  return locals._siteDetails as Promise<SiteDetails>;
}
```

---

## Cache Invalidation

### When to Invalidate

| Event | Affected Caches |
|-------|-----------------|
| Property updated | `/properties/:slug`, `/properties` search |
| Theme changed | `/theme`, `/client-config` |
| Page edited | `/pages/:slug` |
| Links modified | `/links`, `/client-config?include=links` |

### Strategies

1. **Time-based expiry** (current approach)
2. **Cache tags** (for CDN purge by tag)
3. **Webhook-triggered purge** (for real-time updates)

---

## Cloudflare-Specific Settings

### Cache Rules (wrangler.toml)

```toml
[[rules]]
type = "Text"
globs = ["**/*.json"]
fallthrough = true

[cache]
ttl = 300
```

### KV Store for Edge Caching

```typescript
// Cache in Cloudflare KV
const CACHE_KEY = `api:${tenant}:${locale}:${endpoint}`;
const cached = await env.CACHE_KV.get(CACHE_KEY, 'json');

if (cached) {
  return new Response(JSON.stringify(cached));
}

const response = await fetch(apiUrl);
const data = await response.json();

await env.CACHE_KV.put(CACHE_KEY, JSON.stringify(data), {
  expirationTtl: 300
});
```

---

## Best Practices

### DO

- ✅ Use locale in URL path for CDN caching
- ✅ Include `Vary` header for multi-tenant responses
- ✅ Set appropriate `Cache-Control` max-age
- ✅ Return `ETag` for conditional requests
- ✅ Use `stale-while-revalidate` for better UX

### DON'T

- ❌ Cache POST/PUT/DELETE responses
- ❌ Use user-specific data in cached responses
- ❌ Set very long cache times for frequently-changing data
- ❌ Forget to invalidate after content updates

---

## Monitoring

### Metrics to Track

| Metric | Target |
|--------|--------|
| Cache hit rate | >80% |
| Average response time (cached) | <50ms |
| Average response time (cache miss) | <200ms |
| Time to first byte (TTFB) | <100ms |

### Headers for Debugging

```http
X-Cache: HIT  (from CDN)
CF-Cache-Status: HIT  (Cloudflare)
Age: 120  (seconds since cached)
```
