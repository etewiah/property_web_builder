// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Multi-Tenant Admin Login Tests
 *
 * SKIPPED: These tests are designed to test actual authentication flows
 * and are not compatible with BYPASS_ADMIN_AUTH=true mode.
 *
 * Authentication should be tested via:
 * - Unit tests (spec/controllers/pwb/devise/*_spec.rb)
 * - Integration tests (spec/requests/*_spec.rb)
 *
 * E2E tests assume BYPASS_ADMIN_AUTH=true to focus on UI functionality.
 */

test.describe.skip('Multi-Tenant Admin Login', () => {
  // These tests require actual authentication which is bypassed in e2e mode
  // See: spec/controllers/pwb/devise/sessions_controller_spec.rb for auth tests

  test('Tenant A admin can log in successfully', async ({ page }) => {
    // Skipped - authentication is bypassed in e2e tests
  });

  test('Tenant B admin can log in successfully', async ({ page }) => {
    // Skipped - authentication is bypassed in e2e tests
  });

  test('Tenant A admin cannot access Tenant B with same credentials', async ({ page }) => {
    // Skipped - authentication is bypassed in e2e tests
  });

  test('Invalid credentials fail to log in', async ({ page }) => {
    // Skipped - authentication is bypassed in e2e tests
  });

  test('Tenant B admin credentials do not work on Tenant A', async ({ page }) => {
    // Skipped - authentication is bypassed in e2e tests
  });

  test('Admin can access protected admin routes after login', async ({ page }) => {
    // Skipped - authentication is bypassed in e2e tests
  });

  test('Logout works correctly', async ({ page }) => {
    // Skipped - authentication is bypassed in e2e tests
  });
});
