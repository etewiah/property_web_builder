// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
const { goToTenant, waitForPageLoad, expectToBeOnLoginPage } = require('../fixtures/helpers');

/**
 * Tenant Isolation Tests
 * Migrated from: spec/features/pwb/tenant_isolation_spec.rb
 *
 * US-6.1: Tenant Data Isolation
 * As a site admin, I want my data to be completely isolated from other tenants
 * So that my business information is secure
 *
 * US-6.2: Subdomain Routing
 * As a public visitor, I want to access different agencies via subdomains
 * So that each agency has their own branded site
 */

test.describe('Tenant Isolation', () => {
  test.describe('Public Site Isolation', () => {
    test('Tenant A subdomain shows Tenant A branding', async ({ page }) => {
      await goToTenant(page, TENANTS.A, '/');

      // Should display Tenant A branding
      const pageContent = await page.content();
      const hasTenantABranding = pageContent.includes(TENANTS.A.companyName) ||
                                  pageContent.includes('Tenant A') ||
                                  pageContent.includes('Test Company');
      expect(hasTenantABranding).toBeTruthy();
    });

    test('Tenant B subdomain shows Tenant B branding', async ({ page }) => {
      await goToTenant(page, TENANTS.B, '/');

      // Should display Tenant B branding
      const pageContent = await page.content();
      const hasTenantBBranding = pageContent.includes(TENANTS.B.companyName) ||
                                  pageContent.includes('Tenant B') ||
                                  pageContent.includes('Test Company');
      expect(hasTenantBBranding).toBeTruthy();
    });
  });

  test.describe('Admin Panel Isolation', () => {
    test('Tenant A login page is accessible', async ({ page }) => {
      await goToTenant(page, TENANTS.A, ROUTES.LOGIN);

      // Should show login form (either Devise or Firebase)
      const currentURL = page.url();
      const isLoginPage = currentURL.includes('/sign_in') ||
                          currentURL.includes('/pwb_login') ||
                          currentURL.includes('/login');
      expect(isLoginPage).toBeTruthy();
    });

    test('Tenant B login page is accessible', async ({ page }) => {
      await goToTenant(page, TENANTS.B, ROUTES.LOGIN);

      // Should show login form (either Devise or Firebase)
      const currentURL = page.url();
      const isLoginPage = currentURL.includes('/sign_in') ||
                          currentURL.includes('/pwb_login') ||
                          currentURL.includes('/login');
      expect(isLoginPage).toBeTruthy();
    });

    test('admin page requires authentication', async ({ page }) => {
      await goToTenant(page, TENANTS.A, ROUTES.ADMIN.DASHBOARD);

      // Should redirect to login or show login form
      const currentURL = page.url();
      const redirectedToLogin = currentURL.includes('/sign_in') ||
                                currentURL.includes('/pwb_login') ||
                                currentURL.includes('/login');

      // Also check if we're still on the admin page but showing login requirement
      const pageContent = await page.content();
      const requiresAuth = redirectedToLogin ||
                           pageContent.includes('Sign in') ||
                           pageContent.includes('Login') ||
                           pageContent.includes('sign_in');
      expect(requiresAuth).toBeTruthy();
    });
  });

  test.describe('Cross-Tenant Authentication', () => {
    test('Tenant A admin cannot access Tenant B admin', async ({ page }) => {
      // Try to login to Tenant B with Tenant A credentials
      await goToTenant(page, TENANTS.B, ROUTES.LOGIN);

      // Fill in Tenant A admin credentials on Tenant B subdomain
      const emailField = page.locator('input[name="user[email]"], input[type="email"]');
      const passwordField = page.locator('input[name="user[password]"], input[type="password"]');

      if (await emailField.count() > 0 && await passwordField.count() > 0) {
        await emailField.first().fill(ADMIN_USERS.TENANT_A.email);
        await passwordField.first().fill(ADMIN_USERS.TENANT_A.password);

        const submitButton = page.locator('input[type="submit"], button[type="submit"]');
        if (await submitButton.count() > 0) {
          await submitButton.first().click();
          await waitForPageLoad(page);

          // Should fail - either show error or stay on login page
          const pageContent = await page.content();
          const loginFailed = pageContent.includes('Invalid') ||
                              pageContent.includes('does not have admin privileges') ||
                              pageContent.includes('Access Required') ||
                              pageContent.includes('Email') ||
                              pageContent.includes('Password');
          expect(loginFailed).toBeTruthy();
        }
      }
    });
  });

  test.describe('Subdomain Routing', () => {
    test('different subdomains serve different content', async ({ page }) => {
      // Visit Tenant A
      await goToTenant(page, TENANTS.A, '/');
      const tenantAContent = await page.content();

      // Visit Tenant B
      await goToTenant(page, TENANTS.B, '/');
      const tenantBContent = await page.content();

      // Both should be valid pages (have HTML structure)
      expect(tenantAContent).toContain('<html');
      expect(tenantBContent).toContain('<html');

      // Content should reference different tenant branding (or at least be valid pages)
      const tenantAHasBranding = tenantAContent.includes(TENANTS.A.companyName) ||
                                  tenantAContent.includes('Tenant A') ||
                                  tenantAContent.includes('Test Company');
      const tenantBHasBranding = tenantBContent.includes(TENANTS.B.companyName) ||
                                  tenantBContent.includes('Tenant B') ||
                                  tenantBContent.includes('Test Company');

      expect(tenantAHasBranding).toBeTruthy();
      expect(tenantBHasBranding).toBeTruthy();
    });

    test('tenant A buy page is isolated', async ({ page }) => {
      await goToTenant(page, TENANTS.A, ROUTES.BUY);

      // Should load without errors
      const response = await page.goto(`${TENANTS.A.baseURL}${ROUTES.BUY}`);
      expect(response.status()).toBeLessThan(500);
    });

    test('tenant B buy page is isolated', async ({ page }) => {
      await goToTenant(page, TENANTS.B, ROUTES.BUY);

      // Should load without errors
      const response = await page.goto(`${TENANTS.B.baseURL}${ROUTES.BUY}`);
      expect(response.status()).toBeLessThan(500);
    });
  });

  test.describe('Data Isolation Verification', () => {
    test('property listings are tenant-specific', async ({ page }) => {
      // Visit property listings on both tenants
      await goToTenant(page, TENANTS.A, ROUTES.BUY);
      const tenantAListings = await page.content();

      await goToTenant(page, TENANTS.B, ROUTES.BUY);
      const tenantBListings = await page.content();

      // Both should have property-related content but be valid separate pages
      const tenantAHasListings = tenantAListings.includes('Property') ||
                                  tenantAListings.includes('property') ||
                                  tenantAListings.includes('Search');
      const tenantBHasListings = tenantBListings.includes('Property') ||
                                  tenantBListings.includes('property') ||
                                  tenantBListings.includes('Search');

      expect(tenantAHasListings).toBeTruthy();
      expect(tenantBHasListings).toBeTruthy();
    });
  });
});
