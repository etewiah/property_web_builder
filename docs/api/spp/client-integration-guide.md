# SPP Client Integration Guide

This guide is for the team building SPP (Single Property Pages) clients that integrate with PropertyWebBuilder (PWB) as a data backend. It covers everything you need: configuration, authentication, every API endpoint, request/response shapes, enquiry handling, SEO requirements, and caching.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Getting Started](#getting-started)
3. [Authentication](#authentication)
4. [API Endpoints Reference](#api-endpoints-reference)
   - [Fetch Property Data (Public)](#1-fetch-property-data)
   - [Search Properties (Public)](#2-search-properties)
   - [Publish SPP Listing](#3-publish-spp-listing)
   - [Unpublish SPP Listing](#4-unpublish-spp-listing)
   - [Get Property Leads](#5-get-property-leads)
   - [Update SPP Listing Content](#6-update-spp-listing-content)
   - [Submit Enquiry (Browser)](#7-submit-enquiry-from-browser)
5. [Error Handling](#error-handling)
6. [SEO Requirements](#seo-requirements)
7. [Caching and Data Freshness](#caching-and-data-freshness)
8. [TypeScript Types](#typescript-types)
9. [Environment Variables](#environment-variables)
10. [Quick Start Checklist](#quick-start-checklist)

---

## Architecture Overview

```
                    Visitor's Browser
                    /              \
                   /                \
            Page request         Enquiry POST
                 |                    |
                 v                    v
          ┌─────────────┐     ┌─────────────────┐
          │  SPP (Astro) │     │  PWB api_public  │
          │  Your app    │     │  (no auth needed)│
          └──────┬───────┘     └─────────────────┘
                 │
      Server-side API calls
      (X-API-Key + X-Website-Slug)
                 │
                 v
          ┌─────────────────┐
          │  PWB api_manage  │
          │  (auth required) │
          └─────────────────┘
```

**Two API namespaces on PWB:**

| Namespace | Auth | Called by | Purpose |
|-----------|------|-----------|---------|
| `api_public/v1` | None (public) | Browser directly | Fetch property data, submit enquiries |
| `api_manage/v1` | `X-API-Key` header | SPP server only | Publish, unpublish, leads, content management |

**Key principle:** The API key is used **only in your server-side code** (Astro API routes, SSR). The browser never sees it. Browser requests go directly to `api_public` (CORS is configured).

---

## Getting Started

### 1. Get Your Credentials

Ask the PWB admin to run the provisioning command for your tenant:

```bash
rails spp:provision[your-subdomain]
```

This outputs three values you need:

| Value | Example | Where it goes |
|-------|---------|---------------|
| `PWB_API_KEY` | `a1b2c3d4e5f6...` (64-char hex) | Your `.env` / deployment secrets |
| `PWB_WEBSITE_SLUG` | `my-agency` | Your `.env` |
| `PWB_API_URL` | `https://my-agency.propertywebbuilder.com` | Your `.env` |

### 2. Configure Your Environment

```bash
# .env
PWB_API_KEY=a1b2c3d4e5f6...
PWB_WEBSITE_SLUG=my-agency
PWB_API_URL=https://my-agency.propertywebbuilder.com
```

### 3. Verify the URL Template

The PWB admin must also configure `spp_url_template` in the website's `client_theme_config`. This tells PWB what URLs your SPP pages will live at. The template supports these placeholders:

| Placeholder | Replaced with | Example |
|-------------|--------------|---------|
| `{slug}` | Property slug | `123-main-street` |
| `{uuid}` | Property UUID | `a1b2c3d4-...` |
| `{listing_type}` | `sale` or `rental` | `sale` |
| `{locale}` | Locale code | `en` |

Example template:
```
https://{slug}-{listing_type}.spp.example.com/
```

Produces: `https://123-main-st-sale.spp.example.com/`

Without this template, the publish endpoint will return a 422 error.

---

## Authentication

### Server-Side Requests (api_manage)

Every request to `api_manage` must include two headers:

```
X-API-Key: <your PWB_API_KEY>
X-Website-Slug: <your PWB_WEBSITE_SLUG>
Content-Type: application/json
```

Example fetch wrapper (TypeScript):

```typescript
// lib/pwb-client.ts
const PWB_API_URL = import.meta.env.PWB_API_URL;
const PWB_API_KEY = import.meta.env.PWB_API_KEY;
const PWB_WEBSITE_SLUG = import.meta.env.PWB_WEBSITE_SLUG;

export async function pwbManageApi(path: string, options: RequestInit = {}) {
  const url = `${PWB_API_URL}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'X-API-Key': PWB_API_KEY,
      'X-Website-Slug': PWB_WEBSITE_SLUG,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `PWB API error: ${res.status}`);
  }

  return res.json();
}
```

### Browser Requests (api_public)

No API key needed. Only the `X-Website-Slug` header is required for tenant resolution:

```typescript
// Client-side fetch (e.g., enquiry form submission)
export async function pwbPublicApi(path: string, options: RequestInit = {}) {
  const res = await fetch(`${PWB_API_URL}${path}`, {
    ...options,
    headers: {
      'X-Website-Slug': PWB_WEBSITE_SLUG, // This must be available client-side
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });
  return res.json();
}
```

---

## API Endpoints Reference

### 1. Fetch Property Data

Fetch full property details for rendering an SPP page.

```
GET /api_public/v1/properties/:id_or_slug
```

**Headers:** `X-Website-Slug` only (public endpoint).

**The `:id_or_slug` parameter** accepts either the property UUID or its URL slug.

**Response (200):**
```json
{
  "id": "a1b2c3d4-...",
  "slug": "123-main-street",
  "reference": "REF-001",
  "title": "Spacious 3-Bed Apartment in Biarritz",
  "description_en": "A beautiful apartment...",
  "count_bedrooms": 3,
  "count_bathrooms": 2,
  "price_sale_current_cents": 45000000,
  "price_rental_monthly_current_cents": 250000,
  "formatted_price": "450,000 EUR",
  "currency": "EUR",
  "latitude": 43.4832,
  "longitude": -1.5586,
  "city": "Biarritz",
  "region": "Nouvelle-Aquitaine",
  "street_address": "123 Main Street",
  "for_sale": true,
  "for_rent": false,
  "highlighted": true,
  "primary_image_url": "https://...",
  "prop_photos": [
    { "id": 42, "sort_order": 1, "image_url": "https://..." },
    { "id": 17, "sort_order": 2, "image_url": "https://..." }
  ],
  "features": [...],
  "page_contents": [...]
}
```

**Cache:** `Cache-Control: public, max-age=300` (5 minutes). Use `If-Modified-Since` for conditional GET.

**Tip:** Add `?include_images=variants` to get responsive image variants in the response.

---

### 2. Search Properties

Fetch a list of properties for index pages or navigation.

```
GET /api_public/v1/properties?sale_or_rental=sale&page=1&per_page=12
```

**Headers:** `X-Website-Slug` only.

**Query Parameters:**

| Param | Default | Description |
|-------|---------|-------------|
| `sale_or_rental` | `sale` | `"sale"` or `"rental"` |
| `page` | `1` | Page number |
| `per_page` | `12` | Results per page |
| `sort_by` | none | `price-asc`, `price-desc`, `newest`, `oldest` |
| `featured` | none | `"true"` to filter highlighted properties only |
| `limit` | none | Hard cap on results |
| `group_by` | none | `"sale_or_rental"` for grouped response |

**Response (200):**
```json
{
  "data": [
    {
      "id": "a1b2c3d4-...",
      "slug": "123-main-street",
      "title": "Spacious 3-Bed Apartment",
      "formatted_price": "450,000 EUR",
      "count_bedrooms": 3,
      "count_bathrooms": 2,
      "for_sale": true,
      "for_rent": false,
      "primary_image_url": "https://...",
      "prop_photos": [...]
    }
  ],
  "map_markers": [
    { "id": "...", "lat": 43.48, "lng": -1.55, "title": "...", "price": "..." }
  ],
  "meta": {
    "total": 47,
    "page": 1,
    "per_page": 12,
    "total_pages": 4
  }
}
```

---

### 3. Publish SPP Listing

Activate an SPP listing so the page is considered "live" on PWB. This creates or re-activates an `SppListing` record and computes the `liveUrl`.

```
POST /api_manage/v1/:locale/properties/:property_id/spp_publish
```

**Headers:** `X-API-Key`, `X-Website-Slug`, `Content-Type: application/json`

**Request Body:**
```json
{
  "listing_type": "sale"
}
```

| Param | Type | Required | Default | Values |
|-------|------|----------|---------|--------|
| `listing_type` | string | No | `"sale"` | `"sale"` or `"rental"` |

**Response (200):**
```json
{
  "status": "published",
  "listingType": "sale",
  "liveUrl": "https://123-main-st-sale.spp.example.com/",
  "publishedAt": "2026-02-12T10:30:00Z"
}
```

**Key behaviors:**
- Idempotent: calling publish again updates `publishedAt` but doesn't create a duplicate
- Sale and rental listings are independent: publishing sale does not affect rental (or vice versa)
- PWB's own SaleListing/RentalListing records are not affected
- The `liveUrl` is generated from `spp_url_template` in the website config

**Errors:**
- `422` — `spp_url_template` not configured, or invalid `listing_type`
- `404` — Property not found (or belongs to different tenant)
- `401` — Missing or invalid API key

---

### 4. Unpublish SPP Listing

Hide an SPP listing without deleting it. Sets `visible: false` while keeping `active: true` so it can be easily re-published.

```
POST /api_manage/v1/:locale/properties/:property_id/spp_unpublish
```

**Headers:** `X-API-Key`, `X-Website-Slug`, `Content-Type: application/json`

**Request Body:**
```json
{
  "listing_type": "sale"
}
```

**Response (200):**
```json
{
  "status": "draft",
  "listingType": "sale",
  "liveUrl": null
}
```

**Errors:**
- `422` — No active SPP listing of that type, or invalid `listing_type`
- `404` — Property not found
- `401` — Missing or invalid API key

---

### 5. Get Property Leads

Retrieve enquiries/messages submitted for a specific property. Use this for the "Leads" tab in your SPP admin UI.

```
GET /api_manage/v1/:locale/properties/:property_id/spp_leads
```

**Headers:** `X-API-Key`, `X-Website-Slug`

**Response (200):**
```json
[
  {
    "id": 42,
    "name": "Jane Doe",
    "email": "jane@example.com",
    "phone": "+34 612 345 678",
    "message": "I am interested in this property. Is it still available?",
    "createdAt": "2026-02-11T14:22:00Z",
    "isNew": true
  },
  {
    "id": 38,
    "name": "John Smith",
    "email": "john@example.com",
    "phone": null,
    "message": "Can I schedule a viewing?",
    "createdAt": "2026-02-10T09:15:00Z",
    "isNew": false
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Message ID |
| `name` | string | Contact name |
| `email` | string | Contact email |
| `phone` | string or null | Phone number (if provided) |
| `message` | string | Enquiry content |
| `createdAt` | ISO 8601 | When the enquiry was submitted |
| `isNew` | boolean | `true` if unread or created within 48 hours |

Returns `[]` (empty array) when no leads exist — not a 404.

Leads are scoped to the property, not the listing type. Enquiries from both sale and rental SPP pages (and PWB itself) appear in the same list.

---

### 6. Update SPP Listing Content

Update the marketing content, price, curated photos, features, template, and settings on an SPP listing. This is for your admin/editor UI.

```
PUT /api_manage/v1/:locale/spp_listings/:spp_listing_id
```

**Note:** The `:locale` in the URL determines which language the translated fields (`title`, `description`, `seo_title`, `meta_description`) are saved under. To update English content, use `/en/`. To update Spanish, use `/es/`.

**Headers:** `X-API-Key`, `X-Website-Slug`, `Content-Type: application/json`

**Request Body** (all fields optional — send only what you want to update):
```json
{
  "title": "Your Dream Mediterranean Retreat",
  "description": "Imagine waking up to the sound of waves...",
  "seo_title": "Luxury Biarritz Apartment for Sale",
  "meta_description": "Stunning 3-bed apartment with sea views in Biarritz...",
  "price_cents": 45000000,
  "price_currency": "EUR",
  "photo_ids_ordered": [42, 17, 3, 28, 11],
  "highlighted_features": ["sea_views", "private_pool", "parking"],
  "template": "luxury",
  "spp_settings": {
    "color_scheme": "dark",
    "layout": "full-width"
  },
  "extra_data": {
    "agent_name": "Marie Dupont",
    "agent_phone": "+33 6 12 34 56 78",
    "video_tour_url": "https://youtube.com/watch?v=abc123"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Marketing headline. Stored per locale via Mobility translations. |
| `description` | string | Marketing body text. Stored per locale. |
| `seo_title` | string | SEO `<title>` tag. Stored per locale. |
| `meta_description` | string | SEO meta description. Stored per locale. |
| `price_cents` | integer | Price in smallest currency unit (e.g., `45000000` = 450,000.00 EUR) |
| `price_currency` | string | ISO 4217 code (e.g., `"EUR"`, `"USD"`, `"GBP"`) |
| `photo_ids_ordered` | array of integers | PropPhoto IDs in the display order you want. Must be photos belonging to the same property. Send `[]` to reset to default order. |
| `highlighted_features` | array of strings | Feature keys to spotlight (e.g., `["sea_views", "pool"]`). Get available keys from the property's features list. |
| `template` | string | SPP template/theme name (e.g., `"luxury"`, `"modern"`, `"minimal"`) |
| `spp_settings` | object | Arbitrary template settings (colors, layout, etc.) |
| `extra_data` | object | Arbitrary JSON for anything else (agent info, video URLs, testimonials) |

**Response (200):**
```json
{
  "id": "spp-listing-uuid",
  "listingType": "sale",
  "title": "Your Dream Mediterranean Retreat",
  "description": "Imagine waking up to the sound of waves...",
  "seoTitle": "Luxury Biarritz Apartment for Sale",
  "metaDescription": "Stunning 3-bed apartment with sea views...",
  "priceCents": 45000000,
  "priceCurrency": "EUR",
  "photoIdsOrdered": [42, 17, 3, 28, 11],
  "highlightedFeatures": ["sea_views", "private_pool", "parking"],
  "template": "luxury",
  "sppSettings": { "color_scheme": "dark", "layout": "full-width" },
  "extraData": { "agent_name": "Marie Dupont", "video_tour_url": "..." },
  "active": true,
  "visible": true,
  "liveUrl": "https://123-main-st-sale.spp.example.com/",
  "publishedAt": "2026-02-12T10:30:00Z",
  "updatedAt": "2026-02-12T11:00:00Z"
}
```

**Photo validation:** If any ID in `photo_ids_ordered` doesn't belong to the listing's property, you get a 422:
```json
{
  "success": false,
  "error": "Invalid photo IDs",
  "message": "Photo IDs 999, 1000 do not belong to this property"
}
```

**Multi-locale workflow:** To save content in multiple languages, make separate requests:
```typescript
// Save English content
await pwbManageApi(`/api_manage/v1/en/spp_listings/${listingId}`, {
  method: 'PUT',
  body: JSON.stringify({ title: 'Mediterranean Retreat', description: '...' }),
});

// Save Spanish content
await pwbManageApi(`/api_manage/v1/es/spp_listings/${listingId}`, {
  method: 'PUT',
  body: JSON.stringify({ title: 'Refugio Mediterraneo', description: '...' }),
});
```

---

### 7. Submit Enquiry (From Browser)

This is the only endpoint called directly from the visitor's browser. When someone fills out the contact form on your SPP page, POST to PWB's public enquiry endpoint.

```
POST /api_public/v1/enquiries
```

**Headers:** `X-Website-Slug`, `Content-Type: application/json` (no API key — this is public)

**Request Body:**
```json
{
  "enquiry": {
    "name": "Jane Doe",
    "email": "jane@example.com",
    "phone": "+34 612 345 678",
    "message": "I am interested in this property. Is it still available?",
    "property_id": "a1b2c3d4-uuid-of-the-property"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `enquiry[name]` | string | Yes | Visitor's name |
| `enquiry[email]` | string | Yes | Visitor's email |
| `enquiry[phone]` | string | No | Visitor's phone |
| `enquiry[message]` | string | Yes | Enquiry text |
| `enquiry[property_id]` | string | Recommended | Property UUID or slug. Links the enquiry to the property so it appears in the leads endpoint. |

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Your message has been sent successfully.",
  "data": {
    "contact_id": 123,
    "message_id": 456
  }
}
```

**Response (422):**
```json
{
  "success": false,
  "errors": ["Email can't be blank", "Content can't be blank"]
}
```

**CORS:** This is a cross-origin request from the browser to PWB. CORS is configured on PWB for `*.spp.propertywebbuilder.com` and `*.workers.dev` origins. If your SPP is on a custom domain, ask the PWB admin to add it.

**Example client-side code:**

```typescript
// components/EnquiryForm.tsx (or .astro)
async function submitEnquiry(formData: {
  name: string;
  email: string;
  phone?: string;
  message: string;
  propertyId: string;
}) {
  const response = await fetch(`${PWB_API_URL}/api_public/v1/enquiries`, {
    method: 'POST',
    headers: {
      'X-Website-Slug': PWB_WEBSITE_SLUG,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      enquiry: {
        name: formData.name,
        email: formData.email,
        phone: formData.phone,
        message: formData.message,
        property_id: formData.propertyId,
      },
    }),
  });

  const result = await response.json();

  if (!result.success) {
    throw new Error(result.errors?.join(', ') || 'Failed to send enquiry');
  }

  return result;
}
```

---

## Error Handling

All error responses follow this shape:

```json
{
  "success": false,
  "error": "Short error description",
  "message": "Detailed explanation (optional)"
}
```

Or for validation errors:
```json
{
  "success": false,
  "error": "Validation failed",
  "errors": ["Title can't be blank", "..."]
}
```

**HTTP status codes you'll encounter:**

| Status | Meaning | What to do |
|--------|---------|------------|
| `200` | Success | Process the response |
| `201` | Created (enquiry) | Show success message |
| `304` | Not Modified | Use your cached version |
| `400` | Bad Request | Missing `X-Website-Slug` header |
| `401` | Unauthorized | Check your `X-API-Key` |
| `404` | Not Found | Property/listing doesn't exist or belongs to different tenant |
| `422` | Unprocessable | Validation error — check the `error`/`errors` field |
| `500` | Server Error | Retry or report to PWB admin |

---

## SEO Requirements

When a property has an active SPP listing, PWB automatically handles these on its end:
- PWB's property page sets `<link rel="canonical">` pointing to your SPP URL
- PWB's sitemap uses your SPP URL instead of its own property page URL
- PWB's JSON-LD structured data uses your SPP URL

**Your SPP pages must handle:**

### Self-Referencing Canonical

Every SPP page must include a self-referencing canonical tag:

```html
<link rel="canonical" href="https://123-main-st-sale.spp.example.com/">
```

### JSON-LD Structured Data

Generate `RealEstateListing` JSON-LD from the property data you fetch from `api_public`. The `url` field must be your SPP page URL (not PWB's):

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "RealEstateListing",
  "url": "https://123-main-st-sale.spp.example.com/",
  "name": "Your Dream Mediterranean Retreat",
  "description": "...",
  "offers": {
    "@type": "Offer",
    "price": "450000",
    "priceCurrency": "EUR"
  }
}
</script>
```

### Meta Tags

Use the `seoTitle` and `metaDescription` from the SppListing (via the update endpoint response) for your `<title>` and `<meta name="description">` tags. Fall back to the property's own title/description if no SPP-specific ones are set.

---

## Caching and Data Freshness

### API Response Caching

PWB sets `Cache-Control` headers on all `api_public` responses:

| Endpoint | `max-age` | Notes |
|----------|-----------|-------|
| Property detail (`/properties/:id`) | 300s (5 min) | Also supports `ETag` / `If-Modified-Since` |
| Property search (`/properties`) | 120s (2 min) | |
| All other api_public | 3600s (1 hour) | Base default |

**Use conditional GET** to avoid re-downloading unchanged data:

```typescript
// Store Last-Modified from previous response
const res = await fetch(url, {
  headers: {
    'If-Modified-Since': lastModified, // From previous response
  },
});

if (res.status === 304) {
  // Data hasn't changed, use cached version
  return cachedData;
}
```

### What Triggers Data Changes

Property data on PWB changes when an agent:
- Updates price, description, or listing fields
- Adds, removes, or reorders photos
- Publishes or unpublishes a listing

With the current cache TTLs, your SPP pages will see updates within 5 minutes for property detail and within 1 hour for other data. There is no webhook/push mechanism yet — poll or rely on cache expiry.

### SppListing Content is Immediate

When you call the update endpoint (`PUT /spp_listings/:id`), the response contains the updated data immediately. Your admin UI should use the response data directly rather than re-fetching.

---

## TypeScript Types

Reference types for the API responses:

```typescript
// Publish / Unpublish response
interface PublishResponse {
  status: 'published' | 'draft';
  listingType: 'sale' | 'rental';
  liveUrl: string | null;
  publishedAt?: string; // ISO 8601, only on publish
}

// Lead from the leads endpoint
interface Lead {
  id: number;
  name: string;
  email: string;
  phone: string | null;
  message: string;
  createdAt: string; // ISO 8601
  isNew: boolean;
}

// SppListing from the update endpoint response
interface SppListing {
  id: string;
  listingType: 'sale' | 'rental';
  title: string | null;
  description: string | null;
  seoTitle: string | null;
  metaDescription: string | null;
  priceCents: number;
  priceCurrency: string;
  photoIdsOrdered: number[];
  highlightedFeatures: string[];
  template: string | null;
  sppSettings: Record<string, unknown>;
  extraData: Record<string, unknown>;
  active: boolean;
  visible: boolean;
  liveUrl: string | null;
  publishedAt: string | null; // ISO 8601
  updatedAt: string; // ISO 8601
}

// Enquiry submission
interface EnquiryRequest {
  enquiry: {
    name: string;
    email: string;
    phone?: string;
    message: string;
    property_id?: string;
  };
}

interface EnquiryResponse {
  success: boolean;
  message?: string;
  errors?: string[];
  data?: {
    contact_id: number;
    message_id: number;
  };
}

// Property summary (from search)
interface PropertySummary {
  id: string;
  slug: string;
  reference: string;
  title: string;
  formatted_price: string;
  currency: string;
  count_bedrooms: number;
  count_bathrooms: number;
  for_sale: boolean;
  for_rent: boolean;
  highlighted: boolean;
  primary_image_url: string;
  prop_photos: Array<{ id: number; sort_order: number; image_url: string }>;
}

// Search response
interface SearchResponse {
  data: PropertySummary[];
  map_markers: Array<{
    id: string;
    lat: number;
    lng: number;
    title: string;
    price: string;
  }>;
  meta: {
    total: number;
    page: number;
    per_page: number;
    total_pages: number;
  };
}
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PWB_API_URL` | Yes | Base URL of the PWB instance (e.g., `https://my-agency.propertywebbuilder.com`) |
| `PWB_API_KEY` | Yes | 64-character hex API key from `spp:provision` |
| `PWB_WEBSITE_SLUG` | Yes | Tenant slug (e.g., `my-agency`) |

**Security:** `PWB_API_KEY` must be server-side only. Never expose it in client-side bundles. `PWB_WEBSITE_SLUG` and `PWB_API_URL` can be exposed to the browser (they're not secrets).

---

## Quick Start Checklist

1. **Get credentials** from PWB admin (`rails spp:provision[subdomain]`)
2. **Set environment variables** (`PWB_API_KEY`, `PWB_WEBSITE_SLUG`, `PWB_API_URL`)
3. **Verify connectivity** by fetching a property:
   ```bash
   curl -H "X-Website-Slug: my-agency" \
        https://my-agency.propertywebbuilder.com/api_public/v1/properties?sale_or_rental=sale
   ```
4. **Verify API key** by calling an api_manage endpoint:
   ```bash
   curl -X POST \
        -H "X-API-Key: your-key-here" \
        -H "X-Website-Slug: my-agency" \
        -H "Content-Type: application/json" \
        -d '{"listing_type": "sale"}' \
        https://my-agency.propertywebbuilder.com/api_manage/v1/en/properties/PROPERTY_UUID/spp_publish
   ```
5. **Build your property page** using data from `GET /api_public/v1/properties/:id`
6. **Add the enquiry form** that POSTs to `/api_public/v1/enquiries`
7. **Add canonical tag** and JSON-LD to your pages
8. **Build the admin UI** using the publish, unpublish, leads, and update endpoints
9. **Test the full flow:** publish a listing, visit the page, submit an enquiry, check leads
