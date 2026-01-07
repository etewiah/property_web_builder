# PropertyWebBuilder Page Rendering Pipeline Diagrams

## Current Dynamic Rendering Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          HTTP Request                                   │
│                      GET /pages/:page_slug                              │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      PagesController#show_page                          │
│                                                                         │
│  1. Find Page by slug                                                  │
│  2. Load all ordered_visible_page_contents                             │
│  3. Extract content for each page_content:                             │
│     - if is_rails_part? → render partial later                         │
│     - else → get content.raw (pre-rendered HTML)                       │
│  4. Set cache headers (10 min public, 1 hour stale)                    │
│  5. Call render "/pwb/pages/show"                                      │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              Theme Template: /app/themes/{theme}/pages/show.html.erb    │
│                                                                         │
│  <% page_title @page.page_title %>                                     │
│  <!-- Header section -->                                               │
│  <% @page_contents_for_edit.each_with_index do |page_content, i| %>   │
│    <% if page_content.is_rails_part %>                                 │
│      <%= render partial: "pwb/components/#{page_content.page_part_key}"
│    <% else %>                                                           │
│      <%== @content_to_show[i] %>  ← Renders pre-rendered HTML          │
│    <% end %>                                                            │
│  <% end %>                                                              │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        HTML Response Sent to Browser                    │
│                    Cached by browser (10 min max-age)                  │
│                    CDN can use stale-while-revalidate                  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Page Content Structure

```
┌──────────────────────────────────────────────────────────────────┐
│                         Website                                  │
├──────────────────────────────────────────────────────────────────┤
│ • theme_name                                                     │
│ • provisioning_state                                             │
│ • palette_mode: "dynamic" | "compiled"                           │
│ • compiled_palette_css (PaletteCompiler output)                 │
└───┬────────────────────────────┬────────────────────────────┬────┘
    │                            │                            │
    │ has_many :pages            │ has_many :page_parts       │ has_many :page_contents
    │                            │                            │
    ▼                            ▼                            ▼
┌───────────────────┐    ┌──────────────────┐    ┌────────────────────┐
│      Page         │    │    PagePart      │    │   PageContent      │
├───────────────────┤    ├──────────────────┤    ├────────────────────┤
│ • slug: "home"    │    │ • page_part_key  │    │ • page_id (FK)     │
│ • page_title      │    │ • page_slug      │    │ • content_id (FK)  │
│ • visible: true   │    │ • template       │    │ • is_rails_part    │
│ • seo_title       │    │ • block_contents │    │ • visible_on_page  │
│ • meta_description│    │   (JSON)         │    │ • sort_order       │
└────────┬──────────┘    │                  │    └────────┬───────────┘
         │               │ Example:         │             │
         │               │ {                │             │ has_one :content
         │               │   "en": {        │             │
         │               │     "blocks": {  │             ▼
         │               │       "title":   │        ┌──────────────┐
         │               │         "Hero"   │        │   Content    │
         │               │     }            │        ├──────────────┤
         │               │   }              │        │ • key        │
         │               │ }                │        │ • raw        │ ← Pre-rendered HTML
         └───────────────┘                  │        │   (Liquid)   │   OR
                                            │        │ (Mobility)   │   Liquid template
                                            │        │              │
                                            │        • translations │
                                            │          (JSONB)     │
                                            └──────────────────────┘
                                                   │
                                                   │ has_many
                                                   ▼
                                            ┌──────────────────┐
                                            │  ContentPhoto    │
                                            ├──────────────────┤
                                            │ • image          │
                                            │ • block_key      │
                                            └──────────────────┘
```

---

## Liquid Template Rendering Flow

```
┌────────────────────────────────────────────────────────────────┐
│                      PagePart Instance                         │
│                                                                │
│  page_part_key: "heroes/hero_centered"                        │
│  template: "Liquid source code..."                            │
│  block_contents: {                                            │
│    "en": {                                                    │
│      "blocks": {                                              │
│        "title": { "content": "Welcome!" },                    │
│        "subtitle": { "content": "Find your home" },           │
│        "cta_text": { "content": "Search" }                    │
│      }                                                        │
│    }                                                          │
│  }                                                            │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ 1. Load template_content (from DB or file)
             │    - Check DB first (highest priority)
             │    - Check /app/themes/{theme}/page_parts/{key}.liquid
             │    - Check /app/views/pwb/page_parts/{key}.liquid
             │
             ▼
┌────────────────────────────────────────────────────────────────┐
│  app/views/pwb/page_parts/heroes/hero_centered.liquid:        │
│                                                                │
│  <section class="hero">                                       │
│    <h1>{{ page_part["title"]["content"] }}</h1>              │
│    <p>{{ page_part["subtitle"]["content"] }}</p>             │
│    <a href="/search">{{ page_part["cta_text"]["content"] }} │
│  </section>                                                   │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ 2. Parse Liquid template
             │
             ▼
┌────────────────────────────────────────────────────────────────┐
│  liquid_template = Liquid::Template.parse(template_content)   │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ 3. Render with data
             │
             ▼
┌────────────────────────────────────────────────────────────────┐
│  html = liquid_template.render(                               │
│    "page_part" => block_contents["en"]["blocks"],             │
│    registers: { :view => view, :locale => :en, ... }         │
│  )                                                             │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ 4. Custom filters/tags applied:
             │    • {{ "home" | material_icon }}
             │    • {{ "/search" | localize_url }}
             │    • {% page_part "nested/key" %}
             │
             ▼
┌────────────────────────────────────────────────────────────────┐
│  Rendered HTML:                                                │
│                                                                │
│  <section class="hero">                                       │
│    <h1>Welcome!</h1>                                          │
│    <p>Find your home</p>                                      │
│    <a href="/en/search">Search</a>                            │
│  </section>                                                   │
└────────────────────────────────────────────────────────────────┘
```

---

## Proposed Locked Website Rendering Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          HTTP Request                                   │
│                      GET /pages/:page_slug                              │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      PagesController#show_page                          │
│                                                                         │
│  if @current_website.locked_mode?                                       │
│    compiled_page = CompiledPage.find_by(                               │
│      website_id: @current_website.id,                                   │
│      page_slug: params[:page_slug],                                     │
│      locale: I18n.locale.to_s                                           │
│    )                                                                    │
│                                                                         │
│    if compiled_page                                                     │
│      → Set aggressive cache headers (30 days)                           │
│      → Render inline: compiled_page.compiled_html                       │
│      → DONE ✓ (No DB queries, no rendering)                            │
│    end                                                                  │
│  end                                                                    │
│                                                                         │
│  # Fall back to dynamic rendering if not found                         │
│  # (existing logic)                                                    │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ├─ Locked? Has compiled version?
             │  ├─ YES ─→ ┌────────────────────┐
             │  │         │ Return compiled    │
             │  │         │ HTML immediately  │
             │  │         │ Cache: 30 days    │
             │  │         └────────┬───────────┘
             │  │                  │
             │  │                  ▼ [FAST PATH - No rendering]
             │  │          HTML Response
             │  │
             │  └─ NO ─→ Use dynamic rendering (existing code)
             │           HTML Response
             │
             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        HTML Response to Browser                         │
│                                                                         │
│  If Locked:                          If Dynamic:                       │
│  • Cache-Control: public,            • Cache-Control: public,          │
│    max-age=2592000 (30 days)          max-age=600 (10 min)             │
│  • ETag based on compiled_page       • ETag based on page.updated_at   │
│  • Served from Rails cache           • May be cached by CDN            │
│    or directly from compiled_html    • Varies with locale              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Website Lock State Machine

```
                    ┌─────────────────┐
                    │   UNLOCKED      │ ← Default state
                    │  (Dynamic)      │
                    └────────┬────────┘
                             │
                             │ Admin clicks "Lock Website"
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  PageCompiler.compile_all_pages        │
        │                                        │
        │  For each page:                        │
        │  ├─ Render with all translations      │
        │  ├─ Store in CompiledPage table       │
        │  ├─ Mark as locked                    │
        │  └─ Set cache headers                 │
        │                                        │
        │  For each page_content:                │
        │  ├─ If is_rails_part                  │
        │  │  └─ Can't compile (skip/disable)   │
        │  └─ If Liquid                         │
        │     └─ Render and store               │
        └──────────┬─────────────────────────────┘
                   │
                   ▼
        ┌────────────────────┐
        │  website.locked_   │
        │  mode = true       │
        │  updated_at = now  │
        └────────┬───────────┘
                 │
                 ▼
        ┌─────────────────────────────────────┐
        │        LOCKED (Compiled)            │
        │   • No content changes allowed      │
        │   • Serve pre-compiled HTML         │
        │   • Aggressive caching (30 days)    │
        │   • Fast response times             │
        └────────┬────────────────────────────┘
                 │
                 │ Admin clicks "Unlock Website"
                 │ (or calls unlock_website API)
                 │
                 ▼
        ┌─────────────────────────────────────┐
        │  CompiledPage.where(              │
        │    website_id: id                   │
        │  ).delete_all                       │
        │                                     │
        │  website.locked_mode = false        │
        └────────┬────────────────────────────┘
                 │
                 ▼
        ┌─────────────────────────────────────┐
        │  UNLOCKED (Back to Dynamic)         │
        │                                     │
        │  • Content changes re-enabled       │
        │  • Cache headers reset to default   │
        │  • Dynamic rendering resumes        │
        └─────────────────────────────────────┘
```

---

## Comparison: PaletteCompiler (Existing) vs PageCompiler (Proposed)

```
┌──────────────────────────────────────────────────────────────────────┐
│                         PaletteCompiler (CSS)                        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Input:  website.style_variables                                    │
│  ├─ primary_color: "#3b82f6"                                        │
│  ├─ secondary_color: "#64748b"                                      │
│  └─ accent_color: "#f59e0b"                                         │
│                                                                      │
│  Process:                                                           │
│  ├─ Generate color shades (50-900)                                  │
│  ├─ Create CSS variables                                            │
│  ├─ Create utility classes (.bg-primary, .text-primary, etc)        │
│  └─ Combine with semantic utilities                                 │
│                                                                      │
│  Output: CSS string (~5-10 KB)                                      │
│  Storage: website.compiled_palette_css (text column)                │
│                                                                      │
│  Usage:                                                             │
│  ├─ if website.palette_mode == "compiled"                           │
│  │  └─ return website.compiled_palette_css                          │
│  └─ else                                                            │
│     └─ return dynamic CSS                                           │
│                                                                      │
│  Toggle:                                                            │
│  ├─ website.palette_mode = "compiled"                               │
│  ├─ website.compiled_palette_css = compiler.compile                 │
│  └─ website.save!                                                   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

                              ↓ ↓ ↓

┌──────────────────────────────────────────────────────────────────────┐
│                      PageCompiler (HTML) [PROPOSED]                  │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Input:  website.pages (all visible pages)                          │
│  ├─ Page 1: "home"                                                  │
│  ├─ Page 2: "about"                                                 │
│  └─ Page N: ...                                                     │
│                                                                      │
│  Process:                                                           │
│  ├─ For each page:                                                  │
│  │  ├─ For each locale (en, es, fr, ...):                           │
│  │  │  ├─ Simulate PagesController rendering                        │
│  │  │  ├─ Render all Liquid templates with block_contents           │
│  │  │  ├─ Skip/placeholder Rails parts                              │
│  │  │  ├─ Apply theme view                                          │
│  │  │  ├─ Store in CompiledPage table                               │
│  │  │  └─ Update metadata (title, seo, etc)                         │
│  │  └─ end                                                          │
│  └─ end                                                             │
│                                                                      │
│  Output: Full HTML strings (per page, per locale)                   │
│  Storage: pwb_compiled_pages table                                  │
│  └─ Columns:                                                        │
│     ├─ website_id, page_slug, locale                                │
│     ├─ compiled_html (text, ~50-500 KB per page)                    │
│     └─ metadata (JSON: title, seo, cta_links, etc)                  │
│                                                                      │
│  Usage:                                                             │
│  ├─ if website.locked_mode?                                         │
│  │  └─ return CompiledPage.find_by(...).compiled_html               │
│  └─ else                                                            │
│     └─ use dynamic rendering                                        │
│                                                                      │
│  Toggle:                                                            │
│  ├─ website.lock_website                                            │
│  │  └─ PageCompiler.new(website).compile_all_pages                  │
│  │     └─ website.locked_mode = true                                │
│  └─ website.unlock_website                                          │
│     └─ CompiledPage.where(website_id: id).delete_all                │
│        └─ website.locked_mode = false                               │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: Compilation Service

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   admin.lock_website("website_slug")                     │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Pwb::PageCompiler.new(website)                       │
│                           .compile_all_pages                            │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ▼
     ┌───────────────────┐
     │ Find all pages    │
     │ WHERE visible=true│
     └─────────┬─────────┘
               │
               ├─ Page: "home" ─────┐
               ├─ Page: "about" ────┤
               ├─ Page: "contact" ──┤
               └─ Page: "team" ─────┤
                                    │
                                    ▼ For each page
                            ┌───────────────────┐
                            │ For each locale   │
                            │ (en, es, fr, ...) │
                            └─────────┬─────────┘
                                      │
                                      ├─ Locale: "en" ──┐
                                      ├─ Locale: "es" ──┤
                                      └─ Locale: "fr" ──┤
                                                        │
                                                        ▼
                            ┌─────────────────────────────────────┐
                            │ I18n.with_locale(locale) do         │
                            │   render_page(page)                 │
                            │ end                                 │
                            └──────────┬────────────────────────────┘
                                       │
                                       ▼
                            ┌─────────────────────────────────────┐
                            │ For each PageContent:               │
                            │                                     │
                            │ ├─ is_rails_part?                  │
                            │ │  └─ SKIP (can't compile)          │
                            │ │     or render placeholder         │
                            │ │                                   │
                            │ └─ else                             │
                            │    └─ Get content.raw (HTML)        │
                            │       Add to page_html              │
                            └──────────┬────────────────────────────┘
                                       │
                                       ▼
                            ┌─────────────────────────────────────┐
                            │ Render theme template:              │
                            │                                     │
                            │ /app/themes/{theme}/pages/show.html │
                            │   └─ with all content inline        │
                            │                                     │
                            │ Result: Full HTML page              │
                            └──────────┬────────────────────────────┘
                                       │
                                       ▼
                            ┌─────────────────────────────────────┐
                            │ Store in CompiledPage:              │
                            │                                     │
                            │ {                                   │
                            │   website_id: 123,                  │
                            │   page_slug: "home",                │
                            │   locale: "en",                     │
                            │   compiled_html: "<html>...",       │
                            │   metadata: {                       │
                            │     title: "Home",                  │
                            │     seo_title: "...",               │
                            │     meta_description: "..."         │
                            │   }                                 │
                            │ }                                   │
                            └──────────┬────────────────────────────┘
                                       │
                                       ▼
                            ┌─────────────────────────────────────┐
                            │ All pages compiled                  │
                            │ for all locales                     │
                            └──────────┬────────────────────────────┘
                                       │
                                       ▼
                    ┌──────────────────────────────────┐
                    │ website.locked_mode = true       │
                    │ website.locked_pages_updated_at  │
                    │   = Time.current                 │
                    │ website.save!                    │
                    └──────────────────────────────────┘
                                       │
                                       ▼
                    ┌──────────────────────────────────┐
                    │ Website is now LOCKED            │
                    │ Requests serve compiled HTML     │
                    │ No more DB queries on show_page  │
                    └──────────────────────────────────┘
```

---

## Cache Performance Comparison

```
Dynamic Rendering (Current):
┌────────────────────────────────────────────────┐
│ Request 1 (cold):      100ms (full render)    │
│ Request 2 (hot):        20ms (cached DB)      │
│ Request 3 (expired):   100ms (re-render)      │
│ Average per request:    ~40ms                 │
└────────────────────────────────────────────────┘

Locked (Pre-compiled):
┌────────────────────────────────────────────────┐
│ Request 1:              5ms (from DB)          │
│ Request 2:              5ms (from DB cache)    │
│ Request 3 (CDN hit):    0ms (served by edge)   │
│ Average per request:    ~2ms                  │
│                                               │
│ Benefit: 20x faster response times            │
└────────────────────────────────────────────────┘
```

---

## Key Architectural Principles

```
1. SEPARATION OF CONCERNS
   ├─ Compilation (one-time, off-request)
   ├─ Storage (CompiledPage table)
   └─ Serving (fast, simple lookup)

2. BACKWARDS COMPATIBILITY
   ├─ Existing dynamic rendering still works
   ├─ Locking is opt-in
   └─ Can unlock and return to dynamic

3. MULTI-TENANCY SAFETY
   ├─ Compilation per website
   ├─ Respects website.database_shard
   └─ No cross-tenant data leakage

4. FLEXIBILITY
   ├─ Can lock individual pages
   ├─ Can vary by locale
   └─ Can keep Rails parts dynamic

5. PRECEDENT-BASED
   ├─ Follows PaletteCompiler pattern
   ├─ Minimal new code
   └─ Uses existing patterns
```
