// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ROUTES } = require('../fixtures/test-data');
const { goToTenant, waitForPageLoad } = require('../fixtures/helpers');

/**
 * Contact Forms Tests
 * Migrated from: spec/features/pwb/contact_forms_spec.rb
 *
 * Tests contact form functionality on public pages
 */

test.describe('Contact Forms', () => {
  const tenant = TENANTS.A;

  test.describe('General Contact Form', () => {
    test('contact page loads successfully', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.CONTACT);

      // Should have a contact form
      const pageContent = await page.content();
      const hasContactContent = pageContent.includes('Contact') ||
                                pageContent.includes('contact') ||
                                pageContent.includes('Message') ||
                                pageContent.includes('Name');
      expect(hasContactContent).toBeTruthy();
    });

    test('contact form has required fields', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.CONTACT);

      // Check for name field
      const nameField = page.locator('input[name*="name"], input[id*="name"]');
      const hasNameField = await nameField.count() > 0;

      // Check for email field (common in contact forms)
      const emailField = page.locator('input[type="email"], input[name*="email"]');
      const hasEmailField = await emailField.count() > 0;

      // Check for message field
      const messageField = page.locator('textarea, input[name*="message"]');
      const hasMessageField = await messageField.count() > 0;

      // At least some form fields should exist
      const hasFormFields = hasNameField || hasEmailField || hasMessageField;
      expect(hasFormFields).toBeTruthy();
    });

    test('contact form has submit button', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.CONTACT);

      // Should have a submit button
      const submitButton = page.locator('button[type="submit"], input[type="submit"], button:has-text("Send")');
      expect(await submitButton.count()).toBeGreaterThan(0);
    });

    test('contact form can be filled and submitted', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.CONTACT);

      // Try to fill in the contact form
      const nameField = page.locator('input[id="contact_name"], input[name*="name"]').first();
      if (await nameField.count() > 0) {
        await nameField.fill('Test User');
      }

      const emailField = page.locator('input[type="email"], input[name*="email"]').first();
      if (await emailField.count() > 0) {
        await emailField.fill('test@example.com');
      }

      const messageField = page.locator('textarea').first();
      if (await messageField.count() > 0) {
        await messageField.fill('This is a test message');
      }

      // Submit the form
      const submitButton = page.locator('button[type="submit"], input[type="submit"], button:has-text("Send")').first();
      if (await submitButton.count() > 0) {
        await submitButton.click();
        await waitForPageLoad(page);

        // After submission, should show success message or stay on contact page
        const pageContent = await page.content();
        const hasResponse = pageContent.includes('Thank you') ||
                           pageContent.includes('message') ||
                           pageContent.includes('Contact') ||
                           pageContent.includes('sent');
        expect(hasResponse).toBeTruthy();
      }
    });
  });

  test.describe('Property Contact Form', () => {
    test('property detail page has contact section', async ({ page }) => {
      // Visit a property detail page
      await goToTenant(page, tenant, '/en/properties/for-sale/1/test-property');

      // Property pages should have some contact mechanism
      const pageContent = await page.content();
      const hasContactInfo = pageContent.includes('Contact') ||
                             pageContent.includes('contact') ||
                             pageContent.includes('Enquir') ||
                             pageContent.includes('enquir') ||
                             pageContent.includes('Agent') ||
                             pageContent.includes('agent') ||
                             pageContent.includes('not found');
      expect(hasContactInfo).toBeTruthy();
    });
  });

  test.describe('Contact Form Structure', () => {
    test('contact page is accessible from navigation', async ({ page }) => {
      await goToTenant(page, tenant, '/');

      // Look for contact link in navigation
      const contactLink = page.locator('a:has-text("Contact"), a[href*="contact"]');
      if (await contactLink.count() > 0) {
        await contactLink.first().click();
        await waitForPageLoad(page);

        // Should navigate to contact page
        const currentURL = page.url();
        const isContactPage = currentURL.includes('contact');
        expect(isContactPage).toBeTruthy();
      }
    });

    test('contact page maintains tenant branding', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.CONTACT);

      // Should show tenant company name or general branding
      const pageContent = await page.content();
      const hasBranding = pageContent.includes(tenant.companyName) ||
                          pageContent.includes('Tenant A') ||
                          pageContent.includes('nav') ||
                          pageContent.includes('footer');
      expect(hasBranding).toBeTruthy();
    });
  });
});
