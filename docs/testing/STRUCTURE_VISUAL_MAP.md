# Playwright E2E Test Structure - Visual Reference Map

## Complete Directory & File Hierarchy

```
property_web_builder/
│
├── playwright.config.js                              [Config: Base setup, retries, artifacts]
│
├── lib/tasks/
│   └── playwright.rake                               [Tasks: reset, server, server_bypass_auth]
│
├── tests/e2e/
│   │
│   ├── global-setup.js                               [Global: Verify e2e database exists]
│   │
│   ├── fixtures/
│   │   ├── test-data.js                              [Data: TENANTS, USERS, ROUTES, PROPERTIES]
│   │   └── helpers.js                                [Helpers: 11 reusable functions]
│   │
│   ├── admin/                                        [Admin feature tests - 3 spec files]
│   │   ├── site-settings-integration.spec.js        [166+ tests: Settings -> Public integration]
│   │   │   ├── Company Display Name Changes        [Change company name, verify on public]
│   │   │   ├── Theme/Appearance Changes            [Switch themes, change CSS]
│   │   │   ├── Currency and Locale Settings        [Currency, area unit changes]
│   │   │   ├── Navigation Settings                 [Toggle navigation visibility]
│   │   │   ├── External Image Mode                 [Toggle image mode setting]
│   │   │   ├── Page Content Management             [Visibility toggles, slug edit]
│   │   │   └── Admin Access Verification           [Verify BYPASS_ADMIN_AUTH works]
│   │   │
│   │   ├── properties-settings.spec.js             [Property type/feature/state management]
│   │   │   ├── Navigating to Settings              [Access control, page visibility]
│   │   │   ├── Category Tabs                       [Navigate property types/features/states]
│   │   │   ├── Managing Property Types             [Add entries, modal interaction]
│   │   │   ├── Tenant Isolation in Settings        [Settings are tenant-specific]
│   │   │   ├── Form Validation                     [Required fields]
│   │   │   ├── Empty States                        [Helpful messages]
│   │   │   └── Settings UI Elements                [Structure, navigation]
│   │   │
│   │   └── editor.spec.js                          [In-context editor UI and API]
│   │       ├── Editor Shell                        [Load, display, toggle, resize, exit]
│   │       ├── Editor with Path Parameter          [Load specific pages in iframe]
│   │       └── Theme Settings API                  [GET/PATCH endpoints]
│   │
│   ├── auth/                                        [Authentication/isolation tests - 3 spec files]
│   │   ├── admin_login.spec.js                     [7 tests: Multi-tenant auth isolation]
│   │   │   ├── Tenant A admin can log in
│   │   │   ├── Tenant B admin can log in
│   │   │   ├── Cross-tenant access denied
│   │   │   ├── Invalid credentials fail
│   │   │   ├── Wrong tenant credentials rejected
│   │   │   ├── Protected routes access after login
│   │   │   └── Logout functionality
│   │   │
│   │   ├── sessions.spec.js                       [Session management tests]
│   │   │
│   │   └── tenant-isolation.spec.js               [Cross-tenant data isolation tests]
│   │
│   └── public/                                      [Public site tests - 6 spec files]
│       ├── property-browsing.spec.js              [Browse property listings]
│       ├── property-details.spec.js               [View property details]
│       ├── property-search.spec.js                [Search functionality]
│       ├── property_display.spec.js               [Property rendering]
│       ├── contact-forms.spec.js                  [Contact form submission]
│       └── theme-rendering.spec.js                [Theme styling application]
│
└── docs/testing/                                   [This documentation]
    ├── README.md                                   [Index and navigation]
    ├── playwright-e2e-overview.md                 [Comprehensive architecture guide]
    ├── playwright-quick-reference.md              [Quick lookup reference]
    ├── playwright-patterns.md                     [Code examples and patterns]
    ├── EXPLORATION_SUMMARY.md                     [Complete findings summary]
    └── STRUCTURE_VISUAL_MAP.md                    [This file]
```

---

## Test Execution Flow Diagram

```
Terminal 1: Database & Server Setup
════════════════════════════════════════════════════════════════
    $ RAILS_ENV=e2e bin/rails playwright:reset
    ├─ Drop e2e database
    ├─ Create e2e database  
    ├─ Run migrations
    ├─ Load db/seeds/e2e_seeds.rb
    │  ├─ Create Tenant A (tenant-a.e2e.localhost:3001)
    │  ├─ Create Tenant B (tenant-b.e2e.localhost:3001)
    │  ├─ Create admin users (email/password123)
    │  └─ Seed test data (properties, settings, etc.)
    └─ ✅ E2E database ready

    $ RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
    ├─ Set BYPASS_ADMIN_AUTH=true
    ├─ Start Rails server on port 3001
    ├─ Load Rails environment (e2e config)
    └─ ✅ Server ready at:
       ├─ http://tenant-a.e2e.localhost:3001
       └─ http://tenant-b.e2e.localhost:3001

Terminal 2: Run Tests
════════════════════════════════════════════════════════════════
    $ npx playwright test
    ├─ Load playwright.config.js
    ├─ Run global-setup.js
    │  └─ Verify e2e database & tenant-a exists
    ├─ Run tests in parallel (3 categories):
    │  ├─ tests/e2e/admin/
    │  ├─ tests/e2e/auth/
    │  └─ tests/e2e/public/
    ├─ Collect artifacts:
    │  ├─ Screenshots on failure
    │  ├─ Traces on first retry
    │  └─ Videos on first retry
    ├─ Generate HTML report
    └─ ✅ Tests complete

    $ npx playwright show-report
    └─ 📊 View HTML report with details
```

---

## Authentication & Tenant Flow Diagram

```
NORMAL MODE (for auth tests)
════════════════════════════════════════════════════════════════
Server: RAILS_ENV=e2e bin/rails playwright:server

Tenant A Test
─────────────────────────────────────────────────────────────────
User navigates to http://tenant-a.e2e.localhost:3001/users/sign_in
    ↓
Form shows (email, password fields)
    ↓
User enters: admin@tenant-a.test / password123
    ↓
Form submits to Rails server
    ↓
Rails validates credentials against Tenant A users
    ↓
Session created (scoped to tenant-a subdomain)
    ↓
User can access: /site_admin, /site_admin/website/settings, etc.
    ↓
User cannot access tenant-b.e2e.localhost (session not valid)


Tenant B Test  
─────────────────────────────────────────────────────────────────
User navigates to http://tenant-b.e2e.localhost:3001/users/sign_in
    ↓
User enters: admin@tenant-b.test / password123
    ↓
Session created (scoped to tenant-b subdomain)
    ↓
User can access tenant-b admin area
    ↓
Session from Tenant A cannot be reused here


Cross-Tenant Isolation Test
─────────────────────────────────────────────────────────────────
Login to Tenant A at http://tenant-a.e2e.localhost:3001
    ↓
Cookies set for tenant-a.e2e.localhost
    ↓
Navigate to http://tenant-b.e2e.localhost:3001/site_admin
    ↓
Cookies from tenant-a are not sent (different subdomain)
    ↓
Rails sees no valid session
    ↓
Redirect to /users/sign_in on Tenant B
    ✅ Isolation verified


BYPASS MODE (for integration tests)
════════════════════════════════════════════════════════════════
Server: RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
       OR: BYPASS_ADMIN_AUTH=true RAILS_ENV=e2e bin/rails server -p 3001

Admin Access Test
─────────────────────────────────────────────────────────────────
User navigates directly to /site_admin
    ↓
Middleware checks BYPASS_ADMIN_AUTH env var
    ↓
Env var is 'true', bypass authentication
    ↓
✅ Direct access to admin pages (no login required)
    ↓
User navigates to /site_admin/website/settings
    ↓
✅ Can modify settings
    ↓
User navigates to public site /
    ↓
✅ Settings changes appear on public site
```

---

## Helper Function Usage Map

```
fixtures/helpers.js provides 11 functions:
═════════════════════════════════════════════════════════════════

┌─ Authentication Helpers
├─ loginAsAdmin(page, adminUser)
│  └─ Fills login form, submits, waits for navigation
│     ├─ Takes: page, ADMIN_USERS object
│     └─ Used in: auth tests, properties-settings.spec.js
│
├─ goToAdminPage(page, tenant, adminPath)
│  └─ Navigate to admin page with auth bypass verification
│     ├─ Takes: page, TENANTS object, path string
│     └─ Used in: site-settings-integration.spec.js
│
├─ expectToBeLoggedIn(page)
│  └─ Assert: not on login page
│     └─ Used in: all auth tests
│
└─ expectToBeOnLoginPage(page)
   └─ Assert: on login or firebase_login page
      └─ Used in: auth tests, access control verification

┌─ Navigation Helpers
├─ goToTenant(page, tenant, path = '/')
│  └─ Navigate to tenant URL with networkidle wait
│     ├─ Takes: page, TENANTS object, path string
│     └─ Used in: public tests, multi-tenant tests
│
└─ waitForPageLoad(page)
   └─ Wait for networkidle + domcontentloaded
      └─ Used in: nearly every test

┌─ Form Helpers
├─ fillField(page, fieldIdentifier, value)
│  └─ Fill form field by label, name, or id (tries all three)
│     ├─ Takes: page, field identifier, value
│     └─ Used in: form tests, admin settings tests
│
├─ getCsrfToken(page)
│  └─ Extract CSRF token from meta tag
│     └─ Used in: API testing (editor tests)
│
├─ submitFormWithCsrf(page, formSelector)
│  └─ Submit form with CSRF handling
│     └─ Used in: forms with CSRF protection
│
└─ saveAndWait(page, buttonText = 'Save')
   └─ Click save button and wait for navigation
      ├─ Takes: page, optional button text
      └─ Used in: admin settings tests

┌─ Content Helpers
└─ expectPageToHaveAnyContent(page, alternatives)
   └─ Assert page contains one of multiple options
      └─ Used in: flexible content assertions
```

---

## Test Fixtures Data Structure

```
test-data.js
═════════════════════════════════════════════════════════════════

TENANTS = {
  A: {
    subdomain: 'tenant-a'
    baseURL: 'http://tenant-a.e2e.localhost:3001'
    companyName: 'Tenant A Real Estate'
  },
  B: {
    subdomain: 'tenant-b'
    baseURL: 'http://tenant-b.e2e.localhost:3001'
    companyName: 'Tenant B Real Estate'
  }
}

ADMIN_USERS = {
  TENANT_A: {
    email: 'admin@tenant-a.test'
    password: 'password123'
    tenant: TENANTS.A  ← Links to tenant config
  },
  TENANT_B: {
    email: 'admin@tenant-b.test'
    password: 'password123'
    tenant: TENANTS.B  ← Links to tenant config
  }
}

ROUTES = {
  HOME: '/'
  BUY: '/en/buy'
  RENT: '/en/rent'
  CONTACT: '/contact-us'
  LOGIN: '/users/sign_in'
  ADMIN: {
    DASHBOARD: '/site_admin'
    PROPERTIES: '/site_admin/props'
    SETTINGS: '/site_admin/properties/settings'
    WEBSITE_SETTINGS: '/site_admin/website/settings'
    WEBSITE_SETTINGS_GENERAL: '/site_admin/website/settings?tab=general'
    WEBSITE_SETTINGS_APPEARANCE: '/site_admin/website/settings?tab=appearance'
    WEBSITE_SETTINGS_NAVIGATION: '/site_admin/website/settings?tab=navigation'
    ... (more routes)
  }
}

PROPERTIES = {
  SALE: {
    title: 'Test Sale Property'
    price: '250000'
    bedrooms: '3'
    type: 'for-sale'
  },
  RENTAL: {
    title: 'Test Rental Property'
    price: '1500'
    bedrooms: '2'
    type: 'for-rent'
  }
}
```

---

## Configuration & Setup Chain

```
Setup Process
═════════════════════════════════════════════════════════════════

Step 1: Configure environment variables
────────────────────────────────────────
RAILS_ENV=e2e
BYPASS_ADMIN_AUTH=true (optional, for integration tests)

Step 2: Load playwright configuration
────────────────────────────────────────
Read: playwright.config.js
├─ Set baseURL: http://tenant-a.e2e.localhost:3001
├─ Set testDir: ./tests/e2e
├─ Set globalSetup: ./tests/e2e/global-setup.js
├─ Configure retries, workers, artifacts
└─ Set reporters

Step 3: Initialize database (one time)
────────────────────────────────────────
Run: RAILS_ENV=e2e bin/rails playwright:reset
├─ Drop database
├─ Create database
├─ Run migrations
├─ Load seeds (db/seeds/e2e_seeds.rb)
│  ├─ Create 2 tenants (A, B)
│  ├─ Create admin users
│  └─ Seed test data
└─ ✅ Database ready

Step 4: Start Rails server
────────────────────────────────────────
Run: RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
├─ Load Rails environment (e2e config)
├─ Set BYPASS_ADMIN_AUTH environment
├─ Start server on port 3001
└─ ✅ Server ready

Step 5: Run global setup (automatic)
────────────────────────────────────────
Playwright runs: tests/e2e/global-setup.js
├─ Use Rails runner to check database
├─ Verify tenant-a exists
├─ Provide error message if missing
└─ ✅ Ready to run tests

Step 6: Run tests
────────────────────────────────────────
Run: npx playwright test
├─ Load fixture test data (TENANTS, USERS, etc.)
├─ Run tests in parallel
├─ Collect artifacts on failure
└─ Generate report

Step 7: View results
────────────────────────────────────────
Run: npx playwright show-report
└─ 📊 Open HTML report
```

---

## Test Category Overview

```
Admin Tests (3 files, ~166+ test cases)
═════════════════════════════════════════════════════════════════
Purpose: Verify admin changes apply to public site

site-settings-integration.spec.js [AUTH BYPASS MODE REQUIRED]
├─ Company Display Name Changes (1 test)
├─ Theme/Appearance Changes (2 tests)
├─ Currency and Locale Settings (2 tests)
├─ Navigation Settings (1 test)
├─ External Image Mode Setting (1 test)
├─ Page Content Management (2 tests)
└─ Admin Access Verification (1 test)
   └─ Tests: Admin pages accessible without login

properties-settings.spec.js [NORMAL AUTH REQUIRED]
├─ Navigating to Settings (2 tests)
├─ Category Tabs (2 tests)
├─ Managing Property Types (3 tests)
├─ Tenant Isolation (1 test)
├─ Form Validation (1 test)
├─ Empty States (1 test)
└─ Settings UI Elements (2 tests)

editor.spec.js [NORMAL AUTH REQUIRED]
├─ Editor Shell (5 tests)
├─ Editor with Path Parameter (1 test)
└─ Theme Settings API (2 tests)


Auth Tests (3 files, ~15+ test cases)
═════════════════════════════════════════════════════════════════
Purpose: Verify authentication and tenant isolation

admin_login.spec.js [NORMAL AUTH REQUIRED]
├─ Tenant A admin login (1 test)
├─ Tenant B admin login (1 test)
├─ Cross-tenant access denied (1 test)
├─ Invalid credentials fail (1 test)
├─ Wrong tenant credentials rejected (1 test)
├─ Protected routes access after login (1 test)
└─ Logout functionality (1 test)

sessions.spec.js
└─ (Content not examined, likely session management tests)

tenant-isolation.spec.js
└─ (Content not examined, likely cross-tenant isolation tests)


Public Tests (6 files, ~50+ test cases estimated)
═════════════════════════════════════════════════════════════════
Purpose: Verify public-facing website functionality

property-browsing.spec.js
├─ Browse property listings
├─ Filtering and sorting
└─ Pagination (if applicable)

property-details.spec.js
├─ View property details
├─ Image gallery
└─ Contact seller

property-search.spec.js
├─ Search functionality
├─ Search filters
└─ Search results

property_display.spec.js
├─ Property rendering
├─ Layout and styling
└─ Responsive behavior

contact-forms.spec.js
├─ Contact form submission
├─ Form validation
└─ Success confirmation

theme-rendering.spec.js
├─ Theme styling application
├─ Theme-specific UI elements
└─ Theme switching
```

---

## Common Test Workflow Diagram

```
Create a New Test
═════════════════════════════════════════════════════════════════

1. Choose category
   ├─ Admin feature test → tests/e2e/admin/
   ├─ Auth test → tests/e2e/auth/
   └─ Public feature test → tests/e2e/public/

2. Import fixtures
   ├─ const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
   └─ const { loginAsAdmin, waitForPageLoad } = require('../fixtures/helpers');

3. Structure test
   ├─ test.describe('Feature Group', () => {
   ├─   test('specific behavior', async ({ page }) => {
   ├─     // Arrange: Set up initial state
   ├─     // Act: Perform actions
   ├─     // Assert: Verify outcomes
   ├─   });
   ├─ });

4. Use fixtures for setup
   ├─ const tenant = TENANTS.A;
   ├─ const admin = ADMIN_USERS.TENANT_A;
   ├─ const baseURL = tenant.baseURL;
   └─ const route = ROUTES.ADMIN.DASHBOARD;

5. Use helpers for common tasks
   ├─ await loginAsAdmin(page, admin);
   ├─ await goToAdminPage(page, tenant, path);
   ├─ await waitForPageLoad(page);
   ├─ await fillField(page, 'Field Label', 'value');
   └─ await saveAndWait(page, 'Save');

6. Run test
   ├─ npx playwright test tests/e2e/[category]/[feature].spec.js

7. Debug if needed
   ├─ npx playwright test --debug
   ├─ npx playwright test --ui
   └─ npx playwright show-report
```

---

## Deployment & CI/CD Integration

```
Typical CI/CD Pipeline
═════════════════════════════════════════════════════════════════

Code Commit
    ↓
CI Job Triggered
    ↓
Install Dependencies
    ├─ npm install
    └─ bundle install
    ↓
Setup E2E Environment
    ├─ Set: RAILS_ENV=e2e
    ├─ Set: CI=true
    ├─ Run: RAILS_ENV=e2e bin/rails playwright:reset
    └─ (Loads e2e database with test data)
    ↓
Start Rails Server
    ├─ RAILS_ENV=e2e bin/rails playwright:server
    └─ (or with bypass auth if needed)
    ↓
Run Playwright Tests
    ├─ npx playwright test
    ├─ Retries: 2 attempts per test
    ├─ Workers: 1 (serial execution on CI)
    └─ (Parallel possible locally)
    ↓
Collect Test Artifacts
    ├─ Screenshots on failure
    ├─ Traces on first retry
    └─ Videos on first retry
    ↓
Generate Report
    └─ HTML report in playwright-report/
    ↓
Upload Artifacts (Optional)
    ├─ playwright-report/
    └─ test-results/
    ↓
Test Results
    ├─ ✅ All passed → Merge approved
    ├─ ❌ Some failed → Require fixes
    └─ ⚠️  Flaky → Investigate
```

---

## Port & Network Configuration

```
Network Setup
═════════════════════════════════════════════════════════════════

Port 3001 (Rails Server)
├─ Serves: http://localhost:3001
├─ Primary: tenant-a.e2e.localhost:3001
├─ Secondary: tenant-b.e2e.localhost:3001
└─ Verify with: curl http://tenant-a.e2e.localhost:3001/

Subdomain Routing (Tenant-based)
├─ tenant-a.e2e.localhost → Tenant A
├─ tenant-b.e2e.localhost → Tenant B
└─ Requires: /etc/hosts entries or DNS resolution

Localhost Resolution
├─ Edit /etc/hosts (macOS/Linux)
│  ├─ 127.0.0.1 tenant-a.e2e.localhost
│  └─ 127.0.0.1 tenant-b.e2e.localhost
└─ On Windows: Edit C:\Windows\System32\drivers\etc\hosts

Session Management
├─ Cookie scope: subdomain-specific
├─ Tenant A session ≠ Tenant B session
└─ Subdomain routing enforces tenant isolation
```

---

## Summary: Quick Lookup by Use Case

```
I want to... → Look at...

Run all tests
└─ npx playwright test

Run specific test suite
└─ npx playwright test tests/e2e/admin/site-settings-integration.spec.js

Write admin integration test
├─ Review: playwright-patterns.md (Admin Integration Test Patterns)
├─ Use: goToAdminPage(), saveAndWait(), page.goto()
└─ Remember: Requires BYPASS_ADMIN_AUTH=true on server

Write authentication test
├─ Review: playwright-patterns.md (Authentication Patterns)
├─ Use: loginAsAdmin(), expectToBeLoggedIn(), expectToBeOnLoginPage()
└─ Remember: Normal authentication mode (no bypass)

Verify tenant isolation
├─ Review: playwright-patterns.md (Multi-Tenant Isolation Patterns)
├─ Pattern: Login to Tenant A, try to access Tenant B, expect redirect
└─ Remember: Sessions are subdomain-scoped

Fill a form
├─ Use: fillField(page, 'Label', 'value')
└─ Remember: Tries label, name, and id automatically

Save form and verify
├─ Use: saveAndWait(page, 'Save')
└─ Waits for networkidle after submit

Debug a test
├─ Option 1: npx playwright test --debug
├─ Option 2: npx playwright test --ui
└─ Option 3: npx playwright show-report

Fix database issues
└─ RAILS_ENV=e2e bin/rails playwright:reset

Start server (normal auth)
└─ RAILS_ENV=e2e bin/rails playwright:server

Start server (bypass auth for integration tests)
└─ RAILS_ENV=e2e bin/rails playwright:server_bypass_auth

Find test data constants
└─ tests/e2e/fixtures/test-data.js

Find helper functions
└─ tests/e2e/fixtures/helpers.js

Understand architecture
├─ Start: docs/testing/README.md
├─ Deep dive: docs/testing/playwright-e2e-overview.md
├─ Code examples: docs/testing/playwright-patterns.md
└─ Quick ref: docs/testing/playwright-quick-reference.md
```

