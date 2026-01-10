# Backend API Integration Analysis

Last Updated: 2026-01-10

## Executive Summary

**Current Status**: ⚠️ **PARTIALLY COMPLIANT** - The Next.js client correctly fetches most data from the backend API, but has critical gaps in theming and some translation handling.

### What's Correct ✅

- Property listings and details come from API
- Property images come from API
- Site settings (name, logo, contact info) come from API
- Navigation links come from API
- Basic page content comes from API
- Property photos come from API

### What's Wrong ❌

- **Theming**: Colors NOT pulled from backend (hardcoded in Tailwind)
- **Translations**: Hybrid approach - some bundled, some from API
- **Testimonials**: Hardcoded in frontend (should be dynamic)
- **Homepage sections**: Partially hardcoded (Hero partially dynamic, others static)

---

## Detailed Analysis by Data Type

### 1. Properties ✅ **CORRECT**

**Implementation**: `src/lib/api/properties.ts`

All property data correctly comes from the backend API:

```typescript
// ✅ CORRECT: Properties fetched from API
GET /api_public/v1/properties
GET /api_public/v1/properties/:slug
GET /api_public/v1/properties/:id
```

**Data Retrieved from API:**
- Property listings with pagination
- Individual property details
- Property metadata (title, description, price, etc.)
- Property photos (URLs from backend)
- Property location (lat/lng)
- Property features
- Property type, bedrooms, bathrooms, etc.

**Files Using This:**
- `src/app/[locale]/properties/page.tsx` - Property search page
- `src/app/[locale]/properties/[slug]/page.tsx` - Property detail page
- `src/app/[locale]/page.tsx` - Homepage featured properties

**Type Definition**: `src/types/property.ts:13-42`

### 2. Property Images ✅ **CORRECT**

**Implementation**: Property images are correctly fetched from API via the `prop_photos` array.

```typescript
// ✅ CORRECT: Image URLs come from API
export interface PropertyPhoto {
  id: number;
  image: string;        // ← Backend URL
  thumbnail?: string;   // ← Backend URL
  position?: number;
}
```

**Files Using This:**
- Property cards in grid views
- Property detail galleries
- Featured property sections

**Type Definition**: `src/types/property.ts:6-11`

### 3. Site Settings ✅ **MOSTLY CORRECT**

**Implementation**: `src/lib/api/site.ts:18-20`

```typescript
// ✅ CORRECT: Fetches site config from API
GET /api_public/v1/site_details
```

**Data Retrieved from API:**
- ✅ Site name
- ✅ Logo URL
- ✅ Contact email
- ✅ Contact phone
- ✅ Default currency
- ✅ Default area unit
- ✅ Supported locales
- ✅ Default locale
- ✅ Social media links
- ⚠️ Primary color (fetched but NOT used for theming)
- ⚠️ Secondary color (fetched but NOT used for theming)

**Type Definition**: `src/types/site.ts:6-23`

**Usage**: `src/app/[locale]/layout.tsx:37-41`

### 4. Navigation Links ✅ **CORRECT**

**Implementation**: `src/lib/api/site.ts:25-30`

```typescript
// ✅ CORRECT: Navigation from API
GET /api_public/v1/links?position=top_nav
GET /api_public/v1/links?position=footer
```

**Data Retrieved:**
- Link title
- Link URL
- Position (top_nav/footer)
- Order
- Visibility
- External flag

**Type Definition**: `src/types/site.ts:25-33`

**Usage**:
- `src/components/layout/Header.tsx:54-68`
- `src/components/layout/Footer.tsx` (similar pattern)

### 5. Pages/Content ✅ **CORRECT**

**Implementation**: `src/lib/api/site.ts:46-62`

```typescript
// ✅ CORRECT: Dynamic pages from API
GET /api_public/v1/pages/by_slug/:slug?locale=:locale
GET /api_public/v1/pages/:id?locale=:locale
```

**Data Retrieved:**
- Page slug
- Page title
- Meta title/description
- Page parts (content blocks)

**Type Definition**: `src/types/site.ts:43-50`

**Usage**:
- `src/app/[locale]/[slug]/page.tsx` - Dynamic pages
- `src/app/[locale]/page.tsx:59-61` - Homepage content

### 6. Translations ⚠️ **HYBRID APPROACH** (Potentially Problematic)

**Implementation**: `src/i18n/request.ts:37-65`

**Current Approach:**
1. ✅ Loads bundled translations from `src/messages/{locale}.json`
2. ✅ Fetches dynamic translations from API: `GET /api_public/v1/translations?locale=:locale`
3. ✅ Deep merges API translations over bundled ones

```typescript
// ⚠️ HYBRID: Bundled + API translations
const baseMessages = await import(`../messages/${resolvedLocale}.json`);
const apiTranslations = await getTranslations(resolvedLocale);
const merged = deepMerge(baseMessages, apiTranslations);
```

**Bundled Translations** (`src/messages/en.json`):
- Common UI strings (nav, actions)
- Layout strings (header, footer)
- Property detail labels
- Contact form labels
- Error messages

**Problem**: If backend should be the source of truth for ALL translations, this is incorrect.

**Question for Backend Implementation**:
> Should ALL translations come from the backend, or is it acceptable to have:
> - Common UI framework strings bundled in frontend
> - Content/business strings from backend API?

### 7. Theming/Colors ❌ **INCORRECT** - Critical Gap

**Current Implementation**: Colors are defined in `tailwind.config.ts:11-18`

```typescript
// ❌ WRONG: Colors are hardcoded in Tailwind config
colors: {
  background: "var(--background)",
  foreground: "var(--foreground)",
  primary: "var(--primary)",
  "primary-foreground": "var(--primary-foreground)",
  muted: "var(--muted)",
  "muted-foreground": "var(--muted-foreground)",
}
```

**Backend API Provides:**
```typescript
// ✅ API returns colors, but NOT used
interface SiteDetails {
  primary_color: string;      // e.g., "#3B82F6"
  secondary_color?: string;   // e.g., "#10B981"
}
```

**Problem**: The frontend fetches `primary_color` and `secondary_color` from the API but does NOT apply them to the site theme.

**Files Affected**:
- `src/types/site.ts:9-10` - Type defines colors
- `src/lib/api/site.ts:18-20` - API fetches colors
- `src/app/[locale]/layout.tsx:37-41` - Receives colors but doesn't use them
- `tailwind.config.ts` - Uses hardcoded CSS variables instead

### 8. Select Values (Dropdowns) ✅ **CORRECT**

**Implementation**: `src/lib/api/site.ts:67-126`

```typescript
// ✅ CORRECT: Property types, etc. from API
GET /api_public/v1/select_values
```

**Data Retrieved:**
- Property types (house, apartment, villa, etc.)
- Other dropdown options
- Localized labels

**Type Definition**: `src/types/site.ts:52-59`

### 9. Homepage Sections ⚠️ **PARTIALLY HARDCODED**

**Current Implementation**: `src/app/[locale]/page.tsx`

**What's Dynamic (✅ CORRECT):**
- Featured properties from API (`src/app/[locale]/page.tsx:61`)
- Hero content from page parts (`src/app/[locale]/page.tsx:71-80`)
  - Title, subtitle, background image, CTA from API
  - Falls back to bundled translations if no page parts

**What's Hardcoded (❌ WRONG):**
- Testimonials section (`src/app/[locale]/page.tsx:138-155`)
  - Testimonials are hardcoded translation strings, not dynamic data from API
- CTA section partially static
- Section visibility is not controlled by backend

**Example of Hardcoded Testimonials:**
```typescript
// ❌ WRONG: Testimonials are static translations
testimonials={[
  {
    quote: t('t1Quote'),      // ← From bundled JSON
    name: t('t1Name'),        // ← From bundled JSON
    title: t('t1Role'),       // ← From bundled JSON
  },
  // ...
]}
```

**Should Be**: Testimonials should come from backend API (e.g., `GET /api_public/v1/testimonials`)

---

## Backend API Requirements

Based on the analysis, here's what the backend API MUST provide:

### ✅ Already Implemented Endpoints

1. **`GET /api_public/v1/site_details`**
   - Returns site configuration
   - Required fields:
     ```json
     {
       "name": "Site Name",
       "logo_url": "https://...",
       "primary_color": "#3B82F6",
       "secondary_color": "#10B981",
       "contact_email": "info@example.com",
       "contact_phone": "+1234567890",
       "default_currency": "EUR",
       "default_area_unit": "sqm",
       "locales": ["en", "es", "ru"],
       "default_locale": "en",
       "social_links": {
         "facebook": "https://...",
         "twitter": "https://...",
         "instagram": "https://...",
         "linkedin": "https://..."
       }
     }
     ```

2. **`GET /api_public/v1/properties`**
   - Query params: `locale`, `page`, `per_page`, `sale_or_rental`, `property_type`, `for_sale_price_from`, `for_sale_price_till`, `for_rent_price_from`, `for_rent_price_till`, `bedrooms_from`, `bathrooms_from`
   - Returns paginated property list
   - Required response:
     ```json
     {
       "properties": [
         {
           "id": 1,
           "slug": "luxury-villa-marbella",
           "title": "Luxury Villa in Marbella",
           "description": "...",
           "price_sale_current_cents": 150000000,
           "price_rental_monthly_current_cents": null,
           "currency": "EUR",
           "area_unit": "sqm",
           "constructed_area": 450,
           "plot_area": 1200,
           "count_bedrooms": 5,
           "count_bathrooms": 4,
           "count_garages": 2,
           "for_sale": true,
           "for_rent": false,
           "latitude": 36.5108,
           "longitude": -4.8826,
           "address": "Calle Example 123",
           "city": "Marbella",
           "region": "Andalusia",
           "country": "Spain",
           "postal_code": "29600",
           "property_type": "villa",
           "reference": "VIL-001",
           "year_construction": 2020,
           "featured": true,
           "visible": true,
           "prop_photos": [
             {
               "id": 1,
               "image": "https://cdn.example.com/image1.jpg",
               "thumbnail": "https://cdn.example.com/image1_thumb.jpg",
               "position": 1
             }
           ]
         }
       ],
       "meta": {
         "total": 150,
         "page": 1,
         "per_page": 12,
         "total_pages": 13
       }
     }
     ```

3. **`GET /api_public/v1/properties/:slug`**
   - Returns single property by slug
   - Same schema as properties array item, plus:
     ```json
     {
       "features": ["Swimming Pool", "Garden", "Sea View"],
       "nearby_places": ["Beach - 500m", "Golf Course - 2km"],
       "agent": {
         "name": "John Doe",
         "email": "john@example.com",
         "phone": "+1234567890",
         "photo": "https://..."
       }
     }
     ```

4. **`GET /api_public/v1/links?position={top_nav|footer}`**
   - Returns navigation links
   - Required response:
     ```json
     [
       {
         "id": 1,
         "title": "Properties",
         "url": "/properties",
         "position": "top_nav",
         "order": 1,
         "visible": true,
         "external": false
       }
     ]
     ```

5. **`GET /api_public/v1/pages/by_slug/:slug?locale=:locale`**
   - Returns page content
   - Required response:
     ```json
     {
       "id": 1,
       "slug": "home",
       "title": "Home",
       "meta_title": "Welcome to Property Site",
       "meta_description": "Find your dream property",
       "page_parts": [
         {
           "key": "hero",
           "part_type": "hero_section",
           "content": {
             "title": "Find Your Dream Property",
             "subtitle": "Browse our exclusive listings",
             "background_image": "https://...",
             "cta_text": "View Properties",
             "cta_link": "/properties"
           },
           "position": 1,
           "visible": true
         }
       ]
     }
     ```

6. **`GET /api_public/v1/select_values`**
   - Returns dropdown options for forms
   - Required response (flexible format):
     ```json
     {
       "select_values": {
         "property_type": {
           "label": "Property Type",
           "values": [
             {"value": "house", "label": "House"},
             {"value": "apartment", "label": "Apartment"},
             {"value": "villa", "label": "Villa"}
           ]
         }
       }
     }
     ```

7. **`GET /api_public/v1/translations?locale=:locale`**
   - Returns translations for UI strings
   - Required response:
     ```json
     {
       "translations": {
         "Common.nav.home": "Home",
         "Common.nav.properties": "Properties",
         "PropertyDetail.forSale": "For Sale",
         "PropertyDetail.description": "Description"
       }
     }
     ```

### ❌ Missing Backend Endpoints (Need Implementation)

#### 1. **Theme Configuration Endpoint** - CRITICAL

**Endpoint**: `GET /api_public/v1/theme`

**Purpose**: Provide dynamic theming data for multi-tenant sites

**Required Response**:
```json
{
  "theme_name": "luxury",
  "colors": {
    "primary": "#3B82F6",
    "primary_foreground": "#FFFFFF",
    "secondary": "#10B981",
    "secondary_foreground": "#FFFFFF",
    "background": "#FFFFFF",
    "foreground": "#1F2937",
    "muted": "#F3F4F6",
    "muted_foreground": "#6B7280",
    "accent": "#F59E0B",
    "accent_foreground": "#FFFFFF",
    "destructive": "#EF4444",
    "destructive_foreground": "#FFFFFF",
    "border": "#E5E7EB",
    "input": "#E5E7EB",
    "ring": "#3B82F6"
  },
  "fonts": {
    "heading": "Playfair Display",
    "body": "Inter"
  },
  "border_radius": {
    "sm": "0.25rem",
    "md": "0.5rem",
    "lg": "0.75rem",
    "xl": "1rem"
  },
  "custom_css": "/* Additional CSS overrides */"
}
```

**Frontend Usage**:
- Inject CSS variables into `<head>` on server-side
- Apply to Tailwind config dynamically
- Allow per-tenant customization

**Implementation Priority**: **HIGH** - Blocker for multi-tenant theming

#### 2. **Testimonials Endpoint** - RECOMMENDED

**Endpoint**: `GET /api_public/v1/testimonials?locale=:locale`

**Purpose**: Dynamic testimonials instead of hardcoded ones

**Required Response**:
```json
{
  "testimonials": [
    {
      "id": 1,
      "quote": "Great service and super responsive. We found a perfect place quickly.",
      "author_name": "Alex M.",
      "author_role": "Buyer",
      "author_photo": "https://...",
      "rating": 5,
      "visible": true,
      "position": 1
    }
  ]
}
```

**Frontend Usage**:
- `src/app/[locale]/page.tsx` - Homepage testimonials section
- Allow backend to control which testimonials show and in what order

**Implementation Priority**: **MEDIUM** - Improves content flexibility

#### 3. **Homepage Sections Configuration** - OPTIONAL

**Endpoint**: `GET /api_public/v1/homepage_sections?locale=:locale`

**Purpose**: Control homepage layout and content from backend

**Required Response**:
```json
{
  "sections": [
    {
      "type": "hero",
      "visible": true,
      "position": 1,
      "content": {
        "title": "Find Your Dream Property",
        "subtitle": "Browse our exclusive listings",
        "background_image": "https://...",
        "cta_text": "View Properties",
        "cta_link": "/properties"
      }
    },
    {
      "type": "featured_properties",
      "visible": true,
      "position": 2,
      "content": {
        "title": "Featured Properties",
        "subtitle": "Discover our handpicked selection",
        "limit": 6
      }
    },
    {
      "type": "testimonials",
      "visible": true,
      "position": 3,
      "content": {
        "title": "What our clients say",
        "subtitle": "A few words from people we've helped"
      }
    },
    {
      "type": "cta",
      "visible": true,
      "position": 4,
      "content": {
        "title": "Ready to Find Your Perfect Home?",
        "subtitle": "Contact us today",
        "primary_text": "Browse Listings",
        "primary_link": "/properties",
        "secondary_text": "Contact Us",
        "secondary_link": "/contact"
      }
    }
  ]
}
```

**Frontend Usage**:
- Replace hardcoded homepage sections with dynamic rendering
- Allow backend to control section visibility and order

**Implementation Priority**: **LOW** - Nice to have, current approach works

#### 4. **Agent/Staff Endpoint** - OPTIONAL

**Endpoint**: `GET /api_public/v1/agents`

**Purpose**: Display team members on about/contact pages

**Required Response**:
```json
{
  "agents": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "phone": "+1234567890",
      "photo": "https://...",
      "title": "Senior Property Consultant",
      "bio": "With over 15 years of experience...",
      "specialties": ["Luxury Properties", "Commercial Real Estate"],
      "visible": true
    }
  ]
}
```

**Implementation Priority**: **LOW** - Not yet needed

---

## Critical Issues to Fix

### Issue 1: Theming Not Applied from Backend ⚠️ HIGH PRIORITY

**Problem**: Backend API returns `primary_color` and `secondary_color`, but frontend doesn't use them.

**Current Code** (`src/app/[locale]/layout.tsx:37-41`):
```typescript
const [siteDetails] = await Promise.all([
  getSiteDetails(),  // ← Fetches primary_color
  // ...
]);
// But siteDetails.primary_color is NEVER used for theming
```

**Solution Required**:

1. **Option A: Server-Side CSS Injection** (Recommended)
   - In `layout.tsx`, inject CSS variables from `siteDetails.primary_color`
   - Example:
     ```typescript
     <head>
       <style dangerouslySetInnerHTML={{
         __html: `
           :root {
             --primary: ${siteDetails.primary_color};
             --secondary: ${siteDetails.secondary_color || siteDetails.primary_color};
           }
         `
       }} />
     </head>
     ```

2. **Option B: Full Theme Endpoint** (Better for multi-tenant)
   - Backend provides complete theme configuration via new endpoint
   - Frontend applies all color tokens, fonts, border radius, etc.
   - See "Theme Configuration Endpoint" above

**Files to Modify**:
- `src/app/[locale]/layout.tsx` - Inject CSS variables
- `src/types/site.ts` - Expand theme type if using Option B
- `src/lib/api/site.ts` - Add `getTheme()` if using Option B

### Issue 2: Testimonials Hardcoded ⚠️ MEDIUM PRIORITY

**Problem**: Testimonials are translation strings, not dynamic backend data.

**Current Code** (`src/app/[locale]/page.tsx:138-155`):
```typescript
testimonials={[
  { quote: t('t1Quote'), name: t('t1Name'), title: t('t1Role') },
  // ← These are bundled JSON strings, not API data
]}
```

**Solution Required**:
1. Create backend endpoint: `GET /api_public/v1/testimonials`
2. Add frontend API function in `src/lib/api/site.ts`
3. Fetch testimonials in `page.tsx` like featured properties
4. Remove hardcoded testimonials from `src/messages/en.json`

**Files to Modify**:
- Add `src/lib/api/site.ts::getTestimonials()`
- Modify `src/app/[locale]/page.tsx` to fetch from API
- Add type `src/types/site.ts::Testimonial`

### Issue 3: Translation Strategy Unclear ⚠️ LOW PRIORITY

**Problem**: Hybrid approach (bundled + API) may not align with backend expectations.

**Question**: Should the backend provide ALL translations, or is the current hybrid approach acceptable?

**Current Approach**:
- Frontend bundles common UI strings (`Common.nav.home`, etc.)
- Backend overrides with content strings via API
- Deep merge combines both

**Alternative Approach**:
- Backend provides ALL strings via `/api_public/v1/translations`
- Frontend has minimal fallbacks for when API is unreachable

**Decision Needed**: Clarify backend translation strategy

---

## Implementation Checklist

### For Frontend Team

- [ ] Fix theming: Apply `primary_color` from API to Tailwind CSS variables
- [ ] Implement full theme endpoint integration (if backend provides it)
- [ ] Replace hardcoded testimonials with API call
- [ ] Add `getTheme()` to `src/lib/api/site.ts`
- [ ] Add `getTestimonials()` to `src/lib/api/site.ts`
- [ ] Update types in `src/types/site.ts` for theme and testimonials
- [ ] Test theme switching with multiple tenant configurations
- [ ] Document theme CSS variable injection

### For Backend Team

- [ ] **CRITICAL**: Verify `/api_public/v1/site_details` returns `primary_color` and `secondary_color`
- [ ] **HIGH**: Implement `/api_public/v1/theme` endpoint (or expand `site_details` to include full theme)
- [ ] **MEDIUM**: Implement `/api_public/v1/testimonials` endpoint
- [ ] **OPTIONAL**: Implement `/api_public/v1/homepage_sections` for dynamic layout control
- [ ] Confirm translation strategy: Should ALL strings come from API?
- [ ] Document all public API endpoints with example responses
- [ ] Add API versioning strategy (currently using `/api_public/v1`)

---

## API Response Format Standards

Based on the current implementation, the backend API uses inconsistent response wrapping. The frontend handles this with "unwrap" logic:

```typescript
// Current frontend unwrap logic (src/lib/api/properties.ts:65-69)
const unwrap = (value: unknown): unknown => {
  const record = value as Record<string, unknown>;
  return record.data ?? record.payload ?? record.result ?? record;
};
```

**Recommendation for Backend**: Standardize on one response format:

### Recommended Format

```json
{
  "data": { /* main payload */ },
  "meta": { /* pagination or other metadata */ },
  "errors": [ /* validation errors if any */ ]
}
```

**Example**:
```json
{
  "data": {
    "properties": [...],
  },
  "meta": {
    "total": 150,
    "page": 1,
    "per_page": 12,
    "total_pages": 13
  }
}
```

This would eliminate the need for "unwrap" logic and make the API more predictable.

---

## Summary

### What's Working Well ✅

1. Property data fully from API
2. Property images from API
3. Site settings (name, logo, contact) from API
4. Navigation from API
5. Page content from API
6. API client architecture is solid

### What Needs Fixing ❌

1. **CRITICAL**: Theming colors fetched but not applied
2. **HIGH**: Need dedicated theme endpoint for full multi-tenant theming
3. **MEDIUM**: Testimonials hardcoded instead of dynamic
4. **LOW**: Translation strategy should be clarified

### Backend API Coverage

- **Implemented Endpoints**: ~85% of what's needed
- **Missing Endpoints**: Theme, Testimonials (critical for multi-tenant)
- **Endpoint Quality**: Good, but response formats could be more consistent

### Recommended Next Steps

1. **Immediate**: Implement CSS variable injection for `primary_color` from existing API
2. **Short-term**: Create full `/api_public/v1/theme` endpoint
3. **Medium-term**: Add testimonials endpoint
4. **Long-term**: Consider homepage section configuration endpoint

The architecture is sound, but the theming gap is a blocker for production multi-tenant use.
