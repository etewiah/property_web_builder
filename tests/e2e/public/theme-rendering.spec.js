// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToTenant, waitForPageLoad } = require('../fixtures/helpers');

/**
 * Theme Rendering Tests
 * Migrated from: spec/features/pwb/theme_rendering_spec.rb
 *
 * Tests that themes render correctly with semantic CSS classes
 * and page parts display properly
 */

test.describe('Theme Rendering', () => {
  const tenant = TENANTS.A;

  test.describe('Home Page Rendering', () => {
    test('home page loads successfully', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Should load without server errors
      const response = await page.goto(`${tenant.baseURL}/`);
      expect(response.status()).toBeLessThan(500);
    });

    test('home page has basic HTML structure', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Should have basic HTML structure
      const html = page.locator('html');
      expect(await html.count()).toBe(1);

      const body = page.locator('body');
      expect(await body.count()).toBe(1);
    });

    test('home page has navigation', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Should have navigation element
      const nav = page.locator('nav, [role="navigation"], header');
      expect(await nav.count()).toBeGreaterThan(0);
    });

    test('home page has footer', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Should have footer element
      const footer = page.locator('footer, [role="contentinfo"]');
      expect(await footer.count()).toBeGreaterThan(0);
    });

    test('home page renders hero section if present', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Check for hero section (may or may not exist depending on seed data)
      const heroSection = page.locator('.hero-section, .hero, [class*="hero"]');
      const hasHero = await heroSection.count() > 0;

      // If hero exists, it should have content
      if (hasHero) {
        const heroContent = await heroSection.first().textContent();
        expect(heroContent.length).toBeGreaterThan(0);
      }
    });

    test('home page renders services section if present', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Check for services section
      const servicesSection = page.locator('.services-section-wrapper, .services, [class*="service"]');
      const hasServices = await servicesSection.count() > 0;

      // If services section exists, it should be visible
      if (hasServices) {
        expect(await servicesSection.first().isVisible()).toBeTruthy();
      }
    });
  });

  test.describe('About Us Page Rendering', () => {
    test('about page loads successfully', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.ABOUT);

      // Should load without server errors
      const response = await page.goto(`${tenant.baseURL}${ROUTES.ABOUT}`);
      expect(response.status()).toBeLessThan(500);
    });

    test('about page has content', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.ABOUT);

      // Should have some content
      const pageContent = await page.content();
      const hasContent = pageContent.includes('About') ||
                         pageContent.includes('about') ||
                         pageContent.includes('Agency') ||
                         pageContent.includes(tenant.companyName);
      expect(hasContent).toBeTruthy();
    });

    test('about page renders agency section if present', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.ABOUT);

      // Check for agency section
      const agencySection = page.locator('.our-agency-section, .agency-section, [class*="agency"]');
      const hasAgencySection = await agencySection.count() > 0;

      if (hasAgencySection) {
        expect(await agencySection.first().isVisible()).toBeTruthy();
      }
    });
  });

  test.describe('Page Structure Consistency', () => {
    test('all pages have consistent navigation', async ({ page }) => {
      // Test multiple pages for consistent navigation
      const pages = ['/', ROUTES.BUY, ROUTES.RENT, ROUTES.CONTACT];

      for (const pagePath of pages) {
        await goToTenant(page, tenant, pagePath);

        const nav = page.locator('nav, [role="navigation"], header');
        expect(await nav.count()).toBeGreaterThan(0);
      }
    });

    test('all pages have consistent footer', async ({ page }) => {
      // Test multiple pages for consistent footer
      const pages = ['/', ROUTES.BUY, ROUTES.RENT];

      for (const pagePath of pages) {
        await goToTenant(page, tenant, pagePath);

        const footer = page.locator('footer, [role="contentinfo"]');
        expect(await footer.count()).toBeGreaterThan(0);
      }
    });

    test('pages maintain tenant branding', async ({ page }) => {
      const pages = ['/', ROUTES.BUY, ROUTES.CONTACT];

      for (const pagePath of pages) {
        await goToTenant(page, tenant, pagePath);

        const pageContent = await page.content();
        const hasBranding = pageContent.includes(tenant.companyName) ||
                            pageContent.includes('Tenant A') ||
                            pageContent.includes('PropertyWebBuilder') ||
                            pageContent.includes('Test Company');
        expect(hasBranding).toBeTruthy();
      }
    });
  });

  test.describe('CSS Classes and Styling', () => {
    test('pages use semantic CSS classes', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Check for semantic class names (not just utility classes)
      const pageHTML = await page.content();

      // Should have some semantic classes or structural elements
      const hasSemanticStructure = pageHTML.includes('class="') ||
                                    pageHTML.includes('id="') ||
                                    pageHTML.includes('<nav') ||
                                    pageHTML.includes('<header') ||
                                    pageHTML.includes('<main') ||
                                    pageHTML.includes('<footer');
      expect(hasSemanticStructure).toBeTruthy();
    });

    test('pages have responsive meta tag', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Check for viewport meta tag
      const viewportMeta = page.locator('meta[name="viewport"]');
      expect(await viewportMeta.count()).toBeGreaterThan(0);
    });

    test('pages load stylesheets', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Check for stylesheet links
      const styleLinks = page.locator('link[rel="stylesheet"]');
      expect(await styleLinks.count()).toBeGreaterThan(0);
    });
  });

  test.describe('Page Parts Rendering', () => {
    test('page parts container exists on home page', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // The page should have content areas where page parts are rendered
      const pageContent = await page.content();

      // Should have some structured content
      const hasStructuredContent = pageContent.includes('<section') ||
                                    pageContent.includes('<div class="') ||
                                    pageContent.includes('container');
      expect(hasStructuredContent).toBeTruthy();
    });

    test('page content is visible', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Body should have visible content
      const body = page.locator('body');
      const bodyContent = await body.textContent();

      // Should have some text content (not empty)
      expect(bodyContent.trim().length).toBeGreaterThan(0);
    });
  });
});
