# E2E Testing - Quick Command Reference

## One-Time Setup

```bash
# Create and migrate E2E database
RAILS_ENV=e2e bin/rails db:create db:migrate

# Seed with test data (tenants, users, properties, etc.)
RAILS_ENV=e2e bin/rails playwright:reset
```

---

## Running Tests - Development Workflow

### Terminal 1: Start the E2E Server
```bash
# Normal mode (tests with actual auth)
RAILS_ENV=e2e bin/rails playwright:server

# OR: Admin bypass mode (tests admin UI without login)
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```

**Output shows test credentials:**
```
Tenant A Admin:   admin@tenant-a.test / password123
Tenant A User:    user@tenant-a.test / password123
Tenant B Admin:   admin@tenant-b.test / password123
Tenant B User:    user@tenant-b.test / password123
```

### Terminal 2: Run Playwright Tests

```bash
# Run all tests
npx playwright test

# Run specific test file
npx playwright test tests/e2e/public/property-search.spec.js

# Run specific test (by name)
npx playwright test -g "displays search filters"

# Run just public tests
npx playwright test tests/e2e/public

# Run just admin tests
npx playwright test tests/e2e/admin

# Run with UI (interactive)
npx playwright test --ui

# Run in headed mode (watch browser)
npx playwright test --headed

# Run single-threaded (no parallelization)
npx playwright test --workers=1

# Debug single test
npx playwright test -g "test name" --debug
```

---

## Test Structure Quick Reference

### Test Data Fixtures
```javascript
const { TENANTS, ADMIN_USERS, PROPERTIES, ROUTES } = require('../fixtures/test-data');

// Available tenants
TENANTS.A.baseURL  // 'http://tenant-a.e2e.localhost:3001'
TENANTS.B.baseURL  // 'http://tenant-b.e2e.localhost:3001'

// Admin credentials
ADMIN_USERS.TENANT_A.email      // 'admin@tenant-a.test'
ADMIN_USERS.TENANT_A.password   // 'password123'

// Common routes
ROUTES.HOME      // '/'
ROUTES.BUY       // '/en/buy'
ROUTES.RENT      // '/en/rent'
ROUTES.ADMIN.DASHBOARD  // '/site_admin'
```

### Common Helper Functions
```javascript
const {
  loginAsAdmin,
  goToTenant,
  goToAdminPage,
  expectToBeLoggedIn,
  fillField,
  saveAndWait,
  resetWebsiteSettings,
  isE2eEnvironment
} = require('../fixtures/helpers');

// Example: Login as admin
await loginAsAdmin(page, ADMIN_USERS.TENANT_A);

// Example: Navigate to tenant page
await goToTenant(page, TENANTS.A, ROUTES.BUY);

// Example: Go to admin (with auth bypass)
await goToAdminPage(page, TENANTS.A, ROUTES.ADMIN.DASHBOARD);

// Example: Fill and save form
await fillField(page, 'Company Name', 'New Name');
await saveAndWait(page, 'Save');

// Example: Reset test data between tests
await resetWebsiteSettings(page, TENANTS.A);
```

---

## Resetting Test Data

### During Tests
```javascript
// Reset website settings only
await resetWebsiteSettings(page, tenant);

// Reset all test data (more comprehensive)
await resetAllTestData(page, tenant);

// Check if E2E mode is enabled
const isE2e = await isE2eEnvironment(page, tenant);
```

### Between Test Runs
```bash
# Without dropping database (faster)
RAILS_ENV=e2e bin/rails playwright:seed

# Drop and recreate (complete reset)
RAILS_ENV=e2e bin/rails db:drop db:create db:migrate
RAILS_ENV=e2e bin/rails playwright:reset
```

---

## Performance Testing

### Local Performance Audit
```bash
# Run Lighthouse audit locally
npx lhci autorun

# Audits: / (home), /buy, /rent
# Runs 3 times and averages results
```

### Performance Budgets Checked
- **Performance Score:** 70% minimum
- **LCP (Largest Contentful Paint):** ≤4.0s
- **CLS (Cumulative Layout Shift):** ≤0.25
- **FCP (First Contentful Paint):** ≤2.5s (warning)

### In CI/CD
```bash
# Automatic on: push to master/develop, or PR to master
# Reports appear as PR comments with links
```

---

## Screenshots & Documentation

### Capture Screenshots
```bash
# Default theme
node scripts/take-screenshots.js

# Specific theme
SCREENSHOT_THEME=brisbane node scripts/take-screenshots.js

# All themes at once
bundle exec rails runner scripts/capture_all_themes.rb

# Different base URL
BASE_URL=http://localhost:5000 node scripts/take-screenshots.js
```

**Output:** `docs/screenshots/{theme}/`

---

## Troubleshooting

### Port 3001 Already in Use
```bash
# Kill existing process
lsof -ti:3001 | xargs kill -9

# Or use different port
RAILS_ENV=e2e bin/rails s -p 3002
```

### Database Not Set Up
```bash
# Full reset
RAILS_ENV=e2e bin/rails db:drop db:create db:migrate
RAILS_ENV=e2e bin/rails playwright:reset
```

### Subdomain Resolution Issues
Add to `/etc/hosts` (Mac/Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows):
```
127.0.0.1 tenant-a.e2e.localhost
127.0.0.1 tenant-b.e2e.localhost
```

### Tests Failing with Auth Issues
Verify BYPASS_ADMIN_AUTH is set when using admin endpoints:
```bash
# Check health endpoint
curl http://tenant-a.e2e.localhost:3001/e2e/health

# Should show: { "bypass_auth": true }
```

### Database Locked Errors
Clear any hanging connections:
```bash
RAILS_ENV=e2e bin/rails db:drop
RAILS_ENV=e2e bin/rails db:create db:migrate
RAILS_ENV=e2e bin/rails playwright:reset
```

---

## Test File Structure

### Writing a New Test
```javascript
// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToTenant } = require('../fixtures/helpers');

test.describe('My Feature Tests', () => {
  const tenant = TENANTS.A;

  test('should do something', async ({ page }) => {
    await goToTenant(page, tenant, ROUTES.BUY);
    
    // Assertions
    await expect(page.locator('#search-results')).toBeVisible();
  });

  test('admin can edit settings', async ({ page }) => {
    await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
    
    // Admin actions
    await fillField(page, 'Company Name', 'Updated Name');
    await saveAndWait(page, 'Save');
    
    // Verify
    await expect(page.locator('text=Updated Name')).toBeVisible();
  });
});
```

### Test File Locations
- **Public tests:** `tests/e2e/public/*.spec.js`
- **Admin tests:** `tests/e2e/admin/*.spec.js`
- **Auth tests:** `tests/e2e/auth/*.spec.js`
- **Image tests:** `tests/e2e/images/*.spec.js`

---

## Environment Variables

### Required
```bash
RAILS_ENV=e2e        # Always required for E2E testing
```

### Optional
```bash
BYPASS_ADMIN_AUTH=true      # Enable admin auth bypass (for server_bypass_auth)
DATABASE_URL=...            # Override default e2e database
SCREENSHOT_THEME=brisbane   # For screenshot capture
BASE_URL=http://localhost   # For screenshot base URL
```

---

## Key URLs

### Tenant A
- **Public:** `http://tenant-a.e2e.localhost:3001`
- **Admin:** `http://tenant-a.e2e.localhost:3001/site_admin`
- **Login:** `http://tenant-a.e2e.localhost:3001/users/sign_in`

### Tenant B
- **Public:** `http://tenant-b.e2e.localhost:3001`
- **Admin:** `http://tenant-b.e2e.localhost:3001/site_admin`
- **Login:** `http://tenant-b.e2e.localhost:3001/users/sign_in`

### Test Support Endpoints
```
GET  /e2e/health                      # Health check
POST /e2e/reset_website_settings      # Reset settings
POST /e2e/reset_all                   # Reset all data
```

---

## Common Patterns

### Login and Navigate
```javascript
await loginAsAdmin(page, ADMIN_USERS.TENANT_A);
await goToAdminPage(page, TENANTS.A, ROUTES.ADMIN.DASHBOARD);
```

### Wait for Element and Verify
```javascript
await expect(page.locator('text=Success')).toBeVisible();
await expect(page.locator('#form-error')).not.toBeVisible();
```

### Fill Form and Submit
```javascript
await fillField(page, 'Email', 'test@example.com');
await fillField(page, 'Message', 'Hello world');
await saveAndWait(page, 'Send');
```

### Test Data Reset Between Tests
```javascript
test.beforeEach(async ({ page }) => {
  // Reset state before each test
  await resetWebsiteSettings(page, TENANTS.A);
});
```

### Cross-Tenant Isolation Test
```javascript
test('Tenant A cannot access Tenant B data', async ({ page }) => {
  // Create data on Tenant A
  await goToTenant(page, TENANTS.A, ROUTES.HOME);
  
  // Switch to Tenant B
  await goToTenant(page, TENANTS.B, ROUTES.HOME);
  
  // Verify Tenant A data not visible
  await expect(page.locator('text=Tenant A Property')).not.toBeVisible();
});
```

---

## Performance Optimization Notes

### Asset Precompilation
E2E environment uses precompiled assets like production.

If you modify CSS/JS:
```bash
RAILS_ENV=e2e bin/rails assets:precompile
```

### Caching Disabled
E2E environment has caching disabled for consistent test results.
```ruby
config.cache_store = :null_store
config.action_controller.perform_caching = false
```

### Database Queries
E2E environment logs all queries (debug level) for troubleshooting.
```ruby
config.log_level = :debug
```

---

## Files & Locations

| What | Where |
|------|-------|
| Config | `playwright.config.js` |
| E2E Env Config | `config/environments/e2e.rb` |
| Rake Tasks | `lib/tasks/playwright.rake` |
| Test Support Endpoints | `app/controllers/e2e/test_support_controller.rb` |
| Test Data Fixtures | `tests/e2e/fixtures/test-data.js` |
| Test Helpers | `tests/e2e/fixtures/helpers.js` |
| Seed Data | `db/seeds/e2e_seeds.rb` |
| Test Users YAML | `db/yml_seeds/e2e_users.yml` |
| Routes Config | `config/routes.rb` (e2e namespace) |
| GitHub Workflow | `.github/workflows/lighthouse.yml` |
| Lighthouse Config | `lighthouserc.js` |
| Screenshots | `docs/screenshots/` |
| Documentation | `docs/testing/` |

---

## CI/CD Pipeline

### Automatic Triggers
- Push to `master` or `develop` → Full test suite
- PR to `master` → Tests + Lighthouse audit
- Lighthouse results posted to PR comments

### Manual Trigger (GitHub Actions)
1. Go to Actions tab
2. Select "Lighthouse CI" workflow
3. Click "Run workflow"

### What Gets Tested
- E2E tests on commit
- Lighthouse performance audit
- Asset compilation
- Database migrations

---

## Debugging Tips

### Enable Debug Mode
```bash
# Run single test with debugger
npx playwright test -g "test name" --debug
```

### View Full Trace
```bash
# After test fails, view in trace viewer
npx playwright show-trace trace.zip
```

### Headed Mode for Visual Debugging
```bash
npx playwright test --headed
```

### Increase Timeout
```javascript
test.setTimeout(60000); // 60 seconds for this test
```

### Add Console Output
```javascript
console.log('Current URL:', page.url());
console.log('HTML:', await page.content());
```

### Take Manual Screenshot
```javascript
await page.screenshot({ path: 'screenshot.png' });
```

---

## Best Practices

1. **Use helpers:** Don't repeat login/navigation code
2. **Isolate tests:** Each test should be independent
3. **Reset data:** Use reset endpoints between tests if needed
4. **Use fixtures:** Centralize test data in `test-data.js`
5. **Keep tests fast:** Avoid unnecessary waits
6. **Test one thing:** Each test should verify one behavior
7. **Use meaningful names:** Describe what the test does
8. **Test both tenants:** Verify multi-tenant isolation
9. **Don't test auth:** Use RSpec for authentication
10. **Clean up after:** Reset settings if tests modify them

---

## For New Developers

1. **Setup:** Run commands from "One-Time Setup" section
2. **Explore:** Look at example tests in `tests/e2e/public/`
3. **Run:** Follow "Running Tests - Development Workflow"
4. **Debug:** Use "--headed" mode to watch browser
5. **Ask:** Check `docs/testing/` for detailed docs

**Most Common Workflow:**
```bash
# Terminal 1
RAILS_ENV=e2e bin/rails playwright:server

# Terminal 2
npx playwright test --headed
```
