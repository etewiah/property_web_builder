#!/usr/bin/env node
/**
 * Screenshot capture script for PropertyWebBuilder
 * Takes screenshots of all pages across all themes
 */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const SCREENSHOT_DIR = path.join(__dirname, '..', 'docs', 'screenshots');
const THEME = process.env.SCREENSHOT_THEME || 'default';

// Pages to capture for each theme
const PAGES = [
  { name: 'home', path: '/' },
  { name: 'home-en', path: '/en' },
  { name: 'buy', path: '/en/buy' },
  { name: 'rent', path: '/en/rent' },
  { name: 'contact', path: '/contact-us' },
  { name: 'about', path: '/about-us' },
];

// Admin pages (require authentication bypass or logged in state)
const ADMIN_PAGES = [
  { name: 'dashboard', path: '/site_admin' },
  { name: 'properties', path: '/site_admin/props' },
  { name: 'settings', path: '/site_admin/website/settings' },
];

// Viewports for responsive screenshots
const VIEWPORTS = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'mobile', width: 375, height: 812 },
];

async function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

async function takeScreenshot(page, theme, pageName, viewport) {
  const dir = path.join(SCREENSHOT_DIR, theme);
  await ensureDir(dir);

  const filename = `${pageName}-${viewport.name}.png`;
  const filepath = path.join(dir, filename);

  await page.setViewportSize({ width: viewport.width, height: viewport.height });
  await page.screenshot({ path: filepath, fullPage: true });

  console.log(`  Captured: ${filepath}`);
  return filepath;
}

async function captureTheme(browser, themeName) {
  console.log(`\nCapturing theme: ${themeName}`);

  const context = await browser.newContext();
  const page = await context.newPage();

  for (const pageInfo of PAGES) {
    const url = `${BASE_URL}${pageInfo.path}`;
    console.log(`  Loading: ${url}`);

    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
      await page.waitForTimeout(1000); // Wait for any animations

      // Take desktop screenshot (primary)
      await takeScreenshot(page, themeName, pageInfo.name, VIEWPORTS[0]);

      // Take mobile screenshot
      await takeScreenshot(page, themeName, pageInfo.name, VIEWPORTS[2]);

    } catch (error) {
      console.error(`  Error capturing ${pageInfo.name}: ${error.message}`);
    }
  }

  await context.close();
}

async function main() {
  console.log('Starting screenshot capture...');
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Output directory: ${SCREENSHOT_DIR}`);

  const browser = await chromium.launch({ headless: true });

  try {
    // Capture screenshots for the specified theme
    console.log(`Theme: ${THEME}`);
    await captureTheme(browser, THEME);

    console.log('\nScreenshot capture complete!');
    console.log(`Screenshots saved to: ${SCREENSHOT_DIR}/${THEME}`);

  } finally {
    await browser.close();
  }
}

main().catch(console.error);
