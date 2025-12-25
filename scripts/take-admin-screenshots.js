#!/usr/bin/env node
/**
 * Admin Screenshot capture script for PropertyWebBuilder
 * Takes screenshots of all admin pages (site_admin and tenant_admin)
 * Requires authentication - will log in automatically
 *
 * Usage:
 *   node scripts/take-admin-screenshots.js
 *   PHASE=1 node scripts/take-admin-screenshots.js
 *   INCLUDE_MOBILE=true node scripts/take-admin-screenshots.js
 */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// Try to load sharp for compression
let sharp;
try {
  sharp = require('sharp');
} catch (e) {
  console.log('Note: sharp not installed. Run "npm install sharp" to enable auto-compression.');
}

// Configuration
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const SCREENSHOT_DIR = path.join(__dirname, '..', 'docs', 'screenshots', 'dev', 'admin');
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'pwb123456';
const PHASE = process.env.PHASE ? parseInt(process.env.PHASE) : null;
const INCLUDE_MOBILE = process.env.INCLUDE_MOBILE === 'true';
const DEBUG = process.env.DEBUG === 'true';
const VERBOSE = process.env.VERBOSE === 'true';
const MAX_SIZE_MB = parseFloat(process.env.MAX_SIZE_MB || '2');
const MAX_SIZE_BYTES = MAX_SIZE_MB * 1024 * 1024;

// Viewports
const VIEWPORTS = {
  desktop: { name: 'desktop', width: 1440, height: 900 },
  mobile: { name: 'mobile', width: 375, height: 812 },
};

// Max dimensions for compression
const MAX_DESKTOP_WIDTH = 1440;
const MAX_MOBILE_WIDTH = 750;

// ============================================================================
// ADMIN PAGES CONFIGURATION
// ============================================================================

// Phase 1: High Priority - Core admin functionality
const PHASE_1_SITE_ADMIN = [
  { name: 'dashboard/index', path: '/site_admin', description: 'Dashboard' },
  { name: 'properties/list', path: '/site_admin/props', description: 'Properties List' },
  { name: 'properties/edit-general', path: '/site_admin/props/:prop_id/edit/general', dynamic: 'prop' },
  { name: 'properties/edit-photos', path: '/site_admin/props/:prop_id/edit/photos', dynamic: 'prop' },
  { name: 'pages/list', path: '/site_admin/pages', description: 'Pages List' },
  { name: 'pages/edit', path: '/site_admin/pages/:page_id/edit', dynamic: 'page' },
  { name: 'settings/general', path: '/site_admin/website/settings/general', description: 'Settings General' },
  { name: 'settings/appearance', path: '/site_admin/website/settings/appearance', description: 'Settings Appearance' },
  { name: 'settings/navigation', path: '/site_admin/website/settings/navigation', description: 'Settings Navigation' },
  { name: 'onboarding/step1-welcome', path: '/site_admin/onboarding/1', description: 'Onboarding Welcome' },
  { name: 'onboarding/step4-theme', path: '/site_admin/onboarding/4', description: 'Onboarding Theme' },
];

const PHASE_1_TENANT_ADMIN = [
  { name: 'dashboard/index', path: '/tenant_admin', description: 'Dashboard' },
  { name: 'websites/list', path: '/tenant_admin/websites', description: 'Websites List' },
  { name: 'websites/show', path: '/tenant_admin/websites/:website_id', dynamic: 'website' },
  { name: 'subscriptions/list', path: '/tenant_admin/subscriptions', description: 'Subscriptions List' },
  { name: 'subscriptions/show', path: '/tenant_admin/subscriptions/:subscription_id', dynamic: 'subscription' },
  { name: 'plans/list', path: '/tenant_admin/plans', description: 'Plans List' },
  { name: 'plans/edit', path: '/tenant_admin/plans/:plan_id/edit', dynamic: 'plan' },
  { name: 'users/list', path: '/tenant_admin/users', description: 'Users List' },
  { name: 'audit-logs/list', path: '/tenant_admin/auth_audit_logs', description: 'Auth Audit Logs' },
];

// Phase 2: Medium Priority - Secondary pages
const PHASE_2_SITE_ADMIN = [
  { name: 'analytics/overview', path: '/site_admin/analytics', description: 'Analytics Overview' },
  { name: 'analytics/traffic', path: '/site_admin/analytics/traffic', description: 'Analytics Traffic' },
  { name: 'analytics/properties', path: '/site_admin/analytics/properties', description: 'Analytics Properties' },
  { name: 'analytics/conversions', path: '/site_admin/analytics/conversions', description: 'Analytics Conversions' },
  { name: 'email-templates/list', path: '/site_admin/email_templates', description: 'Email Templates' },
  { name: 'properties/edit-text', path: '/site_admin/props/:prop_id/edit/text', dynamic: 'prop' },
  { name: 'properties/edit-sale-rental', path: '/site_admin/props/:prop_id/edit/sale_rental', dynamic: 'prop' },
  { name: 'properties/edit-location', path: '/site_admin/props/:prop_id/edit/location', dynamic: 'prop' },
  { name: 'properties/edit-labels', path: '/site_admin/props/:prop_id/edit/labels', dynamic: 'prop' },
  { name: 'settings/home', path: '/site_admin/website/settings/home', description: 'Settings Home' },
  { name: 'settings/notifications', path: '/site_admin/website/settings/notifications', description: 'Settings Notifications' },
  { name: 'onboarding/step2-profile', path: '/site_admin/onboarding/2', description: 'Onboarding Profile' },
  { name: 'onboarding/step3-property', path: '/site_admin/onboarding/3', description: 'Onboarding Property' },
  { name: 'onboarding/step5-complete', path: '/site_admin/onboarding/5', description: 'Onboarding Complete' },
];

const PHASE_2_TENANT_ADMIN = [
  { name: 'websites/new', path: '/tenant_admin/websites/new', description: 'New Website' },
  { name: 'websites/edit', path: '/tenant_admin/websites/:website_id/edit', dynamic: 'website' },
  { name: 'subscriptions/new', path: '/tenant_admin/subscriptions/new', description: 'New Subscription' },
  { name: 'subscriptions/edit', path: '/tenant_admin/subscriptions/:subscription_id/edit', dynamic: 'subscription' },
  { name: 'plans/new', path: '/tenant_admin/plans/new', description: 'New Plan' },
  { name: 'plans/show', path: '/tenant_admin/plans/:plan_id', dynamic: 'plan' },
  { name: 'domains/list', path: '/tenant_admin/domains', description: 'Domains List' },
  { name: 'subdomains/list', path: '/tenant_admin/subdomains', description: 'Subdomains List' },
  { name: 'users/show', path: '/tenant_admin/users/:user_id', dynamic: 'user' },
  { name: 'audit-logs/show', path: '/tenant_admin/auth_audit_logs/:audit_log_id', dynamic: 'audit_log' },
  { name: 'agencies/list', path: '/tenant_admin/agencies', description: 'Agencies List' },
];

// Phase 3: Complete Coverage
const PHASE_3_SITE_ADMIN = [
  { name: 'properties/show', path: '/site_admin/props/:prop_id', dynamic: 'prop' },
  { name: 'pages/show', path: '/site_admin/pages/:page_id', dynamic: 'page' },
  { name: 'pages/settings', path: '/site_admin/pages/:page_id/settings', dynamic: 'page' },
  { name: 'contents/list', path: '/site_admin/contents', description: 'Contents List' },
  { name: 'users/list', path: '/site_admin/users', description: 'Users List' },
  { name: 'messages/list', path: '/site_admin/messages', description: 'Messages List' },
  { name: 'contacts/list', path: '/site_admin/contacts', description: 'Contacts List' },
  { name: 'storage-stats/index', path: '/site_admin/storage_stats', description: 'Storage Stats' },
  { name: 'domain/index', path: '/site_admin/domain', description: 'Domain Settings' },
  { name: 'properties-settings/index', path: '/site_admin/properties/settings', description: 'Properties Settings' },
];

const PHASE_3_TENANT_ADMIN = [
  { name: 'users/new', path: '/tenant_admin/users/new', description: 'New User' },
  { name: 'users/edit', path: '/tenant_admin/users/:user_id/edit', dynamic: 'user' },
  { name: 'domains/show', path: '/tenant_admin/domains/:domain_id', dynamic: 'domain' },
  { name: 'subdomains/new', path: '/tenant_admin/subdomains/new', description: 'New Subdomain' },
  { name: 'subdomains/show', path: '/tenant_admin/subdomains/:subdomain_id', dynamic: 'subdomain' },
  { name: 'agencies/show', path: '/tenant_admin/agencies/:agency_id', dynamic: 'agency' },
  { name: 'agencies/new', path: '/tenant_admin/agencies/new', description: 'New Agency' },
  { name: 'email-templates/list', path: '/tenant_admin/email_templates', description: 'Email Templates' },
];

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function log(message, ...args) {
  console.log(message, ...args);
}

function verbose(message, ...args) {
  if (VERBOSE) {
    console.log(`  [verbose] ${message}`, ...args);
  }
}

async function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
    verbose(`Created directory: ${dirPath}`);
  }
}

async function getFileSizeMB(filepath) {
  const stats = fs.statSync(filepath);
  return stats.size / (1024 * 1024);
}

async function compressImage(filepath, isMobile = false) {
  if (!sharp) return;

  const originalSize = await getFileSizeMB(filepath);
  if (originalSize <= MAX_SIZE_MB) {
    return;
  }

  log(`    Compressing ${path.basename(filepath)} (${originalSize.toFixed(2)}MB)...`);

  const maxWidth = isMobile ? MAX_MOBILE_WIDTH : MAX_DESKTOP_WIDTH;
  const tempPath = filepath.replace('.png', '.temp.png');

  try {
    let image = sharp(filepath);
    const metadata = await image.metadata();

    if (metadata.width > maxWidth) {
      image = image.resize(maxWidth, null, {
        withoutEnlargement: true,
        fit: 'inside'
      });
    }

    await image
      .png({
        compressionLevel: 9,
        adaptiveFiltering: true,
        palette: true,
        quality: 80
      })
      .toFile(tempPath);

    let newSize = await getFileSizeMB(tempPath);

    if (newSize > MAX_SIZE_MB) {
      await sharp(filepath)
        .resize(Math.floor(maxWidth * 0.8), null, { withoutEnlargement: true, fit: 'inside' })
        .png({
          compressionLevel: 9,
          palette: true,
          colors: 128
        })
        .toFile(tempPath);

      newSize = await getFileSizeMB(tempPath);
    }

    fs.unlinkSync(filepath);
    fs.renameSync(tempPath, filepath);

    log(`    Compressed to ${newSize.toFixed(2)}MB`);

  } catch (error) {
    if (fs.existsSync(tempPath)) {
      fs.unlinkSync(tempPath);
    }
    console.error(`    Compression failed: ${error.message}`);
  }
}

// ============================================================================
// AUTHENTICATION
// ============================================================================

async function login(page) {
  log('Logging in...');

  try {
    await page.goto(`${BASE_URL}/users/sign_in`, { waitUntil: 'networkidle', timeout: 30000 });

    // Fill in login form
    await page.fill('input[name="user[email]"]', ADMIN_EMAIL);
    await page.fill('input[name="user[password]"]', ADMIN_PASSWORD);

    // Submit form
    await page.click('input[type="submit"], button[type="submit"]');

    // Wait for redirect
    await page.waitForURL(url => !url.pathname.includes('sign_in'), { timeout: 10000 });

    log('Login successful!');
    return true;

  } catch (error) {
    console.error(`Login failed: ${error.message}`);
    return false;
  }
}

// ============================================================================
// DYNAMIC ID DISCOVERY
// ============================================================================

// Cache for discovered IDs
const idCache = {
  prop: null,
  page: null,
  website: null,
  subscription: null,
  plan: null,
  user: null,
  domain: null,
  subdomain: null,
  agency: null,
  audit_log: null,
};

async function discoverIds(page) {
  log('Discovering dynamic IDs...');

  // Discover property ID
  try {
    await page.goto(`${BASE_URL}/site_admin/props`, { waitUntil: 'networkidle', timeout: 30000 });
    const propLink = await page.$('a[href*="/site_admin/props/"]');
    if (propLink) {
      const href = await propLink.getAttribute('href');
      const match = href.match(/\/site_admin\/props\/(\d+)/);
      if (match) {
        idCache.prop = match[1];
        verbose(`Found property ID: ${idCache.prop}`);
      }
    }
  } catch (e) {
    verbose(`Could not discover property ID: ${e.message}`);
  }

  // Discover page ID
  try {
    await page.goto(`${BASE_URL}/site_admin/pages`, { waitUntil: 'networkidle', timeout: 30000 });
    const pageLink = await page.$('a[href*="/site_admin/pages/"]');
    if (pageLink) {
      const href = await pageLink.getAttribute('href');
      const match = href.match(/\/site_admin\/pages\/(\d+)/);
      if (match) {
        idCache.page = match[1];
        verbose(`Found page ID: ${idCache.page}`);
      }
    }
  } catch (e) {
    verbose(`Could not discover page ID: ${e.message}`);
  }

  // Discover website ID (tenant admin)
  try {
    await page.goto(`${BASE_URL}/tenant_admin/websites`, { waitUntil: 'networkidle', timeout: 30000 });
    const websiteLink = await page.$('a[href*="/tenant_admin/websites/"]');
    if (websiteLink) {
      const href = await websiteLink.getAttribute('href');
      const match = href.match(/\/tenant_admin\/websites\/(\d+)/);
      if (match) {
        idCache.website = match[1];
        verbose(`Found website ID: ${idCache.website}`);
      }
    }
  } catch (e) {
    verbose(`Could not discover website ID: ${e.message}`);
  }

  // Discover subscription ID
  try {
    await page.goto(`${BASE_URL}/tenant_admin/subscriptions`, { waitUntil: 'networkidle', timeout: 30000 });
    const subLink = await page.$('a[href*="/tenant_admin/subscriptions/"]');
    if (subLink) {
      const href = await subLink.getAttribute('href');
      const match = href.match(/\/tenant_admin\/subscriptions\/(\d+)/);
      if (match) {
        idCache.subscription = match[1];
        verbose(`Found subscription ID: ${idCache.subscription}`);
      }
    }
  } catch (e) {
    verbose(`Could not discover subscription ID: ${e.message}`);
  }

  // Discover plan ID
  try {
    await page.goto(`${BASE_URL}/tenant_admin/plans`, { waitUntil: 'networkidle', timeout: 30000 });
    const planLink = await page.$('a[href*="/tenant_admin/plans/"]');
    if (planLink) {
      const href = await planLink.getAttribute('href');
      const match = href.match(/\/tenant_admin\/plans\/(\d+)/);
      if (match) {
        idCache.plan = match[1];
        verbose(`Found plan ID: ${idCache.plan}`);
      }
    }
  } catch (e) {
    verbose(`Could not discover plan ID: ${e.message}`);
  }

  // Discover user ID
  try {
    await page.goto(`${BASE_URL}/tenant_admin/users`, { waitUntil: 'networkidle', timeout: 30000 });
    const userLink = await page.$('a[href*="/tenant_admin/users/"]');
    if (userLink) {
      const href = await userLink.getAttribute('href');
      const match = href.match(/\/tenant_admin\/users\/(\d+)/);
      if (match) {
        idCache.user = match[1];
        verbose(`Found user ID: ${idCache.user}`);
      }
    }
  } catch (e) {
    verbose(`Could not discover user ID: ${e.message}`);
  }

  // Discover audit log ID
  try {
    await page.goto(`${BASE_URL}/tenant_admin/auth_audit_logs`, { waitUntil: 'networkidle', timeout: 30000 });
    const logLink = await page.$('a[href*="/tenant_admin/auth_audit_logs/"]');
    if (logLink) {
      const href = await logLink.getAttribute('href');
      const match = href.match(/\/tenant_admin\/auth_audit_logs\/(\d+)/);
      if (match) {
        idCache.audit_log = match[1];
        verbose(`Found audit log ID: ${idCache.audit_log}`);
      }
    }
  } catch (e) {
    verbose(`Could not discover audit log ID: ${e.message}`);
  }

  log('ID discovery complete.');
  verbose('Discovered IDs:', idCache);
}

function resolvePath(pagePath) {
  let resolved = pagePath;

  // Replace dynamic segments with discovered IDs
  resolved = resolved.replace(':prop_id', idCache.prop || '1');
  resolved = resolved.replace(':page_id', idCache.page || '1');
  resolved = resolved.replace(':website_id', idCache.website || '1');
  resolved = resolved.replace(':subscription_id', idCache.subscription || '1');
  resolved = resolved.replace(':plan_id', idCache.plan || '1');
  resolved = resolved.replace(':user_id', idCache.user || '1');
  resolved = resolved.replace(':domain_id', idCache.domain || '1');
  resolved = resolved.replace(':subdomain_id', idCache.subdomain || '1');
  resolved = resolved.replace(':agency_id', idCache.agency || '1');
  resolved = resolved.replace(':audit_log_id', idCache.audit_log || '1');

  return resolved;
}

// ============================================================================
// SCREENSHOT CAPTURE
// ============================================================================

async function takeScreenshot(page, section, pageName, viewport) {
  const dir = path.join(SCREENSHOT_DIR, section, path.dirname(pageName));
  await ensureDir(dir);

  const filename = `${path.basename(pageName)}-${viewport.name}.png`;
  const filepath = path.join(dir, filename);
  const isMobile = viewport.name === 'mobile';

  await page.setViewportSize({ width: viewport.width, height: viewport.height });
  await page.screenshot({ path: filepath, fullPage: true });

  const sizeMB = await getFileSizeMB(filepath);
  log(`  Captured: ${section}/${pageName}-${viewport.name}.png (${sizeMB.toFixed(2)}MB)`);

  if (sizeMB > MAX_SIZE_MB) {
    await compressImage(filepath, isMobile);
  }

  return filepath;
}

async function capturePages(page, pages, section) {
  log(`\nCapturing ${section} pages...`);

  let captured = 0;
  let skipped = 0;

  for (const pageInfo of pages) {
    const resolvedPath = resolvePath(pageInfo.path);

    // Skip pages with unresolved dynamic IDs
    if (resolvedPath.includes(':')) {
      verbose(`Skipping ${pageInfo.name}: unresolved path ${resolvedPath}`);
      skipped++;
      continue;
    }

    const url = `${BASE_URL}${resolvedPath}`;
    verbose(`Loading: ${url}`);

    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
      await page.waitForTimeout(500); // Brief wait for animations

      // Check for error pages
      const title = await page.title();
      if (title.includes('404') || title.includes('Error')) {
        verbose(`Skipping ${pageInfo.name}: page returned error`);
        skipped++;
        continue;
      }

      // Take desktop screenshot (always)
      await takeScreenshot(page, section, pageInfo.name, VIEWPORTS.desktop);

      // Take mobile screenshot (optional)
      if (INCLUDE_MOBILE) {
        await takeScreenshot(page, section, pageInfo.name, VIEWPORTS.mobile);
      }

      captured++;

    } catch (error) {
      console.error(`  Error capturing ${pageInfo.name}: ${error.message}`);
      skipped++;
    }
  }

  log(`${section}: ${captured} captured, ${skipped} skipped`);
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  log('='.repeat(60));
  log('PropertyWebBuilder Admin Screenshots');
  log('='.repeat(60));
  log(`Base URL: ${BASE_URL}`);
  log(`Output directory: ${SCREENSHOT_DIR}`);
  log(`Phase: ${PHASE || 'all'}`);
  log(`Include mobile: ${INCLUDE_MOBILE}`);
  log(`Max file size: ${MAX_SIZE_MB}MB`);
  if (!sharp) {
    log('Warning: sharp not available, compression disabled');
  }
  log('');

  const browser = await chromium.launch({
    headless: !DEBUG,
    slowMo: DEBUG ? 100 : 0
  });

  try {
    const context = await browser.newContext();
    const page = await context.newPage();

    // Login
    const loggedIn = await login(page);
    if (!loggedIn) {
      console.error('Failed to login. Exiting.');
      process.exit(1);
    }

    // Discover IDs for dynamic pages
    await discoverIds(page);

    // Build page list based on phase
    let siteAdminPages = [];
    let tenantAdminPages = [];

    if (!PHASE || PHASE === 1) {
      siteAdminPages = siteAdminPages.concat(PHASE_1_SITE_ADMIN);
      tenantAdminPages = tenantAdminPages.concat(PHASE_1_TENANT_ADMIN);
    }

    if (!PHASE || PHASE === 2) {
      siteAdminPages = siteAdminPages.concat(PHASE_2_SITE_ADMIN);
      tenantAdminPages = tenantAdminPages.concat(PHASE_2_TENANT_ADMIN);
    }

    if (!PHASE || PHASE === 3) {
      siteAdminPages = siteAdminPages.concat(PHASE_3_SITE_ADMIN);
      tenantAdminPages = tenantAdminPages.concat(PHASE_3_TENANT_ADMIN);
    }

    // Capture screenshots
    await capturePages(page, siteAdminPages, 'site-admin');
    await capturePages(page, tenantAdminPages, 'tenant-admin');

    await context.close();

    log('\n' + '='.repeat(60));
    log('Screenshot capture complete!');
    log(`Screenshots saved to: ${SCREENSHOT_DIR}`);
    log('='.repeat(60));

  } finally {
    await browser.close();
  }
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
