// @ts-check
const { test, expect } = require('@playwright/test');

// Test configuration
const BASE_URL = 'http://tenant-a.e2e.localhost:3001';

test.describe('In-Context Editor', () => {
  
  test.describe('Editor Shell', () => {
    test('loads the editor page at /edit', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      // Check the editor shell structure - now uses bottom panel layout
      await expect(page.locator('.pwb-editor-panel')).toBeVisible();
      await expect(page.locator('#pwb-site-frame')).toBeVisible();
      await expect(page.locator('.pwb-editor-toolbar')).toBeVisible();
    });

    test('displays bottom panel with content editor', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      // Check panel header and content area
      await expect(page.locator('.pwb-panel-header')).toBeVisible();
      await expect(page.locator('#panel-content')).toBeVisible();
      await expect(page.locator('.pwb-panel-title')).toContainText('Content Editor');
    });

    test('can toggle panel visibility', async ({ page }) => {
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
      await page.goto(`${BASE_URL}/edit`);
      
      const resizeHandle = page.locator('#pwb-resize-handle');
      await expect(resizeHandle).toBeVisible();
      
      // Check cursor style on hover
      await resizeHandle.hover();
      await expect(resizeHandle).toHaveCSS('cursor', 'ns-resize');
    });

    test('iframe loads the site with edit_mode parameter', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      // Get iframe src
      const iframe = page.locator('#pwb-site-frame');
      const src = await iframe.getAttribute('src');
      
      expect(src).toContain('edit_mode=true');
    });

    test('exit button links back to homepage', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      const exitBtn = page.locator('.pwb-btn-exit');
      await expect(exitBtn).toBeVisible();
      await expect(exitBtn).toHaveAttribute('href', '/');
    });
  });

  test.describe('Editor with Path Parameter', () => {
    test('loads specific page in iframe when path provided', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit/about-us`);
      
      const iframe = page.locator('#pwb-site-frame');
      const src = await iframe.getAttribute('src');
      
      expect(src).toContain('/about-us');
      expect(src).toContain('edit_mode=true');
    });
  });
});

test.describe('Theme Settings API', () => {
  test('GET /editor/theme_settings returns current settings', async ({ request }) => {
    const response = await request.get(`${BASE_URL}/editor/theme_settings`);
    
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data).toHaveProperty('style_variables');
    expect(data).toHaveProperty('theme_name');
  });

  test('PATCH /editor/theme_settings updates settings', async ({ request }) => {
    const response = await request.patch(`${BASE_URL}/editor/theme_settings`, {
      form: {
        'style_variables[primary_color]': '#aabbcc',
        'style_variables[secondary_color]': '#112233'
      }
    });
    
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data.status).toBe('success');
    expect(data.style_variables.primary_color).toBe('#aabbcc');
  });
});
