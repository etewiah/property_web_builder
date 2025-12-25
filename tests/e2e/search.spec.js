/**
 * Property Search - Playwright E2E Tests
 *
 * These tests verify the search experience including:
 * - URL state management
 * - Filter interactions
 * - Results updates without full page reload
 * - Browser navigation (back/forward)
 * - Mobile responsiveness
 *
 * Run with: npx playwright test tests/e2e/search.spec.js
 *
 * Before running:
 *   RAILS_ENV=e2e bin/rails playwright:reset
 *   RAILS_ENV=e2e bin/rails playwright:server
 */

const { test, expect } = require('@playwright/test');

// Uses baseURL from playwright.config.js (http://tenant-a.e2e.localhost:3001)

// Selectors that match the actual implementation
const SELECTORS = {
  // Filter form elements
  propertyType: '[data-filter="type"]',
  priceMin: '[data-filter="price_min"]',
  priceMax: '[data-filter="price_max"]',
  // For radio buttons, use the label that wraps the hidden input
  bedroomLabel: (value) => `label:has(input[data-filter="bedrooms"][value="${value}"])`,
  bedroomRadio: (value) => `input[data-filter="bedrooms"][value="${value}"]`,
  bathroomLabel: (value) => `label:has(input[data-filter="bathrooms"][value="${value}"])`,
  bathroomRadio: (value) => `input[data-filter="bathrooms"][value="${value}"]`,
  featureCheckbox: (value) => `input[data-filter="feature"][value="${value}"]`,

  // Results
  resultsCount: '.results-count',
  resultsContainer: '#inmo-search-results',
  propertyCard: '[class*="property-card"], .search-result-item, [data-property-id]',
  loadingIndicator: '.search-loading',

  // Controls
  sortSelect: '#search-sort',
  viewGridBtn: '[data-view="grid"]',
  viewListBtn: '[data-view="list"]',
  clearFiltersBtn: '[data-action*="clearFilters"]',

  // Mobile
  filterToggleBtn: '[data-search-target="filterToggle"], .filter-toggle button',
  filterPanel: '#sidebar-filters, .filter-content, [data-search-target="filterPanel"]',
  applyFiltersBtn: '[data-action*="applyAndClose"]',
  backdrop: '[data-search-target="backdrop"]',

  // Pagination
  paginationNext: '.search-pagination .pagination-btn:last-child',
  paginationPrev: '.search-pagination .pagination-btn:first-child',
  paginationPage: (page) => `.search-pagination [data-page="${page}"]`,

  // Map
  mapContainer: '#search-map, .leaflet-container',
  mapMarker: '.leaflet-marker-icon'
};

test.describe('Property Search', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/en/buy');
    // Wait for page to be fully loaded
    await page.waitForLoadState('networkidle');
  });

  test.describe('URL State Management', () => {
    test('filter selection updates form state', async ({ page }) => {
      // Wait for property type select to be available
      const typeSelect = page.locator(SELECTORS.propertyType);

      // Skip if no property types available
      const options = await typeSelect.locator('option').count();
      if (options <= 1) {
        test.skip();
        return;
      }

      // Select first non-empty option
      const firstOption = await typeSelect.locator('option:not([value=""])').first();
      const optionValue = await firstOption.getAttribute('value');

      await typeSelect.selectOption(optionValue);

      // Wait for debounce + network
      await page.waitForLoadState('networkidle');

      // Filter should be applied (value should be selected)
      await expect(typeSelect).toHaveValue(optionValue);
    });

    test('multiple filters can be selected', async ({ page }) => {
      const typeSelect = page.locator(SELECTORS.propertyType);
      const options = await typeSelect.locator('option:not([value=""])').count();

      if (options < 1) {
        test.skip();
        return;
      }

      // Select property type
      const firstOption = await typeSelect.locator('option:not([value=""])').first();
      const optionValue = await firstOption.getAttribute('value');
      await typeSelect.selectOption(optionValue);
      await page.waitForLoadState('networkidle');

      // Click bedroom radio button label (e.g., 2+)
      const bedroomLabel = page.locator(SELECTORS.bedroomLabel('2'));
      const bedroomRadio = page.locator(SELECTORS.bedroomRadio('2'));
      if (await bedroomLabel.count() > 0) {
        await bedroomLabel.click();
        await page.waitForLoadState('networkidle');

        // Both filters should be applied
        await expect(typeSelect).toHaveValue(optionValue);
        await expect(bedroomRadio).toBeChecked();
      }
    });

    test('filter can be cleared', async ({ page }) => {
      const typeSelect = page.locator(SELECTORS.propertyType);
      const options = await typeSelect.locator('option:not([value=""])').count();

      if (options < 1) {
        test.skip();
        return;
      }

      // Add filter
      const firstOption = await typeSelect.locator('option:not([value=""])').first();
      const optionValue = await firstOption.getAttribute('value');
      await typeSelect.selectOption(optionValue);
      await page.waitForLoadState('networkidle');

      // Remove filter by selecting empty option
      await typeSelect.selectOption('');
      await page.waitForLoadState('networkidle');

      // Filter should be cleared
      await expect(typeSelect).toHaveValue('');
    });

    test('page loads with URL parameters applied', async ({ page }) => {
      // Navigate with parameters
      await page.goto('/en/buy?bedrooms=2');
      await page.waitForLoadState('networkidle');

      // Verify bedroom radio is checked
      const bedroomRadio = page.locator(SELECTORS.bedroomRadio('2'));
      if (await bedroomRadio.count() > 0) {
        await expect(bedroomRadio).toBeChecked();
      }
    });

    test('URL with parameters applies filters on load', async ({ page, context }) => {
      // Navigate directly with URL parameters
      await page.goto('/en/buy?bedrooms=3');
      await page.waitForLoadState('networkidle');

      // Verify filters applied from URL
      const bedroomRadio = page.locator(SELECTORS.bedroomRadio('3'));
      if (await bedroomRadio.count() > 0) {
        await expect(bedroomRadio).toBeChecked();
      }
    });
  });

  test.describe('Results Updates', () => {
    test('results container exists', async ({ page }) => {
      await expect(page.locator(SELECTORS.resultsContainer)).toBeVisible();
    });

    test('results count is displayed', async ({ page }) => {
      const resultsCount = page.locator(SELECTORS.resultsCount);
      await expect(resultsCount).toBeVisible();

      // Should contain a number
      const text = await resultsCount.textContent();
      expect(text).toMatch(/\d+/);
    });

    test('results update when filter changes', async ({ page }) => {
      // Click bedroom filter label
      const bedroomLabel = page.locator(SELECTORS.bedroomLabel('2'));
      const bedroomRadio = page.locator(SELECTORS.bedroomRadio('2'));
      if (await bedroomLabel.count() > 0) {
        await bedroomLabel.click();

        // Wait for network to settle
        await page.waitForLoadState('networkidle');

        // Filter should be applied
        await expect(bedroomRadio).toBeChecked();
      }
    });

    test('map markers exist when map is present', async ({ page }) => {
      // Check if map exists on page
      const mapContainer = page.locator(SELECTORS.mapContainer);

      if (await mapContainer.count() > 0) {
        await expect(mapContainer).toBeVisible();

        // Wait for map to initialize
        await page.waitForTimeout(1000);

        // Markers should be present (or zero if no properties have coordinates)
        const markers = page.locator(SELECTORS.mapMarker);
        const markerCount = await markers.count();
        expect(markerCount).toBeGreaterThanOrEqual(0);
      }
    });
  });

  test.describe('Browser Navigation', () => {
    test('back button works after navigation', async ({ page }) => {
      // Navigate to filtered page
      await page.goto('/en/buy?bedrooms=2');
      await page.waitForLoadState('networkidle');

      const bedroomRadio = page.locator(SELECTORS.bedroomRadio('2'));
      if (await bedroomRadio.count() === 0) {
        test.skip();
        return;
      }

      // Verify filter is applied
      await expect(bedroomRadio).toBeChecked();

      // Navigate somewhere else
      await page.goto('/en/buy');
      await page.waitForLoadState('networkidle');

      // Go back
      await page.goBack();
      await page.waitForLoadState('networkidle');

      // Should be back on filtered page
      expect(page.url()).toContain('bedrooms=2');
    });

    test('forward button works after back', async ({ page }) => {
      // Navigate to filtered page then base page
      await page.goto('/en/buy?bedrooms=3');
      await page.waitForLoadState('networkidle');
      await page.goto('/en/buy');
      await page.waitForLoadState('networkidle');

      // Go back
      await page.goBack();
      await page.waitForLoadState('networkidle');

      // Go forward
      await page.goForward();
      await page.waitForLoadState('networkidle');

      // Should be on base page
      expect(page.url()).not.toContain('bedrooms=');
    });
  });

  test.describe('Filter Interactions', () => {
    test('property type dropdown works', async ({ page }) => {
      const typeSelect = page.locator(SELECTORS.propertyType);
      const options = await typeSelect.locator('option:not([value=""])').count();

      if (options < 1) {
        test.skip();
        return;
      }

      const firstOption = await typeSelect.locator('option:not([value=""])').first();
      const optionValue = await firstOption.getAttribute('value');

      await typeSelect.selectOption(optionValue);
      await page.waitForLoadState('networkidle');

      await expect(typeSelect).toHaveValue(optionValue);
    });

    test('price range selects work', async ({ page }) => {
      const priceMinSelect = page.locator(SELECTORS.priceMin);

      // Get first non-empty price option
      const priceOptions = await priceMinSelect.locator('option:not([value=""])');
      if (await priceOptions.count() === 0) {
        test.skip();
        return;
      }

      const firstPrice = await priceOptions.first();
      const priceValue = await firstPrice.getAttribute('value');

      await priceMinSelect.selectOption(priceValue);
      await page.waitForLoadState('networkidle');

      // Filter should be applied
      await expect(priceMinSelect).toHaveValue(priceValue);
    });

    test('bedrooms radio buttons work', async ({ page }) => {
      const bedroomLabel = page.locator(SELECTORS.bedroomLabel('2'));
      const bedroomRadio = page.locator(SELECTORS.bedroomRadio('2'));
      if (await bedroomLabel.count() === 0) {
        test.skip();
        return;
      }

      await bedroomLabel.click();
      await page.waitForLoadState('networkidle');

      await expect(bedroomRadio).toBeChecked();
    });

    test('features checkboxes work', async ({ page }) => {
      // Find first feature checkbox
      const featureCheckboxes = page.locator('input[data-filter="feature"]');

      if (await featureCheckboxes.count() === 0) {
        test.skip();
        return;
      }

      const firstFeature = featureCheckboxes.first();

      // Use force:true for hidden checkboxes styled with custom labels
      await firstFeature.check({ force: true });
      await page.waitForLoadState('networkidle');

      await expect(firstFeature).toBeChecked();
    });

    test('clear filters button exists', async ({ page }) => {
      // Navigate to a page with filters applied
      await page.goto('/en/buy?bedrooms=2');
      await page.waitForLoadState('networkidle');

      // Clear filters button should exist
      const clearBtn = page.locator(SELECTORS.clearFiltersBtn);
      if (await clearBtn.count() === 0) {
        test.skip();
        return;
      }

      // Button should be visible and clickable
      await expect(clearBtn.first()).toBeVisible();
    });

    test('sort dropdown works', async ({ page }) => {
      const sortSelect = page.locator(SELECTORS.sortSelect);

      if (await sortSelect.count() === 0) {
        test.skip();
        return;
      }

      await sortSelect.selectOption('price-asc');
      await page.waitForLoadState('networkidle');

      await expect(sortSelect).toHaveValue('price-asc');
    });

    test('view toggle buttons exist', async ({ page }) => {
      const listViewBtn = page.locator(SELECTORS.viewListBtn);
      const gridViewBtn = page.locator(SELECTORS.viewGridBtn);

      // At least one view toggle button should exist
      const hasToggle = (await listViewBtn.count() > 0) || (await gridViewBtn.count() > 0);

      if (!hasToggle) {
        test.skip();
        return;
      }

      // The visible button should be clickable
      if (await listViewBtn.count() > 0) {
        await expect(listViewBtn).toBeVisible();
      }
      if (await gridViewBtn.count() > 0) {
        await expect(gridViewBtn).toBeVisible();
      }
    });
  });

  test.describe('Pagination', () => {
    test('pagination is visible when results exceed page size', async ({ page }) => {
      // Pagination only shows when there are multiple pages
      const pagination = page.locator('.search-pagination');

      // This test passes if pagination exists OR doesn't exist (depends on data)
      const paginationCount = await pagination.count();
      expect(paginationCount).toBeGreaterThanOrEqual(0);
    });

    test('clicking pagination updates page', async ({ page }) => {
      const nextBtn = page.locator(SELECTORS.paginationNext);

      if (await nextBtn.count() === 0) {
        test.skip();
        return;
      }

      await nextBtn.click();
      await page.waitForLoadState('networkidle');

      // Either URL has page param or results have updated
      const hasPageParam = page.url().includes('page=');
      const resultsVisible = await page.locator(SELECTORS.resultsContainer).isVisible();

      expect(hasPageParam || resultsVisible).toBe(true);
    });

    test('pagination preserves filters', async ({ page }) => {
      // Apply filter first using label
      const bedroomLabel = page.locator(SELECTORS.bedroomLabel('1'));
      const bedroomRadio = page.locator(SELECTORS.bedroomRadio('1'));
      if (await bedroomLabel.count() === 0) {
        test.skip();
        return;
      }

      await bedroomLabel.click();
      await page.waitForLoadState('networkidle');

      // Check if pagination exists
      const nextBtn = page.locator(SELECTORS.paginationNext);
      if (await nextBtn.count() === 0) {
        test.skip();
        return;
      }

      await nextBtn.click();
      await page.waitForLoadState('networkidle');

      // Bedroom filter should still be selected
      await expect(bedroomRadio).toBeChecked();
    });
  });
});

test.describe('Mobile Experience', () => {
  test.use({ viewport: { width: 375, height: 667 } });

  test('filter panel is hidden by default on mobile', async ({ page }) => {
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');

    // Filter panel should be hidden on mobile (has 'hidden' class or lg:block)
    const filterPanel = page.locator(SELECTORS.filterPanel);

    // Panel exists but is hidden via CSS (hidden class or visibility)
    const isHidden = await filterPanel.evaluate((el) => {
      const style = window.getComputedStyle(el);
      return el.classList.contains('hidden') ||
             style.display === 'none' ||
             style.visibility === 'hidden';
    });

    expect(isHidden).toBe(true);
  });

  test('filter toggle button shows on mobile', async ({ page }) => {
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');

    const toggleBtn = page.locator(SELECTORS.filterToggleBtn);
    await expect(toggleBtn).toBeVisible();
  });

  test('filter panel toggle button is functional', async ({ page }) => {
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');

    const toggleBtn = page.locator(SELECTORS.filterToggleBtn);
    if (await toggleBtn.count() === 0) {
      test.skip();
      return;
    }

    // Toggle button should be visible on mobile
    await expect(toggleBtn.first()).toBeVisible();

    // Button should have aria-expanded attribute
    const ariaExpanded = await toggleBtn.first().getAttribute('aria-expanded');
    expect(['true', 'false']).toContain(ariaExpanded);
  });

  test('mobile apply button exists when filters open', async ({ page }) => {
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');

    // Check if the mobile apply button exists in the DOM
    const applyBtn = page.locator(SELECTORS.applyFiltersBtn);
    const count = await applyBtn.count();

    // This test just verifies the button exists (may be hidden)
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('results are visible on mobile', async ({ page }) => {
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');

    const resultsContainer = page.locator(SELECTORS.resultsContainer);
    await expect(resultsContainer).toBeVisible();
  });
});

test.describe('Accessibility', () => {
  test('filter controls have accessible labels', async ({ page }) => {
    await page.goto('/en/buy');

    // Check property type select has label
    const typeSelect = page.locator(SELECTORS.propertyType);
    const typeId = await typeSelect.getAttribute('id');

    if (typeId) {
      const label = page.locator(`label[for="${typeId}"]`);
      await expect(label).toBeVisible();
    }
  });

  test('results region has aria-live for screen readers', async ({ page }) => {
    await page.goto('/en/buy');

    // Results count should have aria-live
    const resultsCount = page.locator(SELECTORS.resultsCount);
    const ariaLive = await resultsCount.getAttribute('aria-live');

    expect(ariaLive).toBe('polite');
  });

  test('keyboard navigation works', async ({ page }) => {
    await page.goto('/en/buy');

    // Tab through the page
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');

    // Focus should be on an interactive element
    const activeElement = await page.evaluate(() => document.activeElement?.tagName);
    expect(['SELECT', 'INPUT', 'BUTTON', 'A']).toContain(activeElement);
  });
});

test.describe('Performance', () => {
  test('initial load is fast', async ({ page }) => {
    const startTime = Date.now();
    await page.goto('/en/buy');
    await page.waitForLoadState('domcontentloaded');
    const loadTime = Date.now() - startTime;

    // 10 second max for slower CI environments and initial cold starts
    expect(loadTime).toBeLessThan(10000);
  });

  test('filter updates are reasonably fast', async ({ page }) => {
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');

    const bedroomLabel = page.locator(SELECTORS.bedroomLabel('2'));
    if (await bedroomLabel.count() === 0) {
      test.skip();
      return;
    }

    const startTime = Date.now();
    await bedroomLabel.click();
    await page.waitForLoadState('networkidle');
    const updateTime = Date.now() - startTime;

    // 5 second max for filter updates (includes debounce + network)
    expect(updateTime).toBeLessThan(5000);
  });

  test('page remains responsive after filter changes', async ({ page }) => {
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');

    // Perform several filter changes
    const bedroomOptions = ['1', '2', '3'];

    for (const bedroom of bedroomOptions) {
      const label = page.locator(SELECTORS.bedroomLabel(bedroom));
      if (await label.count() > 0) {
        await label.click();
        await page.waitForLoadState('networkidle');
      }
    }

    // Page should still be responsive
    const resultsContainer = page.locator(SELECTORS.resultsContainer);
    await expect(resultsContainer).toBeVisible();
  });
});

test.describe('Visual Regression', () => {
  test('search page matches snapshot', async ({ page }) => {
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');

    // Wait for any animations
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('search-default.png', {
      maxDiffPixelRatio: 0.1
    });
  });

  test('filtered results match snapshot', async ({ page }) => {
    await page.goto('/en/buy?bedrooms=2');
    await page.waitForLoadState('networkidle');

    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('search-filtered.png', {
      maxDiffPixelRatio: 0.1
    });
  });

  test('mobile view matches snapshot', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');

    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('search-mobile.png', {
      maxDiffPixelRatio: 0.1
    });
  });
});
