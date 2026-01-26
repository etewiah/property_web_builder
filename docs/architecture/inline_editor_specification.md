# PWB Inline Editor - Technical Specification

This document provides complete technical details for the PWB inline content editor, sufficient for re-implementation in any frontend framework (e.g., Astro.js).

## Overview

The inline editor is a visual content editing interface that allows authenticated users to edit page content directly on the website. It uses an **iframe-based architecture** where:

1. An **Editor Shell** (parent window) hosts the UI chrome and editing controls
2. The **Site** (iframe) displays the actual website with editable elements highlighted
3. **postMessage API** enables communication between the two

```
┌─────────────────────────────────────────────────────────────┐
│  EDITOR SHELL (Parent Window)                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Toolbar: Logo | Address Bar | Exit                      ││
│  ├─────────────────────────────────────────────────────────┤│
│  │                                                         ││
│  │          IFRAME (Site with ?edit_mode=true)             ││
│  │                                                         ││
│  │    [User clicks element with data-pwb-page-part]        ││
│  │              │                                          ││
│  │              │ postMessage('pwb:element:selected')      ││
│  │              ▼                                          ││
│  ├─────────────────────────────────────────────────────────┤│
│  │ Bottom Panel:                                           ││
│  │   - Locale Selector (EN | ES | FR...)                   ││
│  │   - Edit Form (fetched via AJAX)                        ││
│  │   - Save button                                         ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## URLs and Routes

### Editor Shell Routes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/:locale/edit` | Editor shell (loads homepage in iframe) |
| GET | `/:locale/edit/*path` | Editor shell (loads specific page in iframe) |

### API Routes (Editor Namespace)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/:locale/editor/page_parts/:key` | Fetch edit form for a page part |
| PATCH | `/:locale/editor/page_parts/:key` | Update page part content |
| GET | `/:locale/editor/images` | List available images |
| POST | `/:locale/editor/images` | Upload new image |
| GET | `/:locale/editor/theme_settings` | Get current theme settings |
| PATCH | `/:locale/editor/theme_settings` | Update theme settings |

Note: Page part keys can contain slashes (e.g., `faqs/faq_accordion`), so routes use `*id` wildcard.

## Component 1: Site (iframe) - Edit Mode Behavior

When the site is loaded with `?edit_mode=true`:

### 1.1 Marking Editable Elements

Elements that can be edited must have a `data-pwb-page-part` attribute with the page part key:

```html
<!-- Example: Editable content block -->
<div data-pwb-page-part="homepage_hero">
  <h1>Welcome to Our Site</h1>
  <p>This content is editable</p>
</div>

<!-- Example: Another editable section -->
<section data-pwb-page-part="about_intro">
  <p>About us content here...</p>
</section>
```

### 1.2 Client-Side Script (editor_client.js)

This script must be included on the site **only when `edit_mode=true`**:

```javascript
// PWB Editor Client Script
// Injected into the public site when in edit mode

document.addEventListener('DOMContentLoaded', () => {
  // Find all editable elements
  const editableElements = document.querySelectorAll('[data-pwb-page-part]');

  editableElements.forEach(el => {
    // Visual styling for edit mode
    el.style.cursor = 'pointer';
    el.style.outline = '2px dashed transparent';
    el.style.transition = 'outline 0.2s';

    // Hover effect - blue dashed outline
    el.addEventListener('mouseover', (e) => {
      e.stopPropagation();
      el.style.outline = '2px dashed #3b82f6';
    });

    el.addEventListener('mouseout', (e) => {
      e.stopPropagation();
      el.style.outline = '2px dashed transparent';
    });

    // Click handler - notify parent editor
    el.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();

      const pagePartKey = el.getAttribute('data-pwb-page-part');

      // Send message to parent (editor shell)
      window.parent.postMessage({
        type: 'pwb:element:selected',
        payload: {
          key: pagePartKey,
          content: el.innerHTML  // Optional: current content
        }
      }, '*');
    });
  });
});
```

## Component 2: Editor Shell (Parent Window)

### 2.1 HTML Structure

```html
<!DOCTYPE html>
<html>
<head>
  <title>PWB Editor</title>
  <meta name="csrf-token" content="[CSRF_TOKEN]">
  <meta name="pwb-locale" content="en">
  <meta name="pwb-supported-locales" content="en,es,fr">
</head>
<body class="pwb-editor-body">
  <!-- Main Area -->
  <div class="pwb-editor-main">
    <!-- Toolbar -->
    <div class="pwb-editor-toolbar">
      <div class="pwb-editor-logo">PWB Editor</div>
      <div class="pwb-editor-address-bar">
        <span id="pwb-iframe-url">/</span>
      </div>
      <a href="/" class="pwb-btn-exit">Exit</a>
    </div>

    <!-- Iframe Container -->
    <div class="pwb-iframe-container">
      <iframe
        src="/?edit_mode=true"
        id="pwb-site-frame"
        name="pwb-site-frame">
      </iframe>
    </div>
  </div>

  <!-- Bottom Panel -->
  <div id="pwb-editor-panel" class="pwb-editor-panel">
    <!-- Resize Handle -->
    <div class="pwb-panel-resize-handle" id="pwb-resize-handle"></div>

    <!-- Panel Header -->
    <div class="pwb-panel-header">
      <span class="pwb-panel-title">Content Editor</span>
      <div class="pwb-panel-actions">
        <!-- Locale Selector -->
        <select id="pwb-locale-select">
          <option value="en">EN</option>
          <option value="es">ES</option>
        </select>
        <!-- Toggle Button -->
        <button id="pwb-toggle-panel">▼</button>
      </div>
    </div>

    <!-- Panel Content (dynamically loaded) -->
    <div class="pwb-panel-content" id="panel-content">
      <div class="pwb-panel-placeholder">
        <p>Click an editable element on the page to edit its content.</p>
      </div>
    </div>
  </div>

  <!-- Image Picker Modal -->
  <div id="pwb-image-picker-modal" class="pwb-modal">
    <!-- Modal content for image selection -->
  </div>
</body>
</html>
```

### 2.2 JavaScript - Message Handler

```javascript
// Track editing state
let editingLocale = 'en';  // Current locale being edited
let currentPagePartKey = null;
const editorBasePath = `/${pwbLocale}/editor`;

// Listen for messages from iframe
window.addEventListener('message', (event) => {
  if (event.data.type === 'pwb:element:selected') {
    const key = event.data.payload.key;
    currentPagePartKey = key;

    // Expand panel if collapsed
    panel.classList.remove('pwb-panel-collapsed');

    // Load the edit form
    loadPagePartForm(key);
  }
});

// Fetch and display edit form
function loadPagePartForm(key) {
  const contentPanel = document.getElementById('panel-content');
  contentPanel.innerHTML = '<div class="pwb-loading">Loading...</div>';

  fetch(`${editorBasePath}/page_parts/${key}?editing_locale=${editingLocale}`)
    .then(response => response.text())
    .then(html => {
      contentPanel.innerHTML = html;
      attachFormHandler();
    })
    .catch(err => {
      contentPanel.innerHTML = '<div class="pwb-error">Error loading editor</div>';
    });
}

// Handle form submission
function attachFormHandler() {
  const form = document.getElementById('pwb-editor-form');
  if (form) {
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const formData = new FormData(form);

      fetch(form.action, {
        method: 'PATCH',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      .then(res => res.json())
      .then(data => {
        if (data.status === 'success') {
          showNotification('Content saved successfully', 'success');
          // Refresh iframe to show changes
          document.getElementById('pwb-site-frame').contentWindow.location.reload();
        } else {
          showNotification('Error saving changes', 'error');
        }
      });
    });
  }
}

// Locale selector - changes editing locale (not site display locale)
document.getElementById('pwb-locale-select').addEventListener('change', (e) => {
  editingLocale = e.target.value;

  // Reload current form with new locale
  if (currentPagePartKey) {
    loadPagePartForm(currentPagePartKey);
  }
});
```

## Component 3: API Endpoints

### 3.1 GET `/editor/page_parts/:key`

Returns an HTML form for editing the specified page part.

**Query Parameters:**
- `editing_locale` (optional): The locale to edit content for (e.g., `en`, `es`)

**Response:** HTML partial containing the edit form

**Example Request:**
```
GET /en/editor/page_parts/homepage_hero?editing_locale=es
```

### 3.2 PATCH `/editor/page_parts/:key`

Updates the content for a page part.

**Request Body (FormData):**
```
page_part[content][en][blocks][title][content]=New Title
page_part[content][en][blocks][subtitle][content]=New Subtitle
page_part[content][en][blocks][image_src][content]=https://example.com/image.jpg
```

**Response (JSON):**
```json
{
  "status": "success",
  "content": {
    "en": {
      "blocks": {
        "title": { "content": "New Title" },
        "subtitle": { "content": "New Subtitle" },
        "image_src": { "content": "https://example.com/image.jpg" }
      }
    }
  }
}
```

**Error Response:**
```json
{
  "status": "error",
  "errors": ["Content cannot be blank"]
}
```

### 3.3 GET `/editor/images`

Lists available images for the image picker.

**Response (JSON):**
```json
{
  "images": [
    {
      "id": "content_123",
      "type": "content",
      "url": "https://example.com/uploads/image.jpg",
      "thumb_url": "https://example.com/uploads/image_thumb.jpg",
      "filename": "image.jpg",
      "description": "Hero background"
    },
    {
      "id": "website_456",
      "type": "website",
      "url": "https://example.com/uploads/logo.png",
      "thumb_url": "https://example.com/uploads/logo_thumb.png",
      "filename": "logo.png",
      "description": null
    }
  ]
}
```

**Image Types:**
- `content` - Content photos (from page parts/content blocks)
- `website` - Website-level images (logos, backgrounds)
- `property` - Property listing photos

### 3.4 POST `/editor/images`

Uploads a new image.

**Request Body (FormData):**
```
image: [File]
```

**Response (JSON):**
```json
{
  "success": true,
  "image": {
    "id": "content_789",
    "type": "content",
    "url": "https://example.com/uploads/new_image.jpg",
    "thumb_url": "https://example.com/uploads/new_image_thumb.jpg",
    "filename": "new_image.jpg"
  }
}
```

## Data Model: PagePart

### Database Schema

```sql
CREATE TABLE pwb_page_parts (
  id              BIGINT PRIMARY KEY,
  page_part_key   VARCHAR,           -- Unique identifier (e.g., "homepage_hero")
  page_slug       VARCHAR,           -- Associated page (optional)
  website_id      INTEGER,           -- Tenant ID (multi-tenant)
  block_contents  JSON,              -- Editable content blocks
  template        TEXT,              -- Liquid template (optional override)
  editor_setup    JSON,              -- Editor configuration
  locale          VARCHAR,           -- Default locale
  theme_name      VARCHAR,           -- Theme association
  show_in_editor  BOOLEAN DEFAULT TRUE,
  order_in_editor INTEGER,
  is_rails_part   BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMP,
  updated_at      TIMESTAMP
);
```

### block_contents JSON Structure

There are two supported structures:

**Structure A: Locale-based (recommended for multi-language)**
```json
{
  "en": {
    "blocks": {
      "title": { "content": "Welcome" },
      "subtitle": { "content": "Your journey starts here" },
      "image_src": { "content": "https://example.com/hero.jpg" },
      "cta_text": { "content": "Get Started" },
      "cta_link": { "content": "/signup" }
    }
  },
  "es": {
    "blocks": {
      "title": { "content": "Bienvenido" },
      "subtitle": { "content": "Tu viaje comienza aquí" },
      "image_src": { "content": "https://example.com/hero.jpg" },
      "cta_text": { "content": "Comenzar" },
      "cta_link": { "content": "/signup" }
    }
  }
}
```

**Structure B: Flat (legacy, single-language)**
```json
{
  "title": { "content": "Welcome" },
  "subtitle": { "content": "Your journey starts here" },
  "image_src": { "content": "https://example.com/hero.jpg" }
}
```

### Form Field Naming Convention

For locale-based structure:
```
page_part[content][LOCALE][blocks][BLOCK_KEY][content]

Examples:
page_part[content][en][blocks][title][content]=Welcome
page_part[content][es][blocks][title][content]=Bienvenido
```

For flat structure:
```
page_part[content][BLOCK_KEY]

Example:
page_part[content][title]=Welcome
```

## Field Type Detection

The editor auto-detects field types based on the block key name:

| Key Pattern | Field Type | Input Element |
|-------------|------------|---------------|
| `*image*`, `*photo*`, `*src*` | Image URL | Text input + image picker button |
| Content > 100 chars or contains `<` | Rich text | Textarea |
| All other | Plain text | Text input |

## Image Picker Integration

When a field is detected as an image:

1. Display text input for URL
2. Add "Browse" button to open image picker modal
3. Image picker shows:
   - Upload button (top)
   - Grid of available images
4. Clicking an image fills the input with its URL
5. Preview thumbnail shown below input

```javascript
// Global function called by "Browse" button
window.openImagePicker = function(inputElement) {
  currentImageInput = inputElement;
  imagePickerModal.classList.add('pwb-modal-open');
  loadImages();
};

// When image selected in picker
imageGrid.querySelectorAll('.pwb-image-item').forEach(item => {
  item.addEventListener('click', () => {
    const url = item.dataset.url;
    currentImageInput.value = url;
    currentImageInput.dispatchEvent(new Event('change'));
    imagePickerModal.classList.remove('pwb-modal-open');
  });
});
```

## Authentication

The editor requires authentication. The Rails implementation:

1. Uses Devise for user authentication
2. Checks `user.admin_for?(website)` for authorization
3. Supports `BYPASS_ADMIN_AUTH=true` env var for development/testing

For Astro.js implementation, you could:
- Use the proxy auth headers (`X-User-Id`, `X-User-Email`, `X-User-Role`, `X-Auth-Token`)
- Or implement your own auth check against the Rails backend

## postMessage Protocol

### Message: Element Selected

**Direction:** Site (iframe) → Editor Shell (parent)

```javascript
{
  type: 'pwb:element:selected',
  payload: {
    key: 'homepage_hero',      // page_part_key
    content: '<h1>...</h1>'    // Optional: current innerHTML
  }
}
```

### Future Messages (not yet implemented)

```javascript
// Editor → Site: Highlight element
{ type: 'pwb:element:highlight', payload: { key: 'homepage_hero' } }

// Editor → Site: Content updated (for live preview)
{ type: 'pwb:content:updated', payload: { key: 'homepage_hero', html: '...' } }

// Site → Editor: Navigation occurred
{ type: 'pwb:navigation', payload: { path: '/about-us' } }
```

## CSS Variables (Editor Theme)

```css
:root {
  --pwb-editor-bg: #1e293b;
  --pwb-editor-text: #f8fafc;
  --pwb-editor-border: #334155;
  --pwb-editor-primary: #3b82f6;
  --pwb-editor-toolbar-height: 50px;
  --pwb-editor-panel-height: 200px;
}
```

## Panel Resize Behavior

The bottom panel supports drag-to-resize:

1. Panel height stored in `localStorage` as `pwb-editor-panel-height`
2. Minimum height: 100px
3. Maximum height: 70% of viewport
4. When collapsed, height is 44px (header only)
5. Dragging up from collapsed state auto-expands

## Testing Checklist for Astro Implementation

1. [ ] Editor shell loads at `/edit` and `/edit/*path`
2. [ ] Iframe loads site with `?edit_mode=true`
3. [ ] Editable elements show blue dashed outline on hover
4. [ ] Clicking element sends postMessage to parent
5. [ ] Editor receives message and fetches form
6. [ ] Form displays all content blocks for the page part
7. [ ] Locale selector switches editing language
8. [ ] Form submission saves via PATCH
9. [ ] Success shows notification and reloads iframe
10. [ ] Image picker opens and lists images
11. [ ] Image upload works
12. [ ] Selecting image fills input
13. [ ] Panel collapse/expand works
14. [ ] Panel resize works and persists

## Security Considerations

1. **CSRF Protection:** All PATCH/POST requests must include CSRF token
2. **Multi-tenant Isolation:** Page parts must be scoped to `website_id`
3. **Authentication:** Verify user has admin access to the website
4. **Content Sanitization:** Be careful with `innerHTML` - sanitize before rendering
5. **postMessage Origin:** Consider validating message origin in production

## Related Files (Rails Implementation)

- `app/controllers/pwb/editor_controller.rb` - Editor shell
- `app/controllers/pwb/editor/page_parts_controller.rb` - Page part CRUD
- `app/controllers/pwb/editor/images_controller.rb` - Image API
- `app/views/pwb/editor/show.html.erb` - Editor shell view
- `app/views/pwb/editor/_sidebar.html.erb` - Panel partial
- `app/views/pwb/editor/page_parts/_form.html.erb` - Edit form partial
- `app/assets/javascripts/pwb/editor_client.js` - Site-side script
- `app/assets/stylesheets/pwb/editor.css` - Editor styles
- `app/models/pwb/page_part.rb` - Data model
- `tests/e2e/admin/editor.spec.js` - Playwright tests
