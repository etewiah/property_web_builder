// @ts-check
const { test, expect } = require('@playwright/test');

// Test configuration
const BASE_URL = 'http://tenant-a.e2e.localhost:3001';

test.describe('In-Context Editor', () => {
  
  test.describe('Editor Shell', () => {
    test('loads the editor page at /edit', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      // Check the editor shell structure
      await expect(page.locator('.pwb-editor-sidebar')).toBeVisible();
      await expect(page.locator('#pwb-site-frame')).toBeVisible();
      await expect(page.locator('.pwb-editor-toolbar')).toBeVisible();
    });

    test('displays sidebar with navigation tabs', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      // Check navigation tabs
      await expect(page.locator('a[href="#panel-content"]')).toBeVisible();
      await expect(page.locator('a[href="#panel-theme"]')).toBeVisible();
      await expect(page.locator('a[href="#panel-settings"]')).toBeVisible();
    });

    test('can switch between sidebar tabs', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      // Content tab should be active by default
      await expect(page.locator('#panel-content')).toHaveClass(/active/);
      
      // Click Theme tab
      await page.click('a[href="#panel-theme"]');
      await expect(page.locator('#panel-theme')).toHaveClass(/active/);
      await expect(page.locator('#panel-content')).not.toHaveClass(/active/);
      
      // Click Settings tab
      await page.click('a[href="#panel-settings"]');
      await expect(page.locator('#panel-settings')).toHaveClass(/active/);
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

  test.describe('Theme Settings Panel', () => {
    test('displays color pickers for brand colors', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      // Switch to Theme tab
      await page.click('a[href="#panel-theme"]');
      
      // Check color inputs exist
      await expect(page.locator('#primary_color')).toBeVisible();
      await expect(page.locator('#secondary_color')).toBeVisible();
      await expect(page.locator('#action_color')).toBeVisible();
    });

    test('displays footer color settings', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      await page.click('a[href="#panel-theme"]');
      
      await expect(page.locator('#footer_bg_color')).toBeVisible();
      await expect(page.locator('#footer_main_text_color')).toBeVisible();
    });

    test('color picker syncs with text input', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      await page.click('a[href="#panel-theme"]');
      
      // Get the primary color input
      const colorInput = page.locator('#primary_color');
      const textInput = page.locator('.pwb-color-text[data-for="primary_color"]');
      
      // Change the color picker value
      await colorInput.fill('#ff5500');
      
      // The text input should update (may need to trigger input event)
      await colorInput.dispatchEvent('input');
      
      // Check that text input reflects the change
      const textValue = await textInput.inputValue();
      expect(textValue.toLowerCase()).toBe('#ff5500');
    });

    test('has save and reset buttons', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      await page.click('a[href="#panel-theme"]');
      
      await expect(page.locator('#pwb-theme-form button[type="submit"]')).toBeVisible();
      await expect(page.locator('#pwb-reset-theme')).toBeVisible();
    });

    test('can save theme settings', async ({ page }) => {
      await page.goto(`${BASE_URL}/edit`);
      
      await page.click('a[href="#panel-theme"]');
      
      // Change a color value
      await page.locator('#primary_color').fill('#123456');
      await page.locator('#primary_color').dispatchEvent('input');
      
      // Submit the form
      await page.click('#pwb-theme-form button[type="submit"]');
      
      // Wait for the notification
      await expect(page.locator('.pwb-notification-success')).toBeVisible({ timeout: 5000 });
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
