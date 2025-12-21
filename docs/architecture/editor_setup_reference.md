# Editor Setup Reference Guide

## Overview

The PropertyWebBuilder uses a **block-based editor system** for page parts. This document explains the editor configuration schema and how to extend it.

## Editor Setup JSON Schema

The `editor_setup` JSON field in `pwb_page_parts` table defines which editor blocks are displayed and their configuration.

### Schema Structure

```json
{
  "tabTitleKey": "translations.key.for.tab.title",
  "editorBlocks": [
    [
      {
        "label": "block_key",
        "isHtml": true|false,
        "isSingleLineText": true|false,
        "isMultipleLineText": true|false,
        "isImage": true|false
      }
    ]
  ]
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `label` | string | YES | Unique identifier for this block. Used as key in block_contents |
| `isHtml` | boolean | NO | If true, renders Quill rich text editor |
| `isSingleLineText` | boolean | NO | If true, renders `<input type="text">` |
| `isMultipleLineText` | boolean | NO | If true, renders `<textarea>` |
| `isImage` | boolean | NO | If true, renders image picker |
| `tabTitleKey` | string | NO | Translation key for tab display name |

**Note:** Blocks are organized in a 2D array (columns), but typically all blocks go in first column.

## Block Content Structure

Block contents are stored in `pwb_page_parts.block_contents` JSON:

```json
{
  "en": {
    "blocks": {
      "hero_heading": {
        "content": "<h1>Welcome</h1>"
      },
      "hero_description": {
        "content": "<p>This is the hero section.</p>"
      },
      "hero_image": {
        "content": "/rails/active_storage/blobs/..."
      }
    }
  }
}
```

## Real-World Example

From the codebase, page parts typically use this structure:

```erb
<% editor_setup = @page_part.editor_setup || {} %>
<% editor_blocks = editor_setup['editorBlocks'] || [] %>
<% locale_blocks = @block_contents[@current_locale_base]&.dig('blocks') || {} %>

<% if editor_blocks.any? %>
  <div class="space-y-6">
    <% editor_blocks.each_with_index do |column_blocks, col_index| %>
      <% column_blocks.each do |block_config| %>
        <% label = block_config['label'] %>
        <% block_value = locale_blocks.dig(label, 'content') || '' %>

        <% if block_config['isHtml'] == 'true' || block_config['isHtml'] == true %>
          <!-- Quill Rich Text Editor -->
          <div class="quill-wrapper border border-gray-300 rounded-lg overflow-hidden">
            <div id="quill-<%= label.parameterize %>" 
                 class="quill-editor" 
                 style="min-height: 200px;">
              <%= raw block_value %>
            </div>
          </div>
```

## Editor Types & Their Output

### 1. HTML Editor (isHtml: true)

**UI:** Quill rich text editor with toolbar

**Toolbar Includes:**
- Headers (h1, h2, h3)
- Text formatting (bold, italic, underline, strike)
- Colors and background colors
- Lists (ordered, bullet)
- Text alignment
- Links
- Image insertion
- Clear formatting

**Stored As:** HTML string
```json
{
  "hero_heading": {
    "content": "<h1>Welcome to Our Website</h1>"
  }
}
```

**Quill Configuration:**
```javascript
const quill = new Quill(`#quill-${fieldId}`, {
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
      ]
    }
  },
  placeholder: 'Enter content here...'
});
```

### 2. Single Line Text (isSingleLineText: true)

**UI:** HTML `<input type="text">`

**Stored As:** Plain text string
```json
{
  "page_title": {
    "content": "My Page Title"
  }
}
```

**Use Cases:**
- Page titles
- Section headings
- Call-to-action button text
- Short labels

### 3. Multiple Line Text (isMultipleLineText: true)

**UI:** HTML `<textarea rows="4">`

**Stored As:** Plain text string (multiline)
```json
{
  "description": {
    "content": "Line 1\nLine 2\nLine 3"
  }
}
```

**Use Cases:**
- Longer descriptions
- Instructions
- Comments
- Text that needs line breaks

### 4. Image Editor (isImage: true)

**UI:** 
- Image preview
- "Choose from Library" button (opens modal)
- "Upload New" file picker
- Clear button to remove image

**Features:**
- Image library picker with thumbnails
- Drag-and-drop upload
- Image preview
- Delete/clear functionality

**Stored As:** Image URL (string)
```json
{
  "hero_image": {
    "content": "/rails/active_storage/blobs/abc123..."
  }
}
```

**API Integration:**
- GET `/site_admin/images` - List available images
- POST `/site_admin/images` - Upload new image

## Editor Setup Examples

### Simple Page (Hero + Content)

```json
{
  "tabTitleKey": "editor.setup.tabs.hero_section",
  "editorBlocks": [
    [
      {
        "label": "hero_heading",
        "isHtml": true
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
  ]
}
```

### Complex Page (Multiple Sections)

```json
{
  "editorBlocks": [
    [
      {
        "label": "page_title",
        "isSingleLineText": true
      },
      {
        "label": "intro_text",
        "isMultipleLineText": true
      }
    ],
    [
      {
        "label": "section_1_heading",
        "isSingleLineText": true
      },
      {
        "label": "section_1_content",
        "isHtml": true
      },
      {
        "label": "section_1_image",
        "isImage": true
      }
    ]
  ]
}
```

## Adding New Editor Blocks

### Step 1: Define in Editor Setup

Update the `editor_setup` JSON in your PagePart:

```ruby
page_part.update(
  editor_setup: {
    editorBlocks: [
      [
        { label: 'my_block', isHtml: true },
        { label: 'my_image', isImage: true }
      ]
    ]
  }
)
```

### Step 2: Create Liquid Template

Add block content interpolation to your template:

```liquid
{% if block_contents.my_block.content %}
  <div class="my-section">
    {{ block_contents.my_block.content }}
  </div>
{% endif %}

{% if block_contents.my_image.content %}
  <img src="{{ block_contents.my_image.content }}" 
       alt="Section Image"
       class="w-full rounded-lg">
{% endif %}
```

### Step 3: Handle in Page Part Controller

The editor automatically handles:
- Displaying the appropriate input UI
- Saving block_contents JSON
- Rendering in preview

No additional code needed!

## Data Flow

```
1. User edits page part in admin panel
   ↓
2. Form submitted with block_contents data
   ↓
3. Controller saves to pwb_page_parts.block_contents (JSON)
   ↓
4. Page part renders using Liquid template
   ↓
5. Liquid accesses block_contents JSON
   ↓
6. HTML rendered on frontend
```

## Storage Strategy

### Per-Locale Storage

Block contents are stored per locale:

```json
{
  "en": {
    "blocks": { ... }
  },
  "es": {
    "blocks": { ... }
  }
}
```

### Accessing in Template

In Liquid templates, access the current locale's blocks:

```liquid
{{ block_contents.hero_heading.content }}
```

### Multi-Locale Editing

The editor provides locale tabs:

```erb
<% if @locale_details.length > 1 %>
  <div class="border-b border-gray-200 mb-6">
    <nav class="-mb-px flex space-x-8">
      <% @locale_details.each do |locale_detail| %>
        <%= link_to edit_site_admin_page_page_part_path(
              @page, @page_part, 
              locale: locale_detail[:full]
            ) %>
      <% end %>
    </nav>
  </div>
<% end %>
```

Each locale is edited separately.

## Validation & Constraints

### Current Validation
- No length limits on rich text
- No HTML sanitization policy enforced
- Images limited by ActiveStorage config

### Recommended Validation

```ruby
class PagePart < ApplicationRecord
  validate :validate_block_contents

  def validate_block_contents
    # Validate structure
    return unless block_contents.is_a?(Hash)
    
    block_contents.each do |locale, locale_data|
      blocks = locale_data['blocks']
      return unless blocks.is_a?(Hash)
      
      # Validate content lengths
      blocks.each do |label, block|
        if block['content'].is_a?(String) && block['content'].length > 50000
          errors.add(:block_contents, "#{label} content exceeds maximum length")
        end
      end
    end
  end
end
```

## Advanced Features

### Image Picker Modal

Implemented in edit.html.erb:

```javascript
function openImagePickerForQuill(fieldId) {
  quillImageFieldId = fieldId;
  openImagePickerModal();
}

function insertImageIntoQuill(fieldId, url) {
  const quill = quillEditors[fieldId];
  const range = quill.getSelection(true);
  quill.insertEmbed(range.index, 'image', url);
  quill.setSelection(range.index + 1);
}
```

### Live Preview

The editor includes live previews:

```erb
<div id="page-part-preview-iframe" 
     src="<%= page_part_url %>" ...>
</div>
```

- Shows the specific page part only
- Updates when content is refreshed
- Responsive preview (desktop/tablet/mobile)

## Performance Considerations

### Quill Editor Load
- CDN-loaded (CDN-cached in browsers)
- Large content loads can be slow
- Consider pagination for very large sections

### JSON Storage
- JSONB indexes on translations column help
- Large block_contents can impact query performance
- Monitor with `slow_queries` log

### Multi-Locale Storage
- All locales stored in single block_contents column
- Scales well for 5-10 locales
- Recommend API endpoint caching for public sites

## Security Considerations

### XSS Prevention
- Quill sanitizes by default
- But stored HTML is rendered with `raw` in ERB
- Ensure Liquid templates properly escape unsafe content

### Recommended Security Checks
1. Validate HTML in block_contents on save
2. Use HTML sanitizer gem for stricter validation
3. Log admin edits for audit trail
4. Restrict editor access to trusted users

## Future Enhancements

### Potential Improvements
1. Block versioning/history
2. Content scheduling (publish/draft states)
3. Block templates/presets
4. Collaborative editing
5. Content preview URLs
6. Block-level permissions
7. Custom block types via plugins

### Migration Path
If moving to richer content system:
1. Standardize on block schema
2. Add content versioning table
3. Implement approval workflow
4. Build component library for theme
