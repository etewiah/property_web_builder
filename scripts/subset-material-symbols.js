#!/usr/bin/env node

/**
 * Material Symbols Font Subsetting Script
 * 
 * Generates a subset of Material Symbols Outlined font containing only
 * the icons used in the PropertyWebBuilder application.
 * 
 * This dramatically reduces font size from ~3.8MB to ~50-100KB.
 * 
 * Prerequisites:
 *   - Python 3 with fonttools: pip install fonttools brotli
 *   - npm install (for material-symbols package)
 * 
 * Usage:
 *   node scripts/subset-material-symbols.js
 * 
 * Output:
 *   - app/assets/fonts/material-symbols-subset.woff2
 *   - app/assets/stylesheets/material-symbols-subset.css
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Icons used in the application (from IconHelper::ALLOWED_ICONS)
const ALLOWED_ICONS = [
  'home',
  'search',
  'arrow_back',
  'arrow_forward',
  'chevron_left',
  'chevron_right',
  'expand_more',
  'expand_less',
  'arrow_drop_down',
  'arrow_drop_up',
  'menu',
  'close',
  'check',
  'check_circle',
  'bed',
  'bathroom',
  'bathtub',
  'shower',
  'local_parking',
  'directions_car',
  'garage',
  'phone',
  'email',
  'mail',
  'person',
  'account_circle',
  'people',
  'group',
  'location_on',
  'place',
  'map',
  'public',
  'language',
  'edit',
  'delete',
  'add',
  'remove',
  'visibility',
  'visibility_off',
  'star',
  'star_border',
  'star_half',
  'favorite',
  'favorite_border',
  'share',
  'send',
  'contacts',
  'fullscreen',
  'fullscreen_exit',
  'zoom_in',
  'zoom_out',
  'filter_list',
  'tune',
  'sort',
  'photo_library',
  'image',
  'photo',
  'collections',
  'info',
  'info_outline',
  'warning',
  'error',
  'help',
  'help_outline',
  'login',
  'logout',
  'settings',
  'format_quote',
  'lock',
  'lock_open',
  'key',
  'vpn_key',
  'attach_money',
  'payments',
  'euro',
  'euro_symbol',
  'handshake',
  'wb_sunny',
  'wb_twilight',
  'light_mode',
  'dark_mode',
  'brightness_5',
  'brightness_6',
  'brightness_7',
  'tag',
  'label',
  'category',
  'description',
  'file_copy',
  'article',
  'grid_view',
  'view_list',
  'list',
  'refresh',
  'sync',
  'autorenew',
  'upload',
  'download',
  'cloud_upload',
  'cloud_download',
  'open_in_new',
  'link',
  'content_copy',
  'print',
  'calendar_today',
  'schedule',
  'access_time',
  'verified',
  'thumb_up',
  'thumb_down',
  'comment',
  'chat',
  'forum',
  'notifications',
  'arrow_right_alt',
  'trending_up',
  'trending_down',
  'analytics',
  'insights',
  'dashboard',
  'home_work',
  'apartment',
  'house',
  'villa',
  'cottage',
  'real_estate_agent',
  'sell',
  'shopping_cart',
  'receipt',
  'calculate',
  'straighten',
  'square_foot',
  'crop_square',
  'aspect_ratio',
  'layers',
  'terrain',
  'park',
  'pool',
  'fitness_center',
  'ac_unit',
  'local_laundry_service',
  'kitchen',
  'balcony',
  'deck',
  'roofing',
  'foundation',
  'stairs',
  'elevator',
  'accessible',
  'pets',
  'smoke_free',
  'wifi',
  'tv',
  'security',
  'camera_outdoor',
  'doorbell',
  'solar_power',
  'bolt',
  'water_drop',
  'local_fire_department',
  'thermostat'
];

const ROOT_DIR = path.resolve(__dirname, '..');
const REQUIRED_CHARACTERS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_';
// Material Symbols uses 'rlig' (required ligatures) and 'rclt' (required contextual alternates)
// NOT 'liga' (standard ligatures) - this is critical for icon rendering!
const LAYOUT_FEATURES = ['rlig', 'rclt', 'calt'];
const SOURCE_FONT = path.join(ROOT_DIR, 'node_modules/material-symbols/material-symbols-outlined.woff2');
const OUTPUT_DIR = path.join(ROOT_DIR, 'app/assets/fonts');
const OUTPUT_FONT = path.join(OUTPUT_DIR, 'material-symbols-subset.woff2');
const OUTPUT_CSS = path.join(ROOT_DIR, 'app/assets/stylesheets/material-symbols-subset.css.erb');

// Material Symbols codepoints (icon name -> Unicode codepoint)
// Source: https://github.com/google/material-design-icons
const CODEPOINTS_URL = 'https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.codepoints';

async function fetchCodepoints() {
  console.log('Fetching Material Symbols codepoints...');
  
  // Try to use cached codepoints file
  const codepointsFile = path.join(ROOT_DIR, 'tmp/material-symbols-codepoints.txt');
  
  if (fs.existsSync(codepointsFile)) {
    console.log('Using cached codepoints file.');
    return fs.readFileSync(codepointsFile, 'utf8');
  }
  
  // Fetch from URL
  try {
    const response = await fetch(CODEPOINTS_URL);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const text = await response.text();
    
    // Cache it
    fs.mkdirSync(path.dirname(codepointsFile), { recursive: true });
    fs.writeFileSync(codepointsFile, text);
    
    return text;
  } catch (err) {
    console.error('Failed to fetch codepoints:', err.message);
    console.log('Please manually download codepoints from:');
    console.log(CODEPOINTS_URL);
    console.log(`And save to: ${codepointsFile}`);
    process.exit(1);
  }
}

function parseCodepoints(text) {
  const codepoints = {};
  for (const line of text.split('\n')) {
    const [name, code] = line.trim().split(/\s+/);
    if (name && code) {
      codepoints[name] = parseInt(code, 16);
    }
  }
  return codepoints;
}

function getUnicodeChars(iconNames, codepoints) {
  const chars = [];
  const missing = [];
  
  for (const name of iconNames) {
    const code = codepoints[name];
    if (code) {
      chars.push(String.fromCodePoint(code));
    } else {
      missing.push(name);
    }
  }
  
  if (missing.length > 0) {
    console.warn(`Warning: Could not find codepoints for: ${missing.join(', ')}`);
  }
  
  return chars;
}

function addRequiredCharacters(chars) {
  const set = new Set(chars);
  for (const char of REQUIRED_CHARACTERS) {
    if (!set.has(char)) {
      chars.push(char);
    }
  }
  return chars;
}

function subsetFont(chars) {
  console.log(`\nSubsetting font with ${chars.length} glyphs...`);
  
  // Ensure output directory exists
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  
  // Create a text file with the characters to include
  const charsFile = path.join(ROOT_DIR, 'tmp/subset-chars.txt');
  fs.writeFileSync(charsFile, chars.join(''));
  
  // Use python3 -m fontTools.subset (works even if pyftsubset is not in PATH)
  // The font is a variable font, so we need to handle it properly
  const cmdParts = [
    'python3 -m fontTools.subset',
    `"${SOURCE_FONT}"`,
    `--text-file="${charsFile}"`,
    `--output-file="${OUTPUT_FONT}"`,
    '--flavor=woff2',
    '--no-hinting',
    '--desubroutinize'
  ];

  if (LAYOUT_FEATURES && LAYOUT_FEATURES.length > 0) {
    cmdParts.push(`--layout-features=${LAYOUT_FEATURES.join(',')}`);
  }

  const cmd = cmdParts.join(' ');

  console.log('Running:', cmd);

  try {
    execSync(cmd, { stdio: 'inherit' });
  } catch (err) {
    console.error('\nError: Failed to subset font.');
    console.error('Make sure you have fonttools installed:');
    console.error('  pip3 install fonttools brotli');
    process.exit(1);
  }
  
  // Check output
  if (fs.existsSync(OUTPUT_FONT)) {
    const stats = fs.statSync(OUTPUT_FONT);
    const sizeKB = (stats.size / 1024).toFixed(1);
    console.log(`\nSuccess! Created ${OUTPUT_FONT}`);
    console.log(`Font size: ${sizeKB} KB (reduced from ~3800 KB)`);
  }
}

function generateCSS() {
  console.log('\nGenerating CSS...');

  const css = `/*
 * Material Symbols Outlined - Subset Font
 * Generated by scripts/subset-material-symbols.js
 *
 * This is an optimized subset containing only the icons used in the application.
 * DO NOT load the full Google Fonts version alongside this.
 */

@font-face {
  font-family: 'Material Symbols Outlined';
  font-style: normal;
  font-weight: 100 700;
  font-display: swap;
  src: url('<%= asset_path("material-symbols-subset.woff2") %>') format('woff2');
}

/* ============================================
 * Base Icon Styles
 * ============================================
 * CRITICAL: Material Symbols uses 'rlig' (required ligatures)
 * NOT 'liga' (standard ligatures) - this is essential for icon rendering!
 * ============================================ */

.material-symbols-outlined {
  font-family: 'Material Symbols Outlined' !important;
  font-weight: normal;
  font-style: normal;
  font-size: 24px;
  line-height: 1;
  letter-spacing: normal;
  text-transform: none;
  display: inline-block;
  white-space: nowrap;
  word-wrap: normal;
  direction: ltr;
  vertical-align: middle;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
  /* Material Symbols requires 'rlig' (required ligatures) for icon substitution */
  font-feature-settings: 'rlig' !important;

  /* Default: outlined style */
  font-variation-settings:
    'FILL' 0,
    'wght' 400,
    'GRAD' 0,
    'opsz' 24 !important;
}

/* ============================================
 * Size Variants
 * ============================================ */

.material-symbols-outlined.md-14 {
  font-size: 14px;
  font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 20;
}

.material-symbols-outlined.md-18 {
  font-size: 18px;
  font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 20;
}

.material-symbols-outlined.md-24 {
  font-size: 24px;
  font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
}

.material-symbols-outlined.md-36 {
  font-size: 36px;
  font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 40;
}

.material-symbols-outlined.md-48 {
  font-size: 48px;
  font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 48;
}

/* ============================================
 * Style Variants
 * ============================================ */

/* Filled variant */
.material-symbols-outlined.filled {
  font-variation-settings:
    'FILL' 1,
    'wght' 400,
    'GRAD' 0,
    'opsz' 24;
}

/* Bold/emphasized variant */
.material-symbols-outlined.bold {
  font-variation-settings:
    'FILL' 0,
    'wght' 700,
    'GRAD' 0,
    'opsz' 24;
}

/* Light variant */
.material-symbols-outlined.light {
  font-variation-settings:
    'FILL' 0,
    'wght' 300,
    'GRAD' 0,
    'opsz' 24;
}

/* Filled + Bold */
.material-symbols-outlined.filled.bold {
  font-variation-settings:
    'FILL' 1,
    'wght' 700,
    'GRAD' 0,
    'opsz' 24;
}

/* ============================================
 * Utility Classes
 * ============================================ */

/* Fixed width for alignment in lists */
.material-symbols-outlined.icon-fw {
  width: 1.5em;
  text-align: center;
}

/* Spin animation for loading states */
.material-symbols-outlined.icon-spin {
  animation: icon-spin 1s linear infinite;
}

@keyframes icon-spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* Pulse animation */
.material-symbols-outlined.icon-pulse {
  animation: icon-pulse 1s ease-in-out infinite;
}

@keyframes icon-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

/* Action button icons */
.btn .material-symbols-outlined {
  margin-right: 0.375rem;
  font-size: 1.25em;
}

.btn-icon-only .material-symbols-outlined {
  margin-right: 0;
}

/* ============================================
 * Accessibility
 * ============================================ */

/* Ensure icons don't interfere with screen readers when decorative */
.material-symbols-outlined[aria-hidden="true"] {
  speak: never;
}

/* High contrast mode support */
@media (forced-colors: active) {
  .material-symbols-outlined {
    forced-color-adjust: auto;
  }
}

/* Reduced motion preference */
@media (prefers-reduced-motion: reduce) {
  .material-symbols-outlined.icon-spin,
  .material-symbols-outlined.icon-pulse {
    animation: none;
  }
}
`;

  fs.writeFileSync(OUTPUT_CSS, css);
  console.log(`Created ${OUTPUT_CSS}`);
}

async function main() {
  console.log('='.repeat(60));
  console.log('Material Symbols Font Subsetting');
  console.log('='.repeat(60));
  
  // Check source font exists
  if (!fs.existsSync(SOURCE_FONT)) {
    console.error(`Error: Source font not found at ${SOURCE_FONT}`);
    console.error('Run: npm install');
    process.exit(1);
  }
  
  const sourceStats = fs.statSync(SOURCE_FONT);
  console.log(`Source font: ${SOURCE_FONT}`);
  console.log(`Source size: ${(sourceStats.size / 1024 / 1024).toFixed(2)} MB`);
  console.log(`Icons to include: ${ALLOWED_ICONS.length}`);
  
  // Fetch and parse codepoints
  const codepointsText = await fetchCodepoints();
  const codepoints = parseCodepoints(codepointsText);
  console.log(`Loaded ${Object.keys(codepoints).length} codepoints`);
  
  // Get Unicode characters for our icons
  let chars = getUnicodeChars(ALLOWED_ICONS, codepoints);
  chars = addRequiredCharacters(chars);
  
  // Subset the font
  subsetFont(chars);
  
  // Generate CSS
  generateCSS();
  
  console.log('\n' + '='.repeat(60));
  console.log('Done! Next steps:');
  console.log('1. Update app/themes/default/views/layouts/pwb/application.html.erb');
  console.log('   - Remove the Google Fonts link for Material Symbols');
  console.log('   - Add: <%= stylesheet_link_tag "material-symbols-subset" %>');
  console.log('2. Commit the new font file and CSS');
  console.log('='.repeat(60));
}

main().catch(console.error);
