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

## Recommended Templates (Optional but Helpful)

These templates improve the theme but the app will fall back to defaults if missing:

- [ ] `pwb/search/_search_form_landing.html.erb` - Landing page search form
- [ ] `pwb/welcome/_single_property_row.html.erb` - Featured property row
- [ ] `pwb/welcome/_about_us.html.erb` - About us section on home
- [ ] `pwb/props/_breadcrumb_row.html.erb` - Breadcrumb navigation
- [ ] `pwb/props/_images_section_carousel.html.erb` - Image carousel
- [ ] `pwb/props/_request_prop_info.html.erb` - Request info form

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
# Run theme completeness test
bundle exec rspec spec/views/themes/theme_completeness_spec.rb

# Run E2E tests (if available)
npx playwright test
```

## Common Mistakes to Avoid

1. **Missing `pwb/pages/show.html.erb`** - Causes About Us and other content pages to break
2. **Missing `pwb/sections/contact_us.html.erb`** - Causes Contact page to break
3. **Missing `pwb/components/_form_and_map.html.erb`** - Causes Contact page map/form to break
4. **Forgetting to add CSS to asset precompile list** - Causes styling to fail in production
5. **Not testing all pages** - Easy to miss broken pages

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
