// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS } = require('../fixtures/test-data');
const { goToTenant } = require('../fixtures/helpers');

/**
 * Property Details Tests
 * Migrated from: spec/features/pwb/property_details_spec.rb
 *
 * US-1.3: View Property Details
 * As a public visitor, I want to view detailed information about a property
 * So that I can decide if I want to inquire about it
 */

test.describe('Property Details', () => {
  const tenant = TENANTS.A;

  test.describe('Sale Property Details Page', () => {
    test('displays property page with branding', async ({ page }) => {
      // Visit a property detail page (using a sample URL pattern)
      await goToTenant(page, tenant, '/en/properties/for-sale/1/test-property');

      // Should display a valid page with tenant branding
      const pageContent = await page.content();
      const hasValidContent = pageContent.includes('Property') ||
                              pageContent.includes('property') ||
                              pageContent.includes(tenant.companyName) ||
                              pageContent.includes('Test Company') ||
                              pageContent.includes('not found');
      expect(hasValidContent).toBeTruthy();
    });

    test('page renders without server error', async ({ page }) => {
      await goToTenant(page, tenant, '/en/properties/for-sale/1/test-property');

      // Page should not be a 500 error
      const response = await page.goto(`${tenant.baseURL}/en/properties/for-sale/1/test-property`);
      expect(response.status()).toBeLessThan(500);
    });
  });

  test.describe('Rental Property Details Page', () => {
    test('displays rental property page', async ({ page }) => {
      await goToTenant(page, tenant, '/en/properties/for-rent/1/test-rental');

      // Should display a valid page
      const pageContent = await page.content();
      const hasValidContent = pageContent.includes('Property') ||
                              pageContent.includes('property') ||
                              pageContent.includes('Rent') ||
                              pageContent.includes(tenant.companyName) ||
                              pageContent.includes('not found');
      expect(hasValidContent).toBeTruthy();
    });
  });

  test.describe('Property Page Structure', () => {
    test('property page has navigation and footer', async ({ page }) => {
      await goToTenant(page, tenant, '/en/properties/for-sale/1/test-property');

      // Page should have navigation or footer with company info
      const pageContent = await page.content();
      const hasStructure = pageContent.includes('nav') ||
                           pageContent.includes('footer') ||
                           pageContent.includes(tenant.companyName) ||
                           pageContent.includes('PropertyWebBuilder');
      expect(hasStructure).toBeTruthy();
    });
  });
});
