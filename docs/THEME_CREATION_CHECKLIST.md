# Theme Creation Checklist

This document provides a comprehensive checklist for creating new themes in PropertyWebBuilder. Following this checklist will prevent missing templates and ensure all pages render correctly.

## Pre-Creation Checklist

- [ ] Choose a theme name (lowercase, no spaces)
- [ ] Define the color palette (primary, secondary, accent colors)
- [ ] Select fonts (heading and body fonts)
- [ ] Review an existing complete theme (brisbane or default) as reference

## Required Templates (15 files)

Every theme MUST have these templates to function correctly. Run the theme completeness test to verify: `bundle exec rspec spec/views/themes/theme_completeness_spec.rb`

### Layout (1 file)
- [ ] `layouts/pwb/application.html.erb` - Main application layout

### Header & Footer (2 files)
- [ ] `pwb/_header.html.erb` - Site header/navigation
- [ ] `pwb/_footer.html.erb` - Site footer

### Home Page (1 file)
- [ ] `pwb/welcome/index.html.erb` - Home/landing page

### Search Pages (5 files)
- [ ] `pwb/search/buy.html.erb` - Buy/for-sale search page
- [ ] `pwb/search/rent.html.erb` - Rent search page
- [ ] `pwb/search/_search_form_for_sale.html.erb` - Buy search form partial
- [ ] `pwb/search/_search_form_for_rent.html.erb` - Rent search form partial
- [ ] `pwb/search/_search_results.html.erb` - Search results partial

### Property Detail (1 file)
- [ ] `pwb/props/show.html.erb` - Property detail page

### Generic Pages (1 file)
- [ ] `pwb/pages/show.html.erb` - Generic content pages (About Us, etc.)

### Contact Page (2 files)
- [ ] `pwb/sections/contact_us.html.erb` - Contact us page
- [ ] `pwb/sections/_contact_us_form.html.erb` - Contact form partial

### Components (2 files)
- [ ] `pwb/components/_generic_page_part.html.erb` - Generic page part component
- [ ] `pwb/components/_form_and_map.html.erb` - Contact form and map component

## Required CSS Partial (1 file)

**CRITICAL**: Every theme MUST have a custom CSS partial for theme-specific styling:

- [ ] `app/views/pwb/custom_css/_<theme_name>.css.erb` - Custom CSS with theme variables

**Example structure:**
```erb
/* Custom CSS for YourTheme */
:root {
  --primary-color: <%= @current_website.style_variables['primary_color'] || '#default' %>;
  --secondary-color: <%= @current_website.style_variables['secondary_color'] || '#default' %>;
  /* Add other CSS variables */
}
```

This file is loaded by `layouts/pwb/application.html.erb` via the `custom_styles` helper. Without it, the page will fail to render with `ActionView::MissingTemplate` error.

## Recommended Templates (Optional but Helpful)

These templates improve the theme but the app will fall back to defaults if missing:

- [ ] `pwb/welcome/_single_property_row.html.erb` - Featured property row (**Recommended if showing properties on home page**)
- [ ] `pwb/search/_search_form_landing.html.erb` - Landing page search form
- [ ] `pwb/welcome/_about_us.html.erb` - About us section on home
- [ ] `pwb/props/_breadcrumb_row.html.erb` - Breadcrumb navigation
- [ ] `pwb/props/_images_section_carousel.html.erb` - Image carousel
- [ ] `pwb/props/_request_prop_info.html.erb` - Request info form

**Note:** While `_single_property_row.html.erb` is marked as optional, it's practically required if your home page displays property listings (which most themes do). Missing this will cause `ActionView::MissingTemplate` errors.

## CSS/Styling Files

- [ ] `app/assets/stylesheets/tailwind-{theme}.css` - Tailwind input file
- [ ] Add entry to `package.json` for build script
- [ ] Add to `config/initializers/assets.rb` precompile list
- [ ] Create `app/views/pwb/custom_css/_{theme}.css.erb` (optional)

## Directory Structure

```
app/themes/{theme_name}/
├── views/
│   ├── layouts/
│   │   └── pwb/
│   │       └── application.html.erb
│   └── pwb/
│       ├── _header.html.erb
│       ├── _footer.html.erb
│       ├── components/
│       │   ├── _generic_page_part.html.erb
│       │   └── _form_and_map.html.erb
│       ├── pages/
│       │   └── show.html.erb
│       ├── props/
│       │   └── show.html.erb
│       ├── search/
│       │   ├── buy.html.erb
│       │   ├── rent.html.erb
│       │   ├── _search_form_for_sale.html.erb
│       │   ├── _search_form_for_rent.html.erb
│       │   └── _search_results.html.erb
│       ├── sections/
│       │   ├── contact_us.html.erb
│       │   └── _contact_us_form.html.erb
│       └── welcome/
│           └── index.html.erb
```

## Testing Checklist

After creating the theme, verify these pages render without errors:

### Manual Testing
- [ ] Home page (`/`)
- [ ] Buy/Search page (`/en/buy`)
- [ ] Rent page (`/en/rent`)
- [ ] Property detail page (click any property)
- [ ] About Us page (`/en/about-us`)
- [ ] Contact Us page (`/en/contact-us`)

### Automated Testing
```bash
# Run theme completeness test (verifies all 15 required templates exist)
bundle exec rspec spec/views/themes/theme_completeness_spec.rb

# Run theme homepage requirements tests (verifies navigation visibility, property listings)
npx playwright test tests/e2e/public/theme-rendering.spec.js --grep "Theme Homepage Requirements"

# Run all E2E tests
npx playwright test
```

### Theme Homepage Requirements (E2E Tests)

The following tests in `tests/e2e/public/theme-rendering.spec.js` verify usability standards:

1. **Navigation links are visible and readable** - Verifies nav links have sufficient contrast
2. **Navigation links have sufficient contrast** - Ensures text color differs from background
3. **Home page has property listings section** - Checks for property section when data exists
4. **Property cards display correctly** - Validates property card structure
5. **Navigation links are clickable** - Ensures links have valid href attributes

These tests help catch common theme issues like:
- Text colors too light to read (e.g., warm-600 on white background)
- Missing property listing sections
- Broken navigation links

## Common Mistakes to Avoid

1. **Missing `app/views/pwb/custom_css/_<theme>.css.erb`** - **CRITICAL**: Theme won't render without this
2. **Missing `pwb/welcome/_single_property_row.html.erb`** - Causes errors if home page shows properties
3. **Missing `pwb/pages/show.html.erb`** - Causes About Us and other content pages to break
4. **Missing `pwb/sections/contact_us.html.erb`** - Causes Contact page to break
5. **Missing `pwb/components/_form_and_map.html.erb`** - Causes Contact page map/form to break
6. **Forgetting to add CSS to asset precompile list** - Causes styling to fail in production
7. **Not testing all pages** - Easy to miss broken pages

## Using the Theme

1. Register the theme in `config/initializers/theme.rb` (if applicable)
2. Set the theme in the admin panel or via `Pwb::Current.website.theme`
3. Restart the Rails server after adding new themes

## Troubleshooting

### Missing Template Errors
Run the completeness test to identify missing templates:
```bash
bundle exec rspec spec/views/themes/theme_completeness_spec.rb --format documentation
```

### CSS Not Loading
1. Check `config/initializers/assets.rb` includes your theme CSS
2. Run `rails assets:precompile` in production
3. Restart the Rails server

### Theme Not Appearing
1. Verify directory structure matches expected format
2. Check theme name in `app/themes/{name}` is lowercase
3. Ensure all required files exist
