# Hero Image & LCP (Large Contentful Paint) Analysis

## Summary

Found **three hero/banner image templates** in the codebase. All are already optimized with `fetchpriority="high"` and `loading="eager"`, but lack `<link rel="preload">` tags in the document head for LCP optimization.

## Hero Image Templates Located

### 1. Hero Centered (Full-width background image)
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/heroes/hero_centered.liquid`

Renders a full-width hero section with background image above content overlay.

```liquid
<section class="pwb-hero pwb-hero--centered">
  {% if page_part.background_image.content %}
    <img src="{{ page_part.background_image.content }}"
         alt="{{ page_part.title.content | default: 'Hero background' }}"
         class="pwb-hero__bg-image"
         fetchpriority="high"
         decoding="async"
         loading="eager">
  {% endif %}
  <!-- ... content overlay with title, subtitle, CTA buttons ... -->
</section>
```

**Image source:** `page_part.background_image.content`

---

### 2. Hero Split (Side-by-side layout)
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/heroes/hero_split.liquid`

Renders a two-column layout with hero text on left and image on right.

```liquid
<section class="pwb-hero pwb-hero--split">
  <div class="pwb-container">
    <div class="pwb-grid pwb-grid--2col ...">
      <div class="pwb-hero__content">
        <!-- ... text content ... -->
      </div>
      <div class="pwb-hero__media">
        {% if page_part.image.content %}
          <img src="{{ page_part.image.content }}"
               alt="{{ page_part.image_alt.content | default: page_part.title.content }}"
               class="pwb-hero__image"
               fetchpriority="high"
               decoding="async"
               loading="eager">
        {% endif %}
      </div>
    </div>
  </div>
</section>
```

**Image source:** `page_part.image.content`

---

### 3. Hero Search (Full-width with search form overlay)
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/heroes/hero_search.liquid`

Renders a full-width hero with integrated search form overlay.

```liquid
<section class="pwb-hero pwb-hero--search">
  {% if page_part.background_image.content %}
    <img src="{{ page_part.background_image.content }}"
         alt="{{ page_part.title.content | default: 'Hero background' }}"
         class="pwb-hero__bg-image"
         fetchpriority="high"
         decoding="async"
         loading="eager">
  {% endif %}
  <div class="pwb-hero__overlay"></div>
  <!-- ... hero content with search form ... -->
</section>
```

**Image source:** `page_part.background_image.content`

---

## Banner Image Template

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/cta/cta_banner.liquid`

CTA banner without images (text-only, styled background via CSS):

```liquid
<section class="pwb-cta pwb-cta--banner pwb-cta--{{ page_part.style.content | default: 'primary' }}">
  <div class="pwb-container">
    <div class="pwb-cta__content">
      <!-- ... text content and buttons ... -->
    </div>
  </div>
</section>
```

---

## Data Flow & Rendering

### Page Rendering Flow:

1. **Request** → `Pwb::PagesController#show_page`
2. **Data Assembly:**
   - Fetches `@page.ordered_visible_page_contents`
   - For each page content:
     - If `is_rails_part == false`: Content stored in `@content_to_show` array (raw Liquid/HTML)
     - If `is_rails_part == true`: Rendered as Rails partial in view
3. **Template Rendering** → `/pwb/pages/show.html.erb` (theme-specific)
4. **Liquid Template Compilation:**
   - Each page content's `content.raw` contains Liquid template
   - Compiled/rendered by Rails (likely through a Liquid processor)
   - Output as HTML in page

### Template Chain:

```
app/themes/[theme]/views/pwb/pages/show.html.erb
  └─ Iterates: @page_contents_for_edit
      └─ For non-Rails parts: renders raw Liquid from page_content.content.raw
          └─ Liquid templates: app/views/pwb/page_parts/heroes/*.liquid
```

---

## Layout Templates (HTML Head)

Three theme layouts already have preload/preconnect optimization infrastructure:

### Default Theme
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/default/views/layouts/pwb/application.html.erb`

```erb
<!-- Lines 11-13: Preconnect for CDNs -->
<link rel="preconnect" href="https://cdnjs.cloudflare.com" crossorigin>
<link rel="preconnect" href="https://pub-be9416af8a3c406f859765586492c927.r2.dev" crossorigin>
<link rel="dns-prefetch" href="//unpkg.com">

<!-- Lines 19-20: CSS preload with onload pattern -->
<link rel="preload" href="<%= asset_path('tailwind-default.css') %>" as="style" onload="this.onload=null;this.rel='stylesheet'">
<link rel="preload" href="<%= asset_path('pwb/themes/default.css') %>" as="style" onload="this.onload=null;this.rel='stylesheet'">
```

### Bologna & Brisbane Themes
Both themes have similar preload/preconnect infrastructure. See `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/bologna/views/layouts/pwb/application.html.erb` and brisbane variant.

---

## Key Findings for LCP Optimization

### Current State:
- **Hero images already have:**
  - `fetchpriority="high"` - tells browser this is important
  - `loading="eager"` - loads immediately, not lazily
  - `decoding="async"` - non-blocking decode

### What's Missing for LCP:
- **No `<link rel="preload">` tags in HTML head** for hero images
- Cannot preload hero images in `<head>` because:
  1. Hero image URL is dynamic (stored in Content model, rendered by Liquid)
  2. URL not known until page content is compiled
  3. Would need server-side injection into head or dynamic preload in body

### Preload Challenge:
The image URLs come from the database/Liquid templates, so they're not available until after page content is assembled. Cannot use traditional `<link rel="preload">` in the static head.

---

## Potential Solutions for LCP Improvement

### Option 1: Dynamic Head Injection (Recommended)
Add `yield(:page_head)` hook where controllers can inject preload links:

**In controller (`app/controllers/pwb/pages_controller.rb`):**
```ruby
def show_page
  # ... existing code ...
  
  if @page.present?
    # Get first page content (likely hero)
    first_content = @page.ordered_visible_page_contents.first
    if first_content && first_content.page_part_key.include?('hero')
      # Extract image URL from first page content's Liquid template
      # Inject preload into page_head
      hero_image_url = extract_hero_image_url(first_content)
      content_for(:page_head) do
        tag.link(rel: 'preload', as: 'image', href: hero_image_url, fetchpriority: 'high')
      end
    end
  end
end
```

**In layout (already has support):**
All three theme layouts already include: `<%= yield(:page_head) %>`

### Option 2: Inline Dynamic Preload in Body
Add preload link immediately before first hero section in page template.

### Option 3: Service Worker Preloading
Use service worker to preload/cache hero images for repeat visits.

### Option 4: Placeholder/LQIP Strategy
Use low-quality image placeholders to improve perceived performance while main image loads.

---

## Files to Modify for Preload Implementation

1. **Controllers:**
   - `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/pages_controller.rb` - Add logic to inject preload links

2. **Views:**
   - `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/*/views/pwb/pages/show.html.erb` - Can add inline preload for first section

3. **Hero Templates (already optimized):**
   - `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/heroes/hero_centered.liquid`
   - `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/heroes/hero_split.liquid`
   - `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/heroes/hero_search.liquid`

---

## Related Files (Reference Only)

- Page model: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/page.rb`
- Page content model: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/page_content.rb`
- Content model: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/content.rb`

---

## Conclusion

Hero images are already optimized with `fetchpriority="high"` and `loading="eager"`. The next step for LCP improvement is to dynamically preload the hero image URL in the HTML head. This requires extracting the image URL from the first page content section and injecting it via the `yield(:page_head)` hook that's already present in all theme layouts.
