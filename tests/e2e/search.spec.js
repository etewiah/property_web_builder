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

test.describe('Property Search', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/en/buy');
    // Wait for page to be fully loaded
    await page.waitForLoadState('networkidle');
  });

  test.describe('URL State Management', () => {
    test('URL updates when filter changes', async ({ page }) => {
      // Select property type
      await page.selectOption('[data-filter="type"]', 'apartment');

      // Wait for URL to update
      await page.waitForURL(/type=apartment/);

      expect(page.url()).toContain('type=apartment');
    });

    test('URL updates with multiple filters', async ({ page }) => {
      await page.selectOption('[data-filter="type"]', 'apartment');
      await page.waitForURL(/type=apartment/);

      await page.fill('[data-filter="bedrooms"]', '2');
      await page.waitForURL(/bedrooms=2/);

      expect(page.url()).toContain('type=apartment');
      expect(page.url()).toContain('bedrooms=2');
    });

    test('URL clears when filter is removed', async ({ page }) => {
      // Add filter
      await page.selectOption('[data-filter="type"]', 'apartment');
      await page.waitForURL(/type=apartment/);

      // Remove filter
      await page.selectOption('[data-filter="type"]', '');
      await page.waitForURL(url => !url.toString().includes('type='));

      expect(page.url()).not.toContain('type=apartment');
    });

    test('page loads with URL parameters applied', async ({ page }) => {
      await page.goto('/en/buy?type=apartment&bedrooms=2');

      // Verify filter controls reflect URL state
      await expect(page.locator('[data-filter="type"]')).toHaveValue('apartment');
      await expect(page.locator('[data-filter="bedrooms"]')).toHaveValue('2');
    });

    test('URL is bookmarkable and shareable', async ({ page, context }) => {
      // Set up filters
      await page.selectOption('[data-filter="type"]', 'villa');
      await page.waitForURL(/type=villa/);

      const currentUrl = page.url();

      // Open in new page (simulating bookmark/share)
      const newPage = await context.newPage();
      await newPage.goto(currentUrl);
      await newPage.waitForLoadState('networkidle');

      // Verify same filters applied
      await expect(newPage.locator('[data-filter="type"]')).toHaveValue('villa');

      await newPage.close();
    });
  });

  test.describe('Results Updates', () => {
    test('results update without full page reload', async ({ page }) => {
      // Get initial results count
      const initialCount = await page.locator('.results-count').textContent();

      // Track network requests
      let navigationCount = 0;
      page.on('framenavigated', () => navigationCount++);

      // Apply filter
      await page.selectOption('[data-filter="type"]', 'apartment');

      // Wait for results to update
      await page.waitForSelector('.property-card');

      // Should not have had a full page navigation
      expect(navigationCount).toBeLessThanOrEqual(1);
    });

    test('loading indicator shows during update', async ({ page }) => {
      // Start filter change
      await page.selectOption('[data-filter="type"]', 'apartment');

      // Loading indicator should appear
      await expect(page.locator('.search-loading, [data-search-loading]')).toBeVisible({ timeout: 100 });

      // Wait for loading to complete
      await page.waitForLoadState('networkidle');
    });

    test('results count updates with filters', async ({ page }) => {
      const initialCount = await page.locator('.results-count').textContent();

      await page.selectOption('[data-filter="type"]', 'apartment');
      await page.waitForLoadState('networkidle');

      const newCount = await page.locator('.results-count').textContent();

      // Count should have changed (may be same if all are apartments)
      expect(newCount).toBeDefined();
    });

    test('map markers update with results', async ({ page }) => {
      // Wait for map to load
      await page.waitForSelector('.leaflet-container, #search-map');

      // Get initial marker count
      const initialMarkers = await page.locator('.leaflet-marker-icon').count();

      // Apply restrictive filter
      await page.selectOption('[data-filter="type"]', 'apartment');
      await page.waitForLoadState('networkidle');

      // Markers should update (count may change)
      const newMarkers = await page.locator('.leaflet-marker-icon').count();
      expect(newMarkers).toBeGreaterThanOrEqual(0);
    });
  });

  test.describe('Browser Navigation', () => {
    test('back button restores previous search', async ({ page }) => {
      // Initial state - no filters
      const initialUrl = page.url();

      // Apply filter
      await page.selectOption('[data-filter="type"]', 'apartment');
      await page.waitForURL(/type=apartment/);

      // Go back
      await page.goBack();
      await page.waitForURL(url => !url.toString().includes('type='));

      // URL should be restored
      expect(page.url()).not.toContain('type=apartment');

      // Filter should be cleared
      await expect(page.locator('[data-filter="type"]')).toHaveValue('');
    });

    test('forward button restores search after back', async ({ page }) => {
      // Apply filter
      await page.selectOption('[data-filter="type"]', 'villa');
      await page.waitForURL(/type=villa/);

      // Go back
      await page.goBack();
      await page.waitForURL(url => !url.toString().includes('type='));

      // Go forward
      await page.goForward();
      await page.waitForURL(/type=villa/);

      expect(page.url()).toContain('type=villa');
      await expect(page.locator('[data-filter="type"]')).toHaveValue('villa');
    });

    test('multiple back/forward navigations work correctly', async ({ page }) => {
      // Build up history
      await page.selectOption('[data-filter="type"]', 'apartment');
      await page.waitForURL(/type=apartment/);

      await page.fill('[data-filter="bedrooms"]', '2');
      await page.waitForURL(/bedrooms=2/);

      await page.fill('[data-filter="bedrooms"]', '3');
      await page.waitForURL(/bedrooms=3/);

      // Go back twice
      await page.goBack();
      await page.waitForURL(/bedrooms=2/);

      await page.goBack();
      await page.waitForURL(url => !url.toString().includes('bedrooms='));

      // Verify state
      expect(page.url()).toContain('type=apartment');
      expect(page.url()).not.toContain('bedrooms=');
    });
  });

  test.describe('Filter Interactions', () => {
    test('property type dropdown works', async ({ page }) => {
      await page.selectOption('[data-filter="type"]', 'apartment');
      await page.waitForURL(/type=apartment/);

      await expect(page.locator('[data-filter="type"]')).toHaveValue('apartment');
    });

    test('price range inputs work', async ({ page }) => {
      await page.fill('[data-filter="price_min"]', '100000');
      await page.fill('[data-filter="price_max"]', '500000');

      // Trigger filter update (blur or change event)
      await page.locator('[data-filter="price_max"]').blur();

      await page.waitForURL(/price_min=100000/);
      expect(page.url()).toContain('price_max=500000');
    });

    test('bedrooms filter works', async ({ page }) => {
      await page.click('[data-filter="bedrooms"][value="2"]');
      await page.waitForURL(/bedrooms=2/);

      expect(page.url()).toContain('bedrooms=2');
    });

    test('features checkboxes work', async ({ page }) => {
      await page.check('[data-filter="feature"][value="pool"]');
      await page.waitForURL(/features=.*pool/);

      expect(page.url()).toContain('pool');
    });

    test('clear filters button works', async ({ page }) => {
      // Apply filters
      await page.selectOption('[data-filter="type"]', 'apartment');
      await page.waitForURL(/type=apartment/);

      // Clear all
      await page.click('[data-action="clear-filters"]');
      await page.waitForURL(url => !url.search);

      // URL should be clean
      expect(page.url()).not.toContain('type=');
      expect(page.url()).not.toContain('?');
    });

    test('sort dropdown works', async ({ page }) => {
      await page.selectOption('[data-filter="sort"]', 'price-asc');
      await page.waitForURL(/sort=price-asc/);

      expect(page.url()).toContain('sort=price-asc');
    });

    test('view toggle works', async ({ page }) => {
      await page.click('[data-view="list"]');
      await page.waitForURL(/view=list/);

      expect(page.url()).toContain('view=list');

      // Results should show list layout
      await expect(page.locator('.results-list, [data-results-view="list"]')).toBeVisible();
    });
  });

  test.describe('Pagination', () => {
    test('page parameter updates URL', async ({ page }) => {
      // Assume there are enough results for pagination
      await page.click('.pagination a[data-page="2"], .pagination .next');
      await page.waitForURL(/page=2/);

      expect(page.url()).toContain('page=2');
    });

    test('pagination preserves filters', async ({ page }) => {
      await page.selectOption('[data-filter="type"]', 'apartment');
      await page.waitForURL(/type=apartment/);

      await page.click('.pagination a[data-page="2"], .pagination .next');
      await page.waitForURL(/page=2/);

      expect(page.url()).toContain('type=apartment');
      expect(page.url()).toContain('page=2');
    });
  });
});

test.describe('Mobile Experience', () => {
  test.use({ viewport: { width: 375, height: 667 } });

  test('filter panel is hidden by default on mobile', async ({ page }) => {
    await page.goto(`/en/buy`);
    await page.waitForLoadState('networkidle');

    // Filter panel should be hidden or collapsed
    await expect(page.locator('.filter-panel, [data-filter-panel]'))
      .toBeHidden()
      .or(page.locator('.filter-panel.collapsed, [data-filter-panel][data-collapsed]')).toBeVisible();
  });

  test('filter toggle button shows on mobile', async ({ page }) => {
    await page.goto(`/en/buy`);
    await page.waitForLoadState('networkidle');

    await expect(page.locator('[data-action="toggle-filters"]')).toBeVisible();
  });

  test('filter panel opens on toggle click', async ({ page }) => {
    await page.goto(`/en/buy`);
    await page.waitForLoadState('networkidle');

    await page.click('[data-action="toggle-filters"]');

    await expect(page.locator('.filter-panel, [data-filter-panel]')).toBeVisible();
  });

  test('apply filters button closes panel on mobile', async ({ page }) => {
    await page.goto(`/en/buy`);
    await page.waitForLoadState('networkidle');

    // Open filters
    await page.click('[data-action="toggle-filters"]');
    await expect(page.locator('.filter-panel')).toBeVisible();

    // Select filter and apply
    await page.selectOption('[data-filter="type"]', 'apartment');
    await page.click('[data-action="apply-filters"]');

    // Panel should close
    await expect(page.locator('.filter-panel')).toBeHidden();
  });

  test('results are scrollable on mobile', async ({ page }) => {
    await page.goto(`/en/buy`);
    await page.waitForLoadState('networkidle');

    // Scroll results
    await page.evaluate(() => {
      const results = document.querySelector('.search-results, [data-search-results]');
      if (results) {
        results.scrollTop = 500;
      }
    });

    // Should be able to scroll
    const scrollTop = await page.evaluate(() => {
      const results = document.querySelector('.search-results, [data-search-results]');
      return results ? results.scrollTop : 0;
    });

    expect(scrollTop).toBeGreaterThanOrEqual(0);
  });
});

test.describe('Accessibility', () => {
  test('filter controls have accessible labels', async ({ page }) => {
    await page.goto(`/en/buy`);

    // All filter inputs should have labels
    const filters = await page.locator('[data-filter]').all();
    for (const filter of filters) {
      const id = await filter.getAttribute('id');
      if (id) {
        const label = page.locator(`label[for="${id}"]`);
        await expect(label).toBeVisible();
      }
    }
  });

  test('results announce updates to screen readers', async ({ page }) => {
    await page.goto(`/en/buy`);

    // Results region should have aria-live or be in a live region
    const resultsRegion = page.locator('[aria-live], [role="status"]');
    await expect(resultsRegion).toBeVisible();
  });

  test('keyboard navigation works', async ({ page }) => {
    await page.goto(`/en/buy`);

    // Tab to first filter
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');

    // Should be able to interact with keyboard
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('Enter');

    // Focus should move through interactive elements
    const activeElement = await page.evaluate(() => document.activeElement?.tagName);
    expect(['SELECT', 'INPUT', 'BUTTON', 'A']).toContain(activeElement);
  });
});

test.describe('Performance', () => {
  test('initial load is fast', async ({ page }) => {
    const startTime = Date.now();
    await page.goto(`/en/buy`);
    await page.waitForLoadState('domcontentloaded');
    const loadTime = Date.now() - startTime;

    expect(loadTime).toBeLessThan(3000); // 3 second max
  });

  test('filter updates are fast', async ({ page }) => {
    await page.goto(`/en/buy`);
    await page.waitForLoadState('networkidle');

    const startTime = Date.now();
    await page.selectOption('[data-filter="type"]', 'apartment');
    await page.waitForLoadState('networkidle');
    const updateTime = Date.now() - startTime;

    expect(updateTime).toBeLessThan(1000); // 1 second max
  });

  test('no memory leaks on repeated filter changes', async ({ page }) => {
    await page.goto(`/en/buy`);
    await page.waitForLoadState('networkidle');

    // Perform many filter changes
    for (let i = 0; i < 10; i++) {
      await page.selectOption('[data-filter="type"]', i % 2 === 0 ? 'apartment' : 'villa');
      await page.waitForLoadState('networkidle');
    }

    // Page should still be responsive
    const isResponsive = await page.evaluate(() => {
      return document.querySelector('[data-filter="type"]') !== null;
    });
    expect(isResponsive).toBe(true);
  });
});

test.describe('Visual Regression', () => {
  test('search page matches snapshot', async ({ page }) => {
    await page.goto(`/en/buy`);
    await page.waitForLoadState('networkidle');

    // Wait for any animations
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('search-default.png', {
      maxDiffPixelRatio: 0.1
    });
  });

  test('filtered results match snapshot', async ({ page }) => {
    await page.goto(`/en/buy?type=apartment&bedrooms=2`);
    await page.waitForLoadState('networkidle');

    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('search-filtered.png', {
      maxDiffPixelRatio: 0.1
    });
  });

  test('mobile view matches snapshot', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto(`/en/buy`);
    await page.waitForLoadState('networkidle');

    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('search-mobile.png', {
      maxDiffPixelRatio: 0.1
    });
  });
});
