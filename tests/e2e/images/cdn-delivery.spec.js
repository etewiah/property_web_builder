/**
 * E2E Tests for Image CDN Delivery
 *
 * These tests verify that images are served correctly, with proper loading
 * attributes and (in production) from CDN URLs instead of Rails redirect URLs.
 */

const { test, expect } = require('@playwright/test');

test.describe('Image CDN Delivery', () => {
  test.describe('Property Listing Images', () => {
    test('property card images have lazy loading by default', async ({ page }) => {
      await page.goto('/buy');

      // Wait for property cards to load
      const propertyCards = page.locator('.property-card img, [data-property-card] img');

      // Check if there are any property images
      const count = await propertyCards.count();
      if (count > 0) {
        // Check that images below the fold have lazy loading
        // First few images might be eager, but most should be lazy
        const lazyImages = page.locator('img[loading="lazy"]');
        expect(await lazyImages.count()).toBeGreaterThan(0);
      }
    });

    test('property images do not use Rails redirect URLs in production', async ({ page }) => {
      // This test is most meaningful in production/staging environments
      // In development, redirect URLs are expected
      await page.goto('/buy');

      const images = await page.locator('.property-card img, [data-property-card] img').all();

      for (const img of images) {
        const src = await img.getAttribute('src');
        if (src) {
          // In production with CDN configured, should not use redirect URLs
          // This assertion is conditional - in dev it may use redirect URLs
          if (process.env.RAILS_ENV === 'production') {
            expect(src).not.toContain('/rails/active_storage/representations/redirect/');
            expect(src).not.toContain('/rails/active_storage/blobs/redirect/');
          }
        }
      }
    });
  });

  test.describe('Hero Images', () => {
    test('hero images have eager loading for LCP optimization', async ({ page }) => {
      await page.goto('/');

      // Look for hero section images
      const heroImg = page.locator('.hero-section img, [data-hero] img, .hero img').first();

      if (await heroImg.count() > 0) {
        // Hero images should have eager loading for better LCP
        const loading = await heroImg.getAttribute('loading');
        expect(loading).toBe('eager');

        // Should also have high fetch priority
        const fetchPriority = await heroImg.getAttribute('fetchpriority');
        expect(fetchPriority).toBe('high');
      }
    });
  });

  test.describe('Property Detail Images', () => {
    test('first carousel image has eager loading', async ({ page }) => {
      // Navigate to a property detail page
      await page.goto('/buy');

      // Click on first property card to go to detail
      const firstProperty = page.locator('.property-card a, [data-property-card] a').first();
      if (await firstProperty.count() > 0) {
        await firstProperty.click();
        await page.waitForLoadState('domcontentloaded');

        // Check carousel images
        const carouselImages = page.locator('.carousel img, [data-carousel] img, .property-images img');

        if (await carouselImages.count() > 0) {
          // First image should have eager loading
          const firstImg = carouselImages.first();
          const loading = await firstImg.getAttribute('loading');

          // First image should be eager, rest should be lazy
          expect(loading).toBe('eager');
        }
      }
    });

    test('subsequent carousel images have lazy loading', async ({ page }) => {
      await page.goto('/buy');

      const firstProperty = page.locator('.property-card a, [data-property-card] a').first();
      if (await firstProperty.count() > 0) {
        await firstProperty.click();
        await page.waitForLoadState('domcontentloaded');

        const carouselImages = page.locator('.carousel img, [data-carousel] img, .property-images img');
        const count = await carouselImages.count();

        if (count > 1) {
          // Images after the first should have lazy loading
          for (let i = 1; i < Math.min(count, 5); i++) {
            const img = carouselImages.nth(i);
            const loading = await img.getAttribute('loading');
            expect(loading).toBe('lazy');
          }
        }
      }
    });
  });

  test.describe('Image Loading Performance', () => {
    test('images have async decoding', async ({ page }) => {
      await page.goto('/buy');

      // Most images should have async decoding for better performance
      const asyncImages = page.locator('img[decoding="async"]');
      const totalImages = page.locator('img[src]');

      const asyncCount = await asyncImages.count();
      const totalCount = await totalImages.count();

      if (totalCount > 0) {
        // At least half of images should have async decoding
        expect(asyncCount).toBeGreaterThan(totalCount / 2);
      }
    });

    test('images have alt text for accessibility', async ({ page }) => {
      await page.goto('/buy');

      const images = await page.locator('.property-card img, [data-property-card] img').all();

      for (const img of images) {
        const alt = await img.getAttribute('alt');
        // Alt should be present (not null/undefined) but may be empty for decorative images
        expect(alt).not.toBeNull();
      }
    });
  });

  test.describe('CDN URL Format', () => {
    test('image URLs are well-formed', async ({ page }) => {
      await page.goto('/buy');

      const images = await page.locator('img[src]').all();

      for (const img of images) {
        const src = await img.getAttribute('src');
        if (src && !src.startsWith('data:')) {
          // URL should be valid (starts with http/https or /)
          const isValidUrl = src.startsWith('http://') ||
            src.startsWith('https://') ||
            src.startsWith('/');
          expect(isValidUrl).toBe(true);
        }
      }
    });
  });
});

test.describe('Media Library CDN Delivery', () => {
  // These tests require admin authentication
  test.describe.configure({ mode: 'serial' });

  test.beforeEach(async ({ page }) => {
    // Login as admin (adjust credentials as needed for test environment)
    await page.goto('/users/sign_in');

    // Check if already logged in by looking for sign out link
    const signOutLink = page.locator('a[href*="sign_out"]');
    if (await signOutLink.count() === 0) {
      // Need to login
      await page.fill('#user_email', 'admin@example.com');
      await page.fill('#user_password', 'password');
      await page.click('button[type="submit"], input[type="submit"]');
      await page.waitForLoadState('networkidle');
    }
  });

  test('media library thumbnails load correctly', async ({ page }) => {
    await page.goto('/site_admin/media_library');

    // Wait for media grid to load
    await page.waitForSelector('.media-grid img, [data-media-item] img', { timeout: 5000 }).catch(() => null);

    const thumbnails = page.locator('.media-grid img, [data-media-item] img');
    const count = await thumbnails.count();

    if (count > 0) {
      // Thumbnails should have src attributes
      for (let i = 0; i < Math.min(count, 5); i++) {
        const thumb = thumbnails.nth(i);
        const src = await thumb.getAttribute('src');
        expect(src).toBeTruthy();

        // In production, should not use redirect URLs
        if (process.env.RAILS_ENV === 'production') {
          expect(src).not.toContain('/rails/active_storage/representations/redirect/');
        }
      }
    }
  });
});
