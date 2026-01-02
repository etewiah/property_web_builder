# Brussels Theme Implementation Plan

**Created:** January 2025
**Status:** Planning
**Reference:** [BRUSSELS_THEME_PROPOSAL.md](./BRUSSELS_THEME_PROPOSAL.md)

---

## Overview

This document outlines the phased implementation plan for the Brussels theme, including specific tasks, file locations, testing requirements, and documentation updates.

---

## Phase 1: Foundation (Estimated: 2-3 hours)

### 1.1 Create Theme Directory Structure

**Task:** Set up the basic file structure for the Brussels theme.

```bash
mkdir -p app/themes/brussels/{palettes,views/layouts/pwb,views/pwb,views/components,page_parts/heroes}
```

**Files to create:**
- `app/themes/brussels/palettes/default.json`
- `app/themes/brussels/palettes/ocean_blue.json` (optional variant)
- `app/themes/brussels/palettes/sunset_gold.json` (optional variant)

### 1.2 Add Theme to Configuration

**File:** `app/themes/config.json`

**Action:** Add Brussels theme entry:
```json
{
  "name": "brussels",
  "friendly_name": "Brussels",
  "id": "brussels",
  "version": "1.0.0",
  "enabled": true,
  "parent_theme": "default",
  "description": "Modern clean theme with lime green accents and minimal design",
  "author": "PropertyWebBuilder",
  "tags": ["modern", "minimal", "green", "clean"]
}
```

### 1.3 Create Default Palette

**File:** `app/themes/brussels/palettes/default.json`

**Key colors:**
| Variable | Value | Description |
|----------|-------|-------------|
| `primary_color` | `#9ACD32` | Lime green accent |
| `secondary_color` | `#131313` | Dark gray |
| `header_background_color` | `#13131385` | Semi-transparent header |
| `footer_background_color` | `#616161` | Gray footer |

### 1.4 Create Tailwind Input File

**File:** `app/assets/stylesheets/tailwind-brussels.css`

**Contents:**
- Import Tailwind
- Import Catamaran font from Google Fonts
- Define theme variables in `@theme` block
- Add Material Design shadow utilities
- Add PWB utility classes

### 1.5 Create CSS Variables Partial

**File:** `app/views/pwb/custom_css/_brussels.css.erb`

**Contents:**
- Brussels-specific CSS variables (`--br-*` prefix)
- Theme class styles (`.brussels-theme`)
- Component-specific styles (header, footer, cards, buttons)

### 1.6 Add Build Scripts

**File:** `package.json`

**Add scripts:**
```json
{
  "scripts": {
    "build:css:brussels": "tailwindcss -i ./app/assets/stylesheets/tailwind-brussels.css -o ./app/assets/builds/tailwind-brussels.css --minify"
  }
}
```

**Verification:**
- [ ] Theme directory exists with correct structure
- [ ] Config.json includes Brussels entry
- [ ] Palette JSON validates with PaletteValidator
- [ ] Tailwind builds without errors
- [ ] CSS variables render correctly

---

## Phase 2: Core Templates (Estimated: 4-6 hours)

### 2.1 Application Layout

**File:** `app/themes/brussels/views/layouts/pwb/application.html.erb`

**Features:**
- Catamaran font link
- Material Symbols icon font
- `.brussels-theme` wrapper class
- Sticky header support
- Back-to-top button

### 2.2 Header Partial

**File:** `app/themes/brussels/views/pwb/_header.html.erb`

**Design specifications:**
- Semi-transparent dark overlay background
- Fixed/sticky positioning
- Logo left-aligned
- Navigation links: Properties, About, Services, Contact
- Right side: Callback button, Favorites, Language selector
- Active link highlight in lime green

### 2.3 Footer Partial

**File:** `app/themes/brussels/views/pwb/_footer.html.erb`

**Design specifications:**
- Three-column layout for links
- Gray background (`#616161`)
- White text with categorized links
- Copyright and legal links at bottom
- Partner logo area

### 2.4 Property Card Component

**File:** `app/themes/brussels/views/components/_property_card.html.erb`

**Design specifications:**
- White background, no border radius
- Material Design shadow (3-level elevation)
- Image with favorite button overlay
- Title, location, price display
- Feature icons (beds, baths, area)
- Hover lift effect

### 2.5 Search Form Component

**File:** `app/themes/brussels/views/components/_search_form.html.erb`

**Design specifications:**
- Semi-transparent white background with blur
- Fields: City, Property Type, Price range, Reference, Beds, Baths
- Green search button
- Advanced search link

**Verification:**
- [ ] Layout renders without errors
- [ ] Header displays correctly on all screen sizes
- [ ] Footer links work correctly
- [ ] Property cards display all required information
- [ ] Search form submits correctly

---

## Phase 3: Page Templates (Estimated: 6-8 hours)

### 3.1 Homepage

**File:** `app/themes/brussels/views/pwb/welcome/index.html.erb`

**Sections:**
1. Hero with full-width image and search overlay
2. Location tiles (optional, configurable)
3. CTA banner ("Property to sell?")
4. Featured properties carousel
5. Search by map section
6. Category links grid
7. About/Why Us section with tabs

### 3.2 Property Listing Page

**File:** `app/themes/brussels/views/pwb/search/buy.html.erb`
**File:** `app/themes/brussels/views/pwb/search/rent.html.erb`

**Layout:**
- Breadcrumb navigation
- Filters sidebar (collapsible on mobile)
- Property grid (3-4 columns)
- Pagination
- Sort options

### 3.3 Property Detail Page

**File:** `app/themes/brussels/views/pwb/props/show.html.erb`

**Sections:**
1. Breadcrumb
2. Image gallery (main + thumbnails)
3. Property title and price
4. Key features (beds, baths, area)
5. Description
6. Features/amenities list
7. Location map
8. Contact form
9. Similar properties

### 3.4 Hero Page Part

**File:** `app/themes/brussels/page_parts/heroes/hero_search.liquid`

**Features:**
- Liquid template for CMS editability
- Background image placeholder
- Search form integration
- Mobile-responsive layout

**Verification:**
- [ ] Homepage loads all sections correctly
- [ ] Listing page filters work
- [ ] Property cards link to detail pages
- [ ] Detail page displays all property information
- [ ] Contact form submits successfully
- [ ] Mobile layout is responsive

---

## Phase 4: Testing (Estimated: 4-5 hours)

### 4.1 Palette Validation Specs

**File:** `spec/services/pwb/palette_validator_spec.rb` (add context)

```ruby
describe "Brussels theme palettes" do
  let(:theme_name) { "brussels" }

  it "validates default palette" do
    palette = Pwb::PaletteLoader.load(theme_name, "default")
    result = Pwb::PaletteValidator.validate(palette)
    expect(result).to be_valid
  end

  it "has all required color keys" do
    palette = Pwb::PaletteLoader.load(theme_name, "default")
    expect(palette["colors"]).to include(
      "primary_color",
      "secondary_color",
      "header_background_color",
      "footer_background_color"
    )
  end
end
```

### 4.2 Theme Rendering Specs

**File:** `spec/views/themes/brussels_spec.rb`

```ruby
RSpec.describe "Brussels theme" do
  let(:website) { create(:website, theme: "brussels") }

  before { Pwb::Current.website = website }

  it "renders homepage" do
    render template: "pwb/welcome/index"
    expect(rendered).to have_css(".brussels-theme")
  end

  it "applies Brussels CSS variables" do
    render template: "pwb/custom_css/_brussels"
    expect(rendered).to include("--br-header-bg")
  end
end
```

### 4.3 WCAG Contrast Compliance Specs

**File:** `spec/services/pwb/color_utils_spec.rb` (add context)

```ruby
describe "Brussels palette WCAG compliance" do
  let(:palette) { Pwb::PaletteLoader.load("brussels", "default") }

  it "passes contrast for text on background" do
    ratio = Pwb::ColorUtils.contrast_ratio(
      palette.dig("colors", "text_color"),
      palette.dig("colors", "background_color")
    )
    expect(ratio).to be >= 4.5 # WCAG AA
  end

  it "passes contrast for footer text" do
    ratio = Pwb::ColorUtils.contrast_ratio(
      palette.dig("colors", "footer_text_color"),
      palette.dig("colors", "footer_background_color")
    )
    expect(ratio).to be >= 4.5
  end
end
```

### 4.4 Playwright E2E Visual Tests

**File:** `e2e/tests/themes/brussels.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Brussels Theme', () => {
  test.beforeEach(async ({ page }) => {
    // Set up test website with Brussels theme
  });

  test('homepage renders correctly', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('.brussels-theme')).toBeVisible();
    await expect(page).toHaveScreenshot('brussels-homepage.png');
  });

  test('property cards display correctly', async ({ page }) => {
    await page.goto('/properties');
    const card = page.locator('.property-card').first();
    await expect(card).toHaveCSS('box-shadow', /rgba\(0, 0, 0/);
  });

  test('header is sticky', async ({ page }) => {
    await page.goto('/');
    await page.evaluate(() => window.scrollTo(0, 500));
    const header = page.locator('header');
    await expect(header).toBeVisible();
  });
});
```

**Verification:**
- [ ] All palette validation specs pass
- [ ] Theme rendering specs pass
- [ ] WCAG contrast specs pass
- [ ] Playwright E2E tests pass
- [ ] Visual regression tests have baseline screenshots

---

## Phase 5: Documentation (Estimated: 1-2 hours)

### 5.1 Update Theme README

**File:** `docs/theming/README.md`

**Add:**
- Brussels to available themes list
- Link to Brussels theme proposal
- Example configuration snippet

### 5.2 Theme Selection Guide

**File:** `docs/theming/THEME_SELECTION_GUIDE.md` (create if not exists)

**Content:**
```markdown
## Brussels Theme

**Best for:** Modern, clean websites with a fresh aesthetic

**Characteristics:**
- Lime green accent color (#9ACD32)
- Minimal borders and sharp corners
- Material Design shadows
- Catamaran typography

**Palettes available:**
- Default (Lime Green)
- Ocean Blue (optional)
- Sunset Gold (optional)
```

### 5.3 Update Skills Documentation

**File:** `.claude/skills/theme-creation/SKILL.md`

**Add:**
- Brussels as example of implemented theme
- Reference to Brussels implementation plan

**Verification:**
- [ ] README lists Brussels as available theme
- [ ] Selection guide includes Brussels details
- [ ] Skills documentation updated

---

## Summary Timeline

| Phase | Tasks | Estimated Time | Dependencies |
|-------|-------|----------------|--------------|
| **Phase 1** | Foundation | 2-3 hours | None |
| **Phase 2** | Core Templates | 4-6 hours | Phase 1 |
| **Phase 3** | Page Templates | 6-8 hours | Phase 2 |
| **Phase 4** | Testing | 4-5 hours | Phase 3 |
| **Phase 5** | Documentation | 1-2 hours | Phase 4 |
| **Total** | | **17-24 hours** | |

---

## Risk Mitigation

### Potential Issues

1. **Catamaran font loading**: Ensure fallback to system fonts
2. **Semi-transparent header**: Test on various background images
3. **Lime green contrast**: May need dark text on green buttons for WCAG
4. **Material shadows**: Ensure performance on mobile devices

### Rollback Plan

If issues arise:
1. Set `"enabled": false` in config.json
2. Users on Brussels theme fall back to parent (default)
3. Fix issues and re-enable

---

## Acceptance Criteria

Before marking complete:

- [ ] All 5 phases completed
- [ ] All tests passing (unit, integration, E2E)
- [ ] WCAG AA compliance verified
- [ ] Mobile responsive on all pages
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Deployed to staging for QA

---

**Document Version:** 1.0
**Last Updated:** January 2025
