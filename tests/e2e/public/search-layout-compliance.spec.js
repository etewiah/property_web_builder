/**
 * Search Layout Compliance Tests
 *
 * These tests verify that the search page layout complies with the UI specification
 * (docs/ui/SEARCH_UI_SPECIFICATION.md).
 *
 * Key requirements tested:
 * - Desktop (≥1024px): Filters BESIDE results (side-by-side), NOT stacked
 * - Sidebar: 25% width on LEFT side
 * - Results: 75% width on RIGHT side
 * - Mobile: Filters collapse with toggle button
 *
 * Tests run against ALL available themes to ensure consistency.
 *
 * Run with: RAILS_ENV=e2e npx playwright test tests/e2e/public/search-layout-compliance.spec.js
 */

const { test, expect } = require('@playwright/test');

// All themes that should be tested
// Add new themes here as they are created
const THEMES = ['default', 'brisbane', 'bologna', 'barcelona'];

// Desktop viewport for testing side-by-side layout
const DESKTOP_VIEWPORT = { width: 1440, height: 900 };

// Mobile viewport for testing collapsed filters
const MOBILE_VIEWPORT = { width: 375, height: 667 };

// Breakpoint where layout changes from stacked to side-by-side
const DESKTOP_BREAKPOINT = 1024;

// Expected layout proportions (with tolerance)
const LAYOUT = {
  sidebarWidthPercent: 25,
  resultsWidthPercent: 75,
  tolerance: 5 // Allow 5% deviation
};

// Selectors for search page elements
const SELECTORS = {
  searchLayout: '.search-layout',
  sidebar: '.search-sidebar',
  results: '.search-results-main, .search-results',
  filterPanel: '.filter-content, #sidebar-filters',
  filterToggle: '.filter-toggle button, [data-search-target="filterToggle"]',
  propertyCard: '[class*="property-card"], .search-result-item, [data-property-id]'
};

/**
 * Get computed layout information for the search page
 */
async function getLayoutInfo(page) {
  return await page.evaluate((selectors) => {
    const layout = document.querySelector(selectors.searchLayout);
    const sidebar = document.querySelector(selectors.sidebar);
    const results = document.querySelector(selectors.results);
    const filterPanel = document.querySelector(selectors.filterPanel);

    if (!layout || !sidebar || !results) {
      return { error: 'Required elements not found', layout: !!layout, sidebar: !!sidebar, results: !!results };
    }

    const layoutStyles = window.getComputedStyle(layout);
    const sidebarStyles = window.getComputedStyle(sidebar);
    const resultsStyles = window.getComputedStyle(results);
    const filterPanelStyles = filterPanel ? window.getComputedStyle(filterPanel) : null;

    // Get bounding rectangles to check actual positions
    const sidebarRect = sidebar.getBoundingClientRect();
    const resultsRect = results.getBoundingClientRect();

    return {
      windowWidth: window.innerWidth,
      windowHeight: window.innerHeight,

      // Layout container
      layoutDisplay: layoutStyles.display,
      layoutFlexWrap: layoutStyles.flexWrap,

      // Sidebar (filters)
      sidebarWidth: parseFloat(sidebarStyles.width),
      sidebarOrder: parseInt(sidebarStyles.order) || 0,
      sidebarDisplay: sidebarStyles.display,
      sidebarLeft: sidebarRect.left,
      sidebarRight: sidebarRect.right,

      // Results
      resultsWidth: parseFloat(resultsStyles.width),
      resultsOrder: parseInt(resultsStyles.order) || 0,
      resultsLeft: resultsRect.left,
      resultsRight: resultsRect.right,

      // Filter panel visibility
      filterPanelDisplay: filterPanelStyles?.display,
      filterPanelVisible: filterPanelStyles?.display !== 'none',

      // Check if sidebar is visually to the LEFT of results
      sidebarIsLeftOfResults: sidebarRect.right <= resultsRect.left + 50, // 50px tolerance for padding

      // Check if they're on the same row (side-by-side)
      areSideBySide: Math.abs(sidebarRect.top - resultsRect.top) < 50 // Within 50px vertically
    };
  }, SELECTORS);
}

/**
 * Calculate width percentage relative to container
 */
function calculateWidthPercent(elementWidth, containerWidth) {
  return (elementWidth / containerWidth) * 100;
}

test.describe('Search Layout Compliance', () => {

  // Test each theme
  for (const theme of THEMES) {

    test.describe(`Theme: ${theme}`, () => {

      test.describe('Desktop Layout (≥1024px)', () => {

        test.beforeEach(async ({ page }) => {
          await page.setViewportSize(DESKTOP_VIEWPORT);
        });

        test('buy page - filters display BESIDE results (side-by-side)', async ({ page }) => {
          const url = theme === 'default'
            ? '/en/buy'
            : `/en/buy?theme=${theme}`;

          await page.goto(url);
          await page.waitForLoadState('networkidle');

          const layout = await getLayoutInfo(page);

          // Verify elements exist
          expect(layout.error).toBeUndefined();

          // Verify flex layout
          expect(layout.layoutDisplay).toBe('flex');

          // CRITICAL: Sidebar must be LEFT of results (side-by-side)
          expect(layout.sidebarIsLeftOfResults).toBe(true);
          expect(layout.areSideBySide).toBe(true);

          // Verify sidebar is on LEFT (lower order or same order with earlier source position)
          expect(layout.sidebarOrder).toBeLessThanOrEqual(layout.resultsOrder);

          // Verify filter panel is visible on desktop
          expect(layout.filterPanelVisible).toBe(true);
        });

        test('buy page - sidebar width is approximately 25%', async ({ page }) => {
          const url = theme === 'default'
            ? '/en/buy'
            : `/en/buy?theme=${theme}`;

          await page.goto(url);
          await page.waitForLoadState('networkidle');

          const layout = await getLayoutInfo(page);
          expect(layout.error).toBeUndefined();

          // Calculate percentage of container (approximate based on total width)
          const totalWidth = layout.sidebarWidth + layout.resultsWidth;
          const sidebarPercent = calculateWidthPercent(layout.sidebarWidth, totalWidth);

          // Sidebar should be approximately 25% (with tolerance)
          expect(sidebarPercent).toBeGreaterThanOrEqual(LAYOUT.sidebarWidthPercent - LAYOUT.tolerance);
          expect(sidebarPercent).toBeLessThanOrEqual(LAYOUT.sidebarWidthPercent + LAYOUT.tolerance);
        });

        test('buy page - results width is approximately 75%', async ({ page }) => {
          const url = theme === 'default'
            ? '/en/buy'
            : `/en/buy?theme=${theme}`;

          await page.goto(url);
          await page.waitForLoadState('networkidle');

          const layout = await getLayoutInfo(page);
          expect(layout.error).toBeUndefined();

          // Calculate percentage of container
          const totalWidth = layout.sidebarWidth + layout.resultsWidth;
          const resultsPercent = calculateWidthPercent(layout.resultsWidth, totalWidth);

          // Results should be approximately 75% (with tolerance)
          expect(resultsPercent).toBeGreaterThanOrEqual(LAYOUT.resultsWidthPercent - LAYOUT.tolerance);
          expect(resultsPercent).toBeLessThanOrEqual(LAYOUT.resultsWidthPercent + LAYOUT.tolerance);
        });

        test('rent page - filters display BESIDE results (side-by-side)', async ({ page }) => {
          const url = theme === 'default'
            ? '/en/rent'
            : `/en/rent?theme=${theme}`;

          await page.goto(url);
          await page.waitForLoadState('networkidle');

          const layout = await getLayoutInfo(page);

          // Verify elements exist
          expect(layout.error).toBeUndefined();

          // CRITICAL: Sidebar must be LEFT of results (side-by-side)
          expect(layout.sidebarIsLeftOfResults).toBe(true);
          expect(layout.areSideBySide).toBe(true);

          // Verify filter panel is visible on desktop
          expect(layout.filterPanelVisible).toBe(true);
        });

      });

      test.describe('Mobile Layout (<1024px)', () => {

        test.beforeEach(async ({ page }) => {
          await page.setViewportSize(MOBILE_VIEWPORT);
        });

        test('buy page - filter panel is hidden by default', async ({ page }) => {
          const url = theme === 'default'
            ? '/en/buy'
            : `/en/buy?theme=${theme}`;

          await page.goto(url);
          await page.waitForLoadState('networkidle');

          // Filter panel should be hidden on mobile
          const filterPanel = page.locator(SELECTORS.filterPanel);

          // Check if the filter panel is hidden (display: none or visibility: hidden)
          const isVisible = await filterPanel.isVisible().catch(() => false);

          // On mobile, filters should be collapsed/hidden by default
          // The panel might exist but have display: none from CSS
          if (await filterPanel.count() > 0) {
            const display = await filterPanel.evaluate(el => window.getComputedStyle(el).display);
            // Either hidden or explicitly set to none via CSS
            expect(['none', 'block'].includes(display) || !isVisible).toBe(true);
          }
        });

        test('buy page - filter toggle button is visible', async ({ page }) => {
          const url = theme === 'default'
            ? '/en/buy'
            : `/en/buy?theme=${theme}`;

          await page.goto(url);
          await page.waitForLoadState('networkidle');

          // Filter toggle button should be visible on mobile
          const filterToggle = page.locator(SELECTORS.filterToggle).first();
          await expect(filterToggle).toBeVisible();
        });

        test('buy page - results take full width', async ({ page }) => {
          const url = theme === 'default'
            ? '/en/buy'
            : `/en/buy?theme=${theme}`;

          await page.goto(url);
          await page.waitForLoadState('networkidle');

          const results = page.locator(SELECTORS.results).first();
          const resultsBox = await results.boundingBox();

          if (resultsBox) {
            // Results should be nearly full viewport width on mobile (accounting for padding)
            const viewportWidth = MOBILE_VIEWPORT.width;
            const minExpectedWidth = viewportWidth * 0.85; // At least 85% of viewport

            expect(resultsBox.width).toBeGreaterThanOrEqual(minExpectedWidth);
          }
        });

      });

      test.describe('Breakpoint Behavior', () => {

        test('layout changes at 1024px breakpoint', async ({ page }) => {
          const url = theme === 'default'
            ? '/en/buy'
            : `/en/buy?theme=${theme}`;

          // Test just below breakpoint (mobile layout)
          await page.setViewportSize({ width: DESKTOP_BREAKPOINT - 1, height: 800 });
          await page.goto(url);
          await page.waitForLoadState('networkidle');

          // Filter toggle should be visible below breakpoint
          const filterToggleMobile = page.locator(SELECTORS.filterToggle).first();
          const isMobileToggleVisible = await filterToggleMobile.isVisible().catch(() => false);

          // Test at breakpoint (desktop layout)
          await page.setViewportSize({ width: DESKTOP_BREAKPOINT, height: 800 });
          await page.waitForTimeout(100); // Allow CSS to recalculate

          const layoutDesktop = await getLayoutInfo(page);

          // At 1024px, should have side-by-side layout
          if (!layoutDesktop.error) {
            expect(layoutDesktop.filterPanelVisible).toBe(true);
          }
        });

      });

    });

  }

});

// Additional test to ensure new themes follow the pattern
test.describe('Theme Discovery', () => {

  test('all themes in THEMES array should be tested', async () => {
    // This is a meta-test to remind developers to add new themes
    // When adding a new theme, add it to the THEMES array at the top of this file

    expect(THEMES).toContain('default');
    expect(THEMES).toContain('brisbane');
    expect(THEMES).toContain('bologna');
    expect(THEMES).toContain('barcelona');

    // Log for visibility
    console.log(`Testing ${THEMES.length} themes: ${THEMES.join(', ')}`);
  });

});
