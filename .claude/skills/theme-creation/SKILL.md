---
name: theme-creation
description: Create new themes for PropertyWebBuilder. Use when creating custom themes, styling websites, or modifying theme templates. Handles theme registration, view templates, CSS, and asset configuration.
---

# Theme Creation for PropertyWebBuilder

## Theme System Overview

PropertyWebBuilder uses a multi-tenant theme system where each website can have its own theme. Themes are collections of view templates and assets that control the public-facing website appearance.

### Available Themes (as of Dec 2025)

| Theme | Type | Status | Description |
|-------|------|--------|-------------|
| `default` | Bootstrap | Active | Legacy Bootstrap-based theme |
| `berlin` | Bootstrap | Active | Alternative Bootstrap theme |
| `bristol` | Tailwind/Flowbite | Active | Modern Tailwind CSS theme |
| `brisbane` | Tailwind/Flowbite | Active | Luxury real estate theme with navy/gold palette |

### Key Components

1. **Theme Registry**: `app/themes/config.json` - JSON array defining all available themes
2. **Theme Directories**: `app/themes/[theme_name]/views/` - View templates per theme
3. **View Resolution**: Rails prepends theme view path, falling back to default views
4. **Custom Styles**: `app/views/pwb/custom_css/_[theme_name].css.erb` - Dynamic CSS with style variables
5. **Theme Model**: `Pwb::Theme` using ActiveJSON (read-only from config.json)

### Theme Resolution Flow

1. Request comes in with subdomain (tenant identification)
2. `ApplicationController#set_theme_path` determines theme from:
   - URL parameter `?theme=name` (if whitelisted: berlin, default, bristol)
   - Website's `theme_name` field
   - Fallback to "default"
3. Theme view path is prepended to Rails view lookup
4. Views render from theme directory, falling back to app/views

## Creating a New Theme

### Step 1: Register the Theme

Add to `app/themes/config.json`:

```json
{
  "name": "mytheme",
  "friendly_name": "My Custom Theme",
  "id": "mytheme"
}
```

### Step 2: Create Directory Structure

```bash
mkdir -p app/themes/mytheme/views/layouts/pwb
mkdir -p app/themes/mytheme/views/pwb/welcome
mkdir -p app/themes/mytheme/views/pwb/components
mkdir -p app/themes/mytheme/views/pwb/sections
mkdir -p app/themes/mytheme/views/pwb/pages
mkdir -p app/themes/mytheme/views/pwb/props
mkdir -p app/themes/mytheme/views/pwb/search
mkdir -p app/themes/mytheme/views/pwb/shared
```

### Step 3: Choose Base Theme and Copy Files

**For Bootstrap-based themes** (copy from default):
```bash
cp -r app/themes/default/views/* app/themes/mytheme/views/
```

**For Tailwind-based themes** (copy from bristol):
```bash
cp -r app/themes/bristol/views/* app/themes/mytheme/views/
```

### Step 4: Create Custom CSS Partial

Create `app/views/pwb/custom_css/_mytheme.css.erb`:

```erb
/* Theme: mytheme */
/* CSS custom properties from database style_variables */
:root {
  --primary-color: <%= @current_website.style_variables["primary_color"] || "#e91b23" %>;
  --secondary-color: <%= @current_website.style_variables["secondary_color"] || "#3498db" %>;
  --action-color: <%= @current_website.style_variables["action_color"] || "#4CAF50" %>;
  --footer-bg-color: <%= @current_website.style_variables["footer_bg_color"] || "#333" %>;
  --footer-text-color: <%= @current_website.style_variables["footer_main_text_color"] || "#fff" %>;
  --labels-text-color: <%= @current_website.style_variables["labels_text_color"] || "#fff" %>;
  --border-radius: <%= @current_website.style_variables["border_radius"] || "0.5rem" %>;
  --container-padding: <%= @current_website.style_variables["container_padding"] || "1rem" %>;
  --font-primary: <%= @current_website.style_variables["font_primary"] || "Open Sans" %>;
  --font-secondary: <%= @current_website.style_variables["font_secondary"] || "Vollkorn" %>;
}

.btn-base:hover, .btn-base:focus, .btn-base:active {
    background-color: var(--action-color);
    border-color: var(--action-color);
    color: #fff;
}

.fondo_footer {
  background: var(--footer-bg-color);
  color: var(--footer-text-color);
}

.fondo_principal {
  background: var(--primary-color);
  color: var(--labels-text-color);
}

.fondo_secundario {
  background: var(--secondary-color);
  color: var(--labels-text-color);
}

.color_principal {
  color: var(--primary-color) !important;
}

.color_secundario {
  color: var(--secondary-color) !important;
}

<%= render partial: '/pwb/custom_css/shared', locals: {} %>
```

### Step 5: Update the Layout

#### For Bootstrap-based themes

Edit `app/themes/mytheme/views/layouts/pwb/application.html.erb`:

```erb
<%= stylesheet_link_tag "pwb/themes/mytheme", media: "all" %>
<style>
  <%= custom_styles "mytheme" %>
</style>
<body class="tnt-body mytheme-theme <%= @current_website.body_style %>">
```

#### For Tailwind-based themes (recommended)

Edit `app/themes/mytheme/views/layouts/pwb/application.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= yield(:page_title) %></title>
    <%= yield(:page_head) %>

    <%# Tailwind CSS via CDN (for development) %>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
      tailwind.config = {
        theme: {
          container: { center: true, padding: 'var(--container-padding)' },
          extend: {
            colors: {
              primary: 'var(--primary-color)',
              secondary: 'var(--secondary-color)',
            },
            fontFamily: {
              sans: ['var(--font-primary)', 'sans-serif'],
              serif: ['var(--font-secondary)', 'serif'],
            },
            borderRadius: {
              DEFAULT: 'var(--border-radius)',
            }
          }
        }
      }
    </script>

    <%# Flowbite for UI components %>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" rel="stylesheet" />

    <%# Theme-specific styles %>
    <%= stylesheet_link_tag "mytheme_theme", media: "all" %>
    <style>
      <%= custom_styles "mytheme" %>
    </style>

    <%= javascript_include_tag "pwb/application", async: false %>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.js"></script>
    <%= csrf_meta_tags %>

    <%# Leaflet for maps %>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin=""/>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" crossorigin=""></script>
  </head>
  <body class="tnt-body mytheme-theme <%= @current_website.body_style %> bg-gray-50 text-gray-900">
    <div id="main-vue" class="body-wrap sticky-wrap <%= @current_website.body_style %> flex flex-col min-h-screen">
      <%= render partial: '/pwb/header', locals: { not_devise: true } %>
      <div class="sticky-body flex-grow">
        <%= render 'devise/shared/messages' %>
        <%= yield %>
      </div>
      <%= render partial: '/pwb/footer', locals: {} %>
      <%= render partial: '/pwb/analytics', locals: {} %>
    </div>
    <%= yield(:page_script) %>
    <% if params[:edit_mode] == 'true' %>
      <%= javascript_include_tag "pwb/editor_client" %>
    <% end %>
  </body>
</html>
```

### Step 6: Create Theme Stylesheet

Create `app/assets/stylesheets/mytheme_theme.css`:

```css
/* Theme: mytheme */
/* Add theme-specific styles here */

.mytheme-theme {
  /* Custom styles */
}
```

Add to asset manifest `app/assets/config/manifest.js`:
```javascript
//= link mytheme_theme.css
```

### Step 7: Enable URL Override for Testing

Update `app/controllers/pwb/application_controller.rb`:

```ruby
if %w(berlin default bristol mytheme).include? params[:theme]
  theme_name = params[:theme]
end
```

### Step 8: Test the Theme

```bash
# Via URL parameter
http://localhost:3000/?theme=mytheme

# Or via Rails console
website = Pwb::Website.first
website.update(theme_name: 'mytheme')
```

## Theme View Files Reference

### Required Files (Essential Views)

| Directory | Files | Purpose |
|-----------|-------|---------|
| `layouts/pwb/` | `application.html.erb` | Main HTML layout |
| `pwb/` | `_header.html.erb`, `_footer.html.erb` | Header/footer partials |
| `pwb/components/` | `_generic_page_part.html.erb`, `_form_and_map.html.erb`, `_search_cmpt.html.erb` | Reusable components |
| `pwb/sections/` | `contact_us.html.erb`, `_contact_us_form.html.erb` | Page sections |
| `pwb/pages/` | `show.html.erb` | CMS-managed pages |
| `pwb/props/` | `show.html.erb`, `_breadcrumb_row.html.erb`, `_extras.html.erb` | Property detail pages |
| `pwb/search/` | `buy.html.erb`, `rent.html.erb`, `_search_results.html.erb` | Search results pages |
| `pwb/welcome/` | `index.html.erb`, partials | Homepage |
| `pwb/shared/` | `_flowbite_select.html.erb` (Tailwind themes) | Shared UI components |

### Dynamic Content Rendering

Use the `page_part` helper to render CMS-managed content:

```erb
<% @page.ordered_visible_page_contents.each do |page_content| %>
  <%= page_part page_content %>
<% end %>
```

## Style Variables

Available style variables (stored in `pwb_websites.style_variables_for_theme`):

| Variable | Default | Description |
|----------|---------|-------------|
| `primary_color` | `#e91b23` | Main brand color |
| `secondary_color` | `#3498db` | Secondary accent color |
| `action_color` | `green` | Button/action color |
| `footer_bg_color` | `#333` | Footer background |
| `footer_main_text_color` | `#fff` | Footer text color |
| `labels_text_color` | `#fff` | Label text color |
| `body_style` | `siteLayout.wide` | Layout style class |
| `border_radius` | `0.5rem` | Border radius for elements |
| `container_padding` | `1rem` | Container padding |
| `font_primary` | `Open Sans` | Primary font family |
| `font_secondary` | `Vollkorn` | Secondary font family |

## Tailwind CSS Reference (Bristol Theme Pattern)

The Bristol theme demonstrates the modern Tailwind-based approach:

### Key Features
- Uses Tailwind CSS via CDN with custom config
- Flowbite component library for UI components
- CSS custom properties for dynamic theming
- Leaflet for maps instead of Google Maps
- Responsive mobile-first design

### Tailwind Config Integration
```javascript
tailwind.config = {
  theme: {
    extend: {
      colors: {
        primary: 'var(--primary-color)',    // From style_variables
        secondary: 'var(--secondary-color)', // From style_variables
      }
    }
  }
}
```

### Bootstrap to Tailwind Class Conversion

| Bootstrap | Tailwind |
|-----------|----------|
| `.container` | `.container mx-auto px-4` |
| `.row` | `.flex flex-wrap -mx-4` or `.grid grid-cols-12` |
| `.col-md-6` | `.w-full md:w-1/2 px-4` |
| `.col-md-4` | `.w-full md:w-1/3 px-4` |
| `.col-md-3` | `.w-full md:w-1/4 px-4` |
| `.btn` | `.px-4 py-2 rounded` |
| `.btn-primary` | `.bg-primary text-white hover:bg-primary/90` |
| `.card` | `.bg-white rounded-lg shadow-md` |
| `.form-control` | `.w-full px-3 py-2 border border-gray-300 rounded-lg` |
| `.navbar` | `.flex items-center justify-between` |
| `.d-none d-md-block` | `.hidden md:block` |

## Troubleshooting

### MissingTemplate Errors
Copy the missing view file from the default or bristol theme.

### Asset Not Found
1. Ensure stylesheet exists in `app/assets/stylesheets/`
2. Add to `manifest.js`
3. Run `bin/rails assets:precompile` if needed

### Styles Not Applying
1. Check body class matches theme name (e.g., `mytheme-theme`)
2. Verify `custom_styles` helper is called with correct theme name
3. Check CSS specificity conflicts
4. For Tailwind: ensure custom properties are defined in `:root`

### Theme Not Available
1. Verify entry exists in `app/themes/config.json`
2. Check JSON syntax is valid
3. Restart Rails server after config changes

### Flowbite Components Not Working
1. Ensure Flowbite JS is loaded after the DOM
2. Add manual event listeners as fallback (see Bristol theme)

## Examples

**When user asks: "Create a new Tailwind theme called modern"**
1. Add entry to `app/themes/config.json`
2. Copy bristol theme: `cp -r app/themes/bristol/views app/themes/modern/views`
3. Create custom CSS partial `_modern.css.erb`
4. Update layout with theme-specific class
5. Add to URL override whitelist for testing

**When user asks: "Change the header style for a theme"**
1. Edit `app/themes/[theme]/views/pwb/_header.html.erb`
2. Use Tailwind classes for Tailwind themes, Bootstrap for legacy themes

**When user asks: "Add custom colors to a theme"**
1. Edit `app/views/pwb/custom_css/_[theme].css.erb`
2. Define CSS custom properties in `:root`
3. Use `@current_website.style_variables` for dynamic values

**When user asks: "Convert Bootstrap theme to Tailwind"**
1. Copy bristol theme as starting point
2. Replace Bootstrap classes with Tailwind equivalents
3. Add Flowbite for interactive components
4. Update stylesheet references in layout

## Liquid Template Styling (Critical Knowledge)

### Understanding Page Parts

The landing page content (hero, services, etc.) is NOT in ERB templates - it's rendered via **Liquid templates** stored in the database. These templates use CSS classes that must be styled in the theme's CSS file.

**Key Liquid template page parts:**
- `landing_hero` - Hero section with background image
- `about_us_services` - Three-column services section

### Hero Section Liquid Template Structure

The `landing_hero` page part renders this structure:
```html
<div class="hero-section">
  <div class="hero-bg-wrapper">
    <img src="..." class="hero-bg-img">
  </div>
  <div class="hero-content-wrapper">
    <h1 class="hero-title">...</h1>
    <div class="hero-subtitle">
      <ul><li>bullet points...</li></ul>
    </div>
  </div>
</div>
```

**Required CSS for hero section:**
```css
.mytheme-theme .hero-section {
  position: relative;
  width: 100%;
  min-height: 70vh;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.mytheme-theme .hero-bg-wrapper {
  position: absolute;
  inset: 0;
  z-index: 1;
}

/* Dark overlay for text readability */
.mytheme-theme .hero-bg-wrapper::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, rgba(0,0,0,0.6) 0%, rgba(0,0,0,0.4) 100%);
  z-index: 2;
}

.mytheme-theme .hero-bg-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.mytheme-theme .hero-content-wrapper {
  position: relative;
  z-index: 3;
  text-align: center;
  padding: 2rem;
}

.mytheme-theme .hero-title {
  font-size: 3.5rem;
  color: #fff;
  text-shadow: 0 2px 20px rgba(0,0,0,0.3);
}

/* IMPORTANT: Subtitle text needs strong shadows for readability */
.mytheme-theme .hero-subtitle {
  color: #fff;
  text-shadow: 0 2px 10px rgba(0,0,0,0.5);
}

.mytheme-theme .hero-subtitle li {
  font-weight: 500;
  text-shadow: 0 2px 10px rgba(0,0,0,0.6);
}
```

### Services Section Liquid Template Structure

The `about_us_services` page part renders:
```html
<section class="services-section-wrapper">
  <div class="services-container">
    <div class="service-card">
      <div class="service-icon-wrapper">
        <i class="fa fa-home"></i>
      </div>
      <h4 class="service-title">...</h4>
      <div class="service-content">...</div>
    </div>
    <!-- repeated for 3 cards -->
  </div>
</section>
```

**Required CSS for services section:**
```css
.mytheme-theme .services-section-wrapper {
  padding: 5rem 0;
}

.mytheme-theme .services-container {
  max-width: 1400px; /* Use wide max-width for large screens */
  margin: 0 auto;
  padding: 0 2rem;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2.5rem;
}

/* Scale up for very large screens */
@media (min-width: 1600px) {
  .mytheme-theme .services-container {
    max-width: 1600px;
    gap: 3rem;
  }
}

.mytheme-theme .service-card {
  background: #fff;
  padding: 2.5rem 2rem;
  text-align: center;
  box-shadow: 0 4px 20px rgba(0,0,0,0.08);
  transition: all 0.4s ease;
}

.mytheme-theme .service-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 30px rgba(0,0,0,0.12);
}

.mytheme-theme .service-icon-wrapper {
  width: 80px;
  height: 80px;
  margin: 0 auto 1.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f5f5f5;
  border-radius: 50%;
}

/* Stack to single column on mobile */
@media (max-width: 768px) {
  .mytheme-theme .services-container {
    grid-template-columns: 1fr;
  }
}
```

## Common Pitfalls and Solutions

### 1. Hero Text Not Readable
**Problem:** Text on hero image is hard to read.
**Solution:**
- Add dark gradient overlay via `::after` pseudo-element on hero-bg-wrapper
- Add `text-shadow` to all text elements (title AND subtitle)
- Use white (#fff) text color with sufficient contrast

### 2. Services Section Too Narrow on Large Screens
**Problem:** Content appears cramped on wide monitors.
**Solution:**
- Use `max-width: 1400px` minimum for containers
- Add media query for 1600px+ screens with larger max-width
- Increase gap between cards proportionally

### 3. Theme Colors Not Applying to Dynamic Content
**Problem:** Liquid template content doesn't use theme colors.
**Solution:** Style the CSS classes used in Liquid templates:
- `.hero-section`, `.hero-title`, `.hero-subtitle`
- `.services-section-wrapper`, `.service-card`, `.service-icon-wrapper`
- These are NOT in ERB files - they're generated from database templates

### 4. Property Cards Using Wrong Colors
**Problem:** Property prices/icons show default blue instead of theme colors.
**Solution:** Update `_single_property_row.html.erb`:
```erb
<%# Change from: %>
<h2 class="text-blue-600">...</h2>
<%# To: %>
<h2 class="text-luxury-gold">...</h2>  <%# or your theme color %>
```

### 5. Mobile Responsiveness Issues
**Problem:** Layout breaks on mobile devices.
**Solution:**
- Always test at 390px width (iPhone)
- Use `grid-template-columns: 1fr` on mobile for service cards
- Reduce hero min-height on mobile (60vh instead of 70vh)
- Reduce font sizes proportionally

## Brisbane Theme Reference (Luxury Theme Pattern)

The Brisbane theme demonstrates a luxury real estate design with:

### Color Palette
```css
--luxury-navy: #1a2744;
--luxury-gold: #c9a962;
--luxury-cream: #faf8f5;
--luxury-charcoal: #2d2d2d;
--luxury-pearl: #f5f3f0;
```

### Typography
- Headings: Cormorant Garamond (serif)
- Body: Montserrat (sans-serif)
- Letter spacing: 0.02em for headings, 0.15em for uppercase labels

### Key Design Elements
1. **No border-radius** - Sharp, sophisticated corners
2. **Gold accents** - Icons, dividers, price text
3. **Subtle shadows** - `0 4px 20px rgba(26,39,68,0.08)`
4. **Hover lift effect** - `transform: translateY(-4px)`
5. **Gold dividers** - 60px wide, 2px height decorative lines

### Files Modified for Brisbane Theme
```
app/assets/stylesheets/brisbane_theme.css     # Main theme CSS
app/themes/brisbane/views/layouts/pwb/application.html.erb
app/themes/brisbane/views/pwb/_header.html.erb
app/themes/brisbane/views/pwb/_footer.html.erb
app/themes/brisbane/views/pwb/welcome/index.html.erb
app/themes/brisbane/views/pwb/welcome/_single_property_row.html.erb
app/themes/brisbane/views/pwb/welcome/_content_area_cols.html.erb
app/themes/brisbane/views/pwb/search/_search_form_landing.html.erb
```
