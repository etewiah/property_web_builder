// @ts-check
const { execSync } = require('child_process');

/**
 * Global setup for Playwright E2E tests
 * Verifies that the e2e database has been properly initialized
 *
 * Run this command before running tests for the first time:
 *   RAILS_ENV=e2e bin/rails playwright:reset
 */
async function globalSetup() {
  console.log('\nChecking E2E database setup...');

  try {
    // Check if tenant-a website exists in the e2e database
    const result = execSync(
      'RAILS_ENV=e2e bundle exec rails runner "exit(Pwb::Website.where(subdomain: \'tenant-a\').exists? ? 0 : 1)"',
      {
        cwd: process.cwd(),
        stdio: ['pipe', 'pipe', 'pipe'],
        timeout: 30000
      }
    );
    console.log('E2E database is ready.\n');
  } catch (error) {
    console.error('\n');
    console.error('='.repeat(70));
    console.error('ERROR: E2E database is not set up properly!');
    console.error('='.repeat(70));
    console.error('\nThe test database appears to be missing required seed data.');
    console.error('Please run the following command before running Playwright tests:\n');
    console.error('    RAILS_ENV=e2e bin/rails playwright:reset\n');
    console.error('This will reset the e2e database and load the test fixtures.\n');
    console.error('='.repeat(70));
    console.error('\n');
    process.exit(1);
  }
}

module.exports = globalSetup;
