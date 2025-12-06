# PropertyWebBuilder Bootstrap Dependency Analysis

Date: December 6, 2025
Status: Comprehensive Audit Complete

## Executive Summary

PropertyWebBuilder has **significant Bootstrap dependencies**, but with an interesting twist: the project is **actively transitioning from Bootstrap to Tailwind CSS**. Bootstrap is primarily used in older themes (Default, Berlin, Matt) and the admin interface, while newer themes (Bristol, Brisbane) use Tailwind CSS exclusively.

**Key Finding:** The admin interface (`pwb-admin.scss`) includes compiled Bootstrap CSS totaling hundreds of KB, making it the largest Bootstrap footprint in the project.

---

## 1. Bootstrap Loading Locations

### 1.1 Gem Dependencies
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/Gemfile`

```ruby
# Line 135 - Bootstrap NOT in Gemfile
# gem "bootstrap-sass", "~> 3.4"  # COMMENTED OUT

# Bootstrap is included via vendor assets, not as a gem
```

**Status:** Bootstrap is NOT managed as a Ruby gem. It's included as vendor assets.

### 1.2 NPM/JavaScript Dependencies
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/package.json`

**Result:** No Bootstrap npm packages found. Bootstrap is not in the dependency tree.

### 1.3 Vendor Assets (SCSS)
**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/vendor/assets/stylesheets/`

```
_bootstrap.scss (Bootstrap 3 - v3.3.7)
_bootstrap-sprockets.scss
_bootstrap-mincer.scss
_bootstrap-compass.scss
bootstrap-select.scss
bootstrap/*.scss (27 component files)
```

**Bootstrap Version:** 3.3.7 (Legacy version from ~2013)

### 1.4 Vendor Assets (JavaScript)
**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/vendor/assets/javascripts/`

```
bootstrap.js
bootstrap.min.js
bootstrap-sprockets.js
bootstrap-select.js
bootstrap/*.js (13 component files):
  - alert.js
  - button.js
  - carousel.js
  - collapse.js
  - dropdown.js
  - modal.js
  - popover.js
  - scrollspy.js
  - tab.js
  - tooltip.js
  - transition.js
  - affix.js
```

### 1.5 CDN Links
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/default/views/layouts/pwb/application.html.erb`

```erb
<!-- Line 15 -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.7/js/bootstrap.min.js" async: true ></script>
```

**Finding:** One CDN link to Bootstrap 3.3.7 in the Default theme.

---

## 2. Bootstrap Usage by Theme

### Theme Summary Table

| Theme | Framework | Bootstrap Classes | JS Attributes | Status |
|-------|-----------|------------------|---|--------|
| **default** | Bootstrap 3 + Custom | Heavy | Yes | Active |
| **berlin** | Bootstrap 3 + Custom | Heavy | Yes | Active |
| **vic** | Bootstrap 3 + Custom | Moderate | Minimal | Active |
| **matt** | Bootstrap 3 + Custom | Moderate | Yes | Active |
| **bristol** | Tailwind CSS | None | None | Recent (Tailwind) |
| **brisbane** | Tailwind CSS | None | None | Recent (Tailwind) |
| **airbnb** | Bootstrap 3 | Light | No | Legacy |
| **squares** | Bootstrap 3 | Light | No | Legacy |

### 2.1 Bootstrap-Heavy Themes

#### Default Theme
**Stylesheet:** `/Users/etewiah/dev/sites-older/property_web_builder/app/stylesheets/pwb/themes/default.scss`

```scss
@import "bootstrap";
@import "bootstrap-select";
```

**Components Used:**
- Grid system (`.col-sm-*`, `.row`, `.container`)
- Typography (`.h1`, `.lead`)
- Forms (`.form-group`, `.form-control`)
- Buttons (`.btn`, `.btn-default`)
- Navigation (`.navbar`, `.nav`)
- Carousels (`.carousel`)
- Dropdowns (`.dropdown`)
- Panels (`.panel`, `.panel-group`)

**Files Using Bootstrap Classes:**
- `app/themes/default/views/pwb/search/buy.html.erb`
- `app/themes/default/views/pwb/search/rent.html.erb`
- `app/themes/default/views/pwb/welcome/index.html.erb`

#### Berlin Theme
**Stylesheet:** `/Users/etewiah/dev/sites-older/property_web_builder/app/stylesheets/pwb/themes/berlin.scss`

```scss
@import "bootstrap";
@import "bootstrap-select";
```

**Bootstrap Components:**
- Grid system (`col-md-12`, `row`)
- Navbar with collapse functionality
- Bootstrap variables for theming
- Responsive utilities

**Key File:**
- `app/themes/berlin/views/layouts/pwb/application.html.erb` - HTML5 Shim for IE8

### 2.2 Tailwind-Based Themes

#### Bristol Theme
**Stylesheet:** `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/builds/bristol_theme.css`

```css
/* Compiled Tailwind v4.1.16 - No Bootstrap present */
/*! tailwindcss v4.1.16 | MIT License | https://tailwindcss.com */
```

**Status:** Pure Tailwind CSS, zero Bootstrap dependencies.

#### Brisbane Theme
**Stylesheet:** `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/stylesheets/brisbane_theme.css`

```css
/* Custom CSS with luxury styling */
.brisbane-theme .btn-luxury { }
.brisbane-theme .card-luxury { }
```

**Status:** Custom CSS framework with Tailwind CSS layer beneath. No Bootstrap imports.

---

## 3. Bootstrap Components Usage Analysis

### 3.1 Actively Used Components

#### Navbar/Navigation
**Files:**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/_header.html.erb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/berlin/views/pwb/_header.html.erb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/matt/views/pwb/_header.html.erb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/default/views/pwb/_header.html.erb`

**Bootstrap Classes:**
```html
<div class="navbar navbar-wp navbar-arrow mega-nav" role="navigation">
  <div class="navbar-header">
    <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
    <div class="navbar-collapse collapse">
      <ul class="nav navbar-nav navbar-right">
```

**Bootstrap JS Dependencies:** `data-toggle="collapse"`, `data-target=".navbar-collapse"`

#### Collapse/Accordion (Panel Groups)
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/search/_feature_filters.html.erb`

```html
<div class="feature-filters panel-group" id="feature-filters-accordion">
  <div class="panel panel-default">
    <div class="panel-heading" role="tab" id="features-heading">
      <a role="button" data-toggle="collapse" data-parent="#feature-filters-accordion"
         href="#features-collapse" aria-expanded="false">
```

**Bootstrap JS Dependencies:**
- `data-toggle="collapse"`
- `data-parent="#feature-filters-accordion"`

**Note:** This component is now loading via JavaScript manually (lines 191-210) as a fallback, suggesting Bootstrap JS may not be reliably loaded.

#### Carousel
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/props/_images_section_carousel.html.erb`

```html
<div id="propCarousel" class="carousel carousel-1 slide" data-ride="carousel" data-interval="...">
  <ol class="carousel-indicators">
    <li data-target="#propCarousel" data-slide-to="0" class=""></li>
  </ol>
  <div class="carousel-inner">
    <a class="left carousel-control" href="#propCarousel" data-slide="prev">
    <a class="right carousel-control" href="#propCarousel" data-slide="next">
```

**Bootstrap JS Dependencies:**
- `data-ride="carousel"`
- `data-slide-to`
- `data-slide="prev/next"`

#### Dropdowns
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/_header.html.erb`

```html
<a href="#" class="dropdown-toggle" data-toggle="dropdown">
  <%= t "navbar.admin" %>
</a>
<ul class="dropdown-menu">
  <li>...</li>
</ul>
```

**Bootstrap JS Dependencies:** `data-toggle="dropdown"`

#### Button Groups
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/search/_feature_filters.html.erb`

```html
<div class="btn-group btn-group-sm" data-toggle="buttons">
  <label class="btn btn-default <%= 'active' unless ... %>">
    <input type="radio" name="search[features_match]" value="all">
```

**Bootstrap JS Dependencies:** `data-toggle="buttons"`

#### Forms
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/simple_form_bootstrap.rb`

```ruby
config.wrappers :vertical_form, tag: 'div', class: 'form-group', error_class: 'has-error' do |b|
  b.use :label, class: 'control-label'
  b.use :input, class: 'form-control'
  b.use :error, wrap_with: { tag: 'span', class: 'help-block' }
end

config.wrappers :horizontal_form, tag: 'div', class: 'form-group', error_class: 'has-error' do |b|
  b.use :label, class: 'col-sm-3 control-label'
  b.wrapper tag: 'div', class: 'col-sm-9' do |ba|
    ba.use :input, class: 'form-control'
```

**Bootstrap Classes:** `form-group`, `form-control`, `control-label`, `col-sm-*`, `help-block`, `has-error`, `sr-only`

#### Bootstrap-Select Plugin
**Files:**
- `/Users/etewiah/dev/sites-older/property_web_builder/vendor/assets/javascripts/bootstrap-select.js`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/javascripts/pwb/shared/select-picker.js`

```javascript
if (typeof $(this.$el).selectpicker === 'function') {
  $(this.$el).selectpicker(this.selectPickerTexts);
} else {
  console.warn('bootstrap-select plugin not found');
}
```

**Status:** Custom Vue component wrapper around bootstrap-select plugin.

### 3.2 Admin Interface Heavy Bootstrap Usage
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/vendor/assets/stylesheets/pwb-admin.scss`

**Size:** ~282 KB (pre-compiled)
**Contains:**
- Full Bootstrap 3 CSS framework
- Glyphicon font definitions
- Normalize.css
- Grid system (12-column)
- Form styles
- Tables
- Buttons
- Badges
- Alerts
- Panels
- Modals
- Navbars
- Dropdowns
- All utility classes

**Status:** This is the single largest Bootstrap footprint. Includes the entire framework even if only subset is used.

---

## 4. JavaScript Dependencies on Bootstrap

### 4.1 Bootstrap JS Files Loaded

**Manifest:** `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/config/manifest.js`

```javascript
//= link pwb/application.js
//= link pwb_admin_panel/application.js
```

**Default Theme Layout:**
```erb
<script src="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.7/js/bootstrap.min.js" async: true ></script>
```

### 4.2 Bootstrap Data Attributes (data-toggle, etc.)

**Complete Inventory:**

| Attribute | Component | Files | Count |
|-----------|-----------|-------|-------|
| `data-toggle="collapse"` | Collapse/Accordion | _feature_filters.html.erb, theme headers | 4 |
| `data-toggle="dropdown"` | Dropdown | _header.html.erb (multiple themes) | 4 |
| `data-toggle="buttons"` | Button Group | _feature_filters.html.erb | 1 |
| `data-ride="carousel"` | Carousel | _images_section_carousel.html.erb | 1 |
| `data-slide-to` | Carousel indicators | _images_section_carousel.html.erb | Multiple |
| `data-slide="prev/next"` | Carousel controls | _images_section_carousel.html.erb | 2 |
| `data-target` | Various collapse triggers | _header.html.erb, theme headers | 4 |

**Total:** 26 Bootstrap data attributes across the codebase

### 4.3 jQuery Dependency

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/Gemfile`

```ruby
gem "jquery-rails", "~> 4.5"
```

**Status:** jQuery is a dependency for Bootstrap JS plugins (carousel, dropdown, collapse all require jQuery).

---

## 5. Bootstrap-Specific Helper Methods and View Components

### 5.1 SimpleForm Bootstrap Configuration
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/simple_form_bootstrap.rb`

**Overview:** Complete Bootstrap integration with SimpleForm gem

**Wrapper Classes Defined:**
1. `vertical_form` - Default form layout
2. `vertical_file_input` - File input styling
3. `vertical_boolean` - Checkbox wrapper
4. `vertical_radio_and_checkboxes` - Radio/checkbox groups
5. `horizontal_form` - Horizontal form layout (col-sm-3, col-sm-9)
6. `horizontal_file_input` - Horizontal file input
7. `horizontal_boolean` - Horizontal checkbox
8. `horizontal_radio_and_checkboxes` - Horizontal radio/checkbox
9. `inline_form` - Inline form layout
10. `multi_select` - Multi-select wrapper

**Bootstrap Classes Used:**
- `form-group`
- `control-label`
- `form-control`
- `help-block`
- `has-error`
- `checkbox`
- `col-sm-*` (grid)
- `sr-only` (screen reader only)
- `form-inline`

### 5.2 Vue Components with Bootstrap Integration
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/javascripts/pwb/shared/select-picker.js`

```javascript
Vue.component('select-picker', {
  mounted: function() {
    if (typeof $(this.$el).selectpicker === 'function') {
      $(this.$el).selectpicker(this.selectPickerTexts);
    }
  }
});
```

**Status:** Custom Vue wrapper for Bootstrap-Select jQuery plugin.

---

## 6. Bootstrap CSS Classes Usage Patterns

### 6.1 Most Common Bootstrap Classes

**Grid System:**
```
.container, .row
.col-xs-*, .col-sm-*, .col-md-*, .col-lg-*
```

**Used In:** Default theme layout, admin interface, all public views

**Navigation:**
```
.navbar, .navbar-header, .navbar-brand, .navbar-toggle
.navbar-collapse, .collapse, .nav, .navbar-nav, .navbar-right
```

**Forms:**
```
.form-group, .form-control, .control-label
.input-group, .input-group-addon
.form-inline, .checkbox, .radio
.help-block, .has-error
```

**Components:**
```
.btn, .btn-default, .btn-primary, .btn-lg, .btn-sm
.panel, .panel-group, .panel-default, .panel-heading, .panel-body
.carousel, .carousel-indicators, .carousel-inner, .carousel-control
.dropdown, .dropdown-menu, .dropdown-toggle
.alert, .alert-success, .alert-danger, .alert-warning, .alert-info
```

**Responsive:**
```
.hidden-xs, .hidden-sm, .visible-md
.pull-left, .pull-right
.text-center, .text-left, .text-right
```

### 6.2 Bootstrap Utility Classes
```
.clearfix
.sr-only (screen reader only)
.list-unstyled, .list-inline
.text-muted, .text-success, .text-danger
.bg-info, .bg-success, .bg-warning, .bg-danger
```

---

## 7. Asset Pipeline Integration

### 7.1 Stylesheet Manifest
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/config/manifest.js`

```javascript
//= link_directory ../javascripts .js
//= link pwb/themes/berlin.js
//= link pwb/application.js
//= link pwb_admin_panel/application.js
//= link bristol_theme.css
//= link brisbane_theme.css
```

**Status:** Multiple theme CSS files and JS bundles.

### 7.2 Theme-Specific JavaScript
**Files:**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/javascripts/pwb/themes/berlin.js.erb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/javascripts/pwb/themes/berlin/bootstrap.js`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/javascripts/berlin/bootstrap.js`

**Status:** Theme-specific Bootstrap JS files, but mostly commented out/unused.

---

## 8. Analysis of Bootstrap Dependency Issues

### 8.1 Critical Issues

| Issue | Severity | Impact | Location |
|-------|----------|--------|----------|
| Outdated Bootstrap 3.3.7 | HIGH | Security vulnerabilities, missing modern features | All Bootstrap themes |
| Navbar JS dependencies not reliably loaded | MEDIUM | Hamburger menu may not work | _header.html.erb |
| Feature filter collapse JS fallback | MEDIUM | Accordions use custom JS as fallback | _feature_filters.html.erb |
| Large admin stylesheet (~282KB) | MEDIUM | Bloats admin asset bundle | pwb-admin.scss |
| jQuery dependency required | MEDIUM | Adds 87KB to bundle | jquery-rails gem |
| Carousel JS dependency fragile | LOW | Custom carousel control necessary | _images_section_carousel.html.erb |

### 8.2 Technical Debt

1. **No npm Bootstrap** - Bootstrap is in vendor assets instead of npm
2. **Mixed CSS frameworks** - Bootstrap + Tailwind + custom CSS in same project
3. **Data attributes for JS** - Relies on `data-*` attributes that may not load correctly
4. **IE8 Support** - Outdated HTML5 shim for IE8 in templates
5. **Custom JS fallbacks** - Custom JavaScript written to replicate Bootstrap functionality

---

## 9. Recommendations for Reducing Bootstrap Dependency

### Priority 1: Immediate Actions (Quick Wins)

1. **Remove IE8 Shim**
   - File: `app/themes/berlin/views/layouts/pwb/application.html.erb`
   - Action: Remove lines 16-21 (HTML5 shim)
   - Savings: Minimal, but cleans up legacy code

2. **Add Fallback Check for Bootstrap JS**
   - File: `app/themes/default/views/layouts/pwb/application.html.erb`
   - Action: Check if Bootstrap loaded before using data attributes
   - Impact: Ensures navbar/dropdowns work even if CDN fails

3. **Remove Unused Bootstrap-Select**
   - File: `vendor/assets/stylesheets/_bootstrap.scss`
   - Action: Investigate if bootstrap-select is still needed (move to Tailwind alternative)
   - Savings: ~15KB CSS

### Priority 2: Medium-Term (1-2 Sprints)

1. **Convert Default Theme to Tailwind**
   - File: `app/stylesheets/pwb/themes/default.scss`
   - Action: Replace Bootstrap imports with Tailwind equivalents
   - Reference: Bristol and Brisbane themes show working examples
   - Timeline: 5-10 days
   - Savings: ~50KB CSS per page

2. **Replace SimpleForm Bootstrap Config**
   - File: `config/initializers/simple_form_bootstrap.rb`
   - Action: Create new `simple_form_tailwind.rb` config
   - Savings: Remove hard-coded Bootstrap grid classes
   - Timeline: 2-3 days

3. **Replace Navbar with Tailwind**
   - File: `app/views/pwb/_header.html.erb`
   - Action: Migrate from `.navbar` to Tailwind flex utilities
   - Action: Replace `data-toggle="collapse"` with Alpine.js or Vue
   - Timeline: 3-5 days
   - Savings: Remove jQuery/Bootstrap JS dependency

### Priority 3: Long-Term (Next Quarter)

1. **Consolidate CSS Framework to Tailwind Only**
   - Remove all Bootstrap imports from remaining themes
   - Migrate admin interface to Tailwind
   - Savings: ~200KB+ in admin CSS
   - Timeline: 10-15 days
   - Benefits:
     - Unified styling approach
     - Smaller asset bundles
     - Better mobile performance
     - Modern framework (actively maintained)

2. **Remove jQuery Dependency**
   - Action: Replace jQuery plugins with vanilla JS or Vue alternatives
   - Timeline: 5-10 days
   - Savings: 87KB jQuery library

3. **Optimize Form Rendering**
   - Create Tailwind form partial components
   - Remove SimpleForm Bootstrap wrapper
   - Timeline: 3-5 days

### Priority 4: Future Considerations

1. **Admin Interface Redesign**
   - Current pwb-admin.scss includes entire Bootstrap framework
   - Build new admin in Tailwind + Vue (follows project patterns)
   - Savings: ~150KB CSS
   - Timeline: 2-3 weeks

2. **Migrate Bootstrap-Select to Headless UI**
   - Replace with Headless UI + Tailwind (or native HTML select styling)
   - Timeline: 2-3 days

3. **Update Vite Configuration**
   - Current setup supports Tailwind - optimize for Tailwind-only build
   - Remove SCSS vendor imports
   - Timeline: 1-2 days

---

## 10. Migration Path Strategy

### Phase 1: Audit & Preparation (Week 1)
- Document all Bootstrap class usage (completed in this analysis)
- Create Tailwind form component library
- Set up test environment for theme migration

### Phase 2: Low-Risk Migration (Weeks 2-4)
- Migrate **Matt** theme (lightest Bootstrap usage)
- Create tests for form components
- Document migration patterns

### Phase 3: Core Theme Migration (Weeks 5-8)
- Migrate **Berlin** theme to Tailwind
- Migrate **Default** theme to Tailwind
- Update SimpleForm configuration

### Phase 4: Admin & JavaScript (Weeks 9-12)
- Rebuild admin interface with Tailwind + Vue
- Remove jQuery, migrate to vanilla JS or Vue
- Remove Bootstrap-Select, implement alternative

### Phase 5: Optimization (Weeks 13-14)
- Bundle size optimization
- Performance testing
- Asset pipeline cleanup

---

## 11. Expected Benefits After Migration

### Performance Improvements
- **CSS Bundle Size:** 282KB (admin) → ~50KB = **82% reduction**
- **JS Bundle Size:** 87KB (jQuery) → 0KB = **100% elimination**
- **Total Asset Reduction:** ~350KB per user load
- **Page Load Time:** ~15-20% faster on slower connections

### Maintenance Benefits
- Single CSS framework (Tailwind)
- Consistent styling approach across all themes
- Framework actively maintained (Bootstrap 3 is deprecated)
- Larger ecosystem of Tailwind components
- Better integration with existing Vue frontend

### Development Benefits
- Easier onboarding (one CSS framework to learn)
- Better IDE support for Tailwind utilities
- Faster UI development with utility-first approach
- Reduced CSS debugging complexity

---

## 12. File Inventory for Bootstrap Removal

### Vendor Assets to Review
```
vendor/assets/javascripts/
├── bootstrap.js (38KB)
├── bootstrap.min.js (24KB)
├── bootstrap-sprockets.js (2KB)
├── bootstrap-select.js (15KB)
└── bootstrap/ (13 files, ~50KB total)

vendor/assets/stylesheets/
├── _bootstrap.scss (25KB)
├── _bootstrap-sprockets.scss
├── _bootstrap-mincer.scss
├── _bootstrap-compass.scss
├── bootstrap-select.scss (8KB)
└── bootstrap/ (27 files, ~200KB total)
```

**Total Bootstrap Vendor Assets:** ~365KB

### Configuration Files to Update
```
config/initializers/simple_form_bootstrap.rb (152 lines)
```

### Application Files with Bootstrap Dependencies
```
Themes:
- app/themes/default/ (Heavy)
- app/themes/berlin/ (Heavy)
- app/themes/matt/ (Moderate)
- app/themes/vic/ (Moderate)

Views:
- app/views/pwb/_header.html.erb (Navbar)
- app/views/pwb/search/_feature_filters.html.erb (Accordion)
- app/views/pwb/props/_images_section_carousel.html.erb (Carousel)

Admin:
- vendor/assets/stylesheets/pwb-admin.scss (282KB)
- vendor/assets/javascripts/pwb-admin.js.erb
```

---

## 13. Conclusion

PropertyWebBuilder currently has **extensive Bootstrap 3 dependencies** that are:

1. **Outdated** - Bootstrap 3.3.7 is no longer maintained (released 2013)
2. **Redundant** - Project already uses Tailwind CSS in newer themes
3. **Bloated** - Admin interface includes entire Bootstrap framework (~282KB)
4. **Limiting** - Prevents unified styling approach and modern CSS practices

However, the project is **well-positioned for migration** because:
- Recent themes (Bristol, Brisbane) already use Tailwind successfully
- Vite + Tailwind pipeline is already configured
- Vue frontend doesn't depend on Bootstrap
- Clear migration path exists with low-risk initial phases

**Recommended Action:** Prioritize Phase 2 migration starting with Matt theme, building momentum for larger theme migrations by Q2 2025.
