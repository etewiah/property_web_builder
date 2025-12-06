# Page Part Routes

This document describes the child routes feature that allows rendering individual page parts from a page.

## Overview

Pages in PropertyWebBuilder are composed of multiple "page parts" - reusable content blocks that can be arranged and configured per page. The page part routes feature allows you to access and render a single page part in isolation, which is useful for:

- Previewing individual content sections
- Embedding specific content blocks via iframes
- Debugging page part rendering
- AJAX-based content loading

## URL Pattern

```
/p/:page_slug/:page_part_key
```

With locale:
```
/:locale/p/:page_slug/:page_part_key
```

## Example URLs

Assuming your site is running at `http://tenant-a.e2e.localhost:3001`:

### Available Page Parts (tenant-a)

| Page | Page Part Key | URL |
|------|---------------|-----|
| home | landing_hero | `/p/home/landing_hero` |
| home | about_us_services | `/p/home/about_us_services` |
| about-us | our_agency | `/p/about-us/our_agency` |
| contact-us | form_and_map | `/p/contact-us/form_and_map` |
| sell | content_html | `/p/sell/content_html` |
| legal | content_html | `/p/legal/content_html` |
| privacy | content_html | `/p/privacy/content_html` |

### With Locale

| URL | Description |
|-----|-------------|
| `/en/p/home/landing_hero` | English landing hero |
| `/es/p/home/landing_hero` | Spanish landing hero |
| `/fr/p/about-us/our_agency` | French agency info |

## Full Example URLs for Testing

If running locally with e2e environment (copy-paste ready):

```
http://tenant-a.e2e.localhost:3001/p/home/landing_hero
http://tenant-a.e2e.localhost:3001/p/home/about_us_services
http://tenant-a.e2e.localhost:3001/p/about-us/our_agency
http://tenant-a.e2e.localhost:3001/p/contact-us/form_and_map
http://tenant-a.e2e.localhost:3001/p/sell/content_html
http://tenant-a.e2e.localhost:3001/p/legal/content_html
http://tenant-a.e2e.localhost:3001/p/privacy/content_html
```

With locale:
```
http://tenant-a.e2e.localhost:3001/en/p/home/landing_hero
http://tenant-a.e2e.localhost:3001/es/p/about-us/our_agency
```

## Response Behavior

### Successful Response (200 OK)
When the page and page part exist and the page part is visible, the content is rendered using a minimal layout (`layouts/pwb/page_part`) that includes:
- Basic HTML structure
- Theme-specific CSS
- The page part content

### Not Found Response (404)
Returns a plain text error message when:
- The page slug doesn't exist: `"Page not found: {page_slug}"`
- The page part key doesn't exist: `"Page part not found or not visible: {page_part_key}"`
- The page part exists but is hidden (visible_on_page = false)

## Finding Available Page Parts

To discover what page parts are available for a page, you can:

### Via Rails Console

```ruby
# Set tenant first
tenant('tenant-a')

# Find page parts for a specific page
page = Pwb::Page.find_by(slug: 'home')
page.page_contents.where(visible_on_page: true).pluck(:page_part_key)
# => ["landing_search", "latest_props", "featured_props", ...]
```

### Via Site Admin

Navigate to `/site_admin/pages/{page_id}` to see all page parts for a page.

## Technical Details

### Controller
`Pwb::PagesController#show_page_part` (`app/controllers/pwb/pages_controller.rb`)

### Route Definition
```ruby
# config/routes.rb
get "/p/:page_slug/:page_part_key" => "pages#show_page_part", as: "show_page_part"
```

### Layout
`app/views/layouts/pwb/page_part.html.erb` - A minimal layout without header/footer.

### View Template
`app/views/pwb/pages/show_page_part.html.erb` - Renders the page part content.

## Use Cases

### Embedding in External Sites
```html
<iframe src="https://yoursite.com/p/home/latest_props" width="100%" height="400"></iframe>
```

### AJAX Loading
```javascript
fetch('/p/home/featured_props')
  .then(response => response.text())
  .then(html => {
    document.getElementById('featured-section').innerHTML = html;
  });
```

### Preview During Editing
The in-context editor can use these URLs to preview individual sections being edited.
