# Page Parts Color Issues - Fix Examples

## Issue 1: home__cta_cta_banner.yml

### File Location
`/db/yml_seeds/page_parts/home__cta_cta_banner.yml`

### Current Code (BROKEN - Lines 29-49)
```yaml
template: |
  <section class="cta-banner py-16 bg-primary text-white">
    <div class="max-w-4xl mx-auto px-4 text-center">
      <h2 class="text-3xl font-bold mb-4">{{ page_part["title"]["content"] }}</h2>
      {% if page_part["subtitle"]["content"] %}
        <p class="text-xl opacity-90 mb-8">{{ page_part["subtitle"]["content"] }}</p>
      {% endif %}
      <div class="flex flex-wrap justify-center gap-4">
        {% if page_part["button_text"]["content"] %}
          <a href="{{ page_part["button_link"]["content"] }}" class="px-8 py-3 bg-white text-gray-900 font-semibold rounded-lg hover:bg-gray-100 transition">
            {{ page_part["button_text"]["content"] }}
          </a>
        {% endif %}
        {% if page_part["secondary_button_text"]["content"] %}
          <a href="{{ page_part["secondary_button_link"]["content"] }}" class="px-8 py-3 border-2 border-white font-semibold rounded-lg hover:bg-white/10 transition">
            {{ page_part["secondary_button_text"]["content"] }}
          </a>
        {% endif %}
      </div>
    </div>
  </section>
```

### Problems
1. **`bg-primary`** - Tailwind class, hardcoded to theme's primary but doesn't use CSS variable
2. **`text-white`** - Hardcoded white text
3. **`bg-white`** - Hardcoded white button background
4. **`text-gray-900`** - Hardcoded button text color
5. **`border-white`** - Hardcoded white border
6. **`hover:bg-gray-100`** - Hardcoded hover color
7. **`hover:bg-white/10`** - Hardcoded semi-transparent white

### Why It's Broken
The template uses Tailwind color class names instead of CSS variables. When a website changes its primary color:
- The section background might change (if Tailwind is regenerated)
- But the button colors (white/gray) stay hardcoded
- Result: Mismatched colors that don't respect palette

### Fixed Code (OPTION A - CSS Classes)
```yaml
template: |
  <section class="pwb-cta pwb-cta--primary">
    <div class="pwb-container">
      <div class="pwb-cta__content">
        <div class="pwb-cta__text">
          <h2 class="pwb-cta__title">{{ page_part.title.content }}</h2>
          {% if page_part.subtitle.content %}
            <p class="pwb-cta__subtitle">{{ page_part.subtitle.content }}</p>
          {% endif %}
        </div>
        <div class="pwb-cta__actions">
          {% if page_part.button_text.content %}
            <a href="{{ page_part.button_link.content | default: '#' | localize_url }}" class="pwb-btn pwb-btn--white pwb-btn--lg">
              {{ page_part.button_text.content }}
            </a>
          {% endif %}
          {% if page_part.secondary_button_text.content %}
            <a href="{{ page_part.secondary_button_link.content | default: '#' | localize_url }}" class="pwb-btn pwb-btn--outline-white pwb-btn--lg">
              {{ page_part.secondary_button_text.content }}
            </a>
          {% endif %}
        </div>
      </div>
    </div>
  </section>
```

**Why This Works:**
- `pwb-cta--primary` maps to `--pwb-primary` CSS variable (respects theme!)
- `pwb-btn--white` and `pwb-btn--outline-white` are defined in `_component_styles.css.erb`
- All colors reference CSS variables internally
- When palette changes, entire section updates automatically

### Fixed Code (OPTION B - Inline CSS Variables)
```yaml
template: |
  <section style="background: var(--pwb-primary); color: var(--pwb-text-on-primary); padding: 4rem 0;">
    <div style="max-width: 56rem; margin: 0 auto; padding: 0 1rem; text-align: center;">
      <h2 style="font-size: 1.875rem; font-weight: bold; margin-bottom: 1rem;">
        {{ page_part.title.content }}
      </h2>
      {% if page_part.subtitle.content %}
        <p style="font-size: 1.25rem; opacity: 0.9; margin-bottom: 2rem;">
          {{ page_part.subtitle.content }}
        </p>
      {% endif %}
      <div style="display: flex; flex-wrap: wrap; justify-content: center; gap: 1rem;">
        {% if page_part.button_text.content %}
          <a href="{{ page_part.button_link.content | default: '#' | localize_url }}" 
             style="padding: 0.75rem 2rem; background: white; color: var(--pwb-primary); font-weight: 600; border-radius: 0.5rem; text-decoration: none; transition: background 150ms;">
            {{ page_part.button_text.content }}
          </a>
        {% endif %}
        {% if page_part.secondary_button_text.content %}
          <a href="{{ page_part.secondary_button_link.content | default: '#' | localize_url }}" 
             style="padding: 0.75rem 2rem; background: transparent; border: 2px solid white; color: white; font-weight: 600; border-radius: 0.5rem; text-decoration: none; transition: background 150ms;">
            {{ page_part.secondary_button_text.content }}
          </a>
        {% endif %}
      </div>
    </div>
  </section>
```

**Why This Works:**
- `var(--pwb-primary)` pulls theme color directly
- `var(--pwb-text-on-primary)` ensures good contrast
- White button still hardcoded but secondary button text uses theme color
- Better than current but less maintainable than Option A

### Recommendation
Use **Option A (CSS Classes)** because:
1. Matches existing component patterns in codebase
2. All styling in one place (stylesheet)
3. Easier to maintain dark mode variants
4. Follows best practices (separation of concerns)

---

## Issue 2: home__features_feature_grid_3col.yml

### File Location
`/db/yml_seeds/page_parts/home__features_feature_grid_3col.yml`

### Current Code (BROKEN - Lines 43-95)
```yaml
template: |
  <section class="services-section-wrapper py-16 bg-gray-50" id="home-services">
    <div class="services-container max-w-6xl mx-auto px-4">
      {% if page_part["section_title"]["content"] != blank %}
        <div class="text-center mb-12">
          {% if page_part["section_pretitle"]["content"] != blank %}
            <p class="text-sm uppercase tracking-widest text-amber-700 mb-2">{{ page_part["section_pretitle"]["content"] }}</p>
          {% endif %}
          <h2 class="text-3xl font-bold text-gray-900 mb-4">{{ page_part["section_title"]["content"] }}</h2>
          {% if page_part["section_subtitle"]["content"] != blank %}
            <p class="text-lg text-gray-600 max-w-2xl mx-auto">{{ page_part["section_subtitle"]["content"] }}</p>
          {% endif %}
        </div>
      {% endif %}
      <div class="services-grid grid grid-cols-1 gap-8">
        {% if page_part["feature_1_title"]["content"] != blank %}
          <div class="service-card bg-white p-8 rounded-lg shadow-md text-center hover:shadow-lg transition">
            {% if page_part["feature_1_icon"]["content"] != blank %}
              <div class="service-icon-wrapper text-4xl text-amber-700 mb-4">{{ page_part["feature_1_icon"]["content"] | material_icon: "xl" }}</div>
            {% endif %}
            <h3 class="service-title text-xl font-semibold text-gray-900 mb-3">{{ page_part["feature_1_title"]["content"] }}</h3>
            <p class="service-content text-gray-600">{{ page_part["feature_1_description"]["content"] }}</p>
            {% if page_part["feature_1_link"]["content"] != blank %}
              <a href="{{ page_part["feature_1_link"]["content"] }}" class="inline-block mt-4 text-amber-700 hover:underline">Learn more &rarr;</a>
            {% endif %}
          </div>
        {% endif %}
        <!-- ... repeats for features 2 and 3 ... -->
      </div>
    </div>
  </section>
```

### Problems (Many Hardcoded Colors!)

| Line | Element | Hardcoded Color | Problem |
|------|---------|-----------------|---------|
| 43 | Background | `bg-gray-50` | Light gray background |
| 48 | Pretitle | `text-amber-700` | Always amber, not theme accent! |
| 50 | Heading | `text-gray-900` | Always dark gray |
| 52 | Subtitle | `text-gray-600` | Always medium gray |
| 58 | Card | `bg-white` | Always white |
| 60 | Icon | `text-amber-700` | **Hardcoded amber instead of theme color** |
| 62 | Title | `text-gray-900` | Always dark gray |
| 63 | Description | `text-gray-600` | Always medium gray |
| 65 | Link | `text-amber-700` | **Hardcoded amber, ignores theme** |
| (repeats for features 2, 3) | | | All same hardcoded scheme |

### Why It's REALLY Broken
This file hardcodes an **amber/gray/white color scheme** that is incompatible with the website's custom palette. If someone changes their theme colors, this entire section ignores them:
- Pretitle stays amber ❌
- Icons stay amber ❌  
- Links stay amber ❌
- Background stays light gray ❌

### Fixed Code (OPTION A - Use Component Classes)
```yaml
template: |
  <section class="pwb-section pwb-features pwb-features--cards">
    <div class="pwb-container">
      {% if page_part.section_title.content %}
        <div class="pwb-section__header">
          <h2 class="pwb-section__title">{{ page_part.section_title.content }}</h2>
          {% if page_part.section_subtitle.content %}
            <p class="pwb-section__subtitle">{{ page_part.section_subtitle.content }}</p>
          {% endif %}
        </div>
      {% endif %}

      <div class="pwb-grid pwb-grid--3col pwb-grid--gap-lg">
        <!-- Feature 1 -->
        {% if page_part.feature_1_title.content %}
          <div class="pwb-feature-card">
            {% if page_part.feature_1_icon.content %}
              <div class="pwb-feature-card__icon">
                {{ page_part.feature_1_icon.content | material_icon }}
              </div>
            {% endif %}
            <h3 class="pwb-feature-card__title">{{ page_part.feature_1_title.content }}</h3>
            <p class="pwb-feature-card__description">{{ page_part.feature_1_description.content }}</p>
            {% if page_part.feature_1_link.content %}
              <a href="{{ page_part.feature_1_link.content }}" class="pwb-feature-card__link">
                Learn more →
              </a>
            {% endif %}
          </div>
        {% endif %}

        <!-- Feature 2 -->
        {% if page_part.feature_2_title.content %}
          <div class="pwb-feature-card">
            {% if page_part.feature_2_icon.content %}
              <div class="pwb-feature-card__icon">
                {{ page_part.feature_2_icon.content | material_icon }}
              </div>
            {% endif %}
            <h3 class="pwb-feature-card__title">{{ page_part.feature_2_title.content }}</h3>
            <p class="pwb-feature-card__description">{{ page_part.feature_2_description.content }}</p>
            {% if page_part.feature_2_link.content %}
              <a href="{{ page_part.feature_2_link.content }}" class="pwb-feature-card__link">
                Learn more →
              </a>
            {% endif %}
          </div>
        {% endif %}

        <!-- Feature 3 -->
        {% if page_part.feature_3_title.content %}
          <div class="pwb-feature-card">
            {% if page_part.feature_3_icon.content %}
              <div class="pwb-feature-card__icon">
                {{ page_part.feature_3_icon.content | material_icon }}
              </div>
            {% endif %}
            <h3 class="pwb-feature-card__title">{{ page_part.feature_3_title.content }}</h3>
            <p class="pwb-feature-card__description">{{ page_part.feature_3_description.content }}</p>
            {% if page_part.feature_3_link.content %}
              <a href="{{ page_part.feature_3_link.content }}" class="pwb-feature-card__link">
                Learn more →
              </a>
            {% endif %}
          </div>
        {% endif %}
      </div>
    </div>
  </section>
```

**CSS Classes Used (from `_component_styles.css.erb`):**
```css
.pwb-section                    /* Padding, general section styles */
.pwb-feature-card               /* Card container */
.pwb-feature-card__icon         /* Icon styling - uses --pwb-primary */
.pwb-feature-card__title        /* Title styling */
.pwb-feature-card__description  /* Description - uses --pwb-text-secondary */
.pwb-feature-card__link         /* Link styling - uses --pwb-primary */
.pwb-grid pwb-grid--3col        /* Three-column grid */
.pwb-section__header            /* Header with title */
```

**Why This Works:**
- `.pwb-feature-card__icon` uses `background: var(--pwb-primary-light); color: var(--pwb-primary);`
- `.pwb-feature-card__link` uses `color: var(--pwb-primary);`
- All colors automatically match website palette
- Cleaner template, styling separated from markup

### Fixed Code (OPTION B - Use Pretitle Pattern with Primary Color)
```yaml
template: |
  <section class="pwb-section pwb-features pwb-features--grid">
    <div class="pwb-container">
      {% if page_part.section_title.content %}
        <div class="pwb-section__header">
          {% if page_part.section_pretitle.content %}
            <span class="pwb-section__pretitle">{{ page_part.section_pretitle.content }}</span>
          {% endif %}
          <h2 class="pwb-section__title">{{ page_part.section_title.content }}</h2>
          {% if page_part.section_subtitle.content %}
            <p class="pwb-section__subtitle">{{ page_part.section_subtitle.content }}</p>
          {% endif %}
        </div>
      {% endif %}

      <div class="pwb-grid pwb-grid--3col pwb-grid--gap-lg">
        <!-- Cards here -->
      </div>
    </div>
  </section>
```

**Why This Works:**
- `.pwb-section__pretitle` already styled to use `color: var(--pwb-primary);` in stylesheet
- No hardcoded colors anywhere
- Consistent with other page parts in codebase

### Recommendation
Use **Option A** because:
1. Existing `.pwb-feature-card` component already in stylesheet
2. All styling centralized in CSS
3. Matches `feature_cards_icons.liquid` pattern (which is correct)
4. Clear separation of concerns

---

## Issue 3: Hardcoded Colors in _component_styles.css.erb

### File Location
`/app/views/pwb/custom_css/_component_styles.css.erb`

### Problematic Lines

#### Line 139: Button Text Color
```css
/* BEFORE (WRONG) */
.pwb-btn--white {
  background-color: #ffffff;
  color: var(--pwb-primary);
  border-color: #ffffff;
}

/* AFTER (CORRECT) */
.pwb-btn--white {
  background-color: var(--pwb-bg-light);
  color: var(--pwb-primary);
  border-color: var(--pwb-bg-light);
}
```

**Why:**
- Uses light background variable instead of hardcoded white
- Respects light/dark mode changes
- Consistent with other buttons

#### Line 184: Hero Overlay
```css
/* BEFORE (WRONG) */
.pwb-hero__overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(0,0,0,0.5), rgba(0,0,0,0.7));
}

/* AFTER (CORRECT) */
.pwb-hero__overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    to bottom,
    rgba(0,0,0, calc(var(--pwb-hero-overlay-start, 0.5))),
    rgba(0,0,0, calc(var(--pwb-hero-overlay-end, 0.7)))
  );
}

/* Or simpler: */
.pwb-hero__overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    to bottom,
    rgb(0 0 0 / 0.5),
    rgb(0 0 0 / 0.7)
  );
}
```

**Why:**
- Separates darkening effect from color system
- Could be extended with CSS variables if needed
- Modern CSS syntax clearer

#### Line 338: Success Card Background
```css
/* BEFORE (WRONG) */
.pwb-icon-card__icon--success {
  background: #d4edda;
  color: var(--pwb-success);
}

/* AFTER (CORRECT) */
.pwb-icon-card__icon--success {
  background: color-mix(in srgb, var(--pwb-success) 15%, white);
  color: var(--pwb-success);
}

/* Or: */
.pwb-icon-card__icon--success {
  background: var(--pwb-success-light);
  color: var(--pwb-success);
}
```

**Why:**
- Uses theme's success color
- Derives light variant automatically
- Consistent with primary/secondary/accent cards

#### Line 361: Star Rating Color
```css
/* BEFORE (WRONG) */
.pwb-testimonial-card__rating {
  color: #fbbf24;  /* Always amber! */
  margin-bottom: var(--pwb-spacing-md);
}

/* AFTER (CORRECT) */
.pwb-testimonial-card__rating {
  color: var(--pwb-warning);  /* Use theme's warning/highlight color */
  margin-bottom: var(--pwb-spacing-md);
}

/* Or if there's no warning color defined: */
.pwb-testimonial-card__rating {
  color: var(--pwb-primary);  /* Use primary as fallback */
  margin-bottom: var(--pwb-spacing-md);
}
```

**Why:**
- Gold/amber might not match all themes
- Primary color makes more sense for accent
- Respects theme customization

### Summary of Fixes Needed

```css
/* Create variables for utility colors in _base_variables.css.erb */
:root {
  /* Light/dark text variants */
  --pwb-text-on-light: #000;
  --pwb-text-on-dark: #fff;
  
  /* Light color variants */
  --pwb-primary-light: color-mix(in srgb, var(--pwb-primary) 15%, white);
  --pwb-secondary-light: color-mix(in srgb, var(--pwb-secondary) 15%, white);
  --pwb-accent-light: color-mix(in srgb, var(--pwb-accent) 15%, white);
  --pwb-success-light: color-mix(in srgb, var(--pwb-success) 15%, white);
  
  /* Overlay opacity */
  --pwb-overlay-dark-start: rgba(0, 0, 0, 0.5);
  --pwb-overlay-dark-end: rgba(0, 0, 0, 0.7);
}
```

Then in `_component_styles.css.erb`:
```css
.pwb-btn--white {
  background-color: var(--pwb-bg-light);
  color: var(--pwb-text-on-light);
  border-color: var(--pwb-bg-light);
}

.pwb-hero__overlay {
  background: linear-gradient(to bottom, var(--pwb-overlay-dark-start), var(--pwb-overlay-dark-end));
}

.pwb-testimonial-card__rating {
  color: var(--pwb-primary);
}
```

---

## Testing the Fixes

### Before Fix
```ruby
# Create website with custom colors
website = Pwb::Website.create!(
  name: "Red Theme Site",
  theme_name: "default",
  style_variables: {
    "primary_color" => "#FF0000",    # Red instead of default
    "secondary_color" => "#00FF00",  # Green
    "accent_color" => "#0000FF"      # Blue
  }
)

# Add page with CTA
page = website.pages.create!(slug: "home")
page_part = website.page_parts.find_by(page_part_key: "cta/cta_banner")

# BROKEN: Button is still white, section background might be red but buttons aren't
# FIXED: Section background is red, buttons are white on red (good contrast)
```

### After Fix
```ruby
# Same setup
website = Pwb::Website.create!(...)

# EXPECTED: 
# - Section background = red (#FF0000)
# - Button text = white (good contrast)
# - Link colors in feature cards = red (#FF0000)
# - Icon backgrounds = light red
# - All accent colors = red
# ✓ Everything respects theme palette
```

---

## Validation Checklist

When fixing color issues:

- [ ] No hardcoded hex colors (except for overlays/transparency)
- [ ] No hardcoded Tailwind color classes (use CSS classes or variables)
- [ ] Uses CSS variables for all semantic colors
- [ ] Follows existing component patterns (e.g., `pwb-btn--*`, `pwb-icon-card__icon--*`)
- [ ] Works with dark mode (if enabled)
- [ ] Tested with multiple color palettes
- [ ] Accents use theme's primary/secondary/accent colors
- [ ] Text colors use theme's text color variables
- [ ] Backgrounds use theme's background variables
- [ ] Styling in stylesheet, not in template
- [ ] No hardcoded gray/amber/white color schemes

