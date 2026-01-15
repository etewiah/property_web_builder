# Atomic Design Implementation Plan for Rails Frontend

This document outlines a phased approach to implementing Atomic Design principles in PropertyWebBuilder's Rails-rendered frontend (B-themes).

## Goals

1. **Improve reusability** - Share components across all B-themes
2. **Reduce duplication** - Extract common patterns into reusable partials
3. **Enhance maintainability** - Clear hierarchy makes code easier to navigate
4. **Enable isolated testing** - Smaller units are easier to test
5. **Accelerate theme development** - New themes only override CSS, not structure

---

## Phase 1: Directory Structure Setup

### Create Atomic Directories

```
app/views/shared/
├── atoms/           # Smallest UI primitives
├── molecules/       # Simple combinations of atoms
└── organisms/       # Complex, self-contained components
```

### Files to Create

| Directory | Purpose |
|-----------|---------|
| `shared/atoms/` | Buttons, badges, icons, form inputs, links |
| `shared/molecules/` | Form groups, price displays, nav items, stat cards |
| `shared/organisms/` | Property cards, search filters, testimonial cards |

---

## Phase 2: Extract Atoms

### Priority Atoms to Create

#### 2.1 Button (`_button.html.erb`)

```erb
<%# app/views/shared/atoms/_button.html.erb %>
<%# Usage: render "shared/atoms/button", text: "Submit", variant: :primary, size: :md %>
<%
  variant ||= :primary
  size ||= :md
  type ||= :button
  disabled ||= false
  
  base_classes = "pwb-btn"
  variant_classes = {
    primary: "pwb-btn--primary",
    secondary: "pwb-btn--secondary",
    outline: "pwb-btn--outline",
    ghost: "pwb-btn--ghost"
  }
  size_classes = {
    sm: "pwb-btn--sm",
    md: "pwb-btn--md",
    lg: "pwb-btn--lg"
  }
  
  classes = [base_classes, variant_classes[variant], size_classes[size], local_assigns[:class]].compact.join(" ")
%>
<button type="<%= type %>" class="<%= classes %>" <%= "disabled" if disabled %>>
  <%= text %>
</button>
```

#### 2.2 Badge (`_badge.html.erb`)

```erb
<%# app/views/shared/atoms/_badge.html.erb %>
<%
  variant ||= :default
  classes = "pwb-badge pwb-badge--#{variant} #{local_assigns[:class]}"
%>
<span class="<%= classes %>"><%= text %></span>
```

#### 2.3 Icon (`_icon.html.erb`)

```erb
<%# app/views/shared/atoms/_icon.html.erb %>
<%# Wraps existing icon helper with consistent classes %>
<%= icon(name, class: "pwb-icon pwb-icon--#{size || 'md'} #{local_assigns[:class]}") %>
```

#### 2.4 Form Input (`_input.html.erb`)

```erb
<%# app/views/shared/atoms/_input.html.erb %>
<%
  type ||= :text
  required ||= false
  classes = "pwb-input #{local_assigns[:class]}"
%>
<input 
  type="<%= type %>" 
  name="<%= name %>" 
  id="<%= id || name %>" 
  value="<%= value %>"
  placeholder="<%= placeholder %>"
  class="<%= classes %>"
  <%= "required" if required %>
>
```

---

## Phase 3: Extract Molecules

### Priority Molecules to Create

#### 3.1 Form Group (`_form_group.html.erb`)

```erb
<%# app/views/shared/molecules/_form_group.html.erb %>
<div class="pwb-form-group">
  <label for="<%= input_id %>" class="pwb-form-group__label">
    <%= label_text %>
    <% if required %><span class="pwb-form-group__required">*</span><% end %>
  </label>
  <%= yield %>
  <% if error.present? %>
    <span class="pwb-form-group__error"><%= error %></span>
  <% end %>
</div>
```

#### 3.2 Price Display (`_price_display.html.erb`)

```erb
<%# app/views/shared/molecules/_price_display.html.erb %>
<div class="pwb-price-display">
  <span class="pwb-price-display__value"><%= formatted_price %></span>
  <% if rental %>
    <span class="pwb-price-display__suffix">/<%= I18n.t('common.month') %></span>
  <% end %>
</div>
```

#### 3.3 Property Stats (`_property_stats.html.erb`)

```erb
<%# app/views/shared/molecules/_property_stats.html.erb %>
<div class="pwb-prop-stats">
  <span class="pwb-prop-stats__item">
    <%= render "shared/atoms/icon", name: "bed", size: "sm" %>
    <%= bedrooms %> <%= I18n.t('properties.beds') %>
  </span>
  <span class="pwb-prop-stats__item">
    <%= render "shared/atoms/icon", name: "bath", size: "sm" %>
    <%= bathrooms %> <%= I18n.t('properties.baths') %>
  </span>
  <% if garages.present? && garages > 0 %>
    <span class="pwb-prop-stats__item">
      <%= render "shared/atoms/icon", name: "car", size: "sm" %>
      <%= garages %> <%= I18n.t('properties.garage') %>
    </span>
  <% end %>
</div>
```

#### 3.4 Nav Link (`_nav_link.html.erb`)

```erb
<%# app/views/shared/molecules/_nav_link.html.erb %>
<li class="pwb-nav__item <%= 'pwb-nav__item--active' if active %>">
  <%= link_to path, class: "pwb-nav__link", target: target do %>
    <% if icon.present? %>
      <%= render "shared/atoms/icon", name: icon, size: "sm" %>
    <% end %>
    <%= title %>
  <% end %>
</li>
```

---

## Phase 4: Extract Organisms

### Priority Organisms to Create

#### 4.1 Property Card (`_property_card.html.erb`)

Extract from existing property listing views:

```erb
<%# app/views/shared/organisms/_property_card.html.erb %>
<article class="pwb-prop-card" data-property-id="<%= property.id %>">
  <a href="<%= property_path(property) %>" class="pwb-prop-card__link">
    <div class="pwb-prop-card__image">
      <%= image_tag property.primary_photo_url, alt: property.title, loading: "lazy" %>
      <% if property.highlighted? %>
        <%= render "shared/atoms/badge", text: I18n.t('properties.featured'), variant: :primary %>
      <% end %>
      <div class="pwb-prop-card__price">
        <%= render "shared/molecules/price_display", 
            formatted_price: property.formatted_price, 
            rental: property.for_rent? && !property.for_sale? %>
      </div>
    </div>
    <div class="pwb-prop-card__body">
      <h3 class="pwb-prop-card__title"><%= property.title %></h3>
      <%= render "shared/molecules/property_stats",
          bedrooms: property.count_bedrooms,
          bathrooms: property.count_bathrooms,
          garages: property.count_garages %>
    </div>
  </a>
</article>
```

#### 4.2 Testimonial Card (`_testimonial_card.html.erb`)

```erb
<%# app/views/shared/organisms/_testimonial_card.html.erb %>
<blockquote class="pwb-testimonial">
  <div class="pwb-testimonial__content">
    <p class="pwb-testimonial__quote"><%= testimonial.content %></p>
  </div>
  <footer class="pwb-testimonial__footer">
    <% if testimonial.photo_url.present? %>
      <%= image_tag testimonial.photo_url, alt: testimonial.name, class: "pwb-testimonial__avatar" %>
    <% end %>
    <div class="pwb-testimonial__author">
      <cite class="pwb-testimonial__name"><%= testimonial.name %></cite>
      <% if testimonial.role.present? %>
        <span class="pwb-testimonial__role"><%= testimonial.role %></span>
      <% end %>
    </div>
  </footer>
</blockquote>
```

#### 4.3 Search Filters (`_search_filters.html.erb`)

Extract from existing search form implementation.

---

## Phase 5: Refactor Existing Partials

### Files to Migrate

| Current Location | Target | Priority |
|------------------|--------|----------|
| `pwb/_header.html.erb` | Keep as organism, extract molecules | High |
| `pwb/_footer.html.erb` | Keep as organism, extract molecules | High |
| Property listing cards | `shared/organisms/_property_card.html.erb` | High |
| `page_parts/heroes/*` | Keep, use atoms/molecules internally | Medium |
| `page_parts/features/*` | Keep, use atoms/molecules internally | Medium |
| `page_parts/testimonials/*` | Keep, use atoms/molecules internally | Medium |

---

## Phase 6: CSS Organization

### BEM Class Naming

All atomic components use BEM with `pwb-` prefix:

```css
/* Atoms */
.pwb-btn { }
.pwb-btn--primary { }
.pwb-btn--lg { }

/* Molecules */
.pwb-form-group { }
.pwb-form-group__label { }
.pwb-form-group__error { }

/* Organisms */
.pwb-prop-card { }
.pwb-prop-card__image { }
.pwb-prop-card__title { }
```

### Create Component CSS Files

```
app/views/pwb/custom_css/
├── atoms/
│   ├── _buttons.css.erb
│   ├── _badges.css.erb
│   └── _icons.css.erb
├── molecules/
│   ├── _form_group.css.erb
│   ├── _price_display.css.erb
│   └── _property_stats.css.erb
└── organisms/
    ├── _property_card.css.erb
    └── _testimonial.css.erb
```

---

## Phase 7: Testing Strategy

### ViewComponent Migration (Optional)

For complex organisms, consider migrating to [ViewComponent](https://viewcomponent.org/):

```ruby
# app/components/property_card_component.rb
class PropertyCardComponent < ViewComponent::Base
  def initialize(property:, show_badge: true)
    @property = property
    @show_badge = show_badge
  end
end
```

### Partial Testing

```ruby
# spec/views/shared/atoms/button_spec.rb
RSpec.describe "shared/atoms/_button.html.erb" do
  it "renders primary button" do
    render partial: "shared/atoms/button", locals: { text: "Click", variant: :primary }
    expect(rendered).to have_css(".pwb-btn.pwb-btn--primary", text: "Click")
  end
end
```

---

## Implementation Timeline

| Phase | Estimated Effort | Dependencies |
|-------|------------------|--------------|
| Phase 1: Directory Setup | 1 hour | None |
| Phase 2: Extract Atoms | 4-6 hours | Phase 1 |
| Phase 3: Extract Molecules | 4-6 hours | Phase 2 |
| Phase 4: Extract Organisms | 8-12 hours | Phase 3 |
| Phase 5: Refactor Existing | 12-16 hours | Phase 4 |
| Phase 6: CSS Organization | 4-6 hours | Phase 4 |
| Phase 7: Testing | 8-12 hours | All phases |

**Total Estimated Effort**: 40-60 hours (spread over multiple sprints)

---

## Success Metrics

- [ ] All B-themes share common atoms/molecules
- [ ] New theme creation requires only CSS changes
- [ ] 80%+ code reuse across themes
- [ ] Component preview/documentation available (Lookbook or similar)
- [ ] Reduced bug reports related to UI inconsistencies

---

## Related Documents

- [Design Tokens](./DESIGN_TOKENS.md) - Token values used by atomic components
- [Frontend Standards](../FRONTEND_STANDARDS.md) - BEM naming conventions
