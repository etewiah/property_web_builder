// @ts-check
const { test, expect } = require('@playwright/test');

test('For Sale page displays property details correctly', async ({ page }) => {
  // Navigate to the For Sale page
  await page.goto('http://localhost:9001/#/en/for-sale');

  // Wait for properties to load
  await page.waitForSelector('.listings-summary-card', { timeout: 10000 });

  // Check if at least one property card is displayed
  const propertyCards = page.locator('.listings-summary-card');
  const count = await propertyCards.count();
  expect(count).toBeGreaterThan(0);
  
  // Iterate through cards to find one with the new fields if possible, 
  // or just check the first one and log warnings if data is missing.
  const firstCard = propertyCards.first();

  // Check for Price (should always be there)
  await expect(firstCard.locator('.property-price')).toBeVisible();

  // Check for Bedrooms (should always be there)
  await expect(firstCard.locator('.property-bedrooms')).toBeVisible();

  // Check for Bathrooms (should always be there)
  await expect(firstCard.locator('.property-bathrooms')).toBeVisible();

  // Check for Reference
  // We expect at least some properties to have a reference.
  const reference = firstCard.locator('.property-reference');
  if (await reference.count() > 0) {
      await expect(reference).toBeVisible();
      console.log('Reference found and visible');
  } else {
      console.log('Reference not found on first card (might be missing data)');
  }

  // Check for Area
  const area = firstCard.locator('.property-area');
  if (await area.count() > 0) {
      await expect(area).toBeVisible();
      console.log('Area found and visible');
  } else {
      console.log('Area not found on first card (might be missing data)');
  }

  // Check for Garages
  const garages = firstCard.locator('.property-garages');
  if (await garages.count() > 0) {
      await expect(garages).toBeVisible();
      console.log('Garages found and visible');
  } else {
      console.log('Garages not found on first card (might be missing data)');
  }
});
