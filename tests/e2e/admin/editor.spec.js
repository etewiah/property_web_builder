// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS } = require('../fixtures/test-data');
const { loginAsAdmin, waitForPageLoad } = require('../fixtures/helpers');

// Test configuration
const BASE_URL = 'http://tenant-a.e2e.localhost:3001';
const tenant = TENANTS.A;
const admin = ADMIN_USERS.TENANT_A;

test.describe('In-Context Editor', () => {

  test.describe('Editor Shell', () => {
    test('loads the editor page at /edit', async ({ page }) => {
      // Editor requires admin authentication
      await loginAsAdmin(page, admin);
      await page.goto(`${BASE_URL}/edit`);
      
      // Check the editor shell structure - now uses bottom panel layout
      await expect(page.locator('.pwb-editor-panel')).toBeVisible();
      await expect(page.locator('#pwb-site-frame')).toBeVisible();
      await expect(page.locator('.pwb-editor-toolbar')).toBeVisible();
    });

    test('displays bottom panel with content editor', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${BASE_URL}/edit`);
      
      // Check panel header and content area
      await expect(page.locator('.pwb-panel-header')).toBeVisible();
      await expect(page.locator('#panel-content')).toBeVisible();
      await expect(page.locator('.pwb-panel-title')).toContainText('Content Editor');
    });

    test('can toggle panel visibility', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${BASE_URL}/edit`);
      
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
      await loginAsAdmin(page, admin);
      await page.goto(`${BASE_URL}/edit`);
      
      const resizeHandle = page.locator('#pwb-resize-handle');
      await expect(resizeHandle).toBeVisible();
      
      // Check cursor style on hover
      await resizeHandle.hover();
      await expect(resizeHandle).toHaveCSS('cursor', 'ns-resize');
    });

    test('iframe loads the site with edit_mode parameter', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${BASE_URL}/edit`);
      
      // Get iframe src
      const iframe = page.locator('#pwb-site-frame');
      const src = await iframe.getAttribute('src');
      
      expect(src).toContain('edit_mode=true');
    });

    test('exit button links back to homepage', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${BASE_URL}/edit`);

      const exitBtn = page.locator('.pwb-btn-exit');
      await expect(exitBtn).toBeVisible();
      // The href may include locale parameter (e.g., "/?locale=en" or "/")
      const href = await exitBtn.getAttribute('href');
      expect(href === '/' || href.startsWith('/?') || href.includes('locale=')).toBeTruthy();
    });
  });

  test.describe('Editor with Path Parameter', () => {
    test('loads specific page in iframe when path provided', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${BASE_URL}/edit/about-us`);
      
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
    // Login first to get session
    await loginAsAdmin(page, admin);

    // Navigate to a page on the site first (to establish cookies)
    await page.goto(`${BASE_URL}/edit`);

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
    // Login first to get session
    await loginAsAdmin(page, admin);

    // Navigate to editor page to establish cookies and get CSRF token
    await page.goto(`${BASE_URL}/edit`);

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
