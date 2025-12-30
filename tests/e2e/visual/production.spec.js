// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Production Visual Regression Tests
 *
 * These tests capture and compare visual snapshots of the production site
 * at https://demo.propertywebbuilder.com to detect unintended visual changes.
 *
 * Usage:
 *   # Run tests (will fail if snapshots differ)
 *   npx playwright test tests/e2e/visual/production.spec.js
 *
 *   # Update snapshots after intentional changes
 *   npx playwright test tests/e2e/visual/production.spec.js --update-snapshots
 *
 *   # Run with specific project (browser)
 *   npx playwright test tests/e2e/visual/production.spec.js --project=chromium
 */

const BASE_URL = 'https://demo.propertywebbuilder.com';

// Themes available via subdomain
// Note: Only include themes with working SSL certificates
const THEMES = [
  { name: 'demo', subdomain: 'demo' },
  { name: 'brisbane', subdomain: 'brisbane' },
  // { name: 'bologna', subdomain: 'bologna' }, // Currently has SSL issues
];

// Pages to test for each theme
const PAGES = [
  { name: 'home', path: '/', description: 'Homepage' },
  { name: 'home-en', path: '/en', description: 'English homepage' },
  { name: 'buy', path: '/en/buy', description: 'Properties for sale' },
  { name: 'rent', path: '/en/rent', description: 'Properties for rent' },
  { name: 'contact', path: '/contact-us', description: 'Contact page' },
  { name: 'about', path: '/about-us', description: 'About page' },
];

// Viewport configurations
const VIEWPORTS = {
  desktop: { width: 1440, height: 900 },
  tablet: { width: 768, height: 1024 },
  mobile: { width: 375, height: 812 },
};

// Screenshot options for consistent comparisons
const SCREENSHOT_OPTIONS = {
  fullPage: true,
  animations: 'disabled',
  // Allow some pixel difference for dynamic content (ads, timestamps, etc.)
  maxDiffPixelRatio: 0.05,
  // Threshold for color difference (0-1)
  threshold: 0.2,
};

/**
 * Build URL for a specific theme and path
 */
function buildUrl(subdomain, pagePath) {
  return `https://${subdomain}.propertywebbuilder.com${pagePath}`;
}

/**
 * Wait for page to be fully loaded and stable
 */
async function waitForPageStable(page) {
  await page.waitForLoadState('networkidle');
  // Wait for any lazy-loaded images
  await page.waitForTimeout(1000);
  // Scroll to trigger lazy loading, then scroll back
  await page.evaluate(() => {
    window.scrollTo(0, document.body.scrollHeight);
  });
  await page.waitForTimeout(500);
  await page.evaluate(() => {
    window.scrollTo(0, 0);
  });
  await page.waitForTimeout(500);
}

/**
 * Hide dynamic elements that change between runs
 */
async function hideDynamicElements(page) {
  await page.evaluate(() => {
    // Hide elements that may change (timestamps, counters, etc.)
    const selectorsToHide = [
      '[data-dynamic]',
      '.timestamp',
      '.date-time',
      '.visitor-count',
      '.ad-banner',
      'iframe[src*="google"]',
      'iframe[src*="youtube"]',
    ];

    selectorsToHide.forEach(selector => {
      document.querySelectorAll(selector).forEach(el => {
        el.style.visibility = 'hidden';
      });
    });
  });
}

// =============================================================================
// Desktop Visual Tests
// =============================================================================

test.describe('Production Visual Regression - Desktop', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(VIEWPORTS.desktop);
  });

  for (const theme of THEMES) {
    test.describe(`Theme: ${theme.name}`, () => {
      for (const pageConfig of PAGES) {
        test(`${pageConfig.name} - ${pageConfig.description}`, async ({ page }) => {
          const url = buildUrl(theme.subdomain, pageConfig.path);
          await page.goto(url);
          await waitForPageStable(page);
          await hideDynamicElements(page);

          await expect(page).toHaveScreenshot(
            `${theme.name}-${pageConfig.name}-desktop.png`,
            SCREENSHOT_OPTIONS
          );
        });
      }
    });
  }
});

// =============================================================================
// Mobile Visual Tests
// =============================================================================

test.describe('Production Visual Regression - Mobile', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(VIEWPORTS.mobile);
  });

  for (const theme of THEMES) {
    test.describe(`Theme: ${theme.name}`, () => {
      // Test key pages on mobile
      const mobilePages = PAGES.filter(p =>
        ['home', 'buy', 'contact'].includes(p.name)
      );

      for (const pageConfig of mobilePages) {
        test(`${pageConfig.name} - ${pageConfig.description}`, async ({ page }) => {
          const url = buildUrl(theme.subdomain, pageConfig.path);
          await page.goto(url);
          await waitForPageStable(page);
          await hideDynamicElements(page);

          await expect(page).toHaveScreenshot(
            `${theme.name}-${pageConfig.name}-mobile.png`,
            SCREENSHOT_OPTIONS
          );
        });
      }
    });
  }
});

// =============================================================================
// Tablet Visual Tests
// =============================================================================

test.describe('Production Visual Regression - Tablet', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(VIEWPORTS.tablet);
  });

  // Only test demo theme on tablet to reduce test count
  const theme = THEMES[0];

  for (const pageConfig of PAGES.slice(0, 3)) { // home, home-en, buy
    test(`${theme.name} - ${pageConfig.name}`, async ({ page }) => {
      const url = buildUrl(theme.subdomain, pageConfig.path);
      await page.goto(url);
      await waitForPageStable(page);
      await hideDynamicElements(page);

      await expect(page).toHaveScreenshot(
        `${theme.name}-${pageConfig.name}-tablet.png`,
        SCREENSHOT_OPTIONS
      );
    });
  }
});

// =============================================================================
// Critical Component Tests
// =============================================================================

test.describe('Production Visual Regression - Components', () => {
  const theme = THEMES[0]; // Use demo theme

  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(VIEWPORTS.desktop);
  });

  test('header navigation', async ({ page }) => {
    const url = buildUrl(theme.subdomain, '/en');
    await page.goto(url);
    await waitForPageStable(page);

    const header = page.locator('header').first();
    await expect(header).toHaveScreenshot('component-header.png', {
      animations: 'disabled',
      maxDiffPixelRatio: 0.05,
    });
  });

  test('footer', async ({ page }) => {
    const url = buildUrl(theme.subdomain, '/en');
    await page.goto(url);
    await waitForPageStable(page);

    const footer = page.locator('footer').first();
    await expect(footer).toHaveScreenshot('component-footer.png', {
      animations: 'disabled',
      maxDiffPixelRatio: 0.05,
    });
  });

  test('property card', async ({ page }) => {
    const url = buildUrl(theme.subdomain, '/en/buy');
    await page.goto(url);
    await waitForPageStable(page);

    // Find first property card
    const propertyCard = page.locator('.property-item, .property-card, [data-price]').first();
    if (await propertyCard.count() > 0) {
      await expect(propertyCard).toHaveScreenshot('component-property-card.png', {
        animations: 'disabled',
        maxDiffPixelRatio: 0.1, // Higher tolerance for dynamic content
      });
    }
  });

  test('search filters sidebar', async ({ page }) => {
    const url = buildUrl(theme.subdomain, '/en/buy');
    await page.goto(url);
    await waitForPageStable(page);

    const sidebar = page.locator('#sidebar-filters, .search-filters, aside').first();
    if (await sidebar.count() > 0) {
      await expect(sidebar).toHaveScreenshot('component-search-filters.png', {
        animations: 'disabled',
        maxDiffPixelRatio: 0.05,
      });
    }
  });

  test('hero section', async ({ page }) => {
    const url = buildUrl(theme.subdomain, '/en');
    await page.goto(url);
    await waitForPageStable(page);

    // Try different selectors for hero section
    const hero = page.locator('.hero, [class*="hero"], section:first-of-type').first();
    if (await hero.count() > 0) {
      await expect(hero).toHaveScreenshot('component-hero.png', {
        animations: 'disabled',
        maxDiffPixelRatio: 0.1, // Higher tolerance for background images
      });
    }
  });
});

// =============================================================================
// Property Detail Page Tests
// =============================================================================

test.describe('Production Visual Regression - Property Details', () => {
  const theme = THEMES[0]; // Use demo theme

  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(VIEWPORTS.desktop);
  });

  test('property for sale detail page', async ({ page }) => {
    // First, find a property link from the search page
    const searchUrl = buildUrl(theme.subdomain, '/en/buy');
    await page.goto(searchUrl);
    await waitForPageStable(page);

    const propertyLink = page.locator('a[href*="/properties/for-sale/"]').first();
    if (await propertyLink.count() > 0) {
      await propertyLink.click();
      await waitForPageStable(page);
      await hideDynamicElements(page);

      await expect(page).toHaveScreenshot('property-detail-sale.png', {
        ...SCREENSHOT_OPTIONS,
        maxDiffPixelRatio: 0.15, // Higher tolerance for dynamic property content
      });
    }
  });

  test('property for rent detail page', async ({ page }) => {
    const searchUrl = buildUrl(theme.subdomain, '/en/rent');
    await page.goto(searchUrl);
    await waitForPageStable(page);

    const propertyLink = page.locator('a[href*="/properties/for-rent/"]').first();
    if (await propertyLink.count() > 0) {
      await propertyLink.click();
      await waitForPageStable(page);
      await hideDynamicElements(page);

      await expect(page).toHaveScreenshot('property-detail-rent.png', {
        ...SCREENSHOT_OPTIONS,
        maxDiffPixelRatio: 0.15,
      });
    }
  });
});

// =============================================================================
// Interaction State Tests
// =============================================================================

test.describe('Production Visual Regression - Interactions', () => {
  const theme = THEMES[0];

  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(VIEWPORTS.desktop);
  });

  test('mobile menu open state', async ({ page }) => {
    await page.setViewportSize(VIEWPORTS.mobile);
    const url = buildUrl(theme.subdomain, '/en');
    await page.goto(url);
    await waitForPageStable(page);

    // Click hamburger menu
    const menuButton = page.locator('button[aria-label*="menu"], .hamburger, [data-action*="menu"]').first();
    if (await menuButton.count() > 0) {
      await menuButton.click();
      await page.waitForTimeout(500); // Wait for animation

      await expect(page).toHaveScreenshot('interaction-mobile-menu-open.png', {
        animations: 'disabled',
        maxDiffPixelRatio: 0.05,
      });
    }
  });

  test('search filters applied', async ({ page }) => {
    const url = buildUrl(theme.subdomain, '/en/buy?bedrooms=2&min_price=100000');
    await page.goto(url);
    await waitForPageStable(page);

    await expect(page).toHaveScreenshot('interaction-filtered-results.png', {
      ...SCREENSHOT_OPTIONS,
      maxDiffPixelRatio: 0.1,
    });
  });
});

// =============================================================================
// Cross-Theme Comparison (Smoke Tests)
// =============================================================================

test.describe('Production Visual Regression - Theme Consistency', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(VIEWPORTS.desktop);
  });

  test('all themes render homepage without errors', async ({ page }) => {
    for (const theme of THEMES) {
      const url = buildUrl(theme.subdomain, '/en');
      const response = await page.goto(url);

      // Verify page loads successfully
      expect(response?.status()).toBeLessThan(400);

      // Verify key elements are present
      await expect(page.locator('header')).toBeVisible();
      await expect(page.locator('footer')).toBeVisible();

      // Take a quick screenshot for each theme
      await waitForPageStable(page);
      await expect(page).toHaveScreenshot(
        `theme-smoke-${theme.name}.png`,
        { ...SCREENSHOT_OPTIONS, fullPage: false }
      );
    }
  });
});
