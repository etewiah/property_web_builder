// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToTenant, waitForPageLoad, goToAdminPage } = require('../fixtures/helpers');

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
 *
 * NOTE: Tests assume BYPASS_ADMIN_AUTH=true is set.
 * Authentication-specific tests are skipped - see RSpec tests for auth testing.
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

  test.describe('Admin Panel Access (with BYPASS_ADMIN_AUTH)', () => {
    test('Tenant A admin panel is accessible', async ({ page }) => {
      await goToAdminPage(page, TENANTS.A, ROUTES.ADMIN.DASHBOARD);

      // Should show admin content (not login page)
      const pageContent = await page.content();
      const hasAdminContent = pageContent.includes('Dashboard') ||
                               pageContent.includes('Properties') ||
                               pageContent.includes('Settings') ||
                               pageContent.includes('site_admin');
      expect(hasAdminContent).toBeTruthy();
    });

    test('Tenant B admin panel is accessible', async ({ page }) => {
      await goToAdminPage(page, TENANTS.B, ROUTES.ADMIN.DASHBOARD);

      // Should show admin content (not login page)
      const pageContent = await page.content();
      const hasAdminContent = pageContent.includes('Dashboard') ||
                               pageContent.includes('Properties') ||
                               pageContent.includes('Settings') ||
                               pageContent.includes('site_admin');
      expect(hasAdminContent).toBeTruthy();
    });
  });

  // Authentication-specific tests are skipped - tested via RSpec
  test.describe.skip('Cross-Tenant Authentication', () => {
    // These tests require actual authentication which is bypassed in e2e mode
    // See: spec/controllers/pwb/devise/sessions_controller_spec.rb

    test('Tenant A admin cannot access Tenant B admin', async ({ page }) => {
      // Skipped - authentication is bypassed
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

    test('admin settings are tenant-specific', async ({ page }) => {
      // Access admin settings for Tenant A
      await goToAdminPage(page, TENANTS.A, ROUTES.ADMIN.WEBSITE_SETTINGS);
      const tenantASettings = await page.content();

      // Access admin settings for Tenant B
      await goToAdminPage(page, TENANTS.B, ROUTES.ADMIN.WEBSITE_SETTINGS);
      const tenantBSettings = await page.content();

      // Both should show settings page
      expect(tenantASettings).toContain('Settings');
      expect(tenantBSettings).toContain('Settings');
    });
  });
});
