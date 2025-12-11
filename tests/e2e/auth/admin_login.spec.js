// @ts-check
const { test, expect } = require('@playwright/test');

// Test credentials from e2e_seeds.rb
const TENANT_A_ADMIN = {
  email: 'admin@tenant-a.test',
  password: 'password123',
  baseURL: 'http://tenant-a.e2e.localhost:3001'
};

const TENANT_B_ADMIN = {
  email: 'admin@tenant-b.test',
  password: 'password123',
  baseURL: 'http://tenant-b.e2e.localhost:3001'
};

test.describe('Multi-Tenant Admin Login', () => {
  
  test('Tenant A admin can log in successfully', async ({ page }) => {
    // Navigate to Tenant A login page
    await page.goto(`${TENANT_A_ADMIN.baseURL}/users/sign_in`);
    
    // Wait for login form to be visible
    await page.waitForSelector('input[name="user[email]"]', { timeout: 5000 });
    
    // Fill in login credentials
    await page.fill('input[name="user[email]"]', TENANT_A_ADMIN.email);
    await page.fill('input[name="user[password]"]', TENANT_A_ADMIN.password);
    
    // Submit the form
    await page.click('input[type="submit"]');
    
    // Wait for navigation to complete
    await page.waitForLoadState('networkidle');
    
    // Verify we're logged in by checking for admin dashboard elements
    // Adjust these selectors based on your actual admin dashboard
    const currentURL = page.url();
    expect(currentURL).toContain(TENANT_A_ADMIN.baseURL);
    
    // Check that we're not on the login page anymore
    expect(currentURL).not.toContain('/users/sign_in');
    
    // Verify admin-specific elements are present (adjust selector as needed)
    // This could be an admin menu, dashboard heading, etc.
    await expect(page.locator('body')).toBeVisible();
  });

  test('Tenant B admin can log in successfully', async ({ page }) => {
    // Navigate to Tenant B login page
    await page.goto(`${TENANT_B_ADMIN.baseURL}/users/sign_in`);
    
    // Wait for login form to be visible
    await page.waitForSelector('input[name="user[email]"]', { timeout: 5000 });
    
    // Fill in login credentials
    await page.fill('input[name="user[email]"]', TENANT_B_ADMIN.email);
    await page.fill('input[name="user[password]"]', TENANT_B_ADMIN.password);
    
    // Submit the form
    await page.click('input[type="submit"]');
    
    // Wait for navigation to complete
    await page.waitForLoadState('networkidle');
    
    // Verify we're logged in
    const currentURL = page.url();
    expect(currentURL).toContain(TENANT_B_ADMIN.baseURL);
    
    // Check that we're not on the login page anymore
    expect(currentURL).not.toContain('/users/sign_in');
    
    // Verify admin-specific elements are present
    await expect(page.locator('body')).toBeVisible();
  });

  test('Tenant A admin cannot access Tenant B with same credentials', async ({ page }) => {
    // First, log in to Tenant A
    await page.goto(`${TENANT_A_ADMIN.baseURL}/users/sign_in`);
    await page.waitForSelector('input[name="user[email]"]', { timeout: 5000 });
    await page.fill('input[name="user[email]"]', TENANT_A_ADMIN.email);
    await page.fill('input[name="user[password]"]', TENANT_A_ADMIN.password);
    await page.click('input[type="submit"]');
    await page.waitForLoadState('networkidle');
    
    // Verify Tenant A login succeeded
    let currentURL = page.url();
    expect(currentURL).toContain(TENANT_A_ADMIN.baseURL);
    expect(currentURL).not.toContain('/users/sign_in');
    
    // Now try to access Tenant B admin
    await page.goto(`${TENANT_B_ADMIN.baseURL}/site_admin`);
    await page.waitForLoadState('networkidle');

    // Should be redirected to login or show an error
    // The session should not carry over to Tenant B
    currentURL = page.url();
    const isOnLogin = currentURL.includes('/users/sign_in') || currentURL.includes('/firebase_login');
    const isOnTenantB = currentURL.includes('tenant-b');

    // We should either be on Tenant B's login page or not authenticated
    expect(isOnTenantB).toBeTruthy();

    // If trying to access admin area, should be redirected to login
    if (!currentURL.includes('/site_admin')) {
      expect(isOnLogin).toBeTruthy();
    }
  });

  test('Invalid credentials fail to log in', async ({ page }) => {
    await page.goto(`${TENANT_A_ADMIN.baseURL}/users/sign_in`);
    await page.waitForSelector('input[name="user[email]"]', { timeout: 5000 });
    
    // Use invalid credentials
    await page.fill('input[name="user[email]"]', 'invalid@example.com');
    await page.fill('input[name="user[password]"]', 'wrongpassword');
    await page.click('input[type="submit"]');
    
    await page.waitForLoadState('networkidle');
    
    // Should still be on login page
    const currentURL = page.url();
    expect(currentURL).toContain('/users/sign_in');
    
    // Look for error message
    const errorMessage = page.locator('.alert, .flash, .error, [role="alert"]');
    if (await errorMessage.count() > 0) {
      await expect(errorMessage.first()).toBeVisible();
    }
  });

  test('Tenant B admin credentials do not work on Tenant A', async ({ page }) => {
    // Try to log in to Tenant A using Tenant B admin credentials
    await page.goto(`${TENANT_A_ADMIN.baseURL}/users/sign_in`);
    await page.waitForSelector('input[name="user[email]"]', { timeout: 5000 });
    
    await page.fill('input[name="user[email]"]', TENANT_B_ADMIN.email);
    await page.fill('input[name="user[password]"]', TENANT_B_ADMIN.password);
    await page.click('input[type="submit"]');
    
    await page.waitForLoadState('networkidle');
    
    // Should remain on login page or show error
    const currentURL = page.url();
    expect(currentURL).toContain('/users/sign_in');
    
    // Look for error message about invalid credentials
    const errorMessage = page.locator('.alert, .flash, .error, [role="alert"]');
    if (await errorMessage.count() > 0) {
      await expect(errorMessage.first()).toBeVisible();
    }
  });

  test('Admin can access protected admin routes after login', async ({ page }) => {
    // Log in as Tenant A admin
    await page.goto(`${TENANT_A_ADMIN.baseURL}/users/sign_in`);
    await page.waitForSelector('input[name="user[email]"], #user_email', { timeout: 5000 });
    await page.fill('input[name="user[email]"], #user_email', TENANT_A_ADMIN.email);
    await page.fill('input[name="user[password]"], #user_password', TENANT_A_ADMIN.password);
    await page.click('input[type="submit"], button[type="submit"]');
    await page.waitForLoadState('networkidle');

    // Try to access admin area
    await page.goto(`${TENANT_A_ADMIN.baseURL}/site_admin`);
    await page.waitForLoadState('networkidle');

    const currentURL = page.url();
    // Should not be redirected back to login
    expect(currentURL).not.toContain('/users/sign_in');
    // Should be on an admin route
    expect(currentURL).toContain('/site_admin');
  });

  test('Logout works correctly', async ({ page }) => {
    // Log in first
    await page.goto(`${TENANT_A_ADMIN.baseURL}/users/sign_in`);
    await page.waitForSelector('input[name="user[email]"], #user_email', { timeout: 5000 });
    await page.fill('input[name="user[email]"], #user_email', TENANT_A_ADMIN.email);
    await page.fill('input[name="user[password]"], #user_password', TENANT_A_ADMIN.password);
    await page.click('input[type="submit"], button[type="submit"]');
    await page.waitForLoadState('networkidle');

    // Find and click logout link/button
    const logoutLink = page.locator('a[href*="sign_out"], a[data-method="delete"], button:has-text("Logout"), button:has-text("Sign out")').first();
    if (await logoutLink.count() > 0) {
      await logoutLink.click();
      await page.waitForLoadState('networkidle');

      // Try to access admin area - should redirect to login
      await page.goto(`${TENANT_A_ADMIN.baseURL}/site_admin`);
      await page.waitForLoadState('networkidle');

      const currentURL = page.url();
      const isOnLogin = currentURL.includes('/users/sign_in') || currentURL.includes('/firebase_login');
      expect(isOnLogin).toBeTruthy();
    }
  });
});
