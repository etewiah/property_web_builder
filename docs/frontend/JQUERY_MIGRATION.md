# jQuery to Stimulus.js Migration

**Status**: In Progress (December 2024)

## Overview

This document tracks the migration from jQuery to Stimulus.js for frontend interactivity.

## New Stimulus Controllers

The following controllers replace jQuery functionality:

### 1. `search_form_controller.js`
**Replaces**: jQuery AJAX event handlers in search pages

```erb
<section data-controller="search-form">
  <form data-search-form-target="form">...</form>
  <div data-search-form-target="spinner" class="hidden">Loading...</div>
  <div data-search-form-target="results">Results here</div>
</section>
```

**Features**:
- AJAX loading states (opacity, spinner)
- Form submission handling
- URL parameter updates for bookmarkability
- Description truncation
- Result sorting

### 2. `contact_form_controller.js`
**Replaces**: Remote form handling with jQuery

```erb
<div data-controller="contact-form">
  <form data-contact-form-target="form" 
        data-action="ajax:beforeSend->contact-form#handleBeforeSend">
    ...
    <div data-contact-form-target="result"></div>
    <button data-contact-form-target="submitButton">Send</button>
  </form>
</div>
```

**Features**:
- Loading state on submit button
- Success/error message display
- Form reset after success
- Works with Rails UJS remote forms

### 3. `map_controller.js`
**Replaces**: Inline Leaflet JavaScript and INMOAPP.renderMap

```erb
<div data-controller="map"
     data-map-markers-value='<%= @markers.to_json %>'
     data-map-target="canvas"
     style="height: 400px;">
</div>
```

**Features**:
- Leaflet map initialization
- Multiple markers with popups
- Auto-fit bounds
- Property card hover highlighting

## Migration Status

### Completed
- [x] Search form AJAX handlers (buy.html.erb, rent.html.erb)
- [x] Contact form submission
- [x] Map initialization with Leaflet
- [x] AJAX response files (contact_us, request_info)

### Deprecated (still functional)
- [ ] `INMOAPP` global namespace
- [ ] `slick-carousel` Vue component (use `gallery_controller.js`)
- [ ] `page-content` Vue component
- [ ] Google Maps functions (use Leaflet + `map_controller.js`)

### Future Work
- [ ] Remove jQuery from Gemfile when all dependencies migrated
- [ ] Remove `jquery_ujs` (replace with Turbo or native fetch)
- [ ] Migrate remaining Vue components to Stimulus or remove

## Files Changed

### New Controllers
- `app/javascript/controllers/search_form_controller.js`
- `app/javascript/controllers/contact_form_controller.js`
- `app/javascript/controllers/map_controller.js`

### Updated Views
- `app/themes/default/views/pwb/search/buy.html.erb`
- `app/themes/default/views/pwb/search/rent.html.erb`
- `app/themes/default/views/pwb/sections/_contact_us_form.html.erb`

### Updated AJAX Responses (vanilla JS)
- `app/views/pwb/ajax/contact_us_success.js.erb`
- `app/views/pwb/ajax/contact_us_errors.js.erb`
- `app/views/pwb/ajax/request_info_success.js.erb`
- `app/views/pwb/ajax/request_info_errors.js.erb`

### Deprecated (with notices)
- `app/assets/javascripts/pwb/application.js.erb`
- `app/assets/javascripts/pwb/shared/page-content.js`
- `app/assets/javascripts/pwb/shared/slick-carousel.js`

## Testing Checklist

- [ ] Search page loads without errors
- [ ] Search form submits via AJAX
- [ ] Loading spinner appears during search
- [ ] Search results update correctly
- [ ] Map displays with markers
- [ ] Contact form submits successfully
- [ ] Success/error messages display correctly
- [ ] Mobile filter toggle works
