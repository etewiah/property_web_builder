# Container Page Parts - Composable Layouts

This document describes the container page parts feature, which enables composable layouts by allowing page parts to be positioned side-by-side within layout containers.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Model](#data-model)
4. [Container Definitions](#container-definitions)
5. [Liquid Rendering](#liquid-rendering)
6. [Available Container Types](#available-container-types)
7. [Editor Integration](#editor-integration)
8. [Seeding Configuration](#seeding-configuration)
9. [Constraints and Rules](#constraints-and-rules)
10. [Implementation Checklist](#implementation-checklist)

---

## Overview

### The Problem

Currently, page parts can only be stacked vertically—each occupying the full width of the page:

```
┌─────────────────────────────────────┐
│         Hero Section                │
├─────────────────────────────────────┤
│         Features Grid               │
├─────────────────────────────────────┤
│         Contact Form                │
├─────────────────────────────────────┤
│         Testimonials                │
└─────────────────────────────────────┘
```

This limits layout flexibility. Common designs require side-by-side arrangements:
- Contact form next to a map
- Sidebar with main content
- Multi-column feature sections
- Image gallery next to text

### The Solution: Container Page Parts

Introduce a special type of page part called a **container** that:
- Defines **named slots** (e.g., left, right, main, sidebar)
- Accepts **child page parts** assigned to each slot
- Controls **layout properties** (column widths, gaps, responsiveness)
- Renders children within a **grid/flexbox template**

```
┌─────────────────────────────────────┐
│         Hero Section                │
├─────────────────────────────────────┤
│  ┌─────────────┬─────────────────┐  │
│  │   Contact   │                 │  │
│  │   Form      │   Location Map  │  │  ← Container with 2 slots
│  │   (left)    │   (right)       │  │
│  └─────────────┴─────────────────┘  │
├─────────────────────────────────────┤
│         Testimonials                │
└─────────────────────────────────────┘
```

### Key Characteristics

| Aspect | Design Decision |
|--------|-----------------|
| Nesting | **Single level only** - containers cannot contain other containers |
| Slots | **Fixed per container type** - defined in PagePartLibrary |
| Children | **Referenced** - existing page parts assigned to slots |
| Eligibility | **Any non-container** page part can be a child |

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                 CONTAINER PAGE PARTS SYSTEM                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────┐                                       │
│  │   PagePartLibrary    │                                       │
│  │                      │                                       │
│  │   Container Defs:    │                                       │
│  │   - is_container     │◀──── Marks as container type          │
│  │   - slots            │◀──── Named slot definitions           │
│  │   - fields           │◀──── Layout configuration             │
│  └──────────────────────┘                                       │
│            │                                                    │
│            ▼                                                    │
│  ┌──────────────────────┐    ┌──────────────────────┐          │
│  │   PageContent        │    │   PageContent        │          │
│  │   (Container)        │───▶│   (Child)            │          │
│  │                      │    │                      │          │
│  │   parent: nil        │    │   parent: container  │          │
│  │   children: [...]    │    │   slot_name: "left"  │          │
│  └──────────────────────┘    └──────────────────────┘          │
│            │                                                    │
│            ▼                                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │   Container Liquid Template                               │  │
│  │                                                           │  │
│  │   <div class="pwb-grid">                                  │  │
│  │     <div class="pwb-grid__left">                          │  │
│  │       {% render_slot 'left' %}  ◀── Custom Liquid tag     │  │
│  │     </div>                                                │  │
│  │     <div class="pwb-grid__right">                         │  │
│  │       {% render_slot 'right' %}                           │  │
│  │     </div>                                                │  │
│  │   </div>                                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Rendering Flow

1. Page loads `ordered_visible_page_contents`
2. For each PageContent:
   - If **regular**: Render its Liquid template
   - If **container**: Render container template with slot rendering
3. Container template uses `{% render_slot 'slot_name' %}` tag
4. Slot tag finds child PageContents assigned to that slot
5. Each child is rendered using standard page part rendering

---

## Data Model

### PageContent Model Changes

Add fields to support parent-child relationships and slot assignment:

```ruby
# db/migrate/XXXXXX_add_container_support_to_page_contents.rb
class AddContainerSupportToPageContents < ActiveRecord::Migration[7.0]
  def change
    # Parent reference for nesting
    add_reference :pwb_page_contents, :parent_page_content,
                  foreign_key: { to_table: :pwb_page_contents },
                  null: true

    # Slot assignment for children
    add_column :pwb_page_contents, :slot_name, :string, null: true

    # Index for efficient child lookups
    add_index :pwb_page_contents, [:parent_page_content_id, :slot_name]
  end
end
```

### Updated PageContent Model

```ruby
# app/models/pwb/page_content.rb
module Pwb
  class PageContent < ApplicationRecord
    # Existing associations
    belongs_to :page, optional: true
    belongs_to :content, optional: true
    belongs_to :website, optional: true

    # Container relationships
    belongs_to :parent_page_content,
               class_name: 'Pwb::PageContent',
               optional: true

    has_many :child_page_contents,
             class_name: 'Pwb::PageContent',
             foreign_key: :parent_page_content_id,
             dependent: :nullify

    # Scopes
    scope :root_level, -> { where(parent_page_content_id: nil) }
    scope :in_slot, ->(slot) { where(slot_name: slot) }
    scope :ordered_in_slot, ->(slot) { in_slot(slot).order(:sort_order) }

    # Validations
    validates :slot_name, presence: true, if: :has_parent?
    validate :parent_must_be_container
    validate :no_nested_containers

    # Helpers
    def container?
      definition = Pwb::PagePartLibrary.definition(page_part_key)
      definition&.dig(:is_container) == true
    end

    def has_parent?
      parent_page_content_id.present?
    end

    def root?
      !has_parent?
    end

    def children_in_slot(slot_name)
      child_page_contents.in_slot(slot_name).ordered
    end

    def available_slots
      return [] unless container?
      definition = Pwb::PagePartLibrary.definition(page_part_key)
      definition&.dig(:slots)&.keys || []
    end

    private

    def parent_must_be_container
      return unless has_parent?
      unless parent_page_content&.container?
        errors.add(:parent_page_content, 'must be a container page part')
      end
    end

    def no_nested_containers
      if container? && has_parent?
        errors.add(:base, 'Containers cannot be nested inside other containers')
      end
    end
  end
end
```

### Entity Relationship

```
┌─────────────────────┐
│    PageContent      │
│    (Container)      │
│                     │
│  id: 100            │
│  page_part_key:     │
│    layout_two_col   │
│  parent_id: null    │
│  slot_name: null    │
└─────────┬───────────┘
          │
          │ has_many :child_page_contents
          │
    ┌─────┴─────┐
    │           │
    ▼           ▼
┌─────────┐ ┌─────────┐
│ Child 1 │ │ Child 2 │
│         │ │         │
│ id: 101 │ │ id: 102 │
│ key:    │ │ key:    │
│ contact_│ │ contact_│
│ general │ │ location│
│ parent: │ │ parent: │
│   100   │ │   100   │
│ slot:   │ │ slot:   │
│  "left" │ │ "right" │
└─────────┘ └─────────┘
```

---

## Container Definitions

### PagePartLibrary Structure

Container page parts are defined in `PagePartLibrary` with special attributes:

```ruby
# app/lib/pwb/page_part_library.rb

# Add :layout category
CATEGORIES = {
  # ... existing categories ...
  layout: {
    label: 'Layout',
    description: 'Container layouts for arranging page parts side-by-side',
    icon: 'layout'
  }
}.freeze

DEFINITIONS = {
  # ... existing definitions ...

  # ============================================
  # CONTAINER PAGE PARTS
  # ============================================

  'layout_two_column_equal' => {
    category: :layout,
    label: 'Two Columns (Equal)',
    description: 'Two equal-width columns side by side',
    is_container: true,
    slots: {
      left: {
        label: 'Left Column',
        description: 'Content for the left side',
        width: '1/2'
      },
      right: {
        label: 'Right Column',
        description: 'Content for the right side',
        width: '1/2'
      }
    },
    fields: {
      gap: {
        type: :select,
        label: 'Column Gap',
        hint: 'Space between columns',
        choices: [
          { value: 'none', label: 'None' },
          { value: 'sm', label: 'Small (1rem)' },
          { value: 'md', label: 'Medium (2rem)' },
          { value: 'lg', label: 'Large (3rem)' }
        ],
        default: 'md',
        group: :layout
      },
      vertical_align: {
        type: :select,
        label: 'Vertical Alignment',
        hint: 'How to align columns vertically',
        choices: [
          { value: 'top', label: 'Top' },
          { value: 'center', label: 'Center' },
          { value: 'bottom', label: 'Bottom' },
          { value: 'stretch', label: 'Stretch (equal height)' }
        ],
        default: 'top',
        group: :layout
      },
      stack_on_mobile: {
        type: :boolean,
        label: 'Stack on Mobile',
        hint: 'Stack columns vertically on small screens',
        default: true,
        group: :responsive
      },
      mobile_order: {
        type: :select,
        label: 'Mobile Stack Order',
        hint: 'Which column appears first when stacked',
        choices: [
          { value: 'left_first', label: 'Left column first' },
          { value: 'right_first', label: 'Right column first' }
        ],
        default: 'left_first',
        group: :responsive
      },
      container_width: {
        type: :select,
        label: 'Container Width',
        choices: [
          { value: 'full', label: 'Full width' },
          { value: 'contained', label: 'Contained (max-width)' },
          { value: 'narrow', label: 'Narrow' }
        ],
        default: 'contained',
        group: :layout
      },
      background_style: {
        type: :select,
        label: 'Background',
        choices: [
          { value: 'none', label: 'None (transparent)' },
          { value: 'light', label: 'Light gray' },
          { value: 'white', label: 'White' },
          { value: 'dark', label: 'Dark' }
        ],
        default: 'none',
        group: :appearance
      },
      padding: {
        type: :select,
        label: 'Section Padding',
        choices: [
          { value: 'none', label: 'None' },
          { value: 'sm', label: 'Small' },
          { value: 'md', label: 'Medium' },
          { value: 'lg', label: 'Large' }
        ],
        default: 'md',
        group: :appearance
      }
    },
    field_groups: {
      layout: { label: 'Layout', order: 1 },
      responsive: { label: 'Responsive Behavior', order: 2 },
      appearance: { label: 'Appearance', order: 3 }
    }
  }
}.freeze
```

### Slot Definition Structure

Each slot in a container has:

```ruby
slots: {
  slot_key: {
    label: String,           # Display name in editor
    description: String,     # Help text
    width: String,           # CSS width hint ('1/2', '1/3', '2/3', etc.)
    required: Boolean,       # Whether slot must have content (default: false)
    allowed_categories: [],  # Restrict which page parts can go here (optional)
    max_children: Integer    # Max page parts in slot (default: 1)
  }
}
```

### Naming Convention for Containers

Following the established naming pattern `{category}_{purpose}_{variant}`:

| Name | Description |
|------|-------------|
| `layout_two_column_equal` | Two equal columns (50/50) |
| `layout_two_column_wide_narrow` | Wide left, narrow right (67/33) |
| `layout_two_column_narrow_wide` | Narrow left, wide right (33/67) |
| `layout_sidebar_left` | Left sidebar with main content (25/75) |
| `layout_sidebar_right` | Right sidebar with main content (75/25) |
| `layout_three_column_equal` | Three equal columns (33/33/33) |
| `layout_three_column_featured` | Featured center column (25/50/25) |

---

## Liquid Rendering

### Custom Liquid Tag: render_slot

Create a custom Liquid tag to render children assigned to a slot:

```ruby
# app/lib/pwb/liquid_tags/render_slot_tag.rb
module Pwb
  module LiquidTags
    class RenderSlotTag < Liquid::Tag
      def initialize(tag_name, slot_name, tokens)
        super
        @slot_name = slot_name.strip.delete("'\"")
      end

      def render(context)
        container_page_content = context['container_page_content']
        return '' unless container_page_content

        children = container_page_content.children_in_slot(@slot_name)
        return '' if children.empty?

        # Get rendering context
        website = context['website']
        current_locale = context['current_locale']

        # Render each child
        children.map do |child_page_content|
          render_child(child_page_content, context)
        end.join("\n")
      end

      private

      def render_child(page_content, context)
        # Get the page part and its template
        page_part = find_page_part(page_content, context)
        return '' unless page_part

        template_content = page_part.template_content
        return '' if template_content.blank?

        # Get block contents for current locale
        current_locale = context['current_locale'] || 'en'
        blocks = page_part.block_contents&.dig(current_locale, 'blocks') || {}

        # Parse and render the child template
        child_template = Liquid::Template.parse(template_content)
        child_context = context.dup
        child_context['page_part'] = blocks

        child_template.render(child_context)
      end

      def find_page_part(page_content, context)
        website = context['website']
        page_slug = context['page_slug']

        # Look up the page part record
        Pwb::PagePart.find_by(
          website_id: website&.id,
          page_part_key: page_content.page_part_key,
          page_slug: page_slug
        ) || Pwb::PagePart.find_by(
          website_id: website&.id,
          page_part_key: page_content.page_part_key,
          page_slug: 'website'
        )
      end
    end
  end
end

# Register the tag
Liquid::Template.register_tag('render_slot', Pwb::LiquidTags::RenderSlotTag)
```

### Container Template Example

```liquid
{% comment %}
  layout_two_column_equal.liquid
  ==============================
  Two-column container with equal width columns.

  Available variables:
  - page_part: Container's own field values
  - container_page_content: The PageContent record (for slot rendering)
  - current_locale: Current language code

  Slots:
  - left: Left column content
  - right: Right column content
{% endcomment %}

{% assign gap = page_part.gap.content | default: 'md' %}
{% assign v_align = page_part.vertical_align.content | default: 'top' %}
{% assign stack_mobile = page_part.stack_on_mobile.content | default: 'true' %}
{% assign mobile_order = page_part.mobile_order.content | default: 'left_first' %}
{% assign container_width = page_part.container_width.content | default: 'contained' %}
{% assign bg_style = page_part.background_style.content | default: 'none' %}
{% assign padding = page_part.padding.content | default: 'md' %}

{% comment %} Build CSS classes {% endcomment %}
{% assign container_classes = 'pwb-layout pwb-layout--two-column' %}

{% case container_width %}
  {% when 'full' %}
    {% assign container_classes = container_classes | append: ' pwb-layout--full' %}
  {% when 'narrow' %}
    {% assign container_classes = container_classes | append: ' pwb-layout--narrow' %}
  {% else %}
    {% assign container_classes = container_classes | append: ' pwb-layout--contained' %}
{% endcase %}

{% case bg_style %}
  {% when 'light' %}
    {% assign container_classes = container_classes | append: ' bg-gray-50' %}
  {% when 'white' %}
    {% assign container_classes = container_classes | append: ' bg-white' %}
  {% when 'dark' %}
    {% assign container_classes = container_classes | append: ' bg-gray-900' %}
{% endcase %}

{% case padding %}
  {% when 'sm' %}
    {% assign container_classes = container_classes | append: ' py-6' %}
  {% when 'md' %}
    {% assign container_classes = container_classes | append: ' py-12' %}
  {% when 'lg' %}
    {% assign container_classes = container_classes | append: ' py-16' %}
{% endcase %}

{% comment %} Build grid classes {% endcomment %}
{% assign grid_classes = 'pwb-layout__grid' %}

{% if stack_mobile == 'true' or stack_mobile == true %}
  {% assign grid_classes = grid_classes | append: ' flex flex-col lg:flex-row' %}
{% else %}
  {% assign grid_classes = grid_classes | append: ' flex flex-row' %}
{% endif %}

{% case gap %}
  {% when 'sm' %}
    {% assign grid_classes = grid_classes | append: ' gap-4' %}
  {% when 'md' %}
    {% assign grid_classes = grid_classes | append: ' gap-8' %}
  {% when 'lg' %}
    {% assign grid_classes = grid_classes | append: ' gap-12' %}
{% endcase %}

{% case v_align %}
  {% when 'center' %}
    {% assign grid_classes = grid_classes | append: ' items-center' %}
  {% when 'bottom' %}
    {% assign grid_classes = grid_classes | append: ' items-end' %}
  {% when 'stretch' %}
    {% assign grid_classes = grid_classes | append: ' items-stretch' %}
  {% else %}
    {% assign grid_classes = grid_classes | append: ' items-start' %}
{% endcase %}

{% comment %} Column classes {% endcomment %}
{% assign left_classes = 'pwb-layout__column pwb-layout__column--left w-full lg:w-1/2' %}
{% assign right_classes = 'pwb-layout__column pwb-layout__column--right w-full lg:w-1/2' %}

{% if mobile_order == 'right_first' %}
  {% assign left_classes = left_classes | append: ' order-2 lg:order-1' %}
  {% assign right_classes = right_classes | append: ' order-1 lg:order-2' %}
{% endif %}

<section class="{{ container_classes }}">
  <div class="pwb-container max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="{{ grid_classes }}">

      {% comment %} Left Column {% endcomment %}
      <div class="{{ left_classes }}">
        {% render_slot 'left' %}
      </div>

      {% comment %} Right Column {% endcomment %}
      <div class="{{ right_classes }}">
        {% render_slot 'right' %}
      </div>

    </div>
  </div>
</section>
```

### Template Location

Container templates follow the same convention:

```
app/views/pwb/page_parts/
├── layout/
│   ├── layout_two_column_equal.liquid
│   ├── layout_two_column_wide_narrow.liquid
│   ├── layout_sidebar_left.liquid
│   └── layout_three_column_equal.liquid
```

---

## Available Container Types

### layout_two_column_equal

Two equal-width columns (50/50 split).

```
┌───────────────┬───────────────┐
│     Left      │     Right     │
│     50%       │     50%       │
└───────────────┴───────────────┘
```

**Slots:** `left`, `right`

**Use cases:**
- Contact form next to map
- Image next to text
- Two feature cards side by side

---

### layout_two_column_wide_narrow

Wide left column with narrow right (67/33 split).

```
┌─────────────────────┬─────────┐
│        Left         │  Right  │
│        67%          │   33%   │
└─────────────────────┴─────────┘
```

**Slots:** `left` (wide), `right` (narrow)

**Use cases:**
- Main content with sidebar
- Article with related links

---

### layout_two_column_narrow_wide

Narrow left column with wide right (33/67 split).

```
┌─────────┬─────────────────────┐
│  Left   │        Right        │
│  33%    │        67%          │
└─────────┴─────────────────────┘
```

**Slots:** `left` (narrow), `right` (wide)

**Use cases:**
- Navigation sidebar with content
- Filters with results

---

### layout_sidebar_left

Left sidebar layout (25/75 split).

```
┌───────┬───────────────────────┐
│ Side  │         Main          │
│ 25%   │         75%           │
└───────┴───────────────────────┘
```

**Slots:** `sidebar`, `main`

**Use cases:**
- Page with navigation sidebar
- Dashboard layout

---

### layout_sidebar_right

Right sidebar layout (75/25 split).

```
┌───────────────────────┬───────┐
│         Main          │ Side  │
│         75%           │ 25%   │
└───────────────────────┴───────┘
```

**Slots:** `main`, `sidebar`

**Use cases:**
- Blog post with sidebar
- Property listing with inquiry form

---

### layout_three_column_equal

Three equal-width columns (33/33/33 split).

```
┌───────────┬───────────┬───────────┐
│   Left    │  Center   │   Right   │
│   33%     │   33%     │   33%     │
└───────────┴───────────┴───────────┘
```

**Slots:** `left`, `center`, `right`

**Use cases:**
- Three feature cards
- Triple content comparison

---

## Editor Integration

### Editor UI Requirements

The editor needs to support:

1. **Container placement** - Add container page parts to a page
2. **Slot assignment** - Assign child page parts to slots
3. **Visual representation** - Show container structure with slots
4. **Child management** - Add, remove, reorder children within slots

### Suggested Editor Workflow

```
1. User clicks "Add Page Part"
2. User selects "Layout" category
3. User chooses container type (e.g., "Two Column Equal")
4. Container added to page with empty slots
5. Editor shows visual representation:

   ┌─────────────────────────────────────┐
   │  Two Column Layout                  │
   │  ┌───────────────┬───────────────┐  │
   │  │ Left Column   │ Right Column  │  │
   │  │               │               │  │
   │  │ [+ Add Part]  │ [+ Add Part]  │  │
   │  │               │               │  │
   │  └───────────────┴───────────────┘  │
   └─────────────────────────────────────┘

6. User clicks [+ Add Part] in a slot
7. Modal shows available page parts (non-containers)
8. User selects page part
9. Page part is created and assigned to slot
10. Editor shows populated slot:

   ┌─────────────────────────────────────┐
   │  Two Column Layout                  │
   │  ┌───────────────┬───────────────┐  │
   │  │ Contact Form  │ Location Map  │  │
   │  │ ┌───────────┐ │ ┌───────────┐ │  │
   │  │ │ [Edit]    │ │ │ [Edit]    │ │  │
   │  │ │ [Remove]  │ │ │ [Remove]  │ │  │
   │  │ └───────────┘ │ └───────────┘ │  │
   │  └───────────────┴───────────────┘  │
   └─────────────────────────────────────┘
```

### API Endpoints

New or modified endpoints needed:

```ruby
# Create container with children
POST /api/v1/page_parts/containers
{
  page_slug: "contact",
  page_part_key: "layout_two_column_equal",
  block_contents: { ... },
  children: [
    { page_part_key: "contact_general_enquiry", slot: "left" },
    { page_part_key: "contact_location_map", slot: "right" }
  ]
}

# Assign child to container slot
POST /api/v1/page_contents/:container_id/children
{
  page_part_key: "contact_general_enquiry",
  slot_name: "left"
}

# Move child to different slot
PATCH /api/v1/page_contents/:child_id
{
  slot_name: "right"
}

# Remove child from container
DELETE /api/v1/page_contents/:child_id
# or set parent_page_content_id to null
```

---

## Seeding Configuration

### YAML Seed Format

```yaml
# db/yml_seeds/page_parts/contact__layout_two_column_equal.yml
- page_slug: contact
  page_part_key: layout_two_column_equal
  block_contents:
    en:
      blocks:
        gap:
          content: "md"
        vertical_align:
          content: "top"
        stack_on_mobile:
          content: "true"
        mobile_order:
          content: "left_first"
        container_width:
          content: "contained"
        background_style:
          content: "light"
        padding:
          content: "lg"
  children:
    - slot: left
      page_part_key: contact_general_enquiry
      sort_order: 1
    - slot: right
      page_part_key: contact_location_map
      sort_order: 1
  order_in_editor: 2
  show_in_editor: true
```

### Seeder Updates

```ruby
# lib/pwb/pages_seeder.rb
def seed_page_part_with_children(page, config)
  # Create the container page content
  container_page_content = create_page_content(page, config)

  # Create children
  config['children']&.each do |child_config|
    create_child_page_content(
      container_page_content,
      child_config['page_part_key'],
      child_config['slot'],
      child_config['sort_order']
    )
  end
end

def create_child_page_content(parent, page_part_key, slot_name, sort_order)
  # Find or create the child page part
  child_page_part = find_or_create_page_part(page_part_key, parent.page)

  # Create child page content
  Pwb::PageContent.create!(
    page: parent.page,
    website: parent.website,
    page_part_key: page_part_key,
    parent_page_content: parent,
    slot_name: slot_name,
    sort_order: sort_order,
    visible_on_page: true
  )
end
```

---

## Constraints and Rules

### Enforced Constraints

| Rule | Enforcement |
|------|-------------|
| No nested containers | Model validation |
| Children must have parent that is container | Model validation |
| Children must specify slot_name | Model validation |
| Slot must exist in container definition | Model validation |
| Max children per slot | Model validation (optional) |

### Validation Implementation

```ruby
# app/models/pwb/page_content.rb

validate :slot_exists_in_container

private

def slot_exists_in_container
  return unless has_parent? && slot_name.present?

  parent_definition = Pwb::PagePartLibrary.definition(parent_page_content.page_part_key)
  available_slots = parent_definition&.dig(:slots)&.keys&.map(&:to_s) || []

  unless available_slots.include?(slot_name)
    errors.add(:slot_name, "is not valid for this container. Available: #{available_slots.join(', ')}")
  end
end
```

### Query Considerations

When loading page contents, exclude children from root queries:

```ruby
# Only load root-level page contents (not children)
@page_contents = page.page_contents
                     .root_level
                     .visible
                     .ordered
                     .includes(:child_page_contents)
```

---

## Implementation Checklist

### Phase 1: Data Model

- [ ] Create migration for `parent_page_content_id` and `slot_name`
- [ ] Update `Pwb::PageContent` model with associations
- [ ] Add validations for container rules
- [ ] Update `PwbTenant::PageContent` if needed
- [ ] Write model specs

### Phase 2: PagePartLibrary

- [ ] Add `:layout` category to `CATEGORIES`
- [ ] Add `is_container` and `slots` support to definition schema
- [ ] Add container type definitions
- [ ] Add helper methods: `container?`, `slots_for`, etc.
- [ ] Write library specs

### Phase 3: Liquid Rendering

- [ ] Create `RenderSlotTag` Liquid tag
- [ ] Register tag in initializer
- [ ] Update page part rendering to pass `container_page_content`
- [ ] Create container Liquid templates
- [ ] Write rendering specs

### Phase 4: Templates

- [ ] Create `layout_two_column_equal.liquid`
- [ ] Create `layout_two_column_wide_narrow.liquid`
- [ ] Create `layout_two_column_narrow_wide.liquid`
- [ ] Create `layout_sidebar_left.liquid`
- [ ] Create `layout_sidebar_right.liquid`
- [ ] Create `layout_three_column_equal.liquid`
- [ ] Add CSS/Tailwind classes for layouts

### Phase 5: Seeding

- [ ] Update seeder to support `children` configuration
- [ ] Create example seed files
- [ ] Test seeding workflow

### Phase 6: Editor Integration

- [ ] Update editor UI to show containers
- [ ] Add slot visualization
- [ ] Add "Add to slot" functionality
- [ ] Add child management (reorder, remove)
- [ ] Create/update API endpoints

### Phase 7: Documentation

- [ ] Update PagePart system docs
- [ ] Add editor user guide
- [ ] Create migration guide for existing sites

---

## Related Documentation

- [PagePart System Documentation](../architecture/08_PagePart_System.md) - Core system architecture
- [Form Page Parts Implementation Guide](FORM_PAGE_PARTS.md) - Form page parts and naming conventions
- [Form Page Parts Quick Reference](FORM_PAGE_PARTS_QUICK_REFERENCE.md) - Quick reference
