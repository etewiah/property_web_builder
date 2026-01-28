# API Manage: Site Details Endpoint

This document describes how to use the `api_manage/v1/:locale/site_details` API to build a site settings interface in an Astro.js client.

## Overview

The Site Details endpoint provides site-level configuration and metadata for editing clients. It includes branding, localization, SEO defaults, analytics configuration, navigation structure, and field schemas for building settings forms.

**Base URL:** `/api_manage/v1/:locale`

**Authentication:** Currently bypassed for development. TODO: Firebase token or API key authentication.

**Tenant Scoping:** Endpoints are scoped to the current website based on the subdomain.

---

## Endpoints

### Get Site Details

```
GET /api_manage/v1/:locale/site_details
```

**Example:** `GET /api_manage/v1/en/site_details`

**Response:**
```json
{
  "id": 1,
  "subdomain": "demo",

  "branding": {
    "company_name": "Demo Real Estate",
    "logo_url": "https://example.com/logo.png",
    "favicon_url": "https://example.com/favicon.ico",
    "primary_color": "#3B82F6",
    "secondary_color": "#1E40AF",
    "accent_color": "#F59E0B"
  },

  "localization": {
    "default_locale": "en",
    "available_locales": ["en", "es"],
    "current_locale": "en"
  },

  "seo": {
    "default_title": "Demo Real Estate",
    "default_description": "Your trusted partner in real estate",
    "og_image": "https://example.com/logo.png"
  },

  "analytics": {
    "ga4_id": "G-XXXXXXXXXX",
    "gtm_id": "GTM-XXXXXXX",
    "posthog_key": "phc_xxxxx",
    "posthog_host": "https://app.posthog.com"
  },

  "navigation": {
    "top_nav": [
      { "id": 1, "slug": "home", "title": "Home", "path": "/home" },
      { "id": 2, "slug": "properties", "title": "Properties", "path": "/properties" },
      { "id": 3, "slug": "about", "title": "About Us", "path": "/about" }
    ],
    "footer_nav": [
      { "id": 3, "slug": "about", "title": "About Us", "path": "/about" },
      { "id": 4, "slug": "contact", "title": "Contact", "path": "/contact" },
      { "id": 5, "slug": "privacy", "title": "Privacy Policy", "path": "/privacy" }
    ]
  },

  "pages": [
    {
      "id": 1,
      "slug": "home",
      "title": "Home",
      "visible": true,
      "show_in_top_nav": true,
      "show_in_footer": false,
      "updated_at": "2024-01-15T10:30:00Z"
    },
    {
      "id": 2,
      "slug": "about",
      "title": "About Us",
      "visible": true,
      "show_in_top_nav": true,
      "show_in_footer": true,
      "updated_at": "2024-01-14T15:45:00Z"
    }
  ],

  "theme": {
    "name": "starter_starter_a",
    "display_name": "Starter Starter A"
  },

  "field_schema": {
    "fields": [
      {
        "name": "company_display_name",
        "type": "text",
        "label": "Company Name",
        "hint": "Your company or website name displayed in headers and SEO",
        "required": true,
        "component": "TextInput",
        "group": "branding",
        "validation": { "max_length": 100 }
      },
      {
        "name": "default_meta_description",
        "type": "textarea",
        "label": "Default Meta Description",
        "hint": "Default description for SEO (used when pages don't have their own)",
        "component": "TextArea",
        "group": "seo",
        "validation": { "max_length": 160 },
        "content_guidance": {
          "recommended_length": "120-160 characters",
          "seo_tip": "This appears in search results - make it compelling"
        }
      },
      {
        "name": "default_client_locale",
        "type": "select",
        "label": "Default Language",
        "hint": "The primary language for your website",
        "component": "Select",
        "group": "localization",
        "default": "en",
        "choices": [
          { "value": "en", "label": "English" },
          { "value": "es", "label": "Spanish" },
          { "value": "de", "label": "German" },
          { "value": "fr", "label": "French" }
        ]
      },
      {
        "name": "ga4_measurement_id",
        "type": "text",
        "label": "Google Analytics 4 ID",
        "hint": "Your GA4 Measurement ID (e.g., G-XXXXXXXXXX)",
        "placeholder": "G-XXXXXXXXXX",
        "component": "TextInput",
        "group": "analytics",
        "validation": { "max_length": 20 }
      },
      {
        "name": "gtm_container_id",
        "type": "text",
        "label": "Google Tag Manager ID",
        "hint": "Your GTM Container ID (e.g., GTM-XXXXXXX)",
        "placeholder": "GTM-XXXXXXX",
        "component": "TextInput",
        "group": "analytics",
        "validation": { "max_length": 20 }
      },
      {
        "name": "posthog_api_key",
        "type": "text",
        "label": "PostHog API Key",
        "hint": "Your PostHog project API key for analytics",
        "component": "TextInput",
        "group": "analytics",
        "validation": { "max_length": 100 }
      },
      {
        "name": "posthog_host",
        "type": "url",
        "label": "PostHog Host",
        "hint": "PostHog instance URL (leave empty for cloud)",
        "placeholder": "https://app.posthog.com",
        "component": "UrlInput",
        "group": "analytics"
      }
    ],
    "groups": [
      { "key": "branding", "label": "Branding", "order": 1 },
      { "key": "seo", "label": "SEO Settings", "order": 2 },
      { "key": "localization", "label": "Language", "order": 3 },
      { "key": "analytics", "label": "Analytics", "order": 4 }
    ]
  },

  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

---

### Update Site Settings

```
PATCH /api_manage/v1/:locale/site_details
Content-Type: application/json
```

**Request Body:**
```json
{
  "site": {
    "company_display_name": "Updated Company Name",
    "default_meta_description": "Updated description for SEO",
    "default_client_locale": "es",
    "ga4_measurement_id": "G-NEWID12345",
    "gtm_container_id": "GTM-NEWID",
    "posthog_api_key": "phc_newkey",
    "posthog_host": "https://app.posthog.com"
  }
}
```

**Updateable Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `company_display_name` | string | Company name for branding and SEO |
| `default_meta_description` | string | Default meta description (max 160 chars) |
| `default_client_locale` | string | Default language (en, es, de, fr, etc.) |
| `ga4_measurement_id` | string | Google Analytics 4 ID (G-XXXXXXXXXX) |
| `gtm_container_id` | string | Google Tag Manager ID (GTM-XXXXXXX) |
| `posthog_api_key` | string | PostHog project API key |
| `posthog_host` | string | PostHog instance URL |

**Success Response:**
```json
{
  "site": { /* full site details object */ },
  "message": "Site settings updated successfully"
}
```

**Error Response (422):**
```json
{
  "error": "Validation failed",
  "errors": ["Company display name can't be blank"]
}
```

---

## Response Fields

### branding

Site branding configuration including company name, logo, and theme colors.

| Field | Type | Description |
|-------|------|-------------|
| `company_name` | string | Display name for the company |
| `logo_url` | string | URL to the main logo image |
| `favicon_url` | string | URL to the favicon |
| `primary_color` | string | Primary theme color (hex) |
| `secondary_color` | string | Secondary theme color (hex) |
| `accent_color` | string | Accent theme color (hex) |

### localization

Language and locale settings.

| Field | Type | Description |
|-------|------|-------------|
| `default_locale` | string | Default language code (e.g., "en") |
| `available_locales` | array | List of supported locale codes |
| `current_locale` | string | Currently active locale |

### seo

Default SEO settings applied when pages don't have their own.

| Field | Type | Description |
|-------|------|-------------|
| `default_title` | string | Default page title for SEO |
| `default_description` | string | Default meta description |
| `og_image` | string | Default Open Graph image URL |

### analytics

Third-party analytics integration settings. Only includes configured services.

| Field | Type | Description |
|-------|------|-------------|
| `ga4_id` | string | Google Analytics 4 Measurement ID |
| `gtm_id` | string | Google Tag Manager Container ID |
| `posthog_key` | string | PostHog project API key |
| `posthog_host` | string | PostHog instance URL |

### navigation

Current navigation structure based on page visibility settings.

| Field | Type | Description |
|-------|------|-------------|
| `top_nav` | array | Pages visible in top navigation |
| `footer_nav` | array | Pages visible in footer navigation |

Each navigation item contains:
- `id`: Page ID
- `slug`: URL slug
- `title`: Display title
- `path`: Full URL path

### pages

Summary of all pages for the site, useful for building page management interfaces.

### theme

Current theme information.

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Theme identifier |
| `display_name` | string | Human-readable theme name |

### field_schema

Schema for building settings forms. See [Field Type System](../field_keys/field_type_system.md) for complete documentation.

---

## Astro.js Implementation

### 1. API Client

```typescript
// src/lib/api.ts

export const siteApi = {
  getDetails: (locale: string) =>
    apiClient<SiteDetails>(`/${locale}/site_details`),

  update: (locale: string, data: Partial<SiteSettings>) =>
    apiClient<{ site: SiteDetails; message: string }>(
      `/${locale}/site_details`,
      {
        method: 'PATCH',
        body: JSON.stringify({ site: data }),
      }
    ),
};
```

### 2. TypeScript Types

```typescript
// src/types/site.ts

export interface SiteDetails {
  id: number;
  subdomain: string;
  branding: SiteBranding;
  localization: SiteLocalization;
  seo: SiteSeo;
  analytics?: SiteAnalytics;
  navigation: SiteNavigation;
  pages: PageSummary[];
  theme: ThemeInfo;
  field_schema: FieldSchema;
  created_at: string;
  updated_at: string;
}

export interface SiteBranding {
  company_name?: string;
  logo_url?: string;
  favicon_url?: string;
  primary_color?: string;
  secondary_color?: string;
  accent_color?: string;
}

export interface SiteLocalization {
  default_locale: string;
  available_locales: string[];
  current_locale: string;
}

export interface SiteSeo {
  default_title?: string;
  default_description?: string;
  og_image?: string;
}

export interface SiteAnalytics {
  ga4_id?: string;
  gtm_id?: string;
  posthog_key?: string;
  posthog_host?: string;
}

export interface SiteNavigation {
  top_nav: NavItem[];
  footer_nav: NavItem[];
}

export interface NavItem {
  id: number;
  slug: string;
  title: string;
  path: string;
}

export interface PageSummary {
  id: number;
  slug: string;
  title: string;
  visible: boolean;
  show_in_top_nav: boolean;
  show_in_footer: boolean;
  updated_at: string;
}

export interface ThemeInfo {
  name: string;
  display_name: string;
}

export interface SiteSettings {
  company_display_name: string;
  default_meta_description: string;
  default_client_locale: string;
  ga4_measurement_id: string;
  gtm_container_id: string;
  posthog_api_key: string;
  posthog_host: string;
}
```

### 3. Settings Form Component

```tsx
// src/components/admin/SiteSettingsForm.tsx
import { useState, useEffect } from 'react';
import { siteApi } from '@/lib/api';
import type { SiteDetails, SiteSettings } from '@/types/site';
import { renderFieldBySchema } from '@/components/admin/FieldRenderer';

interface Props {
  locale: string;
}

export default function SiteSettingsForm({ locale }: Props) {
  const [site, setSite] = useState<SiteDetails | null>(null);
  const [formData, setFormData] = useState<Partial<SiteSettings>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    async function loadSite() {
      const { data } = await siteApi.getDetails(locale);
      if (data) {
        setSite(data);
        // Initialize form from current values
        setFormData({
          company_display_name: data.branding.company_name || '',
          default_meta_description: data.seo.default_description || '',
          default_client_locale: data.localization.default_locale,
          ga4_measurement_id: data.analytics?.ga4_id || '',
          gtm_container_id: data.analytics?.gtm_id || '',
          posthog_api_key: data.analytics?.posthog_key || '',
          posthog_host: data.analytics?.posthog_host || '',
        });
      }
      setLoading(false);
    }
    loadSite();
  }, [locale]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    const { data, error } = await siteApi.update(locale, formData);
    if (data) {
      setSite(data.site);
    }

    setSaving(false);
  }

  if (loading || !site) return <div>Loading...</div>;

  // Group fields by their group key
  const fieldsByGroup = site.field_schema.fields.reduce((acc, field) => {
    const group = field.group || 'general';
    if (!acc[group]) acc[group] = [];
    acc[group].push(field);
    return acc;
  }, {} as Record<string, typeof site.field_schema.fields>);

  return (
    <form onSubmit={handleSubmit}>
      {site.field_schema.groups
        .sort((a, b) => a.order - b.order)
        .map((group) => (
          <div key={group.key} className="mb-8">
            <h2 className="text-lg font-bold mb-4">{group.label}</h2>
            <div className="space-y-4">
              {fieldsByGroup[group.key]?.map((field) =>
                renderFieldBySchema(field, formData, setFormData)
              )}
            </div>
          </div>
        ))}

      <button
        type="submit"
        disabled={saving}
        className="px-4 py-2 bg-blue-600 text-white rounded"
      >
        {saving ? 'Saving...' : 'Save Settings'}
      </button>
    </form>
  );
}
```

---

## Error Handling

| Status | Meaning | Example Response |
|--------|---------|------------------|
| 200 | Success | `{ "site": {...}, "message": "..." }` |
| 404 | Website not found | `{ "error": "Website not found" }` |
| 422 | Validation failed | `{ "error": "Validation failed", "errors": ["..."] }` |

---

## Related Endpoints

- `GET /api_manage/v1/:locale/pages` - List all pages
- `GET /api_manage/v1/:locale/pages/:id` - Get page details
- `GET /api_manage/v1/:locale/pages/by_slug/:slug` - Get page by slug
- `GET /api_public/v1/:locale/site_details` - Public site info (read-only)

---

## Notes

1. **Locale Prefix**: All api_manage endpoints require a locale prefix (e.g., `/en/`, `/es/`). This matches the api_public pattern for consistency.

2. **Tenant Scoping**: Requests are scoped based on the subdomain in the request host.

3. **Theme Colors**: Colors come from the website's `style_variables_for_theme` configuration, not from direct database columns.

4. **Analytics**: The `analytics` field is only present if at least one analytics service is configured. Individual keys are only included if they have values.

5. **Field Schema**: Use the field_schema to dynamically generate settings forms. Each field includes its type, validation rules, and UI hints.
