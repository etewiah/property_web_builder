# Theme Creation Quick Reference

**Last Updated:** 2025-12-27

## Critical Files Checklist

Use this as a quick reference when creating a new theme. For full details, see [THEME_CREATION_CHECKLIST.md](THEME_CREATION_CHECKLIST.md).

### ✅ Absolute Must-Haves (Will Break Without These)

1. **Custom CSS Partial** ⚠️ **MOST COMMON MISS**
   ```
   app/views/pwb/custom_css/_<theme_name>.css.erb
   ```
   - Called by layout's `custom_styles` helper
   - Missing = `ActionView::MissingTemplate` error
   - Copy from `_default.css.erb` and customize

2. **Property Row Partial** ⚠️ **COMMON MISS IF HOME SHOWS PROPERTIES**
   ```
   app/themes/<theme_name>/views/pwb/welcome/_single_property_row.html.erb
   ```
   - Used by `welcome/index.html.erb` if properties exist
   - Missing = `ActionView::MissingTemplate` on home page
   - Copy from another theme

3. **15 Required Templates**
   - Layout: `layouts/pwb/application.html.erb`
   - Header/Footer: `pwb/_header.html.erb`, `pwb/_footer.html.erb`
   - Pages: `welcome/index`, `search/buy`, `search/rent`, `props/show`, `pages/show`, `sections/contact_us`
   - Partials: Search forms, results, contact form, components
   - Run test: `bundle exec rspec spec/views/themes/theme_completeness_spec.rb`

### 📦 Build Configuration

1. **Tailwind CSS File**
   ```
   app/assets/stylesheets/tailwind-<theme_name>.css
   ```

2. **package.json** - Add build scripts:
   ```json
   "tailwind:<theme>": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-<theme>.css -o ./app/assets/builds/tailwind-<theme>.css",
   "tailwind:<theme>:prod": "... --minify",
   "tailwind:build": "... && npm run tailwind:<theme>"
   ```

3. **config/initializers/assets.rb** - Add to precompile:
   ```ruby
   Rails.application.config.assets.precompile += %w[tailwind-<theme>.css]
   ```

4. **app/themes/config.json** - Register theme with metadata

### 🧪 Validation

Run this before committing:
```bash
bundle exec rspec spec/views/themes/theme_completeness_spec.rb
```

Should report:
```
<THEME> THEME [COMPLETE]
  Required:    15/15 (100.0%)
  CSS Partial: YES
```

### 🚨 Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Missing partial pwb/custom_css/_<theme>` | No CSS partial | Create `app/views/pwb/custom_css/_<theme>.css.erb` |
| `Missing partial pwb/welcome/_single_property_row` | No property row partial | Copy from another theme to `app/themes/<theme>/views/pwb/welcome/` |
| CSS not loading in production | Not in precompile list | Add to `config/initializers/assets.rb` |
| Tailwind build fails | Missing package.json entry | Add build script to `package.json` |

### 📋 Copy-Paste Template

When creating a new theme, copy these files first:

```bash
THEME_NAME="yourtheme"

# 1. Create directory structure
mkdir -p app/themes/$THEME_NAME/views/{layouts/pwb,pwb/{components,pages,props,search,sections,welcome}}

# 2. Copy all required templates from default theme
cp -r app/themes/default/views/* app/themes/$THEME_NAME/views/

# 3. Create CSS partial (CRITICAL!)
cp app/views/pwb/custom_css/_default.css.erb app/views/pwb/custom_css/_${THEME_NAME}.css.erb

# 4. Create Tailwind CSS
cp app/assets/stylesheets/tailwind-default.css app/assets/stylesheets/tailwind-${THEME_NAME}.css

# 5. Build CSS
npm run tailwind:build

# 6. Run tests
bundle exec rspec spec/views/themes/theme_completeness_spec.rb
```

### 🔍 Testing Checklist

After creation, manually test:
- [ ] Home page (`/`)
- [ ] Buy/Search page (`/en/buy`)
- [ ] Rent page (`/en/rent`)
- [ ] Property detail page (click any property)
- [ ] About Us page (`/en/about-us`)
- [ ] Contact Us page (`/en/contact-us`)

All should render without `ActionView::MissingTemplate` errors.

---

**Remember:** The two most common misses are:
1. `app/views/pwb/custom_css/_<theme>.css.erb` (breaks layout)
2. `pwb/welcome/_single_property_row.html.erb` (breaks home page if properties exist)
