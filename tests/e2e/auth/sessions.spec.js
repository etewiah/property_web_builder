// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');
const { goToTenant, waitForPageLoad } = require('../fixtures/helpers');

/**
 * Sessions Tests
 * Migrated from: spec/features/pwb/sessions_spec.rb
 *
 * Tests user authentication and session management
 */

test.describe('Sessions', () => {
  const tenant = TENANTS.A;
  const admin = ADMIN_USERS.TENANT_A;

  test.describe('Login Form', () => {
    test('login page is accessible', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.LOGIN);

      // Should show login form
      const currentURL = page.url();
      const isLoginPage = currentURL.includes('/sign_in') ||
                          currentURL.includes('/pwb_login') ||
                          currentURL.includes('/login');
      expect(isLoginPage).toBeTruthy();
    });

    test('login form has email and password fields', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.LOGIN);

      // Should have email field
      const emailField = page.locator('input[name="user[email]"], input[type="email"]');
      expect(await emailField.count()).toBeGreaterThan(0);

      // Should have password field
      const passwordField = page.locator('input[name="user[password]"], input[type="password"]');
      expect(await passwordField.count()).toBeGreaterThan(0);
    });

    test('login form has submit button', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.LOGIN);

      // Should have submit button
      const submitButton = page.locator('input[type="submit"], button[type="submit"], button:has-text("Sign in")');
      expect(await submitButton.count()).toBeGreaterThan(0);
    });
  });

  test.describe('Valid Credentials', () => {
    test('successful login redirects to admin', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.LOGIN);

      // Fill in credentials
      const emailField = page.locator('input[name="user[email]"], input[type="email"]').first();
      const passwordField = page.locator('input[name="user[password]"], input[type="password"]').first();

      await emailField.fill(admin.email);
      await passwordField.fill(admin.password);

      // Submit form
      const submitButton = page.locator('input[type="submit"], button[type="submit"], button:has-text("Sign in")').first();
      await submitButton.click();
      await waitForPageLoad(page);

      // Should redirect to admin panel
      const currentURL = page.url();
      const isAdminPage = currentURL.includes('/site_admin') ||
                          currentURL.includes('/admin');
      expect(isAdminPage).toBeTruthy();
    });

    test('successful login shows admin navigation', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.LOGIN);

      // Fill in credentials
      const emailField = page.locator('input[name="user[email]"], input[type="email"]').first();
      const passwordField = page.locator('input[name="user[password]"], input[type="password"]').first();

      await emailField.fill(admin.email);
      await passwordField.fill(admin.password);

      // Submit form
      const submitButton = page.locator('input[type="submit"], button[type="submit"], button:has-text("Sign in")').first();
      await submitButton.click();
      await waitForPageLoad(page);

      // Should show admin content
      const pageContent = await page.content();
      const hasAdminContent = pageContent.includes('Dashboard') ||
                              pageContent.includes('Properties') ||
                              pageContent.includes('Settings') ||
                              pageContent.includes('Admin') ||
                              pageContent.includes('site_admin');
      expect(hasAdminContent).toBeTruthy();
    });
  });

  test.describe('Invalid Credentials', () => {
    test('invalid password shows error message', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.LOGIN);

      // Fill in wrong credentials
      const emailField = page.locator('input[name="user[email]"], input[type="email"]').first();
      const passwordField = page.locator('input[name="user[password]"], input[type="password"]').first();

      await emailField.fill(admin.email);
      await passwordField.fill('wrong-password');

      // Submit form
      const submitButton = page.locator('input[type="submit"], button[type="submit"], button:has-text("Sign in")').first();
      await submitButton.click();
      await waitForPageLoad(page);

      // Should show error message or stay on login page
      const pageContent = await page.content();
      const hasError = pageContent.includes('Invalid') ||
                       pageContent.includes('invalid') ||
                       pageContent.includes('error') ||
                       pageContent.includes('incorrect');
      const stillOnLogin = page.url().includes('/sign_in') ||
                           page.url().includes('/login');

      expect(hasError || stillOnLogin).toBeTruthy();
    });

    test('invalid email shows error message', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.LOGIN);

      // Fill in non-existent email
      const emailField = page.locator('input[name="user[email]"], input[type="email"]').first();
      const passwordField = page.locator('input[name="user[password]"], input[type="password"]').first();

      await emailField.fill('nonexistent@example.com');
      await passwordField.fill('some-password');

      // Submit form
      const submitButton = page.locator('input[type="submit"], button[type="submit"], button:has-text("Sign in")').first();
      await submitButton.click();
      await waitForPageLoad(page);

      // Should show error or stay on login page
      const pageContent = await page.content();
      const hasError = pageContent.includes('Invalid') ||
                       pageContent.includes('invalid') ||
                       pageContent.includes('error');
      const stillOnLogin = page.url().includes('/sign_in') ||
                           page.url().includes('/login');

      expect(hasError || stillOnLogin).toBeTruthy();
    });

    test('empty credentials do not submit', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.LOGIN);

      // Try to submit without filling in credentials
      const submitButton = page.locator('input[type="submit"], button[type="submit"], button:has-text("Sign in")').first();
      await submitButton.click();

      // Should stay on login page (HTML5 validation or server-side)
      const currentURL = page.url();
      const stillOnLogin = currentURL.includes('/sign_in') ||
                           currentURL.includes('/pwb_login') ||
                           currentURL.includes('/login');
      expect(stillOnLogin).toBeTruthy();
    });
  });

  test.describe('Session Persistence', () => {
    test('logged in user can access protected pages', async ({ page }) => {
      await goToTenant(page, tenant, ROUTES.LOGIN);

      // Login
      const emailField = page.locator('input[name="user[email]"], input[type="email"]').first();
      const passwordField = page.locator('input[name="user[password]"], input[type="password"]').first();

      await emailField.fill(admin.email);
      await passwordField.fill(admin.password);

      const submitButton = page.locator('input[type="submit"], button[type="submit"], button:has-text("Sign in")').first();
      await submitButton.click();
      await waitForPageLoad(page);

      // Navigate to protected page
      await page.goto(`${tenant.baseURL}${ROUTES.ADMIN.PROPERTIES}`);
      await waitForPageLoad(page);

      // Should access the page (not redirected to login)
      const currentURL = page.url();
      const hasAccess = currentURL.includes('/props') ||
                        currentURL.includes('/properties') ||
                        currentURL.includes('/site_admin');
      expect(hasAccess).toBeTruthy();
    });
  });
});
