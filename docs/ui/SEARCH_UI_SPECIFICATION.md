# Search UI Specification

This document defines the expected behavior of the property search functionality in PropertyWebBuilder. Use this specification to identify bugs, inconsistencies, and areas for improvement.

---

## Table of Contents

1. [Overview](#overview)
2. [Search Pages](#search-pages)
3. [Search Form](#search-form)
4. [Search Results](#search-results)
5. [Property Cards](#property-cards)
6. [Map Integration](#map-integration)
7. [AJAX Behavior](#ajax-behavior)
8. [Known Issues](#known-issues)
9. [Test Scenarios](#test-scenarios)

---

## Overview

### Routes

| Route | Controller Action | Purpose |
|-------|------------------|---------|
| `GET /buy` or `GET /:locale/buy` | `Pwb::SearchController#buy` | Properties for sale |
| `GET /rent` or `GET /:locale/rent` | `Pwb::SearchController#rent` | Properties for rent |
| `POST /search_ajax_for_sale.js` | `Pwb::SearchController#search_ajax_for_sale` | AJAX filter for sale |
| `POST /search_ajax_for_rent.js` | `Pwb::SearchController#search_ajax_for_rent` | AJAX filter for rent |

### Themes

Three themes implement search pages with varying designs:
- **default** - Tailwind CSS based, clean modern design
- **brisbane** - Tailwind CSS, blue accent colors
- **bologna** - Tailwind CSS, warm terra cotta/olive palette

### Technology Stack

- **Stimulus.js** - All JavaScript interactions (filter toggles, form handling)
- **Leaflet** - Map rendering with OpenStreetMap tiles
- **Rails UJS** - AJAX form submissions (`remote: true`)
- **Vanilla JavaScript** - AJAX response handling (no jQuery)

> **Note**: Vue.js and jQuery have been fully removed from search functionality.

---

## Search Pages

### Page Structure

```
+--------------------------------------------------+
|  Header / Navigation                             |
+--------------------------------------------------+
|  Breadcrumb (Home > Buy/Rent)                    |
+--------------------------------------------------+
|  Page Title & Badge                              |
+--------------------------------------------------+
|           |                                      |
|  Sidebar  |  Search Results                      |
|  Filters  |  - Loading Spinner (hidden)          |
|  (1/4)    |  - Property Cards Grid               |
|           |  (3/4 width)                         |
+--------------------------------------------------+
|  Map Section (if markers exist)                  |
+--------------------------------------------------+
|  Footer                                          |
+--------------------------------------------------+
```

### Responsive Layout Requirements

**CRITICAL: On large screens (≥1024px), search filters MUST display BESIDE search results, NOT above them taking full page width.**

#### Desktop Layout (≥1024px / lg breakpoint)

| Element | Width | Classes |
|---------|-------|---------|
| Container | 100% | `flex flex-wrap` |
| Sidebar | 25% | `w-full lg:w-1/4` |
| Results | 75% | `w-full lg:w-3/4` |

#### Mobile Layout (<1024px)

| Element | Width | Classes |
|---------|-------|---------|
| Filter toggle | visible | `lg:hidden` |
| Sidebar | hidden | `hidden lg:block` |
| Results | 100% | `w-full` |

### Expected Behaviors

#### Page Load
- [ ] Page displays with filter form in sidebar
- [ ] **On large screens (≥1024px): Filters display BESIDE results (side-by-side)**
- [ ] **On mobile (<1024px): Filters hidden with toggle button**
- [ ] Search results render server-side (not via JavaScript injection)
- [ ] Map section displays only if `@map_markers.length > 0`
- [ ] Page title includes page title + company name
- [ ] SEO meta tags are set appropriately

#### Mobile Responsiveness
- [ ] Sidebar filters collapse on mobile (< lg breakpoint)
- [ ] "Filter Properties" button shows on mobile to toggle filters
- [ ] Results display full width on mobile
- [ ] Property cards stack vertically on mobile

#### Large Screen Responsiveness
- [ ] **Filters and results display side-by-side (NOT stacked)**
- [ ] Sidebar takes 1/4 (25%) of content width
- [ ] Results take 3/4 (75%) of content width
- [ ] Optional: Sidebar may use `sticky top-28` for long result lists

---

## Search Form

### Available Filters

| Filter | Field Name | Type | Scope |
|--------|-----------|------|-------|
| Price From | `search[for_sale_price_from]` or `search[for_rent_price_from]` | Select | Price range start |
| Price To | `search[for_sale_price_till]` or `search[for_rent_price_till]` | Select | Price range end |
| Property Type | `search[property_type]` | Select | `prop_type_key` filter |
| Zone | `search[in_zone]` | Select | Geographic zone (if available) |
| Locality | `search[in_locality]` | Select | City/town (if available) |
| Bedrooms | `search[count_bedrooms]` | Select (0-50) | Minimum bedrooms |
| Bathrooms | `search[count_bathrooms]` | Select (0-20) | Minimum bathrooms |
| Features | `search[features][]` | Checkboxes | Feature filters (AND/OR) |
| Features Match | `search[features_match]` | Select | `all` or `any` |

### Expected Behaviors

#### Form Submission
- [ ] Form submits via AJAX (remote: true)
- [ ] Loading spinner appears during submission
- [ ] Results container gets opacity-50 class during loading
- [ ] Results update without full page reload
- [ ] Map markers update after AJAX response

#### Filter Persistence
- [ ] Selected filter values persist after AJAX submission
- [ ] URL-friendly parameters work: `/buy?type=apartment&features=pool,garden`
- [ ] Direct URL access with filters returns correct results

#### Clear Filters
- [ ] "Clear Filters" button appears when no results found
- [ ] Clicking clears all form inputs
- [ ] Form resubmits after clearing

---

## Search Results

### Results Container

The results are rendered into `#inmo-search-results` container.

### Expected Behaviors

#### With Results
- [ ] Properties display in a grid/list format
- [ ] Maximum 45 properties shown (limit in controller)
- [ ] Results ordered by relevance/default sort
- [ ] Client-side sorting available via `INMOAPP.sortSearchResults()`
- [ ] Each property links to detail page

#### No Results
- [ ] "No results found" message displays
- [ ] Search icon visual indicator
- [ ] "Try changing your filters" helper text
- [ ] "Clear Filters" button displayed

#### Pagination
- [ ] **ISSUE**: Pagination UI exists but is hidden (`display:none`)
- [ ] Pagination not currently functional
- [ ] Limit of 45 results may truncate actual results

---

## Property Cards

### Card Structure

```
+------------------------------------------+
| [Featured Badge - if highlighted]        |
+------------------------------------------+
| +--------+  Title (linked)               |
| | Photo  |  Reference Number             |
| | (1/3)  |                               |
| |        |  [Beds] [Baths] [Area] [Cars] |
| +--------+  --------------------------   |
|             Price        [View Details]  |
+------------------------------------------+
```

### Data Display

| Field | Source | Format |
|-------|--------|--------|
| Photo | `property.ordered_photo(1)` | Optimized, height 240, lazy loaded |
| Title | `property.title` | Linked to detail page |
| Reference | `property.reference` | Plain text |
| Bedrooms | `property.count_bedrooms` | Icon + number |
| Bathrooms | `property.count_bathrooms` | Icon + number |
| Area | `property.constructed_area` | Number + unit (m2/sq ft) |
| Garages | `property.count_garages` | Icon + number (if > 0) |
| Price | `property.contextual_price_with_currency(@operation_type)` | Currency formatted |

### Expected Behaviors

#### Highlighted Properties
- [ ] "Featured" or "Highlighted" badge displays
- [ ] Visual distinction (different styling/ribbon)
- [ ] Price may appear in ribbon for highlighted properties

#### Photo Handling
- [ ] Lazy loading enabled (`loading: "lazy"`)
- [ ] Fallback alt text: "Property listing"
- [ ] Click on photo navigates to property detail

#### Links
- [ ] Title links to contextual show path (buy vs rent URL)
- [ ] "View Details" button links to same path
- [ ] Links respect operation type for URL generation

#### Caching
- [ ] Fragment caching with cache key based on property + photos update time
- [ ] Cache key: `property_card_cache_key(property, @operation_type)`

---

## Map Integration

### Map Library

Uses **Leaflet** with OpenStreetMap tiles.

### Map Marker Data Structure

```javascript
{
  id: property.id,
  title: "Property Title",
  show_url: "/en/properties/123",
  image_url: "https://cdn.../image.jpg",
  display_price: "$500,000",
  position: {
    lat: 40.7128,
    lng: -74.0060
  }
}
```

### Expected Behaviors

#### Map Display
- [ ] Map only renders if `@map_markers.length > 0`
- [ ] Map height: 500-600px depending on theme
- [ ] All markers fit within initial view (`fitBounds`)
- [ ] Maximum zoom level: 15 (prevents over-zooming on single marker)

#### Markers
- [ ] Custom marker styling per theme (e.g., terra cotta for Bologna)
- [ ] Default Leaflet markers as fallback
- [ ] Click marker shows popup with property info

#### Marker Popup Content
- [ ] Property image (if available)
- [ ] Property title (linked to detail page)
- [ ] Price display
- [ ] Styled appropriately for theme

#### AJAX Updates
- [ ] Map markers update via Stimulus controller when filters change
- [ ] Custom `search:updated` event is dispatched for coordination

---

## AJAX Behavior

### Request Flow

1. User changes filter or clicks Search
2. Form submits via Rails UJS (`remote: true`)
3. Server processes and returns `search_ajax.js.erb`
4. JavaScript updates `#inmo-search-results` and map markers

### Current AJAX Response (`search_ajax.js.erb`)

```javascript
// Update search results (vanilla JS - no jQuery)
(function() {
  var resultsContainer = document.getElementById('inmo-search-results');
  if (resultsContainer) {
    resultsContainer.innerHTML = "<%= j (render 'search_results') %>";
  }

  // Update map markers if map controller exists
  var markers = <%= @map_markers.to_json.html_safe %>;
  var mapElement = document.querySelector('[data-controller~="map"]');
  if (mapElement && mapElement.mapController) {
    mapElement.mapController.updateMarkers(markers);
  }

  // Trigger custom event for Stimulus controllers to react
  document.dispatchEvent(new CustomEvent('search:updated', {
    detail: { markers: markers }
  }));
})();
```

### Expected Behaviors

- [ ] Results HTML replaced atomically using vanilla JavaScript
- [ ] Map markers updated via Stimulus controller
- [ ] Custom event dispatched for other Stimulus controllers to react

---

## Known Issues

### Moderate

| Issue | Description | Location |
|-------|-------------|----------|
| 45 Result Limit | No pagination means results are capped | `search_controller.rb:55` |
| Pagination Hidden | Pagination exists but is `display:none` | `_search_results.html.erb:22` |

### Minor

| Issue | Description | Location |
|-------|-------------|----------|
| Description Truncation | `truncated_description` div is `display:none` | `_search_result_item.html.erb:31` |

---

## Test Scenarios

### Manual Test Checklist

#### Basic Search Flow
- [ ] Navigate to `/buy` - page loads with properties
- [ ] Navigate to `/rent` - page loads with rental properties
- [ ] Select property type filter - results update
- [ ] Select price range - results filter correctly
- [ ] Select bedroom count - results filter correctly
- [ ] Combine multiple filters - AND logic works

#### Empty States
- [ ] Set impossible filter combination - "No results" message appears
- [ ] Click "Clear Filters" - filters reset and results return

#### Property Cards
- [ ] Click property title - navigates to correct detail page
- [ ] Click property image - navigates to correct detail page
- [ ] Click "View Details" - navigates to correct detail page
- [ ] Verify price displays correctly formatted
- [ ] Verify bedroom/bathroom counts display

#### Map
- [ ] Map displays when properties have coordinates
- [ ] Click marker - popup shows with property info
- [ ] Click popup link - navigates to property
- [ ] Filter changes - map markers should update

#### Mobile
- [ ] Resize to mobile width
- [ ] Filters collapse to button
- [ ] Click filter button - filters show
- [ ] Submit search - works on mobile

#### URL Parameters
- [ ] Access `/buy?search[property_type]=types.apartment` - filters applied
- [ ] Access `/buy?type=apartment` - friendly URL works
- [ ] Bookmark filtered URL - returns same results

---

## Recommended Fixes

### Priority 1 - Important

1. **Implement Pagination**: Enable functional pagination or infinite scroll to handle more than 45 results

### Priority 2 - Nice to Have

2. **Add Result Count**: Show "X properties found"
3. **Add Sort Controls**: UI for price/date sorting

---

**Document Version:** 1.1
**Created:** 2024-12-22
**Updated:** 2024-12-24
**Based on:** Current codebase analysis

### Changelog
- **1.1** (2024-12-24): Removed Vue.js and jQuery references. Updated AJAX implementation to reflect vanilla JS approach with Stimulus controllers.
