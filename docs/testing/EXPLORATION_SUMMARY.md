# Playwright E2E Test Structure - Complete Exploration Summary

**Date:** 2025-12-14  
**Codebase Location:** `/Users/etewiah/dev/sites-older/property_web_builder/`

---

## Executive Summary

PropertyWebBuilder has a comprehensive Playwright E2E test structure with:
- **12 test spec files** organized in 3 categories (admin, auth, public)
- **Centralized fixtures** for test data and reusable helpers
- **Multi-tenant architecture** with pre-configured test tenants
- **Two authentication modes** (normal login + admin bypass for integration tests)
- **Rails integration** with dedicated tasks for setup and server management

The test structure is well-organized, maintainable, and designed to support both authentication testing and integration testing across a multi-tenant system.

---

## Directory Structure

```
tests/e2e/                                    (Root test directory)
├── global-setup.js                          (Verifies E2E database exists)
├── fixtures/
│   ├── helpers.js                           (11 reusable helper functions)
│   └── test-data.js                         (Tenants, users, routes, properties)
├── admin/                                   (Admin feature tests - 3 files)
│   ├── site-settings-integration.spec.js   (Settings changes -> public site)
│   ├── properties-settings.spec.js         (Property type/feature/state management)
│   └── editor.spec.js                      (In-context editor UI & API)
├── auth/                                    (Authentication tests - 3 files)
│   ├── admin_login.spec.js                 (Login, tenant isolation, access control)
│   ├── sessions.spec.js                    (Session management)
│   └── tenant-isolation.spec.js            (Cross-tenant data isolation)
└── public/                                  (Public site tests - 6 files)
    ├── property-browsing.spec.js           (Browse property listings)
    ├── property-details.spec.js            (View property details)
    ├── property-search.spec.js             (Search functionality)
    ├── property_display.spec.js            (Property rendering)
    ├── contact-forms.spec.js               (Contact form submission)
    └── theme-rendering.spec.js             (Theme styling application)
```

---

## Configuration Files

### playwright.config.js
**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/playwright.config.js`

**Key Settings:**
- Test directory: `./tests/e2e`
- Global setup: `./tests/e2e/global-setup.js`
- Base URL: `http://tenant-a.e2e.localhost:3001`
- Parallel execution: Enabled
- Browser: Chromium
- CI retries: 2 attempts
- Artifacts: Screenshots on failure, traces/videos on first retry
- Reporters: HTML report + console list

### lib/tasks/playwright.rake
**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/lib/tasks/playwright.rake`

**Provided Tasks:**
1. `playwright:reset` - Drop, recreate, migrate database; load E2E seeds
2. `playwright:server` - Start Rails server on port 3001 (normal auth)
3. `playwright:server_bypass_auth` - Start server with BYPASS_ADMIN_AUTH=true
4. `playwright:seed` - Load seeds without resetting database

---

## Fixtures & Test Data

### test-data.js
Provides centralized, importable constants:

**TENANTS Configuration:**
```
Tenant A: tenant-a.e2e.localhost:3001
Tenant B: tenant-b.e2e.localhost:3001
```

**ADMIN_USERS Credentials:**
```
Tenant A: admin@tenant-a.test / password123
Tenant B: admin@tenant-b.test / password123
```

**ROUTES Constants:**
```
HOME, BUY, RENT, CONTACT, ABOUT, LOGIN
ADMIN: DASHBOARD, PROPERTIES, CONTACTS, SETTINGS, PAGES, WEBSITE_SETTINGS
```

**PROPERTIES Sample Data:**
```
SALE: $250,000 3-bed property
RENTAL: $1,500/mo 2-bed rental
```

### helpers.js
Provides 11 reusable helper functions:

**Authentication Helpers:**
- `loginAsAdmin()` - Performs login flow
- `goToAdminPage()` - Navigate to admin with auth bypass verification
- `expectToBeLoggedIn()` - Assert not on login page
- `expectToBeOnLoginPage()` - Assert on login page

**Navigation Helpers:**
- `goToTenant()` - Navigate to tenant URL with networkidle wait
- `waitForPageLoad()` - Wait for networkidle + domcontentloaded

**Form Helpers:**
- `fillField()` - Fill form by label/name/id (tries all three)
- `getCsrfToken()` - Extract CSRF token from meta tag
- `submitFormWithCsrf()` - Submit form with CSRF handling
- `saveAndWait()` - Click save button and wait

**Assertion Helpers:**
- `expectPageToHaveAnyContent()` - Assert page has one of multiple options

---

## Global Setup

### global-setup.js
Runs before all tests:
1. Verifies E2E database is initialized
2. Checks that `tenant-a` website exists
3. Uses Rails runner to check database state
4. Provides clear error message with setup instructions if verification fails

---

## Existing Test Suites

### Admin Tests (3 files)

#### 1. site-settings-integration.spec.js (166 tests grouped in sections)
**Purpose:** Verify that admin setting changes appear on public site

**Test Groups:**
- Company Display Name Changes
- Theme/Appearance Changes (theme switching, custom CSS)
- Currency and Locale Settings
- Navigation Settings
- External Image Mode Setting
- Page Content Management (visibility toggles, slug modification)
- Admin Access Verification

**Authentication Mode:** BYPASS_ADMIN_AUTH=true (requires special server start)

#### 2. properties-settings.spec.js
**Purpose:** Test property settings management UI and functionality

**Test Groups:**
- Navigating to Settings (access control, page visibility)
- Category Tabs (navigation between property types/features/states)
- Managing Property Types (add button, modal, translation input)
- Tenant Isolation (settings are tenant-specific)
- Form Validation (required fields)
- Empty States (helpful messaging)
- Settings UI Elements (page structure, navigation)

**Authentication Mode:** Normal login required

#### 3. editor.spec.js
**Purpose:** Test in-context editor shell and theme settings API

**Test Groups:**
- Editor Shell (load page, display panel, toggle, resize, exit)
- Editor with Path Parameter (load specific pages in iframe)
- Theme Settings API (GET/PATCH endpoints with session cookies)

**Key Features:**
- Tests iframe-based editor at `/edit`
- Tests API endpoints at `/editor/theme_settings`
- Uses page.evaluate for API requests with session cookies

### Auth Tests (3 files)

#### 1. admin_login.spec.js
**Test Cases:**
- Tenant A admin can log in successfully
- Tenant B admin can log in successfully
- Tenant A admin cannot access Tenant B with same credentials
- Invalid credentials fail to log in
- Tenant B credentials don't work on Tenant A
- Admin can access protected admin routes after login
- Logout works correctly

**Focus:** Multi-tenant authentication isolation

#### 2. sessions.spec.js
**Purpose:** Session management testing (tests exist but content not examined)

#### 3. tenant-isolation.spec.js
**Purpose:** Cross-tenant data isolation verification (tests exist but content not examined)

### Public Tests (6 files)
Files exist but not examined in detail:
- property-browsing.spec.js
- property-details.spec.js
- property-search.spec.js
- property_display.spec.js
- contact-forms.spec.js
- theme-rendering.spec.js

---

## Authentication Patterns

### Two Modes of Operation

#### Mode 1: Normal Authentication
```bash
RAILS_ENV=e2e bin/rails playwright:server
```
- Tests actual login flow
- Verifies authentication works correctly
- Tests access control and tenant isolation
- **Use for:** `auth/` test suite, `properties-settings.spec.js`

#### Mode 2: Authentication Bypass
```bash
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
# OR
BYPASS_ADMIN_AUTH=true RAILS_ENV=e2e bin/rails server -p 3001
```
- Bypasses admin authentication
- Direct access to admin pages without login
- Faster integration test execution
- **Use for:** `site-settings-integration.spec.js` and similar integration tests

### Key Pattern: Admin Integration Testing
The `site-settings-integration.spec.js` demonstrates the pattern:
1. Navigate to admin page (no login needed with auth bypass)
2. Modify a setting (company name, theme, currency, etc.)
3. Save the settings
4. Navigate to public site
5. Verify the change is visible on the public site

This pattern verifies the end-to-end integration of admin settings with public display.

---

## Multi-Tenancy Support

### Built-in Tenant Infrastructure

**Two Pre-configured Test Tenants:**
- Tenant A: subdomain `tenant-a`, baseURL `http://tenant-a.e2e.localhost:3001`
- Tenant B: subdomain `tenant-b`, baseURL `http://tenant-b.e2e.localhost:3001`

**Session Isolation:**
- Each tenant has separate session/cookies
- Logging into Tenant A doesn't grant access to Tenant B
- Sessions are scoped by subdomain

**Data Isolation:**
- Settings, properties, and users are tenant-specific
- Cross-tenant queries should fail at the application level

### Test Patterns for Multi-Tenancy

1. **Cross-Tenant Access Test**
   - Login to Tenant A
   - Try to access Tenant B admin area
   - Verify redirect to login

2. **Settings Isolation Test**
   - Change setting in Tenant A
   - Verify Tenant B is unaffected

3. **Separate Credentials Test**
   - Tenant B credentials don't work on Tenant A
   - Each tenant has separate user database

---

## Test Execution Commands

### Setup
```bash
# First time only - reset database and load seeds
RAILS_ENV=e2e bin/rails playwright:reset

# Optional - load more seed data without reset
RAILS_ENV=e2e bin/rails playwright:seed
```

### Run Server (Choose One)
```bash
# Option 1: Normal auth (for auth tests)
RAILS_ENV=e2e bin/rails playwright:server

# Option 2: Auth bypass (for integration tests)
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```

### Run Tests (In Another Terminal)
```bash
# All tests
npx playwright test

# Specific test file
npx playwright test tests/e2e/admin/site-settings-integration.spec.js

# Specific test
npx playwright test -g "company name"

# Interactive UI mode
npx playwright test --ui

# Debug mode with inspector
npx playwright test --debug

# Single browser (serial execution)
npx playwright test --workers=1

# Headed mode (see browser)
npx playwright test --headed
```

### View Results
```bash
# HTML report
npx playwright show-report

# Artifacts stored in: playwright-report/
# - Screenshots on failure
# - Traces on first retry  
# - Videos on first retry
```

---

## Common Test Patterns

### Pattern 1: Basic Navigation Test
```javascript
test('page loads', async ({ page }) => {
  await page.goto('http://tenant-a.e2e.localhost:3001/');
  await waitForPageLoad(page);
  expect(page.url()).toContain('localhost');
});
```

### Pattern 2: Admin Test with Normal Auth
```javascript
test('admin can access settings', async ({ page }) => {
  const admin = ADMIN_USERS.TENANT_A;
  await loginAsAdmin(page, admin);
  await page.goto(`${admin.tenant.baseURL}/site_admin/website/settings`);
  await expectToBeLoggedIn(page);
});
```

### Pattern 3: Admin Integration Test (Bypass Auth)
```javascript
test('changing company name updates public site', async ({ page }) => {
  // Note: Requires BYPASS_ADMIN_AUTH=true
  const tenant = TENANTS.A;
  const newName = `Company ${Date.now()}`;
  
  // Admin: Change setting
  await goToAdminPage(page, tenant, '/site_admin/website/settings?tab=general');
  const input = page.locator('input#company_display_name');
  await input.fill(newName);
  await saveAndWait(page);
  
  // Public: Verify change
  await page.goto(`${tenant.baseURL}/`);
  const content = await page.content();
  expect(content).toContain(newName);
});
```

### Pattern 4: Tenant Isolation Verification
```javascript
test('tenant A cannot access tenant B', async ({ page }) => {
  const adminA = ADMIN_USERS.TENANT_A;
  const tenantB = TENANTS.B;
  
  // Login to Tenant A
  await loginAsAdmin(page, adminA);
  
  // Try to access Tenant B
  await page.goto(`${tenantB.baseURL}/site_admin`);
  
  // Should be redirected to login
  await expectToBeOnLoginPage(page);
});
```

---

## Key Implementation Details

### Selectors Used
```javascript
// Login form
input[name="user[email]"], #user_email
input[name="user[password]"], #user_password
input[type="submit"], button[type="submit"]

// Admin elements
input[name="website[company_display_name]"]
select[name="website[theme_name]"]
textarea[name="website[raw_css]"]
button:has-text("Save")

// Navigation
a:has-text("Buy"), a[href*="/buy"]
nav, aside, .sidebar

// Modals
[role="dialog"], .modal
input[name*="translations"][name*="en"]
```

### Wait Strategies
```javascript
// Full page load
await page.waitForLoadState('networkidle');
await page.waitForLoadState('domcontentloaded');

// Specific element
await page.waitForSelector('.element', { timeout: 5000 });

// Helper that combines both
await waitForPageLoad(page);
```

### CSRF Token Handling
```javascript
// Extract from meta tag
const token = await getCsrfToken(page);

// Use in fetch request
headers: { 'X-CSRF-Token': token }
```

---

## Database & Seed Data

### E2E Database Setup
- Separate from development database (uses e2e environment)
- Created from `db/seeds/e2e_seeds.rb`
- Contains two pre-configured tenants with test users
- Reset with `RAILS_ENV=e2e bin/rails playwright:reset`

### Seed Data Includes
- Two tenants (Tenant A, Tenant B)
- Admin user for each tenant
- Sample properties (if configured)
- Test data for property types, features, states

---

## Configuration & Environment

### playwright.config.js Settings
- **testDir:** `./tests/e2e`
- **fullyParallel:** true (tests run in parallel)
- **forbidOnly:** true on CI (prevents `test.only` in code)
- **retries:** 2 on CI, 0 locally
- **workers:** 1 on CI (serial), multiple locally (parallel)
- **baseURL:** `http://tenant-a.e2e.localhost:3001`
- **timeout:** 30 seconds per action (default)

### Environment Variables
```bash
RAILS_ENV=e2e              # Use E2E database and config
BYPASS_ADMIN_AUTH=true     # Skip admin authentication
CI=true                    # CI mode (affects retries, workers)
```

### Prerequisites for Running Tests
- Node.js with Playwright installed
- Ruby/Rails environment set up
- Port 3001 available
- Hostname resolution for `tenant-a.e2e.localhost` and `tenant-b.e2e.localhost`

---

## File Locations Quick Reference

| File | Purpose |
|------|---------|
| `playwright.config.js` | Main Playwright configuration |
| `lib/tasks/playwright.rake` | Rails tasks (reset, server, seed) |
| `tests/e2e/global-setup.js` | Pre-test database verification |
| `tests/e2e/fixtures/test-data.js` | Centralized test data |
| `tests/e2e/fixtures/helpers.js` | Reusable helper functions |
| `tests/e2e/admin/*.spec.js` | Admin feature tests (3 files) |
| `tests/e2e/auth/*.spec.js` | Authentication tests (3 files) |
| `tests/e2e/public/*.spec.js` | Public feature tests (6 files) |
| `db/seeds/e2e_seeds.rb` | Database seed data (referenced) |
| `playwright-report/` | Test artifacts (screenshots, traces, videos) |

---

## Strengths of Current Setup

1. **Well-Organized Structure**
   - Clear separation between admin, auth, and public tests
   - Centralized fixtures and helpers reduce duplication

2. **Multi-Tenancy Built-in**
   - Two pre-configured test tenants
   - Demonstrates tenant isolation testing
   - Tests cross-tenant access control

3. **Flexible Authentication**
   - Normal login mode for auth testing
   - Bypass mode for integration testing
   - Both modes well-supported by helpers

4. **Integration Test Pattern**
   - Admin settings -> public site verification
   - End-to-end feature validation
   - Matches real user workflows

5. **Maintainability**
   - Single source of truth for test data
   - Reusable helpers reduce code duplication
   - Clear patterns for common scenarios

6. **Rails Integration**
   - Rake tasks for setup and server management
   - Proper E2E environment configuration
   - Database management built into tasks

---

## Areas for Potential Enhancement

1. **Test Data Generation**
   - Current approach uses static fixtures
   - Could benefit from factory-based data generation for more complex scenarios

2. **Page Object Model**
   - Current approach uses inline locators
   - Could benefit from POM pattern for complex pages

3. **API Testing**
   - Limited API testing (only theme settings in editor test)
   - Could expand to test more API endpoints

4. **Performance Testing**
   - Current setup is functional testing only
   - Could add performance metrics collection

5. **Visual Testing**
   - No visual regression tests configured
   - Could benefit from screenshot comparison testing

6. **Test Documentation Coverage**
   - Public test files not examined in detail
   - Could benefit from documenting all test suites

---

## Documentation Created

This exploration has produced comprehensive documentation:

1. **README.md** - Index and navigation guide
2. **playwright-e2e-overview.md** - Complete architectural overview (14KB)
3. **playwright-quick-reference.md** - Fast reference and cheat sheets (10KB)
4. **playwright-patterns.md** - Detailed code examples and patterns (20KB)
5. **EXPLORATION_SUMMARY.md** - This document

All files located in: `/Users/etewiah/dev/sites-older/property_web_builder/docs/testing/`

---

## Conclusion

PropertyWebBuilder has a mature, well-structured Playwright E2E test framework that effectively:

- Tests multi-tenant isolation and access control
- Verifies admin feature integration with public display
- Supports both authentication testing and integration testing modes
- Provides clear patterns and helpers for writing new tests
- Maintains centralized test data and configuration

The framework is production-ready and serves as a solid foundation for:
- Adding new feature tests
- Regression testing
- CI/CD pipeline integration
- Quality assurance automation

---

**Exploration Completed:** 2025-12-14
**Next Steps:** Review documentation files and use as reference for writing new tests
