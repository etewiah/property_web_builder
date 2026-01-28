# Page Parts Documentation

This folder contains documentation for the PropertyWebBuilder Page Parts system.

## Documents

### Core Documentation

- **[PagePart System Documentation](../architecture/08_PagePart_System.md)** - Comprehensive guide to the page parts architecture, including database schema, models, templates, and best practices.

### Form Page Parts

- **[Form Page Parts Implementation Guide](FORM_PAGE_PARTS.md)** - Detailed documentation for implementing contact forms using the modern page parts pattern. **Includes naming conventions.**

- **[Form Page Parts Quick Reference](FORM_PAGE_PARTS_QUICK_REFERENCE.md)** - Concise reference for form field definitions, template patterns, and API usage.

### Container Page Parts (Composable Layouts)

- **[Container Page Parts](CONTAINER_PAGE_PARTS.md)** - Documentation for container page parts that enable side-by-side layouts. Containers define named slots where child page parts can be placed.

## Naming Conventions (Important)

Page part keys must be **URL-safe** and **descriptive**. Use the pattern:

```
{category}_{purpose}_{variant}
```

**Examples:**
| Good | Bad | Why |
|------|-----|-----|
| `contact_general_enquiry` | `contact_form` | Too generic |
| `contact_location_map` | `forms/contact_with_map` | Slash breaks URLs |
| `hero_search_centered` | `hero_1` | Not descriptive |

**Validation regex:** `/\A[a-z][a-z0-9]*(_[a-z0-9]+)*\z/`

See [Form Page Parts Implementation Guide](FORM_PAGE_PARTS.md#naming-conventions) for full details.

## Composable Layouts (Containers)

Container page parts enable side-by-side layouts:

```
┌─────────────────────────────────────┐
│         Hero (full width)           │
├─────────────────┬───────────────────┤
│  Contact Form   │   Location Map    │  ← Container with slots
│  (left slot)    │   (right slot)    │
├─────────────────┴───────────────────┤
│         CTA (full width)            │
└─────────────────────────────────────┘
```

**Key concepts:**
- Containers define **named slots** (left, right, main, sidebar)
- Child page parts are **assigned to slots**
- **Single level nesting only** - containers cannot contain other containers
- **Any non-container** page part can be placed in a slot

**Available containers:**
| Container | Slots | Split |
|-----------|-------|-------|
| `layout_two_column_equal` | left, right | 50/50 |
| `layout_two_column_wide_narrow` | left, right | 67/33 |
| `layout_sidebar_left` | sidebar, main | 25/75 |
| `layout_sidebar_right` | main, sidebar | 75/25 |
| `layout_three_column_equal` | left, center, right | 33/33/33 |

See [Container Page Parts](CONTAINER_PAGE_PARTS.md) for full documentation.

## Overview

Page Parts are reusable content blocks that form the building blocks of website pages in PropertyWebBuilder. They provide:

- **Separation of concerns**: Templates (structure) vs content (data)
- **Multilingual support**: Content stored per-locale in `block_contents`
- **Visual editing**: Structured editor UI via `editor_setup`
- **Theme independence**: Content survives theme changes

## Key Concepts

### Page Part Types

| Type | Rendering | Use Case |
|------|-----------|----------|
| **Liquid Part** | Renders via Liquid template | Most content sections |
| **Rails Part** | Renders via ERB partial | Dynamic components |

### Modern vs Legacy

| Aspect | Legacy | Modern |
|--------|--------|--------|
| Field definitions | Array of strings | Hash with metadata |
| Field types | Inferred from name | Explicit type declarations |
| Validation | None | Via field metadata |
| Groups | None | Field groups for UI |

## File Locations

| Component | Location |
|-----------|----------|
| Definitions | `app/lib/pwb/page_part_library.rb` |
| Templates | `app/views/pwb/page_parts/` |
| Models | `app/models/pwb/page_part.rb` |
| Manager | `app/services/pwb/page_part_manager.rb` |
| Seeds | `db/yml_seeds/page_parts/` |

## Quick Links

- [PagePartLibrary source](../../app/lib/pwb/page_part_library.rb)
- [FieldSchemaBuilder source](../../app/lib/pwb/field_schema_builder.rb)
- [Contact API controller](../../app/controllers/api_public/v1/contact_controller.rb)
- [Stimulus controllers](../../app/javascript/controllers/)
