# Scripts

This directory contains utility scripts for PropertyWebBuilder development and documentation.

## Screenshot Scripts

### take-screenshots.js

A Playwright-based script that captures screenshots of all public pages at multiple viewport sizes.

**Usage:**

```bash
# Capture screenshots for the default theme
node scripts/take-screenshots.js

# Capture screenshots for a specific theme
SCREENSHOT_THEME=brisbane node scripts/take-screenshots.js

# Use a different base URL
BASE_URL=http://localhost:5000 node scripts/take-screenshots.js
```

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_URL` | `http://localhost:3000` | The base URL of the running Rails server |
| `SCREENSHOT_THEME` | `default` | Theme name for output directory organization |

**Captured Pages:**

| Page | Path | Description |
|------|------|-------------|
| home | `/` | Homepage (default locale) |
| home-en | `/en` | Homepage (English locale) |
| buy | `/en/buy` | Property search - For Sale |
| rent | `/en/rent` | Property search - For Rent |
| contact | `/contact-us` | Contact Us page |
| about | `/about-us` | About Us page |

**Viewports:**

- **Desktop**: 1440x900
- **Mobile**: 375x812

**Output:**

Screenshots are saved to `docs/screenshots/{theme}/` with naming pattern `{page}-{viewport}.png`.

**Prerequisites:**

```bash
npm install playwright
npx playwright install chromium
```

---

### capture_all_themes.rb

A Rails runner script that automates screenshot capture across all themes by:

1. Saving the current theme
2. Iterating through all themes (default, brisbane, bologna)
3. Updating the website's theme in the database
4. Running `take-screenshots.js` for each theme
5. Restoring the original theme

**Usage:**

```bash
# Ensure the Rails server is running in another terminal
bundle exec rails server

# In a separate terminal, run the capture script
bundle exec rails runner scripts/capture_all_themes.rb
```

**How it works:**

1. Queries `Pwb::Website.first` to get the main website record
2. Stores the original theme name
3. For each theme in `['default', 'brisbane', 'bologna']`:
   - Updates `website.theme_name` to the current theme
   - Clears the Rails cache
   - Runs `take-screenshots.js` with the `SCREENSHOT_THEME` env var
4. Restores the original theme when complete

**Output:**

```
docs/screenshots/
├── default/
│   ├── home-desktop.png
│   ├── home-mobile.png
│   ├── buy-desktop.png
│   └── ...
├── brisbane/
│   └── ...
└── bologna/
    └── ...
```

**Note:** The `docs/screenshots/` directory is gitignored. Screenshots are generated locally for development and documentation purposes.

---

## Adding New Scripts

When adding new scripts to this directory:

1. Use appropriate shebang (`#!/usr/bin/env node` or `#!/usr/bin/env ruby`)
2. Add a descriptive comment block at the top
3. Document the script in this README
4. Consider adding environment variable support for configuration
