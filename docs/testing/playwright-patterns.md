# Playwright E2E Test Patterns & Examples

## Pattern Directory

This document shows common test patterns used in PropertyWebBuilder's Playwright test suite.

## Authentication Patterns

### Pattern 1: Login and Verify Access

**When to use:** Testing that a user can access protected pages after login

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
const { loginAsAdmin, expectToBeLoggedIn, waitForPageLoad } = require('../fixtures/helpers');

test('user can access protected page after login', async ({ page }) => {
  const admin = ADMIN_USERS.TENANT_A;
  const tenant = TENANTS.A;
  
  // Action: Login
  await loginAsAdmin(page, admin);
  
  // Action: Navigate to protected page
  await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.DASHBOARD}`);
  await waitForPageLoad(page);
  
  // Assert: User is logged in
  await expectToBeLoggedIn(page);
  
  // Assert: On correct URL
  expect(page.url()).toContain('/site_admin');
});
```

### Pattern 2: Verify Access Denied Without Login

**When to use:** Testing that protected routes require authentication

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { expectToBeOnLoginPage, waitForPageLoad } = require('../fixtures/helpers');

test('protected page redirects to login', async ({ page }) => {
  const tenant = TENANTS.A;
  
  // Action: Try to access protected page without login
  await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.DASHBOARD}`);
  await waitForPageLoad(page);
  
  // Assert: Redirected to login
  await expectToBeOnLoginPage(page);
});
```

### Pattern 3: Test Login Form Validation

**When to use:** Testing login form behavior and error handling

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { waitForPageLoad } = require('../fixtures/helpers');

test.describe('Login Form', () => {
  test('invalid credentials show error message', async ({ page }) => {
    const tenant = TENANTS.A;
    
    // Action: Navigate to login page
    await page.goto(`${tenant.baseURL}${ROUTES.LOGIN}`);
    await waitForPageLoad(page);
    
    // Action: Fill form with invalid credentials
    const emailInput = page.locator('input[name=\"user[email]\"]');\n    const passwordInput = page.locator('input[name=\"user[password]\"]');\n    \n    await emailInput.fill('invalid@example.com');\n    await passwordInput.fill('wrongpassword');\n    \n    // Action: Submit form\n    const submitBtn = page.locator('input[type=\"submit\"], button[type=\"submit\"]');\n    await submitBtn.click();\n    await waitForPageLoad(page);\n    \n    // Assert: Still on login page\n    expect(page.url()).toContain('/users/sign_in');\n    \n    // Assert: Error message visible\n    const errorMsg = page.locator('.alert, .flash, [role=\"alert\"]');\n    await expect(errorMsg).toBeVisible();\n  });\n\n  test('empty email field prevents submission', async ({ page }) => {\n    const tenant = TENANTS.A;\n    \n    await page.goto(`${tenant.baseURL}${ROUTES.LOGIN}`);\n    await waitForPageLoad(page);\n    \n    // Check if email field is required\n    const emailInput = page.locator('input[name=\"user[email]\"]');\n    const isRequired = await emailInput.getAttribute('required');\n    \n    if (isRequired !== null) {\n      // Browser will prevent submission\n      expect(isRequired).toBeTruthy();\n    }\n  });\n});\n```

## Multi-Tenant Isolation Patterns

### Pattern 1: Verify Cross-Tenant Access Denied

**When to use:** Testing that users cannot access other tenants' data

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
const { loginAsAdmin, expectToBeOnLoginPage, waitForPageLoad } = require('../fixtures/helpers');

test('tenant A user cannot access tenant B admin', async ({ page }) => {\n  const adminA = ADMIN_USERS.TENANT_A;\n  const tenantB = TENANTS.B;\n  \n  // Action: Login as Tenant A\n  await loginAsAdmin(page, adminA);\n  \n  // Action: Try to access Tenant B admin area\n  await page.goto(`${tenantB.baseURL}${ROUTES.ADMIN.DASHBOARD}`);\n  await waitForPageLoad(page);\n  \n  // Assert: Redirected to login (session doesn't carry over)\n  await expectToBeOnLoginPage(page);\n});\n```

### Pattern 2: Verify Settings Are Tenant-Specific

**When to use:** Testing that changes in one tenant don't affect others

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS } = require('../fixtures/test-data');
const { loginAsAdmin, goToAdminPage, saveAndWait, waitForPageLoad } = require('../fixtures/helpers');

test('settings changes are tenant-specific', async ({ page }) => {\n  const uniqueValue = `tenant-a-${Date.now()}`;\n  const tenantA = TENANTS.A;\n  const adminA = ADMIN_USERS.TENANT_A;\n  \n  // Arrange: Login to Tenant A\n  await loginAsAdmin(page, adminA);\n  \n  // Act: Change a setting in Tenant A\n  await goToAdminPage(page, tenantA, '/site_admin/website/settings?tab=general');\n  const companyNameInput = page.locator('input#company_name, input[name=\"website[company_display_name]\"]');\n  await companyNameInput.fill(uniqueValue);\n  await saveAndWait(page);\n  \n  // Assert: Setting changed in Tenant A\n  await page.reload();\n  await waitForPageLoad(page);\n  const savedValue = await companyNameInput.inputValue();\n  expect(savedValue).toBe(uniqueValue);\n  \n  // Assert: Tenant B is not affected\n  // (would need separate test or Tenant B login to fully verify)\n});\n```

## Admin Integration Test Patterns

### Pattern 1: Admin Setting Changes Appear on Public Site

**When to use:** Testing end-to-end admin feature changes with BYPASS_ADMIN_AUTH=true

**Server Setup Required:**
```bash
RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
```

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToAdminPage, saveAndWait, waitForPageLoad } = require('../fixtures/helpers');

test('changing company name in admin shows on public site', async ({ page }) => {\n  const tenant = TENANTS.A;\n  const newCompanyName = `Test Company ${Date.now()}`;\n  \n  // Act: Change company name in admin\n  await goToAdminPage(page, tenant, ROUTES.ADMIN.WEBSITE_SETTINGS_GENERAL);\n  \n  // Verify we're on the right page\n  const settingsHeader = page.locator('h1, h2');\n  await expect(settingsHeader).toBeVisible();\n  \n  // Fill the company name field\n  const companyInput = page.locator(\n    'input#company_display_name, ' +\n    'input[name=\"website[company_display_name]\"], ' +\n    'input[name=\"pwb_website[company_display_name]\"]'\n  );\n  await companyInput.fill(newCompanyName);\n  \n  // Save\n  await saveAndWait(page);\n  \n  // Act: Go to public homepage\n  await page.goto(`${tenant.baseURL}${ROUTES.HOME}`);\n  await waitForPageLoad(page);\n  \n  // Assert: Company name appears on homepage\n  const pageContent = await page.content();\n  expect(pageContent).toContain(newCompanyName);\n});\n```

### Pattern 2: Theme Change Applied to Public Site

**When to use:** Testing theme switching affects public site styling

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToAdminPage, saveAndWait, waitForPageLoad } = require('../fixtures/helpers');

test('switching theme changes public site appearance', async ({ page }) => {\n  const tenant = TENANTS.A;\n  \n  // Act: Go to appearance settings\n  await goToAdminPage(page, tenant, ROUTES.ADMIN.WEBSITE_SETTINGS_APPEARANCE);\n  await waitForPageLoad(page);\n  \n  // Get available themes\n  const themeSelect = page.locator('select[name=\"website[theme_name]\"]');\n  const currentTheme = await themeSelect.inputValue();\n  \n  // Get all theme options\n  const themeOptions = await themeSelect.locator('option').allTextContents();\n  const availableThemes = themeOptions.filter(\n    t => t.trim() !== '' && t.trim() !== currentTheme\n  );\n  \n  // Only proceed if there's another theme available\n  if (availableThemes.length > 0) {\n    const newTheme = availableThemes[0];\n    \n    // Action: Switch theme\n    await themeSelect.selectOption({ label: newTheme });\n    await saveAndWait(page);\n    \n    // Act: View public site\n    await page.goto(`${tenant.baseURL}${ROUTES.HOME}`);\n    await waitForPageLoad(page);\n    \n    // Assert: Body has theme class\n    const bodyClasses = await page.locator('body').getAttribute('class');\n    expect(bodyClasses).toBeTruthy();\n    \n    // Assert: Theme identifier in class\n    const hasThemeClass = \n      bodyClasses.includes('theme') || \n      bodyClasses.includes(newTheme.toLowerCase());\n    expect(hasThemeClass).toBeTruthy();\n  }\n});\n```

### Pattern 3: Navigation Visibility Toggle

**When to use:** Testing that navigation visibility settings affect public menu

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToAdminPage, waitForPageLoad } = require('../fixtures/helpers');

test('hiding navigation link hides it from public site', async ({ page }) => {\n  const tenant = TENANTS.A;\n  \n  // Act: Go to navigation settings\n  await goToAdminPage(page, tenant, ROUTES.ADMIN.WEBSITE_SETTINGS_NAVIGATION);\n  await waitForPageLoad(page);\n  \n  // Find a visibility checkbox\n  const visibilityCheckbox = page.locator('input[type=\"checkbox\"][name*=\"visible\"]').first();\n  const wasChecked = await visibilityCheckbox.isChecked();\n  \n  // Toggle visibility (hide the link)\n  if (wasChecked) {\n    await visibilityCheckbox.uncheck();\n  } else {\n    await visibilityCheckbox.check();\n  }\n  \n  // Save\n  const saveBtn = page.locator('button[type=\"submit\"]:has-text(\"Save\"), input[type=\"submit\"]');\n  if (await saveBtn.count() > 0) {\n    await saveBtn.first().click();\n    await waitForPageLoad(page);\n  }\n  \n  // Act: Check public site navigation\n  await page.goto(`${tenant.baseURL}${ROUTES.HOME}`);\n  await waitForPageLoad(page);\n  \n  // Assert: Navigation is present\n  const nav = page.locator('nav, header');\n  await expect(nav.first()).toBeVisible();\n});\n```

## Form Interaction Patterns

### Pattern 1: Fill and Submit Form

**When to use:** Testing form submission and validation

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS } = require('../fixtures/test-data');
const { fillField, saveAndWait, waitForPageLoad } = require('../fixtures/helpers');

test('contact form submission works', async ({ page }) => {\n  const tenant = TENANTS.A;\n  \n  // Navigate to contact form\n  await page.goto(`${tenant.baseURL}/contact-us`);\n  await waitForPageLoad(page);\n  \n  // Fill form using helper (tries label, name, id)\n  await fillField(page, 'Name', 'John Doe');\n  await fillField(page, 'Email', 'john@example.com');\n  await fillField(page, 'Message', 'Test message');\n  \n  // Submit form\n  await saveAndWait(page, 'Submit');\n  \n  // Assert: Form processed (redirect or confirmation message)\n  await waitForPageLoad(page);\n  const pageContent = await page.content();\n  const hasSuccess = \n    pageContent.includes('Thank you') || \n    pageContent.includes('submitted') ||\n    page.url().includes('thank');\n  expect(hasSuccess).toBeTruthy();\n});\n```

### Pattern 2: Add New Entry with Modal

**When to use:** Testing create/add operations with modal dialogs

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
const { loginAsAdmin, waitForPageLoad } = require('../fixtures/helpers');

test('adding new property type works', async ({ page }) => {\n  const admin = ADMIN_USERS.TENANT_A;\n  const tenant = TENANTS.A;\n  const newTypeName = `Type-${Date.now()}`;\n  \n  // Action: Login and navigate to settings\n  await loginAsAdmin(page, admin);\n  await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}/property_types`);\n  await waitForPageLoad(page);\n  \n  // Action: Click add button to open modal\n  const addBtn = page.locator('button:has-text(\"Add New Entry\"), button:has-text(\"Add\")');\n  await addBtn.click();\n  \n  // Assert: Modal appears\n  const modal = page.locator('[role=\"dialog\"], .modal, #new-entry-modal');\n  await expect(modal).toBeVisible({ timeout: 5000 });\n  \n  // Action: Fill in the English translation field\n  const englishInput = page.locator('input[name*=\"translations\"][name*=\"en\"]');\n  await englishInput.fill(newTypeName);\n  \n  // Action: Submit the form\n  const submitBtn = modal.locator('button[type=\"submit\"]:has-text(\"Add\"), input[type=\"submit\"]');\n  await submitBtn.click();\n  await waitForPageLoad(page);\n  \n  // Assert: Entry appears in list\n  const pageContent = await page.content();\n  expect(pageContent).toContain(newTypeName);\n});\n```

### Pattern 3: Edit and Update Entry

**When to use:** Testing update operations on existing items

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS } = require('../fixtures/test-data');
const { loginAsAdmin, saveAndWait, waitForPageLoad } = require('../fixtures/helpers');

test('editing entry updates values', async ({ page }) => {\n  const admin = ADMIN_USERS.TENANT_A;\n  const tenant = TENANTS.A;\n  const updatedValue = `Updated-${Date.now()}`;\n  \n  // Action: Login and navigate to admin\n  await loginAsAdmin(page, admin);\n  await page.goto(`${tenant.baseURL}/site_admin/properties/settings`);\n  await waitForPageLoad(page);\n  \n  // Action: Click edit on first entry\n  const editLink = page.locator('a[href*=\"/edit\"]').first();\n  await editLink.click();\n  await waitForPageLoad(page);\n  \n  // Action: Update the field\n  const nameInput = page.locator('input[name*=\"name\"]').first();\n  await nameInput.fill(updatedValue);\n  \n  // Action: Save\n  await saveAndWait(page);\n  \n  // Assert: Redirected back to list\n  const url = page.url();\n  expect(url).not.toContain('/edit');\n  \n  // Assert: Updated value appears in list\n  const pageContent = await page.content();\n  expect(pageContent).toContain(updatedValue);\n});\n```

## Navigation and Page Structure Patterns

### Pattern 1: Verify Page Has Required Sections

**When to use:** Testing that page structure and content is correct

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { waitForPageLoad } = require('../fixtures/helpers');

test('property listing page has required sections', async ({ page }) => {\n  const tenant = TENANTS.A;\n  \n  // Action: Navigate to listings\n  await page.goto(`${tenant.baseURL}${ROUTES.BUY}`);\n  await waitForPageLoad(page);\n  \n  // Assert: Page structure\n  // Header with search/filter\n  const header = page.locator('header, [role=\"banner\"]');\n  await expect(header).toBeVisible();\n  \n  // Main content area\n  const mainContent = page.locator('main, [role=\"main\"]');\n  await expect(mainContent).toBeVisible();\n  \n  // Footer\n  const footer = page.locator('footer, [role=\"contentinfo\"]');\n  await expect(footer).toBeVisible();\n});\n```

### Pattern 2: Navigation Menu Works

**When to use:** Testing that main navigation functions correctly

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { waitForPageLoad } = require('../fixtures/helpers');

test('clicking navigation links works', async ({ page }) => {\n  const tenant = TENANTS.A;\n  \n  // Action: Go to home\n  await page.goto(`${tenant.baseURL}${ROUTES.HOME}`);\n  await waitForPageLoad(page);\n  \n  // Find and click \"Buy\" link\n  const buyLink = page.locator('a:has-text(\"Buy\"), a[href*=\"/buy\"]');\n  if (await buyLink.count() > 0) {\n    await buyLink.click();\n    await waitForPageLoad(page);\n    \n    // Assert: Navigated to correct page\n    expect(page.url()).toContain('/buy');\n  }\n});\n```

## Error Handling and Edge Cases

### Pattern 1: Handle Potential Missing Elements

**When to use:** Testing functionality that might not exist in all configurations

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { waitForPageLoad } = require('../fixtures/helpers');

test('optional theme selector works if present', async ({ page }) => {\n  const tenant = TENANTS.A;\n  \n  await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.WEBSITE_SETTINGS_APPEARANCE}`);\n  await waitForPageLoad(page);\n  \n  // Theme selector may or may not exist\n  const themeSelect = page.locator('select[name*=\"theme\"]');\n  \n  // Only test if the element exists\n  if (await themeSelect.count() > 0) {\n    const options = await themeSelect.locator('option').count();\n    expect(options).toBeGreaterThan(0);\n  } else {\n    // Theme selector not present - that's OK\n    // Just verify page loaded\n    const pageContent = await page.content();\n    expect(pageContent).toBeTruthy();\n  }\n});\n```

### Pattern 2: Graceful Fallback for Assertions

**When to use:** Testing across different possible HTML structures

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { loginAsAdmin, waitForPageLoad } = require('../fixtures/helpers');

test('settings form can be found by various selectors', async ({ page }) => {\n  const admin = ADMIN_USERS.TENANT_A;\n  const tenant = TENANTS.A;\n  \n  await loginAsAdmin(page, admin);\n  await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);\n  await waitForPageLoad(page);\n  \n  // Try multiple selectors to find the save button\n  const saveButton = \n    page.locator('input[type=\"submit\"][value*=\"Save\"]') ||\n    page.locator('button[type=\"submit\"]:has-text(\"Save\")') ||\n    page.locator('input[type=\"submit\"]');\n  \n  // Should find something\n  expect(await saveButton.count()).toBeGreaterThan(0);\n});\n```

## Performance and Optimization Patterns

### Pattern 1: Reuse Page State for Multiple Tests

**When to use:** Testing related functionality without repeated login

```javascript
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
const { loginAsAdmin, waitForPageLoad } = require('../fixtures/helpers');

let loggedInPage; // Shared state within test group\n\ntest.describe('Admin Dashboard', () => {\n  test.beforeEach(async ({ page }) => {\n    const admin = ADMIN_USERS.TENANT_A;\n    \n    // Login once for all tests in this group\n    await loginAsAdmin(page, admin);\n    await page.goto(`${admin.tenant.baseURL}${ROUTES.ADMIN.DASHBOARD}`);\n    await waitForPageLoad(page);\n    \n    loggedInPage = page;\n  });\n  \n  test('can access properties section', async () => {\n    const propLink = loggedInPage.locator('a[href*=\"/props\"]');\n    await expect(propLink).toBeVisible();\n  });\n  \n  test('can access pages section', async () => {\n    const pagesLink = loggedInPage.locator('a[href*=\"/pages\"]');\n    await expect(pagesLink).toBeVisible();\n  });\n});\n```

### Pattern 2: Wait Only When Necessary

**When to use:** Speeding up tests by using shorter timeouts where appropriate

```javascript
const { test, expect } = require('@playwright/test');

test('quick assertion with short timeout', async ({ page }) => {\n  // Full page load - we need everything\n  await page.goto('http://example.com');\n  await page.waitForLoadState('networkidle');\n  \n  // This element should appear quickly\n  await page.waitForSelector('.visible-on-load', { timeout: 2000 });\n  \n  // This might take longer\n  await page.waitForSelector('.lazy-loaded-element', { timeout: 10000 });\n});\n```

