// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToAdminPage, waitForPageLoad, fillField } = require('../fixtures/helpers');

/**
 * Onboarding Flow E2E Tests
 *
 * Tests the complete onboarding wizard for new site admins.
 * Covers all 5 steps: Welcome, Profile, Property, Theme, Complete
 *
 * NOTE: These tests require BYPASS_ADMIN_AUTH=true to be set.
 * Start server with: BYPASS_ADMIN_AUTH=true RAILS_ENV=e2e bin/rails server -p 3001
 */

// Skip: Onboarding wizard feature is not yet implemented
// These tests are for a planned multi-step onboarding flow
test.describe.skip('Site Admin Onboarding', () => {
  const tenant = TENANTS.A;

  test.describe('Step 1: Welcome', () => {
    test('displays welcome page with getting started message', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(1));

      // Should show welcome content
      await expect(page.locator('h1, h2').first()).toContainText(/welcome/i);

      // Should have a continue/next button
      const continueButton = page.locator('button:has-text("Continue"), input[type="submit"], a:has-text("Get Started")');
      await expect(continueButton.first()).toBeVisible();
    });

    test('can proceed to step 2', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(1));

      // Click continue button
      const continueButton = page.locator('button:has-text("Continue"), input[type="submit"], a:has-text("Get Started")');
      await continueButton.first().click();
      await waitForPageLoad(page);

      // Should be on step 2 (profile)
      const currentURL = page.url();
      expect(currentURL).toContain('step=2');
    });
  });

  test.describe('Step 2: Profile', () => {
    test('displays agency profile form', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(2));

      // Should show profile/agency form
      const pageContent = await page.content();
      const hasProfileContent = pageContent.includes('Profile') ||
                                 pageContent.includes('Agency') ||
                                 pageContent.includes('Company');
      expect(hasProfileContent).toBeTruthy();

      // Should have form fields
      const displayNameInput = page.locator('input[name*="display_name"], input[name*="company"]');
      await expect(displayNameInput.first()).toBeVisible();
    });

    test('has required agency fields', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(2));

      // Check for common agency fields
      const emailInput = page.locator('input[name*="email"], input[type="email"]');
      const phoneInput = page.locator('input[name*="phone"]');

      expect(await emailInput.count()).toBeGreaterThan(0);
      expect(await phoneInput.count()).toBeGreaterThan(0);
    });

    test('can fill and submit profile form', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(2));

      // Fill in agency details
      const displayNameInput = page.locator('input[name*="display_name"]');
      if (await displayNameInput.count() > 0) {
        await displayNameInput.first().fill('Test Real Estate Agency');
      }

      const emailInput = page.locator('input[name*="email_primary"], input[name*="email"]').first();
      if (await emailInput.isVisible()) {
        await emailInput.fill('test@agency.com');
      }

      const phoneInput = page.locator('input[name*="phone"]').first();
      if (await phoneInput.isVisible()) {
        await phoneInput.fill('+1 555-123-4567');
      }

      // Submit form
      const submitButton = page.locator('input[type="submit"], button[type="submit"]');
      await submitButton.first().click();
      await waitForPageLoad(page);

      // Should advance to step 3
      const currentURL = page.url();
      expect(currentURL).toContain('step=3');
    });

    test('has back button to return to step 1', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(2));

      const backButton = page.locator('a:has-text("Back"), button:has-text("Back")');
      await expect(backButton.first()).toBeVisible();
    });
  });

  test.describe('Step 3: Property', () => {
    test('displays property creation form', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(3));

      // Should show property form
      const pageContent = await page.content();
      const hasPropertyContent = pageContent.includes('Property') ||
                                  pageContent.includes('Listing') ||
                                  pageContent.includes('First');
      expect(hasPropertyContent).toBeTruthy();

      // Should have title field
      const titleInput = page.locator('input[name*="title"]');
      await expect(titleInput.first()).toBeVisible();
    });

    test('has property detail fields', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(3));

      // Check for property fields
      const bedroomsInput = page.locator('input[name*="bedroom"]');
      const bathroomsInput = page.locator('input[name*="bathroom"]');
      const cityInput = page.locator('input[name*="city"]');

      expect(await bedroomsInput.count()).toBeGreaterThan(0);
      expect(await bathroomsInput.count()).toBeGreaterThan(0);
      expect(await cityInput.count()).toBeGreaterThan(0);
    });

    test('can fill and submit property form', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(3));

      // Fill in property details
      await page.locator('input[name*="title"]').first().fill('Beautiful Test Property');

      const bedroomsInput = page.locator('input[name*="bedroom"]').first();
      if (await bedroomsInput.isVisible()) {
        await bedroomsInput.fill('3');
      }

      const bathroomsInput = page.locator('input[name*="bathroom"]').first();
      if (await bathroomsInput.isVisible()) {
        await bathroomsInput.fill('2');
      }

      const cityInput = page.locator('input[name*="city"]').first();
      if (await cityInput.isVisible()) {
        await cityInput.fill('Test City');
      }

      // Submit form
      const submitButton = page.locator('input[type="submit"], button[type="submit"]:has-text("Save")');
      await submitButton.first().click();
      await waitForPageLoad(page);

      // Should advance to step 4
      const currentURL = page.url();
      expect(currentURL).toContain('step=4');
    });

    test('has skip option for property step', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(3));

      // Should have skip button/link
      const skipButton = page.locator('a:has-text("Skip"), button:has-text("Skip")');
      await expect(skipButton.first()).toBeVisible();
    });

    test('can skip property step', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(3));

      // Click skip
      const skipButton = page.locator('a:has-text("Skip"), button:has-text("Skip")');
      await skipButton.first().click();
      await waitForPageLoad(page);

      // Should advance to step 4
      const currentURL = page.url();
      expect(currentURL).toContain('step=4');
    });
  });

  test.describe('Step 4: Theme', () => {
    test('displays theme selection', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(4));

      // Should show theme options
      const pageContent = await page.content();
      const hasThemeContent = pageContent.includes('Theme') ||
                               pageContent.includes('Design') ||
                               pageContent.includes('Look');
      expect(hasThemeContent).toBeTruthy();
    });

    test('shows available themes', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(4));

      // Should have theme options (cards, radio buttons, or similar)
      const themeOptions = page.locator('[data-theme], input[name*="theme"], .theme-card, .theme-option');
      expect(await themeOptions.count()).toBeGreaterThan(0);
    });

    test('can select a theme and continue', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(4));

      // Click on a theme option
      const themeOption = page.locator('[data-theme], input[name*="theme"], .theme-card, .theme-option').first();
      if (await themeOption.isVisible()) {
        await themeOption.click();
      }

      // Submit
      const submitButton = page.locator('input[type="submit"], button[type="submit"]');
      await submitButton.first().click();
      await waitForPageLoad(page);

      // Should advance to step 5
      const currentURL = page.url();
      expect(currentURL).toContain('step=5');
    });
  });

  test.describe('Step 5: Complete', () => {
    test('displays completion message', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(5));

      // Should show completion content
      const pageContent = await page.content();
      const hasCompleteContent = pageContent.includes('Complete') ||
                                  pageContent.includes('Done') ||
                                  pageContent.includes('Ready') ||
                                  pageContent.includes('Congratulations');
      expect(hasCompleteContent).toBeTruthy();
    });

    test('shows summary of setup', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(5));

      // Should show some stats or summary
      const pageContent = await page.content();
      const hasSummary = pageContent.includes('Properties') ||
                          pageContent.includes('Theme') ||
                          pageContent.includes('Pages');
      expect(hasSummary).toBeTruthy();
    });

    test('has link to dashboard', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(5));

      // Should have link to go to dashboard
      const dashboardLink = page.locator('a:has-text("Dashboard"), a:has-text("Get Started"), a[href*="site_admin"]');
      expect(await dashboardLink.count()).toBeGreaterThan(0);
    });

    test('has link to view website', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(5));

      // Should have link to view the live site
      const viewSiteLink = page.locator('a:has-text("View"), a:has-text("Website"), a[target="_blank"]');
      expect(await viewSiteLink.count()).toBeGreaterThan(0);
    });
  });

  test.describe('Progress Indicator', () => {
    test('shows progress on each step', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(2));

      // Should have some form of progress indicator
      const progressIndicator = page.locator('.progress, [role="progressbar"], .steps, .step-indicator, .stepper');
      const stepNumbers = page.locator(':text("Step"), :text("2 of"), :text("2/5")');

      const hasProgress = await progressIndicator.count() > 0 || await stepNumbers.count() > 0;
      expect(hasProgress).toBeTruthy();
    });
  });

  test.describe('Navigation', () => {
    test('can navigate between steps using back button', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(3));

      // Click back button
      const backButton = page.locator('a:has-text("Back"), button:has-text("Back")');
      await backButton.first().click();
      await waitForPageLoad(page);

      // Should be on step 2
      const currentURL = page.url();
      expect(currentURL).toContain('step=2');
    });

    test('maintains step state on page reload', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(3));

      // Reload the page
      await page.reload();
      await waitForPageLoad(page);

      // Should still show step 3 content (property form)
      const titleInput = page.locator('input[name*="title"]');
      await expect(titleInput.first()).toBeVisible();
    });
  });

  test.describe('Form Validation', () => {
    test('step 2 shows validation errors for empty required fields', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(2));

      // Clear any existing values and submit empty form
      const displayNameInput = page.locator('input[name*="display_name"]').first();
      if (await displayNameInput.isVisible()) {
        await displayNameInput.fill('');
      }

      // Submit empty form
      const submitButton = page.locator('input[type="submit"], button[type="submit"]');
      await submitButton.first().click();
      await waitForPageLoad(page);

      // Should either show validation errors or stay on same page
      const currentURL = page.url();
      const pageContent = await page.content();
      const hasError = pageContent.includes('error') ||
                        pageContent.includes('required') ||
                        pageContent.includes('Error') ||
                        currentURL.includes('step=2');
      expect(hasError).toBeTruthy();
    });
  });

  test.describe('Accessibility', () => {
    test('form fields have labels', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(3));

      // Check that inputs have associated labels
      const inputs = page.locator('input[type="text"], input[type="number"]');
      const inputCount = await inputs.count();

      // There should be labels for inputs
      const labels = page.locator('label');
      expect(await labels.count()).toBeGreaterThanOrEqual(inputCount * 0.5); // At least half should have labels
    });

    test('buttons have accessible text', async ({ page }) => {
      await goToAdminPage(page, tenant, ROUTES.ADMIN.ONBOARDING_STEP(1));

      // Action buttons should have text content
      const buttons = page.locator('button, input[type="submit"], a.btn, a[class*="button"]');
      const buttonCount = await buttons.count();

      for (let i = 0; i < buttonCount; i++) {
        const button = buttons.nth(i);
        const text = await button.textContent() || await button.getAttribute('value') || '';
        expect(text.trim().length).toBeGreaterThan(0);
      }
    });
  });
});
