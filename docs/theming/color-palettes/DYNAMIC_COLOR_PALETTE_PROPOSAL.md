# Dynamic Color Palette System Proposal

## Executive Summary

This document analyzes approaches for implementing a flexible color palette system that supports both:
1. **Dynamic Mode** - Real-time color changes for admin experimentation
2. **Compiled Mode** - Pre-compiled CSS for production performance

## Current State Analysis

### How Colors Work Today

```
┌─────────────────────────────────────────────────────────────────────┐
│                         COLOR FLOW                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Palette JSON ──► style_variables ──► CSS ERB Template ──► :root   │
│  (static file)    (database)          (per-request)      (CSS vars)│
│                                                                      │
│  Tailwind Config ──► Build Time ──► tailwind-{theme}.css           │
│  (static)            (npm run)      (pre-compiled, hardcoded)       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### The Gap

| Element | Current State | Desired State |
|---------|--------------|---------------|
| CSS Variables (`--primary-color`) | Dynamic per-tenant | ✓ Working |
| Tailwind utilities (`bg-blue-600`) | Hardcoded at build | Need to respect palette |
| Theme-specific colors (`bg-terra-500`) | Hardcoded at build | Need to respect palette |
| Buttons, links, badges | Use static Tailwind classes | Should use palette colors |

### Root Cause

Templates use static Tailwind classes like `bg-blue-600` instead of CSS variable references like `bg-[var(--primary-color)]`. Even though `--primary-color` is dynamically set, it's not being used.

---

## Approach Analysis

### Option A: CSS Variables Everywhere (Runtime Dynamic)

**Description:** Replace all static Tailwind color classes with CSS variable references.

```erb
<!-- Before (hardcoded) -->
<button class="bg-blue-600 hover:bg-blue-700 text-white">
  Submit
</button>

<!-- After (dynamic) -->
<button class="bg-[var(--primary-color)] hover:bg-[var(--primary-dark)] text-white">
  Submit
</button>
```

**Pros:**
- Instant color changes without rebuild
- Perfect for admin experimentation
- Palette changes visible immediately
- No additional compilation needed
- Works with existing CSS variable system

**Cons:**
- Larger CSS bundle (Tailwind generates classes for each `var()` reference)
- Slightly less performant (browser must resolve variables)
- Less readable class names
- No build-time optimization possible
- Can't use Tailwind's color modifiers easily (opacity variants)

**Performance Impact:**
- Initial CSS parse: +5-10ms
- Paint time: +1-2ms per element
- Runtime variable resolution: negligible

---

### Option B: Pre-compiled Theme+Palette Combinations

**Description:** Generate separate CSS files for each theme/palette combination at build time.

```
app/assets/builds/
├── tailwind-default-classic_red.css
├── tailwind-default-ocean_blue.css
├── tailwind-default-forest_green.css
├── tailwind-brisbane-gold_navy.css
├── tailwind-brisbane-rose_gold.css
└── ... (themes × palettes combinations)
```

**Pros:**
- Maximum performance (no runtime variable resolution)
- Optimal CSS size with PurgeCSS
- Standard Tailwind utilities work
- CDN-cacheable per combination
- Build-time validation

**Cons:**
- Combinatorial explosion: 5 themes × 5 palettes = 25+ CSS files
- Must rebuild on palette changes
- No real-time experimentation
- Complex build pipeline
- Larger total storage footprint

**Performance Impact:**
- Best possible: pre-compiled, minified, gzipped
- ~50-80KB per theme/palette (with purging)

---

### Option C: Tailwind CSS-in-JS / JIT at Runtime

**Description:** Use Tailwind's JIT compiler at runtime to generate CSS on-demand.

**Pros:**
- True dynamic generation
- Only generates used classes
- Could work per-request

**Cons:**
- Not production-ready for server-side
- Requires Node.js process per request
- Significant latency (100-500ms per request)
- Not recommended by Tailwind team
- Complex caching requirements

**Verdict:** Not viable for production.

---

### Option D: Semantic Color Classes + CSS Variables (Hybrid)

**Description:** Create semantic utility classes that reference CSS variables, compiled once.

```css
/* In tailwind-input.css */
@layer utilities {
  .bg-primary { background-color: var(--primary-color); }
  .bg-primary-light { background-color: var(--primary-light); }
  .bg-primary-dark { background-color: var(--primary-dark); }
  .text-primary { color: var(--primary-color); }
  .text-primary-dark { color: var(--primary-dark); }
  .border-primary { border-color: var(--primary-color); }

  .bg-secondary { background-color: var(--secondary-color); }
  .text-secondary { color: var(--secondary-color); }

  .bg-accent { background-color: var(--accent-color); }
  .text-accent { color: var(--accent-color); }

  /* Hover variants */
  .hover\:bg-primary-dark:hover { background-color: var(--primary-dark); }
  .hover\:text-primary:hover { color: var(--primary-color); }
}
```

```erb
<!-- Usage in templates -->
<button class="bg-primary hover:bg-primary-dark text-white">
  Submit
</button>
```

**Pros:**
- Best of both worlds
- Readable, semantic class names
- Single compilation, works for all palettes
- CSS variables provide runtime flexibility
- Compatible with existing Tailwind workflow
- No combinatorial explosion
- Hover, focus, responsive variants work naturally

**Cons:**
- Need to define semantic classes upfront
- Can't use arbitrary Tailwind color values directly
- Some refactoring of existing templates required

**Performance Impact:**
- Same as regular Tailwind (~50KB gzipped)
- Variable resolution: negligible
- Best balance of performance and flexibility

---

## Recommended Solution: Hybrid Mode (Option D + Toggle)

### Design

```
┌──────────────────────────────────────────────────────────────────────┐
│                    HYBRID COLOR SYSTEM                                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────┐     ┌──────────────────┐     ┌───────────────────┐ │
│  │ Palette     │────►│ CSS Variables    │────►│ Semantic Classes  │ │
│  │ JSON/Admin  │     │ (runtime)        │     │ (compiled once)   │ │
│  └─────────────┘     └──────────────────┘     └───────────────────┘ │
│                                                                       │
│  Admin Mode:         Production Mode:                                 │
│  ┌─────────────┐     ┌─────────────────────────────────────────────┐ │
│  │ Live Editor │     │ website.palette_pinned = true               │ │
│  │ with        │     │ → Uses pre-compiled palette CSS             │ │
│  │ instant     │     │ → Maximum performance                        │ │
│  │ preview     │     │ → CDN cacheable                              │ │
│  └─────────────┘     └─────────────────────────────────────────────┘ │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### Two Operating Modes

#### 1. Dynamic Mode (Admin Experimentation)

When `website.palette_mode == "dynamic"` (default for new sites):

- CSS variables set from `style_variables` on each request
- Semantic Tailwind classes reference CSS variables
- Admin can change palette and see results immediately
- Slightly higher runtime cost (negligible in practice)

```ruby
# In controller/helper
def color_mode
  @current_website.palette_mode || "dynamic"
end
```

```erb
<!-- In layout -->
<style>
  :root {
    --primary-color: <%= @current_website.style_variables["primary_color"] %>;
    --primary-light: color-mix(in srgb, var(--primary-color) 70%, white);
    --primary-dark: color-mix(in srgb, var(--primary-color) 70%, black);
    /* ... */
  }
</style>
```

#### 2. Compiled Mode (Production Performance)

When `website.palette_mode == "compiled"`:

- Pre-generate CSS with actual color values baked in
- Stored in `website.compiled_palette_css` (database or file)
- No CSS variable resolution at runtime
- Maximum performance, fully CDN-cacheable

```ruby
# After admin "pins" a palette
website.compile_palette!
# → Generates CSS with actual hex values
# → Stores in website.compiled_palette_css
# → Sets palette_mode = "compiled"
```

```erb
<!-- In layout when compiled -->
<% if @current_website.palette_mode == "compiled" %>
  <style><%= @current_website.compiled_palette_css %></style>
<% else %>
  <style><%= render_dynamic_palette_css %></style>
<% end %>
```

---

## Implementation Plan

### Phase 1: Semantic Color Classes (Week 1)

**Goal:** Create semantic Tailwind utility classes that work with CSS variables.

**Files to modify:**
- `app/assets/stylesheets/tailwind-input.css` (and theme variants)

**Tasks:**
1. Define semantic color utility classes
2. Add hover, focus, active variants
3. Add responsive variants if needed
4. Update Tailwind config

```css
/* app/assets/stylesheets/tailwind-input.css */
@import "tailwindcss";

/* Semantic color utilities - these reference CSS variables */
@layer utilities {
  /* Primary color variants */
  .bg-primary { background-color: var(--pwb-primary, var(--primary-color, #3b82f6)); }
  .bg-primary-50 { background-color: color-mix(in srgb, var(--pwb-primary) 10%, white); }
  .bg-primary-100 { background-color: color-mix(in srgb, var(--pwb-primary) 20%, white); }
  .bg-primary-200 { background-color: color-mix(in srgb, var(--pwb-primary) 35%, white); }
  .bg-primary-300 { background-color: color-mix(in srgb, var(--pwb-primary) 50%, white); }
  .bg-primary-400 { background-color: color-mix(in srgb, var(--pwb-primary) 70%, white); }
  .bg-primary-500 { background-color: var(--pwb-primary); }
  .bg-primary-600 { background-color: color-mix(in srgb, var(--pwb-primary) 85%, black); }
  .bg-primary-700 { background-color: color-mix(in srgb, var(--pwb-primary) 70%, black); }
  .bg-primary-800 { background-color: color-mix(in srgb, var(--pwb-primary) 55%, black); }
  .bg-primary-900 { background-color: color-mix(in srgb, var(--pwb-primary) 40%, black); }

  .text-primary { color: var(--pwb-primary); }
  .text-primary-600 { color: color-mix(in srgb, var(--pwb-primary) 85%, black); }
  .text-primary-700 { color: color-mix(in srgb, var(--pwb-primary) 70%, black); }

  .border-primary { border-color: var(--pwb-primary); }
  .border-primary-200 { border-color: color-mix(in srgb, var(--pwb-primary) 35%, white); }

  .ring-primary { --tw-ring-color: var(--pwb-primary); }

  /* Secondary color variants */
  .bg-secondary { background-color: var(--pwb-secondary, var(--secondary-color, #64748b)); }
  .bg-secondary-50 { background-color: color-mix(in srgb, var(--pwb-secondary) 10%, white); }
  /* ... similar pattern ... */

  .text-secondary { color: var(--pwb-secondary); }

  /* Accent color variants */
  .bg-accent { background-color: var(--pwb-accent, var(--accent-color, #f59e0b)); }
  .text-accent { color: var(--pwb-accent); }

  /* Hover variants */
  .hover\:bg-primary:hover { background-color: var(--pwb-primary); }
  .hover\:bg-primary-600:hover { background-color: color-mix(in srgb, var(--pwb-primary) 85%, black); }
  .hover\:bg-primary-700:hover { background-color: color-mix(in srgb, var(--pwb-primary) 70%, black); }
  .hover\:text-primary:hover { color: var(--pwb-primary); }

  /* Focus variants */
  .focus\:ring-primary:focus { --tw-ring-color: var(--pwb-primary); }
  .focus\:border-primary:focus { border-color: var(--pwb-primary); }
}
```

**Tests:**
```ruby
# spec/helpers/pwb/theme_color_helper_spec.rb
RSpec.describe "Semantic color classes" do
  it "generates bg-primary class" do
    css = compile_tailwind_for_theme("default")
    expect(css).to include(".bg-primary")
    expect(css).to include("var(--pwb-primary")
  end

  it "generates hover variants" do
    css = compile_tailwind_for_theme("default")
    expect(css).to include(".hover\\:bg-primary-600:hover")
  end
end
```

### Phase 2: Template Migration (Week 2)

**Goal:** Update templates to use semantic color classes.

**Strategy:** Start with high-impact components.

**Priority order:**
1. Buttons (CTA, forms)
2. Links and navigation
3. Cards and badges
4. Headers and footers
5. Search forms and filters

**Example migrations:**

```erb
<!-- BEFORE: app/themes/default/views/pwb/sections/_contact_us_form.html.erb -->
<button class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg">
  Submit
</button>

<!-- AFTER -->
<button class="bg-primary hover:bg-primary-700 text-white px-6 py-3 rounded-lg">
  Submit
</button>
```

```erb
<!-- BEFORE: Navigation link -->
<a href="#" class="text-blue-600 hover:text-blue-800">Link</a>

<!-- AFTER -->
<a href="#" class="text-primary hover:text-primary-700">Link</a>
```

**Tests:**
```ruby
# spec/views/themes/color_class_usage_spec.rb
RSpec.describe "Template color class usage" do
  THEMES = %w[default brisbane bologna barcelona biarritz]

  THEMES.each do |theme|
    describe "#{theme} theme" do
      it "uses semantic color classes instead of hardcoded blue" do
        template_files = Dir.glob("app/themes/#{theme}/views/**/*.erb")

        template_files.each do |file|
          content = File.read(file)

          # Should not use hardcoded blue classes for primary actions
          expect(content).not_to match(/\bbg-blue-600\b.*button/i),
            "#{file} uses hardcoded bg-blue-600 instead of bg-primary"
        end
      end

      it "uses bg-primary for primary buttons" do
        button_files = Dir.glob("app/themes/#{theme}/views/**/*{button,form,cta}*.erb")

        button_files.each do |file|
          content = File.read(file)
          if content.include?("button") || content.include?("submit")
            expect(content).to include("bg-primary").or include("btn-primary"),
              "#{file} should use bg-primary for primary buttons"
          end
        end
      end
    end
  end
end
```

### Phase 3: Dynamic/Compiled Toggle (Week 3)

**Goal:** Add ability to "pin" a palette for production performance.

**Database migration:**

```ruby
# db/migrate/xxx_add_palette_mode_to_websites.rb
class AddPaletteModeToWebsites < ActiveRecord::Migration[7.1]
  def change
    add_column :pwb_websites, :palette_mode, :string, default: "dynamic"
    add_column :pwb_websites, :compiled_palette_css, :text
    add_column :pwb_websites, :palette_compiled_at, :datetime

    add_index :pwb_websites, :palette_mode
  end
end
```

**Model changes:**

```ruby
# app/models/concerns/pwb/website_styleable.rb
module Pwb::WebsiteStyleable
  extend ActiveSupport::Concern

  PALETTE_MODES = %w[dynamic compiled].freeze

  included do
    validates :palette_mode, inclusion: { in: PALETTE_MODES }
  end

  def palette_dynamic?
    palette_mode == "dynamic"
  end

  def palette_compiled?
    palette_mode == "compiled"
  end

  def compile_palette!
    css = generate_compiled_palette_css
    update!(
      palette_mode: "compiled",
      compiled_palette_css: css,
      palette_compiled_at: Time.current
    )
  end

  def unpin_palette!
    update!(
      palette_mode: "dynamic",
      compiled_palette_css: nil,
      palette_compiled_at: nil
    )
  end

  def palette_stale?
    return false unless palette_compiled?
    return true if compiled_palette_css.blank?

    # Check if style_variables changed since compilation
    palette_compiled_at < updated_at
  end

  private

  def generate_compiled_palette_css
    Pwb::PaletteCompiler.new(self).compile
  end
end
```

**Compiler service:**

```ruby
# app/services/pwb/palette_compiler.rb
module Pwb
  class PaletteCompiler
    def initialize(website)
      @website = website
      @vars = website.style_variables
    end

    def compile
      <<~CSS
        /* Compiled palette for #{@website.subdomain} */
        /* Generated: #{Time.current.iso8601} */
        /* Palette: #{@website.selected_palette} */

        :root {
          #{compile_color_variables}
        }

        #{compile_semantic_utilities}
      CSS
    end

    private

    def compile_color_variables
      colors = {
        "--pwb-primary" => @vars["primary_color"],
        "--pwb-primary-light" => lighten(@vars["primary_color"], 30),
        "--pwb-primary-dark" => darken(@vars["primary_color"], 30),
        "--pwb-secondary" => @vars["secondary_color"],
        "--pwb-accent" => @vars["accent_color"],
        # ... more variables
      }

      colors.map { |k, v| "#{k}: #{v};" }.join("\n  ")
    end

    def compile_semantic_utilities
      # Bake actual colors into utility classes
      <<~CSS
        .bg-primary { background-color: #{@vars["primary_color"]}; }
        .bg-primary-600 { background-color: #{darken(@vars["primary_color"], 15)}; }
        .bg-primary-700 { background-color: #{darken(@vars["primary_color"], 30)}; }
        .text-primary { color: #{@vars["primary_color"]}; }
        .hover\\:bg-primary-600:hover { background-color: #{darken(@vars["primary_color"], 15)}; }
        /* ... more utilities ... */
      CSS
    end

    def lighten(hex, percent)
      Pwb::ColorUtils.lighten(hex, percent)
    end

    def darken(hex, percent)
      Pwb::ColorUtils.darken(hex, percent)
    end
  end
end
```

**Layout integration:**

```erb
<!-- app/themes/default/views/layouts/pwb/application.html.erb -->
<head>
  <!-- ... other head content ... -->

  <% if @current_website.palette_compiled? && @current_website.compiled_palette_css.present? %>
    <%# Use pre-compiled CSS for maximum performance %>
    <style id="pwb-compiled-palette">
      <%= @current_website.compiled_palette_css.html_safe %>
    </style>
  <% else %>
    <%# Use dynamic CSS variables %>
    <style id="pwb-dynamic-palette">
      <%= render partial: 'pwb/custom_css/base_variables' %>
      <%= custom_styles(@current_website.theme_name) %>
    </style>
  <% end %>
</head>
```

**Tests:**

```ruby
# spec/models/pwb/website_palette_mode_spec.rb
RSpec.describe Pwb::Website, "palette mode" do
  let(:website) { create(:website, palette_mode: "dynamic") }

  describe "#compile_palette!" do
    it "generates compiled CSS" do
      website.compile_palette!

      expect(website.palette_mode).to eq("compiled")
      expect(website.compiled_palette_css).to be_present
      expect(website.palette_compiled_at).to be_present
    end

    it "includes actual color values" do
      website.style_variables["primary_color"] = "#DC2626"
      website.compile_palette!

      expect(website.compiled_palette_css).to include("#DC2626")
      expect(website.compiled_palette_css).to include(".bg-primary")
    end
  end

  describe "#unpin_palette!" do
    before { website.compile_palette! }

    it "reverts to dynamic mode" do
      website.unpin_palette!

      expect(website.palette_mode).to eq("dynamic")
      expect(website.compiled_palette_css).to be_nil
    end
  end

  describe "#palette_stale?" do
    it "returns true when style_variables changed after compilation" do
      website.compile_palette!
      website.update!(style_variables: website.style_variables.merge("primary_color" => "#FF0000"))

      expect(website.palette_stale?).to be true
    end
  end
end

# spec/services/pwb/palette_compiler_spec.rb
RSpec.describe Pwb::PaletteCompiler do
  let(:website) do
    build(:website, style_variables: {
      "primary_color" => "#DC2626",
      "secondary_color" => "#1F2937",
      "accent_color" => "#F59E0B"
    })
  end

  subject { described_class.new(website) }

  describe "#compile" do
    it "generates valid CSS" do
      css = subject.compile

      expect(css).to be_valid_css
    end

    it "includes all semantic utility classes" do
      css = subject.compile

      expect(css).to include(".bg-primary")
      expect(css).to include(".bg-primary-600")
      expect(css).to include(".text-primary")
      expect(css).to include(".hover\\:bg-primary-600:hover")
    end

    it "uses actual color values, not variables" do
      css = subject.compile

      # In compiled mode, we want actual hex values
      expect(css).to include("background-color: #DC2626")
      expect(css).not_to include("var(--pwb-primary)")
    end
  end
end
```

### Phase 4: Admin UI (Week 4)

**Goal:** Add UI for switching between dynamic/compiled modes.

**Admin controller:**

```ruby
# app/controllers/admin/palette_controller.rb
class Admin::PaletteController < Admin::BaseController
  def show
    @website = current_website
    @palettes = @website.current_theme.palettes
    @current_palette = @website.effective_palette_id
  end

  def preview
    @website = current_website
    @preview_palette = params[:palette_id]

    # Temporarily apply palette for preview
    @preview_style_variables = @website.current_theme.palette_colors(@preview_palette)

    render layout: false
  end

  def apply
    @website = current_website
    @website.apply_palette!(params[:palette_id])

    redirect_to admin_palette_path, notice: "Palette applied successfully"
  end

  def compile
    @website = current_website
    @website.compile_palette!

    redirect_to admin_palette_path, notice: "Palette compiled for production"
  end

  def unpin
    @website = current_website
    @website.unpin_palette!

    redirect_to admin_palette_path, notice: "Palette unpinned - now in dynamic mode"
  end
end
```

**Admin view:**

```erb
<!-- app/views/admin/palette/show.html.erb -->
<div class="p-6">
  <h1 class="text-2xl font-bold mb-6">Color Palette Settings</h1>

  <!-- Current Mode Indicator -->
  <div class="mb-8 p-4 rounded-lg <%= @website.palette_compiled? ? 'bg-green-100' : 'bg-blue-100' %>">
    <div class="flex items-center justify-between">
      <div>
        <span class="font-semibold">
          Mode: <%= @website.palette_mode.titleize %>
        </span>
        <% if @website.palette_compiled? %>
          <p class="text-sm text-gray-600">
            Compiled at: <%= @website.palette_compiled_at&.strftime("%B %d, %Y %H:%M") %>
          </p>
          <% if @website.palette_stale? %>
            <p class="text-sm text-orange-600 font-medium">
              Warning: Palette has been modified since compilation
            </p>
          <% end %>
        <% else %>
          <p class="text-sm text-gray-600">
            Colors update in real-time as you make changes
          </p>
        <% end %>
      </div>

      <div class="space-x-2">
        <% if @website.palette_compiled? %>
          <%= button_to "Unpin (Dynamic Mode)", unpin_admin_palette_path,
              method: :post, class: "btn btn-secondary" %>
          <% if @website.palette_stale? %>
            <%= button_to "Recompile", compile_admin_palette_path,
                method: :post, class: "btn btn-primary" %>
          <% end %>
        <% else %>
          <%= button_to "Compile for Production", compile_admin_palette_path,
              method: :post, class: "btn btn-primary",
              data: { confirm: "This will lock the current colors for optimal performance. You can unpin later to make changes." } %>
        <% end %>
      </div>
    </div>
  </div>

  <!-- Palette Selection -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
    <% @palettes.each do |palette_id, palette| %>
      <div class="border rounded-lg overflow-hidden <%= @current_palette == palette_id ? 'ring-2 ring-primary' : '' %>">
        <!-- Palette Preview -->
        <div class="h-24 flex">
          <% palette["preview_colors"]&.each do |color| %>
            <div class="flex-1" style="background-color: <%= color %>"></div>
          <% end %>
        </div>

        <div class="p-4">
          <h3 class="font-semibold"><%= palette["name"] %></h3>
          <p class="text-sm text-gray-600"><%= palette["description"] %></p>

          <div class="mt-4 space-x-2">
            <%= link_to "Preview", preview_admin_palette_path(palette_id: palette_id),
                class: "btn btn-sm btn-secondary", data: { turbo_frame: "preview-frame" } %>

            <% unless @current_palette == palette_id %>
              <%= button_to "Apply", apply_admin_palette_path(palette_id: palette_id),
                  method: :post, class: "btn btn-sm btn-primary" %>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Live Preview Frame -->
  <turbo-frame id="preview-frame" class="mt-8">
    <!-- Preview loads here -->
  </turbo-frame>
</div>
```

---

## Alternative: Pre-compiled Palette Variants

If the hybrid approach proves insufficient, here's a fallback for pre-compiling theme+palette combinations:

### Build Script

```javascript
// scripts/compile-palette-variants.js
const palettes = require('../app/themes/default/palettes');
const themes = ['default', 'brisbane', 'bologna'];

async function compileAllVariants() {
  for (const theme of themes) {
    const themePalettes = require(`../app/themes/${theme}/palettes`);

    for (const [paletteId, palette] of Object.entries(themePalettes)) {
      const inputFile = `app/assets/stylesheets/tailwind-${theme}.css`;
      const outputFile = `app/assets/builds/tailwind-${theme}-${paletteId}.css`;

      // Generate CSS variables for this palette
      const cssVars = generateCssVariables(palette.colors);

      // Compile with PostCSS
      await compileWithVariables(inputFile, outputFile, cssVars);
    }
  }
}

function generateCssVariables(colors) {
  return Object.entries(colors)
    .map(([key, value]) => `--${key.replace(/_/g, '-')}: ${value};`)
    .join('\n');
}
```

### Serving Pre-compiled Variants

```ruby
# In layout
def tailwind_stylesheet_for_website
  if @current_website.palette_compiled?
    theme = @current_website.theme_name
    palette = @current_website.selected_palette
    "tailwind-#{theme}-#{palette}"
  else
    "tailwind-#{@current_website.theme_name}"
  end
end
```

```erb
<%= stylesheet_link_tag tailwind_stylesheet_for_website, "data-turbo-track": "reload" %>
```

---

## Testing Strategy

### Unit Tests

```ruby
# spec/services/pwb/palette_compiler_spec.rb
# spec/models/concerns/pwb/website_styleable_spec.rb
# spec/helpers/pwb/palette_helper_spec.rb
```

### Integration Tests

```ruby
# spec/features/admin/palette_management_spec.rb
RSpec.describe "Palette Management", type: :feature do
  let(:admin) { create(:admin) }
  let(:website) { create(:website) }

  before { sign_in admin }

  scenario "Admin changes palette and sees live preview" do
    visit admin_palette_path

    click_link "Preview", match: :first

    within("#preview-frame") do
      expect(page).to have_css(".bg-primary")
    end
  end

  scenario "Admin compiles palette for production" do
    visit admin_palette_path

    click_button "Compile for Production"

    expect(page).to have_text("Mode: Compiled")
    expect(website.reload.palette_mode).to eq("compiled")
  end
end
```

### Visual Regression Tests

```javascript
// tests/e2e/palette-visual.spec.js
const { test, expect } = require('@playwright/test');

test.describe('Palette Colors', () => {
  test('primary button uses palette primary color', async ({ page }) => {
    await page.goto('/');

    const button = page.locator('button.bg-primary').first();
    const bgColor = await button.evaluate(el =>
      getComputedStyle(el).backgroundColor
    );

    // Should be the red from Classic Red palette
    expect(bgColor).toBe('rgb(220, 38, 38)');
  });

  test('palette change updates button color', async ({ page }) => {
    // Apply Ocean Blue palette
    await page.goto('/admin/palette');
    await page.click('[data-palette="ocean_blue"] button:has-text("Apply")');

    await page.goto('/');

    const button = page.locator('button.bg-primary').first();
    const bgColor = await button.evaluate(el =>
      getComputedStyle(el).backgroundColor
    );

    // Should be blue from Ocean Blue palette
    expect(bgColor).toBe('rgb(52, 152, 219)');
  });
});
```

---

## Performance Benchmarks

### Metrics to Track

| Metric | Dynamic Mode Target | Compiled Mode Target |
|--------|---------------------|---------------------|
| CSS Parse Time | < 50ms | < 30ms |
| First Contentful Paint | < 1.5s | < 1.2s |
| Largest Contentful Paint | < 2.5s | < 2.0s |
| Total CSS Size (gzipped) | < 80KB | < 60KB |

### Benchmark Script

```ruby
# lib/tasks/benchmark_palette.rake
namespace :palette do
  desc "Benchmark palette rendering modes"
  task benchmark: :environment do
    require 'benchmark'

    website = Pwb::Website.first

    Benchmark.bm(20) do |x|
      x.report("Dynamic CSS gen:") do
        100.times { website.generate_dynamic_css }
      end

      x.report("Compiled CSS:") do
        website.compile_palette!
        100.times { website.compiled_palette_css }
      end
    end
  end
end
```

---

## Rollout Plan

### Week 1: Foundation
- [ ] Add semantic color utilities to Tailwind input files
- [ ] Rebuild Tailwind CSS for all themes
- [ ] Write unit tests for new utilities

### Week 2: Template Migration
- [ ] Create migration script to identify hardcoded colors
- [ ] Update high-priority templates (buttons, links, CTAs)
- [ ] Update remaining templates
- [ ] Run visual regression tests

### Week 3: Mode Toggle
- [ ] Add database migration for palette_mode
- [ ] Implement PaletteCompiler service
- [ ] Add compile/unpin methods to Website model
- [ ] Integration tests

### Week 4: Admin UI & Polish
- [ ] Build admin palette management UI
- [ ] Add live preview functionality
- [ ] Performance benchmarking
- [ ] Documentation

---

## Summary

**Recommended approach:** Hybrid (Option D) with dynamic/compiled toggle.

**Benefits:**
- Immediate experimentation in dynamic mode
- Production-grade performance when compiled
- Single Tailwind build (no combinatorial explosion)
- Semantic, readable class names
- Backward compatible with existing templates

**Trade-offs:**
- Requires template migration effort
- New semantic classes to learn
- Two code paths (dynamic vs compiled)

**Estimated effort:** 4 weeks for complete implementation.

---

*Document created: 2025-12-29*
*Author: Claude Code*
