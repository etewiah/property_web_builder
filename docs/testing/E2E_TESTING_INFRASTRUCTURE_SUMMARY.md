# E2E Testing Infrastructure Summary

## Overview

PropertyWebBuilder has a comprehensive Playwright-based E2E testing infrastructure with dedicated test environments, seeding systems, and support tooling. This document provides a detailed analysis of the existing infrastructure.

---

## 1. Playwright Configuration

### Location
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/playwright.config.js`

### Key Configuration Details

```javascript
testDir: './tests/e2e'
globalSetup: './tests/e2e/global-setup.js'
fullyParallel: true
```

### Features
- **Global Setup:** Verifies E2E database initialization before running tests
- **Parallel Execution:** Tests run in parallel by default
- **CI Behavior:** 
  - 2 retries on CI
  - Single worker on CI (serial execution)
  - 0 retries on local runs
- **Base URL:** `http://tenant-a.e2e.localhost:3001` (configurable per test)
- **Reporters:** HTML report + list format
- **Test Artifacts:**
  - Screenshots on failure only
  - Traces on first retry
  - Videos on first retry

### Browser Projects
```javascript
projects: [
  {
    name: 'chromium',
    testIgnore: '**/admin/**',  // Admin tests excluded (run separately)
  },
  {
    name: 'chromium-admin',
    testMatch: '**/admin/**',
    fullyParallel: false,  // Admin tests run serially (modify shared state)
  }
]
```

**Note:** Firefox and WebKit projects are commented out but available for future use.

---

## 2. Rake Tasks for E2E Testing

### Location
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/lib/tasks/playwright.rake`

### Available Tasks

#### `playwright:reset` (Primary Setup)
```bash
RAILS_ENV=e2e bin/rails playwright:reset
```
**Purpose:** Complete E2E test database setup
- Drops existing E2E database
- Creates new database
- Runs all migrations
- Loads E2E seed data from `db/seeds/e2e_seeds.rb`
- Checks seed image availability (R2 or local fallback)

#### `playwright:seed` (Data-Only)
```bash
RAILS_ENV=e2e bin/rails playwright:seed
```
**Purpose:** Reseed test data without dropping the database
- Loads E2E seed data from `db/seeds/e2e_seeds.rb`
- Useful for resetting test state between test runs
- Preserves database schema

#### `playwright:server` (Web Server)
```bash
RAILS_ENV=e2e bin/rails playwright:server
```
**Purpose:** Start Rails server for E2E testing
- Runs on port 3001
- Displays test credentials on startup
- Shows available tenant URLs
- Output example:
  ```
  Tenant A: http://tenant-a.e2e.localhost:3001
    Admin: admin@tenant-a.test / password123
    User:  user@tenant-a.test / password123
  Tenant B: http://tenant-b.e2e.localhost:3001
    Admin: admin@tenant-b.test / password123
    User:  user@tenant-b.test / password123
  ```

#### `playwright:server_bypass_auth` (Admin Bypass Mode)
```bash
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```
**Purpose:** Start server with admin authentication disabled
- Sets `BYPASS_ADMIN_AUTH=true` environment variable
- Allows access to admin pages without login
- Useful for testing admin UI without auth flow
- Shows accessible admin paths on startup:
  - `/site_admin`
  - `/site_admin/website/settings`
  - `/site_admin/pages`
  - `/site_admin/props`

---

## 3. E2E Database and Environment Configuration

### Location
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/config/environments/e2e.rb`

### Key Configuration Features

#### Database & Isolation
```ruby
config.cache_store = :null_store  # No caching for consistent tests
config.action_controller.perform_caching = false
```

#### Subdomain Configuration
```ruby
config.hosts << "tenant-a.e2e.localhost"
config.hosts << "tenant-b.e2e.localhost"
```

#### Security & Testing
```ruby
config.middleware.delete Rack::Attack  # Disable rate limiting for tests
skip_before_action :verify_authenticity_token  # In test support controller
```

#### Logging
- Dual logging to file and stdout
- Log level: debug
- Log file: `log/e2e.log`

#### Active Record & Zeitwerk
```ruby
# Handles both rake tasks (eager load, no reload) and web server (hot reload)
running_in_rake = defined?(Rake) && !Rake.application.top_level_tasks.empty?
config.enable_reloading = !running_in_rake
config.eager_load = running_in_rake
```

### Environment Variables
```bash
RAILS_ENV=e2e                    # Required for all E2E operations
DATABASE_URL=postgres://...e2e   # E2E database connection
BYPASS_ADMIN_AUTH=true           # Enable admin auth bypass (optional)
```

---

## 4. Seed Data and Test Fixtures

### Location
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/e2e_seeds.rb`

### Comprehensive Seeding Approach

The E2E seed file creates a fully functional test environment with:

#### Test Tenants
```ruby
tenant_a = Pwb::Website.find_or_create_by!(subdomain: 'tenant-a')
  # company_display_name: 'Tenant A Real Estate'
  # theme_name: 'default'

tenant_b = Pwb::Website.find_or_create_by!(subdomain: 'tenant-b')
  # company_display_name: 'Tenant B Real Estate'
  # theme_name: 'default'
```

#### Test Users (from `db/yml_seeds/e2e_users.yml`)
```yaml
tenant_a:
  admin:
    email: admin@tenant-a.test
    password: password123
    admin: true
  regular:
    email: user@tenant-a.test
    password: password123
    admin: false
tenant_b:
  admin:
    email: admin@tenant-b.test
    password: password123
    admin: true
  regular:
    email: user@tenant-b.test
    password: password123
    admin: false
```

#### User Memberships
- Admin users: `admin` role with `active: true`
- Regular users: `member` role with `active: true`
- Each user scoped to their respective website

#### Sample Contacts & Messages
- Per-tenant contacts with test email addresses
- Sample messages for each tenant:
  - Property inquiry messages
  - General contact messages
  - Message delivery status variation (success/failed)

#### Sample Properties
**For Sale:** 4 properties per tenant
- `US-SALE-001`: Family home (4BR, 2BA, $425K)
- `US-SALE-002`: Luxury apartment (2BR, 2BA, $1.85M)
- `US-SALE-003`: Oceanfront villa (5BR, 4BA, $5.5M)
- `US-SALE-004`: Historic townhouse (3BR, 2BA, $875K)

**For Rent:** 4 properties per tenant
- `US-RENT-001`: Downtown apartment (1BR, 1BA, $2,800/mo)
- `US-RENT-002`: Family home (3BR, 2BA, $3,200/mo)
- `US-RENT-003`: Studio (0BR, 1BA, $1,950/mo, furnished)
- `US-RENT-004`: Luxury penthouse (3BR, 3BA, $8,500/mo)

#### Property Details
Each property includes:
- Complete address information with coordinates
- Bedroom/bathroom/garage counts
- Construction year and area measurements
- Property state (new_build, excellent, good, renovated)
- Image attachments (external URL or local fallback)
- Features/amenities (gardens, pools, heating systems, security)
- Active & visible listing status

#### Materialized View Refresh
```ruby
Pwb::ListedProperty.refresh  # For property search queries
```

---

## 5. E2E Test File Structure

### Location
**Directory:** `/Users/etewiah/dev/sites-older/property_web_builder/tests/e2e/`

### Test Files Organization

#### Global Setup
- **File:** `global-setup.js`
- **Purpose:** Pre-test database verification
- **Logic:** Uses Rails runner to verify tenant-a website exists in e2e database
- **Failure:** Provides detailed error message with setup instructions

#### Public Tests (`public/`)
```
public/
├── contact-forms.spec.js           # Contact form submission tests
├── property_display.spec.js        # Property rendering tests
├── property-browsing.spec.js       # Property list navigation
├── property-details.spec.js        # Individual property pages
├── property-search.spec.js         # Search filters & results
├── search-layout-compliance.spec.js # Layout requirements
└── theme-rendering.spec.js         # Theme appearance tests
```

#### Authentication Tests (`auth/`)
```
auth/
├── admin_login.spec.js      # Multi-tenant admin login (SKIPPED - auth tested via unit tests)
├── sessions.spec.js         # Session management
└── tenant-isolation.spec.js # Cross-tenant isolation verification
```

#### Admin Tests (`admin/`)
```
admin/
├── admin-to-site-integration.spec.js  # Admin→public site integration
├── editor.spec.js                     # In-context page editor
├── onboarding.spec.js                 # Onboarding flow
├── properties-settings.spec.js        # Property management
└── site-settings-integration.spec.js  # Settings integration
```

#### Images Tests (`images/`)
```
images/
└── cdn-delivery.spec.js  # CDN/CloudFlare R2 image delivery
```

#### Other
- **File:** `search.spec.js` (root)
- **Purpose:** Search functionality with snapshot testing
- **Artifacts:** Visual regression snapshots in `search.spec.js-snapshots/`

### Total Test Files
**17 spec files** covering:
- Public property browsing and search
- Authentication and tenant isolation
- Admin interface and settings
- Theme rendering
- Image delivery
- Contact forms

---

## 6. Test Helper Functions & Fixtures

### Location: Fixtures
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/tests/e2e/fixtures/test-data.js`

### Test Data Export
```javascript
TENANTS = {
  A: { subdomain: 'tenant-a', baseURL: 'http://tenant-a.e2e.localhost:3001', ... },
  B: { subdomain: 'tenant-b', baseURL: 'http://tenant-b.e2e.localhost:3001', ... }
}

ADMIN_USERS = {
  TENANT_A: { email: 'admin@tenant-a.test', password: 'password123', tenant: TENANTS.A },
  TENANT_B: { email: 'admin@tenant-b.test', password: 'password123', tenant: TENANTS.B }
}

PROPERTIES = {
  SALE: { title: 'Test Sale Property', price: '250000', bedrooms: '3', type: 'for-sale' },
  RENTAL: { title: 'Test Rental Property', price: '1500', bedrooms: '2', type: 'for-rent' }
}

ROUTES = {
  HOME: '/',
  BUY: '/en/buy',
  RENT: '/en/rent',
  LOGIN: '/users/sign_in',
  ADMIN: { DASHBOARD: '/site_admin', PROPERTIES: '/site_admin/props', ... }
}
```

### Location: Helpers
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/tests/e2e/fixtures/helpers.js`

### Helper Functions

#### Authentication
- `loginAsAdmin(page, adminUser)` - Login as admin user
- `expectToBeLoggedIn(page)` - Verify not on login page
- `expectToBeOnLoginPage(page)` - Verify on login page

#### Navigation
- `goToTenant(page, tenant, path)` - Navigate to tenant URL with load state
- `goToAdminPage(page, tenant, adminPath)` - Navigate to admin page (with auth bypass)
- `waitForPageLoad(page)` - Wait for full page load

#### Form Interaction
- `fillField(page, fieldIdentifier, value)` - Fill form by label/name/id
- `getCsrfToken(page)` - Extract CSRF token from meta tag
- `submitFormWithCsrf(page, formSelector)` - Submit form with CSRF
- `saveAndWait(page, buttonText)` - Click save and wait for network

#### Page Assertions
- `expectPageToHaveAnyContent(page, alternatives)` - Verify page has any of multiple texts

#### Test Data Reset (via endpoints)
- `resetWebsiteSettings(page, tenant)` - POST `/e2e/reset_website_settings`
- `resetAllTestData(page, tenant)` - POST `/e2e/reset_all`
- `isE2eEnvironment(page, tenant)` - GET `/e2e/health` check

---

## 7. E2E Test Support Endpoints

### Location
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/e2e/test_support_controller.rb`

### Endpoints
All endpoints require: `Rails.env.e2e? && ENV['BYPASS_ADMIN_AUTH'] == 'true'`

#### GET `/e2e/health`
**Response:**
```json
{
  "success": true,
  "environment": "e2e",
  "bypass_auth": true,
  "website": "tenant-a"
}
```
**Use:** Health check to verify E2E mode is enabled

#### POST `/e2e/reset_website_settings`
**Response:**
```json
{
  "success": true,
  "message": "Website settings reset to seed values",
  "website": {
    "subdomain": "tenant-a",
    "company_display_name": "Tenant A Real Estate",
    "default_currency": "USD",
    "default_area_unit": "sqmt",
    "theme_name": "default"
  }
}
```
**Reset Actions:**
- Restore company_display_name to seed value
- Set locale to 'en-UK'
- Set currency to 'USD'
- Set area unit to 'sqmt'
- Set theme to 'default'
- Disable external_image_mode
- Reset supported_locales to ['en']

#### POST `/e2e/reset_all`
**Similar to reset_website_settings, plus:**
- Resets agency data (company_name, display_name)
- More comprehensive but slower
- For complete test state cleanup

---

## 8. Lighthouse and Performance Testing

### Location
**Config File:** `/Users/etewiah/dev/sites-older/property_web_builder/lighthouserc.js`

### Purpose
Automated performance auditing with Lighthouse CI

### Configuration

#### Collection Settings
```javascript
numberOfRuns: 3  // Average results over 3 runs
startServerCommand: 'bundle exec rails server -p 3000 -e test'
startServerReadyPattern: 'Listening on'
startServerReadyTimeout: 30000
```

#### Audited URLs
- `http://localhost:3000/` (homepage)
- `http://localhost:3000/buy` (for-sale search)
- `http://localhost:3000/rent` (for-rent search)

#### Chrome Settings
```javascript
chromeFlags: '--no-sandbox --headless --disable-gpu'
throttlingMethod: 'simulate'
preset: 'desktop'
```

#### Performance Budgets & Assertions
```javascript
'categories:performance': ['error', { minScore: 0.7 }]    // Fail if <70%
'categories:accessibility': ['error', { minScore: 0.9 }]  // Fail if <90%
'categories:best-practices': ['warn', { minScore: 0.9 }]  // Warn if <90%
'categories:seo': ['error', { minScore: 0.9 }]            // Fail if <90%
```

#### Core Web Vitals Targets
```javascript
'first-contentful-paint': ['warn', { maxNumericValue: 2500 }]      // ≤2.5s
'largest-contentful-paint': ['error', { maxNumericValue: 4000 }]   // ≤4.0s
'cumulative-layout-shift': ['error', { maxNumericValue: 0.25 }]    // ≤0.25
'total-blocking-time': ['warn', { maxNumericValue: 500 }]          // ≤500ms
```

#### Resource Optimization Checks
```javascript
'render-blocking-resources': 'off'        // Addressed elsewhere
'uses-responsive-images': 'warn'
'offscreen-images': 'warn'
'uses-webp-images': 'warn'
'unused-css-rules': 'warn'
'unused-javascript': 'warn'
```

#### Upload
```javascript
target: 'temporary-public-storage'  // For CI artifacts
```

### CI/CD Integration
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/.github/workflows/lighthouse.yml`

#### Workflow Triggers
- Push to master or develop
- Pull requests to master

#### Pipeline Steps
1. PostgreSQL database service setup
2. Ruby environment setup (3.2)
3. Node environment setup (22)
4. Dependency installation
5. Asset building
6. Lighthouse CI run
7. PR comment with results (on PR)

#### Results Handling
- Uploads HTML artifacts
- Posts results to PR comments
- Uses temporary public storage for reports

---

## 9. Screenshot and Documentation Scripts

### Location
**Directory:** `/Users/etewiah/dev/sites-older/property_web_builder/scripts/`

### Screenshot Capture Scripts

#### `take-screenshots.js`
**Purpose:** Playwright-based screenshot automation

**Usage:**
```bash
node scripts/take-screenshots.js
SCREENSHOT_THEME=brisbane node scripts/take-screenshots.js
BASE_URL=http://localhost:5000 node scripts/take-screenshots.js
```

**Environment Variables:**
- `BASE_URL` (default: `http://localhost:3000`)
- `SCREENSHOT_THEME` (default: `default`)
- `MAX_SIZE_MB` (default: `2`)

**Pages Captured:**
- home (`/`)
- home-en (`/en`)
- buy (`/en/buy`)
- rent (`/en/rent`)
- sell (`/p/sell`)
- contact (`/contact-us`)
- about (`/about-us`)
- Dynamic pages (property details)

**Viewports:**
- Desktop: 1440x900
- Mobile: 375x812

**Output:**
- Location: `docs/screenshots/{theme}/`
- Format: PNG with auto-compression
- Compression: Uses sharp library (optional)

#### `capture_all_themes.rb`
**Purpose:** Rails runner script to capture all themes at once

**Usage:**
```bash
bundle exec rails runner scripts/capture_all_themes.rb
```

**Process:**
1. Saves current theme
2. Iterates through ['default', 'brisbane', 'bologna']
3. Updates website theme for each
4. Clears Rails cache
5. Runs `take-screenshots.js`
6. Restores original theme

**Output:**
```
docs/screenshots/
├── default/
├── brisbane/
└── bologna/
```

### Other Scripts
- `take-screenshots-prod.js` - Production screenshot capture
- `take-admin-screenshots.js` - Admin UI screenshots
- `compress-screenshots.js` - Image compression utility
- `extract-critical-css.js` - Performance optimization
- `check-icons.sh` - Icon validation

---

## 10. Comprehensive Documentation

### Location
**Directory:** `/Users/etewiah/dev/sites-older/property_web_builder/docs/testing/`

### Documentation Files

| File | Purpose | Lines |
|------|---------|-------|
| PLAYWRIGHT_TESTING.md | Quick start guide | ~180 |
| E2E_TESTING_QUICK_START.md | Setup walkthrough | ~350 |
| E2E_TESTING_SETUP.md | Detailed setup instructions | ~450 |
| E2E_TESTING_SUMMARY.md | Overview and best practices | ~400 |
| E2E_TESTING.md | Comprehensive guide | ~400 |
| E2E_USER_STORIES.md | Test scenarios & user stories | ~600 |
| playwright-e2e-overview.md | Directory structure & config | ~350 |
| playwright-patterns.md | Test patterns & examples | ~600 |
| playwright-quick-reference.md | API quick reference | ~350 |
| EXPLORATION_SUMMARY.md | Investigation findings | ~450 |
| INDEX.md | Documentation index | ~500 |
| README.md | Overview & links | ~400 |
| STRUCTURE_VISUAL_MAP.md | Visual structure diagram | ~600 |

**Total:** ~13,000 lines of testing documentation

### Key Documentation Covers
- Setup and installation
- Test environment configuration
- Test data and fixtures
- Writing new tests
- Test patterns and best practices
- Troubleshooting
- CI/CD integration
- Performance testing

---

## 11. Test Environment Setup Workflow

### Quick Start (Typical Developer Workflow)

```bash
# 1. Setup E2E Database (one time)
RAILS_ENV=e2e bin/rails db:create db:migrate
RAILS_ENV=e2e bin/rails playwright:reset

# 2. Start E2E Server (Terminal 1)
RAILS_ENV=e2e bin/rails playwright:server

# 3. Run Tests (Terminal 2)
npx playwright test

# Alternative: Run with UI
npx playwright test --ui

# Alternative: Admin tests with auth bypass
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
npx playwright test tests/e2e/admin
```

### CI/CD Workflow

```bash
# Setup
RAILS_ENV=e2e bin/rails db:create db:migrate
RAILS_ENV=e2e bin/rails playwright:reset

# Start server in background
RAILS_ENV=e2e bin/rails s -p 3001 &

# Run tests
npx playwright test

# Run Lighthouse audits
npx lhci autorun

# Cleanup
pkill -f "rails s"
```

---

## 12. Key Features & Capabilities

### Multi-Tenancy Testing
- Two separate test tenants (A and B)
- Isolated databases per tenant
- Cross-tenant isolation verification tests
- Tenant-aware fixtures and helpers

### Flexible Authentication
- Full auth testing via unit tests
- Admin auth bypass mode for UI testing
- E2E test support endpoints for state management
- Session handling helpers

### Comprehensive Test Data
- Pre-seeded users with different roles
- Sample properties (4 for-sale + 4 for-rent per tenant)
- Property features and amenities
- Contact data and message history
- Image attachments (R2 external or local fallback)

### Test State Management
- Per-test data reset endpoints
- Materialized view refresh for queries
- Seed data consistency verification
- Test isolation between runs

### Performance Monitoring
- Lighthouse CI integration
- Core Web Vitals tracking
- Performance budgets enforcement
- Automated performance reports in PRs

### Browser & Viewport Coverage
- Chromium desktop (1440px)
- Mobile viewport support (375px)
- Firefox/WebKit ready (commented out)
- Headless and headed modes

### Serial Admin Testing
- Admin tests run serially to avoid race conditions
- Separate browser project for admin tests
- Shared state modification handling
- Independent from parallel public tests

### Debugging & Visibility
- HTML test reports
- Screenshots on failure
- Video recordings on retry
- Full traces on first retry
- Console and network logging

---

## 13. Testing Philosophy & Patterns

### Design Principles
1. **Isolation:** E2E tests don't rely on RSpec unit test database
2. **Repeatability:** Can run tests multiple times with consistent results
3. **Speed:** Parallel execution for public tests, serial for admin
4. **Clarity:** Descriptive test names and helper functions
5. **Maintainability:** Centralized fixtures and helper functions

### Test Separation
- **Unit Tests:** Auth flows (RSpec in `spec/`)
- **E2E Tests:** UI functionality (Playwright in `tests/e2e/`)
- **Performance Tests:** Lighthouse (CI workflow)
- **Screenshot Tests:** Visual regression (scripts/)

### Helper-Driven Approach
```javascript
// Good - Using helpers for consistent patterns
await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
await goToAdminPage(page, tenant, ROUTES.ADMIN.DASHBOARD);

// Instead of - Repeating login code in every test
await page.goto('...');
await page.fill(...);
// ... etc
```

### Data-Driven Testing
```javascript
// Centralized test data
const testData = require('../fixtures/test-data');

// Reusable across all tests
const user = testData.ADMIN_USERS.TENANT_A;
const tenant = testData.TENANTS.A;
```

---

## 14. File Manifest

### Critical Configuration Files
```
playwright.config.js                          # Playwright config
config/environments/e2e.rb                    # E2E environment config
lib/tasks/playwright.rake                     # Rake tasks
app/controllers/e2e/test_support_controller.rb # Test endpoints
```

### Test Files
```
tests/e2e/
├── global-setup.js
├── fixtures/helpers.js
├── fixtures/test-data.js
├── public/ (7 spec files)
├── auth/ (3 spec files)
├── admin/ (5 spec files)
├── images/ (1 spec file)
└── search.spec.js
```

### Seed Data
```
db/seeds/e2e_seeds.rb                        # Main E2E seeds
db/yml_seeds/e2e_users.yml                   # Test user credentials
```

### Scripts
```
scripts/take-screenshots.js
scripts/capture_all_themes.rb
scripts/take-screenshots-prod.js
scripts/take-admin-screenshots.js
scripts/compress-screenshots.js
scripts/extract-critical-css.js
scripts/check-icons.sh
```

### Documentation
```
docs/testing/ (13 markdown files, ~13,000 lines)
.github/workflows/lighthouse.yml              # Lighthouse CI workflow
```

---

## 15. Quick Reference: Common Commands

### Setup & Maintenance
```bash
# Initialize E2E environment
RAILS_ENV=e2e bin/rails db:create db:migrate playwright:reset

# Reseed without dropping database
RAILS_ENV=e2e bin/rails playwright:seed
```

### Running Tests
```bash
# All tests
npx playwright test

# Specific file
npx playwright test tests/e2e/public/property-search.spec.js

# Admin tests only
npx playwright test tests/e2e/admin

# With UI
npx playwright test --ui

# Headed mode (see browser)
npx playwright test --headed

# Single worker (no parallelization)
npx playwright test --workers=1
```

### Server Management
```bash
# Normal E2E server
RAILS_ENV=e2e bin/rails playwright:server

# With auth bypass (for admin UI testing)
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```

### Performance Testing
```bash
# Local Lighthouse audit
npx lhci autorun

# CI workflow (automatic)
# Triggered by push to master/develop or PR to master
```

### Screenshots
```bash
# Capture default theme
node scripts/take-screenshots.js

# Specific theme
SCREENSHOT_THEME=brisbane node scripts/take-screenshots.js

# All themes at once
bundle exec rails runner scripts/capture_all_themes.rb
```

---

## 16. Integration Points

### With Rails Framework
- E2E environment configuration (`config/environments/e2e.rb`)
- Rake task integration (`lib/tasks/playwright.rake`)
- Database seeding system (`db/seeds/`, `db/yml_seeds/`)
- Test support endpoints (Rails controller)
- Asset precompilation compatibility

### With GitHub Actions
- Lighthouse CI workflow (`.github/workflows/lighthouse.yml`)
- Automated performance reporting
- PR comment integration
- CI/CD environment setup

### With Stimulus.js
- Admin tests validate Stimulus interactions
- Helper functions work with Stimulus selectors
- Admin auth bypass mode for isolated UI testing

### With Multi-Tenancy
- Subdomain-based tenant routing
- Per-tenant test data
- Tenant-aware database seeding
- Cross-tenant isolation verification

### With Theme System
- Theme-aware test data
- Screenshot capture per theme
- Theme rendering tests
- Dynamic theme switching

---

## 17. Limitations & Notes

### Current Scope
- Only Chromium browser in CI (Firefox/WebKit available for setup)
- Test database is separate from development/production
- Admin tests run serially to avoid conflicts
- Auth tests skip actual authentication (tested via RSpec)

### Authentication Testing
- **By Design:** Authentication flows tested in RSpec (`spec/controllers/`, `spec/requests/`)
- **Bypass Mode:** E2E tests use BYPASS_ADMIN_AUTH for UI focus
- **Health Check:** `/e2e/health` endpoint verifies bypass is active

### Database Considerations
- E2E database: `pwb_e2e`
- Separate from test database: `pwb_test`
- Separate from development database: `pwb_development`
- Migrations must be run manually: `RAILS_ENV=e2e bin/rails db:migrate`

### Performance Budgets
- Performance score: 70% minimum (warning level)
- LCP (Largest Contentful Paint): ≤4.0s max
- CLS (Cumulative Layout Shift): ≤0.25 max
- Some metrics set to 'warn' rather than 'error' for flexibility

---

## 18. Future Expansion Points

### Ready for Extension
- Additional browsers (Firefox, WebKit) - config already supports
- Mobile-specific tests (viewport presets available)
- API testing (can add REST/GraphQL tests)
- Accessibility testing (Playwright supports axe-core)
- Visual regression testing (snapshot infrastructure in place)
- Load testing (separate from E2E but compatible with setup)

### Potential Improvements
- Visual regression snapshots (snapshot testing started in search.spec.js)
- Accessibility audits (using Playwright accessibility features)
- Custom reporters (HTML reporter can be extended)
- Flaky test detection (CI retry mechanism in place)
- Test results aggregation (multiple test runs averaged)

---

## Summary

The PropertyWebBuilder E2E testing infrastructure is:

1. **Comprehensive:** 17 test spec files covering public, admin, auth, and performance
2. **Well-Organized:** Clear separation of concerns with fixtures, helpers, and controllers
3. **Thoroughly Documented:** ~13,000 lines of testing documentation
4. **Production-Ready:** CI/CD integration, performance monitoring, and artifact collection
5. **Developer-Friendly:** Simple setup, helpful error messages, multiple debugging options
6. **Multi-Tenant Aware:** Proper isolation and cross-tenant testing
7. **Performance-Focused:** Lighthouse integration with performance budgets
8. **Maintainable:** Centralized test data and reusable helper functions

All components work together to enable reliable, automated E2E testing with excellent visibility and control for PropertyWebBuilder development and deployment.
