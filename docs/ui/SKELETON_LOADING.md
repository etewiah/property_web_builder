# Skeleton Loading Components

A lightweight skeleton loading system using Stimulus.js and Tailwind CSS. Provides smooth loading states without external dependencies.

## Quick Start

### Basic Usage with Helper

```erb
<%= skeleton_loader do |loader| %>
  <%= loader.placeholder do %>
    <%= skeleton_property_cards(3) %>
  <% end %>
  <%= loader.content do %>
    <%= render @properties %>
  <% end %>
<% end %>
```

### Standalone Skeleton (no controller)

```erb
<%= skeleton_property_cards(3) %>
```

## Available Skeleton Types

### Property Cards
For property listing grids:
```erb
<%= skeleton_property_cards(3) %>
<%= skeleton_property_cards(6, aspect: "aspect-square") %>
```

### Text Lines
For content loading:
```erb
<%= skeleton_text(4) %>
```

### Images
For image placeholders:
```erb
<%= skeleton_image(aspect: "aspect-video") %>
<%= skeleton_image(aspect: "aspect-square") %>
```

### Stat Cards
For dashboard statistics:
```erb
<%= skeleton_stat_cards(4) %>
```

### Table Rows
For table content:
```erb
<table>
  <tbody>
    <%= skeleton_table_rows(5) %>
  </tbody>
</table>
```

### List Items
For list views:
```erb
<%= skeleton_list_items(5) %>
```

### Search Results
For search result pages:
```erb
<%= skeleton_search_results(3) %>
```

### Media Grid
For media library:
```erb
<div class="grid grid-cols-4 gap-4">
  <%= skeleton_media_grid(8) %>
</div>
```

## Stimulus Controller Usage

### Auto-reveal After Delay

Show skeleton for a minimum time (useful for very fast loads):

```erb
<%= skeleton_loader(delay: 500) do |loader| %>
  <%= loader.placeholder do %>
    <%= skeleton_text(3) %>
  <% end %>
  <%= loader.content do %>
    <p>Content that loads quickly</p>
  <% end %>
<% end %>
```

### With Turbo Frames

Automatically reveal content when Turbo frame loads:

```erb
<turbo-frame id="properties" data-controller="skeleton" data-action="turbo:frame-load->skeleton#loaded">
  <div data-skeleton-target="placeholder">
    <%= skeleton_property_cards(6) %>
  </div>
  <div data-skeleton-target="content" class="hidden">
    <!-- Content loaded via Turbo -->
  </div>
</turbo-frame>
```

Or using the helper:

```erb
<%= skeleton_loader(turbo_frame: true) do |loader| %>
  <%= loader.placeholder do %>
    <%= skeleton_property_cards(6) %>
  <% end %>
  <%= loader.content do %>
    <%= render partial: "properties/property", collection: @properties %>
  <% end %>
<% end %>
```

### With Image Loading

Reveal content when an image finishes loading:

```erb
<div data-controller="skeleton">
  <div data-skeleton-target="placeholder">
    <%= skeleton_image %>
  </div>
  <img
    data-skeleton-target="content"
    data-action="load->skeleton#loaded"
    class="hidden"
    src="<%= property.main_image_url %>"
    alt="<%= property.title %>"
  >
</div>
```

### Manual Control via JavaScript

```javascript
// Get the controller
const element = document.querySelector('[data-controller="skeleton"]')
const controller = this.application.getControllerForElementAndIdentifier(element, 'skeleton')

// Show loading state
controller.loading()

// Reveal content
controller.loaded()
```

### Listen for Load Events

```erb
<div
  data-controller="my-controller skeleton"
  data-action="skeleton:loaded->my-controller#onContentLoaded"
>
  ...
</div>
```

## Raw HTML Usage

You can use skeletons without helpers:

```html
<!-- Property card skeleton -->
<div class="bg-white rounded-lg shadow-sm border overflow-hidden animate-pulse">
  <div class="aspect-video bg-gray-200"></div>
  <div class="p-4">
    <div class="h-4 bg-gray-200 rounded w-3/4 mb-3"></div>
    <div class="h-3 bg-gray-200 rounded w-1/2 mb-4"></div>
    <div class="flex items-center justify-between">
      <div class="flex space-x-3">
        <div class="h-3 bg-gray-200 rounded w-8"></div>
        <div class="h-3 bg-gray-200 rounded w-8"></div>
      </div>
      <div class="h-5 bg-gray-200 rounded w-20"></div>
    </div>
  </div>
</div>
```

## Customization

### Disable Animations

```erb
<%= skeleton_loader(animate: false) do |loader| %>
  ...
<% end %>
```

### Custom Skeleton Styles

Create your own skeletons using Tailwind's `animate-pulse` and `bg-gray-200`:

```html
<div class="animate-pulse">
  <div class="h-6 bg-gray-200 rounded-full w-24 mb-2"></div>
  <div class="h-4 bg-gray-200 rounded w-full"></div>
</div>
```

### Dark Mode Support

Add dark mode variants if needed:

```html
<div class="animate-pulse">
  <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded"></div>
</div>
```

## Best Practices

1. **Match the layout** - Skeletons should closely match the shape of actual content
2. **Use appropriate counts** - Show the expected number of items
3. **Don't overuse** - Only use skeletons where loading time is noticeable
4. **Minimum display time** - Consider using `delay` to prevent flash of skeleton
5. **Accessible** - Skeletons are decorative; actual content will be announced to screen readers

## Files

- `app/javascript/controllers/skeleton_controller.js` - Stimulus controller
- `app/views/shared/_skeleton.html.erb` - Skeleton templates
- `app/helpers/skeleton_helper.rb` - View helpers
