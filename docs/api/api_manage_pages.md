# API Manage: Pages Endpoint

This document describes how to use the `api_manage/v1/pages` API to build a page settings interface in an Astro.js client, replicating the functionality at `/site_admin/pages/:id/settings`.

## Overview

The `api_manage` namespace provides authenticated CRUD operations for managing website content. These endpoints are designed for external admin UIs built with frameworks like Astro.js.

**Base URL:** `/api_manage/v1/:locale`

**Authentication:** Currently bypassed for development. TODO: Firebase token or API key authentication.

**Tenant Scoping:** Endpoints are scoped to the current website based on the subdomain.

**Locale Prefix:** All endpoints require a locale prefix (e.g., `/en/`, `/es/`). This matches the api_public pattern for consistency.

---

## Endpoints

### List All Pages

```
GET /api_manage/v1/:locale/pages
```

**Example:** `GET /api_manage/v1/en/pages`

**Response:**
```json
{
  "pages": [
    {
      "id": 1,
      "slug": "home",
      "title": "Home",
      "visible": true,
      "show_in_top_nav": true,
      "show_in_footer": false,
      "sort_order_top_nav": 1,
      "sort_order_footer": 0,
      "updated_at": "2024-01-15T10:30:00Z"
    },
    {
      "id": 8,
      "slug": "about-us",
      "title": "About Us",
      "visible": true,
      "show_in_top_nav": true,
      "show_in_footer": true,
      "sort_order_top_nav": 2,
      "sort_order_footer": 1,
      "updated_at": "2024-01-14T15:45:00Z"
    }
  ]
}
```

---

### Get Page Details

```
GET /api_manage/v1/:locale/pages/:id
```

**Example:** `GET /api_manage/v1/en/pages/8`

**Response:**
```json
{
  "page": {
    "id": 8,
    "slug": "about-us",
    "title": "About Us",
    "visible": true,
    "show_in_top_nav": true,
    "show_in_footer": true,
    "sort_order_top_nav": 2,
    "sort_order_footer": 1,
    "seo_title": "About Our Real Estate Agency | Your Trusted Partner",
    "meta_description": "Learn about our experienced team of real estate professionals...",
    "meta_keywords": "real estate, agency, about us",
    "page_parts": [
      {
        "id": 15,
        "page_part_key": "heroes/hero_centered",
        "order_in_editor": 0,
        "show_in_editor": true
      },
      {
        "id": 16,
        "page_part_key": "content/our_agency",
        "order_in_editor": 1,
        "show_in_editor": true
      }
    ],
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-14T15:45:00Z"
  }
}
```

---

### Get Page by Slug

```
GET /api_manage/v1/:locale/pages/by_slug/:slug
```

**Example:** `GET /api_manage/v1/en/pages/by_slug/about-us`

**Response:** Same as Get Page Details above.

---

### Update Page Settings

```
PATCH /api_manage/v1/:locale/pages/:id
Content-Type: application/json
```

**Example:** `PATCH /api_manage/v1/en/pages/8`

**Request Body:**
```json
{
  "page": {
    "slug": "about-us",
    "visible": true,
    "show_in_top_nav": true,
    "show_in_footer": true,
    "sort_order_top_nav": 2,
    "sort_order_footer": 1,
    "seo_title": "About Our Agency",
    "meta_description": "Learn about our team...",
    "meta_keywords": "real estate, agency"
  }
}
```

**Updateable Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `slug` | string | URL-friendly identifier (e.g., "about-us") |
| `visible` | boolean | Show page in navigation |
| `show_in_top_nav` | boolean | Display in top navigation menu |
| `show_in_footer` | boolean | Display in footer navigation |
| `sort_order_top_nav` | integer | Sort position in top nav (lower = first) |
| `sort_order_footer` | integer | Sort position in footer (lower = first) |
| `seo_title` | string | Custom SEO title (50-60 chars recommended) |
| `meta_description` | string | Meta description (150-160 chars recommended) |
| `meta_keywords` | string | Comma-separated keywords |

**Success Response:**
```json
{
  "page": { /* updated page object */ },
  "message": "Page updated successfully"
}
```

**Error Response (422):**
```json
{
  "error": "Validation failed",
  "errors": ["Slug can't be blank", "Slug has already been taken"]
}
```

---

### Reorder Page Parts

```
PATCH /api_manage/v1/:locale/pages/:id/reorder_parts
Content-Type: application/json
```

**Example:** `PATCH /api_manage/v1/en/pages/8/reorder_parts`

**Request Body:**
```json
{
  "part_ids": [16, 15, 17]
}
```

The order of IDs in the array determines the new order (index 0 = first).

**Response:**
```json
{
  "message": "Page parts reordered successfully"
}
```

---

## Astro.js Implementation

### 1. API Client Setup

Create a reusable API client:

```typescript
// src/lib/api.ts

const API_BASE = '/api_manage/v1';

interface ApiResponse<T> {
  data?: T;
  error?: string;
  errors?: string[];
}

export async function apiClient<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<ApiResponse<T>> {
  const url = `${API_BASE}${endpoint}`;

  const defaultHeaders: HeadersInit = {
    'Content-Type': 'application/json',
    // TODO: Add auth header when implemented
    // 'Authorization': `Bearer ${getToken()}`
  };

  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        ...defaultHeaders,
        ...options.headers,
      },
    });

    const json = await response.json();

    if (!response.ok) {
      return {
        error: json.error || 'Request failed',
        errors: json.errors,
      };
    }

    return { data: json };
  } catch (error) {
    return { error: 'Network error' };
  }
}

// Typed API methods
export const pagesApi = {
  list: (locale: string) =>
    apiClient<{ pages: Page[] }>(`/${locale}/pages`),

  get: (locale: string, id: number) =>
    apiClient<{ page: PageDetails }>(`/${locale}/pages/${id}`),

  getBySlug: (locale: string, slug: string) =>
    apiClient<{ page: PageDetails }>(`/${locale}/pages/by_slug/${slug}`),

  update: (locale: string, id: number, data: Partial<PageSettings>) =>
    apiClient<{ page: PageDetails; message: string }>(`/${locale}/pages/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ page: data }),
    }),

  reorderParts: (locale: string, id: number, partIds: number[]) =>
    apiClient<{ message: string }>(`/${locale}/pages/${id}/reorder_parts`, {
      method: 'PATCH',
      body: JSON.stringify({ part_ids: partIds }),
    }),
};
```

### 2. TypeScript Types

```typescript
// src/types/pages.ts

export interface Page {
  id: number;
  slug: string;
  title: string;
  visible: boolean;
  show_in_top_nav: boolean;
  show_in_footer: boolean;
  sort_order_top_nav: number;
  sort_order_footer: number;
  updated_at: string;
}

export interface PagePart {
  id: number;
  page_part_key: string;
  order_in_editor: number;
  show_in_editor: boolean;
}

export interface PageDetails extends Page {
  seo_title: string | null;
  meta_description: string | null;
  meta_keywords: string | null;
  page_parts: PagePart[];
  created_at: string;
}

export interface PageSettings {
  slug: string;
  visible: boolean;
  show_in_top_nav: boolean;
  show_in_footer: boolean;
  sort_order_top_nav: number;
  sort_order_footer: number;
  seo_title: string;
  meta_description: string;
  meta_keywords: string;
}
```

### 3. Page Settings Component

```astro
---
// src/pages/admin/pages/[id]/settings.astro
import AdminLayout from '@/layouts/AdminLayout.astro';
import PageSettingsForm from '@/components/admin/PageSettingsForm';

const { id } = Astro.params;
---

<AdminLayout title="Page Settings">
  <PageSettingsForm pageId={Number(id)} client:load />
</AdminLayout>
```

### 4. React Form Component

```tsx
// src/components/admin/PageSettingsForm.tsx
import { useState, useEffect } from 'react';
import { pagesApi } from '@/lib/api';
import type { PageDetails, PageSettings } from '@/types/pages';

interface Props {
  pageId: number;
}

export default function PageSettingsForm({ pageId }: Props) {
  const [page, setPage] = useState<PageDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  // Form state
  const [formData, setFormData] = useState<Partial<PageSettings>>({});

  // Load page data
  useEffect(() => {
    async function loadPage() {
      const { data, error } = await pagesApi.get(pageId);
      if (error) {
        setError(error);
      } else if (data) {
        setPage(data.page);
        setFormData({
          slug: data.page.slug,
          visible: data.page.visible,
          show_in_top_nav: data.page.show_in_top_nav,
          show_in_footer: data.page.show_in_footer,
          sort_order_top_nav: data.page.sort_order_top_nav,
          sort_order_footer: data.page.sort_order_footer,
          seo_title: data.page.seo_title || '',
          meta_description: data.page.meta_description || '',
          meta_keywords: data.page.meta_keywords || '',
        });
      }
      setLoading(false);
    }
    loadPage();
  }, [pageId]);

  // Handle form submission
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(false);

    const { data, error: err, errors } = await pagesApi.update(pageId, formData);

    if (err) {
      setError(errors ? errors.join(', ') : err);
    } else {
      setSuccess(true);
      if (data) setPage(data.page);
      setTimeout(() => setSuccess(false), 3000);
    }

    setSaving(false);
  }

  // Update form field
  function updateField<K extends keyof PageSettings>(field: K, value: PageSettings[K]) {
    setFormData(prev => ({ ...prev, [field]: value }));
  }

  if (loading) return <div>Loading...</div>;
  if (!page) return <div>Page not found</div>;

  // SEO Preview
  const previewTitle = formData.seo_title || page.title || page.slug;
  const previewDescription = formData.meta_description || 'Page description will appear here...';
  const pageUrl = page.slug === 'home' ? '/' : `/p/${formData.slug || page.slug}`;

  return (
    <form onSubmit={handleSubmit} className="max-w-4xl mx-auto">
      {/* Success/Error Messages */}
      {success && (
        <div className="mb-4 p-4 bg-green-50 border border-green-200 rounded-lg text-green-800">
          Settings saved successfully!
        </div>
      )}
      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg text-red-800">
          {error}
        </div>
      )}

      {/* Navigation Settings Card */}
      <div className="bg-white rounded-lg shadow mb-6">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-bold text-gray-900">Navigation Settings</h2>
          <p className="text-sm text-gray-500 mt-1">
            Configure URL and navigation visibility for "{page.title}"
          </p>
        </div>

        <div className="p-6 space-y-6">
          {/* Slug */}
          <div>
            <label className="block text-sm font-medium text-gray-700">Slug</label>
            <input
              type="text"
              value={formData.slug || ''}
              onChange={(e) => updateField('slug', e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
            />
            <p className="mt-1 text-sm text-gray-500">
              The URL-friendly identifier for this page
            </p>
          </div>

          {/* Visibility Checkboxes */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={formData.visible || false}
                onChange={(e) => updateField('visible', e.target.checked)}
                className="rounded border-gray-300 text-blue-600"
              />
              <span className="ml-2 text-sm font-medium text-gray-700">Visible</span>
            </label>

            <label className="flex items-center">
              <input
                type="checkbox"
                checked={formData.show_in_top_nav || false}
                onChange={(e) => updateField('show_in_top_nav', e.target.checked)}
                className="rounded border-gray-300 text-blue-600"
              />
              <span className="ml-2 text-sm font-medium text-gray-700">
                Show in Top Navigation
              </span>
            </label>

            <label className="flex items-center">
              <input
                type="checkbox"
                checked={formData.show_in_footer || false}
                onChange={(e) => updateField('show_in_footer', e.target.checked)}
                className="rounded border-gray-300 text-blue-600"
              />
              <span className="ml-2 text-sm font-medium text-gray-700">
                Show in Footer
              </span>
            </label>
          </div>

          {/* Sort Order */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">
                Sort Order (Top Nav)
              </label>
              <input
                type="number"
                value={formData.sort_order_top_nav || 0}
                onChange={(e) => updateField('sort_order_top_nav', parseInt(e.target.value) || 0)}
                className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Sort Order (Footer)
              </label>
              <input
                type="number"
                value={formData.sort_order_footer || 0}
                onChange={(e) => updateField('sort_order_footer', parseInt(e.target.value) || 0)}
                className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
              />
            </div>
          </div>
        </div>
      </div>

      {/* SEO Settings Card */}
      <div className="bg-white rounded-lg shadow mb-6">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-bold text-gray-900">SEO Settings</h2>
          <p className="text-sm text-gray-500 mt-1">
            Optimize how this page appears in search engine results
          </p>
        </div>

        <div className="p-6 space-y-6">
          {/* Search Engine Preview */}
          <div className="p-4 bg-gray-50 rounded-lg border border-gray-200">
            <p className="text-xs font-medium text-gray-500 mb-3">Search Engine Preview</p>
            <div className="bg-white p-4 rounded border border-gray-200">
              <p className="text-blue-800 text-xl font-normal truncate">
                {previewTitle}
              </p>
              <p className="text-green-700 text-sm mt-1">
                {typeof window !== 'undefined' ? window.location.host : 'example.com'}{pageUrl}
              </p>
              <p className="text-gray-600 text-sm mt-1 line-clamp-2">
                {previewDescription}
              </p>
            </div>
          </div>

          {/* SEO Title */}
          <div>
            <label className="block text-sm font-medium text-gray-700">
              SEO Title
              <span className="text-gray-400 font-normal ml-1">
                (50-60 characters recommended)
              </span>
            </label>
            <input
              type="text"
              value={formData.seo_title || ''}
              onChange={(e) => updateField('seo_title', e.target.value)}
              maxLength={70}
              placeholder="Custom title for search engines..."
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
            />
            <div className="mt-1 flex justify-between">
              <p className="text-xs text-gray-500">Leave blank to use the page title</p>
              <CharacterCounter value={formData.seo_title || ''} max={70} optimal={60} />
            </div>
          </div>

          {/* Meta Description */}
          <div>
            <label className="block text-sm font-medium text-gray-700">
              Meta Description
              <span className="text-gray-400 font-normal ml-1">
                (150-160 characters recommended)
              </span>
            </label>
            <textarea
              value={formData.meta_description || ''}
              onChange={(e) => updateField('meta_description', e.target.value)}
              rows={3}
              maxLength={200}
              placeholder="A brief description of this page for search engines..."
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
            />
            <div className="mt-1 flex justify-between">
              <p className="text-xs text-gray-500">Appears in search results below the title</p>
              <CharacterCounter value={formData.meta_description || ''} max={200} optimal={160} />
            </div>
          </div>

          {/* SEO Tips */}
          <div className="p-4 bg-blue-50 rounded-lg border border-blue-100">
            <p className="text-sm font-medium text-blue-800 mb-2">SEO Tips</p>
            <ul className="text-xs text-blue-700 space-y-1">
              <li>• Include your main keyword in the SEO title</li>
              <li>• Write a compelling meta description that encourages clicks</li>
              <li>• Keep titles under 60 characters to avoid truncation</li>
              <li>• Make each page's title and description unique</li>
            </ul>
          </div>
        </div>
      </div>

      {/* Form Actions */}
      <div className="flex justify-end space-x-3">
        <a
          href="/admin/pages"
          className="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
        >
          Cancel
        </a>
        <button
          type="submit"
          disabled={saving}
          className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50"
        >
          {saving ? 'Saving...' : 'Save Settings'}
        </button>
      </div>
    </form>
  );
}

// Character counter component
function CharacterCounter({ value, max, optimal }: { value: string; max: number; optimal: number }) {
  const length = value.length;
  let colorClass = 'text-gray-500';

  if (length > 0 && length <= optimal) {
    colorClass = 'text-green-600';
  } else if (length > optimal && length <= max) {
    colorClass = 'text-yellow-600';
  } else if (length > max) {
    colorClass = 'text-red-600';
  }

  return (
    <p className={`text-xs ${colorClass}`}>
      {length} / {max} characters
    </p>
  );
}
```

---

## Error Handling

| Status | Meaning | Example Response |
|--------|---------|------------------|
| 200 | Success | `{ "page": {...}, "message": "..." }` |
| 404 | Page not found | `{ "error": "Not found", "message": "..." }` |
| 422 | Validation failed | `{ "error": "Validation failed", "errors": ["..."] }` |
| 401 | Unauthorized | `{ "error": "Unauthorized", "message": "..." }` |
| 403 | Forbidden | `{ "error": "Forbidden", "message": "..." }` |

---

## Related Endpoints

For fetching page content to render:
- `GET /api_public/v1/:locale/liquid_page/by_slug/:page_slug` - Get Liquid templates + block_contents
- `GET /api_public/v1/:locale/localized_page/by_slug/:page_slug` - Get pre-rendered HTML + SEO metadata

---

## Notes

1. **Tenant Scoping**: All requests are scoped to the website based on the subdomain. Ensure your Astro.js client is hosted on the correct subdomain or configure proper headers.

2. **Authentication**: Currently bypassed. When implemented, include `Authorization: Bearer <token>` header.

3. **Slug Changes**: Changing a page's slug will affect its URL. The page will be accessible at `/p/{new-slug}`.

4. **SEO Best Practices**:
   - SEO Title: 50-60 characters (max 70)
   - Meta Description: 150-160 characters (max 200)
   - Each page should have unique title and description
