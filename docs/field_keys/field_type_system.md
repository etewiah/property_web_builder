# Field Type System - Comprehensive Review & Improvement Plan

This document provides a detailed analysis of the current field type inference system and recommendations for building a robust, client-friendly API that supports rich editing functionality.

## Table of Contents

1. [Current System Overview](#current-system-overview)
2. [Critical Limitations](#critical-limitations)
3. [Proposed Field Schema](#proposed-field-schema)
4. [Implementation Recommendations](#implementation-recommendations)
5. [API Response Specification](#api-response-specification)
6. [Migration Path](#migration-path)

---

## Current System Overview

### How Field Types Are Determined

The current system infers field types from field names using pattern matching:

```ruby
# app/controllers/api_manage/v1/liquid_pages_controller.rb
def infer_field_type(field_name)
  name = field_name.to_s.downcase

  if name == 'faq_items'
    'faq_array'
  elsif name.include?('image') || name.include?('photo') || name.include?('src') || name.include?('background')
    'image'
  elsif name.include?('html') || name.end_with?('_html')
    'html'
  elsif name.include?('content') || name.include?('description') || name.include?('body') || name.include?('text')
    'textarea'
  elsif name.include?('link') || name.include?('url') || name.include?('href')
    'url'
  elsif name.include?('icon')
    'icon'
  elsif name.include?('color')
    'color'
  else
    'text'
  end
end
```

### Current Field Types

| Type | Detection Pattern | Editor Component |
|------|-------------------|------------------|
| `faq_array` | Exact match `faq_items` | FAQ array editor |
| `image` | Contains `image`, `photo`, `src`, `background` | Image picker |
| `html` | Contains `html` or ends with `_html` | WYSIWYG editor |
| `textarea` | Contains `content`, `description`, `body`, `text` | Multi-line textarea |
| `url` | Contains `link`, `url`, `href` | URL input |
| `icon` | Contains `icon` | Icon selector |
| `color` | Contains `color` | Color picker |
| `text` | Default fallback | Single-line input |

### Data Structure

All field values are stored in `block_contents` JSON with this structure:

```json
{
  "en": {
    "blocks": {
      "field_name": { "content": "field value" }
    }
  },
  "es": {
    "blocks": {
      "field_name": { "content": "valor del campo" }
    }
  }
}
```

---

## Critical Limitations

### 1. No Explicit Field Type Definitions

Field types are inferred from names, leading to:
- `stat_1_value` → `text` (should be `number`)
- `member_1_email` → `text` (should be `email`)
- `plan_1_price` → `text` (should be `currency`)
- `style` → `text` (should be `select` with options)

### 2. Missing Field Types

| Needed Type | Use Case | Current Behavior |
|-------------|----------|------------------|
| `email` | Contact emails | Falls back to `text` |
| `phone` | Phone numbers | Falls back to `text` |
| `number` | Statistics, counts | Falls back to `text` |
| `currency` | Prices | Falls back to `text` |
| `select` | Style choices, dropdowns | Falls back to `text` |
| `boolean` | Toggle options | Not supported |
| `date` | Event dates | Not supported |
| `repeater` | Dynamic lists | Uses numbered fields |

### 3. No Field Metadata

Clients cannot determine:
- Required vs optional fields
- Character limits (min/max length)
- Placeholder text / hints
- Default values
- Validation rules
- Field grouping / relationships

### 4. No Content Hints

Editors cannot provide guidance on:
- Recommended content length
- Best practices for the field
- Example content
- SEO recommendations

### 5. Numbered Fields Instead of Arrays

Team members, testimonials, and features use:
```
member_1_name, member_1_role, member_1_image
member_2_name, member_2_role, member_2_image
...
```

Instead of a proper repeatable structure that allows dynamic add/remove.

---

## Proposed Field Schema

### Enhanced Field Definition

Each field should have explicit metadata:

```ruby
{
  name: 'title',
  type: 'text',
  label: 'Page Title',
  hint: 'The main headline for this section',
  placeholder: 'Enter a compelling title...',
  required: true,
  validation: {
    min_length: 3,
    max_length: 80,
    pattern: nil
  },
  content_guidance: {
    recommended_length: '40-60 characters',
    seo_tip: 'Include your primary keyword naturally',
    examples: ['Discover Your Dream Home', 'Expert Real Estate Services']
  },
  default_value: nil,
  group: 'main_content',
  order: 1
}
```

### Complete Type System

```ruby
FIELD_TYPES = {
  # Text Types
  text: {
    component: 'TextInput',
    description: 'Single-line text input',
    validations: [:min_length, :max_length, :pattern]
  },
  textarea: {
    component: 'TextareaInput',
    description: 'Multi-line plain text',
    validations: [:min_length, :max_length, :rows]
  },
  html: {
    component: 'WysiwygEditor',
    description: 'Rich HTML content with formatting',
    validations: [:max_length],
    toolbar: [:bold, :italic, :link, :list, :heading]
  },
  markdown: {
    component: 'MarkdownEditor',
    description: 'Markdown-formatted text',
    validations: [:max_length]
  },

  # Numeric Types
  number: {
    component: 'NumberInput',
    description: 'Integer or decimal number',
    validations: [:min, :max, :step, :precision]
  },
  currency: {
    component: 'CurrencyInput',
    description: 'Price with currency symbol',
    validations: [:min, :max],
    options: [:currency_code, :locale]
  },
  percentage: {
    component: 'PercentageInput',
    description: 'Percentage value (0-100)',
    validations: [:min, :max]
  },

  # Contact Types
  email: {
    component: 'EmailInput',
    description: 'Email address',
    validations: [:format]
  },
  phone: {
    component: 'PhoneInput',
    description: 'Phone number',
    validations: [:format, :country_code]
  },
  url: {
    component: 'UrlInput',
    description: 'Web URL',
    validations: [:format, :protocols]
  },

  # Media Types
  image: {
    component: 'ImagePicker',
    description: 'Image URL or upload',
    validations: [:max_size, :dimensions, :formats],
    options: [:aspect_ratio, :alt_text_field]
  },
  video: {
    component: 'VideoPicker',
    description: 'Video URL (YouTube, Vimeo, etc.)',
    validations: [:providers]
  },
  file: {
    component: 'FilePicker',
    description: 'File attachment',
    validations: [:max_size, :formats]
  },

  # Selection Types
  select: {
    component: 'SelectInput',
    description: 'Dropdown selection',
    options: [:choices, :allow_empty]
  },
  radio: {
    component: 'RadioGroup',
    description: 'Radio button selection',
    options: [:choices]
  },
  checkbox: {
    component: 'CheckboxInput',
    description: 'Boolean toggle',
    options: [:checked_label, :unchecked_label]
  },
  multi_select: {
    component: 'MultiSelectInput',
    description: 'Multiple selection',
    options: [:choices, :max_selections]
  },

  # Special Types
  icon: {
    component: 'IconPicker',
    description: 'Icon selector',
    options: [:icon_set, :categories]
  },
  color: {
    component: 'ColorPicker',
    description: 'Color value',
    options: [:format, :presets, :allow_custom]
  },
  date: {
    component: 'DatePicker',
    description: 'Date selection',
    validations: [:min_date, :max_date],
    options: [:format]
  },
  datetime: {
    component: 'DateTimePicker',
    description: 'Date and time selection',
    validations: [:min, :max],
    options: [:format, :timezone]
  },

  # Complex Types
  link: {
    component: 'LinkEditor',
    description: 'URL with optional text and target',
    fields: [:url, :text, :target, :rel]
  },
  social_link: {
    component: 'SocialLinkEditor',
    description: 'Social media profile link',
    options: [:platforms]
  },
  map_embed: {
    component: 'MapEmbedEditor',
    description: 'Embedded map (Google Maps, etc.)',
    fields: [:embed_code, :address, :coordinates]
  },

  # Array Types
  array: {
    component: 'ArrayEditor',
    description: 'Repeatable list of items',
    options: [:item_schema, :min_items, :max_items]
  },
  faq_array: {
    component: 'FaqEditor',
    description: 'FAQ items with question/answer pairs',
    options: [:min_items, :max_items]
  },
  feature_list: {
    component: 'FeatureListEditor',
    description: 'List of features (pipe-delimited or array)',
    options: [:delimiter, :max_items]
  }
}.freeze
```

---

## Implementation Recommendations

### Step 1: Add Field Definitions to PagePartLibrary

Enhance `DEFINITIONS` with explicit field metadata:

```ruby
# app/lib/pwb/page_part_library.rb

DEFINITIONS = {
  'heroes/hero_centered' => {
    category: :heroes,
    label: 'Centered Hero',
    description: 'Full-width hero with centered content',
    fields: {
      pretitle: {
        type: :text,
        label: 'Pre-title',
        hint: 'Small text above the main title',
        placeholder: 'e.g., Welcome to',
        max_length: 50,
        group: 'titles'
      },
      title: {
        type: :text,
        label: 'Main Title',
        hint: 'The primary headline',
        required: true,
        max_length: 80,
        content_guidance: {
          recommended_length: '40-60 characters',
          seo_tip: 'Include your primary keyword'
        },
        group: 'titles'
      },
      subtitle: {
        type: :textarea,
        label: 'Subtitle',
        hint: 'Supporting text below the title',
        max_length: 200,
        rows: 2,
        group: 'titles'
      },
      cta_text: {
        type: :text,
        label: 'Button Text',
        hint: 'Primary call-to-action button',
        placeholder: 'e.g., Get Started',
        max_length: 30,
        group: 'cta'
      },
      cta_link: {
        type: :url,
        label: 'Button Link',
        hint: 'URL for the primary button',
        placeholder: '/contact',
        group: 'cta',
        paired_with: 'cta_text'  # Indicates these fields belong together
      },
      background_image: {
        type: :image,
        label: 'Background Image',
        hint: 'Full-width background image',
        required: true,
        aspect_ratio: '16:9',
        recommended_size: '1920x1080',
        group: 'media'
      }
    },
    field_groups: {
      titles: { label: 'Titles & Text', order: 1 },
      cta: { label: 'Call to Action', order: 2 },
      media: { label: 'Media', order: 3 }
    }
  },

  'stats/stats_counter' => {
    category: :stats,
    label: 'Stats Counter',
    fields: {
      section_title: {
        type: :text,
        label: 'Section Title',
        max_length: 60
      },
      stat_1_value: {
        type: :number,
        label: 'Statistic 1 Value',
        hint: 'The number to display',
        placeholder: '500',
        min: 0,
        group: 'stat_1'
      },
      stat_1_prefix: {
        type: :text,
        label: 'Prefix',
        hint: 'Symbol before the number',
        placeholder: '$',
        max_length: 5,
        group: 'stat_1'
      },
      stat_1_suffix: {
        type: :text,
        label: 'Suffix',
        hint: 'Symbol after the number',
        placeholder: '+',
        max_length: 5,
        group: 'stat_1'
      },
      style: {
        type: :select,
        label: 'Style',
        choices: [
          { value: 'light', label: 'Light Background' },
          { value: 'dark', label: 'Dark Background' },
          { value: 'gradient', label: 'Gradient Background' }
        ],
        default: 'light'
      }
    }
  },

  'teams/team_grid' => {
    category: :teams,
    label: 'Team Grid',
    fields: {
      section_title: { type: :text, label: 'Section Title' },
      members: {
        type: :array,
        label: 'Team Members',
        min_items: 1,
        max_items: 8,
        item_schema: {
          name: { type: :text, label: 'Name', required: true },
          role: { type: :text, label: 'Role/Title' },
          image: { type: :image, label: 'Photo', aspect_ratio: '1:1' },
          bio: { type: :textarea, label: 'Bio', max_length: 300 },
          email: { type: :email, label: 'Email' },
          phone: { type: :phone, label: 'Phone' },
          linkedin: { type: :url, label: 'LinkedIn URL' }
        }
      }
    }
  }
}
```

### Step 2: Create Field Schema Builder

```ruby
# app/lib/pwb/field_schema_builder.rb

module Pwb
  class FieldSchemaBuilder
    FIELD_TYPES = {
      text: {
        component: 'TextInput',
        default_validations: { max_length: 255 }
      },
      textarea: {
        component: 'TextareaInput',
        default_validations: { max_length: 5000, rows: 4 }
      },
      html: {
        component: 'WysiwygEditor',
        default_validations: { max_length: 50000 },
        default_options: {
          toolbar: %w[bold italic underline link list heading image]
        }
      },
      number: {
        component: 'NumberInput',
        default_validations: {}
      },
      currency: {
        component: 'CurrencyInput',
        default_options: { currency_code: 'USD', locale: 'en-US' }
      },
      email: {
        component: 'EmailInput',
        default_validations: {
          pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        }
      },
      phone: {
        component: 'PhoneInput',
        default_validations: {}
      },
      url: {
        component: 'UrlInput',
        default_validations: {
          pattern: '^https?://.+'
        }
      },
      image: {
        component: 'ImagePicker',
        default_options: {
          accept: %w[image/jpeg image/png image/webp image/gif],
          max_size_mb: 5
        }
      },
      select: {
        component: 'SelectInput',
        default_options: { allow_empty: true }
      },
      checkbox: {
        component: 'CheckboxInput',
        default_options: {}
      },
      icon: {
        component: 'IconPicker',
        default_options: { icon_set: 'lucide' }
      },
      color: {
        component: 'ColorPicker',
        default_options: { format: 'hex', presets: [] }
      },
      array: {
        component: 'ArrayEditor',
        default_options: { min_items: 0, max_items: 10 }
      },
      faq_array: {
        component: 'FaqEditor',
        default_options: { min_items: 1, max_items: 20 }
      }
    }.freeze

    class << self
      def build_field_definition(field_name, config)
        type = config[:type] || infer_type(field_name)
        type_config = FIELD_TYPES[type] || FIELD_TYPES[:text]

        {
          name: field_name.to_s,
          type: type.to_s,
          label: config[:label] || field_name.to_s.humanize,
          hint: config[:hint],
          placeholder: config[:placeholder],
          required: config[:required] || false,
          component: type_config[:component],
          validation: build_validation(config, type_config),
          options: build_options(config, type_config),
          content_guidance: config[:content_guidance],
          group: config[:group],
          paired_with: config[:paired_with],
          order: config[:order],
          # For array types
          item_schema: config[:item_schema] ?
            build_item_schema(config[:item_schema]) : nil
        }.compact
      end

      def build_validation(config, type_config)
        validations = (type_config[:default_validations] || {}).dup

        validations[:min_length] = config[:min_length] if config[:min_length]
        validations[:max_length] = config[:max_length] if config[:max_length]
        validations[:min] = config[:min] if config[:min]
        validations[:max] = config[:max] if config[:max]
        validations[:pattern] = config[:pattern] if config[:pattern]
        validations[:min_items] = config[:min_items] if config[:min_items]
        validations[:max_items] = config[:max_items] if config[:max_items]

        validations.presence
      end

      def build_options(config, type_config)
        options = (type_config[:default_options] || {}).dup

        options[:choices] = config[:choices] if config[:choices]
        options[:aspect_ratio] = config[:aspect_ratio] if config[:aspect_ratio]
        options[:recommended_size] = config[:recommended_size] if config[:recommended_size]
        options[:rows] = config[:rows] if config[:rows]
        options[:default] = config[:default] if config.key?(:default)

        options.presence
      end

      def build_item_schema(schema)
        schema.transform_values do |field_config|
          build_field_definition(field_config.keys.first, field_config)
        end
      end

      # Fallback inference for legacy definitions
      def infer_type(field_name)
        name = field_name.to_s.downcase

        case
        when name == 'faq_items'
          :faq_array
        when name.match?(/_(image|photo|img|background|src)$/) ||
             name.start_with?('image', 'photo', 'background')
          :image
        when name.end_with?('_html') || name == 'content_html'
          :html
        when name.match?(/_(email)$/) || name == 'email'
          :email
        when name.match?(/_(phone|tel)$/) || name == 'phone'
          :phone
        when name.match?(/_(price|cost|amount)$/)
          :currency
        when name.match?(/_(count|number|value|qty|quantity)$/)
          :number
        when name.match?(/_(url|link|href)$/)
          :url
        when name.match?(/_(color|colour)$/)
          :color
        when name.match?(/_(icon)$/)
          :icon
        when name.match?(/_(style|type|layout|position)$/)
          :select
        when name.match?(/_(content|description|body|bio|text|summary)$/)
          :textarea
        when name.match?(/_(features|items|list)$/) && !name.include?('faq')
          :feature_list
        else
          :text
        end
      end
    end
  end
end
```

### Step 3: Update API Response

```ruby
# app/controllers/api_manage/v1/liquid_pages_controller.rb

def build_field_definitions(definition, page_part)
  return nil unless definition

  fields = definition[:fields]
  return legacy_field_definitions(fields) if fields.is_a?(Array)

  # New hash-based field definitions
  field_groups = definition[:field_groups] || {}

  {
    fields: fields.map do |field_name, field_config|
      Pwb::FieldSchemaBuilder.build_field_definition(field_name, field_config)
    end,
    groups: field_groups.map do |group_key, group_config|
      {
        key: group_key.to_s,
        label: group_config[:label],
        order: group_config[:order]
      }
    end.sort_by { |g| g[:order] || 999 }
  }
end

# Support legacy array-based field definitions
def legacy_field_definitions(fields)
  {
    fields: fields.map do |field_name|
      Pwb::FieldSchemaBuilder.build_field_definition(
        field_name,
        { type: Pwb::FieldSchemaBuilder.infer_type(field_name) }
      )
    end,
    groups: []
  }
end
```

---

## API Response Specification

### Enhanced Response Structure

```json
{
  "id": 6,
  "slug": "legal",
  "locale": "es",
  "title": "Nuestro Aviso Legal",
  "page_contents": [
    {
      "page_part_key": "content_html",
      "sort_order": 1,
      "visible": true,
      "rendered_html": "...",
      "liquid_part_template": "...",
      "block_contents": {
        "blocks": {
          "main_content": { "content": "<b>RENUNCIA</b>..." }
        }
      },
      "available_locales": ["en", "es", "de"],
      "field_schema": {
        "fields": [
          {
            "name": "content_html",
            "type": "html",
            "label": "Content",
            "hint": "The main content for this page section",
            "required": true,
            "component": "WysiwygEditor",
            "validation": {
              "max_length": 50000
            },
            "options": {
              "toolbar": ["bold", "italic", "underline", "link", "list", "heading"]
            },
            "content_guidance": {
              "recommended_length": "500-2000 characters",
              "seo_tip": "Break up long content with headings for better readability",
              "examples": null
            }
          }
        ],
        "groups": []
      }
    }
  ]
}
```

### Field Schema for Complex Page Part

```json
{
  "page_part_key": "heroes/hero_centered",
  "field_schema": {
    "fields": [
      {
        "name": "pretitle",
        "type": "text",
        "label": "Pre-title",
        "hint": "Small text above the main title",
        "placeholder": "e.g., Welcome to",
        "required": false,
        "component": "TextInput",
        "validation": {
          "max_length": 50
        },
        "group": "titles",
        "order": 1
      },
      {
        "name": "title",
        "type": "text",
        "label": "Main Title",
        "hint": "The primary headline",
        "required": true,
        "component": "TextInput",
        "validation": {
          "max_length": 80
        },
        "content_guidance": {
          "recommended_length": "40-60 characters",
          "seo_tip": "Include your primary keyword naturally"
        },
        "group": "titles",
        "order": 2
      },
      {
        "name": "cta_text",
        "type": "text",
        "label": "Button Text",
        "hint": "Primary call-to-action button",
        "placeholder": "e.g., Get Started",
        "component": "TextInput",
        "validation": {
          "max_length": 30
        },
        "group": "cta",
        "paired_with": "cta_link"
      },
      {
        "name": "cta_link",
        "type": "url",
        "label": "Button Link",
        "hint": "URL for the primary button",
        "placeholder": "/contact",
        "component": "UrlInput",
        "validation": {
          "pattern": "^(https?://|/).+"
        },
        "group": "cta",
        "paired_with": "cta_text"
      },
      {
        "name": "background_image",
        "type": "image",
        "label": "Background Image",
        "hint": "Full-width background image",
        "required": true,
        "component": "ImagePicker",
        "options": {
          "aspect_ratio": "16:9",
          "recommended_size": "1920x1080",
          "accept": ["image/jpeg", "image/png", "image/webp"],
          "max_size_mb": 5
        },
        "group": "media"
      }
    ],
    "groups": [
      { "key": "titles", "label": "Titles & Text", "order": 1 },
      { "key": "cta", "label": "Call to Action", "order": 2 },
      { "key": "media", "label": "Media", "order": 3 }
    ]
  }
}
```

### Array Field Schema (Team Members)

```json
{
  "name": "members",
  "type": "array",
  "label": "Team Members",
  "component": "ArrayEditor",
  "validation": {
    "min_items": 1,
    "max_items": 8
  },
  "item_schema": {
    "name": {
      "type": "text",
      "label": "Name",
      "required": true,
      "component": "TextInput"
    },
    "role": {
      "type": "text",
      "label": "Role/Title",
      "component": "TextInput"
    },
    "image": {
      "type": "image",
      "label": "Photo",
      "component": "ImagePicker",
      "options": {
        "aspect_ratio": "1:1"
      }
    },
    "email": {
      "type": "email",
      "label": "Email",
      "component": "EmailInput"
    },
    "linkedin": {
      "type": "url",
      "label": "LinkedIn URL",
      "component": "UrlInput"
    }
  }
}
```

---

## Migration Path

### Phase 1: Enhanced Inference (Quick Win)

Update `infer_field_type` with better patterns:

```ruby
def infer_field_type(field_name)
  name = field_name.to_s.downcase

  case
  when name == 'faq_items'
    'faq_array'
  # Image fields
  when name.match?(/_(image|photo|img|background|src|avatar|logo|banner)$/) ||
       name.start_with?('image', 'photo', 'background', 'avatar', 'logo')
    'image'
  # HTML/Rich text
  when name.end_with?('_html') || name == 'content_html'
    'html'
  # Email
  when name.match?(/_(email|mail)$/) || name == 'email'
    'email'
  # Phone
  when name.match?(/_(phone|tel|mobile|fax)$/) || name == 'phone'
    'phone'
  # Currency/Price
  when name.match?(/_(price|cost|amount|fee|rate)$/)
    'currency'
  # Numbers
  when name.match?(/_(count|number|value|qty|quantity|total|year|age)$/)
    'number'
  # URLs
  when name.match?(/_(url|link|href|website)$/)
    'url'
  # Colors
  when name.match?(/_(color|colour|bg_color|text_color)$/)
    'color'
  # Icons
  when name.match?(/_(icon)$/)
    'icon'
  # Select/Choice fields
  when name.match?(/_(style|type|layout|position|alignment|size|theme|variant)$/)
    'select'
  # Textarea/Long text
  when name.match?(/_(content|description|body|bio|text|summary|excerpt|intro|message)$/)
    'textarea'
  # Feature lists
  when name.match?(/_(features|items|tags|list)$/) && !name.include?('faq')
    'feature_list'
  else
    'text'
  end
end
```

### Phase 2: Add Field Metadata to Definitions

Gradually update `PagePartLibrary::DEFINITIONS` to use hash-based field configs.

### Phase 3: Database Schema Enhancement

Add `field_schema` column to `pwb_page_parts` for per-instance customization:

```ruby
add_column :pwb_page_parts, :field_schema, :jsonb, default: {}
```

### Phase 4: Full Client Implementation

Build client-side form generator that reads field schema and renders appropriate components.

---

## Client Implementation Guide

### TypeScript Types

```typescript
interface FieldDefinition {
  name: string;
  type: FieldType;
  label: string;
  hint?: string;
  placeholder?: string;
  required: boolean;
  component: string;
  validation?: FieldValidation;
  options?: FieldOptions;
  content_guidance?: ContentGuidance;
  group?: string;
  paired_with?: string;
  order?: number;
  item_schema?: Record<string, FieldDefinition>;
}

type FieldType =
  | 'text' | 'textarea' | 'html' | 'markdown'
  | 'number' | 'currency' | 'percentage'
  | 'email' | 'phone' | 'url'
  | 'image' | 'video' | 'file'
  | 'select' | 'radio' | 'checkbox' | 'multi_select'
  | 'icon' | 'color' | 'date' | 'datetime'
  | 'link' | 'social_link' | 'map_embed'
  | 'array' | 'faq_array' | 'feature_list';

interface FieldValidation {
  min_length?: number;
  max_length?: number;
  min?: number;
  max?: number;
  pattern?: string;
  min_items?: number;
  max_items?: number;
}

interface FieldOptions {
  choices?: Array<{ value: string; label: string }>;
  aspect_ratio?: string;
  recommended_size?: string;
  accept?: string[];
  max_size_mb?: number;
  rows?: number;
  default?: any;
  toolbar?: string[];
}

interface ContentGuidance {
  recommended_length?: string;
  seo_tip?: string;
  examples?: string[];
}

interface FieldGroup {
  key: string;
  label: string;
  order: number;
}

interface FieldSchema {
  fields: FieldDefinition[];
  groups: FieldGroup[];
}
```

### Component Mapping

```typescript
const COMPONENT_MAP: Record<string, React.ComponentType<FieldProps>> = {
  TextInput: TextInput,
  TextareaInput: TextareaInput,
  WysiwygEditor: WysiwygEditor,
  NumberInput: NumberInput,
  CurrencyInput: CurrencyInput,
  EmailInput: EmailInput,
  PhoneInput: PhoneInput,
  UrlInput: UrlInput,
  ImagePicker: ImagePicker,
  SelectInput: SelectInput,
  CheckboxInput: CheckboxInput,
  IconPicker: IconPicker,
  ColorPicker: ColorPicker,
  DatePicker: DatePicker,
  ArrayEditor: ArrayEditor,
  FaqEditor: FaqEditor,
  FeatureListEditor: FeatureListEditor,
};

function renderField(field: FieldDefinition, value: any, onChange: (v: any) => void) {
  const Component = COMPONENT_MAP[field.component] || TextInput;

  return (
    <FieldWrapper
      label={field.label}
      hint={field.hint}
      required={field.required}
      guidance={field.content_guidance}
    >
      <Component
        name={field.name}
        value={value}
        onChange={onChange}
        placeholder={field.placeholder}
        validation={field.validation}
        options={field.options}
      />
    </FieldWrapper>
  );
}
```

---

## Summary

The current field type system works but is limited by:
1. Name-based inference only
2. Missing field types (email, phone, number, currency, select)
3. No validation or content guidance
4. No field grouping or relationships

The recommended improvements will enable:
1. Explicit field type definitions
2. Rich metadata for editors (hints, placeholders, guidance)
3. Validation rules (required, min/max, patterns)
4. Field grouping and visual organization
5. Content guidance for SEO and best practices
6. Support for complex/repeating fields

Implementation can be done incrementally, starting with enhanced inference and gradually adding explicit field definitions.
