#!/usr/bin/env node

/**
 * Critical CSS Extraction Script
 *
 * Extracts above-the-fold CSS for each theme and generates inline CSS files
 * that can be included in the <head> of each page for faster initial paint.
 *
 * Usage:
 *   npm run critical:extract
 *
 * Prerequisites:
 *   - Rails server running on localhost:3000
 *   - npm install (to install the 'critical' package)
 *
 * Output:
 *   - app/assets/builds/critical-default.css
 *   - app/assets/builds/critical-bologna.css
 *   - app/assets/builds/critical-brisbane.css
 */

const critical = require('critical');
const fs = require('fs');
const path = require('path');

// Configuration
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const OUTPUT_DIR = path.join(__dirname, '..', 'app', 'assets', 'builds');

// Theme configurations with their key pages
const themes = [
  {
    name: 'default',
    pages: [
      { path: '/', output: 'critical-default-home.css' },
      { path: '/search/buy', output: 'critical-default-search.css' },
    ]
  },
  {
    name: 'bologna',
    pages: [
      { path: '/', output: 'critical-bologna-home.css' },
      { path: '/search/buy', output: 'critical-bologna-search.css' },
    ]
  },
  {
    name: 'brisbane',
    pages: [
      { path: '/', output: 'critical-brisbane-home.css' },
      { path: '/search/buy', output: 'critical-brisbane-search.css' },
    ]
  }
];

// Viewport dimensions for critical CSS extraction
const dimensions = [
  { width: 375, height: 667 },   // Mobile
  { width: 768, height: 1024 },  // Tablet
  { width: 1440, height: 900 },  // Desktop
];

async function extractCriticalCSS(theme, page) {
  const url = `${BASE_URL}${page.path}`;
  const outputPath = path.join(OUTPUT_DIR, page.output);

  console.log(`Extracting critical CSS for ${theme.name}: ${page.path}`);

  try {
    const { css } = await critical.generate({
      src: url,
      width: 1440,
      height: 900,
      dimensions: dimensions,
      // Include specific CSS files
      css: [
        path.join(OUTPUT_DIR, `tailwind-${theme.name}.css`),
      ],
      // Inline options
      inline: false,
      // Extract options
      extract: true,
      // Ignore certain CSS patterns that cause issues
      ignore: {
        atrule: ['@font-face'],
        decl: (node, value) => {
          // Ignore very long data URIs
          return /data:/.test(value) && value.length > 1000;
        }
      },
      // Penthouse options for better extraction
      penthouse: {
        timeout: 60000,
        renderWaitTime: 500,
      }
    });

    // Write the critical CSS file
    fs.writeFileSync(outputPath, css);
    console.log(`  -> Generated: ${outputPath} (${(css.length / 1024).toFixed(2)} KB)`);

    return css;
  } catch (error) {
    console.error(`  Error extracting ${page.path}:`, error.message);
    return null;
  }
}

async function combineCriticalCSS(theme) {
  const criticalFiles = theme.pages.map(p =>
    path.join(OUTPUT_DIR, p.output)
  );

  let combinedCSS = '';

  for (const file of criticalFiles) {
    if (fs.existsSync(file)) {
      combinedCSS += fs.readFileSync(file, 'utf8') + '\n';
    }
  }

  // Deduplicate CSS rules (simple approach)
  const rules = new Set(combinedCSS.split('\n').filter(Boolean));
  const dedupedCSS = Array.from(rules).join('\n');

  const outputPath = path.join(OUTPUT_DIR, `critical-${theme.name}.css`);
  fs.writeFileSync(outputPath, dedupedCSS);
  console.log(`Combined critical CSS: ${outputPath} (${(dedupedCSS.length / 1024).toFixed(2)} KB)`);

  // Clean up individual page files
  for (const file of criticalFiles) {
    if (fs.existsSync(file)) {
      fs.unlinkSync(file);
    }
  }
}

async function main() {
  console.log('Critical CSS Extraction');
  console.log('=======================\n');
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Output directory: ${OUTPUT_DIR}\n`);

  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  for (const theme of themes) {
    console.log(`\nProcessing theme: ${theme.name}`);
    console.log('-'.repeat(40));

    for (const page of theme.pages) {
      await extractCriticalCSS(theme, page);
    }

    // Combine all page critical CSS into one file per theme
    await combineCriticalCSS(theme);
  }

  console.log('\nDone!');
  console.log('\nTo use critical CSS, include it inline in your layout:');
  console.log('  <style><%= Rails.root.join("app/assets/builds/critical-#{theme_name}.css").read %></style>');
}

// Run the script
main().catch(console.error);
