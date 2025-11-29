# Playwright E2E Testing Guide

This document describes how to run end-to-end tests using Playwright with a dedicated test environment.

## Overview

The project uses a separate `e2e` Rails environment for Playwright tests. This keeps test data isolated from development and provides a clean, reproducible testing environment.

## Quick Start

### 1. Setup E2E Environment

```bash
# Create and migrate the E2E database
RAILS_ENV=e2e bin/rails db:create db:migrate

# Seed test data
RAILS_ENV=e2e bin/rails playwright:reset
```

### 2. Start E2E Server

```bash
# Start Rails server on port 3001
RAILS_ENV=e2e bin/rails playwright:server
```

The server will be available at:
- **Tenant A**: http://tenant-a.e2e.localhost:3001
- **Tenant B**: http://tenant-b.e2e.localhost:3001

### 3. Run Playwright Tests

In a separate terminal:

```bash
# Run all E2E tests
npx playwright test

# Run specific test file
npx playwright test tests/e2e/auth.spec.js

# Run with UI
npx playwright test --ui

# Run in headed mode (see browser)
npx playwright test --headed
```

## Test Data

The E2E environment is seeded with predictable test data:

### Test Users

| Email | Password | Website | Role |
|-------|----------|---------|------|
| `admin@tenant-a.test` | `password123` | Tenant A | Admin |
| `user@tenant-a.test` | `password123` | Tenant A | User |
| `admin@tenant-b.test` | `password123` | Tenant B | Admin |
| `user@tenant-b.test` | `password123` | Tenant B | User |

### Test Tenants

- **Tenant A**: `tenant-a` subdomain
- **Tenant B**: `tenant-b` subdomain

## Available Rake Tasks

```bash
# Reset database and reseed test data
RAILS_ENV=e2e bin/rails playwright:reset

# Seed test data without resetting
RAILS_ENV=e2e bin/rails playwright:seed

# Start server for E2E testing
RAILS_ENV=e2e bin/rails playwright:server
```

## Environment Details

- **Environment**: `e2e`
- **Database**: `pwb_e2e`
- **Port**: `3001`
- **Configuration**: `config/environments/e2e.rb`
- **Seed File**: `db/seeds/e2e_seeds.rb`

## Writing Tests

Tests should use the seeded test data:

```javascript
const USER_A = {
  email: 'admin@tenant-a.test',
  password: 'password123'
};

test('User can log in', async ({ page }) => {
  await page.goto('http://tenant-a.e2e.localhost:3001/users/sign_in');
  await page.fill('#user_email', USER_A.email);
  await page.fill('#user_password', USER_A.password);
  await page.click('input[type="submit"]');
  // ... assertions
});
```

## Troubleshooting

### Database Issues

If you encounter database issues:

```bash
# Drop and recreate everything
RAILS_ENV=e2e bin/rails db:drop db:create db:migrate
RAILS_ENV=e2e bin/rails playwright:seed
```

### Port Already in Use

If port 3001 is already in use:

```bash
# Find and kill the process
lsof -ti:3001 | xargs kill -9

# Or use a different port
RAILS_ENV=e2e bin/rails s -p 3002
```

Remember to update the PORT in your test files if using a different port.

### Subdomain Resolution

If subdomains don't resolve:

- Ensure entries exist in `config/environments/e2e.rb`:
  ```ruby
  config.hosts << "tenant-a.e2e.localhost"
  config.hosts << "tenant-b.e2e.localhost"
  config.action_dispatch.tld_length = 2
  ```

- On Mac/Linux, `*.localhost` should resolve to `127.0.0.1` automatically
- On Windows, you may need to add entries to your hosts file

## CI/CD Integration

For CI pipelines:

```bash
# Setup
RAILS_ENV=e2e bin/rails db:create db:migrate playwright:seed

# Start server in background
RAILS_ENV=e2e bin/rails s -p 3001 -d

# Run tests
npx playwright test

# Cleanup
pkill -f "rails s"
```

## Best Practices

1. **Always use the e2e environment** for Playwright tests
2. **Reset data between test runs** if tests modify data
3. **Use descriptive test data** that's easy to identify in tests
4. **Keep tests independent** - don't rely on test execution order
5. **Clean up after tests** if they create data

## Further Reading

- [Playwright Documentation](https://playwright.dev)
- [Rails Environments Guide](https://guides.rubyonrails.org/configuring.html#rails-environment-settings)
