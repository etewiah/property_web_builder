# Stimulus.js Guide

Stimulus is the JavaScript framework for PropertyWebBuilder. It provides modest, focused JavaScript for server-rendered HTML.

## Philosophy

Stimulus is designed to augment your HTML with just enough behavior. It connects JavaScript to HTML via:
- **Controllers** - JavaScript classes that add behavior
- **Actions** - Map DOM events to controller methods
- **Targets** - Reference important elements within a controller
- **Values** - Read/write data attributes as typed properties

## Installation

Stimulus is already installed. To use it in a view:

```erb
<%# In your layout or view %>
<%= javascript_importmap_tags %>
```

## Available Controllers

### toggle_controller

Show/hide elements:

```erb
<div data-controller="toggle">
  <button data-action="toggle#toggle">Toggle Content</button>
  <div data-toggle-target="content" class="hidden">
    This content can be shown/hidden
  </div>
</div>
```

### tabs_controller

Tabbed interfaces:

```erb
<div data-controller="tabs">
  <nav class="flex border-b">
    <button data-tabs-target="tab" data-action="tabs#select" 
            class="px-4 py-2">Details</button>
    <button data-tabs-target="tab" data-action="tabs#select" 
            class="px-4 py-2">Features</button>
    <button data-tabs-target="tab" data-action="tabs#select" 
            class="px-4 py-2">Location</button>
  </nav>
  
  <div data-tabs-target="panel" class="p-4">
    Property details here...
  </div>
  <div data-tabs-target="panel" class="p-4 hidden">
    Property features here...
  </div>
  <div data-tabs-target="panel" class="p-4 hidden">
    Property location here...
  </div>
</div>
```

### gallery_controller

Property photo galleries:

```erb
<div data-controller="gallery" 
     data-gallery-autoplay-value="true"
     data-gallery-interval-value="5000">
  
  <% @property.photos.each_with_index do |photo, index| %>
    <div data-gallery-target="slide" class="<%= 'hidden' unless index == 0 %>">
      <%= image_tag photo.url, class: "w-full" %>
    </div>
  <% end %>
  
  <button data-action="gallery#previous" class="absolute left-2">
    &larr;
  </button>
  <button data-action="gallery#next" class="absolute right-2">
    &rarr;
  </button>
  
  <div data-gallery-target="counter" class="text-center">
    1 / <%= @property.photos.count %>
  </div>
</div>
```

### dropdown_controller

Dropdown menus:

```erb
<div data-controller="dropdown" 
     data-action="click@window->dropdown#closeOnClickOutside keydown.escape->dropdown#closeOnEscape">
  
  <button data-action="dropdown#toggle" 
          data-dropdown-target="button"
          class="px-4 py-2 border rounded">
    Select Property Type
  </button>
  
  <div data-dropdown-target="menu" class="hidden absolute bg-white shadow-lg">
    <a href="#" data-action="dropdown#select" data-value="apartment" 
       class="block px-4 py-2 hover:bg-gray-100">Apartment</a>
    <a href="#" data-action="dropdown#select" data-value="house" 
       class="block px-4 py-2 hover:bg-gray-100">House</a>
    <a href="#" data-action="dropdown#select" data-value="villa" 
       class="block px-4 py-2 hover:bg-gray-100">Villa</a>
  </div>
  
  <input type="hidden" name="property_type" data-dropdown-target="input">
</div>
```

### filter_controller

Search filters:

```erb
<div data-controller="filter" data-filter-submit-on-change-value="true">
  <button data-action="filter#togglePanel" class="flex items-center">
    Filters <span data-filter-target="count" class="ml-2">No filters</span>
  </button>
  
  <div data-filter-target="panel" class="hidden p-4 bg-gray-50">
    <%= form_with url: search_path, method: :get, 
                  data: { filter_target: "form", action: "change->filter#submitOnChange" } do |f| %>
      
      <div class="grid grid-cols-2 gap-4">
        <%= f.select :bedrooms, options_for_select([["Any", ""], "1", "2", "3", "4+"]) %>
        <%= f.select :bathrooms, options_for_select([["Any", ""], "1", "2", "3+"]) %>
        <%= f.select :price_from, @prices_from_collection %>
        <%= f.select :price_till, @prices_till_collection %>
      </div>
      
      <button type="button" data-action="filter#clear" class="text-sm text-gray-500">
        Clear All
      </button>
    <% end %>
  </div>
</div>
```

## Creating New Controllers

Generate a new controller:

```bash
rails generate stimulus controller_name
```

This creates `app/javascript/controllers/controller_name_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["element"]
  static values = { name: String }
  
  connect() {
    // Called when controller is connected to DOM
  }
  
  disconnect() {
    // Called when controller is removed from DOM
  }
  
  action(event) {
    // Called via data-action
  }
}
```

## Best Practices

1. **Keep controllers small and focused** - One controller per behavior
2. **Use targets instead of querySelector** - More declarative and reliable
3. **Use values for configuration** - Type-safe data attributes
4. **Dispatch events for cross-controller communication**
5. **Use Tailwind classes** - Toggle classes rather than inline styles

## Resources

- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
- [Stimulus Reference](https://stimulus.hotwired.dev/reference/controllers)
