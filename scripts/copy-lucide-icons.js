#!/usr/bin/env node
/**
 * Copy required Lucide icons to app/assets/images/icons/
 *
 * This script copies only the icons used by PropertyWebBuilder
 * from node_modules/lucide-static to the assets folder.
 */

const fs = require('fs');
const path = require('path');

const SOURCE_DIR = path.join(__dirname, '../node_modules/lucide-static/icons');
const DEST_DIR = path.join(__dirname, '../app/assets/images/icons');

// Map of Material Symbols names to Lucide icon filenames
// Format: 'material_name': 'lucide-filename' (without .svg)
const ICON_MAP = {
  // Property/Real Estate
  'home': 'house',
  'apartment': 'building',
  'bed': 'bed',
  'shower': 'shower-head',
  'bathtub': 'bath',
  'directions_car': 'car',
  'local_parking': 'car',
  'garage': 'warehouse',
  'square_foot': 'square',
  'straighten': 'ruler',
  'landscape': 'mountain',
  'terrain': 'mountain',
  'pool': 'waves',
  'fitness_center': 'dumbbell',
  'ac_unit': 'snowflake',
  'kitchen': 'cooking-pot',
  'balcony': 'fence',
  'deck': 'fence',
  'roofing': 'home',
  'stairs': 'stairs',
  'elevator': 'arrow-up-down',
  'accessible': 'accessibility',
  'pets': 'paw-print',
  'smoke_free': 'cigarette-off',
  'wifi': 'wifi',
  'tv': 'tv',
  'security': 'shield',
  'solar_power': 'sun',
  'bolt': 'zap',
  'water_drop': 'droplet',
  'thermostat': 'thermometer',

  // Navigation
  'chevron_left': 'chevron-left',
  'chevron_right': 'chevron-right',
  'expand_more': 'chevron-down',
  'expand_less': 'chevron-up',
  'keyboard_arrow_down': 'chevron-down',
  'keyboard_arrow_up': 'chevron-up',
  'arrow_back': 'arrow-left',
  'arrow_forward': 'arrow-right',
  'arrow_drop_down': 'chevron-down',
  'arrow_drop_up': 'chevron-up',
  'arrow_right_alt': 'arrow-right',
  'close': 'x',
  'menu': 'menu',

  // Communication
  'email': 'mail',
  'mail': 'mail',
  'phone': 'phone',
  'location_on': 'map-pin',
  'place': 'map-pin',
  'map': 'map',
  'public': 'globe',
  'language': 'globe',
  'send': 'send',
  'chat': 'message-circle',
  'forum': 'messages-square',
  'contacts': 'contact',
  'comment': 'message-square',
  'notifications': 'bell',

  // Actions
  'search': 'search',
  'filter_list': 'filter',
  'tune': 'sliders-horizontal',
  'sort': 'arrow-up-down',
  'refresh': 'refresh-cw',
  'sync': 'refresh-cw',
  'autorenew': 'refresh-cw',
  'check': 'check',
  'check_circle': 'check-circle',
  'edit': 'pencil',
  'delete': 'trash-2',
  'add': 'plus',
  'remove': 'minus',
  'fullscreen': 'maximize',
  'fullscreen_exit': 'minimize',
  'zoom_in': 'zoom-in',
  'zoom_out': 'zoom-out',
  'visibility': 'eye',
  'visibility_off': 'eye-off',
  'upload': 'upload',
  'download': 'download',
  'cloud_upload': 'cloud-upload',
  'cloud_download': 'cloud-download',
  'open_in_new': 'external-link',
  'link': 'link',
  'content_copy': 'copy',
  'print': 'printer',
  'share': 'share-2',

  // UI Elements
  'tag': 'tag',
  'label': 'tag',
  'category': 'folder',
  'description': 'file-text',
  'file_copy': 'files',
  'article': 'file-text',
  'grid_view': 'grid-3x3',
  'view_list': 'list',
  'list': 'list',
  'photo_library': 'images',
  'image': 'image',
  'photo': 'image',
  'collections': 'images',
  'layers': 'layers',

  // Status/Info
  'info': 'info',
  'warning': 'alert-triangle',
  'error': 'alert-circle',
  'help': 'help-circle',
  'help_outline': 'help-circle',
  'verified': 'badge-check',
  'thumb_up': 'thumbs-up',
  'thumb_down': 'thumbs-down',
  'trending_up': 'trending-up',
  'trending_down': 'trending-down',

  // User/Account
  'person': 'user',
  'account_circle': 'user-circle',
  'people': 'users',
  'group': 'users',
  'login': 'log-in',
  'logout': 'log-out',
  'settings': 'settings',
  'lock': 'lock',
  'lock_open': 'unlock',
  'key': 'key',
  'vpn_key': 'key',

  // Commerce
  'attach_money': 'dollar-sign',
  'payments': 'credit-card',
  'euro': 'euro',
  'euro_symbol': 'euro',
  'shopping_cart': 'shopping-cart',
  'receipt': 'receipt',
  'calculate': 'calculator',
  'sell': 'tag',
  'handshake': 'handshake',

  // Misc
  'star': 'star',
  'star_border': 'star',
  'star_half': 'star-half',
  'favorite': 'heart',
  'favorite_border': 'heart',
  'format_quote': 'quote',
  'wb_sunny': 'sun',
  'light_mode': 'sun',
  'dark_mode': 'moon',
  'brightness_5': 'sun',
  'brightness_6': 'sun',
  'brightness_7': 'sun',
  'calendar_today': 'calendar',
  'schedule': 'clock',
  'access_time': 'clock',
  'dashboard': 'layout-dashboard',
  'home_work': 'building-2',
  'house': 'house',
  'villa': 'castle',
  'cottage': 'home',
  'real_estate_agent': 'user',
  'analytics': 'bar-chart-2',
  'insights': 'lightbulb',
  'park': 'trees',
  'aspect_ratio': 'ratio',
  'crop_square': 'square',
  'doorbell': 'bell',
  'camera_outdoor': 'camera',
  'local_fire_department': 'flame',
  'local_laundry_service': 'shirt',
  'foundation': 'layers',

  // Social (these will use brand_icon, but map anyway)
  'facebook': 'facebook',
  'instagram': 'instagram',
  'linkedin': 'linkedin',
  'youtube': 'youtube',
  'twitter': 'twitter',
  'x': 'twitter',
  'whatsapp': 'message-circle',
};

// Get unique Lucide icon names
const uniqueLucideIcons = [...new Set(Object.values(ICON_MAP))];

console.log(`Copying ${uniqueLucideIcons.length} Lucide icons to ${DEST_DIR}\n`);

// Ensure destination directory exists
if (!fs.existsSync(DEST_DIR)) {
  fs.mkdirSync(DEST_DIR, { recursive: true });
}

let copied = 0;
let missing = [];

for (const iconName of uniqueLucideIcons) {
  const srcFile = path.join(SOURCE_DIR, `${iconName}.svg`);
  const destFile = path.join(DEST_DIR, `${iconName}.svg`);

  if (fs.existsSync(srcFile)) {
    fs.copyFileSync(srcFile, destFile);
    copied++;
    console.log(`  Copied: ${iconName}.svg`);
  } else {
    missing.push(iconName);
    console.log(`  MISSING: ${iconName}.svg`);
  }
}

console.log(`\n========================================`);
console.log(`Copied: ${copied} icons`);
console.log(`Missing: ${missing.length} icons`);

if (missing.length > 0) {
  console.log(`\nMissing icons:`);
  missing.forEach(name => console.log(`  - ${name}`));
}

// Calculate total size
let totalSize = 0;
const files = fs.readdirSync(DEST_DIR);
for (const file of files) {
  if (file.endsWith('.svg')) {
    const stats = fs.statSync(path.join(DEST_DIR, file));
    totalSize += stats.size;
  }
}

console.log(`\nTotal size: ${(totalSize / 1024).toFixed(1)} KB`);
console.log(`(vs 3.7 MB font file = ${((1 - totalSize / (3.7 * 1024 * 1024)) * 100).toFixed(1)}% reduction)`);
