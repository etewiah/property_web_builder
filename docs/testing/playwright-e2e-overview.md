# Playwright E2E Test Structure Overview

## Directory Structure

```
tests/e2e/
├── global-setup.js                          # Global setup: verifies e2e database exists
├── fixtures/
│   ├── helpers.js                           # Reusable helper functions
│   └── test-data.js                         # Test data: tenants, users, routes
├── admin/
│   ├── site-settings-integration.spec.js    # Admin settings integration tests
│   ├── properties-settings.spec.js          # Property settings management tests
│   └── editor.spec.js                       # In-context editor tests
├── auth/
│   ├── admin_login.spec.js                  # Multi-tenant admin login tests
│   ├── sessions.spec.js                     # Session management tests
│   └── tenant-isolation.spec.js             # Tenant isolation verification tests
└── public/
    ├── property-browsing.spec.js            # Public property browsing tests
    ├── property-details.spec.js             # Property detail page tests
    ├── property-search.spec.js              # Property search functionality tests
    ├── property_display.spec.js             # Property display/rendering tests
    ├── contact-forms.spec.js                # Contact form tests
    └── theme-rendering.spec.js              # Theme rendering tests
```

## Configuration

### playwright.config.js

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/playwright.config.js`

Key configuration details:

- **Test Directory:** `./tests/e2e`
- **Global Setup:** `./tests/e2e/global-setup.js` (verifies e2e database exists)
- **Base URL:** `http://tenant-a.e2e.localhost:3001`
- **Parallel Execution:** Enabled (`fullyParallel: true`)
- **CI Behavior:** Retries 2 times on CI, single worker
- **Reporters:** HTML report + list output
- **Browser:** Chromium (Firefox/WebKit commented out)
- **Artifacts:**
  - Screenshots on failure
  - Traces on first retry
  - Videos on first retry

### Environment Setup

Before running tests, you must:

1. **Reset the E2E database:**
   ```bash
   RAILS_ENV=e2e bin/rails playwright:reset
   ```
   
2. **Start the Rails server** (choose one):

   **Option A - Normal authentication:**
   ```bash
   RAILS_ENV=e2e bin/rails playwright:server
   ```
   
   **Option B - Authentication bypass (for admin integration tests):**
   ```bash
   RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
   ```
   Or manually:
   ```bash
   BYPASS_ADMIN_AUTH=true RAILS_ENV=e2e bin/rails server -p 3001
   ```

## Test Data Fixtures

### test-data.js

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/tests/e2e/fixtures/test-data.js`

Provides central test data matching seed data in `db/seeds/e2e_seeds.rb`:

#### Tenants Configuration

```javascript
const TENANTS = {
  A: {
    subdomain: 'tenant-a',
    baseURL: 'http://tenant-a.e2e.localhost:3001',
    companyName: 'Tenant A Real Estate',
  },
  B: {
    subdomain: 'tenant-b',
    baseURL: 'http://tenant-b.e2e.localhost:3001',
    companyName: 'Tenant B Real Estate',
  }
};
```

#### Admin User Credentials

```javascript
const ADMIN_USERS = {
  TENANT_A: {
    email: 'admin@tenant-a.test',
    password: 'password123',
    tenant: TENANTS.A,
  },
  TENANT_B: {
    email: 'admin@tenant-b.test',
    password: 'password123',
    tenant: TENANTS.B,
  }
};
```

#### Test Properties

```javascript
const PROPERTIES = {
  SALE: {
    title: 'Test Sale Property',
    price: '250000',
    bedrooms: '3',
    type: 'for-sale',
  },
  RENTAL: {
    title: 'Test Rental Property',
    price: '1500',
    bedrooms: '2',
    type: 'for-rent',
  }
};
```

#### Routes

```javascript
const ROUTES = {
  HOME: '/',
  BUY: '/en/buy',
  RENT: '/en/rent',
  CONTACT: '/contact-us',
  ABOUT: '/about-us',
  LOGIN: '/users/sign_in',
  ADMIN: {
    DASHBOARD: '/site_admin',
    PROPERTIES: '/site_admin/props',
    CONTACTS: '/site_admin/contacts',
    SETTINGS: '/site_admin/properties/settings',
    PAGES: '/site_admin/pages',
    WEBSITE_SETTINGS: '/site_admin/website/settings',
    WEBSITE_SETTINGS_GENERAL: '/site_admin/website/settings?tab=general',
    WEBSITE_SETTINGS_APPEARANCE: '/site_admin/website/settings?tab=appearance',
    WEBSITE_SETTINGS_NAVIGATION: '/site_admin/website/settings?tab=navigation',
    WEBSITE_SETTINGS_NOTIFICATIONS: '/site_admin/website/settings?tab=notifications',
  }
};
```

## Helper Functions

### helpers.js

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/tests/e2e/fixtures/helpers.js`

Common helper functions for tests:

#### Authentication Helpers

- **`loginAsAdmin(page, adminUser)`** - Logs in as an admin user
  - Takes page and adminUser object (from ADMIN_USERS)
  - Navigates to login page, fills form, submits
  - Waits for page load

- **`goToAdminPage(page, tenant, adminPath)`** - Navigates to admin page
  - Works with BYPASS_ADMIN_AUTH=true
  - Verifies auth bypass is working
  - Throws error if redirected to login

#### Navigation Helpers

- **`goToTenant(page, tenant, path = '/')`** - Navigate to tenant URL with networkidle wait
- **`waitForPageLoad(page)`** - Waits for networkidle and domcontentloaded states

#### Form Helpers

- **`fillField(page, fieldIdentifier, value)`** - Fill form field by label, name, or id
- **`getCsrfToken(page)`** - Extract CSRF token from meta tag
- **`submitFormWithCsrf(page, formSelector)`** - Submit form with CSRF protection
- **`saveAndWait(page, buttonText = 'Save')`** - Click save button and wait

#### Assertion Helpers

- **`expectPageToHaveAnyContent(page, alternatives)`** - Assert page has one of multiple content options
- **`expectToBeLoggedIn(page)`** - Assert user is logged in (not on login page)
- **`expectToBeOnLoginPage(page)`** - Assert user is on login page

## Global Setup

### global-setup.js

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/tests/e2e/global-setup.js`

Runs before all tests:

- Verifies E2E database has been initialized with `tenant-a` website
- Uses Rails runner to check existence
- Provides clear error message if setup incomplete
- Directs user to run `RAILS_ENV=e2e bin/rails playwright:reset`

## Existing Admin Tests

### 1. site-settings-integration.spec.js

**Purpose:** Test that admin settings changes are reflected on public site

**Test Groups:**
- **Company Display Name Changes** - Change company name and verify it appears on homepage
- **Theme/Appearance Changes** - Switch themes and verify styling updates
- **Currency and Locale Settings** - Change currency and area units
- **Navigation Settings** - Toggle navigation link visibility
- **External Image Mode Setting** - Toggle and persist image mode setting
- **Page Content Management** - Visibility toggles and slug modification
- **Admin Access Verification** - Verify admin pages are accessible with BYPASS_ADMIN_AUTH

**Key Pattern:**
1. Navigate to admin settings page
2. Verify auth bypass is working
3. Modify a setting
4. Save the settings
5. Navigate to public site
6. Assert the change is visible

### 2. properties-settings.spec.js

**Purpose:** Test property settings management functionality

**Test Groups:**
- **Navigating to Settings** - Access control and page visibility
- **Category Tabs** - Navigation between property types, features, states
- **Managing Property Types** - Add new entries with modal
- **Tenant Isolation** - Settings are tenant-specific
- **Form Validation** - Required field enforcement
- **Empty States** - Helpful messaging
- **Settings UI Elements** - Page structure and navigation

**Key Pattern:**
- Uses standard login flow
- Tests page navigation and form interactions
- Verifies tenant isolation with cross-tenant access attempts

### 3. admin_login.spec.js

**Purpose:** Test multi-tenant admin authentication

**Test Cases:**
- Tenant A admin can log in
- Tenant B admin can log in
- Tenant A admin cannot access Tenant B
- Invalid credentials fail
- Tenant B credentials don't work on Tenant A
- Access to protected admin routes after login
- Logout functionality

**Key Pattern:**
- Tests auth isolation between tenants
- Verifies login page mechanics
- Confirms access controls work correctly

### 4. editor.spec.js

**Purpose:** Test the in-context editor functionality

**Test Groups:**
- **Editor Shell** - Load, display, toggle, resize, exit
- **Editor with Path Parameter** - Load specific pages
- **Theme Settings API** - GET/PATCH theme settings endpoints

**Key Pattern:**
- Tests iframe-based editor
- Tests API endpoints for theme configuration
- Uses page.evaluate for API calls with session cookies

## Authentication Patterns

### Two Authentication Modes

#### 1. Normal Authentication
```bash
RAILS_ENV=e2e bin/rails playwright:server
```

- Tests login flow using `loginAsAdmin()` helper
- Verifies authentication works correctly
- Tests tenant isolation and access control

Example pattern:
```javascript
await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
await page.goto(`${TENANTS.A.baseURL}/site_admin`);
```

#### 2. Authentication Bypass (for Integration Tests)
```bash
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```

- Skips authentication for admin pages
- Used for integration testing (settings -> public site)
- Faster test execution
- Set via `BYPASS_ADMIN_AUTH=true` environment variable

Example pattern:
```javascript
await goToAdminPage(page, tenant, '/site_admin/website/settings?tab=general');
// No login needed - directly access admin pages
```

## Test Execution

### Run All Tests
```bash
npm test  # or yarn test or npx playwright test
```

### Run Specific Test Suite
```bash
npx playwright test tests/e2e/admin/site-settings-integration.spec.js
```

### Run Tests in Debug Mode
```bash
npx playwright test --debug
```

### Run with UI Mode (Interactive)
```bash
npx playwright test --ui
```

### View HTML Report
```bash
npx playwright show-report
```

## Multi-Tenancy Considerations

### Tenant Isolation Features

1. **Subdomain-Based Routing**
   - Tenant A: `tenant-a.e2e.localhost:3001`
   - Tenant B: `tenant-b.e2e.localhost:3001`

2. **Session Isolation**
   - Each tenant has separate session/cookies
   - Logging into Tenant A doesn't grant access to Tenant B

3. **Data Isolation**
   - Settings, properties, users are tenant-specific
   - Cross-tenant access attempts should fail

4. **Test Pattern**
   - Always use tenant-specific baseURL from TENANTS config
   - Verify tenant isolation with cross-tenant navigation tests
   - Check that sensitive operations are scoped to current tenant

## Common Test Patterns

### Pattern 1: Admin Page Modification with Public Verification

```javascript
test('changing setting updates public site', async ({ page }) => {
  // 1. Go to admin page with BYPASS_ADMIN_AUTH=true
  await goToAdminPage(page, tenant, '/site_admin/website/settings');
  
  // 2. Modify a setting
  await page.fill('input#setting_name', 'new value');
  
  // 3. Save
  await saveAndWait(page, 'Save');
  
  // 4. Verify on public site
  await page.goto(`${tenant.baseURL}/`);
  const pageContent = await page.content();
  expect(pageContent).toContain('new value');
});
```

### Pattern 2: Authentication Test

```javascript
test('admin access requires login', async ({ page }) => {
  await page.goto(`${tenant.baseURL}/site_admin`);
  
  const currentURL = page.url();
  expect(currentURL).toContain('/sign_in');
});
```

### Pattern 3: Tenant Isolation Verification

```javascript
test('users cannot access other tenants', async ({ page }) => {
  // Login to Tenant A
  await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
  
  // Try to access Tenant B
  await page.goto(`${TENANTS.B.baseURL}/site_admin`);
  
  // Should be redirected to login
  const currentURL = page.url();
  expect(currentURL).toContain('/sign_in');
});
```

## Troubleshooting

### Database Not Set Up
**Error:** "E2E database is not set up properly!"

**Solution:** Run database reset
```bash
RAILS_ENV=e2e bin/rails playwright:reset
```

### Auth Bypass Not Working
**Error:** "Auth bypass not working! Redirected to login."

**Solution:** Start server with auth bypass enabled
```bash
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```

### Port Already in Use
**Error:** Address already in use - Port 3001

**Solution:** Kill existing process or use different port
```bash
lsof -i :3001
kill -9 <PID>
```

### Hostname Not Resolving
**Error:** Can't resolve `tenant-a.e2e.localhost`

**Solution:** Ensure `/etc/hosts` has entries or use localhost directly:
```
127.0.0.1 tenant-a.e2e.localhost
127.0.0.1 tenant-b.e2e.localhost
```

## File Locations Summary

| File | Purpose |
|------|---------|
| `/playwright.config.js` | Main Playwright configuration |
| `/lib/tasks/playwright.rake` | Rails tasks for setup and server |
| `/tests/e2e/global-setup.js` | Global test setup verification |
| `/tests/e2e/fixtures/test-data.js` | Shared test data (tenants, users, routes) |
| `/tests/e2e/fixtures/helpers.js` | Shared helper functions |
| `/tests/e2e/admin/*.spec.js` | Admin feature tests |
| `/tests/e2e/auth/*.spec.js` | Authentication and isolation tests |
| `/tests/e2e/public/*.spec.js` | Public site functionality tests |
| `/db/seeds/e2e_seeds.rb` | E2E database seed data (referenced, not shown) |

## Key Takeaways

1. **Two-Tier Architecture:** Configuration + Test Suites
   - `playwright.config.js` sets up Playwright
   - Test files use centralized helpers and fixtures

2. **Fixtures Centralization:** 
   - All test data in `test-data.js`
   - All helpers in `helpers.js`
   - Easy to update across all tests

3. **Multi-Tenant Testing Built-in:**
   - Two pre-configured tenants (A and B)
   - Cross-tenant isolation tests included
   - Tenant-aware helpers and route constants

4. **Authentication Flexibility:**
   - Normal login flow for auth tests
   - Bypass mode for integration testing
   - Both modes well supported

5. **Admin Testing Strategy:**
   - Settings changes verified on public site
   - Integration tests confirm feature end-to-end
   - Tenant isolation verified at each layer

