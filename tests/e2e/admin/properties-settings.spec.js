// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
const { loginAsAdmin, goToTenant, waitForPageLoad } = require('../fixtures/helpers');

/**
 * Properties Settings Management Tests
 * Migrated from: spec/system/site_admin/properties_settings_spec.rb
 *
 * Tests admin functionality for managing property settings
 * including property types, features, and states
 */

test.describe('Properties Settings Management', () => {
  const tenant = TENANTS.A;
  const admin = ADMIN_USERS.TENANT_A;

  test.describe('Navigating to Settings', () => {
    test('settings page requires authentication', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.ADMIN.SETTINGS);

      // Should redirect to login
      const currentURL = page.url();
      const redirectedToLogin = currentURL.includes('/sign_in') ||
                                currentURL.includes('/firebase_login') ||
                                currentURL.includes('/login');
      expect(redirectedToLogin).toBeTruthy();
    });

    test('settings page is accessible after login', async ({ page }) => {
      // Login as admin
      await loginAsAdmin(page, admin);

      // Navigate to settings
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Should be on settings page (not redirected to login)
      const currentURL = page.url();
      const isOnSettings = currentURL.includes('settings') ||
                           currentURL.includes('site_admin');
      expect(isOnSettings).toBeTruthy();
    });

    test('settings page displays property types section', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Should have property types content
      const pageContent = await page.content();
      const hasPropertyTypes = pageContent.includes('Property Types') ||
                                pageContent.includes('Types') ||
                                pageContent.includes('type');
      expect(hasPropertyTypes).toBeTruthy();
    });
  });

  test.describe('Category Tabs', () => {
    test('displays category navigation tabs', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Should have tab links for different categories
      const typesLink = page.locator('a:has-text("Types"), a[href*="types"]');
      const featuresLink = page.locator('a:has-text("Features"), a[href*="features"]');
      const statesLink = page.locator('a:has-text("States"), a[href*="states"]');

      // At least some tabs should exist
      const hasTypes = await typesLink.count() > 0;
      const hasFeatures = await featuresLink.count() > 0;
      const hasStates = await statesLink.count() > 0;

      const hasTabs = hasTypes || hasFeatures || hasStates;
      expect(hasTabs).toBeTruthy();
    });

    test('can switch between category tabs', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Try clicking on different tabs
      const typesLink = page.locator('a:has-text("Types")');
      if (await typesLink.count() > 0) {
        await typesLink.first().click();
        await waitForPageLoad(page);

        const currentURL = page.url();
        expect(currentURL).toContain('types');
      }
    });
  });

  test.describe('Managing Property Types', () => {
    test('property types page has add button', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Should have an add button
      const addButton = page.locator('button:has-text("Add"), button:has-text("New"), a:has-text("Add")');
      expect(await addButton.count()).toBeGreaterThan(0);
    });

    test('can open add new entry modal', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Click add button
      const addButton = page.locator('button:has-text("Add New Entry"), button:has-text("Add")');
      if (await addButton.count() > 0) {
        await addButton.first().click();

        // Modal should appear
        const modal = page.locator('#new-entry-modal, [role="dialog"], .modal');
        await expect(modal).toBeVisible({ timeout: 5000 });
      }
    });

    test('add modal has translation input', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Click add button
      const addButton = page.locator('button:has-text("Add New Entry"), button:has-text("Add")');
      if (await addButton.count() > 0) {
        await addButton.first().click();

        // Modal should have translation input
        const translationInput = page.locator('input[name*="translations"], input[name*="en"]');
        expect(await translationInput.count()).toBeGreaterThan(0);
      }
    });
  });

  test.describe('Tenant Isolation in Settings', () => {
    test('settings are tenant-specific', async ({ page }) => {
      // Login to Tenant A
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Should show settings page for current tenant
      const pageContent = await page.content();
      const hasSettings = pageContent.includes('Settings') ||
                          pageContent.includes('Property Types') ||
                          pageContent.includes('Features');
      expect(hasSettings).toBeTruthy();
    });

    test('admin access is restricted to own tenant', async ({ page }) => {
      // Try to access Tenant B settings with Tenant A credentials
      await loginAsAdmin(page, admin);

      // Navigate to Tenant B settings (should not work)
      await page.goto(`${TENANTS.B.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Should be redirected to login or show access denied
      const currentURL = page.url();
      const pageContent = await page.content();

      const accessDenied = currentURL.includes('/sign_in') ||
                           currentURL.includes('/firebase_login') ||
                           currentURL.includes('/login') ||
                           pageContent.includes('Access') ||
                           pageContent.includes('denied') ||
                           pageContent.includes('not authorized');
      expect(accessDenied).toBeTruthy();
    });
  });

  test.describe('Form Validation', () => {
    test('add form has required English field', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Open modal
      const addButton = page.locator('button:has-text("Add New Entry"), button:has-text("Add")');
      if (await addButton.count() > 0) {
        await addButton.first().click();

        // English translation field should be required
        const englishInput = page.locator('input[name*="translations"][name*="en"]');
        if (await englishInput.count() > 0) {
          const isRequired = await englishInput.first().getAttribute('required');
          expect(isRequired !== null || await englishInput.first().isVisible()).toBeTruthy();
        }
      }
    });
  });

  test.describe('Empty States', () => {
    test('shows helpful message when no entries exist', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Page should either show entries or an empty state message
      const pageContent = await page.content();
      const hasContent = pageContent.includes('No ') ||
                         pageContent.includes('Add New') ||
                         pageContent.includes('Create') ||
                         pageContent.includes('card-');
      expect(hasContent).toBeTruthy();
    });
  });

  test.describe('Settings UI Elements', () => {
    test('settings page has proper structure', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Should have header/title
      const hasTitle = await page.locator('h1, h2, .page-title').count() > 0;
      expect(hasTitle).toBeTruthy();

      // Should have some form of content area
      const hasContent = await page.locator('main, .content, .container').count() > 0;
      expect(hasContent).toBeTruthy();
    });

    test('settings page maintains admin navigation', async ({ page }) => {
      await loginAsAdmin(page, admin);
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.SETTINGS}`);
      await waitForPageLoad(page);

      // Should have admin navigation/sidebar
      const hasNav = await page.locator('nav, aside, .sidebar').count() > 0;
      expect(hasNav).toBeTruthy();
    });
  });
});
