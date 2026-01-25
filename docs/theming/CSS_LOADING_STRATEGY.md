# CSS Loading Strategy

This document explains the CSS loading approach used in PropertyWebBuilder themes and the rationale behind it.

## Overview

PropertyWebBuilder uses a **standard stylesheet loading** strategy for theme CSS files, combined with **inlined critical CSS** for fast initial rendering.

## Loading Strategy

### 1. Critical CSS (Inlined)

Critical CSS is inlined directly in the `<head>` to ensure above-the-fold content renders immediately:

```erb
<style><%= critical_css %><%= palette_css %><%= font_css_variables %><%= custom_styles "default" %></style>
```

This includes:
- Basic reset and layout styles
- Color palette CSS variables
- Font family declarations
- Theme-specific custom styles

### 2. Main CSS (Standard Loading)

Theme stylesheets use standard `<link rel="stylesheet">` tags:

```erb
<%= stylesheet_link_tag "tailwind-default", media: "all" %>
<%= stylesheet_link_tag "pwb/themes/default", media: "all" %>
```

### 3. External CSS (Flowbite)

Third-party CSS like Flowbite is loaded via standard link tags:

```html
<link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.5.2/flowbite.min.css" rel="stylesheet">
```

## Why Not Preload Pattern?

We previously used the preload-to-stylesheet pattern:

```html
<!-- OLD APPROACH - NOT USED -->
<link rel="preload" href="styles.css" as="style" onload="this.onload=null;this.rel='stylesheet'">
<noscript><link rel="stylesheet" href="styles.css"></noscript>
```

This pattern was abandoned due to **MIME type sensitivity issues**:

### The Problem

1. **CDN Content-Type Issues**: Cloudflare R2 and some CDN configurations may serve CSS files with incorrect `Content-Type` headers (e.g., `application/octet-stream` instead of `text/css`).

2. **Browser Rejection**: When browsers preload a resource with `as="style"`, they expect `Content-Type: text/css`. If the MIME type is wrong, the browser may:
   - Preload the file successfully
   - But refuse to apply it as a stylesheet when `rel` changes to `stylesheet`
   - Result: page renders without styles

3. **Silent Failure**: This failure is silent - no console errors, just unstyled content.

### Root Cause

The issue occurs because:
- R2 stores files without explicit Content-Type metadata
- Cloudflare may not always pass through Content-Type from R2
- Transform rules or Workers may strip headers

### Solution

Standard `<link rel="stylesheet">` is more forgiving:
- Browsers are more lenient about MIME types for regular stylesheets
- Falls back gracefully in edge cases
- Works reliably across all CDN configurations

## Performance Considerations

### Trade-offs

| Aspect | Preload Pattern | Standard Loading |
|--------|-----------------|------------------|
| Initial render | Faster (non-blocking) | Slightly slower (blocking) |
| Reliability | Fragile (MIME-sensitive) | Robust (works everywhere) |
| Complexity | Higher (JS onload) | Lower (just HTML) |
| Debug difficulty | Hard (silent failures) | Easy (clear errors) |

### Mitigations

We mitigate the performance impact of blocking CSS through:

1. **Critical CSS Inlining**: Above-the-fold styles are inlined, so initial paint is fast
2. **Preconnect Hints**: Early DNS/connection for CDN domains
3. **Asset CDN**: CSS served from edge locations (Cloudflare)
4. **Compression**: Gzip/Brotli compression enabled
5. **Cache Headers**: Long cache times (1 year) with immutable flag

## CDN Asset Configuration

### Uploading Assets with Correct MIME Types

When syncing assets to R2, always set Content-Type:

```ruby
# lib/tasks/assets_cdn.rake
client.put_object(
  bucket: bucket,
  key: key,
  body: file,
  content_type: content_type,  # IMPORTANT: Set correct MIME type
  cache_control: "public, max-age=31536000, immutable"
)
```

### Fixing Existing Assets

If assets have wrong MIME types, run:

```bash
rails assets:fix_content_types
```

This updates metadata without re-uploading file content.

### Force Re-sync

To re-upload all assets with correct metadata:

```bash
rails assets:force_sync_to_r2
```

## Theme Layout Pattern

All theme layouts should follow this pattern:

```erb
<%# 1. Preconnects (early in head) %>
<link rel="preconnect" href="https://cdn-assets.propertywebbuilder.com" crossorigin>

<%# 2. Critical CSS (inlined) %>
<style><%= critical_css %><%= palette_css %><%= font_css_variables %></style>

<%# 3. Main CSS (standard loading) %>
<%= stylesheet_link_tag "tailwind-THEME", media: "all" %>
<%= stylesheet_link_tag "THEME_theme", media: "all" %>

<%# 4. External CSS %>
<link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.5.2/flowbite.min.css" rel="stylesheet">
```

## Debugging CSS Issues

### Symptoms of MIME Type Issues

- Page loads but has no styles (plain HTML)
- Critical CSS works (inline) but external CSS doesn't
- Works locally but not in production
- Works with direct R2 URL but not CDN URL

### Diagnosis

Check Content-Type header:

```bash
curl -sI "https://cdn-assets.example.com/assets/styles.css" | grep content-type
# Should be: content-type: text/css
# Problem if: content-type: application/octet-stream
```

### Fix

1. Run `rails assets:fix_content_types` on server
2. Or use standard stylesheet loading (current approach)
3. Or add Cloudflare Transform Rule to set Content-Type

## Using Preload Pattern with Cloudflare (Optional)

If you want to use the preload-to-stylesheet pattern for better performance, you must configure Cloudflare to serve correct Content-Type headers. This section documents the required steps.

> **Note**: This configuration is optional. The default standard loading approach works without any Cloudflare configuration.

### Prerequisites

- Cloudflare account with your domain configured
- R2 bucket connected to a custom domain (e.g., `cdn-assets.propertywebbuilder.com`)
- Access to Cloudflare Dashboard > Rules

### Step 1: Create Transform Rules for Content-Type

Transform Rules modify response headers. Create rules to set correct MIME types for CSS and JS files.

1. Go to **Cloudflare Dashboard** → **Your Domain** → **Rules** → **Transform Rules**
2. Click **Create rule** → **Modify Response Header**

#### Rule 1: CSS Files

- **Rule name**: `Set Content-Type for CSS`
- **When incoming requests match**:
  - Field: `URI Path`
  - Operator: `ends with`
  - Value: `.css`
- **Then**:
  - Select **Set static**
  - Header name: `Content-Type`
  - Value: `text/css; charset=utf-8`

#### Rule 2: JavaScript Files

- **Rule name**: `Set Content-Type for JS`
- **When incoming requests match**:
  - Field: `URI Path`
  - Operator: `ends with`
  - Value: `.js`
- **Then**:
  - Select **Set static**
  - Header name: `Content-Type`
  - Value: `application/javascript; charset=utf-8`

#### Rule 3: Font Files (WOFF2)

- **Rule name**: `Set Content-Type for WOFF2`
- **When incoming requests match**:
  - Field: `URI Path`
  - Operator: `ends with`
  - Value: `.woff2`
- **Then**:
  - Select **Set static**
  - Header name: `Content-Type`
  - Value: `font/woff2`

### Step 2: Configure CORS Headers

For cross-origin font and asset loading, add CORS headers.

1. In **Transform Rules**, create another **Modify Response Header** rule

#### Rule: CORS for Assets

- **Rule name**: `CORS for CDN Assets`
- **When incoming requests match**:
  - Field: `Hostname`
  - Operator: `equals`
  - Value: `cdn-assets.propertywebbuilder.com` (your CDN domain)
- **Then** (add multiple headers):
  - **Set static**: `Access-Control-Allow-Origin` = `*`
  - **Set static**: `Access-Control-Allow-Methods` = `GET, HEAD, OPTIONS`
  - **Set static**: `Access-Control-Allow-Headers` = `*`

### Step 3: Configure Cache Rules (Optional)

For optimal caching with correct headers:

1. Go to **Rules** → **Cache Rules**
2. Create a rule for your CDN domain

#### Rule: Cache Assets

- **Rule name**: `Cache CDN Assets`
- **When incoming requests match**:
  - Field: `Hostname`
  - Operator: `equals`
  - Value: `cdn-assets.propertywebbuilder.com`
- **Then**:
  - Cache eligibility: **Eligible for cache**
  - Edge TTL: **Override** → 1 year (31536000 seconds)
  - Browser TTL: **Override** → 1 year

### Step 4: Update Theme Layouts for Preload

After Cloudflare is configured, update theme layouts to use preload pattern:

```erb
<%# Main CSS - Preload pattern (requires Cloudflare Transform Rules) %>
<link rel="preload" href="<%= asset_path('tailwind-default.css') %>" as="style" onload="this.onload=null;this.rel='stylesheet'">
<link rel="preload" href="<%= asset_path('pwb/themes/default.css') %>" as="style" onload="this.onload=null;this.rel='stylesheet'">
<noscript>
  <%= stylesheet_link_tag "tailwind-default", media: "all" %>
  <%= stylesheet_link_tag "pwb/themes/default", media: "all" %>
</noscript>
```

### Step 5: Verify Configuration

Test that Content-Type headers are correct:

```bash
# Check CSS Content-Type
curl -sI "https://cdn-assets.propertywebbuilder.com/assets/tailwind-default-abc123.css" | grep -i content-type
# Expected: content-type: text/css; charset=utf-8

# Check JS Content-Type
curl -sI "https://cdn-assets.propertywebbuilder.com/assets/application-abc123.js" | grep -i content-type
# Expected: content-type: application/javascript; charset=utf-8

# Check CORS headers
curl -sI "https://cdn-assets.propertywebbuilder.com/assets/style.css" | grep -i access-control
# Expected: access-control-allow-origin: *
```

### Troubleshooting Preload Issues

If styles still don't apply after configuring Transform Rules:

1. **Clear Cloudflare Cache**: Dashboard → Caching → Purge Everything
2. **Check Rule Order**: Transform Rules are processed in order; ensure no conflicting rules
3. **Verify Rule Matches**: Use Cloudflare's "Test rule" feature
4. **Check Browser DevTools**: Network tab should show correct Content-Type
5. **Try Incognito Mode**: Browser cache may have old responses

### Alternative: Cloudflare Worker

For more complex logic, use a Cloudflare Worker:

```javascript
// workers/asset-headers.js
export default {
  async fetch(request, env) {
    const response = await fetch(request);
    const url = new URL(request.url);

    // Clone response to modify headers
    const newResponse = new Response(response.body, response);

    // Set Content-Type based on extension
    if (url.pathname.endsWith('.css')) {
      newResponse.headers.set('Content-Type', 'text/css; charset=utf-8');
    } else if (url.pathname.endsWith('.js')) {
      newResponse.headers.set('Content-Type', 'application/javascript; charset=utf-8');
    } else if (url.pathname.endsWith('.woff2')) {
      newResponse.headers.set('Content-Type', 'font/woff2');
    }

    // Add CORS headers
    newResponse.headers.set('Access-Control-Allow-Origin', '*');

    return newResponse;
  }
};
```

Deploy the Worker and add a route for your CDN domain.

### When to Use Preload vs Standard Loading

| Scenario | Recommendation |
|----------|----------------|
| Simple setup, no Cloudflare config access | Standard loading |
| Performance-critical, can configure Cloudflare | Preload pattern |
| Multiple CDN providers | Standard loading |
| Full control over infrastructure | Preload pattern |
| Debugging issues | Standard loading (easier) |

## Related Files

- `app/themes/*/views/layouts/pwb/application.html.erb` - Theme layouts
- `app/helpers/pwb/css_helper.rb` - Critical CSS helper
- `lib/tasks/assets_cdn.rake` - Asset sync tasks
- `config/initializers/assets.rb` - Asset pipeline config

## History

- **2026-01**: Switched from preload pattern to standard loading due to Cloudflare R2 MIME type issues in production
- **Previous**: Used preload-to-stylesheet pattern for performance optimization
