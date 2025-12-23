#!/usr/bin/env node
/**
 * Screenshot compression script for PropertyWebBuilder
 * Resizes and compresses PNG screenshots to be under 2MB
 * 
 * Usage:
 *   node scripts/compress-screenshots.js
 *   node scripts/compress-screenshots.js --max-size 1.5  # Max size in MB
 *   node scripts/compress-screenshots.js --theme bologna  # Only compress one theme
 */

const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const SCREENSHOT_DIR = path.join(__dirname, '..', 'docs', 'screenshots');
const MAX_SIZE_MB = parseFloat(process.env.MAX_SIZE_MB || process.argv.find(a => a.startsWith('--max-size='))?.split('=')[1] || '2');
const MAX_SIZE_BYTES = MAX_SIZE_MB * 1024 * 1024;
const TARGET_THEME = process.env.TARGET_THEME || process.argv.find(a => a.startsWith('--theme='))?.split('=')[1] || null;

// Quality settings for compression
const PNG_COMPRESSION_LEVEL = 9;
const QUALITY_STEPS = [100, 90, 80, 70, 60];
const MAX_WIDTH = 1920; // Max width for desktop screenshots
const MAX_MOBILE_WIDTH = 800; // Max width for mobile screenshots

async function getFileSizeInMB(filepath) {
  const stats = fs.statSync(filepath);
  return stats.size / (1024 * 1024);
}

async function compressImage(filepath) {
  const filename = path.basename(filepath);
  const isMobile = filename.includes('-mobile');
  const maxWidth = isMobile ? MAX_MOBILE_WIDTH : MAX_WIDTH;
  
  const originalSize = await getFileSizeInMB(filepath);
  
  if (originalSize <= MAX_SIZE_MB) {
    console.log(`  ✓ ${filename}: ${originalSize.toFixed(2)}MB (already under ${MAX_SIZE_MB}MB)`);
    return { filepath, originalSize, newSize: originalSize, compressed: false };
  }
  
  console.log(`  → ${filename}: ${originalSize.toFixed(2)}MB - compressing...`);
  
  const tempPath = filepath.replace('.png', '.temp.png');
  let newSize = originalSize;
  
  try {
    // First try: resize if larger than max dimensions
    let image = sharp(filepath);
    const metadata = await image.metadata();
    
    if (metadata.width > maxWidth) {
      image = image.resize(maxWidth, null, { 
        withoutEnlargement: true,
        fit: 'inside'
      });
    }
    
    // Apply PNG compression
    await image
      .png({ 
        compressionLevel: PNG_COMPRESSION_LEVEL,
        adaptiveFiltering: true,
        palette: true // Use palette-based PNG for smaller size
      })
      .toFile(tempPath);
    
    newSize = await getFileSizeInMB(tempPath);
    
    // If still too large, try converting to JPEG (lossy but much smaller)
    if (newSize > MAX_SIZE_MB) {
      const jpegPath = filepath.replace('.png', '.jpg');
      
      for (const quality of QUALITY_STEPS) {
        await sharp(filepath)
          .resize(maxWidth, null, { withoutEnlargement: true, fit: 'inside' })
          .jpeg({ quality, mozjpeg: true })
          .toFile(jpegPath);
        
        const jpegSize = await getFileSizeInMB(jpegPath);
        
        if (jpegSize <= MAX_SIZE_MB) {
          // Convert back to PNG from the smaller JPEG
          await sharp(jpegPath)
            .png({ compressionLevel: PNG_COMPRESSION_LEVEL })
            .toFile(tempPath);
          
          fs.unlinkSync(jpegPath);
          newSize = await getFileSizeInMB(tempPath);
          
          if (newSize <= MAX_SIZE_MB) {
            break;
          }
        }
        
        fs.unlinkSync(jpegPath);
      }
    }
    
    // Replace original with compressed version
    if (newSize < originalSize) {
      fs.unlinkSync(filepath);
      fs.renameSync(tempPath, filepath);
      console.log(`    ✓ Compressed to ${newSize.toFixed(2)}MB (saved ${((originalSize - newSize) / originalSize * 100).toFixed(1)}%)`);
    } else {
      fs.unlinkSync(tempPath);
      console.log(`    ✗ Could not reduce size further`);
    }
    
    return { filepath, originalSize, newSize, compressed: newSize < originalSize };
    
  } catch (error) {
    // Cleanup temp file if it exists
    if (fs.existsSync(tempPath)) {
      fs.unlinkSync(tempPath);
    }
    throw error;
  }
}

async function compressTheme(themeName) {
  const themeDir = path.join(SCREENSHOT_DIR, themeName);
  
  if (!fs.existsSync(themeDir)) {
    console.log(`Theme directory not found: ${themeDir}`);
    return [];
  }
  
  console.log(`\nCompressing theme: ${themeName}`);
  
  const files = fs.readdirSync(themeDir)
    .filter(f => f.endsWith('.png'))
    .map(f => path.join(themeDir, f));
  
  const results = [];
  
  for (const filepath of files) {
    try {
      const result = await compressImage(filepath);
      results.push(result);
    } catch (error) {
      console.error(`  ✗ Error compressing ${path.basename(filepath)}: ${error.message}`);
      results.push({ filepath, error: error.message });
    }
  }
  
  return results;
}

async function main() {
  console.log('Screenshot Compression Tool');
  console.log(`Max file size: ${MAX_SIZE_MB}MB`);
  console.log(`Screenshot directory: ${SCREENSHOT_DIR}`);
  
  if (!fs.existsSync(SCREENSHOT_DIR)) {
    console.error(`Screenshot directory not found: ${SCREENSHOT_DIR}`);
    process.exit(1);
  }
  
  const themes = TARGET_THEME 
    ? [TARGET_THEME]
    : fs.readdirSync(SCREENSHOT_DIR)
        .filter(f => fs.statSync(path.join(SCREENSHOT_DIR, f)).isDirectory());
  
  let totalOriginal = 0;
  let totalNew = 0;
  let filesCompressed = 0;
  
  for (const theme of themes) {
    const results = await compressTheme(theme);
    
    for (const result of results) {
      if (!result.error) {
        totalOriginal += result.originalSize;
        totalNew += result.newSize;
        if (result.compressed) filesCompressed++;
      }
    }
  }
  
  console.log('\n=== Summary ===');
  console.log(`Files compressed: ${filesCompressed}`);
  console.log(`Total original size: ${totalOriginal.toFixed(2)}MB`);
  console.log(`Total new size: ${totalNew.toFixed(2)}MB`);
  console.log(`Space saved: ${(totalOriginal - totalNew).toFixed(2)}MB (${((totalOriginal - totalNew) / totalOriginal * 100).toFixed(1)}%)`);
}

main().catch(error => {
  console.error('Error:', error.message);
  process.exit(1);
});
