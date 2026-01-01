# Speed Optimization Lessons for PropertyWebBuilder

*Inspired by [crazyfast.website](https://crazyfast.website/) - a demonstration of extreme web performance optimization*

## Overview

This document outlines performance optimization techniques that could differentiate PropertyWebBuilder in the market. The core insight: **speed can be a product feature**, not just a technical metric.

---

## 1. Edge Computing & CDN Strategy

### What They Do
- Cloudflare Workers execute code at 200+ global edge locations
- Response times of ~30ms for dynamic content

### How PWB Can Apply

**Current State:** Static assets served via CDN (R2), but HTML is server-rendered.

**Opportunity:** Cache entire tenant pages at the edge.

```ruby
# config/environments/production.rb

# Enable stale-while-revalidate for tenant public pages
config.action_controller.default_caching_headers = {
  'Cache-Control' => 'public, max-age=60, stale-while-revalidate=3600'
}
```

**Implementation Options:**

| Approach | Complexity | Speed Gain |
|----------|------------|------------|
| Cloudflare Page Rules | Low | 2-3x |
| Cloudflare Workers | Medium | 5-10x |
| Full static generation | High | 10-20x |

---

## 2. Aggressive Asset Caching

### What They Do
- 31-year immutable cache headers
- All assets fingerprinted and cached forever

### How PWB Can Apply

```ruby
# config/environments/production.rb

# Immutable headers for fingerprinted assets
config.public_file_server.headers = {
  'Cache-Control' => 'public, max-age=31536000, immutable'
}
```

```ruby
# config/initializers/assets.rb

# Ensure all assets are fingerprinted
Rails.application.config.assets.digest = true
Rails.application.config.assets.version = '1.0'
```

**Nginx Configuration:**
```nginx
location /assets/ {
  expires max;
  add_header Cache-Control "public, max-age=31536000, immutable";
  gzip_static on;
  brotli_static on;
}
```

---

## 3. Service Worker for Repeat Visits

### What They Do
- Cache-first strategy brings repeat visits to ~4ms
- Entire site available offline

### How PWB Can Apply

Create a service worker for tenant public sites:

```javascript
// public/sw.js

const CACHE_NAME = 'pwb-v1';
const STATIC_ASSETS = [
  '/',
  '/assets/application.css',
  '/assets/application.js',
  '/offline.html'
];

// Install: cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    })
  );
});

// Fetch: cache-first for assets, network-first for HTML
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Cache-first for static assets
  if (url.pathname.startsWith('/assets/')) {
    event.respondWith(
      caches.match(event.request).then((cached) => {
        return cached || fetch(event.request).then((response) => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, clone);
          });
          return response;
        });
      })
    );
    return;
  }

  // Stale-while-revalidate for HTML pages
  event.respondWith(
    caches.match(event.request).then((cached) => {
      const fetchPromise = fetch(event.request).then((response) => {
        const clone = response.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, clone);
        });
        return response;
      });
      return cached || fetchPromise;
    })
  );
});
```

**Registration in layout:**
```erb
<%# app/themes/default/views/layouts/pwb/application.html.erb %>

<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js')
        .then(reg => console.log('SW registered'))
        .catch(err => console.log('SW failed:', err));
    });
  }
</script>
```

---

## 4. Critical CSS Inlining

### What They Do
- All CSS inline (~2.5KB compressed)
- Zero render-blocking external requests

### How PWB Can Apply

For landing pages and property listings, inline critical CSS:

```ruby
# app/helpers/performance_helper.rb

module PerformanceHelper
  def critical_css
    Rails.cache.fetch("critical_css_#{current_website.theme}", expires_in: 1.day) do
      # Extract above-the-fold CSS
      css_path = Rails.root.join("app/themes/#{current_website.theme}/assets/critical.css")
      if File.exist?(css_path)
        "<style>#{File.read(css_path)}</style>".html_safe
      end
    end
  end
end
```

```erb
<%# In layout head %>
<%= critical_css %>
<link rel="preload" href="<%= stylesheet_path('application') %>" as="style" onload="this.onload=null;this.rel='stylesheet'">
<noscript><link rel="stylesheet" href="<%= stylesheet_path('application') %>"></noscript>
```

---

## 5. System Fonts for Speed

### What They Do
- Use system font stack, avoiding font loading delay
- Zero font-related network requests

### How PWB Can Apply

Offer a "Fast Mode" theme option:

```css
/* Fast system font stack */
:root {
  --font-system: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                 Helvetica, Arial, sans-serif, "Apple Color Emoji",
                 "Segoe UI Emoji", "Segoe UI Symbol";
}

body {
  font-family: var(--font-system);
}
```

**Plan-based feature:**
```ruby
# Could be a plan feature
def use_custom_fonts?
  current_website.subscription&.has_feature?('custom_fonts')
end
```

---

## 6. Preconnect & DNS Prefetch

### What They Do
- Minimize connection overhead for required origins

### How PWB Can Apply

```erb
<%# In layout head - preconnect to CDN and analytics %>
<link rel="dns-prefetch" href="//cdn.propertywebbuilder.com">
<link rel="preconnect" href="https://cdn.propertywebbuilder.com" crossorigin>

<%# Preload hero image %>
<% if @hero_image_url.present? %>
  <link rel="preload" href="<%= @hero_image_url %>" as="image">
<% end %>
```

---

## 7. Performance Metrics as Marketing

### What They Do
- Display load time prominently on the page
- Turn speed into the value proposition

### How PWB Can Apply

**Admin Dashboard Widget:**
```erb
<%# app/views/pwb/admin/dashboard/_performance_widget.html.erb %>

<div class="performance-widget">
  <h3>Site Performance</h3>
  <div class="metric">
    <span class="value"><%= @lighthouse_score %></span>
    <span class="label">Lighthouse Score</span>
  </div>
  <div class="metric">
    <span class="value"><%= @avg_load_time %>ms</span>
    <span class="label">Avg Load Time</span>
  </div>
  <p class="tagline">Your visitors experience blazing fast load times</p>
</div>
```

**Public Site Badge (optional):**
```html
<!-- "Powered by PWB - Loads in Xms" badge -->
<div id="pwb-speed-badge" style="position:fixed;bottom:10px;right:10px;">
  Loaded in <span id="load-time"></span>ms
</div>
<script>
  window.addEventListener('load', () => {
    const timing = performance.timing;
    const loadTime = timing.loadEventEnd - timing.navigationStart;
    document.getElementById('load-time').textContent = loadTime;
  });
</script>
```

---

## Implementation Roadmap

### Phase 1: Quick Wins (1-2 days)
- [ ] Add immutable cache headers for assets
- [ ] Enable Brotli compression
- [ ] Add preconnect hints for CDN
- [ ] Implement system font option

### Phase 2: Caching Strategy (3-5 days)
- [ ] Fragment caching for property cards
- [ ] Full-page caching for public pages
- [ ] Stale-while-revalidate headers
- [ ] CDN cache invalidation on content change

### Phase 3: Advanced (1-2 weeks)
- [ ] Service worker implementation
- [ ] Critical CSS extraction
- [ ] Cloudflare Workers for edge rendering
- [ ] Performance dashboard in admin

### Phase 4: Marketing (ongoing)
- [ ] Lighthouse score monitoring
- [ ] Performance comparison vs competitors
- [ ] "Fastest Real Estate Sites" messaging
- [ ] Case studies with speed metrics

---

## Measuring Success

### Key Metrics to Track

| Metric | Current | Target | Tool |
|--------|---------|--------|------|
| Lighthouse Performance | ? | 90+ | Chrome DevTools |
| First Contentful Paint | ? | <1.5s | WebPageTest |
| Largest Contentful Paint | ? | <2.5s | Core Web Vitals |
| Time to Interactive | ? | <3.5s | Lighthouse |
| Total Blocking Time | ? | <200ms | Lighthouse |

### Monitoring Setup

```ruby
# lib/tasks/performance.rake

namespace :performance do
  desc "Run Lighthouse audit on tenant sites"
  task audit: :environment do
    Pwb::Website.active.each do |website|
      # Run lighthouse and store results
      result = `lighthouse #{website.primary_url} --output=json`
      website.update(lighthouse_score: JSON.parse(result)['categories']['performance']['score'] * 100)
    end
  end
end
```

---

## References

- [crazyfast.website](https://crazyfast.website/) - Inspiration source
- [web.dev/performance](https://web.dev/performance/) - Core Web Vitals
- [Cloudflare Workers](https://workers.cloudflare.com/) - Edge computing
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API) - Offline support
