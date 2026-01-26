# Page Parts API - Complete Specification for Astro.js Implementation

This document provides complete technical details for implementing the page parts system in an Astro.js client, including both rendering and editing capabilities.

## Table of Contents

1. [Overview](#overview)
2. [Data Model](#data-model)
3. [API Endpoints](#api-endpoints)
4. [Rendering Page Parts](#rendering-page-parts)
5. [Edit Mode Implementation](#edit-mode-implementation)
6. [Astro.js Implementation Guide](#astrojs-implementation-guide)
7. [Complete Code Examples](#complete-code-examples)

---

## Overview

Page Parts are reusable content blocks that make up the pages of a PWB website. Each page part:

- Has a unique `page_part_key` (e.g., `heroes/hero_centered`, `cta/cta_banner`)
- Contains structured content in `block_contents` (JSON)
- Can have a Liquid template for rendering (server-side)
- Is scoped to a website (multi-tenant)

### Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        RAILS BACKEND                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │  PagePart    │───▶│   Liquid     │───▶│  Rendered HTML       │  │
│  │ (database)   │    │  Template    │    │  (stored in Content) │  │
│  │              │    │  (file)      │    │                      │  │
│  │ block_       │    │              │    │                      │  │
│  │ contents     │    │ page_part.*  │    │                      │  │
│  └──────────────┘    └──────────────┘    └──────────────────────┘  │
│         │                                          │                │
│         │                                          │                │
│         ▼                                          ▼                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    PUBLIC API                                │   │
│  │  GET /api_public/v1/pages/:slug?include_rendered=true       │   │
│  │  Returns: { page_contents: [ { page_part_key, rendered_html }]}│   │
│  └─────────────────────────────────────────────────────────────┘   │
│         │                                                          │
└─────────│──────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        ASTRO.JS CLIENT                              │
│                                                                     │
│  Option A: Use pre-rendered HTML from API                          │
│  ─────────────────────────────────────────                         │
│  Simply inject rendered_html into the page                         │
│                                                                     │
│  Option B: Client-side rendering with Astro components             │
│  ─────────────────────────────────────────────────────             │
│  Fetch block_contents and render with custom components            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Model

### PagePart Table Schema

```sql
CREATE TABLE pwb_page_parts (
  id              BIGINT PRIMARY KEY,
  page_part_key   VARCHAR NOT NULL,    -- e.g., "heroes/hero_centered"
  page_slug       VARCHAR,             -- Associated page slug (optional)
  website_id      INTEGER NOT NULL,    -- Tenant ID
  block_contents  JSON,                -- Content data (editable)
  template        TEXT,                -- Liquid template override (optional)
  editor_setup    JSON,                -- Editor field configuration
  locale          VARCHAR,             -- Default locale
  theme_name      VARCHAR,             -- Theme association
  show_in_editor  BOOLEAN DEFAULT TRUE,
  order_in_editor INTEGER,
  is_rails_part   BOOLEAN DEFAULT FALSE,
  flags           INTEGER DEFAULT 0,
  created_at      TIMESTAMP NOT NULL,
  updated_at      TIMESTAMP NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX index_page_parts_unique_per_website
  ON pwb_page_parts (page_part_key, page_slug, website_id);
```

### block_contents JSON Structure

The `block_contents` field stores editable content. There are two structures:

#### Structure A: Locale-based (Recommended)

Supports multiple languages with a `blocks` sub-object:

```json
{
  "en": {
    "blocks": {
      "title": { "content": "Welcome to Our Site" },
      "subtitle": { "content": "Your journey starts here" },
      "background_image": { "content": "https://example.com/hero.jpg" },
      "cta_text": { "content": "Get Started" },
      "cta_link": { "content": "/signup" },
      "cta_secondary_text": { "content": "Learn More" },
      "cta_secondary_link": { "content": "/about" }
    }
  },
  "es": {
    "blocks": {
      "title": { "content": "Bienvenido a Nuestro Sitio" },
      "subtitle": { "content": "Tu viaje comienza aquí" },
      "background_image": { "content": "https://example.com/hero.jpg" },
      "cta_text": { "content": "Comenzar" },
      "cta_link": { "content": "/es/signup" }
    }
  },
  "fr": {
    "blocks": {
      "title": { "content": "Bienvenue sur Notre Site" },
      "subtitle": { "content": "Votre voyage commence ici" }
    }
  }
}
```

#### Structure B: Flat (Legacy)

Single-language, no locale nesting:

```json
{
  "title": { "content": "Welcome" },
  "subtitle": { "content": "Your journey starts here" },
  "image_src": { "content": "https://example.com/hero.jpg" }
}
```

### Accessing Content in Templates

In Liquid templates, content is accessed via `page_part.BLOCK_KEY.content`:

```liquid
<h1>{{ page_part.title.content }}</h1>
{% if page_part.subtitle.content %}
  <p>{{ page_part.subtitle.content }}</p>
{% endif %}
```

---

## API Endpoints

### 1. Get Page with Rendered Content

**Endpoint:** `GET /api_public/v1/pages/by_slug/:slug`

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `locale` | string | Content locale (e.g., `en`, `es`) |
| `include_rendered` | boolean | Include pre-rendered HTML |
| `include_parts` | boolean | Include raw page part metadata |

**Example Request:**
```
GET /api_public/v1/pages/by_slug/home?locale=en&include_rendered=true
```

**Response:**
```json
{
  "id": 1,
  "slug": "home",
  "title": "Home",
  "meta_title": "Welcome | Property Website",
  "meta_description": "Find your dream property...",
  "page_contents": [
    {
      "page_part_key": "heroes/hero_centered",
      "sort_order": 1,
      "visible": true,
      "is_rails_part": false,
      "rendered_html": "<section class=\"pwb-hero pwb-hero--centered\">...</section>",
      "label": "Hero Section"
    },
    {
      "page_part_key": "features/feature_grid_3col",
      "sort_order": 2,
      "visible": true,
      "is_rails_part": false,
      "rendered_html": "<section class=\"pwb-features\">...</section>",
      "label": "Features"
    },
    {
      "page_part_key": "cta/cta_banner",
      "sort_order": 3,
      "visible": true,
      "is_rails_part": false,
      "rendered_html": "<section class=\"pwb-cta pwb-cta--banner\">...</section>",
      "label": "Call to Action"
    }
  ]
}
```

### 2. Get Page Part for Editing

**Endpoint:** `GET /:locale/editor/page_parts/:key`

**Note:** The `:key` can contain slashes (e.g., `heroes/hero_centered`).

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `editing_locale` | string | The locale to load content for |

**Example Request:**
```
GET /en/editor/page_parts/heroes/hero_centered?editing_locale=es
```

**Response:** HTML form partial (see [Edit Mode Implementation](#edit-mode-implementation))

### 3. Update Page Part Content

**Endpoint:** `PATCH /:locale/editor/page_parts/:key`

**Headers:**
```
Content-Type: multipart/form-data
X-CSRF-Token: [token]
```

**Request Body (FormData):**

For locale-based structure:
```
page_part[content][es][blocks][title][content]=Nuevo Título
page_part[content][es][blocks][subtitle][content]=Nuevo Subtítulo
page_part[content][es][blocks][background_image][content]=https://example.com/new-image.jpg
```

For flat structure:
```
page_part[content][title]=New Title
page_part[content][subtitle]=New Subtitle
```

**Success Response:**
```json
{
  "status": "success",
  "content": {
    "en": {
      "blocks": {
        "title": { "content": "Welcome" },
        "subtitle": { "content": "Your journey starts here" }
      }
    },
    "es": {
      "blocks": {
        "title": { "content": "Nuevo Título" },
        "subtitle": { "content": "Nuevo Subtítulo" }
      }
    }
  }
}
```

**Error Response:**
```json
{
  "status": "error",
  "errors": ["Title cannot be blank"]
}
```

### 4. List Images

**Endpoint:** `GET /:locale/editor/images`

**Response:**
```json
{
  "images": [
    {
      "id": "content_123",
      "type": "content",
      "url": "https://cdn.example.com/uploads/hero-bg.jpg",
      "thumb_url": "https://cdn.example.com/uploads/hero-bg_thumb.jpg",
      "filename": "hero-bg.jpg",
      "description": "Hero background image"
    },
    {
      "id": "website_456",
      "type": "website",
      "url": "https://cdn.example.com/uploads/logo.png",
      "thumb_url": "https://cdn.example.com/uploads/logo_thumb.png",
      "filename": "logo.png",
      "description": null
    },
    {
      "id": "prop_789",
      "type": "property",
      "url": "https://cdn.example.com/uploads/property-1.jpg",
      "thumb_url": "https://cdn.example.com/uploads/property-1_thumb.jpg",
      "filename": "property-1.jpg",
      "description": "Beach House - Main Photo"
    }
  ]
}
```

### 5. Upload Image

**Endpoint:** `POST /:locale/editor/images`

**Request Body (FormData):**
```
image: [File]
```

**Response:**
```json
{
  "success": true,
  "image": {
    "id": "content_999",
    "type": "content",
    "url": "https://cdn.example.com/uploads/new-image.jpg",
    "thumb_url": "https://cdn.example.com/uploads/new-image_thumb.jpg",
    "filename": "new-image.jpg"
  }
}
```

---

## Rendering Page Parts

### Template Library

PWB includes a library of pre-built page part templates. Key templates:

#### Heroes
| Key | Description |
|-----|-------------|
| `heroes/hero_centered` | Full-width hero with centered text |
| `heroes/hero_split` | Hero with image on one side |
| `heroes/hero_search` | Hero with property search form |

#### Call to Action
| Key | Description |
|-----|-------------|
| `cta/cta_banner` | Full-width CTA banner |
| `cta/cta_split_image` | CTA with image |

#### Features
| Key | Description |
|-----|-------------|
| `features/feature_grid_3col` | 3-column feature grid |

#### Testimonials
| Key | Description |
|-----|-------------|
| `testimonials/testimonial_carousel` | Sliding testimonial carousel |
| `testimonials/testimonial_grid` | Grid of testimonial cards |

### Example: Hero Centered Template

**Liquid Template** (`app/views/pwb/page_parts/heroes/hero_centered.liquid`):

```liquid
<section class="pwb-hero pwb-hero--centered">
  {% if page_part.background_image.content %}
    <img src="{{ page_part.background_image.content }}"
         alt="{{ page_part.title.content | default: 'Hero background' }}"
         class="pwb-hero__bg-image"
         fetchpriority="high"
         loading="eager">
  {% endif %}
  <div class="pwb-hero__overlay"></div>
  <div class="pwb-container">
    <div class="pwb-hero__content">
      {% if page_part.pretitle.content %}
        <span class="pwb-hero__pretitle">{{ page_part.pretitle.content }}</span>
      {% endif %}
      <h1 class="pwb-hero__title">{{ page_part.title.content }}</h1>
      {% if page_part.subtitle.content %}
        <p class="pwb-hero__subtitle">{{ page_part.subtitle.content }}</p>
      {% endif %}
      {% if page_part.cta_text.content %}
        <div class="pwb-hero__actions">
          <a href="{{ page_part.cta_link.content | default: '#' }}"
             class="pwb-btn pwb-btn--primary pwb-btn--lg">
            {{ page_part.cta_text.content }}
          </a>
          {% if page_part.cta_secondary_text.content %}
            <a href="{{ page_part.cta_secondary_link.content | default: '#' }}"
               class="pwb-btn pwb-btn--outline pwb-btn--lg">
              {{ page_part.cta_secondary_text.content }}
            </a>
          {% endif %}
        </div>
      {% endif %}
    </div>
  </div>
</section>
```

**Expected block_contents:**
```json
{
  "en": {
    "blocks": {
      "background_image": { "content": "https://example.com/hero.jpg" },
      "pretitle": { "content": "Welcome to" },
      "title": { "content": "Your Dream Home" },
      "subtitle": { "content": "Find the perfect property for you and your family" },
      "cta_text": { "content": "Search Properties" },
      "cta_link": { "content": "/search" },
      "cta_secondary_text": { "content": "Contact Us" },
      "cta_secondary_link": { "content": "/contact" }
    }
  }
}
```

---

## Edit Mode Implementation

### Marking Elements as Editable

On the site, editable elements must have the `data-pwb-page-part` attribute:

```html
<!-- This element is editable -->
<section data-pwb-page-part="heroes/hero_centered" class="pwb-hero">
  <h1>Welcome</h1>
  <p>Your journey starts here</p>
</section>
```

### Client-Side Script (edit_mode.js)

When the page loads with `?edit_mode=true`, this script highlights editable elements and sends click events to the parent editor:

```javascript
// PWB Edit Mode Client Script
(function() {
  'use strict';

  // Only run in edit mode
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('edit_mode') !== 'true') return;

  console.log('PWB Edit Mode Active');

  // Style for editable elements
  const style = document.createElement('style');
  style.textContent = `
    [data-pwb-page-part] {
      cursor: pointer !important;
      outline: 2px dashed transparent !important;
      transition: outline 0.2s ease !important;
    }
    [data-pwb-page-part]:hover {
      outline: 2px dashed #3b82f6 !important;
    }
    [data-pwb-page-part].pwb-selected {
      outline: 2px solid #3b82f6 !important;
    }
  `;
  document.head.appendChild(style);

  // Find all editable elements
  const editableElements = document.querySelectorAll('[data-pwb-page-part]');

  editableElements.forEach(el => {
    el.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();

      // Remove selection from others
      editableElements.forEach(other => other.classList.remove('pwb-selected'));

      // Mark this one as selected
      el.classList.add('pwb-selected');

      const pagePartKey = el.getAttribute('data-pwb-page-part');

      // Send message to parent editor
      window.parent.postMessage({
        type: 'pwb:element:selected',
        payload: {
          key: pagePartKey,
          content: el.innerHTML
        }
      }, '*');
    });
  });

  // Listen for highlight commands from editor
  window.addEventListener('message', (event) => {
    if (event.data.type === 'pwb:element:highlight') {
      const key = event.data.payload.key;
      const el = document.querySelector(`[data-pwb-page-part="${key}"]`);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        el.classList.add('pwb-selected');
      }
    }
  });
})();
```

### Form Field Auto-Detection

The editor automatically determines input types based on block key names:

```javascript
function getFieldType(key, content) {
  const keyLower = key.toLowerCase();

  // Image fields
  if (keyLower.includes('image') ||
      keyLower.includes('photo') ||
      keyLower.includes('src') ||
      keyLower.includes('background') ||
      /\.(jpg|jpeg|png|gif|webp|svg)(\?|$)/i.test(content)) {
    return 'image';
  }

  // Rich text / HTML fields
  if (content && (content.length > 100 || content.includes('<'))) {
    return 'textarea';
  }

  // Default to text
  return 'text';
}
```

### Form Parameter Naming

For PATCH requests, form parameters follow this convention:

**Locale-based structure:**
```
page_part[content][LOCALE][blocks][BLOCK_KEY][content]=VALUE

Examples:
page_part[content][en][blocks][title][content]=Welcome
page_part[content][en][blocks][subtitle][content]=Your journey starts here
page_part[content][es][blocks][title][content]=Bienvenido
```

**Flat structure (legacy):**
```
page_part[content][BLOCK_KEY]=VALUE

Example:
page_part[content][title]=Welcome
```

---

## Astro.js Implementation Guide

### Project Structure

```
src/
├── components/
│   ├── page-parts/
│   │   ├── HeroCentered.astro      # Hero component
│   │   ├── HeroSplit.astro
│   │   ├── CtaBanner.astro         # CTA component
│   │   ├── FeatureGrid.astro       # Features component
│   │   └── PagePartRenderer.astro   # Dynamic renderer
│   └── editor/
│       ├── EditorShell.astro       # Editor wrapper
│       ├── EditorPanel.astro       # Bottom panel
│       ├── EditForm.astro          # Dynamic form
│       └── ImagePicker.astro       # Image selection modal
├── layouts/
│   ├── BaseLayout.astro
│   └── EditorLayout.astro          # Editor shell layout
├── pages/
│   ├── [...slug].astro             # Dynamic page routing
│   └── edit/
│       └── [...path].astro         # Editor routes
├── lib/
│   ├── api.ts                      # API client
│   └── page-parts.ts               # Page part utilities
└── scripts/
    └── edit-mode.ts                # Edit mode client script
```

### Step 1: API Client

```typescript
// src/lib/api.ts
const API_BASE = import.meta.env.PUBLIC_API_URL || 'http://localhost:3000';

export interface PagePart {
  page_part_key: string;
  sort_order: number;
  visible: boolean;
  is_rails_part: boolean;
  rendered_html: string | null;
  label: string;
}

export interface PageData {
  id: number;
  slug: string;
  title: string;
  page_contents: PagePart[];
}

export interface BlockContent {
  content: string;
}

export interface BlockContents {
  [locale: string]: {
    blocks: {
      [key: string]: BlockContent;
    };
  };
}

export async function fetchPage(slug: string, locale: string = 'en'): Promise<PageData> {
  const response = await fetch(
    `${API_BASE}/api_public/v1/pages/by_slug/${slug}?locale=${locale}&include_rendered=true`,
    {
      headers: {
        'Accept': 'application/json',
        'X-Website-Slug': import.meta.env.PUBLIC_WEBSITE_SLUG
      }
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to fetch page: ${response.status}`);
  }

  return response.json();
}

export async function fetchPagePartForm(key: string, editingLocale: string): Promise<string> {
  const response = await fetch(
    `${API_BASE}/en/editor/page_parts/${encodeURIComponent(key)}?editing_locale=${editingLocale}`,
    {
      credentials: 'include',
      headers: {
        'Accept': 'text/html'
      }
    }
  );

  return response.text();
}

export async function updatePagePart(
  key: string,
  locale: string,
  blocks: Record<string, string>,
  csrfToken: string
): Promise<{ status: string; content?: BlockContents; errors?: string[] }> {
  const formData = new FormData();

  for (const [blockKey, value] of Object.entries(blocks)) {
    formData.append(
      `page_part[content][${locale}][blocks][${blockKey}][content]`,
      value
    );
  }

  const response = await fetch(
    `${API_BASE}/en/editor/page_parts/${encodeURIComponent(key)}`,
    {
      method: 'PATCH',
      credentials: 'include',
      headers: {
        'X-CSRF-Token': csrfToken
      },
      body: formData
    }
  );

  return response.json();
}

export async function fetchImages(): Promise<{ images: Image[] }> {
  const response = await fetch(`${API_BASE}/en/editor/images`, {
    credentials: 'include'
  });
  return response.json();
}

export async function uploadImage(file: File, csrfToken: string): Promise<{ success: boolean; image?: Image; errors?: string[] }> {
  const formData = new FormData();
  formData.append('image', file);

  const response = await fetch(`${API_BASE}/en/editor/images`, {
    method: 'POST',
    credentials: 'include',
    headers: {
      'X-CSRF-Token': csrfToken
    },
    body: formData
  });

  return response.json();
}
```

### Step 2: Page Part Renderer Component

```astro
---
// src/components/page-parts/PagePartRenderer.astro
import HeroCentered from './HeroCentered.astro';
import HeroSplit from './HeroSplit.astro';
import CtaBanner from './CtaBanner.astro';
import FeatureGrid from './FeatureGrid.astro';

interface Props {
  pagePartKey: string;
  renderedHtml?: string | null;
  blockContents?: Record<string, { content: string }>;
  editMode?: boolean;
}

const { pagePartKey, renderedHtml, blockContents, editMode = false } = Astro.props;

// Map page part keys to components
const componentMap: Record<string, any> = {
  'heroes/hero_centered': HeroCentered,
  'heroes/hero_split': HeroSplit,
  'cta/cta_banner': CtaBanner,
  'features/feature_grid_3col': FeatureGrid,
};

const Component = componentMap[pagePartKey];
const editableAttr = editMode ? { 'data-pwb-page-part': pagePartKey } : {};
---

{Component ? (
  <div {...editableAttr}>
    <Component blocks={blockContents} />
  </div>
) : renderedHtml ? (
  <div {...editableAttr} set:html={renderedHtml} />
) : (
  <div {...editableAttr} class="pwb-missing-part">
    <p>Unknown page part: {pagePartKey}</p>
  </div>
)}
```

### Step 3: Hero Component Example

```astro
---
// src/components/page-parts/HeroCentered.astro
interface Props {
  blocks: {
    background_image?: { content: string };
    pretitle?: { content: string };
    title?: { content: string };
    subtitle?: { content: string };
    cta_text?: { content: string };
    cta_link?: { content: string };
    cta_secondary_text?: { content: string };
    cta_secondary_link?: { content: string };
  };
}

const { blocks } = Astro.props;
const {
  background_image,
  pretitle,
  title,
  subtitle,
  cta_text,
  cta_link,
  cta_secondary_text,
  cta_secondary_link
} = blocks || {};
---

<section class="pwb-hero pwb-hero--centered">
  {background_image?.content && (
    <img
      src={background_image.content}
      alt={title?.content || 'Hero background'}
      class="pwb-hero__bg-image"
      loading="eager"
    />
  )}
  <div class="pwb-hero__overlay"></div>
  <div class="pwb-container">
    <div class="pwb-hero__content">
      {pretitle?.content && (
        <span class="pwb-hero__pretitle">{pretitle.content}</span>
      )}
      <h1 class="pwb-hero__title">{title?.content}</h1>
      {subtitle?.content && (
        <p class="pwb-hero__subtitle">{subtitle.content}</p>
      )}
      {cta_text?.content && (
        <div class="pwb-hero__actions">
          <a href={cta_link?.content || '#'} class="pwb-btn pwb-btn--primary pwb-btn--lg">
            {cta_text.content}
          </a>
          {cta_secondary_text?.content && (
            <a href={cta_secondary_link?.content || '#'} class="pwb-btn pwb-btn--outline pwb-btn--lg">
              {cta_secondary_text.content}
            </a>
          )}
        </div>
      )}
    </div>
  </div>
</section>

<style>
  .pwb-hero {
    position: relative;
    min-height: 60vh;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }

  .pwb-hero__bg-image {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    object-fit: cover;
    z-index: 0;
  }

  .pwb-hero__overlay {
    position: absolute;
    inset: 0;
    background: linear-gradient(to bottom, rgba(0,0,0,0.4), rgba(0,0,0,0.6));
    z-index: 1;
  }

  .pwb-hero__content {
    position: relative;
    z-index: 2;
    text-align: center;
    color: white;
    max-width: 800px;
    padding: 2rem;
  }

  .pwb-hero__pretitle {
    font-size: 1rem;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    opacity: 0.9;
  }

  .pwb-hero__title {
    font-size: 3rem;
    font-weight: 700;
    margin: 0.5rem 0;
  }

  .pwb-hero__subtitle {
    font-size: 1.25rem;
    opacity: 0.9;
    margin-bottom: 2rem;
  }

  .pwb-hero__actions {
    display: flex;
    gap: 1rem;
    justify-content: center;
    flex-wrap: wrap;
  }
</style>
```

### Step 4: Dynamic Page Route

```astro
---
// src/pages/[...slug].astro
import BaseLayout from '../layouts/BaseLayout.astro';
import PagePartRenderer from '../components/page-parts/PagePartRenderer.astro';
import { fetchPage } from '../lib/api';

const { slug = 'home' } = Astro.params;
const locale = Astro.url.searchParams.get('locale') || 'en';
const editMode = Astro.url.searchParams.get('edit_mode') === 'true';

let page;
try {
  page = await fetchPage(slug as string, locale);
} catch (error) {
  return Astro.redirect('/404');
}
---

<BaseLayout title={page.title}>
  {editMode && (
    <script src="/scripts/edit-mode.js"></script>
  )}

  <main>
    {page.page_contents
      .filter(part => part.visible && !part.is_rails_part)
      .sort((a, b) => a.sort_order - b.sort_order)
      .map(part => (
        <PagePartRenderer
          pagePartKey={part.page_part_key}
          renderedHtml={part.rendered_html}
          editMode={editMode}
        />
      ))
    }
  </main>
</BaseLayout>
```

### Step 5: Editor Shell

```astro
---
// src/pages/edit/[...path].astro
import EditorLayout from '../../layouts/EditorLayout.astro';

const { path = '' } = Astro.params;
const locale = 'en'; // Or get from context
const iframeSrc = `/${path}?edit_mode=true`;
const supportedLocales = ['en', 'es', 'fr']; // Get from API or config
---

<EditorLayout title="PWB Editor">
  <div class="pwb-editor-main">
    <!-- Toolbar -->
    <div class="pwb-editor-toolbar">
      <div class="pwb-editor-logo">
        <svg>...</svg> PWB Editor
      </div>
      <div class="pwb-editor-center">
        <div class="pwb-editor-address-bar">
          <span id="pwb-iframe-url">{iframeSrc}</span>
        </div>
      </div>
      <a href="/" class="pwb-btn-exit">Exit</a>
    </div>

    <!-- Iframe -->
    <div class="pwb-iframe-container">
      <iframe src={iframeSrc} id="pwb-site-frame" name="pwb-site-frame"></iframe>
    </div>
  </div>

  <!-- Bottom Panel -->
  <div id="pwb-editor-panel" class="pwb-editor-panel">
    <div class="pwb-panel-resize-handle" id="pwb-resize-handle"></div>
    <div class="pwb-panel-header">
      <span class="pwb-panel-title">Content Editor</span>
      <div class="pwb-panel-actions">
        <select id="pwb-locale-select">
          {supportedLocales.map(loc => (
            <option value={loc} selected={loc === locale}>{loc.toUpperCase()}</option>
          ))}
        </select>
        <button id="pwb-toggle-panel">▼</button>
      </div>
    </div>
    <div class="pwb-panel-content" id="panel-content">
      <div class="pwb-panel-placeholder">
        <p>Click an editable element on the page to edit its content.</p>
      </div>
    </div>
  </div>

  <!-- Image Picker Modal -->
  <div id="pwb-image-picker-modal" class="pwb-modal">
    <!-- Modal content -->
  </div>
</EditorLayout>

<script>
  // Editor JavaScript (see inline_editor_specification.md for full implementation)
  import { fetchPagePartForm, updatePagePart, fetchImages, uploadImage } from '../../lib/api';

  let editingLocale = 'en';
  let currentPagePartKey: string | null = null;
  const panel = document.getElementById('pwb-editor-panel')!;
  const contentPanel = document.getElementById('panel-content')!;

  // Listen for element selection from iframe
  window.addEventListener('message', async (event) => {
    if (event.data.type === 'pwb:element:selected') {
      const key = event.data.payload.key;
      currentPagePartKey = key;

      // Expand panel
      panel.classList.remove('pwb-panel-collapsed');

      // Load form
      contentPanel.innerHTML = '<div class="pwb-loading">Loading...</div>';
      try {
        const html = await fetchPagePartForm(key, editingLocale);
        contentPanel.innerHTML = html;
        attachFormHandler();
      } catch (err) {
        contentPanel.innerHTML = '<div class="pwb-error">Error loading editor</div>';
      }
    }
  });

  function attachFormHandler() {
    const form = document.getElementById('pwb-editor-form') as HTMLFormElement;
    if (!form) return;

    form.addEventListener('submit', async (e) => {
      e.preventDefault();

      const formData = new FormData(form);
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';

      try {
        const response = await fetch(form.action, {
          method: 'PATCH',
          body: formData,
          headers: { 'X-CSRF-Token': csrfToken }
        });

        const data = await response.json();

        if (data.status === 'success') {
          showNotification('Saved!', 'success');
          // Reload iframe
          (document.getElementById('pwb-site-frame') as HTMLIFrameElement)
            .contentWindow?.location.reload();
        } else {
          showNotification('Error: ' + (data.errors?.join(', ') || 'Unknown'), 'error');
        }
      } catch (err) {
        showNotification('Network error', 'error');
      }
    });
  }

  function showNotification(message: string, type: 'success' | 'error') {
    // Implementation
  }
</script>
```

---

## Complete Code Examples

### Example: Full Edit Workflow

```typescript
// 1. User navigates to /edit/about-us
// 2. Editor shell loads with iframe src="/about-us?edit_mode=true"
// 3. Site loads with edit mode script
// 4. User clicks on hero section
// 5. postMessage sent: { type: 'pwb:element:selected', payload: { key: 'heroes/hero_centered' } }
// 6. Editor fetches form: GET /en/editor/page_parts/heroes/hero_centered?editing_locale=en
// 7. Form displayed in panel
// 8. User edits title and clicks Save
// 9. PATCH request sent with form data
// 10. Server updates block_contents, returns success
// 11. Iframe reloads to show updated content
```

### Example: Handling Multiple Locales

```typescript
// User switches locale selector from EN to ES
editingLocale = 'es';

// If form is loaded, reload with new locale
if (currentPagePartKey) {
  const html = await fetchPagePartForm(currentPagePartKey, 'es');
  contentPanel.innerHTML = html;
  // Form now shows Spanish content for editing
}

// When saving, data goes to the ES locale bucket:
// page_part[content][es][blocks][title][content]=Nuevo Título
```

### Example: Creating a New Page Part Component

```astro
---
// src/components/page-parts/TeamGrid.astro
interface TeamMember {
  name: { content: string };
  role: { content: string };
  photo: { content: string };
  bio: { content: string };
}

interface Props {
  blocks: {
    title?: { content: string };
    subtitle?: { content: string };
    members?: { content: string }; // JSON array of team members
  };
}

const { blocks } = Astro.props;
const members: TeamMember[] = blocks.members?.content
  ? JSON.parse(blocks.members.content)
  : [];
---

<section class="pwb-team-grid">
  <div class="pwb-container">
    {blocks.title?.content && <h2>{blocks.title.content}</h2>}
    {blocks.subtitle?.content && <p class="subtitle">{blocks.subtitle.content}</p>}

    <div class="team-members">
      {members.map(member => (
        <div class="team-member">
          {member.photo?.content && (
            <img src={member.photo.content} alt={member.name?.content} />
          )}
          <h3>{member.name?.content}</h3>
          <p class="role">{member.role?.content}</p>
          <p class="bio">{member.bio?.content}</p>
        </div>
      ))}
    </div>
  </div>
</section>
```

---

## Testing Checklist

### API Integration
- [ ] `GET /api_public/v1/pages/by_slug/:slug` returns page data
- [ ] `include_rendered=true` includes pre-rendered HTML
- [ ] Locale parameter affects content language

### Edit Mode
- [ ] `?edit_mode=true` activates edit mode styling
- [ ] Editable elements have `data-pwb-page-part` attribute
- [ ] Hover shows blue dashed outline
- [ ] Click sends postMessage to parent

### Editor
- [ ] Editor shell loads at `/edit/*`
- [ ] Iframe displays site with edit_mode
- [ ] postMessage received and form loaded
- [ ] Locale selector changes editing language
- [ ] Form submission saves content
- [ ] Success notification and iframe reload

### Image Picker
- [ ] Image list loads from API
- [ ] Clicking image fills input
- [ ] Upload creates new image
- [ ] Modal opens/closes correctly

---

## Related Documentation

- [Inline Editor Specification](./inline_editor_specification.md) - Complete editor architecture
- [API Public Reference](./api_public_reference.md) - Full API documentation
- [Theme Development Guide](./theme_development.md) - Creating custom themes
