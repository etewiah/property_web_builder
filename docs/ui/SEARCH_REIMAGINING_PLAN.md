# Search Experience Reimagining Plan

## Executive Summary

This document outlines a comprehensive plan to reimagine the property search experience in PropertyWebBuilder. The goal is to create a modern, responsive search that:

1. **Preserves state in the URL** - Bookmarkable, shareable, browser-navigable searches
2. **Updates without full page reloads** - Instant, responsive filter changes
3. **Provides excellent UX** - Clear feedback, intuitive interactions, fast performance

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Proposed Architecture](#proposed-architecture)
3. [URL Schema Design](#url-schema-design)
4. [User Experience Design](#user-experience-design)
5. [Implementation Plan](#implementation-plan)
6. [Testing Strategy](#testing-strategy)
7. [Migration Path](#migration-path)

---

## Current State Analysis

### What Works
- Server-side filtering with robust query scoping
- SEO-friendly URL helper methods exist
- Faceted search service for counting matches
- Map integration with markers
- Stimulus controller for loading states

### What Doesn't Work

| Issue | Impact | Root Cause |
|-------|--------|------------|
| URL doesn't restore state | Users can't share/bookmark searches | POST-based AJAX, verbose param format |
| Full page feel during updates | Jarring UX, slow perceived performance | JS.erb template replacement |
| Filter changes require button click | Extra friction, not instant | Form-based submission model |
| Back button doesn't work | Navigation feels broken | History not properly managed |
| Map/results out of sync | Confusing UX | Separate update mechanisms |

### Current Technical Debt
- Uses `remote: true` (Rails UJS) - deprecated in favor of Turbo
- JS.erb templates are fragile and hard to test
- Hardcoded URLs in form actions (`/search_ajax_for_sale.js`)
- Mixed patterns: Stimulus + inline scripts + Rails UJS

---

## Proposed Architecture

### Option A: Turbo Frames + Turbo Drive (Recommended)

**Approach**: Use Rails 7 Turbo to handle navigation and partial updates.

```
┌─────────────────────────────────────────────────────────────────┐
│                         Browser                                  │
├─────────────────────────────────────────────────────────────────┤
│  URL State ←──→ Stimulus Controller ←──→ Turbo Frame            │
│     ↑                    ↑                     ↓                 │
│     └────── History API ─┘              Server Request           │
│                                               ↓                  │
│                                    ┌─────────────────┐           │
│                                    │ SearchController │           │
│                                    │  (HTML response) │           │
│                                    └─────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

**Benefits**:
- Progressive enhancement (works without JS)
- Server-rendered HTML (SEO-friendly)
- Built into Rails 7+
- Automatic history management

**Trade-offs**:
- Server round-trip for each filter change
- Requires Turbo gem (already installed)

### Option B: Full Client-Side with JSON API

**Approach**: Build a JSON API and render results with JavaScript.

**Benefits**:
- Instant client-side filtering for small datasets
- Can cache entire dataset locally
- Rich client interactions

**Trade-offs**:
- Requires separate JSON API
- More complex client code
- Not progressive enhancement
- SEO requires additional work

### Recommendation: **Option A (Turbo Frames)**

Turbo Frames is the recommended approach because:
1. Already have Turbo installed
2. Better SEO (server-rendered)
3. Progressive enhancement
4. Simpler implementation
5. Consistent with Rails conventions

---

## URL Schema Design

### Principles

1. **Human-readable** - `/buy?type=apartment&bedrooms=2`
2. **Concise** - Avoid verbose `search[param_name]` format
3. **Canonical** - Consistent ordering for SEO
4. **Restorable** - Full state from URL alone

### URL Structure

```
/{locale}/{operation}?{filters}&sort={sort}&view={view}

Examples:
/en/buy
/en/buy?type=apartment
/en/buy?type=apartment&bedrooms=2&price_min=100000&price_max=500000
/en/rent?type=villa&features=pool,sea-views&sort=price-asc
/es/comprar?tipo=apartamento&habitaciones=3
```

### Parameter Reference

| Parameter | Description | Format | Example |
|-----------|-------------|--------|---------|
| `type` | Property type | slug | `apartment`, `villa` |
| `bedrooms` | Min bedrooms | integer | `2` |
| `bathrooms` | Min bathrooms | integer | `1` |
| `price_min` | Minimum price | integer | `100000` |
| `price_max` | Maximum price | integer | `500000` |
| `features` | Features filter | comma-separated slugs | `pool,garden` |
| `zone` | Zone/region | slug | `costa-del-sol` |
| `locality` | City/town | slug | `marbella` |
| `sort` | Sort order | enum | `price-asc`, `price-desc`, `newest` |
| `view` | Results view | enum | `grid`, `list`, `map` |
| `page` | Pagination | integer | `1` |

### Parameter Normalization

All parameters should be:
- Lowercase
- Hyphenated (not underscored)
- Alphabetically sorted in canonical URLs

```ruby
# Canonical URL generation
/buy?bathrooms=1&bedrooms=2&features=garden,pool&type=apartment
```

---

## User Experience Design

### Interaction Model

```
┌────────────────────────────────────────────────────────────────┐
│                    SEARCH PAGE LAYOUT                          │
├────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐  ┌────────────────────────────────────┐   │
│ │   FILTER PANEL   │  │         RESULTS AREA               │   │
│ │                  │  │  ┌─────────────────────────────┐   │   │
│ │  Property Type   │  │  │ Results Header              │   │   │
│ │  [▼ Apartment ]  │  │  │ "24 apartments in Marbella" │   │   │
│ │                  │  │  │ Sort: [Price ▼] View: [□ ▤] │   │   │
│ │  Price Range     │  │  └─────────────────────────────┘   │   │
│ │  [€100k] - [€500k]│  │                                    │   │
│ │                  │  │  ┌─────┐ ┌─────┐ ┌─────┐           │   │
│ │  Bedrooms        │  │  │     │ │     │ │     │           │   │
│ │  [2+]            │  │  │ P1  │ │ P2  │ │ P3  │           │   │
│ │                  │  │  │     │ │     │ │     │           │   │
│ │  Location        │  │  └─────┘ └─────┘ └─────┘           │   │
│ │  [▼ Marbella  ]  │  │                                    │   │
│ │                  │  │  ┌─────┐ ┌─────┐ ┌─────┐           │   │
│ │  Features        │  │  │ P4  │ │ P5  │ │ P6  │           │   │
│ │  ☑ Pool          │  │  └─────┘ └─────┘ └─────┘           │   │
│ │  ☐ Garden        │  │                                    │   │
│ │  ☐ Sea Views     │  │  [Load More] or Pagination         │   │
│ │                  │  │                                    │   │
│ │  [Clear Filters] │  └────────────────────────────────────┘   │
│ └──────────────────┘                                           │
│                                                                │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │                    MAP VIEW (Collapsible)                  │ │
│ │                        🏠  🏠                               │ │
│ │                    🏠       🏠  🏠                          │ │
│ └────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

### Interaction Behaviors

#### Filter Changes
1. User changes a filter (dropdown, checkbox, slider)
2. URL updates immediately via `pushState`
3. Results area shows subtle loading indicator
4. Turbo Frame fetches new results
5. Results replace with smooth transition
6. Map markers update to match
7. Results count updates

#### URL Navigation
1. User lands on URL with parameters
2. Server renders page with filters applied
3. All filter controls reflect URL state
4. Results show filtered properties

#### Browser Back/Forward
1. User clicks back button
2. `popstate` event triggers
3. Turbo Drive handles navigation
4. Page state restores from URL

### Mobile Experience

```
┌──────────────────────────┐
│ ☰  SEARCH  🔍            │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ [Filters (3)]  [Map] │ │
│ └──────────────────────┘ │
│                          │
│ 24 properties found      │
│ Sort: Price ▼            │
│                          │
│ ┌──────────────────────┐ │
│ │                      │ │
│ │     Property 1       │ │
│ │                      │ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │     Property 2       │ │
│ └──────────────────────┘ │
│                          │
│ [Show More]              │
└──────────────────────────┘

Filter Panel (Slide-in):
┌──────────────────────────┐
│ ← Filters         Clear  │
├──────────────────────────┤
│ Property Type            │
│ [▼ Apartment        ]    │
│                          │
│ Price Range              │
│ €100,000 ─────●── €500k  │
│                          │
│ Bedrooms                 │
│ ○ Any ● 1+ ○ 2+ ○ 3+     │
│                          │
│ [Show 24 Properties]     │
└──────────────────────────┘
```

### Loading States

```
Filter Change:
┌─────────────────────┐
│ Results             │
│ ┌─────────────────┐ │
│ │ ░░░░░░░░░░░░░░░ │ │  ← Skeleton cards with pulse animation
│ │ ░░░░░░░░░░░░░░░ │ │
│ └─────────────────┘ │
│ ┌─────────────────┐ │
│ │ ░░░░░░░░░░░░░░░ │ │
│ └─────────────────┘ │
└─────────────────────┘

Or subtle overlay:
┌─────────────────────┐
│ Results    [⟳]      │  ← Small spinner in header
│ ┌─────────────────┐ │
│ │     Card 1      │ │  ← Content dimmed (opacity: 0.5)
│ └─────────────────┘ │
└─────────────────────┘
```

---

## Implementation Plan

### Phase 1: Foundation (Week 1)

#### 1.1 URL Parameter Service
Create a service to handle URL ↔ search params conversion.

```ruby
# app/services/pwb/search_params_service.rb
class Pwb::SearchParamsService
  # URL params → search criteria
  def from_url_params(params)

  # Search criteria → URL params (for links)
  def to_url_params(criteria)

  # Generate canonical URL
  def canonical_url(criteria, locale:)
end
```

#### 1.2 Turbo Frame Setup
Wrap results in a Turbo Frame.

```erb
<%# app/themes/*/views/pwb/search/buy.html.erb %>
<turbo-frame id="search-results" data-turbo-action="advance">
  <%= render 'search_results' %>
</turbo-frame>
```

#### 1.3 Stimulus Controller Rewrite
Replace current controller with URL-first approach.

```javascript
// app/javascript/controllers/search_controller.js
export default class extends Controller {
  static targets = ["form", "results", "filters"]

  filterChanged(event) {
    this.updateUrl()
    this.fetchResults()
  }

  updateUrl() {
    const params = this.buildParams()
    history.pushState({}, '', `${location.pathname}?${params}`)
  }

  fetchResults() {
    // Turbo.visit or fetch to turbo-frame
  }
}
```

### Phase 2: Core Features (Week 2)

#### 2.1 Instant Filtering
- Debounced filter changes (300ms)
- Automatic submission on select change
- Range sliders for price

#### 2.2 Results Header
- Result count with filter summary
- Sort controls
- View toggle (grid/list/map)

#### 2.3 Map Synchronization
- Map updates when results change
- Clicking marker highlights card
- Clicking card pans to marker

### Phase 3: Polish (Week 3)

#### 3.1 Animations & Transitions
- Smooth results fade/slide
- Filter panel animations
- Loading skeletons

#### 3.2 Mobile Optimization
- Bottom sheet filter panel
- Touch-friendly controls
- Infinite scroll option

#### 3.3 Performance
- Request debouncing
- Result caching
- Lazy load images

---

## File Structure

```
app/
├── controllers/
│   └── pwb/
│       └── search_controller.rb          # Updated controller
├── services/
│   └── pwb/
│       └── search_params_service.rb      # NEW: URL ↔ params
├── javascript/
│   └── controllers/
│       ├── search_controller.js          # NEW: Main search controller
│       ├── search_filters_controller.js  # NEW: Filter panel
│       ├── search_map_controller.js      # NEW: Map integration
│       └── search_results_controller.js  # NEW: Results grid
├── views/
│   └── pwb/
│       └── search/
│           ├── buy.html.erb              # Updated with Turbo Frame
│           ├── rent.html.erb             # Updated with Turbo Frame
│           ├── _results_frame.html.erb   # NEW: Turbo Frame wrapper
│           ├── _results_header.html.erb  # NEW: Count, sort, view
│           ├── _results_grid.html.erb    # NEW: Grid layout
│           ├── _filter_panel.html.erb    # NEW: Filter controls
│           └── _property_card.html.erb   # Updated card component
└── themes/
    └── */
        └── views/
            └── pwb/
                └── search/               # Theme overrides
```

---

## Testing Strategy

### Unit Tests

```ruby
# spec/services/pwb/search_params_service_spec.rb
RSpec.describe Pwb::SearchParamsService do
  describe '#from_url_params' do
    it 'parses type parameter'
    it 'parses numeric bedrooms'
    it 'parses comma-separated features'
    it 'ignores unknown parameters'
  end

  describe '#to_url_params' do
    it 'generates clean URL params'
    it 'omits empty values'
    it 'sorts params alphabetically'
  end

  describe '#canonical_url' do
    it 'generates consistent URLs'
    it 'includes locale prefix'
  end
end
```

### Integration Tests

```ruby
# spec/requests/pwb/search_spec.rb
RSpec.describe 'Property Search', type: :request do
  describe 'GET /buy' do
    it 'renders search page'
    it 'applies URL filters'
    it 'returns correct results count'
  end

  describe 'GET /buy with Turbo Frame' do
    it 'returns only frame content'
    it 'updates results based on params'
  end
end
```

### System Tests (Playwright)

```javascript
// spec/system/search_spec.js
describe('Property Search', () => {
  test('URL updates when filter changes', async () => {
    await page.goto('/buy')
    await page.selectOption('#property-type', 'apartment')
    expect(page.url()).toContain('type=apartment')
  })

  test('Results update without reload', async () => {
    await page.goto('/buy')
    const initialCount = await page.$eval('.results-count', el => el.textContent)
    await page.selectOption('#property-type', 'apartment')
    await page.waitForSelector('.results-count:not(:has-text("' + initialCount + '"))')
  })

  test('Back button restores previous search', async () => {
    await page.goto('/buy')
    await page.selectOption('#property-type', 'apartment')
    await page.goBack()
    expect(page.url()).not.toContain('type=')
  })
})
```

### Visual Regression Tests

```javascript
// Test consistent rendering across filter states
test('search results visual regression', async () => {
  await page.goto('/buy?type=apartment&bedrooms=2')
  await expect(page).toHaveScreenshot('search-filtered.png')
})
```

---

## Migration Path

### Phase 1: Parallel Implementation
1. Create new URL parameter handling alongside old
2. Support both URL formats temporarily
3. Add feature flag for new search

### Phase 2: Gradual Rollout
1. Enable for one theme (bologna)
2. Monitor for issues
3. Roll out to other themes

### Phase 3: Deprecation
1. Redirect old URL format to new
2. Remove legacy code
3. Update documentation

### Backwards Compatibility

```ruby
# Support both old and new URL formats during transition
def normalize_params
  if params[:search].present?
    # Old format: search[property_type]=apartment
    legacy_to_new_params(params[:search])
  else
    # New format: type=apartment
    params
  end
end
```

---

## Success Metrics

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| Time to first filter result | ~800ms | <400ms | Performance monitoring |
| URL state restoration | 0% | 100% | Automated testing |
| Back button works | No | Yes | Automated testing |
| Mobile filter usability | Poor | Excellent | User testing |
| Search page bounce rate | ? | -20% | Analytics |
| Search → detail conversion | ? | +15% | Analytics |

---

## Appendix: Wireframes

### Desktop Wireframe

See: `docs/ui/wireframes/search-desktop.svg`

### Mobile Wireframe

See: `docs/ui/wireframes/search-mobile.svg`

### Component Library

See: `docs/ui/wireframes/search-components.svg`

---

**Document Version:** 1.0
**Created:** 2024-12-24
**Author:** Claude Code
**Status:** Draft - Pending Review
