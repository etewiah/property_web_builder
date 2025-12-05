---
name: theme-creation
description: Create new themes for PropertyWebBuilder. Use when creating custom themes, styling websites, or modifying theme templates. Handles theme registration, view templates, CSS, and asset configuration.
---

# Theme Creation for PropertyWebBuilder

## Theme System Overview

PropertyWebBuilder uses a multi-tenant theme system where each website can have its own theme. Themes are collections of view templates and assets that control the public-facing website appearance.

### Key Components

1. **Theme Registry**: `app/themes/config.json` - JSON array defining all available themes
2. **Theme Directories**: `app/themes/[theme_name]/views/` - View templates per theme
3. **View Resolution**: Rails prepends theme view path, falling back to default views
4. **Custom Styles**: `app/views/pwb/custom_css/_[theme_name].css.erb` - Dynamic CSS with style variables
5. **Theme Model**: `Pwb::Theme` using ActiveJSON (read-only from config.json)

### Theme Resolution Flow

1. Request comes in with subdomain (tenant identification)
2. `ApplicationController#set_theme_path` determines theme from:
   - URL parameter `?theme=name` (if whitelisted)
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
```

### Step 3: Copy All View Files from Default Theme

**CRITICAL**: Copy ALL view files - don't rely on Rails fallback

```bash
# Layout
cp app/themes/default/views/layouts/pwb/application.html.erb app/themes/mytheme/views/layouts/pwb/

# Components
cp app/themes/default/views/pwb/components/*.erb app/themes/mytheme/views/pwb/components/

# Sections
cp app/themes/default/views/pwb/sections/*.erb app/themes/mytheme/views/pwb/sections/

# Pages
cp app/themes/default/views/pwb/pages/*.erb app/themes/mytheme/views/pwb/pages/

# Props (property details)
cp app/themes/default/views/pwb/props/*.erb app/themes/mytheme/views/pwb/props/

# Search
cp app/themes/default/views/pwb/search/*.erb app/themes/mytheme/views/pwb/search/

# Welcome (homepage)
cp app/themes/default/views/pwb/welcome/*.erb app/themes/mytheme/views/pwb/welcome/
```

### Step 4: Create Custom CSS Partial

Create `app/views/pwb/custom_css/_mytheme.css.erb`:

```erb
/* Theme: mytheme */
/* These styles use dynamic variables from the database */

.btn-base:hover, .btn-base:focus, .btn-base:active {
    background-color: <%= @current_website.style_variables["action_color"] || "#4CAF50" %>;
    border-color: <%= @current_website.style_variables["action_color"] || "#4CAF50" %>;
    color: #fff;
}

.fondo_footer {
  background: <%= @current_website.style_variables["footer_bg_color"] || "#333" %>;
  color: <%= @current_website.style_variables["footer_main_text_color"] || "#fff" %>;
}

.fondo_principal {
  background: <%= @current_website.style_variables["primary_color"] || "#e91b23" %>;
  color: <%= @current_website.style_variables["labels_text_color"] || "#fff" %>;
}

.fondo_secundario {
  background: <%= @current_website.style_variables["secondary_color"] || "#3498db" %>;
  color: <%= @current_website.style_variables["labels_text_color"] || "#fff" %>;
}

.color_principal {
  color: <%= @current_website.style_variables["primary_color"] || "#e91b23" %> !important;
}

.color_secundario {
  color: <%= @current_website.style_variables["secondary_color"] || "#3498db" %> !important;
}

<%= render partial: '/pwb/custom_css/shared', locals: {} %>
```

### Step 5: Update the Layout

Edit `app/themes/mytheme/views/layouts/pwb/application.html.erb`:

1. Update stylesheet reference:
```erb
<%= stylesheet_link_tag "pwb/themes/mytheme", media: "all" %>
```

2. Update custom_styles call:
```erb
<style>
  <%= custom_styles "mytheme" %>
</style>
```

3. Update body class:
```erb
<body class="tnt-body mytheme-theme <%= @current_website.body_style %>">
```

### Step 6: Create Theme Stylesheet

Create `app/stylesheets/pwb/themes/mytheme.scss`:

```scss
// Theme: mytheme
// Import shared styles
@import "pwb/themes/shared/gmap";

// Theme-specific styles
.mytheme-theme {
  // Your custom styles here
}
```

Add to asset manifest `app/assets/config/manifest.js`:
```javascript
//= link pwb/themes/mytheme.css
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

### Required Files (copy from default theme)

| Directory | Files | Purpose |
|-----------|-------|---------|
| `layouts/pwb/` | `application.html.erb` | Main HTML layout |
| `pwb/components/` | `_generic_page_part.html.erb`, `_form_and_map.html.erb`, `_search_cmpt.html.erb` | Reusable components |
| `pwb/sections/` | `contact_us.html.erb`, `_contact_us_form.html.erb` | Page sections |
| `pwb/pages/` | `show.html.erb` | CMS-managed pages |
| `pwb/props/` | `show.html.erb`, `_breadcrumb_row.html.erb` | Property detail pages |
| `pwb/search/` | `buy.html.erb`, `rent.html.erb` | Search results pages |
| `pwb/welcome/` | `index.html.erb`, partials | Homepage |

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

## Tailwind CSS Themes

For Tailwind-based themes (like Bristol):

1. Create `app/assets/tailwind/application.css` with Tailwind imports
2. Create rake task for building CSS (`lib/tasks/mytheme.rake`)
3. Use unique asset name to avoid conflicts (e.g., `mytheme_theme.css`)
4. Update `manifest.js` to link the built CSS

## Bootstrap to Tailwind Conversion Reference

| Bootstrap | Tailwind |
|-----------|----------|
| `.container` | `.container mx-auto px-4` |
| `.row` | `.flex flex-wrap -mx-4` |
| `.col-md-6` | `.w-full md:w-1/2 px-4` |
| `.col-md-4` | `.w-full md:w-1/3 px-4` |
| `.col-md-3` | `.w-full md:w-1/4 px-4` |
| `.btn` | `.px-4 py-2 rounded` |
| `.btn-primary` | `.bg-blue-600 text-white hover:bg-blue-700` |

## Troubleshooting

### MissingTemplate Errors
Copy the missing view file from the default theme.

### Asset Not Found
1. Ensure stylesheet exists in `app/stylesheets/pwb/themes/`
2. Add to `manifest.js`
3. Run `bin/rails assets:precompile` if needed

### Styles Not Applying
1. Check body class matches theme name
2. Verify `custom_styles` helper is called with correct theme name
3. Check CSS specificity conflicts

### Theme Not Available
1. Verify entry exists in `app/themes/config.json`
2. Check JSON syntax is valid
3. Restart Rails server after config changes

## Examples

**When user asks: "Create a new theme called modern"**
1. Add entry to `app/themes/config.json`
2. Create directory structure under `app/themes/modern/views/`
3. Copy all view files from default theme
4. Create custom CSS partial
5. Update layout with theme-specific references
6. Add to URL override whitelist for testing

**When user asks: "Change the header style for a theme"**
1. Edit `app/themes/[theme]/views/layouts/pwb/application.html.erb`
2. Or create/edit a header partial in the theme's views

**When user asks: "Add custom colors to a theme"**
1. Edit `app/views/pwb/custom_css/_[theme].css.erb`
2. Use `@current_website.style_variables` for dynamic values

**When user asks: "Convert theme to Tailwind CSS"**
1. Create Tailwind configuration
2. Set up build task
3. Replace Bootstrap classes in all view files
4. Update layout to reference new Tailwind CSS file
