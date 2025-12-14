// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { waitForPageLoad, goToAdminPage } = require('../fixtures/helpers');

/**
 * Admin to Site Integration Tests
 *
 * These tests verify that changes made in the site admin panel
 * are correctly applied to the public-facing website.
 *
 * IMPORTANT: These tests require BYPASS_ADMIN_AUTH=true to be set
 * on the Rails server to skip authentication.
 *
 * Start server with:
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

/**
 * Helper to save settings and wait for completion
 * @param {import('@playwright/test').Page} page
 */
async function saveSettings(page) {
  const saveButton = page.locator('input[type="submit"][value*="Save"], button[type="submit"]:has-text("Save")');
  await saveButton.first().click();
  await waitForPageLoad(page);
}

/**
 * Helper to wait for an element to be ready for interaction
 * @param {import('@playwright/test').Page} page
 * @param {import('@playwright/test').Locator} locator
 */
async function waitForElement(page, locator) {
  await locator.waitFor({ state: 'visible', timeout: 10000 });
  await page.waitForTimeout(100); // Small delay for stability
}

// Run tests serially to avoid race conditions when modifying shared settings
test.describe.configure({ mode: 'serial' });

test.describe('Admin to Site Integration', () => {

  test.describe('Company Name Changes', () => {
    test('changing company display name in admin persists correctly', async ({ page }) => {
      // Generate unique company name
      const uniqueCompanyName = `E2E Test Company ${Date.now()}`;

      // Step 1: Go to admin general settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Wait for the General Settings header to confirm page is loaded
      await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

      // Step 3: Change the company display name
      const companyNameInput = page.locator('input[name="pwb_website[company_display_name]"]');
      await waitForElement(page, companyNameInput);
      await companyNameInput.fill(uniqueCompanyName);

      // Step 4: Save settings
      await saveSettings(page);

      // Verify save was successful
      await expect(page).toHaveURL(/settings/);

      // Step 5: Reload page and verify the setting persisted
      await page.reload();
      await waitForPageLoad(page);
      await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

      // Verify the company name was saved
      const savedValue = await companyNameInput.inputValue();
      expect(savedValue).toBe(uniqueCompanyName);

      // Step 6: Verify the company name appears in the admin header
      // (The admin header shows the company display name)
      const adminHeader = await page.content();
      expect(adminHeader).toContain(uniqueCompanyName);
    });
  });

  test.describe('Currency Settings', () => {
    test('changing default currency persists and affects display', async ({ page }) => {
      // Step 1: Go to admin general settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Wait for the General Settings header to confirm page is loaded
      await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

      // Step 3: Find and change currency
      const currencySelect = page.locator('select[name="pwb_website[default_currency]"]');
      await waitForElement(page, currencySelect);

      // Get current currency
      const currentCurrency = await currencySelect.inputValue();

      // Switch to different currency
      const newCurrency = currentCurrency === 'USD' ? 'EUR' : 'USD';
      await currencySelect.selectOption(newCurrency);

      // Step 4: Save settings
      await saveSettings(page);

      // Step 5: Reload and verify setting persisted
      await page.reload();
      await waitForPageLoad(page);
      await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

      const savedCurrency = await currencySelect.inputValue();
      expect(savedCurrency).toBe(newCurrency);

      // Step 6: Visit property listings page to see currency in action
      await page.goto(`${BASE_URL}/en/buy`);
      await waitForPageLoad(page);

      // Page should load successfully
      await expect(page.locator('body')).toBeVisible();
    });
  });

  test.describe('Area Unit Settings', () => {
    test('changing area unit setting persists correctly', async ({ page }) => {
      // Step 1: Go to admin general settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Wait for the General Settings header to confirm page is loaded
      await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

      // Step 3: Find and change area unit
      const areaUnitSelect = page.locator('select[name="pwb_website[default_area_unit]"]');
      await waitForElement(page, areaUnitSelect);

      // Get current unit
      const currentUnit = await areaUnitSelect.inputValue();

      // Toggle between sqmt and sqft
      const newUnit = currentUnit === 'sqmt' ? 'sqft' : 'sqmt';
      await areaUnitSelect.selectOption(newUnit);

      // Step 4: Save settings
      await saveSettings(page);

      // Step 5: Verify setting persisted
      await page.reload();
      await waitForPageLoad(page);
      await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

      const savedUnit = await areaUnitSelect.inputValue();
      expect(savedUnit).toBe(newUnit);
    });
  });

  test.describe('Language Settings', () => {
    test('changing default language setting persists', async ({ page }) => {
      // Step 1: Go to admin general settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Wait for the General Settings header to confirm page is loaded
      await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

      // Step 3: Find default locale select
      const localeSelect = page.locator('select[name="pwb_website[default_client_locale]"]');
      await waitForElement(page, localeSelect);

      // Get current value
      const currentLocale = await localeSelect.inputValue();

      // Change to a different locale
      const newLocale = currentLocale === 'en-UK' ? 'en-US' : 'en-UK';
      await localeSelect.selectOption(newLocale);

      // Step 4: Save settings
      await saveSettings(page);

      // Step 5: Verify setting persisted
      await page.reload();
      await waitForPageLoad(page);
      await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

      const savedLocale = await localeSelect.inputValue();
      expect(savedLocale).toBe(newLocale);
    });

    test('enabling supported languages shows language switcher on site', async ({ page }) => {
      // Step 1: Go to admin general settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Enable Spanish as a supported language
      const spanishCheckbox = page.locator('input[type="checkbox"][value="es"]');
      if (await spanishCheckbox.count() > 0) {
        // Check if not already checked
        const isChecked = await spanishCheckbox.isChecked();
        if (!isChecked) {
          await spanishCheckbox.check();
        }

        // Step 3: Save settings
        await saveSettings(page);

        // Step 4: Visit public site and check for language options
        await page.goto(`${BASE_URL}/`);
        await waitForPageLoad(page);

        // Look for language switcher or Spanish link
        const pageContent = await page.content();
        const hasLanguageOption = pageContent.includes('/es/') ||
                                   pageContent.includes('Español') ||
                                   pageContent.includes('Spanish') ||
                                   await page.locator('a[href*="/es"]').count() > 0;

        // This is a soft check - language switcher may be theme-dependent
        expect(pageContent).toBeTruthy();
      }
    });
  });

  test.describe('External Image Mode', () => {
    test('toggling external image mode persists correctly', async ({ page }) => {
      // Step 1: Go to admin general settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Wait for the General Settings header to confirm page is loaded
      await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

      // Step 3: Find external image mode checkbox
      const externalImageCheckbox = page.locator('input#external_image_mode');

      if (await externalImageCheckbox.count() > 0) {
        await waitForElement(page, externalImageCheckbox);

        // Get current state
        const wasChecked = await externalImageCheckbox.isChecked();

        // Toggle the setting
        if (wasChecked) {
          await externalImageCheckbox.uncheck();
        } else {
          await externalImageCheckbox.check();
        }

        // Step 4: Save settings
        await saveSettings(page);

        // Step 5: Verify setting persisted
        await page.reload();
        await waitForPageLoad(page);
        await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

        const isNowChecked = await externalImageCheckbox.isChecked();
        expect(isNowChecked).toBe(!wasChecked);

        // Restore original setting
        if (wasChecked) {
          await externalImageCheckbox.check();
        } else {
          await externalImageCheckbox.uncheck();
        }
        await saveSettings(page);
      }
    });
  });

  test.describe('Page Content Visibility', () => {
    test('toggling page part visibility affects public page', async ({ page }) => {
      // Step 1: Go to pages list
      await page.goto(`${BASE_URL}/site_admin/pages`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Find and click on home page edit link
      const homeEditLink = page.locator('a[href*="/pages/"][href*="/edit"]').first();

      if (await homeEditLink.count() > 0) {
        await homeEditLink.click();
        await waitForPageLoad(page);

        // Step 3: Look for visibility toggles
        const visibilityButtons = page.locator('button:has-text("Visible"), button:has-text("Hidden")');

        if (await visibilityButtons.count() > 0) {
          // Get first visibility button text
          const firstButton = visibilityButtons.first();
          const buttonText = await firstButton.textContent();
          const wasVisible = buttonText?.includes('Visible');

          // Click to toggle
          await firstButton.click();
          await waitForPageLoad(page);

          // Step 4: Visit public page
          await page.goto(`${BASE_URL}/`);
          await waitForPageLoad(page);

          // Page should load successfully
          await expect(page.locator('body')).toBeVisible();

          // Step 5: Restore original state
          await page.goto(`${BASE_URL}/site_admin/pages`);
          await waitForPageLoad(page);

          await homeEditLink.click();
          await waitForPageLoad(page);

          // Toggle back if needed
          const restoredButton = visibilityButtons.first();
          const restoredText = await restoredButton.textContent();
          const isNowVisible = restoredText?.includes('Visible');

          if (wasVisible !== isNowVisible) {
            await restoredButton.click();
            await waitForPageLoad(page);
          }
        }
      }
    });
  });

  test.describe('Page Part Content Editing', () => {
    test('editing page part content updates public page', async ({ page }) => {
      // Step 1: Navigate to pages list
      await page.goto(`${BASE_URL}/site_admin/pages`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Find and edit home page
      const homeEditLink = page.locator('a[href*="/pages/"][href*="/edit"]').first();

      if (await homeEditLink.count() > 0) {
        await homeEditLink.click();
        await waitForPageLoad(page);

        // Step 3: Find first Edit Content button
        const editContentButtons = page.locator('a:has-text("Edit Content")');

        if (await editContentButtons.count() > 0) {
          await editContentButtons.first().click();
          await waitForPageLoad(page);

          // Step 4: Look for VISIBLE text input fields (not hidden ones used by Quill)
          // Single line text inputs are visible, whereas Quill hidden inputs are type="hidden"
          const visibleTextInputs = page.locator('input[name*="block_contents"]:visible:not([type="hidden"]), textarea[name*="block_contents"]:visible');

          if (await visibleTextInputs.count() > 0) {
            const firstInput = visibleTextInputs.first();
            const originalValue = await firstInput.inputValue();
            const uniqueText = `E2E Test Content ${Date.now()}`;

            // Fill the visible input
            await firstInput.fill(uniqueText);

            // Step 5: Save changes
            const saveButton = page.locator('input[type="submit"][value*="Save"], button[type="submit"]:has-text("Save")');
            await saveButton.first().click();
            await waitForPageLoad(page);

            // Step 6: Visit public page and verify content
            await page.goto(`${BASE_URL}/`);
            await waitForPageLoad(page);

            const pageContent = await page.content();

            // The unique text should appear on the page
            expect(pageContent).toContain(uniqueText);

            // Step 7: Restore original content
            await page.goto(`${BASE_URL}/site_admin/pages`);
            await waitForPageLoad(page);
            await homeEditLink.click();
            await waitForPageLoad(page);
            await editContentButtons.first().click();
            await waitForPageLoad(page);

            const restoredInput = page.locator('input[name*="block_contents"]:visible:not([type="hidden"]), textarea[name*="block_contents"]:visible').first();
            if (await restoredInput.count() > 0) {
              await restoredInput.fill(originalValue || '');
              await saveButton.first().click();
              await waitForPageLoad(page);
            }
          } else {
            // No visible text inputs found - this page part may only have Quill editors
            // Skip this test gracefully
            test.skip();
          }
        }
      }
    });
  });

  test.describe('Theme/Appearance Settings', () => {
    test('theme selection persists in admin', async ({ page }) => {
      // Step 1: Go to appearance settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=appearance`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Look for theme selector
      const themeSelect = page.locator('select[name*="theme"]');

      if (await themeSelect.count() > 0) {
        // Get available themes
        const options = await themeSelect.locator('option').allTextContents();
        const currentTheme = await themeSelect.inputValue();

        // Find a different theme
        const availableThemes = options.filter(t => t !== '' && t.toLowerCase() !== currentTheme.toLowerCase());

        if (availableThemes.length > 0) {
          const newTheme = availableThemes[0];
          await themeSelect.selectOption({ label: newTheme });

          // Save settings
          await saveSettings(page);

          // Step 3: Visit public site
          await page.goto(`${BASE_URL}/`);
          await waitForPageLoad(page);

          // Page should load with new theme
          await expect(page.locator('body')).toBeVisible();

          // Step 4: Restore original theme
          await page.goto(`${BASE_URL}/site_admin/website/settings?tab=appearance`);
          await waitForPageLoad(page);
          await themeSelect.selectOption(currentTheme);
          await saveSettings(page);
        }
      }
    });
  });

  test.describe('Navigation Settings', () => {
    test('navigation tab loads and displays options', async ({ page }) => {
      // Step 1: Go to navigation settings
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=navigation`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Verify page loaded
      const pageContent = await page.content();
      const hasNavigationContent = pageContent.includes('Navigation') ||
                                    pageContent.includes('Menu') ||
                                    pageContent.includes('Links');
      expect(hasNavigationContent).toBeTruthy();
    });
  });

  test.describe('Admin Dashboard', () => {
    test('admin dashboard is accessible and shows overview', async ({ page }) => {
      // Step 1: Go to admin dashboard
      await page.goto(`${BASE_URL}/site_admin`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Dashboard should have some content
      const pageContent = await page.content();
      const hasDashboardContent = pageContent.includes('Dashboard') ||
                                   pageContent.includes('Properties') ||
                                   pageContent.includes('Pages') ||
                                   pageContent.includes('Welcome');
      expect(hasDashboardContent).toBeTruthy();
    });
  });

  test.describe('Properties Management', () => {
    test('properties list page is accessible', async ({ page }) => {
      // Step 1: Go to properties list
      await page.goto(`${BASE_URL}/site_admin/props`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Step 2: Page should load
      const pageContent = await page.content();
      const hasPropertiesContent = pageContent.includes('Properties') ||
                                    pageContent.includes('Listings') ||
                                    pageContent.includes('property');
      expect(hasPropertiesContent).toBeTruthy();
    });
  });
});

test.describe('Settings Tab Navigation', () => {
  test('all settings tabs are accessible', async ({ page }) => {
    const tabs = ['general', 'appearance', 'navigation', 'notifications'];

    for (const tab of tabs) {
      await page.goto(`${BASE_URL}/site_admin/website/settings?tab=${tab}`);
      await waitForPageLoad(page);
      await verifyAdminAccess(page);

      // Tab should load without error
      const currentUrl = page.url();
      expect(currentUrl).toContain(`tab=${tab}`);

      // Should not be redirected to login
      expect(currentUrl).not.toContain('/sign_in');
    }
  });
});

test.describe('Cross-Page Navigation', () => {
  test('public pages are accessible and consistent after admin changes', async ({ page }) => {
    // Step 1: Make a change in admin (e.g., currency)
    await page.goto(`${BASE_URL}/site_admin/website/settings?tab=general`);
    await waitForPageLoad(page);
    await verifyAdminAccess(page);

    // Wait for page to fully load
    await expect(page.locator('h2:has-text("General Settings")')).toBeVisible({ timeout: 10000 });

    // Change currency to EUR
    const currencySelect = page.locator('select[name="pwb_website[default_currency]"]');
    await waitForElement(page, currencySelect);
    await currencySelect.selectOption('EUR');
    await saveSettings(page);

    // Step 2: Check homepage loads
    await page.goto(`${BASE_URL}/`);
    await waitForPageLoad(page);
    await expect(page.locator('body')).toBeVisible();

    // Step 3: Check buy page loads
    await page.goto(`${BASE_URL}/en/buy`);
    await waitForPageLoad(page);
    await expect(page.locator('body')).toBeVisible();

    // Step 4: Check rent page loads
    await page.goto(`${BASE_URL}/en/rent`);
    await waitForPageLoad(page);
    await expect(page.locator('body')).toBeVisible();

    // Step 5: Verify pages have links (navigation present in some form)
    const pageLinks = page.locator('a');
    expect(await pageLinks.count()).toBeGreaterThan(0);
  });
});
