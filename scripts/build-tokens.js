#!/usr/bin/env node
/**
 * Build Design Tokens
 * 
 * Generates CSS custom properties from tokens.json for both:
 * - Rails: app/views/pwb/custom_css/_tokens.css.erb
 * - Astro: pwb-frontend-clients/pwb-astrojs-client/src/styles/tokens.css
 * 
 * Usage: node scripts/build-tokens.js
 */

const fs = require('fs');
const path = require('path');

const TOKENS_PATH = path.join(__dirname, '..', 'config', 'design', 'tokens.json');
const RAILS_OUTPUT = path.join(__dirname, '..', 'app', 'views', 'pwb', 'custom_css', '_tokens.css.erb');
const ASTRO_OUTPUT = path.join(__dirname, '..', 'pwb-frontend-clients', 'pwb-astrojs-client', 'src', 'styles', 'tokens.css');

/**
 * Convert camelCase to kebab-case
 */
function toKebabCase(str) {
  return str.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase();
}

/**
 * Flatten nested token object into CSS variable declarations
 */
function flattenTokens(obj, prefix = 'pwb') {
  const result = [];
  
  for (const [key, value] of Object.entries(obj)) {
    const varName = `--${prefix}-${toKebabCase(key)}`;
    
    if (value && typeof value === 'object') {
      if ('$value' in value) {
        // This is a token with a value
        result.push({ name: varName, value: value.$value, description: value.$description });
      } else {
        // Nested object, recurse
        result.push(...flattenTokens(value, `${prefix}-${toKebabCase(key)}`));
      }
    }
  }
  
  return result;
}

/**
 * Generate CSS custom properties block
 */
function generateCSS(tokens, includeComments = false) {
  const lines = [':root {'];
  
  for (const token of tokens) {
    if (includeComments && token.description) {
      lines.push(`  /* ${token.description} */`);
    }
    lines.push(`  ${token.name}: ${token.value};`);
  }
  
  lines.push('}');
  return lines.join('\n');
}

/**
 * Generate Rails ERB file with dynamic overrides
 */
function generateRailsCSS(tokens) {
  const lines = [
    '<%# Auto-generated from config/design/tokens.json - DO NOT EDIT MANUALLY %>',
    '<%# Run: node scripts/build-tokens.js to regenerate %>',
    '',
    '<%',
    '  # Get style variables with dynamic overrides from website',
    '  vars = @current_website&.style_variables || {}',
    '%>',
    '',
    ':root {'
  ];
  
  // Group tokens by category for better organization
  const categories = {};
  for (const token of tokens) {
    const parts = token.name.split('-');
    const category = parts[2] || 'base'; // e.g., --pwb-color-primary -> color
    if (!categories[category]) categories[category] = [];
    categories[category].push(token);
  }
  
  for (const [category, categoryTokens] of Object.entries(categories)) {
    lines.push(`  /* ===== ${category.charAt(0).toUpperCase() + category.slice(1)} ===== */`);
    
    for (const token of categoryTokens) {
      // Extract the key for dynamic override lookup
      const overrideKey = token.name.replace('--pwb-', '').replace(/-/g, '_');
      lines.push(`  ${token.name}: <%= vars["${overrideKey}"] || "${token.value}" %>;`);
    }
    lines.push('');
  }
  
  lines.push('}');
  return lines.join('\n');
}

/**
 * Generate Astro CSS file with Tailwind v4 @theme integration
 */
function generateAstroCSS(tokens) {
  const lines = [
    '/* Auto-generated from config/design/tokens.json - DO NOT EDIT MANUALLY */',
    '/* Run: node scripts/build-tokens.js to regenerate */',
    '',
    '/* Base token values - can be overridden by API-injected styles */',
    ':root {'
  ];
  
  for (const token of tokens) {
    lines.push(`  ${token.name}: ${token.value};`);
  }
  
  lines.push('}');
  lines.push('');
  lines.push('/* Tailwind v4 @theme mappings */');
  lines.push('@theme {');
  
  // Map key tokens to Tailwind theme variables
  const themeMap = [
    ['--color-pwb-primary', 'var(--pwb-color-primary)'],
    ['--color-pwb-secondary', 'var(--pwb-color-secondary)'],
    ['--color-pwb-accent', 'var(--pwb-color-accent)'],
    ['--color-pwb-text', 'var(--pwb-color-text-primary)'],
    ['--color-pwb-background', 'var(--pwb-color-background-body)'],
    ['--color-pwb-surface', 'var(--pwb-color-background-surface)'],
    ['--color-pwb-border', 'var(--pwb-color-border-default)'],
    ['--font-sans', 'var(--pwb-typography-font-family-primary)'],
    ['--font-serif', 'var(--pwb-typography-font-family-secondary)'],
  ];
  
  for (const [tailwindVar, tokenRef] of themeMap) {
    lines.push(`  ${tailwindVar}: ${tokenRef};`);
  }
  
  lines.push('}');
  
  return lines.join('\n');
}

// Main execution
try {
  console.log('📦 Loading tokens from', TOKENS_PATH);
  const tokensRaw = fs.readFileSync(TOKENS_PATH, 'utf-8');
  const tokens = JSON.parse(tokensRaw);
  
  // Remove $schema from processing
  delete tokens.$schema;
  
  const flatTokens = flattenTokens(tokens);
  console.log(`✅ Parsed ${flatTokens.length} tokens`);
  
  // Generate Rails CSS
  const railsCSS = generateRailsCSS(flatTokens);
  fs.writeFileSync(RAILS_OUTPUT, railsCSS);
  console.log('✅ Generated Rails CSS:', RAILS_OUTPUT);
  
  // Generate Astro CSS
  const astroCSS = generateAstroCSS(flatTokens);
  fs.writeFileSync(ASTRO_OUTPUT, astroCSS);
  console.log('✅ Generated Astro CSS:', ASTRO_OUTPUT);
  
  console.log('\n🎉 Token generation complete!');
} catch (error) {
  console.error('❌ Error generating tokens:', error.message);
  process.exit(1);
}
