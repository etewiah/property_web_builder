# Bootstrap Quick Reference Guide

## Files with Bootstrap Dependencies

### Critical Files (Most Impact)
```
1. /vendor/assets/stylesheets/pwb-admin.scss (282 KB)
   └─ Largest Bootstrap footprint - includes entire framework
   
2. /config/initializers/simple_form_bootstrap.rb (152 lines)
   └─ Form styling - affects all form rendering
   
3. /app/views/pwb/_header.html.erb
   └─ Navigation with data-toggle="collapse" and data-toggle="dropdown"
   
4. /app/views/pwb/search/_feature_filters.html.erb
   └─ Accordion with .panel-group and data-toggle="collapse"
   
5. /app/views/pwb/props/_images_section_carousel.html.erb
   └─ Carousel with .carousel and data-slide attributes
```

### Theme Files Using Bootstrap
```
/app/stylesheets/pwb/themes/
├── default.scss (imports bootstrap)
├── berlin.scss (imports bootstrap)
├── matt.scss (minimal bootstrap)
├── vic.scss (some bootstrap)
└── chic.scss (legacy, minimal use)

/app/themes/default/views/ (Heavy Bootstrap classes)
/app/themes/berlin/views/ (Heavy Bootstrap classes)
/app/themes/matt/views/ (Moderate Bootstrap classes)
```

### Vendor Assets
```
/vendor/assets/stylesheets/
├── _bootstrap.scss (Bootstrap 3.3.7 imports)
├── bootstrap/ (27 component files)
└── bootstrap-select.scss

/vendor/assets/javascripts/
├── bootstrap.js + bootstrap.min.js
├── bootstrap-sprockets.js
├── bootstrap-select.js
└── bootstrap/ (13 component files)
```

---

## Bootstrap Classes Used in HTML

### Grid System
```
.container       - Fixed/fluid container
.row            - Row container
.col-xs-*       - Extra small (phones)
.col-sm-*       - Small (tablets)
.col-md-*       - Medium (laptops)
.col-lg-*       - Large (desktops)
.col-sm-offset-* - Offset columns
```

### Navigation
```
.navbar                  - Main navbar container
.navbar-header          - Logo/brand area
.navbar-brand           - Logo/site name
.navbar-toggle          - Hamburger menu button
.navbar-collapse        - Collapsible menu area
.nav                    - Navigation list
.navbar-nav             - Navigation items in navbar
.navbar-right           - Right-aligned nav items
.dropdown-toggle        - Dropdown trigger button
.dropdown-menu          - Dropdown menu list
```

### Forms
```
.form-group      - Form field wrapper
.form-control    - Input/textarea/select styles
.control-label   - Form label
.input-group     - Group input with addon
.input-group-addon - Addon before/after input
.form-inline     - Inline form layout
.checkbox        - Checkbox wrapper
.radio           - Radio button wrapper
.help-block      - Help text under field
.has-error       - Error state on form-group
.sr-only         - Screen reader only text
```

### Buttons
```
.btn             - Base button
.btn-default     - Default button style
.btn-primary     - Primary button
.btn-success     - Success button
.btn-warning     - Warning button
.btn-danger      - Danger button
.btn-lg          - Large button
.btn-sm          - Small button
.btn-xs          - Extra small button
.btn-group       - Group of buttons
.btn-group-sm    - Small button group
.btn-group-vertical - Vertical button group
```

### Panels/Cards
```
.panel           - Panel container
.panel-group     - Group of panels (accordion)
.panel-default   - Default panel style
.panel-heading   - Panel header
.panel-title     - Title inside panel header
.panel-body      - Panel content
.panel-collapse  - Collapsible content
```

### Carousels
```
.carousel        - Carousel container
.carousel-slide  - Sliding animation
.carousel-indicators - Dot indicators
.carousel-inner  - Inner slides container
.item            - Individual slide
.carousel-control - Previous/next buttons
.left            - Left arrow
.right           - Right arrow
```

### Alerts
```
.alert           - Base alert
.alert-success   - Success alert
.alert-info      - Info alert
.alert-warning   - Warning alert
.alert-danger    - Danger alert
.alert-link      - Link in alert
```

### Responsive Utilities
```
.hidden-xs       - Hide on extra small screens
.hidden-sm       - Hide on small screens
.visible-md      - Show only on medium screens
.pull-left       - Float left
.pull-right      - Float right
.clearfix        - Clear floats
```

### Typography
```
.h1, .h2, .h3, etc. - Heading styles
.lead            - Large lead paragraph
.small           - Small text
.text-muted      - Muted text color
.text-primary    - Primary color text
.text-success    - Success color text
.text-warning    - Warning color text
.text-danger     - Danger color text
.text-center     - Center aligned text
.text-left       - Left aligned text
.text-right      - Right aligned text
```

---

## Bootstrap Data Attributes (JavaScript Behavior)

### Collapse/Accordion
```html
<a data-toggle="collapse" 
   data-target="#target-id"
   href="#target-id">
   Toggle Content
</a>
<div id="target-id" class="collapse">
  Hidden content
</div>
```
**Usage:** _feature_filters.html.erb, theme headers

### Dropdown
```html
<a href="#" class="dropdown-toggle" data-toggle="dropdown">
  Dropdown
</a>
<ul class="dropdown-menu">
  <li><a href="#">Item</a></li>
</ul>
```
**Usage:** _header.html.erb

### Button Group Toggle
```html
<div class="btn-group" data-toggle="buttons">
  <label class="btn btn-default">
    <input type="radio" name="option"> Option
  </label>
</div>
```
**Usage:** _feature_filters.html.erb (features match selector)

### Carousel
```html
<div class="carousel slide" data-ride="carousel" data-interval="5000">
  <ol class="carousel-indicators">
    <li data-target="#carousel-id" data-slide-to="0"></li>
  </ol>
  <div class="carousel-inner">
    <div class="item"><img></div>
  </div>
  <a class="carousel-control" href="#" data-slide="prev"></a>
  <a class="carousel-control" href="#" data-slide="next"></a>
</div>
```
**Usage:** _images_section_carousel.html.erb

---

## Related Dependencies

### jQuery (Required by Bootstrap JS)
```ruby
# Gemfile
gem "jquery-rails", "~> 4.5"
```
- Size: 87 KB
- Required for: Dropdowns, collapses, carousels, modals
- Can be removed if: All Bootstrap JS disabled

### Bootstrap-Select jQuery Plugin
```javascript
vendor/assets/javascripts/bootstrap-select.js
app/assets/javascripts/pwb/shared/select-picker.js (Vue wrapper)
```
- Size: 15 KB JS + 8 KB CSS
- Provides: Searchable select dropdowns
- Alternative: Headless UI + Tailwind styling

### Simple Form Gem
```ruby
gem "simple_form", "~> 5.1"
```
- Configured in: config/initializers/simple_form_bootstrap.rb
- Generates: Bootstrap-styled forms
- Alternative: Create Tailwind form builders

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Bootstrap Version | 3.3.7 (2013) |
| Vendor Assets Size | ~365 KB |
| Admin CSS Size | 282 KB |
| Total Bootstrap Files | 40+ |
| Themes Using Bootstrap | 4 of 8 (Default, Berlin, Matt, Vic) |
| Themes Using Tailwind | 2 of 8 (Bristol, Brisbane) |
| Data Attributes Using Bootstrap JS | 26 |
| jQuery Dependency | Yes (87 KB) |
| SimpleForm Bootstrap Config | 152 lines |

---

## Migration Checklist

- [ ] Document all Bootstrap classes in use (✓ Complete)
- [ ] Create Tailwind component equivalents
- [ ] Test form rendering with new components
- [ ] Create navbar without Bootstrap JS
- [ ] Create accordion without Bootstrap JS collapse
- [ ] Create carousel without Bootstrap JS
- [ ] Create dropdown without Bootstrap JS
- [ ] Migrate CSS from SCSS Bootstrap imports to Tailwind
- [ ] Update SimpleForm configuration
- [ ] Remove jQuery dependency
- [ ] Test all themes thoroughly
- [ ] Performance testing (bundle size, load time)

---

## Emergency Fallback

If Bootstrap JS fails to load (CDN issue), these components will break:
1. Mobile hamburger menu (navbar collapse)
2. Feature filter accordion
3. Dropdown menus
4. Image carousel

**Solution:** Add custom JavaScript fallbacks (already partially done in _feature_filters.html.erb)

---

## Further Reading

- Full Analysis: `/docs/claude_thoughts/BOOTSTRAP_DEPENDENCY_ANALYSIS.md`
- Bootstrap 3 Docs: https://getbootstrap.com/docs/3.3/ (archived)
- Tailwind CSS Docs: https://tailwindcss.com/docs
- Migration Guide: See "Phase 1-5" in full analysis document
