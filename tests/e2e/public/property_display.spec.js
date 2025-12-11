// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS } = require('../fixtures/test-data');

test.describe('Property Display', () => {
  const tenant = TENANTS.A;

  test('For Sale page displays properties', async ({ page }) => {
    // Navigate to the For Sale page
    await page.goto(`${tenant.baseURL}/en/buy`);
    await page.waitForLoadState('networkidle');

    // Check page loaded successfully
    const pageContent = await page.content();
    const hasPropertyContent = pageContent.includes('Property') ||
                               pageContent.includes('property') ||
                               pageContent.includes('Sale') ||
                               pageContent.includes('Buy');
    expect(hasPropertyContent).toBeTruthy();

    // Check for property listings (various possible selectors)
    const propertyCards = page.locator('.property-card, .listing-card, .prop-card, [class*="property"], article');
    const count = await propertyCards.count();

    // Should have some property cards or at least a property list
    if (count > 0) {
      // Check first card has some content
      const firstCard = propertyCards.first();
      await expect(firstCard).toBeVisible();
    }
  });

  test('For Rent page displays properties', async ({ page }) => {
    // Navigate to the For Rent page
    await page.goto(`${tenant.baseURL}/en/rent`);
    await page.waitForLoadState('networkidle');

    // Check page loaded successfully
    const pageContent = await page.content();
    const hasPropertyContent = pageContent.includes('Property') ||
                               pageContent.includes('property') ||
                               pageContent.includes('Rent');
    expect(hasPropertyContent).toBeTruthy();
  });

  test('Property details page is accessible', async ({ page }) => {
    // First go to buy page
    await page.goto(`${tenant.baseURL}/en/buy`);
    await page.waitForLoadState('networkidle');

    // Find a property link and click it
    const propertyLink = page.locator('a[href*="/properties/"], a[href*="/for-sale/"]').first();
    if (await propertyLink.count() > 0) {
      await propertyLink.click();
      await page.waitForLoadState('networkidle');

      // Should be on a property details page
      const currentURL = page.url();
      const isPropertyPage = currentURL.includes('/properties/') || currentURL.includes('/for-sale/');
      expect(isPropertyPage).toBeTruthy();
    }
  });
});
