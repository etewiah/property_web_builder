# Astro.js Client Integration Guide

This guide provides comprehensive documentation for implementing an Astro.js client that integrates with PropertyWebBuilder's API endpoints for both viewing and editing website content.

## Table of Contents

1. [Overview](#overview)
2. [API Base URLs](#api-base-urls)
3. [Authentication](#authentication)
4. [Public API (Viewing)](#public-api-viewing)
5. [Management API (Editing)](#management-api-editing)
6. [Data Models](#data-models)
7. [Rendering Strategies](#rendering-strategies)
8. [TypeScript Types](#typescript-types)
9. [Example Implementation](#example-implementation)

---

## Overview

PropertyWebBuilder provides two API namespaces:

| Namespace | Purpose | Authentication | Caching |
|-----------|---------|----------------|---------|
| `api_public` | Read-only access to published content | None | CDN-friendly |
| `api_manage` | CRUD operations for content editing | Required (TODO) | No caching |

### Key Concepts

- **Page**: A URL-addressable page (e.g., `/home`, `/about-us`)
- **PageContent**: A placement of a page part on a page (controls visibility, order)
- **PagePart**: Content template + data (block_contents) for a specific component
- **block_contents**: JSON structure holding the actual editable content per locale

---

## API Base URLs

```typescript
// Base URLs (replace with your domain)
const API_PUBLIC = 'https://your-domain.com/api_public/v1';
const API_MANAGE = 'https://your-domain.com/api_manage/v1';

// Locale-prefixed (recommended for CDN caching)
const publicUrl = (locale: string, path: string) =>
  `${API_PUBLIC}/${locale}${path}`;

const manageUrl = (locale: string, path: string) =>
  `${API_MANAGE}/${locale}${path}`;
```

---

## Authentication

> **Note**: Authentication is currently in development. For now, endpoints are open but will require Firebase tokens or API keys in production.

```typescript
// Future authentication header
const headers = {
  'Authorization': `Bearer ${firebaseToken}`,
  'Content-Type': 'application/json'
};
```

---

## Public API (Viewing)

### Get Site Configuration

```http
GET /api_public/v1/:locale/site_details
```

Returns website branding, navigation, and configuration.

```typescript
interface SiteDetails {
  agency: {
    display_name: string;
    phone: string;
    email: string;
    address: {
      street_address: string;
      city: string;
      region: string;
      country: string;
      postal_code: string;
    };
  };
  branding: {
    logo_url: string | null;
    favicon_url: string | null;
  };
  navigation: {
    top_nav: NavItem[];
    footer_nav: NavItem[];
  };
  localization: {
    default_locale: string;
    available_locales: string[];
  };
}
```

### Get Page with Liquid Templates (Recommended for Editors)

```http
GET /api_public/v1/:locale/liquid_page/by_slug/:page_slug
```

Returns page data with Liquid templates and block_contents for client-side rendering.

**Response:**
```json
{
  "id": 1,
  "slug": "home",
  "locale": "en",
  "title": "Home",
  "meta_description": "Welcome to our website",
  "page_contents": [
    {
      "page_part_key": "heroes/hero_centered",
      "page_slug": "home",
      "edit_key": "home::heroes/hero_centered",
      "sort_order": 1,
      "visible": true,
      "is_rails_part": false,
      "rendered_html": "<section class='pwb-hero'>...</section>",
      "liquid_part_template": "{% if page_part.title.content %}...",
      "block_contents": {
        "blocks": {
          "title": { "content": "Welcome" },
          "subtitle": { "content": "Find your dream home" },
          "cta_text": { "content": "Get Started" },
          "cta_link": { "content": "/contact" }
        }
      },
      "available_locales": ["en", "es"],
      "field_schema": {
        "fields": [
          {
            "name": "title",
            "type": "text",
            "label": "Main Title",
            "required": true,
            "max_length": 80
          }
        ],
        "groups": [
          { "key": "titles", "label": "Titles & Text", "order": 1 }
        ]
      }
    }
  ]
}
```

**Key fields for editing:**
- `edit_key`: Use this with the `api_manage` endpoint to update content (URL-encode it)
- `page_slug`: The page this content belongs to
- `field_schema`: Metadata for building the editor UI (types, labels, validation)

### Get Page with Pre-rendered HTML

```http
GET /api_public/v1/:locale/pages/:id?include_rendered=true
```

Returns page with pre-rendered HTML (faster, but less flexible).

**Response includes:**
```json
{
  "page_contents": [
    {
      "id": 1,
      "page_part_key": "heroes/hero_centered",
      "rendered_html": "<section class='pwb-hero'>...</section>",
      "is_container": false
    }
  ]
}
```

### Container Page Parts

Containers have a nested `slots` structure:

```json
{
  "page_part_key": "layout/layout_two_column_equal",
  "is_container": true,
  "rendered_html": "<section class='pwb-layout'>...</section>",
  "slots": {
    "left": [
      { "id": 2, "page_part_key": "cta/cta_banner", "sort_order": 1 }
    ],
    "right": [
      { "id": 3, "page_part_key": "contact_general_enquiry", "sort_order": 1 }
    ]
  }
}
```

### Get Translations

```http
GET /api_public/v1/:locale/translations
```

Returns UI translation strings for the specified locale.

### Get Navigation Links

```http
GET /api_public/v1/:locale/links
```

Returns navigation links with placement information.

---

## Management API (Editing)

### Site Details

```http
GET  /api_manage/v1/:locale/site_details
PATCH /api_manage/v1/:locale/site_details
```

**Update Example:**
```typescript
await fetch(manageUrl('en', '/site_details'), {
  method: 'PATCH',
  headers,
  body: JSON.stringify({
    site: {
      company_display_name: 'New Company Name',
      default_meta_description: 'Updated description'
    }
  })
});
```

### Pages

```http
GET    /api_manage/v1/:locale/pages                    # List all pages
GET    /api_manage/v1/:locale/pages/:id                # Get page details
GET    /api_manage/v1/:locale/pages/by_slug/:slug      # Get by slug
PATCH  /api_manage/v1/:locale/pages/:id                # Update page settings
```

**Update Page:**
```typescript
await fetch(manageUrl('en', `/pages/${pageId}`), {
  method: 'PATCH',
  headers,
  body: JSON.stringify({
    page: {
      seo_title: 'New SEO Title',
      meta_description: 'New meta description',
      visible: true
    }
  })
});
```

### Page Contents (Placements)

```http
GET    /api_manage/v1/:locale/pages/:page_id/page_contents     # List page contents
POST   /api_manage/v1/:locale/pages/:page_id/page_contents     # Create page content
GET    /api_manage/v1/:locale/page_contents/:id                # Get details
PATCH  /api_manage/v1/:locale/page_contents/:id                # Update
DELETE /api_manage/v1/:locale/page_contents/:id                # Delete
PATCH  /api_manage/v1/:locale/pages/:page_id/page_contents/reorder  # Reorder
```

**Create Page Content (add component to page):**
```typescript
await fetch(manageUrl('en', `/pages/${pageId}/page_contents`), {
  method: 'POST',
  headers,
  body: JSON.stringify({
    page_content: {
      page_part_key: 'cta/cta_banner',
      sort_order: 5,
      visible_on_page: true
    }
  })
});
```

**Create Child in Container Slot:**
```typescript
await fetch(manageUrl('en', `/pages/${pageId}/page_contents`), {
  method: 'POST',
  headers,
  body: JSON.stringify({
    page_content: {
      page_part_key: 'contact_general_enquiry',
      parent_page_content_id: containerId,
      slot_name: 'right',
      sort_order: 1,
      visible_on_page: true
    }
  })
});
```

**Reorder Page Contents:**
```typescript
await fetch(manageUrl('en', `/pages/${pageId}/page_contents/reorder`), {
  method: 'PATCH',
  headers,
  body: JSON.stringify({
    order: [
      { id: 1, sort_order: 2 },
      { id: 2, sort_order: 1 }
    ]
  })
});
```

### Page Parts (Content Editing)

```http
GET    /api_manage/v1/:locale/page_parts                       # List all
GET    /api_manage/v1/:locale/page_parts/:id                   # Get by ID
GET    /api_manage/v1/:locale/page_parts/by_key/:key           # Get by key
PATCH  /api_manage/v1/:locale/page_parts/:id                   # Update by ID
PATCH  /api_manage/v1/:locale/page_parts/by_key/:key           # Update by key
POST   /api_manage/v1/:locale/page_parts/:id/regenerate        # Re-render HTML
```

**Key Format:** `page_slug::page_part_key` (e.g., `home::heroes/hero_centered`)
- URL-encode the key: `home::heroes%2Fhero_centered`
- For website-level parts, omit page_slug: `heroes/hero_centered`

> **Tip:** The `liquid_page` endpoint returns an `edit_key` field for each page_content that is already
> in the correct format. Use it directly:
> ```typescript
> // From liquid_page response
> const pageContent = response.page_contents[0];
> const editKey = encodeURIComponent(pageContent.edit_key); // "home::heroes/hero_centered"
>
> // Use for update
> await fetch(`/api_manage/v1/en/page_parts/by_key/${editKey}`, { ... });
> ```

**Update Page Part Content:**
```typescript
// By ID
await fetch(manageUrl('en', `/page_parts/${pagePartId}`), {
  method: 'PATCH',
  headers,
  body: JSON.stringify({
    block_contents: {
      title: { content: 'New Title' },
      subtitle: { content: 'New subtitle text' },
      cta_text: { content: 'Click Here' },
      cta_link: { content: '/contact' }
    },
    regenerate: true  // Re-render pre-rendered HTML
  })
});

// By key (auto-creates if not exists)
const key = encodeURIComponent('home::heroes/hero_centered');
await fetch(manageUrl('en', `/page_parts/by_key/${key}`), {
  method: 'PATCH',
  headers,
  body: JSON.stringify({
    block_contents: {
      title: { content: 'Updated Hero Title' }
    }
  })
});
```

**Response includes field_schema for building editor UI:**
```json
{
  "page_part": {
    "id": 1,
    "page_part_key": "heroes/hero_centered",
    "block_contents": {
      "blocks": {
        "title": { "content": "Welcome" }
      }
    },
    "field_schema": {
      "fields": [
        {
          "name": "title",
          "type": "text",
          "label": "Main Title",
          "hint": "The primary headline",
          "required": true,
          "max_length": 80,
          "group": "titles"
        },
        {
          "name": "background_image",
          "type": "image",
          "label": "Background Image",
          "hint": "Full-width background (1920x1080)",
          "group": "media"
        }
      ],
      "groups": [
        { "key": "titles", "label": "Titles & Text", "order": 1 },
        { "key": "media", "label": "Media", "order": 2 }
      ]
    }
  }
}
```

---

## Data Models

### block_contents Structure

```typescript
interface BlockContents {
  [locale: string]: {
    blocks: {
      [fieldName: string]: {
        content: string;
      };
    };
  };
}

// Example
const blockContents: BlockContents = {
  "en": {
    "blocks": {
      "title": { "content": "Welcome" },
      "subtitle": { "content": "Find your dream home" }
    }
  },
  "es": {
    "blocks": {
      "title": { "content": "Bienvenido" },
      "subtitle": { "content": "Encuentra tu hogar ideal" }
    }
  }
};
```

### Field Types

| Type | Description | Editor Component |
|------|-------------|------------------|
| `text` | Single-line text | `<input type="text">` |
| `textarea` | Multi-line text | `<textarea>` |
| `html` | Rich text HTML | WYSIWYG editor |
| `image` | Image URL/upload | Image uploader |
| `url` | URL with validation | URL input |
| `email` | Email address | Email input |
| `phone` | Phone number | Phone input |
| `number` | Numeric value | Number input |
| `boolean` | True/false | Checkbox/toggle |
| `select` | Dropdown choices | `<select>` |
| `color` | Color picker | Color input |
| `date` | Date selection | Date picker |
| `faq_array` | Array of Q&A pairs | FAQ editor |

---

## Rendering Strategies

### Strategy 1: Pre-rendered HTML (Simple)

Use `rendered_html` directly from the API:

```astro
---
// src/pages/[slug].astro
const { slug } = Astro.params;
const locale = Astro.currentLocale || 'en';

const response = await fetch(
  `${API_PUBLIC}/${locale}/pages/by_slug/${slug}?include_rendered=true`
);
const page = await response.json();
---

<Layout title={page.title}>
  {page.page_contents.map((content) => (
    <Fragment set:html={content.rendered_html} />
  ))}
</Layout>
```

### Strategy 2: Client-Side Liquid Rendering

For editor preview with live updates:

```astro
---
// src/pages/[slug].astro
import { Liquid } from 'liquidjs';

const engine = new Liquid();
const { slug } = Astro.params;
const locale = Astro.currentLocale || 'en';

const response = await fetch(
  `${API_PUBLIC}/${locale}/liquid_page/by_slug/${slug}`
);
const page = await response.json();
---

<Layout title={page.title}>
  {page.page_contents.map((content) => {
    if (content.liquid_part_template && content.block_contents) {
      const html = engine.parseAndRenderSync(
        content.liquid_part_template,
        { page_part: content.block_contents.blocks }
      );
      return <Fragment set:html={html} />;
    }
    return <Fragment set:html={content.rendered_html} />;
  })}
</Layout>
```

### Strategy 3: Astro Components

Map page_part_key to Astro components:

```astro
---
// src/pages/[slug].astro
import HeroCentered from '../components/heroes/HeroCentered.astro';
import CtaBanner from '../components/cta/CtaBanner.astro';
import ContactForm from '../components/forms/ContactForm.astro';

const componentMap = {
  'heroes/hero_centered': HeroCentered,
  'cta/cta_banner': CtaBanner,
  'contact_general_enquiry': ContactForm,
};

const response = await fetch(`${API_PUBLIC}/${locale}/liquid_page/by_slug/${slug}`);
const page = await response.json();
---

<Layout title={page.title}>
  {page.page_contents.map((content) => {
    const Component = componentMap[content.page_part_key];
    if (Component) {
      return <Component data={content.block_contents?.blocks || {}} />;
    }
    return <Fragment set:html={content.rendered_html} />;
  })}
</Layout>
```

```astro
---
// src/components/heroes/HeroCentered.astro
interface Props {
  data: {
    title?: { content: string };
    subtitle?: { content: string };
    cta_text?: { content: string };
    cta_link?: { content: string };
    background_image?: { content: string };
  };
}

const { data } = Astro.props;
---

<section class="hero-centered">
  {data.background_image?.content && (
    <img src={data.background_image.content} alt="" class="hero-bg" />
  )}
  <div class="hero-content">
    {data.title?.content && <h1>{data.title.content}</h1>}
    {data.subtitle?.content && <p>{data.subtitle.content}</p>}
    {data.cta_text?.content && data.cta_link?.content && (
      <a href={data.cta_link.content} class="btn">{data.cta_text.content}</a>
    )}
  </div>
</section>
```

---

## TypeScript Types

```typescript
// src/types/pwb.ts

export interface PageContent {
  id: number;
  page_part_key: string;
  page_slug: string;           // Page this content belongs to
  edit_key: string;            // Composite key for editing: "page_slug::page_part_key"
  sort_order: number;
  visible: boolean;
  is_rails_part: boolean;
  is_container: boolean;
  label?: string;
  parent_page_content_id?: number;
  slot_name?: string;
  rendered_html?: string;
  liquid_part_template?: string;
  block_contents?: LocaleBlockContents;
  slots?: Record<string, SlotChild[]>;
  field_schema?: FieldSchema;
}

export interface SlotChild {
  id: number;
  page_part_key: string;
  sort_order: number;
  label?: string;
}

export interface LocaleBlockContents {
  blocks: Record<string, { content: string }>;
}

export interface FieldSchema {
  fields: FieldDefinition[];
  groups: FieldGroup[];
}

export interface FieldDefinition {
  name: string;
  type: FieldType;
  label: string;
  hint?: string;
  placeholder?: string;
  required?: boolean;
  max_length?: number;
  min_length?: number;
  default?: string;
  group?: string;
  choices?: { value: string; label: string }[];
}

export type FieldType =
  | 'text' | 'textarea' | 'html' | 'image' | 'url'
  | 'email' | 'phone' | 'number' | 'boolean' | 'select'
  | 'color' | 'date' | 'faq_array';

export interface FieldGroup {
  key: string;
  label: string;
  order: number;
}

export interface Page {
  id: number;
  slug: string;
  locale: string;
  title: string;
  meta_description?: string;
  meta_keywords?: string;
  page_contents: PageContent[];
}

export interface PagePart {
  id: number;
  page_part_key: string;
  page_slug?: string;
  block_contents: LocaleBlockContents;
  available_locales: string[];
  field_schema?: FieldSchema;
  definition?: {
    label: string;
    description: string;
    category: string;
    is_container: boolean;
    slots?: Record<string, SlotDefinition>;
  };
}

export interface SlotDefinition {
  label: string;
  description: string;
  width: string;
}
```

---

## Example Implementation

### API Client

```typescript
// src/lib/api.ts

const API_PUBLIC = import.meta.env.PUBLIC_API_URL || 'https://api.example.com/api_public/v1';
const API_MANAGE = import.meta.env.PUBLIC_API_MANAGE_URL || 'https://api.example.com/api_manage/v1';

export async function getPage(locale: string, slug: string) {
  const res = await fetch(`${API_PUBLIC}/${locale}/liquid_page/by_slug/${slug}`);
  if (!res.ok) throw new Error(`Page not found: ${slug}`);
  return res.json();
}

export async function getSiteDetails(locale: string) {
  const res = await fetch(`${API_PUBLIC}/${locale}/site_details`);
  if (!res.ok) throw new Error('Site details not found');
  return res.json();
}

export async function updatePagePart(
  locale: string,
  pagePartId: number,
  blockContents: Record<string, { content: string }>
) {
  const res = await fetch(`${API_MANAGE}/${locale}/page_parts/${pagePartId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ block_contents: blockContents })
  });
  if (!res.ok) {
    const error = await res.json();
    throw new Error(error.message || 'Failed to update');
  }
  return res.json();
}

export async function getPagePartByKey(locale: string, pageSlug: string, pagePartKey: string) {
  const key = encodeURIComponent(`${pageSlug}::${pagePartKey}`);
  const res = await fetch(`${API_MANAGE}/${locale}/page_parts/by_key/${key}`);
  if (!res.ok) throw new Error('Page part not found');
  return res.json();
}
```

### Editor Component (React/Solid)

```tsx
// src/components/PagePartEditor.tsx
import { createSignal, createEffect } from 'solid-js';
import type { PagePart, FieldDefinition } from '../types/pwb';

interface Props {
  locale: string;
  pageSlug: string;
  pagePartKey: string;
}

export function PagePartEditor(props: Props) {
  const [pagePart, setPagePart] = createSignal<PagePart | null>(null);
  const [saving, setSaving] = createSignal(false);

  // Load page part data
  createEffect(async () => {
    const key = encodeURIComponent(`${props.pageSlug}::${props.pagePartKey}`);
    const res = await fetch(`/api_manage/v1/${props.locale}/page_parts/by_key/${key}`);
    const data = await res.json();
    setPagePart(data.page_part);
  });

  const handleSave = async (fieldName: string, value: string) => {
    const pp = pagePart();
    if (!pp) return;

    setSaving(true);
    try {
      await fetch(`/api_manage/v1/${props.locale}/page_parts/${pp.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          block_contents: { [fieldName]: { content: value } }
        })
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div class="page-part-editor">
      {pagePart()?.field_schema?.fields.map((field: FieldDefinition) => (
        <FieldEditor
          field={field}
          value={pagePart()?.block_contents?.blocks?.[field.name]?.content || ''}
          onSave={(value) => handleSave(field.name, value)}
          disabled={saving()}
        />
      ))}
    </div>
  );
}
```

---

## Error Handling

All API endpoints return consistent error responses:

```json
{
  "error": "Error type",
  "message": "Human-readable message",
  "code": "ERROR_CODE",
  "errors": ["List of validation errors"]
}
```

**Common HTTP Status Codes:**

| Status | Meaning |
|--------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (invalid params) |
| 404 | Not Found |
| 422 | Unprocessable Entity (validation failed) |
| 500 | Server Error |

---

## Related Documentation

- [Container Page Parts](/docs/architecture/container_page_parts.md)
- [Page Parts Overview](/docs/architecture/page_parts_overview.md)
- [Field Schema Builder](/docs/api/field_schema.md)
