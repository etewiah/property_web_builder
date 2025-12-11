// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToTenant } = require('../fixtures/helpers');

/**
 * Property Search Tests
 * Migrated from: spec/features/pwb/property_search_spec.rb
 *
 * US-1.2: Search Properties with Filters
 * As a public visitor, I want to filter properties by various criteria
 * So that I can narrow down my search to relevant listings
 */

test.describe('Property Search', () => {
  const tenant = TENANTS.A;

  test.describe('Sale Search Page', () => {
    test('displays search filters', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // The buy page should have a search form with filters
      const pageContent = await page.content();
      const hasSearchOrFilter = pageContent.includes('Search') || pageContent.includes('Filter');
      const hasPrice = pageContent.includes('Price');

      expect(hasSearchOrFilter).toBeTruthy();
      expect(hasPrice).toBeTruthy();
    });

    test('has property type filter', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // Should have property type filter
      const pageContent = await page.content();
      const hasPropertyType = pageContent.includes('Property Type') || pageContent.includes('Type');

      expect(hasPropertyType).toBeTruthy();
    });

    test('has bedroom filter', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // Should have bedroom filter
      const pageContent = await page.content();
      const hasBedroom = pageContent.toLowerCase().includes('bedroom');

      expect(hasBedroom).toBeTruthy();
    });
  });

  test.describe('Rental Search Page', () => {
    test('displays rental-specific filters', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      // The rent page should have rental-specific filters
      const pageContent = await page.content();
      const hasRent = pageContent.includes('Rent');
      const hasSearchOrFilter = pageContent.includes('Search') || pageContent.includes('Filter');

      expect(hasRent).toBeTruthy();
      expect(hasSearchOrFilter).toBeTruthy();
    });

    test('shows rental terminology', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      // Rental page should have monthly rent terminology
      const pageContent = await page.content().then(c => c.toLowerCase());
      expect(pageContent).toContain('rent');
    });
  });

  test.describe('Search Form Structure', () => {
    test('buy page has submit button', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // Should have a search/submit button
      const searchButton = page.locator('button:has-text("Search"), input[type="submit"], button[type="submit"]');
      expect(await searchButton.count()).toBeGreaterThan(0);
    });

    test('rent page has submit button', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      // Should have a search/submit button
      const searchButton = page.locator('button:has-text("Search"), input[type="submit"], button[type="submit"]');
      expect(await searchButton.count()).toBeGreaterThan(0);
    });
  });
});
