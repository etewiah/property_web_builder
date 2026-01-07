# Website Locking / Pre-Compilation Architecture Investigation

**Date:** January 7, 2026  
**Purpose:** Understand PropertyWebBuilder's rendering architecture to plan a website locking feature where main pages get pre-compiled and no longer have dynamic sections.

---

## Executive Summary

PropertyWebBuilder has a **highly modular, Liquid template-driven page rendering system**. To implement website locking with pre-compilation, we would:

1. **Add a `locked_mode` field** to Website model to indicate a website is "frozen"
2. **Create a compilation service** that captures all page content, renders Liquid templates, and stores static HTML
3. **Add a pre-compiled HTML fallback** in the page controllers 
4. **Maintain read-only access** for locked websites while preventing any content changes
5. **Keep the existing rendering pipeline** intact (no major architectural changes)

The existing **PaletteCompiler** service provides a perfect precedent for this pattern.

---

## 1. Current Page Rendering Flow

### 1.1 Welcome/Home Page Rendering
**File:** `/app/controllers/pwb/welcome_controller.rb`

```ruby
def index
  @page = @current_website.pages.find_by_slug "home"
  @properties_for_sale = @current_website.listed_properties.for_sale.visible...
  @properties_for_rent = @current_website.listed_properties.for_rent.visible...
  render "pwb/welcome/index"
end
```

**Key Points:**
- Fetches dynamic properties from DB (for_sale, for_rent, limited to 9 each)
- These are **always current** - tied to property visibility/highlighting status
- Passes data to theme-specific ERB view

### 1.2 Generic Page Rendering
**File:** `/app/controllers/pwb/pages_controller.rb`

```ruby
def show_page
  @page = @current_website.pages.find_by_slug page_slug
  @content_to_show = []
  @page_contents_for_edit = []
  
  @page.ordered_visible_page_contents.each do |page_content|
    if page_content.is_rails_part
      # Rails partials (dynamic components) - rendered inline
      @content_to_show.push nil
    else
      # Static Liquid template content
      @content_to_show.push page_content.content&.raw
    end
  end
  
  render "/pwb/pages/show"
end
```

**Key Points:**
- Pages contain **PageContent** join models
- Each page content can be:
  - **Rails parts** (dynamic partials like forms, search, maps) - rendered at request time
  - **Liquid templates** (static content) - stored as raw HTML in Content.raw column

### 1.3 Page Structure Model
**Models:**
- **Website** - has_many :pages, :page_contents
- **Page** - has_many :page_contents, :page_parts
- **PageContent** (join model) - links Page → Content, controls visibility & sort order
- **Content** - stores translatable content with Mobility (JSONB)
- **PagePart** - Liquid templates + block_contents (data used to render the template)

### 1.4 Liquid Template Processing
**Files:** 
- `/app/views/pwb/page_parts/*.liquid` - Template definitions
- `/app/lib/pwb/liquid_tags/*.rb` - Custom Liquid tags

**Flow:**
1. PagePart has:
   - `template` (Liquid source, stored in DB or loaded from file)
   - `block_contents` (JSON data used to render the template)
2. Rendering:
   ```ruby
   liquid_template = Liquid::Template.parse(template_content)
   liquid_template.render("page_part" => block_contents)
   ```
3. Custom filters/tags:
   - `material_icon` - renders SVG icons
   - `localize_url` - prepends locale to URLs
   - `page_part` tag - renders nested page parts
   - `featured_properties_tag` - **dynamic** (queries DB for properties)

**Theme-Specific Views:**
- `/app/themes/{theme_name}/views/pwb/pages/show.html.erb` - Renders page parts in a loop
- Example: Barcelona theme loads content with `<%== @content_to_show[index] %>`

---

## 2. Dynamic vs. Static Content

### What's Dynamic (Runtime)
1. **Property listings** - from materialized view `listed_properties`
   - Filtered by visibility, operation type (sale/rent), highlights
   - Used in home page carousel
2. **Search facets** - calculated from property filters
3. **Rails partials** - forms, contact elements, maps, search components
4. **Custom tags** - `featured_properties_tag`, `contact_form_tag`
5. **URL localization** - depends on current locale
6. **Translations** - via Mobility (JSONB)

### What's Static (Compile-able)
1. **Page metadata** - title, slug, SEO info
2. **PagePart content** - block_contents (text, images, links)
3. **Liquid templates** - when rendered with fixed data
4. **Palette CSS** - colors, styles (already has PaletteCompiler!)
5. **Navigation links** - top nav, footer nav
6. **Styling** - theme CSS, raw_css

### What Stays Dynamic (Even Locked)
- Property pages (individual property details) - probably should still be dynamic
- Search functionality - if locked, could redirect to static pages
- Contact forms - might be disabled or static
- Admin panel - never locked

---

## 3. Existing Compilation Pattern: PaletteCompiler

**File:** `/app/services/pwb/palette_compiler.rb`

This service is a **perfect precedent** for what we need:

```ruby
class PaletteCompiler
  def initialize(website)
    @website = website
    @style_vars = website.style_variables || {}
  end

  def compile
    css_lines = []
    css_lines << ":root {"
    css_lines << compile_css_variables
    css_lines << "}"
    css_lines.join("\n")
  end
end

# Usage:
# compiler = Pwb::PaletteCompiler.new(website)
# css = compiler.compile
# website.update!(compiled_palette_css: css, palette_mode: "compiled")
```

**Key Insights:**
- Stores compiled output in a dedicated `compiled_palette_css` column
- Has a `palette_mode` field ("dynamic" vs "compiled")
- Website can toggle between modes
- Called explicitly (not automatic)

**Same Pattern Would Work for Pages:**
- `compiled_html_{page_slug}` columns or separate table
- `page_mode` field ("dynamic" vs "locked")
- Explicit compilation service
- Fallback rendering during request

---

## 4. Website Model Fields & Capabilities

**File:** `/app/models/pwb/website.rb`

Key existing fields:
- `provisioning_state` - AASM state machine (pending → live)
- `palette_mode` - "dynamic" or "compiled"
- `compiled_palette_css` - pre-compiled CSS
- `raw_css` - custom CSS
- `configuration` - JSON with flexible config
- `admin_config` - admin-specific settings

**Existing States (AASM):**
- pending → owner_assigned → agency_created → links_created → field_keys_created → properties_seeded → ready → locked_pending_email_verification → locked_pending_registration → live
- suspended, terminated, failed states

**Could Add:**
- `locked_mode` boolean or enum field
- `locked_pages_snapshot` JSON (stores page slugs that are locked)
- `compiled_pages_updated_at` timestamp
- Separate `CompiledPage` table with columns: website_id, page_slug, compiled_html, locale, created_at

---

## 5. Page Rendering Pipeline Architecture

```
Request → PagesController#show_page
    ↓
Check if website is locked AND page is compiled?
    ↓ Yes           ↓ No
Serve              Load Page → Load PageContents
compiled HTML      ↓
                   Loop through PageContents
                   ├─ Rails part? → Render partial
                   └─ Liquid? → content.raw (already HTML)
                   ↓
                   Render theme template
                   ↓
                   Return HTML
```

**Key Point:** PageContent already stores `content.raw` which is **pre-rendered HTML**, not the Liquid template itself.

So the compilation flow would be:
1. Identify all pages on website
2. For each page, for each page content:
   - If it's a Liquid template (PagePart), render it with its block_contents
   - Store the rendered HTML in Content.raw
   - Mark as "locked"
3. For each page, serialize the entire rendered page to compiled_html
4. Update website.locked_mode = true

---

## 6. HTTP Caching Pattern

**File:** `/app/controllers/concerns/http_cacheable.rb`

PropertyWebBuilder already has sophisticated HTTP caching:

```ruby
module HttpCacheable
  etag { current_website&.id }
  etag { I18n.locale }
  
  def set_cache_control_headers(options = {})
    max_age = options.fetch(:max_age, 5.minutes)
    cache_control << "public" if public_cache
    cache_control << "max-age=#{max_age.to_i}"
    cache_control << "stale-while-revalidate=#{stale_while_revalidate.to_i}"
  end
end
```

**Already Used in PagesController:**
```ruby
set_cache_control_headers(
  max_age: 10.minutes,
  public: true,
  stale_while_revalidate: 1.hour
)
```

**For Locked Pages:** Could be cached much more aggressively
- `max_age: 30.days` or longer
- ETags would be based on compiled_pages_updated_at
- CDN would cache the entire page

---

## 7. Key Files & Dependencies

### Core Models
- **Website** (`/app/models/pwb/website.rb`) - 364 lines
  - Concerns: WebsiteProvisionable, WebsiteStyleable, WebsiteThemeable, DemoWebsite
  - Has `provisioning_state`, `palette_mode`, `compiled_palette_css`

- **Page** (`/app/models/pwb/page.rb`) - 130 lines
  - Has `page_contents`, `page_parts`
  - Translates: raw_html, page_title, link_title (Mobility)

- **PageContent** (`/app/models/pwb/page_content.rb`) - 72 lines
  - Join model: Page ↔ Content
  - Fields: is_rails_part, visible_on_page, sort_order

- **PagePart** (`/app/models/pwb/page_part.rb`) - 102 lines
  - Has `block_contents` (JSON), `template` (Liquid source)
  - Method: `template_content` (loads from DB or file with caching)

- **Content** (`/app/models/pwb/content.rb`) - 119 lines
  - Stores translatable content via Mobility
  - Translates: `raw` (the HTML/Liquid content)

### Controllers
- **PagesController** (`/app/controllers/pwb/pages_controller.rb`) - 125 lines
  - `show_page` - main rendering action
  - `show_page_part` - single part rendering
  - Includes HttpCacheable

- **WelcomeController** (`/app/controllers/pwb/welcome_controller.rb`) - 40 lines
  - `index` - home page with dynamic property carousel

### Services
- **PaletteCompiler** (`/app/services/pwb/palette_compiler.rb`) - 374 lines
  - ✨ Perfect model for what we need!

- **CacheService** (`/app/services/cache_service.rb`) - 155 lines
  - Caches field keys, website config, property counts, navigation links

### Libraries/Tags
- **LiquidFilters** (`/app/lib/pwb/liquid_filters.rb`) - 332 lines
  - material_icon, brand_icon, localize_url

- **PagePartLibrary** (`/app/lib/pwb/page_part_library.rb`) - 332 lines
  - Registry of available page parts with metadata

- **PagePartTag** (`/app/lib/pwb/liquid_tags/page_part_tag.rb`) - 86 lines
  - Allows {% page_part "key" %} in Liquid templates

### Views
- **PagesController views:**
  - `/app/views/pwb/pages/show_page_part.html.erb` - Single part rendering

- **Theme-specific:**
  - `/app/themes/{theme}/views/pwb/pages/show.html.erb`
  - `/app/themes/{theme}/views/pwb/welcome/index.html.erb`

- **Page parts (Liquid):**
  - `/app/views/pwb/page_parts/**/*.liquid` - 20+ templates
  - Organized by category: heroes, features, cta, galleries, etc.

---

## 8. What Would Need to Change

### Database Changes (Migration)
```ruby
class AddWebsiteLockingSupport < ActiveRecord::Migration[7.0]
  def change
    add_column :pwb_websites, :locked_mode, :boolean, default: false
    add_column :pwb_websites, :locked_pages_updated_at, :datetime
    add_index :pwb_websites, :locked_mode
    
    create_table :pwb_compiled_pages do |t|
      t.references :website, foreign_key: { to_table: :pwb_websites }
      t.string :page_slug, null: false
      t.string :locale, default: "en"
      t.text :compiled_html
      t.jsonb :metadata # page_title, seo info, etc.
      t.timestamps
    end
    
    add_index :pwb_compiled_pages, [:website_id, :page_slug, :locale], unique: true
  end
end
```

### New Service: PageCompiler
```ruby
class Pwb::PageCompiler
  def initialize(website)
    @website = website
  end
  
  def compile_all_pages
    @website.pages.where(visible: true).each do |page|
      compile_page(page)
    end
  end
  
  def compile_page(page)
    # For each locale
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        html = render_page(page)
        store_compiled_page(page, html, locale)
      end
    end
  end
  
  private
  
  def render_page(page)
    # Simulate the controller rendering
    content_to_show = []
    page.ordered_visible_page_contents.each do |page_content|
      if page_content.is_rails_part
        # Skip dynamic parts - mark as [DYNAMIC SECTION]
        content_to_show.push nil
      else
        content_to_show.push page_content.content&.raw
      end
    end
    
    # Render the view with compiled content
    # This would need special handling - maybe render via ActionController
    ApplicationController.render(
      template: "/pwb/pages/show",
      assigns: {
        page: page,
        content_to_show: content_to_show,
        page_contents_for_edit: []
      }
    )
  end
  
  def store_compiled_page(page, html, locale)
    Pwb::CompiledPage.upsert({
      website_id: @website.id,
      page_slug: page.slug,
      locale: locale.to_s,
      compiled_html: html,
      metadata: {
        title: page.page_title,
        seo_title: page.seo_title,
        meta_description: page.meta_description
      }
    }, unique_by: [:website_id, :page_slug, :locale])
  end
end
```

### Modified Controller
```ruby
def show_page
  if @current_website.locked_mode? && compiled_page = find_compiled_page
    # Serve pre-compiled HTML with aggressive caching
    set_cache_control_headers(
      max_age: 30.days,
      public: true
    )
    return render inline: compiled_page.compiled_html
  end
  
  # ... existing rendering logic
end

private

def find_compiled_page
  Pwb::CompiledPage.find_by(
    website_id: @current_website.id,
    page_slug: params[:page_slug] || 'home',
    locale: I18n.locale.to_s
  )
end
```

### Prevent Content Changes When Locked
```ruby
class Pwb::PageContent < ApplicationRecord
  validate :validate_not_locked, on: :update
  
  private
  
  def validate_not_locked
    if page.website.locked_mode?
      errors.add(:base, "Cannot modify content on a locked website")
    end
  end
end

class Pwb::PagePart < ApplicationRecord
  validate :validate_not_locked, on: :update
  
  private
  
  def validate_not_locked
    if website.locked_mode?
      errors.add(:base, "Cannot modify page parts on a locked website")
    end
  end
end
```

### Add Locking/Unlocking Events
```ruby
class Pwb::Website < ApplicationRecord
  def lock_website
    PageCompiler.new(self).compile_all_pages
    update!(locked_mode: true, locked_pages_updated_at: Time.current)
  end
  
  def unlock_website
    CompiledPage.where(website_id: id).delete_all
    update!(locked_mode: false)
  end
end
```

---

## 9. Challenges & Gotchas

### 1. Dynamic Rails Partials
**Problem:** Pages with contact forms, search bars, maps, etc. are rendered as Rails partials, not Liquid.

**Solutions:**
- Option A: Skip locking for pages with Rails parts (is_rails_part = true)
- Option B: Disable Rails parts on locked pages (show placeholder like "Contact form unavailable")
- Option C: Render Rails parts ahead of time and embed static HTML

### 2. Translations
**Problem:** Content is translated via Mobility (JSONB).

**Solution:** Compile separately for each locale, store in CompiledPage.locale column

### 3. Multi-Tenancy
**Problem:** Pages exist in single website_id scope, but could be shared across shards.

**Solution:** Compilation happens per website, respects shard boundaries via website.database_shard

### 4. Welcome Page & Home Page
**Problem:** Welcome index pulls dynamic properties (for_sale, for_rent).

**Solutions:**
- Option A: Compile home page but show static/cached property list from last compilation
- Option B: Don't lock home page, only lock other pages
- Option C: Have a "locked property list" - properties shown on locked home page

### 5. Cache Invalidation
**Problem:** How do you update a locked page if content changes?

**Solutions:**
- Don't allow content changes (validation errors)
- Manual recompilation button (admin UI)
- Auto-recompile on admin request
- Schedule periodic recompilation

### 6. SEO & Metadata
**Problem:** Pages have seo_title, meta_description that need to be in <head>.

**Solution:** Store metadata in CompiledPage.metadata JSON, use in layout

### 7. Theme Changes
**Problem:** If theme changes, locked pages might have old styling.

**Solution:** When theme changes, auto-unlock website and require recompilation

---

## 10. Suggested Implementation Path

### Phase 1: Foundation
1. Add `locked_mode` boolean to Website
2. Create `CompiledPage` model
3. Create `PageCompiler` service
4. Modify PagesController to check locked_mode

### Phase 2: Locking UI
1. Add lock/unlock button to admin panel
2. Show "Website is locked" message
3. Prevent content editing when locked
4. Show which pages are compiled

### Phase 3: Feature Completeness
1. Handle Rails parts gracefully
2. Implement per-locale compilation
3. Cache headers optimization
4. Webhook/API for programmatic locking

### Phase 4: Optimization
1. Background job for compilation (sidekiq)
2. Incremental compilation (only changed pages)
3. CDN headers optimization
4. Performance monitoring

---

## 11. Alternative Approaches Considered

### Approach A: Static Site Generator
**Pros:** Full pre-rendering, maximum performance, SEO friendly  
**Cons:** Complete departure from Rails, massive refactor, breaks admin UI

### Approach B: HTTP Caching Only
**Pros:** Simpler, leverages existing HttpCacheable  
**Cons:** Still hits Rails on cache misses, doesn't prevent changes, CDN-dependent

### Approach C: Read Replica + Cache
**Pros:** Database level caching, transaction safety  
**Cons:** Doesn't solve page rendering, infrastructure overhead

### Approach D: Snapshot Serialization
**Pros:** Can serialize all page state as JSON  
**Cons:** Brittle, hard to update individual pages

**Chosen Approach:** Option 1 (PaletteCompiler pattern) is best because:
- Fits existing architecture
- Precedent already in codebase
- Minimal schema changes
- Can be toggled on/off
- Doesn't require infra changes

---

## 12. Questions for Implementation

1. **Home Page Behavior:** Should home page show latest properties even when locked, or use snapshot?
2. **Dynamic Content Whitelist:** Should certain page parts (contact forms) be allowed on locked pages?
3. **Lock Duration:** Should locks expire? Require manual unlock?
4. **Lock Scope:** Lock entire website or per-page?
5. **Performance Baseline:** What response time are we optimizing for?
6. **Admin Access:** Should admins see "live" content even on locked pages, or always see compiled version?
7. **Rollback:** If we unlock, should we keep old compiled HTML or regenerate?

---

## 13. Files to Create/Modify

### New Files
- `app/models/pwb/compiled_page.rb` - Model for stored compiled HTML
- `app/services/pwb/page_compiler.rb` - Compilation service
- `app/views/pwb/admin/websites/_locking_controls.html.erb` - Lock/unlock UI
- `db/migrate/[timestamp]_add_website_locking_support.rb` - Schema changes
- `docs/features/website_locking.md` - Feature documentation

### Modified Files
- `app/models/pwb/website.rb` - Add locked_mode, lock_website, unlock_website methods
- `app/models/pwb/page_content.rb` - Add validation to prevent changes when locked
- `app/models/pwb/page_part.rb` - Add validation to prevent changes when locked
- `app/controllers/pwb/pages_controller.rb` - Check for compiled page and serve it
- `app/controllers/pwb/welcome_controller.rb` - Handle locked home page
- `config/initializers/liquid.rb` - May need to register new Liquid tags/filters

---

## Summary Table

| Aspect | Current | For Locking |
|--------|---------|-------------|
| Rendering | Dynamic (per request) | Compiled + served from DB/cache |
| Page Compilation | PaletteCompiler (CSS only) | PageCompiler (full HTML) |
| Storage | Page/PageContent in DB | CompiledPage table for snapshots |
| Caching | 10 min (public), 1 hour stale | 30+ days when locked |
| Content Updates | Always live | Disabled when locked |
| Architecture | No changes needed | Minimal (compilation service + model) |
| Precedent | PaletteCompiler | Follow same pattern |
| Lock Type | Currently: provisioning_state | New: locked_mode boolean |

---

## Conclusion

PropertyWebBuilder's architecture is **well-suited for website locking with pre-compilation**. The key insight is that:

1. **PageContent already stores rendered HTML** in Content.raw (not raw Liquid)
2. **PaletteCompiler is a perfect precedent** showing how to store compiled output
3. **HTTP caching layer exists** and can be configured more aggressively
4. **Minimal schema changes needed** - just add CompiledPage table and locked_mode flag
5. **Rails partials are the main challenge** but can be handled with placeholders or static rendering

The implementation would be **~1000-1500 lines of new code** with no major architectural changes needed.
