# BEM Implementation Plan

## Overview

With theme inheritance now working, BEM class naming can be implemented in the **default theme only**. Child themes (brisbane, biarritz, bologna, brussels, barcelona) will automatically inherit these changes for any files they don't override.

## Implementation Phases

### Phase 1: Core Layout Components (High Impact)
Files that affect all pages:

| File | Priority | BEM Classes to Add |
|------|----------|-------------------|
| `default/layouts/pwb/application.html.erb` | HIGH | `pwb-body`, `pwb-main` |
| `default/pwb/_header.html.erb` | HIGH | `pwb-header`, `pwb-header__*` |
| `default/pwb/_footer.html.erb` | HIGH | `pwb-footer`, `pwb-footer__*` |

### Phase 2: Property Components (Core Functionality)
Files for property listings and details:

| File | BEM Block |
|------|-----------|
| `default/pwb/search/_search_result_item.html.erb` | `pwb-prop-card` |
| `default/pwb/props/show.html.erb` | `pwb-prop-detail` |
| `default/pwb/props/_prop_info_list.html.erb` | `pwb-prop-detail__*` |
| `default/pwb/props/_breadcrumb_row.html.erb` | `pwb-breadcrumb` |

### Phase 3: Search Components
| File | BEM Block |
|------|-----------|
| `default/pwb/search/_search_form_for_sale.html.erb` | `pwb-search-box` |
| `default/pwb/search/_search_form_for_rent.html.erb` | `pwb-search-box` |
| `default/pwb/search/_search_form_landing.html.erb` | `pwb-search-box` |

### Phase 4: Form Components
| File | BEM Block |
|------|-----------|
| `default/pwb/props/_request_prop_info.html.erb` | `pwb-form` |
| `default/pwb/sections/_contact_us_form.html.erb` | `pwb-form` |
| `app/helpers/pwb/application_helper.rb` | `pwb-form__*` |

### Phase 5: Seed YAML Files
Update page part templates in `db/yml_seeds/page_parts/`:
- `home__heroes_*.yml` - Add `pwb-hero`, `pwb-hero__*`
- `home__cta_*.yml` - Add `pwb-section`, `pwb-btn`
- `home__features_*.yml` - Add `pwb-section--features`

## BEM Class Reference

From `docs/FRONTEND_STANDARDS.md`:

```
.pwb-body           - Root body element
.pwb-main           - Main content wrapper
.pwb-header         - Site header container
.pwb-header__*      - Header elements (logo-wrapper, logo-img, nav, etc.)
.pwb-footer         - Site footer container
.pwb-prop-card      - Property card wrapper
.pwb-prop-card__*   - Card elements (img, body, title, price, etc.)
.pwb-prop-detail    - Property detail page wrapper
.pwb-prop-detail__* - Detail elements (title, price, gallery, map, etc.)
.pwb-search-box     - Search container
.pwb-search-box__*  - Search elements (input, select, submit, etc.)
.pwb-form           - Form wrapper
.pwb-form__*        - Form elements (group, label, input, submit, etc.)
.pwb-btn--primary   - Primary button modifier
.pwb-btn--secondary - Secondary button modifier
```

## Key Rules

1. **Always place semantic class BEFORE Tailwind utilities**
   ```html
   <button class="pwb-btn--primary bg-blue-500 text-white">
   ```

2. **Use `pwb-container` for width-constrained containers**
   ```html
   <div class="pwb-container container mx-auto px-4">
   ```

3. **Child themes override**
   - If a child theme has its own version of a file, update that file too
   - Example: brisbane has custom `_header.html.erb`, so it needs separate BEM updates

## Files Requiring Separate Updates (Due to Customization)

### brisbane theme (17 customized files)
- `layouts/pwb/application.html.erb`
- `pwb/_header.html.erb`
- `pwb/_footer.html.erb`
- `pwb/search/_search_form_for_rent.html.erb`
- `pwb/search/_search_form_for_sale.html.erb`
- (and 12 more...)

### Other themes
- bologna: 18 customized files
- brussels: 19 customized files
- barcelona: 21 customized files (disabled theme)
- biarritz: 8 customized files

## Verification

After implementation, verify with:
```bash
# Check for pwb- classes in default theme
grep -r "pwb-" app/themes/default/views/ | head -20

# Verify no missing semantic classes on key elements
grep -rL "pwb-header" app/themes/*/views/pwb/_header.html.erb
```
