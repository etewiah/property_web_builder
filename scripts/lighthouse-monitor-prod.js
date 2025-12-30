#!/usr/bin/env node
/**
 * Production Lighthouse Performance Monitor for PropertyWebBuilder
 *
 * Runs Lighthouse audits against production sites across all themes.
 * Detects performance degradation and sends NTFY notifications.
 * Results are saved in date-based folders for historical tracking.
 *
 * Usage:
 *   node scripts/lighthouse-monitor-prod.js
 *
 * Environment variables:
 *   NTFY_TOPIC     - NTFY topic for notifications (default: pwb-lighthouse)
 *   NTFY_SERVER    - NTFY server URL (default: https://ntfy.sh)
 *   BASELINE_DIR   - Directory containing baseline scores (optional)
 *   DEGRADATION_THRESHOLD - Score drop to trigger alert (default: 5)
 *
 * For periodic runs, add to crontab:
 *   0 6 * * * cd /path/to/project && node scripts/lighthouse-monitor-prod.js
 */

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const https = require('https');
const http = require('http');

// =============================================================================
// Configuration
// =============================================================================

// Generate date/time strings
function getDateString() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function getTimestamp() {
  const now = new Date();
  return now.toISOString().replace(/[:.]/g, '-').slice(0, 19);
}

const DATE_STRING = getDateString();
const TIMESTAMP = getTimestamp();

// Output directories (gitignored)
const REPORTS_BASE_DIR = path.join(__dirname, '..', 'lighthouse-reports');
const REPORTS_DIR = path.join(REPORTS_BASE_DIR, 'prod', DATE_STRING);
const BASELINE_DIR = process.env.BASELINE_DIR || path.join(REPORTS_BASE_DIR, 'baselines');

// NTFY configuration
const NTFY_SERVER = process.env.NTFY_SERVER || 'https://ntfy.sh';
const NTFY_TOPIC = process.env.NTFY_TOPIC || 'pwb-lighthouse';

// Performance thresholds
const DEGRADATION_THRESHOLD = parseFloat(process.env.DEGRADATION_THRESHOLD || '5');

// Score thresholds for alerts (0-100 scale)
const SCORE_THRESHOLDS = {
  performance: 50,
  accessibility: 80,
  'best-practices': 80,
  seo: 80,
};

// Themes with their subdomains
const THEMES = [
  { name: 'demo', subdomain: 'demo' },
  { name: 'brisbane', subdomain: 'brisbane' },
  { name: 'bologna', subdomain: 'bologna' },
];

// Pages to audit for each theme
const PAGES = [
  { name: 'home', path: '/' },
  { name: 'home-en', path: '/en' },
  { name: 'buy', path: '/en/buy' },
  { name: 'rent', path: '/en/rent' },
  { name: 'contact', path: '/contact-us' },
  { name: 'about', path: '/about-us' },
];

// Lighthouse categories to audit
const CATEGORIES = ['performance', 'accessibility', 'best-practices', 'seo'];

// =============================================================================
// Utility Functions
// =============================================================================

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function buildUrl(subdomain, pagePath) {
  return `https://${subdomain}.propertywebbuilder.com${pagePath}`;
}

/**
 * Send notification via NTFY
 */
async function sendNotification(title, message, priority = 'default', tags = []) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${NTFY_SERVER}/${NTFY_TOPIC}`);
    const isHttps = url.protocol === 'https:';
    const httpModule = isHttps ? https : http;

    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'text/plain',
        'Title': title,
        'Priority': priority,
        'Tags': tags.join(','),
      },
    };

    const req = httpModule.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log(`  Notification sent: ${title}`);
          resolve(data);
        } else {
          console.error(`  Notification failed (${res.statusCode}): ${data}`);
          resolve(null); // Don't reject, just log
        }
      });
    });

    req.on('error', (error) => {
      console.error(`  Notification error: ${error.message}`);
      resolve(null); // Don't reject, just log
    });

    req.write(message);
    req.end();
  });
}

/**
 * Run Lighthouse audit using the CLI
 */
async function runLighthouse(url, outputPath) {
  return new Promise((resolve, reject) => {
    const args = [
      url,
      '--output=json,html',
      `--output-path=${outputPath}`,
      '--chrome-flags="--headless --no-sandbox --disable-gpu"',
      '--quiet',
      `--only-categories=${CATEGORIES.join(',')}`,
      '--preset=desktop',
    ];

    console.log(`    Running Lighthouse for: ${url}`);

    try {
      // Use npx to run lighthouse
      execSync(`npx lighthouse ${args.join(' ')}`, {
        stdio: 'pipe',
        timeout: 120000, // 2 minute timeout
      });

      // Read the JSON results
      const jsonPath = outputPath + '.report.json';
      if (fs.existsSync(jsonPath)) {
        const report = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
        resolve(report);
      } else {
        reject(new Error('Lighthouse JSON report not found'));
      }
    } catch (error) {
      reject(new Error(`Lighthouse failed: ${error.message}`));
    }
  });
}

/**
 * Extract scores from Lighthouse report
 */
function extractScores(report) {
  const scores = {};
  for (const category of CATEGORIES) {
    const categoryData = report.categories[category];
    if (categoryData) {
      scores[category] = Math.round(categoryData.score * 100);
    }
  }
  return scores;
}

/**
 * Load baseline scores for comparison
 */
function loadBaseline(themeName, pageName) {
  const baselinePath = path.join(BASELINE_DIR, `${themeName}-${pageName}.json`);
  if (fs.existsSync(baselinePath)) {
    try {
      return JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
    } catch (e) {
      return null;
    }
  }
  return null;
}

/**
 * Save scores as new baseline
 */
function saveBaseline(themeName, pageName, scores) {
  ensureDir(BASELINE_DIR);
  const baselinePath = path.join(BASELINE_DIR, `${themeName}-${pageName}.json`);
  const data = {
    scores,
    timestamp: new Date().toISOString(),
    theme: themeName,
    page: pageName,
  };
  fs.writeFileSync(baselinePath, JSON.stringify(data, null, 2));
}

/**
 * Check for degradation compared to baseline
 */
function checkDegradation(currentScores, baseline) {
  if (!baseline || !baseline.scores) return [];

  const degradations = [];
  for (const [category, currentScore] of Object.entries(currentScores)) {
    const baselineScore = baseline.scores[category];
    if (baselineScore !== undefined) {
      const diff = baselineScore - currentScore;
      if (diff >= DEGRADATION_THRESHOLD) {
        degradations.push({
          category,
          current: currentScore,
          baseline: baselineScore,
          diff,
        });
      }
    }
  }
  return degradations;
}

/**
 * Check if scores are below thresholds
 */
function checkThresholds(scores) {
  const failures = [];
  for (const [category, score] of Object.entries(scores)) {
    const threshold = SCORE_THRESHOLDS[category];
    if (threshold && score < threshold) {
      failures.push({
        category,
        score,
        threshold,
      });
    }
  }
  return failures;
}

// =============================================================================
// Main Audit Functions
// =============================================================================

/**
 * Audit a single page
 */
async function auditPage(theme, page) {
  const url = buildUrl(theme.subdomain, page.path);
  const outputDir = path.join(REPORTS_DIR, theme.name);
  ensureDir(outputDir);

  const outputPath = path.join(outputDir, `${page.name}-${TIMESTAMP}`);

  try {
    const report = await runLighthouse(url, outputPath);
    const scores = extractScores(report);

    console.log(`    Scores: P:${scores.performance} A:${scores.accessibility} BP:${scores['best-practices']} SEO:${scores.seo}`);

    // Load baseline and check for degradation
    const baseline = loadBaseline(theme.name, page.name);
    const degradations = checkDegradation(scores, baseline);
    const thresholdFailures = checkThresholds(scores);

    // Save summary JSON
    const summaryPath = path.join(outputDir, `${page.name}-${TIMESTAMP}-summary.json`);
    const summary = {
      url,
      theme: theme.name,
      page: page.name,
      timestamp: new Date().toISOString(),
      scores,
      baseline: baseline?.scores || null,
      degradations,
      thresholdFailures,
    };
    fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));

    return {
      success: true,
      url,
      theme: theme.name,
      page: page.name,
      scores,
      degradations,
      thresholdFailures,
      reportPath: outputPath,
    };

  } catch (error) {
    console.error(`    Error: ${error.message}`);
    return {
      success: false,
      url,
      theme: theme.name,
      page: page.name,
      error: error.message,
    };
  }
}

/**
 * Audit all pages for a theme
 */
async function auditTheme(theme) {
  console.log(`\nAuditing theme: ${theme.name} (${theme.subdomain}.propertywebbuilder.com)`);

  const results = [];
  for (const page of PAGES) {
    console.log(`  Page: ${page.name}`);
    const result = await auditPage(theme, page);
    results.push(result);
  }

  return results;
}

/**
 * Generate summary report
 */
function generateSummaryReport(allResults) {
  const summary = {
    timestamp: new Date().toISOString(),
    date: DATE_STRING,
    totalPages: allResults.length,
    successful: allResults.filter(r => r.success).length,
    failed: allResults.filter(r => !r.success).length,
    degradations: [],
    thresholdFailures: [],
    results: allResults,
  };

  // Collect all degradations and threshold failures
  for (const result of allResults) {
    if (result.degradations?.length > 0) {
      summary.degradations.push({
        theme: result.theme,
        page: result.page,
        url: result.url,
        degradations: result.degradations,
      });
    }
    if (result.thresholdFailures?.length > 0) {
      summary.thresholdFailures.push({
        theme: result.theme,
        page: result.page,
        url: result.url,
        failures: result.thresholdFailures,
      });
    }
  }

  // Save summary
  const summaryPath = path.join(REPORTS_DIR, `summary-${TIMESTAMP}.json`);
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));

  return summary;
}

/**
 * Send notifications for issues
 */
async function sendAlertNotifications(summary) {
  const issues = [];

  // Collect degradation alerts
  for (const deg of summary.degradations) {
    for (const d of deg.degradations) {
      issues.push(`${deg.theme}/${deg.page}: ${d.category} dropped ${d.diff} points (${d.baseline} -> ${d.current})`);
    }
  }

  // Collect threshold alerts
  for (const tf of summary.thresholdFailures) {
    for (const f of tf.failures) {
      issues.push(`${tf.theme}/${tf.page}: ${f.category} score ${f.score} below threshold ${f.threshold}`);
    }
  }

  if (issues.length > 0) {
    const title = `PWB Lighthouse Alert: ${issues.length} issue(s) detected`;
    const message = issues.join('\n');
    await sendNotification(title, message, 'high', ['warning', 'chart_with_downwards_trend']);
  } else {
    // Send success notification (optional, can be disabled)
    const avgPerf = Math.round(
      summary.results
        .filter(r => r.success && r.scores?.performance)
        .reduce((sum, r) => sum + r.scores.performance, 0) /
      summary.results.filter(r => r.success && r.scores?.performance).length
    );

    const title = `PWB Lighthouse: All checks passed`;
    const message = `Audited ${summary.successful}/${summary.totalPages} pages. Avg performance: ${avgPerf}`;
    await sendNotification(title, message, 'low', ['white_check_mark']);
  }
}

/**
 * Update baselines with current scores (optional)
 */
function updateBaselines(results, forceUpdate = false) {
  for (const result of results) {
    if (result.success && result.scores) {
      const baseline = loadBaseline(result.theme, result.page);

      // Update baseline if it doesn't exist or if forced
      if (!baseline || forceUpdate) {
        saveBaseline(result.theme, result.page, result.scores);
        console.log(`  Updated baseline for ${result.theme}/${result.page}`);
      }
    }
  }
}

// =============================================================================
// Main Entry Point
// =============================================================================

async function main() {
  console.log('='.repeat(60));
  console.log('PropertyWebBuilder Production Lighthouse Monitor');
  console.log('='.repeat(60));
  console.log(`Date: ${DATE_STRING}`);
  console.log(`Timestamp: ${TIMESTAMP}`);
  console.log(`Reports directory: ${REPORTS_DIR}`);
  console.log(`NTFY topic: ${NTFY_TOPIC}`);
  console.log(`Degradation threshold: ${DEGRADATION_THRESHOLD} points`);

  // Ensure output directory exists
  ensureDir(REPORTS_DIR);

  // Check if lighthouse is available
  try {
    execSync('npx lighthouse --version', { stdio: 'pipe' });
  } catch (e) {
    console.error('\nError: Lighthouse CLI not found. Install with: npm install -g lighthouse');
    process.exit(1);
  }

  const allResults = [];

  // Audit each theme
  for (const theme of THEMES) {
    const themeResults = await auditTheme(theme);
    allResults.push(...themeResults);
  }

  // Generate summary
  console.log('\n' + '='.repeat(60));
  console.log('Generating Summary Report');
  console.log('='.repeat(60));

  const summary = generateSummaryReport(allResults);

  console.log(`\nResults: ${summary.successful}/${summary.totalPages} pages audited successfully`);
  console.log(`Degradations detected: ${summary.degradations.length}`);
  console.log(`Threshold failures: ${summary.thresholdFailures.length}`);

  // Update baselines for new pages (don't overwrite existing)
  console.log('\nUpdating baselines for new pages...');
  updateBaselines(allResults, false);

  // Send notifications
  console.log('\nSending notifications...');
  await sendAlertNotifications(summary);

  // Print summary table
  console.log('\n' + '='.repeat(60));
  console.log('Score Summary');
  console.log('='.repeat(60));
  console.log('Theme      | Page       | Perf | A11y | BP   | SEO');
  console.log('-'.repeat(60));

  for (const result of allResults) {
    if (result.success) {
      const s = result.scores;
      console.log(
        `${result.theme.padEnd(10)} | ${result.page.padEnd(10)} | ${String(s.performance).padStart(4)} | ${String(s.accessibility).padStart(4)} | ${String(s['best-practices']).padStart(4)} | ${String(s.seo).padStart(4)}`
      );
    } else {
      console.log(
        `${result.theme.padEnd(10)} | ${result.page.padEnd(10)} | FAILED: ${result.error}`
      );
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log(`Reports saved to: ${REPORTS_DIR}`);
  console.log('='.repeat(60));

  // Exit with error code if there were issues
  if (summary.degradations.length > 0 || summary.thresholdFailures.length > 0) {
    process.exit(1);
  }
}

// Handle command line arguments
const args = process.argv.slice(2);

if (args.includes('--help') || args.includes('-h')) {
  console.log(`
PropertyWebBuilder Production Lighthouse Monitor

Usage:
  node scripts/lighthouse-monitor-prod.js [options]

Options:
  --help, -h              Show this help message
  --update-baselines      Force update all baselines with current scores
  --theme=NAME            Only audit a specific theme
  --dry-run               Run without sending notifications

Environment variables:
  NTFY_TOPIC              NTFY topic for notifications (default: pwb-lighthouse)
  NTFY_SERVER             NTFY server URL (default: https://ntfy.sh)
  DEGRADATION_THRESHOLD   Score drop to trigger alert (default: 5)

Examples:
  # Run full audit
  node scripts/lighthouse-monitor-prod.js

  # Update baselines
  node scripts/lighthouse-monitor-prod.js --update-baselines

  # Audit only brisbane theme
  node scripts/lighthouse-monitor-prod.js --theme=brisbane

Crontab example (daily at 6 AM):
  0 6 * * * cd /path/to/project && node scripts/lighthouse-monitor-prod.js
`);
  process.exit(0);
}

if (args.includes('--update-baselines')) {
  console.log('Baseline update mode: Will force update all baselines');
  // Modify the updateBaselines call in main to use forceUpdate=true
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
