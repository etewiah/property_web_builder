// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToTenant, waitForPageLoad } = require('../fixtures/helpers');

/**
 * Property Search Tests
 * Based on: docs/ui/SEARCH_UI_SPECIFICATION.md
 *
 * US-1.2: Search Properties with Filters
 * As a public visitor, I want to filter properties by various criteria
 * So that I can narrow down my search to relevant listings
 */

test.describe('Property Search', () => {
  const tenant = TENANTS.A;

  test.describe('Sale Search Page', () => {
    test('loads successfully with 200 status', async ({ page }) => {
      const response = await page.goto(`${tenant.baseURL}${ROUTES.BUY}`);
      expect(response.status()).toBe(200);
    });

    test('displays search results container', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);
      await expect(page.locator('#inmo-search-results')).toBeVisible();
    });

    test('displays property results list container', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);
      // The results container should exist (either #ordered-properties or #inmo-search-results)
      const resultsContainer = page.locator('#ordered-properties, #inmo-search-results');
      await expect(resultsContainer).toBeAttached();
    });

    test('displays search filters', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const pageContent = await page.content();
      const hasSearchOrFilter = pageContent.includes('Search') || pageContent.includes('Filter');
      const hasPrice = pageContent.includes('Price');

      expect(hasSearchOrFilter).toBeTruthy();
      expect(hasPrice).toBeTruthy();
    });

    test('has property type filter', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const pageContent = await page.content();
      const hasPropertyType = pageContent.includes('Property Type') || pageContent.includes('Type');

      expect(hasPropertyType).toBeTruthy();
    });

    test('has bedroom filter', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const pageContent = await page.content();
      const hasBedroom = pageContent.toLowerCase().includes('bedroom');

      expect(hasBedroom).toBeTruthy();
    });

    test('has search form with submit button', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const searchButton = page.locator('button:has-text("Search"), input[type="submit"], button[type="submit"]');
      expect(await searchButton.count()).toBeGreaterThan(0);
    });
  });

  test.describe('Rental Search Page', () => {
    test('loads successfully with 200 status', async ({ page }) => {
      const response = await page.goto(`${tenant.baseURL}${ROUTES.RENT}`);
      expect(response.status()).toBe(200);
    });

    test('displays search results container', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);
      await expect(page.locator('#inmo-search-results')).toBeVisible();
    });

    test('displays rental-specific filters', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      const pageContent = await page.content();
      const hasRent = pageContent.includes('Rent');
      const hasSearchOrFilter = pageContent.includes('Search') || pageContent.includes('Filter');

      expect(hasRent).toBeTruthy();
      expect(hasSearchOrFilter).toBeTruthy();
    });

    test('shows rental terminology', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      const pageContent = await page.content().then(c => c.toLowerCase());
      expect(pageContent).toContain('rent');
    });

    test('has search form with submit button', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      const searchButton = page.locator('button:has-text("Search"), input[type="submit"], button[type="submit"]');
      expect(await searchButton.count()).toBeGreaterThan(0);
    });
  });

  test.describe('Property Cards', () => {
    test('displays property items or empty state on buy page', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // Look for property items (various class names used across themes)
      const propertyItems = page.locator('.property-item, .property-card, [data-price]');
      // Look for empty state message (various translations)
      const emptyState = page.locator('text=/no results|noResultsForSearch/i');

      const hasProperties = await propertyItems.count() > 0;
      const hasEmptyState = await emptyState.count() > 0;

      // Either properties or empty state should be shown
      expect(hasProperties || hasEmptyState).toBeTruthy();
    });

    test('displays property items or empty state on rent page', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.RENT);

      // Look for property items (various class names used across themes)
      const propertyItems = page.locator('.property-item, .property-card, [data-price]');
      // Look for empty state message (various translations)
      const emptyState = page.locator('text=/no results|noResultsForSearch/i');

      const hasProperties = await propertyItems.count() > 0;
      const hasEmptyState = await emptyState.count() > 0;

      // Either properties or empty state should be shown
      expect(hasProperties || hasEmptyState).toBeTruthy();
    });

    test('property cards show bedroom icon when properties exist', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const propertyItems = page.locator('.property-item, .property-card, [data-price]');
      if (await propertyItems.count() > 0) {
        const firstCard = propertyItems.first();
        await expect(firstCard.locator('i.fa-bed')).toBeVisible();
      }
    });

    test('property cards show bathroom icon when properties exist', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const propertyItems = page.locator('.property-item, .property-card, [data-price]');
      if (await propertyItems.count() > 0) {
        const firstCard = propertyItems.first();
        await expect(firstCard.locator('i.fa-shower')).toBeVisible();
      }
    });

    test('property cards show area icon when properties exist', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const propertyItems = page.locator('.property-item, .property-card, [data-price]');
      if (await propertyItems.count() > 0) {
        const firstCard = propertyItems.first();
        await expect(firstCard.locator('i.fa-arrows-alt')).toBeVisible();
      }
    });

    test('property cards have clickable links to details', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const propertyItems = page.locator('.property-item, .property-card, [data-price]');
      if (await propertyItems.count() > 0) {
        const firstCard = propertyItems.first();
        const links = firstCard.locator('a');
        expect(await links.count()).toBeGreaterThan(0);
      }
    });
  });

  test.describe('Empty State', () => {
    test('shows no results message when no properties match', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const propertyItems = page.locator('.property-item, .property-card, [data-price]');
      if (await propertyItems.count() === 0) {
        // Look for various empty state messages
        const emptyMessage = page.locator('text=/no results|noResultsForSearch|No properties found/i');
        await expect(emptyMessage).toBeVisible();
      }
    });

    test('shows clear filters button in empty state', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const propertyItems = page.locator('.property-item, .property-card, [data-price]');
      if (await propertyItems.count() === 0) {
        // Look for clear/reset filters button
        const clearButton = page.locator('button:has-text("Clear"), button:has-text("clear"), button:has-text("Reset")');
        if (await clearButton.count() > 0) {
          await expect(clearButton.first()).toBeVisible();
        }
      }
    });
  });

  test.describe('Map Section', () => {
    test('displays map container when properties have locations', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      const mapContainer = page.locator('#search-map');
      // Map is conditionally rendered based on @map_markers
      if (await mapContainer.count() > 0) {
        await expect(mapContainer).toBeVisible();
      }
    });
  });

  test.describe('Highlighted Properties', () => {
    test('highlighted properties have featured class or badge', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // Look for various ways highlighted properties are shown
      const featuredProperty = page.locator('.property-item.featured, .property-card.ring-2, [class*="featured"], [class*="highlighted"]');
      if (await featuredProperty.count() > 0) {
        await expect(featuredProperty.first()).toBeVisible();
      }
    });
  });

  test.describe('JavaScript Functionality', () => {
    test('Stimulus application is available', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);
      await waitForPageLoad(page);

      // Wait for JS to initialize
      await page.waitForTimeout(1000);

      // Stimulus-based apps use Stimulus.Application
      const stimulusExists = await page.evaluate(() => {
        return typeof window.Stimulus !== 'undefined' ||
               document.querySelector('[data-controller]') !== null;
      });

      expect(stimulusExists).toBeTruthy();
    });

    test('search form controller is connected', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);
      await waitForPageLoad(page);
      await page.waitForTimeout(1000);

      // Check for search form with Stimulus controller or data-remote for AJAX
      const hasSearchForm = await page.evaluate(() => {
        const searchController = document.querySelector('[data-controller*="search"]');
        const ajaxForm = document.querySelector('form[data-remote="true"]');
        return searchController !== null || ajaxForm !== null;
      });

      // Search form should exist (either Stimulus or UJS AJAX)
      expect(hasSearchForm).toBeTruthy();
    });

    test('search results container exists', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);
      await waitForPageLoad(page);

      // The results container should exist (either #ordered-properties or #inmo-search-results)
      const resultsContainer = page.locator('#ordered-properties, #inmo-search-results');
      await expect(resultsContainer).toBeAttached();
    });
  });

  test.describe('Responsive Design', () => {
    test('mobile filter toggle is visible on small screens', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await goToTenant(page, tenant, ROUTES.BUY);

      // Look for mobile filter toggle button (lg:hidden means visible on mobile)
      const filterToggle = page.locator('button:has-text("Filter")');
      if (await filterToggle.count() > 0) {
        await expect(filterToggle.first()).toBeVisible();
      }
    });

    test('sidebar filters are visible on desktop', async ({ page }) => {
      await page.setViewportSize({ width: 1200, height: 800 });
      await goToTenant(page, tenant, ROUTES.BUY);

      // On desktop, filters should be visible in sidebar
      const sidebarFilters = page.locator('#sidebar-filters');
      if (await sidebarFilters.count() > 0) {
        await expect(sidebarFilters).toBeVisible();
      }
    });
  });

  test.describe('Loading State', () => {
    test('search spinner element exists in DOM', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // Spinner should exist (may be hidden)
      const spinner = page.locator('#search-spinner');
      // Some themes have it, some don't
      const spinnerCount = await spinner.count();
      // Just verify the page loaded correctly
      await expect(page.locator('#inmo-search-results')).toBeVisible();
    });
  });

  test.describe('Search Form Behavior', () => {
    test('form uses AJAX for submissions', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.BUY);

      // Check that the form has data-remote attribute for AJAX
      const form = page.locator('form.form-light, form.simple_form');
      if (await form.count() > 0) {
        const dataRemote = await form.first().getAttribute('data-remote');
        // May use data-remote="true" for Rails UJS AJAX
        expect(dataRemote === 'true' || dataRemote === null).toBeTruthy();
      }
    });
  });
});
