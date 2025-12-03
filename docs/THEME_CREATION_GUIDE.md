# Theme Creation Guide

This comprehensive guide explains how the theme system works in PropertyWebBuilder and provides step-by-step instructions for creating a new theme.

## Understanding the Theme System

PropertyWebBuilder uses a multi-tenant theme system where each website can have its own theme. Themes are essentially collections of view templates and assets that determine the look and feel of the public-facing website.

### Key Components

1.  **Theme Configuration**: Themes are defined in `app/themes/config.json`. This file registers the theme and makes it available for selection.
2.  **Theme Directory**: Each theme has its own directory in `app/themes/[theme_name]`. This directory contains the view templates.
3.  **View Resolution**: The `ApplicationController` prepends the current theme's view path to the Rails view lookup path. This means that if a view exists in the theme directory, it will be used; otherwise, Rails falls back to the default views in `app/views`.
4.  **Custom Styles**: Themes can have a custom CSS partial located in `app/views/pwb/custom_css/_[theme_name].css.erb`. This allows for dynamic styling based on database variables.
5.  **Page Parts**: Content is rendered dynamically using the `page_part` helper, which renders content blocks managed via the CMS.

## Step-by-Step: Creating the Bristol Theme

This guide documents the creation of the "bristol" theme as an example. Follow these steps to create your own theme.

### Step 1: Register the Theme

Add your theme to `app/themes/config.json`:

```json
{
  "name": "bristol",
  "friendly_name": "Bristol Theme",
  "id": "bristol"
}
```

### Step 2: Create the Directory Structure

Create all necessary directories for your theme views:

```bash
mkdir -p app/themes/bristol/views/layouts/pwb
mkdir -p app/themes/bristol/views/pwb/welcome
mkdir -p app/themes/bristol/views/pwb/components
mkdir -p app/themes/bristol/views/pwb/sections
mkdir -p app/themes/bristol/views/pwb/pages
mkdir -p app/themes/bristol/views/pwb/props
mkdir -p app/themes/bristol/views/pwb/search
```

### Step 3: Create the Layout

Create the main layout at `app/themes/bristol/views/layouts/pwb/application.html.erb`.

**Important**: Use unique names for your theme's assets to avoid conflicts.

Example for Bristol theme using Tailwind CSS:

```erb
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="index, follow">
    <title><%= yield(:page_title) %></title>
    <%= yield(:page_head) %>
    
    <%# Tailwind CSS %>
    <%= stylesheet_link_tag "bristol_theme", media: "all" %>
    
    <style>
      <%= custom_styles "bristol" %>
    </style>
    
    <%= javascript_include_tag "pwb/application", async: false %>
    
    <%# Flowbite JS %>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.js"></script>
    
    <%= csrf_meta_tags %>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  </head>
  <body class="tnt-body bristol-theme <%= @current_website.body_style %> bg-gray-50 text-gray-900">
    <div id="main-vue" class="body-wrap sticky-wrap <%= @current_website.body_style %> flex flex-col min-h-screen">
      <%= render :partial => '/pwb/header', :locals => { not_devise: true }  %>
      <div class="sticky-body flex-grow">
        <%= render 'devise/shared/messages' %>
        <%= yield %>
      </div>
      <%= render :partial => '/pwb/footer', :locals => {}  %>
      <%= render :partial => '/pwb/analytics', :locals => {}  %>
    </div>
  </body>
</html>
```

**Note**: This layout excludes Bootstrap entirely and uses Tailwind CSS instead.

### Step 4: Create the Custom CSS Partial

Create a partial for your theme's dynamic styles at `app/views/pwb/custom_css/_bristol.css.erb`:

```css
/* Custom CSS for Bristol Theme */
:root {
  --primary-color: <%= @current_website.style_variables['primary_color'] || '#3b82f6' %>;
  --secondary-color: <%= @current_website.style_variables['secondary_color'] || '#1e40af' %>;
}

.bristol-theme {
  /* Add any theme-specific overrides here */
}
```

### Step 5: Copy ALL View Files from Default Theme

You **must** copy ALL view files from the default theme to ensure your theme has complete coverage. Missing files will result in errors.

#### Components

```bash
cp app/themes/default/views/pwb/components/_generic_page_part.html.erb app/themes/bristol/views/pwb/components/
cp app/themes/default/views/pwb/components/_form_and_map.html.erb app/themes/bristol/views/pwb/components/
cp app/themes/default/views/pwb/components/_search_cmpt.html.erb app/themes/bristol/views/pwb/components/
```

#### Sections

```bash
cp app/themes/default/views/pwb/sections/* app/themes/bristol/views/pwb/sections/
```

#### Pages, Props, Search, and Welcome

```bash
cp app/themes/default/views/pwb/pages/* app/themes/bristol/views/pwb/pages/
cp app/themes/default/views/pwb/props/* app/themes/bristol/views/pwb/props/
cp app/themes/default/views/pwb/search/* app/themes/bristol/views/pwb/search/
cp app/themes/default/views/pwb/welcome/* app/themes/bristol/views/pwb/welcome/
```

### Step 6: Convert Bootstrap Classes to Tailwind

After copying the files, you **must** convert Bootstrap classes to Tailwind classes. Here's a conversion reference:

#### Common Bootstrap to Tailwind Conversions

| Bootstrap | Tailwind |
|-----------|----------|
| `.container` | `.container mx-auto px-4` |
| `.row` | `.flex flex-wrap -mx-4` |
| `.col-md-6` | `.w-full md:w-1/2 px-4` |
| `.col-md-4` | `.w-full md:w-1/3 px-4` |
| `.col-md-3` | `.w-full md:w-1/4 px-4` |
| `.col-md-9` | `.w-full md:w-3/4 px-4` |
| `.col-md-12` | `.w-full px-4` |
| `.breadcrumb` | `.inline-flex items-center space-x-1` |
| `.breadcrumb > li.active` | `.text-gray-500` |
| `.btn` | `.px-4 py-2 rounded` |
| `.btn-primary` | `.bg-blue-600 text-white hover:bg-blue-700` |
| `.bg-white` | `.bg-white` (same) |
| `.text-center` | `.text-center` (same) |

#### Example Conversion

**Before (Bootstrap)**:
```erb
<div class="container">
  <div class="row">
    <div class="col-md-6">
      <h2>Title</h2>
    </div>
  </div>
</div>
```

**After (Tailwind)**:
```erb
<div class="container mx-auto px-4">
  <div class="flex flex-wrap -mx-4">
    <div class="w-full md:w-1/2 px-4">
      <h2 class="text-2xl font-bold">Title</h2>
    </div>
  </div>
</div>
```

### Step 7: Configure Assets

If you are using Tailwind CSS, you need to create a specific build for your theme.

#### Create a Rake Task

Create `lib/tasks/bristol_theme.rake`:

```ruby
namespace :bristol do
  desc "Build Bristol theme CSS"
  task :build do
    input = "app/assets/tailwind/application.css"
    output = "app/assets/builds/bristol_theme.css"
    
    command = "npx tailwindcss -i #{input} -o #{output} --minify"
    puts "Running: #{command}"
    system(command)
  end
  
  desc "Watch Bristol theme CSS"
  task :watch do
    input = "app/assets/tailwind/application.css"
    output = "app/assets/builds/bristol_theme.css"
    
    command = "npx tailwindcss -i #{input} -o #{output} --watch"
    puts "Running: #{command}"
    system(command)
  end
end
```

#### Update Procfile.dev

```yaml
css: bin/rails bristol:watch
```

#### Update manifest.js

Add to `app/assets/config/manifest.js`:

```javascript
//= link bristol_theme.css
```

#### Build the CSS

```bash
bin/rails bristol:build
```

### Step 8: Dynamic Content Rendering

**Critical**: To ensure your theme displays CMS-managed content, use the `page_part` helper.

In your views (e.g., `app/themes/bristol/views/pwb/welcome/index.html.erb`):

```erb
<% @page.ordered_visible_page_contents.each do |page_content| %>
  <%= page_part page_content %>
<% end %>
```

This loop renders all visible content blocks for the page. This is what allows users to manage content via the admin interface without modifying theme code.

### Step 9: Enable URL Override for Testing

Update `app/controllers/pwb/application_controller.rb`:

```ruby
if %w(berlin default bristol).include? params[:theme]
  theme_name = params[:theme]
end
```

### Step 10: Test Your Theme

```bash
# Via URL parameter
http://localhost:3000/?theme=bristol

# Or set it for a website in Rails console
website = Pwb::Website.first
website.update(theme_name: 'bristol')
```

## Checklist: Files to Copy/Create

- [ ] Layout: `layouts/pwb/application.html.erb`
- [ ] Components: All files from `pwb/components/`
  - [ ] `_generic_page_part.html.erb`
  - [ ] `_form_and_map.html.erb`
  - [ ] `_search_cmpt.html.erb`
- [ ] Sections: All files from `pwb/sections/`
- [ ] Pages: All files from `pwb/pages/`
- [ ] Props: All files from `pwb/props/`
- [ ] Search: All files from `pwb/search/`
- [ ] Welcome: All files from `pwb/welcome/`
- [ ] Custom CSS partial: `app/views/pwb/custom_css/_[theme_name].css.erb`
- [ ] Asset build configuration (rake task, Procfile, manifest)

## Naming Conventions

-   **Theme Name**: Use snake_case (e.g., `bristol`, `my_theme`).
-   **Asset Names**: Prefix assets with the theme name (e.g., `bristol_theme.css`) to prevent collisions.
-   **CSS Classes**: Use a root class on the `<body>` tag (e.g., `.bristol-theme`) to scope your styles.

## Best Practices

-   **Copy ALL Files**: Don't assume Rails fallback will work. Copy every view file.
-   **Convert Classes Meticulously**: Search and replace Bootstrap classes systematically.
-   **Test Thoroughly**: Test every page type (home, search, property detail, etc.).
-   **Document Changes**: If you modify behavior, document it.
-   **Use Version Control**: Commit after each major step.

## Troubleshooting

### MissingTemplate Errors

If you see `ActionView::MissingTemplate`, you're missing a view file. Check the error message for the file name and copy it from the default theme.

### Asset Not Found Errors

If you see `AssetNotFound`, ensure:
1. You've run the asset build task (`bin/rails bristol:build`)
2. The asset is listed in `manifest.js`
3. The stylesheet_link_tag uses the correct asset name

### Bootstrap Styling Still Appears

Check:
1. Your layout doesn't include Bootstrap CSS
2. You've converted all class names in your views
3. No partials are being rendered from outside your theme directory that contain Bootstrap classes

## Summary

Creating a new theme requires:
1. Registering it in `config.json`
2. Creating the directory structure
3. Copying **ALL** view files from the default theme
4. Converting Bootstrap classes to your chosen CSS framework (e.g., Tailwind)
5. Creating theme-specific assets
6. Testing thoroughly

The Bristol theme serves as a complete example of a Tailwind-based theme with all Bootstrap references removed.
