---
name: e2e-testing
description: Playwright E2E testing and Lighthouse performance auditing. Use when setting up E2E tests, running Playwright tests, performing Lighthouse audits, or debugging E2E test failures.
---

# E2E Testing & Lighthouse Audits

This skill covers Playwright browser testing and Lighthouse performance auditing for PropertyWebBuilder.

## E2E Environment Setup

### Initial Setup (One-time)

```bash
# 1. Install Playwright browsers
npx playwright install

# 2. Reset and seed the E2E database
RAILS_ENV=e2e bin/rails playwright:reset
```

### Starting the E2E Server

The E2E environment runs on port 3001 with two test tenants.

```bash
# Standard server (requires login)
RAILS_ENV=e2e bin/rails playwright:server

# Server with admin auth bypass (for UI testing without login)
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```

**Test Tenants:**
- Tenant A: http://tenant-a.e2e.localhost:3001
- Tenant B: http://tenant-b.e2e.localhost:3001

**Test Users (per tenant):**
- Admin: `admin@tenant-a.test` / `password123`
- Regular: `user@tenant-a.test` / `password123`
- (Same pattern for tenant-b)

### Re-seeding Data

```bash
# Full reset (drop, create, migrate, seed)
RAILS_ENV=e2e bin/rails playwright:reset

# Re-seed only (faster, keeps schema)
RAILS_ENV=e2e bin/rails playwright:seed
```

## Running Playwright Tests

### Run All Tests

```bash
# Run all tests (server must be running)
npx playwright test

# Run with UI mode (interactive)
npx playwright test --ui

# Run with headed browser (see the browser)
npx playwright test --headed
```

### Run Specific Tests

```bash
# Run a specific test file
npx playwright test tests/e2e/public/property-search.spec.js

# Run tests matching a pattern
npx playwright test -g "property search"

# Run only admin tests
npx playwright test --project=chromium-admin

# Run only public tests
npx playwright test --project=chromium
```

### Debug Failing Tests

```bash
# Run with debug mode (step through)
npx playwright test --debug

# Run with trace viewer
npx playwright test --trace on

# Show HTML report after run
npx playwright show-report
```

## Test File Structure

```
tests/e2e/
├── fixtures/
│   ├── test-data.js      # TENANTS, ADMIN_USERS, ROUTES constants
│   └── helpers.js        # loginAsAdmin, goToTenant, resetWebsiteSettings
├── public/               # Public-facing page tests (parallel)
│   ├── property-search.spec.js
│   ├── property-details.spec.js
│   └── contact-form.spec.js
├── admin/                # Admin tests (run serially)
│   ├── editor.spec.js
│   ├── properties-settings.spec.js
│   └── site-settings.spec.js
├── auth/                 # Authentication tests
│   └── sessions.spec.js
└── global-setup.js       # Verifies E2E database
```

## Writing E2E Tests

### Basic Test Pattern

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('./fixtures/test-data');
const { goToTenant, loginAsAdmin } = require('./fixtures/helpers');

test.describe('Feature Name', () => {
  test('should do something', async ({ page }) => {
    await goToTenant(page, TENANTS.A, ROUTES.HOME);
    await expect(page).toHaveTitle(/Expected Title/);
  });
});
```

### Admin Test Pattern

```javascript
const { ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
const { loginAsAdmin, goToAdminPage } = require('../fixtures/helpers');

test.describe('Admin Feature', () => {
  test.beforeEach(async ({ page }) => {
    // With auth bypass server:
    await goToAdminPage(page, ADMIN_USERS.TENANT_A.tenant, ROUTES.ADMIN.DASHBOARD);

    // OR with regular server:
    await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
  });

  test('should manage settings', async ({ page }) => {
    // test code
  });
});
```

### Available Helpers

```javascript
// Navigation
await goToTenant(page, TENANTS.A, '/en/buy');
await goToAdminPage(page, tenant, '/site_admin');

// Authentication
await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
await expectToBeLoggedIn(page);
await expectToBeOnLoginPage(page);

// Forms
await fillField(page, 'Email', 'test@example.com');
await submitFormWithCsrf(page, 'form.contact-form');
await saveAndWait(page, 'Save Changes');

// Test data reset
await resetWebsiteSettings(page, tenant);
await resetAllTestData(page, tenant);

// Environment check
const isE2e = await isE2eEnvironment(page, tenant);
```

## Lighthouse Performance Audits

### Run Lighthouse Locally

```bash
# Run Lighthouse CI (starts server automatically)
npx lhci autorun

# Run against running server
npx lhci collect --url=http://localhost:3000/
npx lhci assert
```

### Lighthouse Configuration

The `lighthouserc.js` file configures:

**URLs Audited:**
- Homepage: http://localhost:3000/
- Buy page: http://localhost:3000/buy
- Rent page: http://localhost:3000/rent

**Performance Budgets:**
| Metric | Threshold | Level |
|--------|-----------|-------|
| Performance Score | ≥70% | error |
| Accessibility Score | ≥90% | error |
| Best Practices | ≥90% | warn |
| SEO Score | ≥90% | error |
| LCP | ≤4.0s | error |
| CLS | ≤0.25 | error |
| FCP | ≤2.5s | warn |
| TBT | ≤500ms | warn |

### View Lighthouse Reports

```bash
# After running lhci autorun, reports are in .lighthouseci/
open .lighthouseci/lhr-*.html

# Or view the uploaded report URL (shown in terminal)
```

## Troubleshooting

### Server Not Running

```
Error: page.goto: net::ERR_CONNECTION_REFUSED
```

**Fix:** Start the E2E server first:
```bash
RAILS_ENV=e2e bin/rails playwright:server
```

### Database Not Initialized

```
Error: E2E database not initialized
```

**Fix:** Reset the database:
```bash
RAILS_ENV=e2e bin/rails playwright:reset
```

### Auth Bypass Not Working

```
Error: Auth bypass not working! Redirected to login.
```

**Fix:** Use the auth bypass server:
```bash
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```

### Tenant Not Found

```
Error: Could not find website for subdomain
```

**Fix:** Ensure you're using the correct tenant URLs:
- `http://tenant-a.e2e.localhost:3001`
- `http://tenant-b.e2e.localhost:3001`

### Stale Test Data

```
Tests failing with unexpected data
```

**Fix:** Reset test data:
```bash
RAILS_ENV=e2e bin/rails playwright:reset
# Or via helper in test:
await resetAllTestData(page, TENANTS.A);
```

## CI/CD Integration

### GitHub Actions Workflow

The `.github/workflows/lighthouse.yml` runs Lighthouse on push/PR:
- Uploads results to temporary public storage
- Posts score summary as PR comment
- Fails build if performance budgets not met

### Running E2E in CI

```yaml
- name: Setup E2E database
  run: RAILS_ENV=e2e bin/rails playwright:reset

- name: Start E2E server
  run: RAILS_ENV=e2e bin/rails playwright:server_bypass_auth &

- name: Run Playwright tests
  run: npx playwright test
```

## Quick Reference

| Task | Command |
|------|---------|
| Setup E2E database | `RAILS_ENV=e2e bin/rails playwright:reset` |
| Start E2E server | `RAILS_ENV=e2e bin/rails playwright:server` |
| Start server (no auth) | `RAILS_ENV=e2e bin/rails playwright:server_bypass_auth` |
| Run all E2E tests | `npx playwright test` |
| Run tests with UI | `npx playwright test --ui` |
| Debug failing test | `npx playwright test --debug` |
| View test report | `npx playwright show-report` |
| Run Lighthouse | `npx lhci autorun` |
| Reseed test data | `RAILS_ENV=e2e bin/rails playwright:seed` |
