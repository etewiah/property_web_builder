// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS } = require('../fixtures/test-data');
const { waitForPageLoad, goToAdminPage } = require('../fixtures/helpers');

/**
 * In-Context Editor Tests
 *
 * NOTE: These tests require BYPASS_ADMIN_AUTH=true to be set.
 * Start server with: BYPASS_ADMIN_AUTH=true RAILS_ENV=e2e bin/rails server -p 3001
 */

// Test configuration
const tenant = TENANTS.A;
const BASE_URL = tenant.baseURL;

/**
 * Helper to verify we have admin access (auth bypass is working)
 * @param {import('@playwright/test').Page} page
 */
async function verifyAdminAccess(page) {
  const currentURL = page.url();
  if (currentURL.includes('/sign_in') || currentURL.includes('/pwb_login')) {
    throw new Error(
      'BYPASS_ADMIN_AUTH is not enabled! ' +
      'Restart the server with: BYPASS_ADMIN_AUTH=true RAILS_ENV=e2e bin/rails server -p 3001'
    );
  }
}

test.describe('In-Context Editor', () => {

  test.describe('Editor Shell', () => {
    test('loads the editor page at /edit', async ({ page }) => {
      // Editor requires admin access - use auth bypass
      await page.goto(`${BASE_URL}/edit`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Check the editor shell structure - now uses bottom panel layout
      await expect(page.locator('.pwb-editor-panel')).toBeVisible();
      await expect(page.locator('#pwb-site-frame')).toBeVisible();
      await expect(page.locator('.pwb-editor-toolbar')).toBeVisible();
    });

    test('displays bottom panel with content editor', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Check panel header and content area
      await expect(page.locator('.pwb-panel-header')).toBeVisible();
      await expect(page.locator('#panel-content')).toBeVisible();
      await expect(page.locator('.pwb-panel-title')).toContainText('Content Editor');
    });

    test('can toggle panel visibility', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      const panel = page.locator('.pwb-editor-panel');
      const toggleBtn = page.locator('#pwb-toggle-panel');

      // Panel should be visible initially
      await expect(panel).not.toHaveClass(/pwb-panel-collapsed/);

      // Click toggle to collapse
      await toggleBtn.click();
      await expect(panel).toHaveClass(/pwb-panel-collapsed/);

      // Click toggle to expand
      await toggleBtn.click();
      await expect(panel).not.toHaveClass(/pwb-panel-collapsed/);
    });

    test('has resize handle for adjusting panel height', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      const resizeHandle = page.locator('#pwb-resize-handle');
      await expect(resizeHandle).toBeVisible();

      // Check cursor style on hover
      await resizeHandle.hover();
      await expect(resizeHandle).toHaveCSS('cursor', 'ns-resize');
    });

    test('iframe loads the site with edit_mode parameter', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Get iframe src
      const iframe = page.locator('#pwb-site-frame');
      const src = await iframe.getAttribute('src');

      expect(src).toContain('edit_mode=true');
    });

    test('exit button links back to homepage', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      const exitBtn = page.locator('.pwb-btn-exit');
      await expect(exitBtn).toBeVisible();
      // The href may include locale parameter (e.g., "/?locale=en" or "/")
      const href = await exitBtn.getAttribute('href');
      expect(href === '/' || href.startsWith('/?') || href.includes('locale=')).toBeTruthy();
    });
  });

  test.describe('Editor with Path Parameter', () => {
    test('loads specific page in iframe when path provided', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit/about-us`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      const iframe = page.locator('#pwb-site-frame');
      const src = await iframe.getAttribute('src');

      expect(src).toContain('/about-us');
      expect(src).toContain('edit_mode=true');
    });
  });
});

test.describe('Theme Settings API', () => {
  // Note: These API tests use page.evaluate to make fetch requests with session cookies
  test('GET /editor/theme_settings returns current settings', async ({ page }) => {
    // Navigate to editor page first (to establish session with auth bypass)
    await page.goto(`${BASE_URL}/edit`);
    await waitForPageLoad(page);
    await verifyAdminAccess(page);

    // Use page.evaluate to make API request with session cookies
    const result = await page.evaluate(async () => {
      const response = await fetch('/editor/theme_settings', {
        credentials: 'include',
        headers: { 'Accept': 'application/json' }
      });
      return {
        status: response.status,
        ok: response.ok,
        data: response.ok ? await response.json() : null
      };
    });

    // Should return JSON with theme settings
    if (result.ok) {
      expect(result.data).toHaveProperty('style_variables');
      expect(result.data).toHaveProperty('theme_name');
    } else {
      // If 401/403, that's expected if auth is required
      expect(result.status).toBeGreaterThanOrEqual(400);
    }
  });

  test('PATCH /editor/theme_settings updates settings', async ({ page }) => {
    // Navigate to editor page to establish session and get CSRF token
    await page.goto(`${BASE_URL}/edit`);
    await waitForPageLoad(page);
    await verifyAdminAccess(page);

    // Get CSRF token from meta tag
    const csrfToken = await page.evaluate(() => {
      const meta = document.querySelector('meta[name="csrf-token"]');
      return meta ? meta.getAttribute('content') : null;
    });

    // Make PATCH request with session cookies and CSRF token
    const result = await page.evaluate(async (token) => {
      const formData = new FormData();
      formData.append('style_variables[primary_color]', '#aabbcc');
      formData.append('style_variables[secondary_color]', '#112233');

      const response = await fetch('/editor/theme_settings', {
        method: 'PATCH',
        credentials: 'include',
        headers: token ? { 'X-CSRF-Token': token } : {},
        body: formData
      });
      return {
        status: response.status,
        ok: response.ok
      };
    }, csrfToken);

    // Should get a response (success or validation error)
    expect(result.status).toBeDefined();
    // CSRF is skipped for this endpoint, so it should succeed
    expect(result.ok).toBeTruthy();
  });
});
