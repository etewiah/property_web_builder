# Material Icons Migration Plan

> **Note:** This plan is now deprecated. PropertyWebBuilder ships with Lucide inline SVG icons (see `docs/lucide-migration-guide.md`). The details below remain for historical reference only.

## Executive Summary

This document outlines the complete migration from Font Awesome and Phosphor Icons to Google Material Icons, with enforcement mechanisms to prevent future use of other icon libraries.

## Why Material Icons?

| Criteria | Font Awesome | Phosphor | Material Icons |
|----------|-------------|----------|----------------|
| **Size (subset)** | 9.5KB | ~200KB (CDN) | ~42KB (woff2) |
| **Total Icons** | 7,000+ | 7,000+ | 2,500+ |
| **Style Variants** | 3 (solid, regular, brands) | 6 (regular, bold, thin, fill, duotone, light) | 5 (outlined, filled, rounded, sharp, two-tone) |
| **License** | OFL/MIT (Free), Commercial (Pro) | MIT | Apache 2.0 |
| **Self-hostable** | Yes | Yes | Yes |
| **Maintenance** | Fonticons Inc. | Open source | Google |
| **Design System** | General purpose | Modern/minimal | Material Design 3 |

### Decision Rationale

1. **Unified Design Language**: Material Design is widely recognized and provides a consistent, professional aesthetic
2. **Google Backing**: Long-term maintenance and updates guaranteed
3. **Apache 2.0 License**: No commercial restrictions
4. **Reasonable Size**: 42KB is a good balance between Font Awesome's minimal subset and Phosphor's large CDN load
5. **Variable Font Support**: Material Symbols offers variable font with weight, fill, grade, and optical size customization

---

## Current State (Updated: December 2024)

### Migration Progress

| Component | Status | Notes |
|-----------|--------|-------|
| Infrastructure (CSS, Fonts) | **Complete** | Material Symbols font installed in `public/fonts/material-symbols/` |
| Icon Helper (ERB) | **Complete** | `app/helpers/pwb/icon_helper.rb` with validation |
| Liquid Filters | **Complete** | `material_icon` and `brand_icon` filters in `app/lib/pwb/liquid_filters.rb` |
| Brand Icon SVG Sprite | **Complete** | `app/assets/images/icons/brands.svg` |
| Rake Tasks | **Complete** | `icons:audit`, `icons:migrate_database`, `icons:migrate_templates` |
| CI Workflow | **Complete** | `.github/workflows/icon-check.yml` |
| Pre-commit Hook | **Complete** | `scripts/check-icons.sh` |
| Liquid Templates (Page Parts) | **Complete** | All `.liquid` files migrated |
| ERB Templates | **In Progress** | ~380 instances remaining |
| YAML Seed Files | **In Progress** | Legacy icon patterns still present |

### Remaining Work

Run `rake icons:audit` to see current status. As of migration start:

| Category | File Count | Icon Instances |
|----------|------------|----------------|
| ERB Templates (themes) | 55+ | ~230 |
| YAML Seeds | 15+ | ~40 |
| Admin Views | 10+ | ~20 |
| Other (controllers, etc.) | 5 | ~10 |

### Icon Mapping

See `app/helpers/pwb/icon_helper.rb` for the complete `ICON_ALIASES` mapping.

---

## Migration Strategy

### Phase 1: Infrastructure Setup (Week 1)

#### 1.1 Install Material Icons

```bash
# Option A: Self-host (Recommended)
# Download from https://github.com/nicholasess/google-material-design-symbols-for-sketch
# Or use npm package

# Option B: CDN (Quick start)
# Add to application layout
```

**Create CSS file**: `app/assets/stylesheets/material-icons.css`

```css
/* Material Symbols - Variable Font */
@font-face {
  font-family: 'Material Symbols Outlined';
  font-style: normal;
  font-weight: 100 700;
  font-display: swap;
  src: url('/fonts/material-symbols/MaterialSymbolsOutlined.woff2') format('woff2');
}

.material-symbols-outlined {
  font-family: 'Material Symbols Outlined';
  font-weight: normal;
  font-style: normal;
  font-size: 24px;
  line-height: 1;
  letter-spacing: normal;
  text-transform: none;
  display: inline-block;
  white-space: nowrap;
  word-wrap: normal;
  direction: ltr;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
  font-feature-settings: 'liga';
}

/* Size variants */
.material-symbols-outlined.md-18 { font-size: 18px; }
.material-symbols-outlined.md-24 { font-size: 24px; }
.material-symbols-outlined.md-36 { font-size: 36px; }
.material-symbols-outlined.md-48 { font-size: 48px; }

/* Fill variant */
.material-symbols-outlined.filled {
  font-variation-settings: 'FILL' 1;
}
```

#### 1.2 Create Icon Helper

**Create**: `app/helpers/pwb/icon_helper.rb`

```ruby
# frozen_string_literal: true

module Pwb
  module IconHelper
    # Central icon rendering - THE ONLY WAY to render icons
    #
    # @param name [Symbol, String] Icon name (e.g., :home, :search, "arrow_forward")
    # @param options [Hash] Options for the icon
    # @option options [Symbol] :size (:md) Size: :sm (18px), :md (24px), :lg (36px), :xl (48px)
    # @option options [Boolean] :filled (false) Use filled variant
    # @option options [String] :class Additional CSS classes
    # @option options [Hash] :aria Accessibility attributes
    #
    # @example Basic usage
    #   <%= icon(:home) %>
    #   # => <span class="material-symbols-outlined" aria-hidden="true">home</span>
    #
    # @example With options
    #   <%= icon(:search, size: :lg, filled: true, class: "text-primary") %>
    #
    # @example Accessible icon (with meaning)
    #   <%= icon(:warning, aria: { label: "Warning" }) %>
    #
    def icon(name, options = {})
      name = normalize_icon_name(name)
      validate_icon_name!(name)

      size_class = icon_size_class(options[:size] || :md)
      filled_class = options[:filled] ? "filled" : nil
      custom_class = options[:class]

      classes = ["material-symbols-outlined", size_class, filled_class, custom_class].compact.join(" ")

      aria_attrs = if options[:aria]&.key?(:label)
        { "aria-label" => options[:aria][:label], role: "img" }
      else
        { "aria-hidden" => "true" }
      end

      content_tag(:span, name, class: classes, **aria_attrs)
    end

    # Alias for common patterns
    def icon_button(name, options = {})
      button_class = options.delete(:button_class) || "icon-button"
      content_tag(:button, icon(name, options), class: button_class, type: "button")
    end

    private

    ALLOWED_ICONS = %w[
      home search arrow_back arrow_forward chevron_left chevron_right
      chevron_down chevron_up menu close check check_circle
      bed bathroom local_parking directions_car
      phone email person location_on map
      edit delete add remove visibility visibility_off
      star star_border favorite favorite_border
      share facebook instagram linkedin youtube
      expand_more expand_less fullscreen fullscreen_exit
      filter_list sort photo_library image
      info warning error help
      login logout settings
      arrow_drop_down arrow_drop_up
      format_quote lock key
      attach_money payments handshake
      sunny wb_sunny brightness_5 brightness_6 brightness_7
      tag label category
      description file_copy
      grid_view list view_list
      refresh sync
      upload download cloud_upload
      open_in_new link
    ].freeze

    ICON_ALIASES = {
      # Property features
      bedroom: "bed",
      bathroom: "bathroom",
      parking: "local_parking",
      car: "directions_car",

      # Navigation
      back: "arrow_back",
      forward: "arrow_forward",
      left: "chevron_left",
      right: "chevron_right",
      down: "chevron_down",
      up: "chevron_up",
      hamburger: "menu",

      # Contact
      envelope: "email",
      user: "person",
      marker: "location_on",
      globe: "public",

      # Actions
      pencil: "edit",
      trash: "delete",
      plus: "add",
      minus: "remove",
      eye: "visibility",
      eye_off: "visibility_off",

      # Social (map to generic share since Material doesn't have brand icons)
      # Brand icons will use SVG sprites
      twitter: "share",
      whatsapp: "share",

      # Misc
      expand: "fullscreen",
      arrows_alt: "fullscreen",
      quote: "format_quote",
      money: "attach_money",
      hand_coins: "payments",

      # Light exposure
      sun: "wb_sunny",
      sun_horizon: "brightness_6",
      sun_dim: "brightness_5"
    }.freeze

    def normalize_icon_name(name)
      name = name.to_s.underscore
      ICON_ALIASES[name.to_sym] || name
    end

    def validate_icon_name!(name)
      return if ALLOWED_ICONS.include?(name) || Rails.env.production?

      raise ArgumentError, "Unknown icon: '#{name}'. Add it to ALLOWED_ICONS in IconHelper if valid."
    end

    def icon_size_class(size)
      case size.to_sym
      when :sm then "md-18"
      when :md then "md-24"
      when :lg then "md-36"
      when :xl then "md-48"
      else "md-24"
      end
    end
  end
end
```

#### 1.3 Create Brand Icon SVG Sprite

Material Icons doesn't include brand logos (Facebook, Instagram, etc.). Use SVG sprites for these.

**Create**: `app/assets/images/icons/brands.svg`

```svg
<svg xmlns="http://www.w3.org/2000/svg" style="display:none">
  <symbol id="icon-facebook" viewBox="0 0 24 24">
    <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
  </symbol>
  <symbol id="icon-instagram" viewBox="0 0 24 24">
    <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/>
  </symbol>
  <symbol id="icon-linkedin" viewBox="0 0 24 24">
    <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
  </symbol>
  <symbol id="icon-youtube" viewBox="0 0 24 24">
    <path d="M23.498 6.186a3.016 3.016 0 00-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 00.502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 002.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 002.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
  </symbol>
  <symbol id="icon-twitter" viewBox="0 0 24 24">
    <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
  </symbol>
  <symbol id="icon-whatsapp" viewBox="0 0 24 24">
    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
  </symbol>
</svg>
```

**Helper for brand icons**:

```ruby
# Add to icon_helper.rb
def brand_icon(name, options = {})
  size = options[:size] || 24
  css_class = ["brand-icon", options[:class]].compact.join(" ")

  content_tag(:svg, class: css_class, width: size, height: size, "aria-hidden": "true") do
    content_tag(:use, nil, href: "#icon-#{name}")
  end
end
```

### Phase 2: Enforcement Mechanisms (Week 1-2)

#### 2.1 Custom RuboCop Cop

**Create**: `lib/rubocop/cop/pwb/no_inline_icons.rb`

```ruby
# frozen_string_literal: true

module RuboCop
  module Cop
    module Pwb
      # Detects inline icon class usage that bypasses the icon helper.
      #
      # @example Bad
      #   content_tag(:i, '', class: 'fa fa-home')
      #   "<i class='ph ph-house'></i>"
      #
      # @example Good
      #   icon(:home)
      #   brand_icon(:facebook)
      #
      class NoInlineIcons < Base
        MSG = "Use `icon(:name)` helper instead of inline icon classes. " \
              "See docs/architecture/MATERIAL_ICONS_MIGRATION_PLAN.md"

        FORBIDDEN_PATTERNS = [
          /\bfa\s+fa-/,           # Font Awesome
          /\bfas\s+fa-/,          # Font Awesome Solid
          /\bfab\s+fa-/,          # Font Awesome Brands
          /\bph\s+ph-/,           # Phosphor
          /\bglyphicon\b/,        # Glyphicons
          /\bzmdi\b/,             # Material Design Iconic Font
        ].freeze

        def on_str(node)
          return unless forbidden_icon_class?(node.value)

          add_offense(node)
        end

        def on_dstr(node)
          node.each_child_node(:str) do |str_node|
            if forbidden_icon_class?(str_node.value)
              add_offense(str_node)
            end
          end
        end

        private

        def forbidden_icon_class?(str)
          FORBIDDEN_PATTERNS.any? { |pattern| str.match?(pattern) }
        end
      end
    end
  end
end
```

#### 2.2 ERB Linter Rule

**Create**: `lib/erb_lint/linters/no_inline_icons.rb`

```ruby
# frozen_string_literal: true

require "erb_lint/linters/linter"

module ERBLint
  module Linters
    class NoInlineIcons < Linter
      include LinterRegistry

      FORBIDDEN_PATTERNS = [
        /class\s*=\s*["'][^"']*\bfa\s+fa-[^"']*["']/,
        /class\s*=\s*["'][^"']*\bph\s+ph-[^"']*["']/,
        /class\s*=\s*["'][^"']*\bglyphicon\b[^"']*["']/,
      ].freeze

      def run(processed_source)
        FORBIDDEN_PATTERNS.each do |pattern|
          processed_source.source.scan(pattern) do
            match = Regexp.last_match
            add_offense(
              processed_source.to_source_range(match.begin(0)...match.end(0)),
              "Inline icon classes are forbidden. Use `<%= icon(:name) %>` helper instead."
            )
          end
        end
      end
    end
  end
end
```

#### 2.3 Git Pre-commit Hook

**Create**: `scripts/check_icons.sh`

```bash
#!/bin/bash
# Pre-commit hook to prevent forbidden icon classes

FORBIDDEN_PATTERNS=(
  'class="[^"]*fa fa-'
  "class='[^']*fa fa-"
  'class="[^"]*ph ph-'
  "class='[^']*ph ph-"
  'class="[^"]*glyphicon'
)

FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(erb|html|liquid|rb|yml|yaml)$')

if [ -z "$FILES" ]; then
  exit 0
fi

ERRORS=0

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
  MATCHES=$(echo "$FILES" | xargs grep -l "$pattern" 2>/dev/null)
  if [ -n "$MATCHES" ]; then
    echo "ERROR: Forbidden icon class pattern found: $pattern"
    echo "Files:"
    echo "$MATCHES" | sed 's/^/  - /'
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "Use the icon(:name) helper instead of inline icon classes."
  echo "See: docs/architecture/MATERIAL_ICONS_MIGRATION_PLAN.md"
  exit 1
fi

exit 0
```

#### 2.4 CI GitHub Action

**Create**: `.github/workflows/icon-check.yml`

```yaml
name: Icon Enforcement

on:
  pull_request:
    paths:
      - '**/*.erb'
      - '**/*.html'
      - '**/*.liquid'
      - '**/*.rb'
      - '**/*.yml'
      - '**/*.yaml'

jobs:
  check-icons:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check for forbidden icon classes
        run: |
          FORBIDDEN_PATTERNS=(
            'fa fa-'
            'fas fa-'
            'fab fa-'
            'ph ph-'
            'glyphicon'
          )

          ERRORS=0

          for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
            MATCHES=$(grep -rn "$pattern" \
              --include="*.erb" \
              --include="*.html" \
              --include="*.liquid" \
              --include="*.rb" \
              --include="*.yml" \
              --include="*.yaml" \
              app/ db/ lib/ config/ 2>/dev/null || true)

            if [ -n "$MATCHES" ]; then
              echo "::error::Forbidden icon pattern '$pattern' found:"
              echo "$MATCHES"
              ERRORS=$((ERRORS + 1))
            fi
          done

          if [ $ERRORS -gt 0 ]; then
            echo ""
            echo "::error::Use icon(:name) helper instead of inline icon classes"
            exit 1
          fi

          echo "No forbidden icon patterns found."
```

### Phase 3: Migration Execution (Week 2-4)

#### 3.1 Migration Rake Task

**Create**: `lib/tasks/icons.rake`

```ruby
# frozen_string_literal: true

namespace :icons do
  desc "Audit codebase for non-Material icon usage"
  task audit: :environment do
    require "find"

    patterns = {
      "Font Awesome" => /\bfa\s+fa-|\bfas\s+fa-|\bfab\s+fa-/,
      "Phosphor" => /\bph\s+ph-/,
      "Glyphicons" => /\bglyphicon\b/
    }

    results = Hash.new { |h, k| h[k] = [] }

    extensions = %w[.erb .html .liquid .rb .yml .yaml]

    Find.find(Rails.root.join("app"), Rails.root.join("db"), Rails.root.join("lib")) do |path|
      next unless extensions.include?(File.extname(path))
      next if path.include?("node_modules")

      content = File.read(path)

      patterns.each do |name, pattern|
        if content.match?(pattern)
          matches = content.scan(pattern)
          results[name] << { file: path, count: matches.length }
        end
      end
    end

    if results.empty?
      puts "No forbidden icon patterns found!"
    else
      results.each do |icon_type, files|
        puts "\n#{icon_type} icons found:"
        files.each do |file|
          puts "  #{file[:file]} (#{file[:count]} instances)"
        end
      end

      total = results.values.flatten.sum { |f| f[:count] }
      puts "\nTotal: #{total} instances to migrate"
    end
  end

  desc "Update database icon_class values to Material Icons"
  task migrate_database: :environment do
    ICON_MAP = {
      # Font Awesome to Material
      "fa fa-facebook" => "facebook",
      "fa fa-instagram" => "instagram",
      "fa fa-linkedin" => "linkedin",
      "fa fa-youtube" => "youtube",
      "fa fa-twitter" => "twitter",
      "fa fa-whatsapp" => "whatsapp",
      "fa fa-home" => "home",
      "fa fa-user" => "person",
      "fa fa-envelope" => "email",
      "fa fa-phone" => "phone",
      "fa fa-map-marker-alt" => "location_on",
      "fa fa-search" => "search",
      "fa fa-check" => "check",
      "fa fa-bed" => "bed",
      "fa fa-bath" => "bathroom",
      "fa fa-car" => "local_parking",
      "fa fa-money" => "attach_money",
      "fa fa-key" => "key",
      # Phosphor to Material
      "ph ph-house" => "home",
      "ph ph-user" => "person",
      "ph ph-envelope" => "email",
      "ph ph-phone" => "phone",
      "ph ph-map-pin" => "location_on",
      "ph ph-magnifying-glass" => "search",
      "ph ph-check" => "check",
      "ph ph-bed" => "bed",
      "ph ph-bathtub" => "bathroom",
      "ph ph-car" => "local_parking",
      "ph ph-hand-coins" => "payments",
      "ph ph-key" => "key"
    }.freeze

    # Migrate Link model
    Pwb::Link.find_each do |link|
      next unless link.icon_class.present?

      new_class = ICON_MAP[link.icon_class]
      if new_class
        puts "Updating Link ##{link.id}: #{link.icon_class} -> #{new_class}"
        link.update_column(:icon_class, new_class)
      elsif !link.icon_class.match?(/^[a-z_]+$/)
        puts "WARNING: Unknown icon class on Link ##{link.id}: #{link.icon_class}"
      end
    end

    puts "Database migration complete!"
  end
end
```

#### 3.2 Template Migration Order

1. **Layouts** (highest impact)
   - `app/views/layouts/pwb/application.html.erb`
   - Theme-specific layouts

2. **Shared Partials** (high reuse)
   - `app/views/pwb/shared/_social_sharing.html.erb`
   - Footer partials across all themes

3. **Page Parts** (Liquid templates)
   - Feature cards, testimonials, FAQ accordions

4. **Property Templates**
   - Property cards, show pages, carousels

5. **Search Templates**
   - Search forms and results

6. **YAML Seeds**
   - Content translations
   - Seed packs

### Phase 4: Cleanup (Week 4)

#### 4.1 Remove Old Icon Assets

```bash
# Remove Font Awesome
rm -rf public/fonts/fontawesome-subset/
rm app/assets/stylesheets/fontawesome-subset.css

# Remove Phosphor CDN references
# Edit layout files to remove CDN links

# Remove legacy icon fonts
rm -rf public/fonts/glyphicons*
rm -rf public/fonts/Material-Design-Iconic-Font*
rm -rf app/assets/fonts/fonts/
rm -rf vendor/assets/fonts/
```

#### 4.2 Update Asset Pipeline

```ruby
# config/initializers/assets.rb
# Remove: Rails.application.config.assets.precompile += %w[fontawesome-subset.css]
# Add: Rails.application.config.assets.precompile += %w[material-icons.css]
```

---

## Icon Mapping Reference

### Complete Mapping Table

| Old Icon (FA/Phosphor) | Material Icon | Context |
|------------------------|---------------|---------|
| `fa-home` / `ph-house` | `home` | Navigation, property type |
| `fa-user` / `ph-user` | `person` | User profile |
| `fa-envelope` / `ph-envelope` | `email` | Contact |
| `fa-phone` / `ph-phone` | `phone` | Contact |
| `fa-search` / `ph-magnifying-glass` | `search` | Search |
| `fa-bed` / `ph-bed` | `bed` | Bedrooms |
| `fa-bath` / `ph-bathtub` | `bathroom` | Bathrooms |
| `fa-car` / `ph-car` | `local_parking` | Parking |
| `fa-map-marker-alt` / `ph-map-pin` | `location_on` | Location |
| `fa-check` / `ph-check` | `check` | Confirmation |
| `fa-chevron-down` | `expand_more` | Dropdown |
| `fa-chevron-up` | `expand_less` | Collapse |
| `fa-chevron-left` / `ph-caret-left` | `chevron_left` | Navigation |
| `fa-chevron-right` / `ph-caret-right` | `chevron_right` | Navigation |
| `fa-bars` | `menu` | Menu |
| `fa-expand` / `ph-arrows-out` | `fullscreen` | Expand |
| `fa-edit` | `edit` | Edit |
| `fa-star` / `ph-star` | `star` | Rating |
| `fa-quote-left` | `format_quote` | Testimonial |
| `fa-info-circle` / `ph-info` | `info` | Information |
| `fa-lock` | `lock` | Security |
| `fa-key` / `ph-key` | `key` | Access |
| `fa-money` / `ph-hand-coins` | `attach_money` | Price |
| `fa-globe` | `public` | Website |
| `fa-images` | `photo_library` | Gallery |
| `fa-filter` | `filter_list` | Filters |
| `fa-spinner` | `sync` | Loading |
| `fa-sign-out-alt` | `logout` | Logout |
| `fa-cloud-upload-alt` | `cloud_upload` | Upload |
| `fa-external-link` | `open_in_new` | External link |

### Brand Icons (Use SVG Sprite)

| Brand | SVG Symbol ID |
|-------|---------------|
| Facebook | `#icon-facebook` |
| Instagram | `#icon-instagram` |
| LinkedIn | `#icon-linkedin` |
| YouTube | `#icon-youtube` |
| Twitter/X | `#icon-twitter` |
| WhatsApp | `#icon-whatsapp` |

---

## Validation Checklist

### Before Migration
- [ ] All icon usage audited via `rake icons:audit`
- [ ] Icon helper created and tested
- [ ] Brand icon SVG sprite created
- [ ] RuboCop cop installed
- [ ] ERB linter rule installed
- [ ] Pre-commit hook installed
- [ ] CI workflow added

### During Migration
- [ ] Layouts migrated
- [ ] Shared partials migrated
- [ ] All 5 themes migrated
- [ ] Page parts (Liquid) migrated
- [ ] YAML seeds updated
- [ ] Database records updated via `rake icons:migrate_database`

### After Migration
- [ ] Old icon assets removed
- [ ] All tests passing
- [ ] Visual regression testing complete
- [ ] No CI failures
- [ ] Documentation updated

---

## Rollback Plan

If issues arise:

1. **Revert Git commits** containing template changes
2. **Restore old CSS**: `git checkout HEAD~n -- app/assets/stylesheets/fontawesome-subset.css`
3. **Restore font files**: `git checkout HEAD~n -- public/fonts/fontawesome-subset/`
4. **Re-run database migration** with reverse mapping

---

## Timeline

| Week | Phase | Deliverables |
|------|-------|--------------|
| 1 | Infrastructure | Icon helper, CSS, enforcement tools |
| 2 | Enforcement | RuboCop, ERB linter, CI, pre-commit |
| 2-3 | Migration | Templates, partials, Liquid files |
| 3-4 | Database & Seeds | YAML files, database records |
| 4 | Cleanup | Remove old assets, final testing |

---

## Maintenance

### Adding New Icons

1. Check if icon exists in Material Symbols: https://fonts.google.com/icons
2. Add icon name to `ALLOWED_ICONS` in `IconHelper`
3. Use `<%= icon(:new_icon_name) %>` in templates

### Adding New Brand Icons

1. Get SVG from Simple Icons: https://simpleicons.org/
2. Add `<symbol>` to `app/assets/images/icons/brands.svg`
3. Use `<%= brand_icon(:brand_name) %>` in templates

---

## References

- [Material Symbols](https://fonts.google.com/icons)
- [Material Design Icons Guidelines](https://m3.material.io/styles/icons)
- [Simple Icons](https://simpleicons.org/) (for brand logos)
