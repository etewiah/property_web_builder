# PropertyWebBuilder Content Management Analysis

## Overview

This document analyzes how content and text is currently stored, managed, and edited in the PropertyWebBuilder application. It identifies existing rich text editing capabilities and models that could benefit from enhanced text editing features.

---

## 1. Current Content Storage Approach

### 1.1 Text Column Types in Database

**Simple Text Columns (VARCHAR/TEXT):**
- `pwb_contents.translations` - JSONB column storing translatable content
- `pwb_pages.translations` - JSONB column storing page translations  
- `pwb_links.translations` - JSONB column storing link translations
- `pwb_messages.content` - TEXT column for message bodies
- `pwb_realty_assets.description` - TEXT column for property descriptions
- `pwb_props.meta_description` - TEXT column for SEO descriptions
- `pwb_pages.meta_description` - TEXT column for page SEO descriptions
- `pwb_page_parts.template` - TEXT column for Liquid template storage

**Translation Fields:**
- `pwb_prop_translations.description` - TEXT, translation table
- `pwb_prop_translations.title` - VARCHAR, translation table
- `pwb_page_translations.raw_html` - TEXT column for HTML content
- `pwb_page_translations.page_title` - VARCHAR
- `pwb_page_translations.link_title` - VARCHAR
- `pwb_content_translations.raw` - TEXT for content translations

**No ActiveRecord Migrations Required Yet:**
The current schema supports these text columns without special setup.

### 1.2 Translation Strategy: Mobility Gem

The application uses **Mobility gem** (gem 'mobility' in Gemfile) for multi-language content management.

**Models using Mobility:**
```ruby
# Content Model
class Content < ApplicationRecord
  extend Mobility
  translates :raw  # Stores in JSONB translations column
end

# Page Model  
class Page < ApplicationRecord
  extend Mobility
  translates :raw_html, :page_title, :link_title
end

# Link Model
class Link < ApplicationRecord
  extend Mobility
  translates :link_title
end

# SaleListing Model
class SaleListing < ApplicationRecord
  extend Mobility
  translates :title, :description
end

# RentalListing Model
class RentalListing < ApplicationRecord
  extend Mobility
  translates :title, :description
end

# RealtyAsset Model
class RealtyAsset < ApplicationRecord
  # Translations stored via associated models
end
```

**How Mobility Works:**
- Uses container backend with JSONB columns (`translations` column)
- Provides locale-aware accessors: `content.raw_en`, `content.raw_es`, etc.
- Single JSONB column per model instead of separate translation tables
- Efficient for multi-tenant, multi-locale scenarios

---

## 2. Current Rich Text Editing Capabilities

### 2.1 Quill Editor (Already Implemented)

**Location:** `/app/views/site_admin/pages/page_parts/edit.html.erb`

**Integration Details:**
- Uses Quill v2.0.2 via CDN
- Rich text formatting: bold, italic, underline, strike
- Headers (h1-h3)
- Text colors and background colors
- Lists (ordered/bullet)
- Text alignment
- Hyperlinks
- Image insertion via custom image picker

**JavaScript Implementation:**
```javascript
const quill = new Quill(`#${editorId}`, {
  theme: 'snow',
  modules: {
    toolbar: {
      container: [
        [{ 'header': [1, 2, 3, false] }],
        ['bold', 'italic', 'underline', 'strike'],
        [{ 'color': [] }, { 'background': [] }],
        [{ 'list': 'ordered'}, { 'list': 'bullet' }],
        [{ 'align': [] }],
        ['link', 'image'],
        ['clean']
      ],
      handlers: {
        'image': function() {
          openImagePickerForQuill(fieldId);
        }
      }
    }
  }
});
```

**Where It's Used:**
- Page part editing (site_admin/pages/page_parts/edit)
- Configurable via `editor_setup` JSON field in PagePart model
- Block-based editor with support for multiple block types

### 2.2 Page Part Editor System

**Block Configuration in PagePart Model:**

The `editor_setup` JSON field defines editor blocks:
```json
{
  "editorBlocks": [
    {
      "label": "hero_heading",
      "isHtml": true,
      "isSingleLineText": false,
      "isImage": false,
      "isMultipleLineText": false
    },
    {
      "label": "hero_description",
      "isHtml": true
    },
    {
      "label": "hero_image",
      "isImage": true
    }
  ]
}
```

**Block Content Storage:**
- Stored in `pwb_page_parts.block_contents` JSON column
- Structure: `{ "block_label": { "content": "..." } }`
- Supports multiple content types per block:
  - `isHtml: true` - Quill rich text editor
  - `isSingleLineText: true` - Text input
  - `isMultipleLineText: true` - Textarea
  - `isImage: true` - Image picker

### 2.3 Image Management System

**Features:**
- Image library picker modal
- Drag and drop support
- Upload new images
- Image preview
- Integrated with ActiveStorage
- Thumbnail support
- Multiple image selection

**Location:** Implemented in page part editor view with JavaScript handlers

---

## 3. Content Models & Their Text Fields

### 3.1 Page-Related Content

**Pwb::Page**
- `raw_html` (TEXT via Mobility) - Main page HTML content
- `page_title` (VARCHAR via Mobility) - Page title
- `link_title` (VARCHAR via Mobility) - Navigation link title
- `meta_description` (TEXT) - SEO description
- `seo_title` (VARCHAR) - SEO title

**Pwb::Content**
- `raw` (TEXT via Mobility) - Content block text
- Used as shared content blocks
- Can be included on multiple pages via page_contents join table

**Pwb::PagePart**
- `block_contents` (JSON) - Structured block data with HTML/images
- `template` (TEXT) - Liquid template for rendering
- `editor_setup` (JSON) - Configuration for the editor UI

### 3.2 Property/Listing-Related Content

**Pwb::SaleListing** (and RentalListing)
- `title` (VARCHAR via Mobility) - Marketing title
- `description` (TEXT via Mobility) - Full property description
- Multi-locale support through Mobility

**Pwb::RealtyAsset**
- `description` (TEXT) - Property description (currently plain text)
- `title` (VARCHAR) - Property title
- Associated with sale/rental listings

**Pwb::PropTranslation** (Legacy translation table)
- `description` (TEXT) - Translated property description
- `title` (VARCHAR) - Translated property title

### 3.3 Message/Contact Content

**Pwb::Message**
- `content` (TEXT) - User message/inquiry text
- `title` (VARCHAR) - Message subject
- Simple text, no rich text

### 3.4 Navigation & Links

**Pwb::Link**
- `link_title` (VARCHAR via Mobility) - Link text
- Simple text only

---

## 4. Existing ActionText Status

**Finding:** No ActionText integration currently exists in the codebase.

Rails ActionText (built-in rich text solution) is not being used. Instead, the app uses:
1. **Quill Editor** for manual rich text editing (page parts only)
2. **Plain Text/JSONB** for most content storage
3. **Mobility** for translations

**Reasons for Not Using ActionText:**
- Quill provides more flexible, configurable UI
- Mobility already handles translations efficiently
- ActionText primarily targets single-language content
- Custom block-based editor meets specific needs

---

## 5. Editor Gems & Libraries

**Installed:**
- ✓ `mobility` - Translation management (JSONB backend)
- ✓ `quill` (via CDN) - Rich text editor for page parts
- ✗ No ActionText
- ✗ No Trix editor
- ✗ No TinyMCE
- ✗ No CKEditor
- ✗ No Froala editor

**Other Content-Related Gems:**
- `liquid` - Template rendering engine
- `simple_form` - Form builder
- `active_storage_dashboard` - Image/asset management UI
- `image_processing` - Image optimization

---

## 6. Models That Could Benefit from Rich Text

### 6.1 High Priority (User-Facing Content)

**1. SaleListing / RentalListing**
- Currently: Plain text `description` field
- Benefit: Enable formatted property descriptions with images, lists, etc.
- Impact: Would significantly improve property presentation
- Current UI: Form inputs in `site_admin/props/rental_listings/_form.html.erb`

**2. Message / Contact Inquiries**
- Currently: Plain text `content` field
- Benefit: Preserve formatting if users copy/paste formatted text
- Note: Lower priority (mostly automated)

**3. RealtyAsset Description**
- Currently: Plain text `description`
- Note: Currently returns `nil` (marketing text belongs to listing instead)
- Could be repurposed for structured property details

### 6.2 Medium Priority (Admin/Presentation)

**1. Page Meta Descriptions**
- Currently: Plain text
- Could support basic formatting for better SEO previews

**2. Content Blocks**
- Currently: Stored as translated raw text
- Already supports HTML via Mobility
- Could benefit from visual editor for non-technical users

### 6.3 Lower Priority

**1. Links**
- Currently: Simple text titles
- Rich text unnecessary for navigation

**2. Messages**
- Currently: Plain text from contact forms
- Minimal benefit from rich text

---

## 7. Implementation Recommendations

### 7.1 Short Term (Enhance Existing)

**1. Extend Quill Editor to Property Descriptions**
- Reuse existing Quill setup from page parts
- Add to property editing forms
- Store HTML in `description` field
- Could use a migration to wrap existing text descriptions in HTML

**2. Create Shared Editor Component**
- Extract Quill editor into Rails component (ViewComponent)
- Make reusable across different models
- Centralize JavaScript handlers

**3. Improve Image Picker Integration**
- Already supports Quill; extend to property images
- Make modal-based image picker reusable

### 7.2 Medium Term (Add Infrastructure)

**1. ActionText Integration (Optional)**
- If more WYSIWYG editors needed across models
- Provides better Rails integration
- Requires:
  - ActionText gem (Rails 6+, available in Rails 8.1)
  - Rich_text_areas table
  - Migration for each model

**2. Markdown Editor Option**
- Add support for Markdown + preview
- Less heavyweight than Quill
- Good for technical users and developers

**3. Structured Content Blocks**
- Enhance PagePart system with more block types
- Video embeds, custom callouts, testimonials, etc.

### 7.3 Long Term (Content Management System)**

**1. Block-Based Page Builder**
- Extend current PagePart editor
- Drag-and-drop interface
- Pre-built component library

**2. Property Description Templates**
- Guided editing with templates
- Auto-populate with common sections
- Ensures consistency across properties

**3. Content Versioning**
- Track history of changes
- Restore previous versions
- Audit trail for compliance

---

## 8. Database Schema Summary

### Text Columns by Type

```
VARCHAR (String)
├── page_title (180 chars)
├── seo_title
├── link_title
└── title (on listings/assets)

TEXT
├── raw_html (page content)
├── meta_description
├── description (properties)
├── content (messages)
└── template (liquid templates)

JSONB
├── translations (Content, Page, Link, Listing)
├── block_contents (PagePart)
├── editor_setup (PagePart)
└── details (various models)
```

### Translation Tables

```
pwb_content_translations
├── content_id (FK)
├── locale
└── raw (TEXT)

pwb_page_translations
├── page_id (FK)
├── locale
├── raw_html
├── page_title
└── link_title

pwb_prop_translations
├── prop_id (FK)
├── locale
├── title
├── description
└── realty_asset_id (FK)

pwb_link_translations
├── link_id (FK)
├── locale
└── link_title
```

---

## 9. Current Content Editing Workflow

### Admin Panel Flow

```
Site Admin Dashboard
  ├── Pages Editor (site_admin/pages)
  │   └── Page Parts Editor (page_parts/edit)
  │       └── Quill Rich Text + Image Picker
  │
  ├── Content Manager (site_admin/contents)
  │   └── Translatable text blocks (simple form)
  │
  └── Property Management (site_admin/props)
      ├── Sale Listings (plain form inputs)
      └── Rental Listings (plain form inputs)

Tenant Admin Dashboard
  ├── Website Settings
  └── (Inherits same content management)
```

### View Rendering

```
Page Part Template (Liquid)
  ├── Interpolates block_contents JSON
  ├── Renders Quill HTML as-is
  └── Serves via page show action

Property Display
  ├── Fetches description from listing
  ├── Currently plain text
  └── Rendered in property detail page
```

---

## 10. Technical Debt & Future Considerations

### Current Limitations

1. **Rich Text Only in Page Parts**
   - Property descriptions still plain text
   - Inconsistent editing experience

2. **No Built-in Validation**
   - No length limits on rich text
   - No sanitization policy defined
   - Potential XSS vectors if not careful

3. **Image Management Scattered**
   - ActiveStorage for file storage
   - Custom image picker for page parts
   - No unified library for property images

4. **Multi-Locale Complexity**
   - Mobility provides translations
   - Editors must switch locales manually
   - No side-by-side locale editing

5. **No Content Scheduling**
   - Can't schedule content publication
   - No draft/published states for content

### Migration Path if Adopting ActionText

```ruby
# Would need:
class SaleListing < ApplicationRecord
  has_rich_text :description
  # Requires rich_text_areas table
end

# View:
<%= form.rich_text_area :description %>
```

---

## 11. Recommendations Summary

### Immediate Actions
1. Extract Quill editor into reusable component
2. Document current editor_setup JSON schema
3. Add rich text support to property descriptions
4. Improve image library integration

### Next Quarter
1. Consider ActionText if needs expand beyond current scope
2. Implement content versioning for audit trail
3. Add content scheduling capability
4. Create property description templates

### Long-term Vision
1. Block-based page builder with drag-drop
2. Multi-locale editing interface
3. Content preview across devices
4. Structured data export (JSON-LD, schema.org)

---

## Appendix: File Locations

### Views
- `/app/views/site_admin/pages/page_parts/edit.html.erb` - Main page part editor with Quill
- `/app/views/site_admin/props/rental_listings/_form.html.erb` - Rental form (needs rich text)
- `/app/views/site_admin/props/sale_listings/_form.html.erb` - Sale form (needs rich text)

### Models
- `/app/models/pwb/content.rb` - Translatable content blocks
- `/app/models/pwb/page.rb` - CMS pages
- `/app/models/pwb/page_part.rb` - Page sections with templates
- `/app/models/pwb/sale_listing.rb` - Sale transaction with descriptions
- `/app/models/pwb/rental_listing.rb` - Rental transaction with descriptions
- `/app/models/pwb/realty_asset.rb` - Physical property data

### Database
- `/db/schema.rb` - Current schema definition
- Translation tables: `pwb_*_translations`
- JSONB columns: `translations`, `block_contents`, `editor_setup`

### Assets
- Quill: CDN loaded in page_parts/edit.html.erb
- No local JavaScript for Quill (uses CDN)
- Custom scripts in edit.html.erb for image picker integration
