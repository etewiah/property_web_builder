# Playwright E2E Tests - Quick Reference Guide

## Getting Started (Quick Steps)

### First Time Setup
```bash
# 1. Reset and seed the e2e database
RAILS_ENV=e2e bin/rails playwright:reset

# 2. Start the Rails server (choose based on what you're testing)
# For authentication tests:
RAILS_ENV=e2e bin/rails playwright:server

# For integration tests (admin changes -> public site):
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```

### Run Tests
```bash
# All tests
npx playwright test

# Specific test file
npx playwright test tests/e2e/admin/site-settings-integration.spec.js

# Interactive mode
npx playwright test --ui

# Debug mode
npx playwright test --debug

# Show report
npx playwright show-report
```

## Test Data Quick Reference

### Import in Tests
```javascript
const { TENANTS, ADMIN_USERS, ROUTES, PROPERTIES } = require('../fixtures/test-data');
const { loginAsAdmin, goToAdminPage, waitForPageLoad, fillField } = require('../fixtures/helpers');
```

### Tenant URLs
```javascript
// Tenant A (default)
http://tenant-a.e2e.localhost:3001

// Tenant B
http://tenant-b.e2e.localhost:3001
```

### Admin Credentials
```javascript
// Tenant A
Email: admin@tenant-a.test
Password: password123

// Tenant B
Email: admin@tenant-b.test
Password: password123
```

### Common Routes
```javascript
/                                     // Home
/en/buy                              // Buy listings
/en/rent                             // Rent listings
/users/sign_in                       // Login page
/site_admin                          // Admin dashboard
/site_admin/website/settings         // Website settings
/site_admin/website/settings?tab=general
/site_admin/website/settings?tab=appearance
/site_admin/website/settings?tab=navigation
/site_admin/pages                    // Page management
/site_admin/props                    // Property listings
```

## Helper Functions Cheat Sheet

### Navigation
```javascript
// Log in as admin
await loginAsAdmin(page, ADMIN_USERS.TENANT_A);

// Go to admin page (auth bypass mode)
await goToAdminPage(page, TENANTS.A, '/site_admin/website/settings');

// Go to any tenant page
await goToTenant(page, TENANTS.A, '/en/buy');

// Wait for page load
await waitForPageLoad(page);
```

### Form Interaction
```javascript
// Fill a field (by label, name, or id)
await fillField(page, 'Company Name', 'My Company');

// Save form
await saveAndWait(page, 'Save');

// Get CSRF token
const token = await getCsrfToken(page);
```

### Assertions
```javascript
// Check if logged in
await expectToBeLoggedIn(page);

// Check if on login page
await expectToBeOnLoginPage(page);

// Check page content
await expectPageToHaveAnyContent(page, ['Option A', 'Option B']);
```

## Test Structure Template

### Simple Navigation Test
```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { waitForPageLoad } = require('../fixtures/helpers');

test.describe('My Feature', () => {
  test('should do something', async ({ page }) => {
    // Arrange
    const tenant = TENANTS.A;
    
    // Act
    await page.goto(`${tenant.baseURL}${ROUTES.HOME}`);
    await waitForPageLoad(page);
    
    // Assert
    const content = await page.content();
    expect(content).toContain('Expected Text');
  });
});
```

### Admin Test (with Login)
```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
const { loginAsAdmin, waitForPageLoad } = require('../fixtures/helpers');

test.describe('Admin Feature', () => {
  test('should work after login', async ({ page }) => {
    // Arrange
    const admin = ADMIN_USERS.TENANT_A;
    
    // Act
    await loginAsAdmin(page, admin);
    await page.goto(`${admin.tenant.baseURL}${ROUTES.ADMIN.DASHBOARD}`);
    await waitForPageLoad(page);
    
    // Assert
    const url = page.url();
    expect(url).toContain('/site_admin');
  });
});
```

### Admin Test (with Bypass Auth)
```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToAdminPage, waitForPageLoad } = require('../fixtures/helpers');

test.describe('Admin Integration', () => {
  test('should update public site', async ({ page }) => {
    // Note: Requires BYPASS_ADMIN_AUTH=true on server
    
    // Arrange
    const tenant = TENANTS.A;
    
    // Act - Modify admin setting
    await goToAdminPage(page, tenant, ROUTES.ADMIN.WEBSITE_SETTINGS_GENERAL);
    await page.fill('input#company_name', 'New Name');
    const saveBtn = page.locator('button:has-text("Save")');
    await saveBtn.click();
    await waitForPageLoad(page);
    
    // Act - Verify on public site
    await page.goto(`${tenant.baseURL}${ROUTES.HOME}`);
    await waitForPageLoad(page);
    
    // Assert
    const content = await page.content();
    expect(content).toContain('New Name');
  });
});
```

### Multi-Tenant Isolation Test
```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS } = require('../fixtures/test-data');
const { loginAsAdmin, waitForPageLoad } = require('../fixtures/helpers');

test.describe('Tenant Isolation', () => {
  test('tenant A cannot access tenant B', async ({ page }) => {
    // Arrange & Act
    // Log into Tenant A
    await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
    
    // Try to access Tenant B admin
    await page.goto(`${TENANTS.B.baseURL}/site_admin`);
    await waitForPageLoad(page);
    
    // Assert - should be redirected to login
    const url = page.url();
    expect(url).toContain('/users/sign_in');
  });
});
```

## Common Selectors

### Form Elements
```javascript
// By label
page.locator('label:has-text("Field Name")')

// By name attribute
page.locator('input[name="field_name"]')

// By id
page.locator('#field_id')

// Input with specific type
page.locator('input[type="submit"]')
page.locator('button[type="submit"]')

// Containing text
page.locator('button:has-text("Save")')
page.locator('a:has-text("Edit")')
```

### Admin Elements
```javascript
// Sidebar/Navigation
page.locator('nav, aside, .sidebar')

// Modals
page.locator('[role="dialog"]')
page.locator('.modal')

// Buttons
page.locator('button:has-text("Add New Entry")')
page.locator('input[type="submit"]')

// Messages
page.locator('.alert, .flash, .error, [role="alert"]')
```

## Environment Variables

### Server Configuration
```bash
RAILS_ENV=e2e          # Use e2e database and config
BYPASS_ADMIN_AUTH=true # Skip admin authentication
```

### Playwright Configuration
```bash
CI=true              # Run in CI mode (affects retries, workers)
DEBUG=pw:api         # Enable debug logging
```

## Existing Test Suites

### Admin Tests
- `tests/e2e/admin/site-settings-integration.spec.js`
  - Modifying settings and verifying they appear on public site
  - Company name, theme, currency, area unit, navigation, external images
  - Page content management

- `tests/e2e/admin/properties-settings.spec.js`
  - Property type, feature, state management
  - Settings navigation and tabs
  - Tenant isolation
  - Form validation

- `tests/e2e/admin/editor.spec.js`
  - In-context editor UI (toggle, resize, exit)
  - Iframe loading with edit_mode parameter
  - Theme settings API (GET/PATCH)

### Auth Tests
- `tests/e2e/auth/admin_login.spec.js`
  - Login success/failure scenarios
  - Tenant isolation (can't use other tenant's credentials)
  - Protected route access

- `tests/e2e/auth/sessions.spec.js`
  - Session management (likely)

- `tests/e2e/auth/tenant-isolation.spec.js`
  - Cross-tenant data isolation verification (likely)

### Public Tests
- `tests/e2e/public/property-browsing.spec.js`
- `tests/e2e/public/property-details.spec.js`
- `tests/e2e/public/property-search.spec.js`
- `tests/e2e/public/property_display.spec.js`
- `tests/e2e/public/contact-forms.spec.js`
- `tests/e2e/public/theme-rendering.spec.js`

## Debugging Tips

### Check What Went Wrong
```bash
# View HTML report
npx playwright show-report

# Run with debug UI
npx playwright test --debug

# Run with interactive mode
npx playwright test --ui

# Enable tracing (already on-first-retry in config)
# Screenshots on failure (already in config)
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "E2E database not set up" | Database not initialized | `RAILS_ENV=e2e bin/rails playwright:reset` |
| "Auth bypass not working" | Server not started with auth bypass | `RAILS_ENV=e2e bin/rails playwright:server_bypass_auth` |
| "Can't find tenant-a.e2e.localhost" | Hostname resolution | Add to `/etc/hosts` or use localhost |
| "Port 3001 already in use" | Another process on port | Kill process or use different port |
| "Selector not found" | Element not rendered yet | Add `waitForSelector()` or use proper wait states |

## Performance Notes

### Default Configuration
- **Parallel Tests:** Yes (multiple test files simultaneously)
- **Timeouts:** 30 seconds per action
- **Wait States:** networkidle + domcontentloaded
- **Artifacts:** Screenshots, traces, videos on failure

### Optimization Tips
```javascript
// Don't wait longer than needed
await page.goto(url);  // Default 30s timeout
await page.goto(url, { timeout: 10000 });  // Shorter timeout

// Use more specific waits
await page.waitForSelector('.specific-element', { timeout: 5000 });

// Navigate without waiting for full load
await page.goto(url, { waitUntil: 'domcontentloaded' });

// Check multiple things in one assertion
const content = await page.content();
expect(content).toContain('A');
expect(content).toContain('B');
```

## File Locations Quick Map

```
playwright.config.js          ← Main config
lib/tasks/playwright.rake     ← Rails tasks
tests/e2e/
├── global-setup.js           ← Runs before all tests
├── fixtures/
│   ├── test-data.js          ← Import tenants, users, routes
│   └── helpers.js            ← Import helper functions
├── admin/                     ← Admin feature tests
├── auth/                      ← Auth and isolation tests
└── public/                    ← Public feature tests
```

