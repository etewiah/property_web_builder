# Container Page Parts System

Container page parts enable **composable layouts** where multiple page parts can be arranged side-by-side within columns. This allows for flexible two-column, three-column, and sidebar layouts without requiring custom templates for each combination.

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Container Page Part                       │
│  (e.g., layout/layout_two_column_equal)                     │
├──────────────────────────┬──────────────────────────────────┤
│      Left Slot           │         Right Slot                │
│  ┌──────────────────┐   │   ┌──────────────────────────┐    │
│  │   CTA Banner     │   │   │   Contact Form           │    │
│  │   (child)        │   │   │   (child)                │    │
│  └──────────────────┘   │   └──────────────────────────┘    │
│                         │                                    │
└─────────────────────────┴────────────────────────────────────┘
```

## Key Concepts

### Container vs Regular Page Parts

| Feature | Regular Page Part | Container Page Part |
|---------|-------------------|---------------------|
| Has children | No | Yes (in slots) |
| Rendered at | Save time (pre-rendered) | Display time (dynamic) |
| Uses `{% render_slot %}` | No | Yes |
| `is_container` flag | false | true |

### Slots

Containers define named **slots** where child page parts can be placed:

```ruby
# PagePartLibrary definition
'layout/layout_two_column_equal' => {
  is_container: true,
  slots: {
    left: { label: 'Left Column', width: '50%' },
    right: { label: 'Right Column', width: '50%' }
  }
}
```

### Parent-Child Relationship

Child page contents are linked to their parent container via:
- `parent_page_content_id` - ID of the container PageContent
- `slot_name` - Which slot the child occupies (e.g., "left", "right")

## Available Container Layouts

| Key | Description | Slots |
|-----|-------------|-------|
| `layout/layout_two_column_equal` | Two equal columns (50/50) | left, right |
| `layout/layout_two_column_wide_narrow` | Wide left, narrow right (67/33) | left, right |
| `layout/layout_sidebar_left` | Sidebar on left (25/75) | sidebar, main |
| `layout/layout_sidebar_right` | Sidebar on right (75/25) | main, sidebar |
| `layout/layout_three_column_equal` | Three equal columns (33/33/33) | left, center, right |

## Database Schema

### PageContent Model

```ruby
# app/models/pwb/page_content.rb
class PageContent < ApplicationRecord
  belongs_to :parent_page_content, class_name: 'PageContent', optional: true
  has_many :child_page_contents, class_name: 'PageContent',
           foreign_key: 'parent_page_content_id', dependent: :destroy

  scope :root_level, -> { where(parent_page_content_id: nil) }

  def container?
    Pwb::PagePartLibrary.container?(page_part_key)
  end

  def available_slots
    Pwb::PagePartLibrary.slot_names(page_part_key)
  end

  def children_in_slot(slot_name)
    child_page_contents.where(slot_name: slot_name).order(:sort_order)
  end
end
```

### Migration

```ruby
add_reference :pwb_page_contents, :parent_page_content,
              foreign_key: { to_table: :pwb_page_contents }
add_column :pwb_page_contents, :slot_name, :string
add_index :pwb_page_contents, [:parent_page_content_id, :slot_name]
```

## Rendering Flow

### 1. Display Time (not save time)

Unlike regular page parts which are pre-rendered at save time and stored in `Content.raw`, containers are rendered **dynamically at display time**. This is necessary because:

- Containers need access to their children via `page_content`
- Children can be added/removed/reordered without re-rendering the container
- The `{% render_slot %}` tag needs to know which `PageContent` it belongs to

### 2. The `render_slot` Liquid Tag

Container templates use the `{% render_slot %}` tag to render children:

```liquid
<!-- app/views/pwb/page_parts/layout/layout_two_column_equal.liquid -->
<section class="pwb-layout pwb-layout--two-col-equal">
  <div class="pwb-container">
    <div class="pwb-layout__grid pwb-layout__grid--2col-equal">
      <div class="pwb-layout__slot pwb-layout__slot--left">
        {% render_slot "left" %}
      </div>
      <div class="pwb-layout__slot pwb-layout__slot--right">
        {% render_slot "right" %}
      </div>
    </div>
  </div>
</section>
```

### 3. ComponentHelper Detection

The `page_part` helper detects containers and renders them dynamically:

```ruby
# app/helpers/pwb/component_helper.rb
def page_part(page_content)
  if page_content.container?
    render_container_page_part(page_content, edit_mode)
  else
    # Use pre-rendered content
    content = page_content.content&.raw
    render partial: "pwb/components/generic_page_part", locals: { content: content }
  end
end
```

### 4. Liquid 5.x Context API

Containers use `Liquid::Context` with registers for proper rendering:

```ruby
def render_container_page_part(page_content, edit_mode = false)
  liquid_template = Liquid::Template.parse(template_content)

  # Build context with registers for Liquid 5.x
  context = Liquid::Context.new
  context["page_part"] = block_contents
  context.registers[:website] = website
  context.registers[:locale] = locale
  context.registers[:page_content] = page_content  # Critical for render_slot

  rendered_html = liquid_template.render(context)
end
```

## API Endpoints

### Public API (Viewing)

```
GET /api_public/v1/:locale/pages/:id?include_rendered=true
```

Returns containers with nested `slots` structure:

```json
{
  "page_contents": [
    {
      "id": 1,
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
  ]
}
```

### Management API (Editing)

#### List Page Contents
```
GET /api_manage/v1/:locale/pages/:page_id/page_contents
```

Returns root-level page contents with container slots nested.

#### Create Page Content
```
POST /api_manage/v1/:locale/pages/:page_id/page_contents
```

```json
{
  "page_content": {
    "page_part_key": "cta/cta_banner",
    "parent_page_content_id": 123,
    "slot_name": "left",
    "sort_order": 1,
    "visible_on_page": true
  }
}
```

**Validation**: Parent must be a container. Returns 422 if parent is not a container.

#### Delete Page Content
```
DELETE /api_manage/v1/:locale/page_contents/:id
```

**Validation**: Cannot delete a container that has children. Returns 422 with `children_count`.

#### Reorder Page Contents
```
PATCH /api_manage/v1/:locale/pages/:page_id/page_contents/reorder
```

```json
{
  "order": [
    { "id": 1, "sort_order": 2 },
    { "id": 2, "sort_order": 1 }
  ],
  "container_id": 123,
  "slot_order": {
    "left": [4, 5, 6],
    "right": [7, 8]
  }
}
```

## Creating Container Content

### Via Rake Task

```bash
# Seed example containers on about-us page
rake pwb:containers:seed_examples

# List all containers
rake pwb:containers:list

# Remove example containers
rake pwb:containers:remove_examples
```

### Via Rails Console

```ruby
website = Pwb::Website.first
page = website.pages.find_by(slug: 'about-us')

ActsAsTenant.with_tenant(website) do
  # Create container
  container = page.page_contents.create!(
    page_part_key: 'layout/layout_two_column_equal',
    website_id: website.id,
    sort_order: 1,
    visible_on_page: true
  )

  # Create child in left slot
  page.page_contents.create!(
    page_part_key: 'cta/cta_banner',
    parent_page_content_id: container.id,
    slot_name: 'left',
    website_id: website.id,
    sort_order: 1,
    visible_on_page: true
  )

  # Create child in right slot
  page.page_contents.create!(
    page_part_key: 'contact_general_enquiry',
    parent_page_content_id: container.id,
    slot_name: 'right',
    website_id: website.id,
    sort_order: 1,
    visible_on_page: true
  )
end
```

### Via API

```bash
# Create container
curl -X POST /api_manage/v1/en/pages/1/page_contents \
  -d '{"page_content": {"page_part_key": "layout/layout_two_column_equal"}}'

# Create child in slot
curl -X POST /api_manage/v1/en/pages/1/page_contents \
  -d '{"page_content": {"page_part_key": "cta/cta_banner", "parent_page_content_id": 1, "slot_name": "left"}}'
```

## Adding New Container Layouts

### 1. Define in PagePartLibrary

```ruby
# app/lib/pwb/page_part_library.rb
'layout/layout_custom' => {
  category: :layout,
  label: 'Custom Layout',
  description: 'Description of layout',
  is_container: true,
  fields: {},  # Containers typically have no editable fields
  slots: {
    header: { label: 'Header', description: 'Top section' },
    content: { label: 'Content', description: 'Main content area' },
    footer: { label: 'Footer', description: 'Bottom section' }
  }
}
```

### 2. Create Liquid Template

```liquid
<!-- app/views/pwb/page_parts/layout/layout_custom.liquid -->
<section class="pwb-layout pwb-layout--custom">
  <div class="pwb-container">
    <header class="pwb-layout__header">
      {% render_slot "header" %}
    </header>
    <main class="pwb-layout__content">
      {% render_slot "content" %}
    </main>
    <footer class="pwb-layout__footer">
      {% render_slot "footer" %}
    </footer>
  </div>
</section>
```

### 3. Add CSS (Tailwind)

Add styles in your theme's CSS or use Tailwind utility classes directly in the template.

## Troubleshooting

### Container Not Rendering Children

**Symptom**: Container renders but slots are empty.

**Cause**: Usually a Liquid context issue.

**Solution**: Ensure `context.registers[:page_content]` is set when rendering:

```ruby
context = Liquid::Context.new
context.registers[:page_content] = page_content  # Must be set!
```

### "Parent must be a container" Error

**Cause**: Trying to create a child in a non-container page part.

**Solution**: Only use `parent_page_content_id` with container page parts.

### Children Not Appearing in API

**Cause**: API returning all page contents instead of just root-level.

**Solution**: Use `.root_level` scope:

```ruby
page.page_contents.root_level.ordered_visible
```

## Testing

```ruby
# spec/requests/api_manage/v1/page_contents_spec.rb
RSpec.describe "ApiManage::V1::PageContents" do
  it "creates child page content in slot" do
    post "/api_manage/v1/en/pages/#{page.id}/page_contents",
      params: {
        page_content: {
          page_part_key: "cta/cta_banner",
          parent_page_content_id: container.id,
          slot_name: "left"
        }
      }

    expect(response).to have_http_status(201)
    expect(json["page_content"]["slot_name"]).to eq("left")
  end

  it "rejects invalid parent" do
    post "/api_manage/v1/en/pages/#{page.id}/page_contents",
      params: {
        page_content: {
          page_part_key: "heroes/hero_centered",
          parent_page_content_id: non_container.id,
          slot_name: "left"
        }
      }

    expect(response).to have_http_status(422)
    expect(json["error"]).to eq("Invalid parent")
  end
end
```

## Related Documentation

- [Page Parts Overview](/docs/architecture/page_parts_overview.md)
- [Liquid Templates](/docs/architecture/liquid_templates.md)
- [API Reference](/docs/api/page_contents.md)
