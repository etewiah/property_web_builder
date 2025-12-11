// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToTenant, waitForPageLoad } = require('../fixtures/helpers');

/**
 * Property Browsing Tests
 * Migrated from: spec/features/pwb/property_browsing_spec.rb
 *
 * US-1.1: View Property Listings
 * As a public visitor, I want to browse available properties
 * So that I can find properties that interest me
 */

test.describe('Property Browsing', () => {
  const tenant = TENANTS.A;

  test.describe('Sale Properties Page', () => {
    test('displays search filters for sale properties', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // The buy page should have a search form with price filters
      const pageContent = await page.content();
      const hasSearchOrFilter = pageContent.includes('Search') || pageContent.includes('Filter');
      const hasPrice = pageContent.includes('Price');

      expect(hasSearchOrFilter).toBeTruthy();
      expect(hasPrice).toBeTruthy();
    });

    test('can access property listing page', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // Page should load without errors
      await expect(page).toHaveURL(/\/en\/buy/);

      // Should have some content indicating it's a property listing page
      const pageContent = await page.content();
      const hasPropertyContent = pageContent.includes('Property') ||
                                  pageContent.includes('property') ||
                                  pageContent.includes('Search') ||
                                  pageContent.includes('Filter');
      expect(hasPropertyContent).toBeTruthy();
    });
  });

  test.describe('Rental Properties Page', () => {
    test('displays search filters for rental properties', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      // The rent page should have rental-specific filters
      const pageContent = await page.content();
      const hasSearchOrFilter = pageContent.includes('Search') || pageContent.includes('Filter');
      const hasRent = pageContent.includes('Rent') || pageContent.includes('rent');

      expect(hasSearchOrFilter).toBeTruthy();
      expect(hasRent).toBeTruthy();
    });

    test('can access rental listing page', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      // Page should load without errors
      await expect(page).toHaveURL(/\/en\/rent/);

      // Should have some content indicating it's a rental page
      const pageContent = await page.content();
      const hasRentalContent = pageContent.includes('Rent') ||
                                pageContent.includes('rent') ||
                                pageContent.includes('Property');
      expect(hasRentalContent).toBeTruthy();
    });
  });

  test.describe('Navigation between property types', () => {
    test('can navigate from buy to rent page', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // Look for rent/rental link in navigation
      const rentLink = page.locator('a:has-text("Rent")');
      if (await rentLink.count() > 0) {
        await rentLink.first().click();
        await waitForPageLoad(page);
        await expect(page).toHaveURL(/\/rent/);
      }
    });

    test('can navigate from rent to buy page', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      // Look for buy/sale link in navigation
      const buyLink = page.locator('a:has-text("Buy"), a:has-text("Sale")');
      if (await buyLink.count() > 0) {
        await buyLink.first().click();
        await waitForPageLoad(page);
        await expect(page).toHaveURL(/\/buy/);
      }
    });
  });
});
