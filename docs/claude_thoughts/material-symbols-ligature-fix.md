# Material Symbols Icon Rendering Issue - Fixed

## Problem

After self-hosting the Material Symbols font subset (commits e7d18b04, 651142b8, 1b22fb41), icons were not rendering correctly. Instead of showing icons, the text names (e.g., "home") were displayed.

Example HTML that wasn't working:
```html
<span class="material-symbols-outlined md-48" aria-hidden="true">home</span>
```

## Root Causes (Multiple Issues)

### Issue 1: Missing CSS Class Definition

The `material-symbols-subset.css.erb` file only contained the `@font-face` declaration but was **missing the critical CSS class definition** for `.material-symbols-outlined`.

### Issue 2: Wrong Ligature Feature

The CSS was using `font-feature-settings: 'liga'` (standard ligatures), but Material Symbols actually uses `'rlig'` (required ligatures).

### Issue 3: Font Subsetting Removed Ligatures

The initial subsetting script used `--layout-features=liga,dlig,calt,ccmp,kern`, but Material Symbols uses different features: `rlig` and `rclt`. This caused the ligature data to be stripped from the subset font.

### Issue 4: Tailwind CSS Override

Tailwind CSS's base reset applies `font-feature-settings: normal` globally, which was overriding the ligature settings even when they were present.

## How Material Symbols Icons Work

Material Symbols uses a ligature-based system:

1. The font file contains mappings from text strings to icon glyphs (e.g., "home" → home icon glyph)
2. These mappings are stored as OpenType ligature features in the font
3. The CSS property `font-feature-settings: 'liga'` tells the browser to enable ligature substitution
4. When the browser sees text "home" with this font and feature enabled, it replaces it with the icon glyph

## The Complete Fix

### 1. Updated CSS Files

Updated `app/assets/stylesheets/material-symbols-subset.css.erb` and `material-icons.css` to include:

1. **Base icon styles** with `font-feature-settings: 'rlig' !important` (CRITICAL - must be 'rlig' not 'liga')
2. **Size variants** (.md-14, .md-18, .md-24, .md-36, .md-48)
3. **Style variants** (.filled, .bold, .light)
4. **Utility classes** (.icon-fw, .icon-spin, .icon-pulse)
5. **Accessibility features** (aria-hidden support, reduced motion)

### 2. Updated Subsetting Script

Updated `scripts/subset-material-symbols.js` to:
- Use `--layout-features=rlig,rclt,calt` instead of `liga,dlig,calt,ccmp,kern`
- Use `python3 -m fontTools.subset` instead of `pyftsubset` (more reliable)
- Generate complete CSS with `font-feature-settings: 'rlig' !important`

### 3. Regenerated Font File

Ran the subsetting script to create a new font file with the correct ligature features preserved.

### Why `!important` is Needed

Tailwind CSS's base reset applies `font-feature-settings: normal` to all elements. Since Tailwind CSS is loaded before the Material Symbols CSS in the layout, and both have the same CSS specificity, Tailwind's reset was overriding the ligature settings.

Using `!important` on these critical properties ensures they take precedence:
- `font-family: 'Material Symbols Outlined' !important`
- `font-feature-settings: 'rlig' !important` (NOT 'liga'!)
- `font-variation-settings: ... !important`

### Why 'rlig' Not 'liga'

Material Symbols uses **required ligatures** (`rlig`) not standard ligatures (`liga`). This is a critical distinction:
- `liga` = Standard ligatures (optional, for typography like "fi" → "ﬁ")
- `rlig` = Required ligatures (mandatory for functionality, used by icon fonts)

The source font contains only `rlig` and `rclt` features, not `liga`.

## Why the Subsetting Script Preserved Ligatures

The commits attempted to preserve ligatures in the font file itself:

- Commit 651142b8: Created the subsetting script
- Commit 1b22fb41: Added `--layout-features=liga,dlig,calt,ccmp,kern` to preserve ligature features

These changes correctly preserved the ligature data **in the font file**, but the CSS was still missing the property to **enable** those ligatures in the browser.

## Testing

After applying this fix:

1. Restart the Rails server (or clear asset cache)
2. Visit http://localhost:4444/
3. Icons should now render correctly as glyphs instead of text

## Files Changed

- `app/assets/stylesheets/material-symbols-subset.css.erb` - Added complete CSS rules with `!important`
- `app/assets/stylesheets/material-icons.css` - Added `!important` to critical properties
- `scripts/subset-material-symbols.js` - Updated to generate complete CSS with `!important`
- `docs/claude_thoughts/material-symbols-ligature-fix.md` - This documentation

## Technical Details: CSS Specificity and Load Order

The issue was compounded by CSS specificity and load order:

1. **Tailwind CSS Reset**: Tailwind's base styles include `font-feature-settings: normal` on all elements
2. **Load Order**: In `app/themes/default/views/layouts/pwb/application.html.erb`:
   - Line 30-31: Tailwind CSS is preloaded
   - Line 42-43: Material Symbols CSS is loaded after
3. **Specificity Problem**: Both rules target `.material-symbols-outlined` with the same specificity
4. **Solution**: Use `!important` to ensure Material Symbols properties override Tailwind's reset

This is a legitimate use of `!important` because:
- We're overriding a third-party CSS reset (Tailwind)
- The properties are critical for functionality (not just styling)
- Without ligatures enabled, the icons don't work at all

## References

- [Material Symbols Documentation](https://fonts.google.com/icons)
- [OpenType Ligature Features](https://developer.mozilla.org/en-US/docs/Web/CSS/font-feature-settings)
- Original CSS reference: `app/assets/stylesheets/material-icons.css`

