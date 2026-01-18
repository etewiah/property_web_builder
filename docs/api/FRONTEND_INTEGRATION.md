# Frontend Integration Guide

This guide explains how the Astro frontend integrates with the PropertyWebBuilder API.

---

## Base Configuration

### API Client Setup

```typescript
// src/lib/api/client.ts
import axios from 'axios';

export const API_BASE_URL = 
  import.meta.env.PUBLIC_API_URL || 'http://localhost:3000';

const apiClient = axios.create({
  baseURL: `${API_BASE_URL}/api_public/v1`,
  headers: { 'Content-Type': 'application/json' },
  timeout: 5000,
});
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PUBLIC_API_URL` | Yes | Backend API base URL |
| `PUBLIC_THEME_NAME` | No | Override theme for preview |
| `PUBLIC_DEBUG_API` | No | Enable API request logging |

---

## Locale Handling

### Locale-Prefixed Paths (Recommended)

For better CDN caching, use locale in the URL path:

```typescript
import { buildLocalePath } from './client';

// Use locale in path for better caching
const path = buildLocalePath('/properties', 'en');
// Returns: '/en/properties'

const response = await client.get(path);
```

### The `buildLocalePath` Helper

```typescript
export const buildLocalePath = (path: string, locale?: string): string => {
  if (!locale) return path;
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  const normalizedLocale = locale.toLowerCase().split('-')[0];
  return `/${normalizedLocale}${normalizedPath}`;
};
```

### Supported Locale Patterns

```
/api_public/v1/en/properties       ✓ Recommended
/api_public/v1/es-ES/properties    ✓ With region code
/api_public/v1/properties?locale=en ✓ Legacy (still works)
```

---

## Per-Request Data Caching

### Using `Astro.locals` for Deduplication

```typescript
// src/lib/utils/shared-data.ts
export async function getSharedSiteDetails(Astro: AstroGlobal): Promise<SiteDetails> {
  const locals = Astro.locals as Record<string, unknown>;
  
  if (!locals._siteDetails) {
    const apiUrl = getApiUrl(Astro);
    locals._siteDetails = getSiteDetails(apiUrl);
  }
  
  return locals._siteDetails as Promise<SiteDetails>;
}
```

### Available Shared Data Functions

| Function | Description |
|----------|-------------|
| `getSharedSiteDetails(Astro)` | Site name, locales, colors |
| `getSharedNavigationLinks(Astro, position)` | Top nav or footer links |
| `getSharedTranslations(Astro, locale)` | I18n translations |
| `getSharedTheme(Astro)` | Theme colors and CSS variables |

---

## Aggregated Data with `include=`

### Reduce API Calls

Instead of 5+ separate calls, use the `include=` parameter:

```typescript
// Single call for landing page data
const response = await client.get('/en/client-config', {
  params: {
    include: 'links,site_details,translations,homepage,featured_properties'
  }
});

const { data } = response;
// data.links - All navigation links
// data.site_details - Site metadata
// data.translations - I18n strings
// data.homepage - Home page content
// data.featured_properties - { sale: [...], rental: [...] }
```

### Available Includes

| Include | Description |
|---------|-------------|
| `site_details` | Site name, locales, analytics config |
| `links` | All navigation links with position |
| `translations` | I18n translations for locale |
| `homepage` | Home page with rendered content |
| `testimonials` | Visible testimonials (limit: 6) |
| `featured_properties` | Featured properties grouped by sale/rental |

### Error Handling for Partial Failures

```typescript
const { data, _errors } = response;

if (_errors?.length) {
  console.warn('Partial failure:', _errors);
  // Handle missing sections gracefully
}
```

---

## Grouped Properties

### Single Request for Sale + Rental

```typescript
// Old way: 2 requests
const sale = await getProperties({ sale_or_rental: 'sale', featured: true });
const rental = await getProperties({ sale_or_rental: 'rental', featured: true });

// New way: 1 request
const response = await client.get('/en/properties', {
  params: {
    group_by: 'sale_or_rental',
    per_group: 3,
    featured: true
  }
});

const { sale, rental } = response;
// sale.properties, sale.meta
// rental.properties, rental.meta
```

---

## Response Normalization

### Handling Multiple Response Shapes

The API may return different shapes. Use extractors:

```typescript
// src/lib/api/properties.ts
const extractProperties = (value: unknown) => {
  if (Array.isArray(value)) return { properties: value };
  if (isRecord(value)) {
    if (Array.isArray(value.data)) return { properties: value.data, meta: value.meta };
    if (Array.isArray(value.properties)) return { properties: value.properties, meta: value.meta };
  }
  return null;
};
```

---

## Caching Strategy

### Cache TTLs

```typescript
export const CacheTTL = {
  CLIENT_CONFIG: 5 * 60 * 1000,      // 5 minutes
  SITE_DETAILS: 60 * 60 * 1000,       // 1 hour
  NAVIGATION: 30 * 60 * 1000,         // 30 minutes
  TRANSLATIONS: 60 * 60 * 1000,       // 1 hour
  THEME: 60 * 60 * 1000,              // 1 hour
};
```

### In-Memory Cache Helper

```typescript
import { withCache, getCacheKey } from '@/lib/utils/cache';

const data = await withCache(
  getCacheKey(apiUrl, 'site_details'),
  () => client.get('/site_details'),
  { ttl: CacheTTL.SITE_DETAILS }
);
```

---

## Error Handling

### API Error Wrapper

```typescript
const toSafeError = (error: unknown): Error => {
  if (axios.isAxiosError(error)) {
    const status = error.response?.status;
    const message = status
      ? `API request failed (${status})`
      : error.message;
    return new Error(message);
  }
  return new Error('Unknown API error');
};
```

### Graceful Degradation

```typescript
export async function getSiteDetails(): Promise<SiteDetails> {
  try {
    return await client.get('/site_details');
  } catch (error) {
    reportApiIssue('getSiteDetails', 'using defaults', error);
    return DEFAULT_SITE_DETAILS;
  }
}
```

---

## Multi-Tenant Routing

### Dynamic API URL Resolution

```typescript
export function getApiUrl(Astro: AstroGlobal): string {
  // Check runtime env first (Cloudflare Workers)
  const runtimeEnv = Astro.locals?.runtime?.env;
  if (runtimeEnv?.API_BASE_URL) {
    return runtimeEnv.API_BASE_URL;
  }
  
  // Fall back to build-time env
  return import.meta.env.PUBLIC_API_URL || 'http://localhost:3000';
}
```

### Passing API URL to Functions

```typescript
const apiUrl = getApiUrl(Astro);
const siteDetails = await getSiteDetails(apiUrl);
const properties = await getProperties({ locale: 'en' }, apiUrl);
```

---

## Debug Mode

### Enable API Logging

Set `PUBLIC_DEBUG_API=true` to log all API requests:

```
[API] GET /api_public/v1/en/properties
[API] 200 GET /api_public/v1/en/properties (123ms)
```

### Diagnostic Reporting

```typescript
import { reportApiIssue } from '@/lib/utils/api-diagnostics';

reportApiIssue(
  'getProperties',
  'unexpected response shape',
  response
);
```
