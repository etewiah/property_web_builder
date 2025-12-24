#!/usr/bin/env node
/**
 * Production screenshot capture script for PropertyWebBuilder
 * Takes screenshots of the production demo site across all themes
 * Automatically compresses images to stay under 2MB
 */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// Try to load sharp for compression, fall back gracefully if not available
let sharp;
try {
  sharp = require('sharp');
} catch (e) {
  console.log('Note: sharp not installed. Run "npm install" to enable auto-compression.');
}

const BASE_URL = process.env.BASE_URL || 'https://demo.propertywebbuilder.com';
const SCREENSHOT_DIR = path.join(__dirname, '..', 'docs', 'screenshots', 'prod');
const MAX_SIZE_MB = parseFloat(process.env.MAX_SIZE_MB || '2');
const MAX_SIZE_BYTES = MAX_SIZE_MB * 1024 * 1024;

// Themes to capture (default first, then others via ?theme= parameter)
const THEMES = [
  { name: 'default', param: null },
  { name: 'brisbane', param: 'brisbane' },
  { name: 'bologna', param: 'bologna' },
];

// Pages to capture for each theme
const PAGES = [
  { name: 'home', path: '/' },
  { name: 'home-en', path: '/en' },
  { name: 'buy', path: '/en/buy' },
  { name: 'rent', path: '/en/rent' },
  { name: 'sell', path: '/p/sell' },
  { name: 'contact', path: '/contact-us' },
  { name: 'about', path: '/about-us' },
];

// Dynamic pages that need to be discovered (e.g., property detail pages)
const DYNAMIC_PAGES = [
  {
    name: 'property-sale',
    discoverFrom: '/en/buy',
    linkSelector: 'a[href*="/properties/for-sale/"]',
    description: 'Property for sale detail page'
  },
  {
    name: 'property-rent',
    discoverFrom: '/en/rent',
    linkSelector: 'a[href*="/properties/for-rent/"]',
    description: 'Property for rent detail page'
  },
];

// Viewports for responsive screenshots
const VIEWPORTS = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'mobile', width: 375, height: 812 },
];

// Max dimensions for compression
const MAX_DESKTOP_WIDTH = 1440;
const MAX_MOBILE_WIDTH = 750;

function buildUrl(basePath, themeParam) {
  const url = `${BASE_URL}${basePath}`;
  if (!themeParam) return url;

  // Add theme parameter
  const separator = url.includes('?') ? '&' : '?';
  return `${url}${separator}theme=${themeParam}`;
}

async function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
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
    return; // Already under limit
  }

  console.log(`    Compressing ${path.basename(filepath)} (${originalSize.toFixed(2)}MB)...`);

  const maxWidth = isMobile ? MAX_MOBILE_WIDTH : MAX_DESKTOP_WIDTH;
  const tempPath = filepath.replace('.png', '.temp.png');

  try {
    let image = sharp(filepath);
    const metadata = await image.metadata();

    // Resize if needed
    if (metadata.width > maxWidth) {
      image = image.resize(maxWidth, null, {
        withoutEnlargement: true,
        fit: 'inside'
      });
    }

    // Apply PNG compression with palette for smaller size
    await image
      .png({
        compressionLevel: 9,
        adaptiveFiltering: true,
        palette: true,
        quality: 80
      })
      .toFile(tempPath);

    let newSize = await getFileSizeMB(tempPath);

    // If still too large, be more aggressive
    if (newSize > MAX_SIZE_MB) {
      // Reduce colors and resize more
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

    // Replace original
    fs.unlinkSync(filepath);
    fs.renameSync(tempPath, filepath);

    console.log(`    Compressed to ${newSize.toFixed(2)}MB`);

  } catch (error) {
    if (fs.existsSync(tempPath)) {
      fs.unlinkSync(tempPath);
    }
    console.error(`    Compression failed: ${error.message}`);
  }
}

async function takeScreenshot(page, themeName, pageName, viewport) {
  const dir = path.join(SCREENSHOT_DIR, themeName);
  await ensureDir(dir);

  const filename = `${pageName}-${viewport.name}.png`;
  const filepath = path.join(dir, filename);
  const isMobile = viewport.name === 'mobile';

  await page.setViewportSize({ width: viewport.width, height: viewport.height });
  await page.screenshot({ path: filepath, fullPage: true });

  const sizeMB = await getFileSizeMB(filepath);
  console.log(`  Captured: ${filename} (${sizeMB.toFixed(2)}MB)`);

  // Auto-compress if over limit
  if (sizeMB > MAX_SIZE_MB) {
    await compressImage(filepath, isMobile);
  }

  return filepath;
}

async function discoverAndCaptureDynamicPage(page, themeName, themeParam, dynamicPage) {
  console.log(`  Discovering ${dynamicPage.description}...`);

  try {
    // Navigate to the discovery page
    const discoverUrl = buildUrl(dynamicPage.discoverFrom, themeParam);
    await page.goto(discoverUrl, { waitUntil: 'networkidle', timeout: 60000 });
    await page.waitForTimeout(2000);

    // Find the first matching link
    const link = await page.$(dynamicPage.linkSelector);
    if (!link) {
      console.log(`    No ${dynamicPage.name} link found on ${dynamicPage.discoverFrom}`);
      return;
    }

    let href = await link.getAttribute('href');
    if (!href) {
      console.log(`    Link found but no href attribute`);
      return;
    }

    // Build the property URL with theme parameter if needed
    let propertyUrl;
    if (href.startsWith('http')) {
      propertyUrl = href;
    } else {
      propertyUrl = `${BASE_URL}${href}`;
    }

    // Add theme parameter if needed
    if (themeParam) {
      const separator = propertyUrl.includes('?') ? '&' : '?';
      propertyUrl = `${propertyUrl}${separator}theme=${themeParam}`;
    }

    console.log(`  Loading: ${propertyUrl}`);
    await page.goto(propertyUrl, { waitUntil: 'networkidle', timeout: 60000 });
    await page.waitForTimeout(2000);

    // Take screenshots
    await takeScreenshot(page, themeName, dynamicPage.name, VIEWPORTS[0]);
    await takeScreenshot(page, themeName, dynamicPage.name, VIEWPORTS[2]);

  } catch (error) {
    console.error(`  Error capturing ${dynamicPage.name}: ${error.message}`);
  }
}

async function captureTheme(browser, theme) {
  console.log(`\nCapturing theme: ${theme.name}${theme.param ? ` (via ?theme=${theme.param})` : ''}`);

  const context = await browser.newContext();
  const page = await context.newPage();

  // Capture static pages
  for (const pageInfo of PAGES) {
    const url = buildUrl(pageInfo.path, theme.param);
    console.log(`  Loading: ${url}`);

    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
      await page.waitForTimeout(2000); // Wait for any animations

      // Take desktop screenshot (primary)
      await takeScreenshot(page, theme.name, pageInfo.name, VIEWPORTS[0]);

      // Take mobile screenshot
      await takeScreenshot(page, theme.name, pageInfo.name, VIEWPORTS[2]);

    } catch (error) {
      console.error(`  Error capturing ${pageInfo.name}: ${error.message}`);
    }
  }

  // Capture dynamic pages (property details, etc.)
  for (const dynamicPage of DYNAMIC_PAGES) {
    await discoverAndCaptureDynamicPage(page, theme.name, theme.param, dynamicPage);
  }

  await context.close();
}

async function main() {
  console.log('Starting production screenshot capture...');
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Output directory: ${SCREENSHOT_DIR}`);
  console.log(`Max file size: ${MAX_SIZE_MB}MB`);
  if (!sharp) {
    console.log('Warning: sharp not available, compression disabled');
  }

  const browser = await chromium.launch({ headless: true });

  try {
    // Capture screenshots for each theme
    for (const theme of THEMES) {
      await captureTheme(browser, theme);
    }

    console.log('\nProduction screenshot capture complete!');
    console.log(`Screenshots saved to: ${SCREENSHOT_DIR}`);

  } finally {
    await browser.close();
  }
}

main().catch(console.error);
