# PropertyWebBuilder Testing Documentation

This folder contains comprehensive documentation for testing in PropertyWebBuilder.

## Documentation Files

### [playwright-e2e-overview.md](./playwright-e2e-overview.md) - MAIN REFERENCE
Comprehensive overview of the entire Playwright E2E test structure.

**Covers:**
- Directory structure of tests (admin, auth, public)
- Configuration (`playwright.config.js`)
- Environment setup and database initialization
- Test data fixtures (tenants, users, routes)
- Helper functions and their usage
- Global setup verification
- Existing admin tests details
- Authentication patterns (normal + bypass)
- Multi-tenancy considerations
- Common test patterns
- Troubleshooting guide

**Best for:** Understanding the complete architecture and getting started

---

### [playwright-quick-reference.md](./playwright-quick-reference.md) - QUICK START
Fast reference guide with quick setup steps and cheat sheets.

**Covers:**
- Quick setup commands
- Test execution commands
- Test data quick reference (URLs, credentials, routes)
- Helper function cheat sheet
- Test structure templates with examples
- Common selectors
- Environment variables
- Existing test suite overview
- Debugging tips
- Common issues and solutions

**Best for:** Quick lookup while writing tests, fast reference during development

---

### [playwright-patterns.md](./playwright-patterns.md) - EXAMPLES & PATTERNS
Detailed code examples and patterns for common testing scenarios.

**Covers:**
- Authentication patterns (3 patterns)
- Multi-tenant isolation patterns (2 patterns)
- Admin integration test patterns (3 patterns)
- Form interaction patterns (3 patterns)
- Navigation and page structure patterns (2 patterns)
- Error handling and edge cases (2 patterns)
- Performance and optimization patterns (2 patterns)

**Best for:** Copy-paste code examples, understanding how to structure tests

---

## Quick Navigation

### I want to...

**Understand the test structure**
→ Read [playwright-e2e-overview.md](./playwright-e2e-overview.md#directory-structure)

**Get started running tests**
→ Read [playwright-quick-reference.md](./playwright-quick-reference.md#getting-started-quick-steps)

**Write a new test**
→ Read [playwright-patterns.md](./playwright-patterns.md) for examples

**Debug a failing test**
→ Read [playwright-quick-reference.md](./playwright-quick-reference.md#debugging-tips)

**Understand tenant isolation**
→ Read [playwright-e2e-overview.md](./playwright-e2e-overview.md#multi-tenancy-considerations)

**Test authentication**
→ Read [playwright-patterns.md](./playwright-patterns.md#authentication-patterns)

**Test admin settings**
→ Read [playwright-patterns.md](./playwright-patterns.md#admin-integration-test-patterns)

**Troubleshoot setup issues**
→ Read [playwright-e2e-overview.md](./playwright-e2e-overview.md#troubleshooting)

**Find a specific helper function**
→ Read [playwright-quick-reference.md](./playwright-quick-reference.md#helper-functions-cheat-sheet)

---

## Quick Start (TL;DR)

```bash
# 1. Set up database
RAILS_ENV=e2e bin/rails playwright:reset

# 2. Start server (choose one)
# For auth tests:
RAILS_ENV=e2e bin/rails playwright:server

# For integration tests (admin -> public):
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth

# 3. Run tests (in another terminal)
npx playwright test                # All tests
npx playwright test --ui           # Interactive mode
npx playwright test tests/e2e/admin/site-settings-integration.spec.js  # Specific file
```

---

## Test Structure Overview

```
PropertyWebBuilder E2E Tests
│
├─ playwright.config.js          ← Main configuration
├─ lib/tasks/playwright.rake     ← Rails tasks
│
└─ tests/e2e/                    ← All test files
   ├─ global-setup.js            ← Runs before tests
   ├─ fixtures/
   │  ├─ test-data.js            ← Tenants, users, routes, properties
   │  └─ helpers.js              ← Reusable helper functions
   ├─ admin/                      ← Admin feature tests (3 files)
   ├─ auth/                       ← Auth & isolation tests (3 files)
   └─ public/                     ← Public feature tests (6 files)
```

---

## Test Data Reference

### Tenants
- **Tenant A:** `http://tenant-a.e2e.localhost:3001`
- **Tenant B:** `http://tenant-b.e2e.localhost:3001`

### Admin Credentials
- **Tenant A:** `admin@tenant-a.test` / `password123`
- **Tenant B:** `admin@tenant-b.test` / `password123`

### Common Routes
```
/                                    Home
/en/buy                             Buy listings
/users/sign_in                      Login page
/site_admin                         Admin dashboard
/site_admin/website/settings        Website settings
/site_admin/pages                   Page management
```

---

## Authentication Modes

### Mode 1: Normal Authentication
```bash
RAILS_ENV=e2e bin/rails playwright:server
```
- Tests login flow
- Verifies access control
- Tests tenant isolation
- Use for: `auth/` test suite

### Mode 2: Auth Bypass (Admin Only)
```bash
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```
- Skips admin login
- Direct access to admin pages
- Faster integration testing
- Use for: `admin/site-settings-integration.spec.js`

---

## Helper Functions Quick Guide

```javascript
// Import
const { loginAsAdmin, goToAdminPage, waitForPageLoad, fillField, saveAndWait } = require('../fixtures/helpers');

// Navigation
await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
await goToAdminPage(page, TENANTS.A, '/site_admin/website/settings');
await goToTenant(page, TENANTS.A, '/en/buy');

// Forms
await fillField(page, 'Field Label', 'value');
await saveAndWait(page, 'Save');
const token = await getCsrfToken(page);

// Assertions
await expectToBeLoggedIn(page);
await expectToBeOnLoginPage(page);
await expectPageToHaveAnyContent(page, ['Option A', 'Option B']);

// Wait
await waitForPageLoad(page);
```

---

## Existing Test Suites

### Admin Tests (3 files)
1. **site-settings-integration.spec.js** - Settings changes apply to public site
2. **properties-settings.spec.js** - Property type/feature/state management
3. **editor.spec.js** - In-context editor UI and API

### Auth Tests (3 files)
1. **admin_login.spec.js** - Login success/failure, tenant isolation
2. **sessions.spec.js** - Session management
3. **tenant-isolation.spec.js** - Cross-tenant data isolation

### Public Tests (6 files)
1. **property-browsing.spec.js** - Browse listings
2. **property-details.spec.js** - Property detail pages
3. **property-search.spec.js** - Search functionality
4. **property_display.spec.js** - Display/rendering
5. **contact-forms.spec.js** - Contact forms
6. **theme-rendering.spec.js** - Theme application

---

## Common Test Patterns

### Simple Navigation Test
```javascript
test('page loads', async ({ page }) => {
  await page.goto('http://tenant-a.e2e.localhost:3001/');
  await waitForPageLoad(page);
  expect(page.url()).toContain('localhost');
});
```

### Admin Test with Login
```javascript
test('admin can login', async ({ page }) => {
  await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
  await page.goto(`${TENANTS.A.baseURL}/site_admin`);
  await expectToBeLoggedIn(page);
});
```

### Admin Integration Test (Auth Bypass)
```javascript
test('admin setting changes appear on public site', async ({ page }) => {
  await goToAdminPage(page, TENANTS.A, '/site_admin/website/settings');
  await fillField(page, 'Company Name', 'New Name');
  await saveAndWait(page);
  
  await page.goto(`${TENANTS.A.baseURL}/`);
  expect(await page.content()).toContain('New Name');
});
```

### Tenant Isolation Test
```javascript
test('tenant A cannot access tenant B', async ({ page }) => {
  await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
  await page.goto(`${TENANTS.B.baseURL}/site_admin`);
  await expectToBeOnLoginPage(page);
});
```

---

## Debugging & Troubleshooting

### View Test Report
```bash
npx playwright show-report
```

### Interactive Test Mode
```bash
npx playwright test --ui
```

### Debug Mode with Inspector
```bash
npx playwright test --debug
```

### Common Issues

| Issue | Solution |
|-------|----------|
| E2E database not set up | `RAILS_ENV=e2e bin/rails playwright:reset` |
| Auth bypass not working | `RAILS_ENV=e2e bin/rails playwright:server_bypass_auth` |
| Port 3001 in use | Kill process: `lsof -i :3001 \| kill -9 <PID>` |
| Can't resolve hostname | Add to `/etc/hosts`: `127.0.0.1 tenant-a.e2e.localhost` |

See [playwright-e2e-overview.md#troubleshooting](./playwright-e2e-overview.md#troubleshooting) for more details.

---

## File Locations

```
/Users/etewiah/dev/sites-older/property_web_builder/

playwright.config.js                           ← Main config
lib/tasks/playwright.rake                      ← Rails tasks
tests/e2e/
├── global-setup.js                            ← Runs before tests
├── fixtures/
│   ├── test-data.js                           ← Tenants, users, routes
│   └── helpers.js                             ← Helper functions
├── admin/
│   ├── site-settings-integration.spec.js
│   ├── properties-settings.spec.js
│   └── editor.spec.js
├── auth/
│   ├── admin_login.spec.js
│   ├── sessions.spec.js
│   └── tenant-isolation.spec.js
└── public/
    ├── property-browsing.spec.js
    ├── property-details.spec.js
    ├── property-search.spec.js
    ├── property_display.spec.js
    ├── contact-forms.spec.js
    └── theme-rendering.spec.js
```

---

## Development Guidelines

### When Writing Tests

1. **Use test data fixtures**
   ```javascript
   const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
   ```

2. **Use helper functions**
   ```javascript
   const { loginAsAdmin, waitForPageLoad } = require('../fixtures/helpers');
   ```

3. **Follow existing patterns**
   - See `playwright-patterns.md` for examples
   - Look at existing tests in same directory

4. **Test both success and failure cases**
   - Auth required (should redirect)
   - Auth provided (should succeed)
   - Invalid input (should fail gracefully)

5. **Verify tenant isolation**
   - Cross-tenant access should fail
   - Data should be tenant-specific

6. **Use meaningful test names**
   ```javascript
   test('users cannot access other tenant admin pages', async ({ page }) => {
     // Clear what is being tested
   });
   ```

### Configuration Notes

- **baseURL:** Set to Tenant A in config, override as needed
- **Parallel execution:** Enabled by default
- **Retries:** 2 on CI, 0 locally
- **Artifacts:** Screenshots, traces, videos on failure
- **Wait states:** networkidle for stability

---

## Additional Resources

### Playwright Documentation
- [Playwright Official Docs](https://playwright.dev)
- [Test API Reference](https://playwright.dev/docs/api/class-test)
- [Locator Guide](https://playwright.dev/docs/locators)

### PropertyWebBuilder Documentation
- [Main README](../../README.md)
- [Architecture Documentation](../architecture/)
- [Multi-Tenancy Documentation](../multi_tenancy/)
- [Seed Data Documentation](../seeding/)

---

## Contributing Tests

When adding new tests:

1. **Choose the right directory**
   - `/admin/` for admin feature tests
   - `/auth/` for authentication/isolation tests
   - `/public/` for public site feature tests

2. **Follow naming convention**
   - Use `.spec.js` extension
   - Use descriptive names: `feature-name.spec.js`

3. **Use fixtures**
   - Import from `../fixtures/test-data.js`
   - Import from `../fixtures/helpers.js`

4. **Add comments for complex tests**
   - Document what is being tested
   - Explain "arrange-act-assert" steps

5. **Test for tenant isolation**
   - Verify cross-tenant access fails appropriately
   - Ensure settings are tenant-specific

---

Last Updated: 2025-12-14

For questions or updates, refer to the comprehensive guides in this folder.
