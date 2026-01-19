# Responsive Images Implementation

## Overview
This document describes the implementation of responsive images for PropertyWebBuilder content. The goal is to automatically upgrade static `<img>` tags in page content to responsive `<picture>` elements with WebP sources and lazy loading, specifically catering to PWB's seed images.

## Components

### 1. `Pwb::ImagesHelper#make_media_responsive`
This helper method is the core transformation logic.
- **Input**: An HTML string.
- **Output**: The HTML string with `<img>` tags replaced or modified.
- **Logic**:
    - Parses HTML using `Nokogiri`.
    - Identifies `<img>` tags that are not already within a `<picture>` element.
    - Checks if the image source is "trusted" (e.g., existing seed images buckets) and is a JPEG.
    - If trusted: Replaces the `<img>` tag with a `<picture>` element containing a WebP source.
    - For all images: Ensures `loading="lazy"` is set.

### 2. `Pwb::PagePartManager` Integration
The `PagePartManager` handles the saving and rebuilding of page part content (the blocks of HTML that make up a page).
- **Modification**: In the `rebuild_page_content` method, before saving the generated HTML to the `Pwb::Content` record (`raw_en`, etc.), we call `make_media_responsive`.
- **Effect**: Any time content is updated via the Editor or API, it is automatically optimized before storage.

### 3. `Pwb::ResponsiveContentMigrationService`
A one-time migration service to update existing content in the database.
- **Logic**: Iterates through all `Pwb::Content` records, checks all translation fields, applies `make_media_responsive`, and saves if changes are detected.

## Usage

### Automatic
No manual intervention is needed for new content. Using the PWB Editor to save content will trigger the optimization.

### Manual Migration
To migrate legacy content:

```ruby
Pwb::ResponsiveContentMigrationService.new.run
```

## Testing
- **Unit Tests**: `spec/helpers/pwb/images_helper_responsive_spec.rb` covers HTML transformation edge cases.
- **Integration Tests**: `spec/services/pwb/page_part_manager_spec.rb` verifies that saving content triggers the transformation.

## Comparison with `docs/images` Specification

The current implementation differs from the architecture proposed in `docs/images` in several key ways. This pragmatic approach was chosen to integrate with the existing codebase without requiring a full refactor of the underlying image handling system.

| Feature | `docs/images` Specification | Current Implementation |
| :--- | :--- | :--- |
| **Architecture** | New `Pwb::ResponsiveVariants` module and `Pwb::ResponsiveImagesHelper`. | Extends existing `Pwb::ImagesHelper` with `make_media_responsive`. |
| **Breakpoints** | Tailwind-aligned: `[320, 640, 768, 1024, 1280, 1536, 1920]`. | Legacy PWB: `[320, 640, 768, 1024, 1280]`. |
| **Formats** | AVIF (primary), WebP (fallback), JPEG (fallback). | WebP (primary), JPEG (fallback). AVIF is not configured. |
| **Presets** | Named presets (`:hero`, `:card`, etc.) defining sizes. | hardcoded logic or passed-in options. |
| **Scope** | Comprehensive system for all app images (Property Cards, etc.). | Focused on **content** HTML optimization (`raw_*` fields). |

## Future Enhancements / TODOs

To fully align with the `docs/images` vision, the following tasks are recommended:

- [ ] **Create `Pwb::ResponsiveVariants`**: Centralize breakpoint and format configuration (including adding Tailwind-aligned breakpoints).
- [ ] **Implement AVIF Support**: Update image generation logic to support AVIF if the server environment (libvips) allows it.
- [ ] **Refactor `ImagesHelper`**: Migrate logic to `Pwb::ResponsiveImagesHelper` as a dedicated module for modern image tags.
- [ ] **Implement Named Presets**: Replace hardcoded `sizes` attributes with semantic presets (e.g., `make_media_responsive(html, preset: :content)`).
- [ ] **Backfill Strategy**: Create a job to generate variants for all `PropPhoto` and `ContentPhoto` records, not just correct the HTML references.

