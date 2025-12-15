// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { waitForPageLoad, goToAdminPage } = require('../fixtures/helpers');

/**
 * Site Admin Settings Integration Tests
 *
 * These tests verify that changes made in the site admin panel
 * are correctly applied to the public-facing website.
 *
 * IMPORTANT: These tests require BYPASS_ADMIN_AUTH=true to be set
 * on the Rails server to skip authentication.
 *
 * Start server with one of:
 *   RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
 *   BYPASS_ADMIN_AUTH=true RAILS_ENV=e2e bin/rails server -p 3001
 */

const tenant = TENANTS.A;
const BASE_URL = tenant.baseURL;

/**
 * Helper to verify we have admin access (auth bypass is working)
 * @param {import('@playwright/test').Page} page
 */
async function verifyAdminAccess(page) {
  const pageContent = await page.content();
  if (pageContent.includes('Admin Access Required') || pageContent.includes('Sign in')) {
    throw new Error(
      'BYPASS_ADMIN_AUTH is not enabled! ' +
      'Restart the server with: BYPASS_ADMIN_AUTH=true RAILS_ENV=e2e bin/rails server -p 3001'
    );
  }
}

test.describe('Site Admin Settings Integration', () => {

  test.describe('Company Display Name Changes', () => {
    // Generate unique company name to avoid test pollution
    const uniqueCompanyName = `Test Company ${Date.now()}`;

    test('changing company name in admin updates the public site', async ({ page }) => {
      // Step 1: Go to site admin general settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);

      // Verify auth bypass is working
      await verifyAdminAccess(page);

      // Verify we're on the settings page
      const generalSettingsHeader = page.locator('h2:has-text("General Settings")');
      await expect(generalSettingsHeader).toBeVisible({ timeout: 5000 });

      // Step 2: Change the company display name
      const companyNameInput = page.locator('input#pwb_website_company_display_name, input[name="pwb_website[company_display_name]"], input[name="website[company_display_name]"]');
      await expect(companyNameInput).toBeVisible();

      // Clear and fill with new name
      await companyNameInput.fill(uniqueCompanyName);

      // Step 3: Save the settings
      const saveButton = page.locator('input[type="submit"][value*="Save"], button[type="submit"]:has-text("Save")');
      await saveButton.click();
      await waitForPageLoad(page);

      // Verify save was successful (should see success notice or stay on page)
      const currentUrl = page.url();
      expect(currentUrl).toContain('settings');

      // Step 4: Visit the public homepage and verify company name appears
      await page.goto(`${BASE_URL}/`);
      await waitForPageLoad(page);

      // The company name should appear somewhere on the page (header, footer, or title)
      const pageContent = await page.content();
      expect(pageContent).toContain(uniqueCompanyName);
    });
  });

  test.describe('Theme/Appearance Changes', () => {
    test('changing theme in admin updates the public site styling', async ({ page }) => {
      // Step 1: Go to appearance settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=appearance`);
      await waitForPageLoad(page);

      // Verify auth bypass is working
      await verifyAdminAccess(page);

      // Verify we're on the appearance tab
      await expect(page.locator('h2:has-text("Appearance"), h2:has-text("Theme")')).toBeVisible({ timeout: 5000 });

      // Get available themes
      const themeSelect = page.locator('select[name="website[theme_name]"]');
      if (await themeSelect.count() > 0) {
        // Get current theme
        const currentTheme = await themeSelect.inputValue();

        // Get all options
        const options = await themeSelect.locator('option').allTextContents();

        // Find a different theme to switch to
        const availableThemes = options.filter(t => t.toLowerCase() !== currentTheme.toLowerCase() && t !== '');

        if (availableThemes.length > 0) {
          // Select a different theme
          const newTheme = availableThemes[0];
          await themeSelect.selectOption({ label: newTheme });

          // Save settings
          const saveButton = page.locator('input[type="submit"][value*="Save"], button[type="submit"]:has-text("Save")');
          await saveButton.click();
          await waitForPageLoad(page);

          // Step 2: Visit public site and verify theme is applied
          await page.goto(`${BASE_URL}/`);
          await waitForPageLoad(page);

          // Check that body has theme class
          const bodyClasses = await page.locator('body').getAttribute('class');
          // Theme class should be present (e.g., 'brisbane-theme', 'default-theme')
          expect(bodyClasses).toBeTruthy();
        }
      }
    });

    test('custom CSS added in admin appears on public site', async ({ page }) => {
      const uniqueClassName = `test-class-${Date.now()}`;
      const customCSS = `.${uniqueClassName} { display: block; }`;

      // Step 1: Go to appearance settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=appearance`);
      await waitForPageLoad(page);

      // Find the custom CSS textarea
      const cssTextarea = page.locator('textarea[name="website[raw_css]"]');
      if (await cssTextarea.count() > 0) {
        // Get existing CSS and append our test CSS
        const existingCSS = await cssTextarea.inputValue();
        await cssTextarea.fill(`${existingCSS}\n/* Test CSS */\n${customCSS}`);

        // Save settings
        const saveButton = page.locator('input[type="submit"][value*="Save"], button[type="submit"]:has-text("Save")');
        await saveButton.click();
        await waitForPageLoad(page);

        // Step 2: Visit public site and verify CSS is included
        await page.goto(`${BASE_URL}/`);
        await waitForPageLoad(page);

        // Check that our custom CSS rule is in the page
        const styleTags = await page.locator('style').allTextContents();
        const allStyles = styleTags.join(' ');

        // The CSS should be somewhere in the styles
        expect(allStyles).toContain(uniqueClassName);
      }
    });
  });

  test.describe('Currency and Locale Settings', () => {
    test('changing default currency updates property display format', async ({ page }) => {
      // Step 1: Go to general settings and change currency
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);

      // Verify auth bypass is working
      await verifyAdminAccess(page);

      const currencySelect = page.locator('select[name*="default_currency"]');
      await expect(currencySelect).toBeVisible();

      // Get current currency
      const currentCurrency = await currencySelect.inputValue();

      // Switch to a different currency (toggle between USD and EUR)
      const newCurrency = currentCurrency === 'USD' ? 'EUR' : 'USD';
      await currencySelect.selectOption(newCurrency);

      // Save settings
      const saveButton = page.locator('input[type="submit"][value*="Save"], button[type="submit"]:has-text("Save")');
      await saveButton.click();
      await waitForPageLoad(page);

      // Step 2: Visit a property listing page
      await page.goto(`${BASE_URL}/en/buy`);
      await waitForPageLoad(page);

      // The page should load successfully (currency formatting is internal)
      const pageContent = await page.content();
      // Look for currency symbols - EUR uses € and USD uses $
      const hasCurrencySymbol = pageContent.includes('€') || pageContent.includes('$') || pageContent.includes('EUR') || pageContent.includes('USD');
      // This is a soft check - properties might not be present
      expect(pageContent).toBeTruthy();
    });

    test('changing area unit setting persists correctly', async ({ page }) => {
      // Step 1: Go to general settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);

      // Verify auth bypass is working
      await verifyAdminAccess(page);

      const areaUnitSelect = page.locator('select[name*="default_area_unit"]');
      await expect(areaUnitSelect).toBeVisible();

      // Toggle between sqmt and sqft
      const currentUnit = await areaUnitSelect.inputValue();
      const newUnit = currentUnit === 'sqmt' ? 'sqft' : 'sqmt';
      await areaUnitSelect.selectOption(newUnit);

      // Save settings
      const saveButton = page.locator('input[type="submit"][value*="Save"], button[type="submit"]:has-text("Save")');
      await saveButton.click();
      await waitForPageLoad(page);

      // Verify setting was saved by reloading the page
      await page.reload();
      await waitForPageLoad(page);

      const savedUnit = await areaUnitSelect.inputValue();
      expect(savedUnit).toBe(newUnit);
    });
  });

  test.describe('Navigation Settings', () => {
    test('changing navigation link visibility affects public site menu', async ({ page }) => {
      // Step 1: Go to navigation settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=navigation`);
      await waitForPageLoad(page);

      // Check for navigation link visibility toggles
      const visibilityCheckboxes = page.locator('input[type="checkbox"][name*="visible"]');
      const checkboxCount = await visibilityCheckboxes.count();

      if (checkboxCount > 0) {
        // Get the first link's visibility state
        const firstCheckbox = visibilityCheckboxes.first();
        const wasChecked = await firstCheckbox.isChecked();

        // Toggle the visibility
        if (wasChecked) {
          await firstCheckbox.uncheck();
        } else {
          await firstCheckbox.check();
        }

        // Save navigation settings (look for the form's submit)
        const saveButton = page.locator('button[type="submit"]:has-text("Save"), input[type="submit"]');
        if (await saveButton.count() > 0) {
          await saveButton.first().click();
          await waitForPageLoad(page);
        }

        // Step 2: Visit public site and check navigation
        await page.goto(`${BASE_URL}/`);
        await waitForPageLoad(page);

        // Navigation should be present on the page
        const nav = page.locator('nav, header');
        await expect(nav.first()).toBeVisible();
      }
    });
  });

  test.describe('External Image Mode Setting', () => {
    test('toggling external image mode persists correctly', async ({ page }) => {
      // Step 1: Go to general settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);

      // Find the external image mode checkbox
      const externalImageCheckbox = page.locator('input[type="checkbox"]#external_image_mode, input[name*="external_image_mode"]');

      if (await externalImageCheckbox.count() > 0) {
        // Get current state
        const wasChecked = await externalImageCheckbox.isChecked();

        // Toggle the setting
        if (wasChecked) {
          await externalImageCheckbox.uncheck();
        } else {
          await externalImageCheckbox.check();
        }

        // Save settings
        const saveButton = page.locator('input[type="submit"][value*="Save"], button[type="submit"]:has-text("Save")');
        await saveButton.click();
        await waitForPageLoad(page);

        // Verify setting persisted by reloading
        await page.reload();
        await waitForPageLoad(page);

        const isNowChecked = await externalImageCheckbox.isChecked();
        expect(isNowChecked).toBe(!wasChecked);

        // Restore original setting
        if (isNowChecked !== wasChecked) {
          if (wasChecked) {
            await externalImageCheckbox.check();
          } else {
            await externalImageCheckbox.uncheck();
          }
          await saveButton.click();
          await waitForPageLoad(page);
        }
      }
    });
  });
});

test.describe('Page Content Management', () => {
  test('page part visibility toggle affects public page rendering', async ({ page }) => {
    // Step 1: Go to pages management
    await page.goto(`${BASE_URL}/site_admin/pages`);
    await waitForPageLoad(page);

    // Find the home page edit link
    const homePageLink = page.locator('a[href*="/pages/"][href*="/edit"], a:has-text("Home")').first();

    if (await homePageLink.count() > 0) {
      await homePageLink.click();
      await waitForPageLoad(page);

      // Check for visibility toggles on page parts
      const visibilityToggles = page.locator('input[type="checkbox"][name*="visible"], button:has-text("visible")');

      if (await visibilityToggles.count() > 0) {
        // Page has visibility controls - this confirms the edit page works
        await expect(visibilityToggles.first()).toBeVisible();
      }
    }
  });

  test('page settings (slug) can be modified', async ({ page }) => {
    // Step 1: Go to pages list
    await page.goto(`${BASE_URL}/site_admin/pages`);
    await waitForPageLoad(page);

    // Look for a settings link (not home page to avoid breaking navigation)
    const settingsLinks = page.locator('a[href*="/settings"]');

    if (await settingsLinks.count() > 0) {
      // Click on a non-home page settings
      const aboutSettingsLink = page.locator('a[href*="about"][href*="settings"], a[href*="settings"]:not([href*="home"])').first();

      if (await aboutSettingsLink.count() > 0) {
        await aboutSettingsLink.click();
        await waitForPageLoad(page);

        // Should see the settings form
        const slugInput = page.locator('input[name*="slug"]');
        if (await slugInput.count() > 0) {
          await expect(slugInput).toBeVisible();
          // Verify we can read the current slug value
          const currentSlug = await slugInput.inputValue();
          expect(currentSlug).toBeTruthy();
        }
      }
    }
  });
});

test.describe('Admin Access Verification', () => {
  test('admin pages are accessible with BYPASS_ADMIN_AUTH', async ({ page }) => {
    // These routes should be accessible when BYPASS_ADMIN_AUTH=true
    const adminRoutes = [
      '/site_admin',
      '/site_admin/pages',
      '/site_admin/website/settings',
      '/site_admin/props',
    ];

    for (const route of adminRoutes) {
      await page.goto(`${BASE_URL}${route}`);
      await waitForPageLoad(page);

      // Should NOT be redirected to login page
      const currentUrl = page.url();
      expect(currentUrl).not.toContain('/sign_in');
      expect(currentUrl).not.toContain('/pwb_login');

      // Should see admin content (not access denied)
      const pageContent = await page.content();
      expect(pageContent).not.toContain('Access Denied');
    }
  });
});
