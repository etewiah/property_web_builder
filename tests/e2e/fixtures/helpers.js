/**
 * Helper functions for E2E tests
 */

const { expect } = require('@playwright/test');

/**
 * Login as admin user
 * @param {import('@playwright/test').Page} page
 * @param {Object} adminUser - Admin user credentials object
 */
async function loginAsAdmin(page, adminUser) {
  await page.goto(`${adminUser.tenant.baseURL}/users/sign_in`);
  await page.waitForSelector('input[name="user[email]"]', { timeout: 5000 });
  await page.fill('input[name="user[email]"]', adminUser.email);
  await page.fill('input[name="user[password]"]', adminUser.password);
  await page.click('input[type="submit"]');
  await page.waitForLoadState('networkidle');
}

/**
 * Assert page has content (with multiple alternatives)
 * @param {import('@playwright/test').Page} page
 * @param {string[]} alternatives - Array of possible text content
 */
async function expectPageToHaveAnyContent(page, alternatives) {
  const pageContent = await page.content();
  const hasAny = alternatives.some(text => pageContent.includes(text));
  expect(hasAny).toBeTruthy();
}

/**
 * Check if user is logged in (not on login page)
 * @param {import('@playwright/test').Page} page
 */
async function expectToBeLoggedIn(page) {
  const currentURL = page.url();
  expect(currentURL).not.toContain('/users/sign_in');
  expect(currentURL).not.toContain('/firebase_login');
}

/**
 * Check if user is redirected to login
 * @param {import('@playwright/test').Page} page
 */
async function expectToBeOnLoginPage(page) {
  const currentURL = page.url();
  const isOnLogin = currentURL.includes('/users/sign_in') ||
                    currentURL.includes('/firebase_login') ||
                    currentURL.includes('/login');
  expect(isOnLogin).toBeTruthy();
}

/**
 * Navigate to tenant URL
 * @param {import('@playwright/test').Page} page
 * @param {Object} tenant - Tenant configuration object
 * @param {string} path - Path to navigate to
 */
async function goToTenant(page, tenant, path = '/') {
  await page.goto(`${tenant.baseURL}${path}`);
  await page.waitForLoadState('networkidle');
}

/**
 * Wait for page to be fully loaded
 * @param {import('@playwright/test').Page} page
 */
async function waitForPageLoad(page) {
  await page.waitForLoadState('networkidle');
  await page.waitForLoadState('domcontentloaded');
}

/**
 * Fill in a form field by label or name
 * @param {import('@playwright/test').Page} page
 * @param {string} fieldIdentifier - Label text, name, or id
 * @param {string} value - Value to fill
 */
async function fillField(page, fieldIdentifier, value) {
  // Try by label first
  const byLabel = page.locator(`label:has-text("${fieldIdentifier}") + input, label:has-text("${fieldIdentifier}") + textarea`);
  if (await byLabel.count() > 0) {
    await byLabel.fill(value);
    return;
  }

  // Try by name attribute
  const byName = page.locator(`input[name*="${fieldIdentifier}"], textarea[name*="${fieldIdentifier}"]`);
  if (await byName.count() > 0) {
    await byName.first().fill(value);
    return;
  }

  // Try by id
  const byId = page.locator(`#${fieldIdentifier}`);
  if (await byId.count() > 0) {
    await byId.fill(value);
    return;
  }

  throw new Error(`Could not find field: ${fieldIdentifier}`);
}

module.exports = {
  loginAsAdmin,
  expectPageToHaveAnyContent,
  expectToBeLoggedIn,
  expectToBeOnLoginPage,
  goToTenant,
  waitForPageLoad,
  fillField,
};
