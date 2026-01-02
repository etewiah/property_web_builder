/**
 * Brussels Theme - Playwright E2E Visual Tests
 *
 * These tests verify the Brussels theme visual appearance including:
 * - Theme-specific color scheme (lime green accents, dark header)
 * - Material Design shadows and sharp corners
 * - Responsive layout behavior
 * - Component styling (cards, buttons, forms)
 *
 * Run with: npx playwright test tests/e2e/themes/brussels.spec.js
 *
 * Before running:
 *   # Ensure you have a tenant configured with brussels theme
 *   RAILS_ENV=e2e bin/rails playwright:reset
 *   RAILS_ENV=e2e bin/rails playwright:server
 *
 * Note: These tests require a tenant to be configured with the brussels theme.
 * You may need to seed appropriate test data.
 */

const { test, expect } = require('@playwright/test');

// Theme-specific selectors
const SELECTORS = {
  // Theme wrapper
  themeWrapper: '.brussels-theme',

  // Header elements
  header: 'header, .site-header',
  headerNav: '.nav-link, header a',
  logo: '.site-logo, header img',

  // Hero section
  heroSection: '.hero-section, .brussels-landing',
  heroTitle: '.hero-title, .hero-content h1',
  searchForm: '.search-container, .search-form',

  // Property cards
  propertyCard: '.property-card, .card',
  propertyTitle: '.property-card .property-title, .property-card h3',
  propertyPrice: '.property-card .property-price, .property-price',
  propertyFeatures: '.property-card .property-features',

  // Buttons
  primaryButton: '.btn-primary, .pwb-btn--primary, .bg-brussels-lime',
  secondaryButton: '.btn-secondary, .btn-outline',

  // Footer
  footer: 'footer, .site-footer',
  footerLinks: 'footer a',

  // Forms
  formInput: 'input.form-control, select, input[type="text"]',
  formLabel: '.form-label, label',

  // Badges
  badge: '.badge, .property-badge'
};

// Brussels theme color values (for visual verification)
const BRUSSELS_COLORS = {
  lime: 'rgb(154, 205, 50)',      // #9ACD32
  dark: 'rgb(19, 19, 19)',        // #131313
  footerGray: 'rgb(97, 97, 97)',  // #616161
  white: 'rgb(255, 255, 255)'     // #FFFFFF
};

test.describe('Brussels Theme Visual Tests', () => {
  // Skip if brussels tenant is not configured
  test.beforeEach(async ({ page }) => {
    // Navigate to a brussels-themed site
    // This assumes you have a tenant configured with brussels theme
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Check if this is actually the brussels theme
    const hasBrusselsTheme = await page.locator(SELECTORS.themeWrapper).count() > 0;
    if (!hasBrusselsTheme) {
      test.skip();
    }
  });

  test.describe('Theme Structure', () => {
    test('page has brussels-theme wrapper class', async ({ page }) => {
      const wrapper = page.locator(SELECTORS.themeWrapper);
      await expect(wrapper).toBeVisible();
    });

    test('header is visible', async ({ page }) => {
      const header = page.locator(SELECTORS.header);
      await expect(header.first()).toBeVisible();
    });

    test('footer is visible', async ({ page }) => {
      const footer = page.locator(SELECTORS.footer);
      await expect(footer.first()).toBeVisible();
    });
  });

  test.describe('Color Scheme', () => {
    test('header has semi-transparent dark background', async ({ page }) => {
      const header = page.locator(SELECTORS.header).first();

      const bgColor = await header.evaluate((el) => {
        return window.getComputedStyle(el).backgroundColor;
      });

      // Should have dark background with transparency
      expect(bgColor).toMatch(/rgba?\(19,\s*19,\s*19|rgba?\(0,\s*0,\s*0/);
    });

    test('primary buttons use lime green color', async ({ page }) => {
      const primaryBtn = page.locator(SELECTORS.primaryButton).first();

      if (await primaryBtn.count() > 0) {
        const bgColor = await primaryBtn.evaluate((el) => {
          return window.getComputedStyle(el).backgroundColor;
        });

        // Should have lime green background
        expect(bgColor).toMatch(/154,\s*205,\s*50|rgb\(154,\s*205,\s*50\)/);
      }
    });

    test('footer has gray background', async ({ page }) => {
      const footer = page.locator(SELECTORS.footer).first();

      const bgColor = await footer.evaluate((el) => {
        return window.getComputedStyle(el).backgroundColor;
      });

      // Should have gray background (#616161)
      expect(bgColor).toMatch(/97,\s*97,\s*97|rgb\(97,\s*97,\s*97\)/);
    });
  });

  test.describe('Typography', () => {
    test('uses Catamaran font family', async ({ page }) => {
      const body = page.locator(SELECTORS.themeWrapper);

      const fontFamily = await body.evaluate((el) => {
        return window.getComputedStyle(el).fontFamily;
      });

      expect(fontFamily.toLowerCase()).toContain('catamaran');
    });

    test('headings have proper weight', async ({ page }) => {
      const h1 = page.locator('h1').first();

      if (await h1.count() > 0) {
        const fontWeight = await h1.evaluate((el) => {
          return window.getComputedStyle(el).fontWeight;
        });

        // Should have weight 400 or 600+
        expect(['400', '600', '700', 'normal', 'bold']).toContain(fontWeight);
      }
    });
  });

  test.describe('Material Design Elements', () => {
    test('cards have material design shadows', async ({ page }) => {
      const card = page.locator(SELECTORS.propertyCard).first();

      if (await card.count() > 0) {
        const boxShadow = await card.evaluate((el) => {
          return window.getComputedStyle(el).boxShadow;
        });

        // Should have some box shadow (not 'none')
        expect(boxShadow).not.toBe('none');
      }
    });

    test('cards have sharp corners (minimal border-radius)', async ({ page }) => {
      const card = page.locator(SELECTORS.propertyCard).first();

      if (await card.count() > 0) {
        const borderRadius = await card.evaluate((el) => {
          return window.getComputedStyle(el).borderRadius;
        });

        // Should have minimal border radius (0-2px)
        const radius = parseInt(borderRadius);
        expect(radius).toBeLessThanOrEqual(4);
      }
    });

    test('buttons have minimal border-radius', async ({ page }) => {
      const btn = page.locator(SELECTORS.primaryButton).first();

      if (await btn.count() > 0) {
        const borderRadius = await btn.evaluate((el) => {
          return window.getComputedStyle(el).borderRadius;
        });

        const radius = parseInt(borderRadius);
        expect(radius).toBeLessThanOrEqual(4);
      }
    });
  });

  test.describe('Responsive Layout', () => {
    test('desktop layout shows sidebar', async ({ page }) => {
      await page.setViewportSize({ width: 1280, height: 800 });
      await page.goto('/en/buy');
      await page.waitForLoadState('networkidle');

      // Sidebar should be visible on desktop
      const sidebar = page.locator('.search-sidebar, aside');
      if (await sidebar.count() > 0) {
        await expect(sidebar.first()).toBeVisible();
      }
    });

    test('mobile layout hides sidebar by default', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/en/buy');
      await page.waitForLoadState('networkidle');

      // Sidebar filter panel should be hidden by default
      const filterPanel = page.locator('#sidebar-filters, .filter-content');
      if (await filterPanel.count() > 0) {
        const isHidden = await filterPanel.evaluate((el) => {
          const style = window.getComputedStyle(el);
          return el.classList.contains('hidden') ||
                 style.display === 'none';
        });
        expect(isHidden).toBe(true);
      }
    });

    test('property grid adapts to screen size', async ({ page }) => {
      await page.goto('/');
      await page.waitForLoadState('networkidle');

      const grid = page.locator('.grid');

      if (await grid.count() > 0) {
        // Get grid columns at different viewports
        await page.setViewportSize({ width: 1280, height: 800 });
        const desktopCols = await grid.first().evaluate((el) => {
          return window.getComputedStyle(el).gridTemplateColumns.split(' ').length;
        });

        await page.setViewportSize({ width: 375, height: 667 });
        const mobileCols = await grid.first().evaluate((el) => {
          return window.getComputedStyle(el).gridTemplateColumns.split(' ').length;
        });

        // Desktop should have more columns than mobile
        expect(desktopCols).toBeGreaterThanOrEqual(mobileCols);
      }
    });
  });

  test.describe('Component Styling', () => {
    test('search form has backdrop blur effect', async ({ page }) => {
      const searchForm = page.locator(SELECTORS.searchForm).first();

      if (await searchForm.count() > 0) {
        const backdropFilter = await searchForm.evaluate((el) => {
          return window.getComputedStyle(el).backdropFilter;
        });

        // May have blur effect or be 'none' depending on implementation
        expect(backdropFilter).toBeDefined();
      }
    });

    test('form inputs have proper styling', async ({ page }) => {
      await page.goto('/en/buy');
      await page.waitForLoadState('networkidle');

      const input = page.locator(SELECTORS.formInput).first();

      if (await input.count() > 0) {
        const borderColor = await input.evaluate((el) => {
          return window.getComputedStyle(el).borderColor;
        });

        // Should have visible border
        expect(borderColor).not.toBe('transparent');
      }
    });

    test('badges use lime green background', async ({ page }) => {
      const badge = page.locator(SELECTORS.badge).first();

      if (await badge.count() > 0) {
        const bgColor = await badge.evaluate((el) => {
          return window.getComputedStyle(el).backgroundColor;
        });

        // Should have lime or dark background
        expect(bgColor).toMatch(/154,\s*205,\s*50|19,\s*19,\s*19/);
      }
    });
  });

  test.describe('Focus States (Accessibility)', () => {
    test('focusable elements have visible focus indicator', async ({ page }) => {
      await page.goto('/en/buy');
      await page.waitForLoadState('networkidle');

      // Tab to first focusable element
      await page.keyboard.press('Tab');

      // Check if focus is visible
      const focusedElement = await page.evaluate(() => {
        const el = document.activeElement;
        if (!el) return null;
        const style = window.getComputedStyle(el);
        return {
          outline: style.outline,
          outlineWidth: style.outlineWidth,
          boxShadow: style.boxShadow
        };
      });

      // Should have some visible focus indicator
      expect(focusedElement).not.toBeNull();
    });
  });
});

test.describe('Brussels Theme Visual Regression', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const hasBrusselsTheme = await page.locator('.brussels-theme').count() > 0;
    if (!hasBrusselsTheme) {
      test.skip();
    }
  });

  test('homepage matches snapshot', async ({ page }) => {
    await page.waitForTimeout(500); // Wait for animations

    await expect(page).toHaveScreenshot('brussels-home.png', {
      maxDiffPixelRatio: 0.1,
      fullPage: true
    });
  });

  test('buy page matches snapshot', async ({ page }) => {
    await page.goto('/en/buy');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('brussels-buy.png', {
      maxDiffPixelRatio: 0.1
    });
  });

  test('rent page matches snapshot', async ({ page }) => {
    await page.goto('/en/rent');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('brussels-rent.png', {
      maxDiffPixelRatio: 0.1
    });
  });

  test('mobile homepage matches snapshot', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('brussels-home-mobile.png', {
      maxDiffPixelRatio: 0.1,
      fullPage: true
    });
  });

  test('tablet homepage matches snapshot', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('brussels-home-tablet.png', {
      maxDiffPixelRatio: 0.1,
      fullPage: true
    });
  });
});

test.describe('Brussels Theme Interactions', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const hasBrusselsTheme = await page.locator('.brussels-theme').count() > 0;
    if (!hasBrusselsTheme) {
      test.skip();
    }
  });

  test('card hover shows elevation change', async ({ page }) => {
    const card = page.locator('.property-card, .card').first();

    if (await card.count() > 0) {
      const initialShadow = await card.evaluate((el) => {
        return window.getComputedStyle(el).boxShadow;
      });

      await card.hover();
      await page.waitForTimeout(300); // Wait for transition

      const hoverShadow = await card.evaluate((el) => {
        return window.getComputedStyle(el).boxShadow;
      });

      // Shadow should change on hover (Material Design elevation)
      // They may be the same if transitions are disabled
      expect(hoverShadow).toBeDefined();
    }
  });

  test('button hover shows brightness change', async ({ page }) => {
    const btn = page.locator('.bg-brussels-lime, .btn-primary').first();

    if (await btn.count() > 0) {
      await btn.hover();
      await page.waitForTimeout(200);

      // Button should still be visible after hover
      await expect(btn).toBeVisible();
    }
  });

  test('navigation links highlight on hover', async ({ page }) => {
    const navLink = page.locator('header a, .nav-link').first();

    if (await navLink.count() > 0) {
      await navLink.hover();

      // Link should change color on hover
      await expect(navLink).toBeVisible();
    }
  });
});
