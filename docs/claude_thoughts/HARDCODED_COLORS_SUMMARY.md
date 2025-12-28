# Hardcoded Colors - Quick Reference

## Overview

Total hardcoded color issues found across all themes: **60+** instances

**Status:**
- Default Theme: ✅ Mostly OK (uses Tailwind variables)
- Bologna Theme: ⚠️ 2 issues (footer content links)
- Brisbane Theme: ⚠️ 5 issues (header + footer)
- Barcelona Theme: ⚠️ 2 issues (footer content links)
- Biarritz Theme: 🔴 **40+ issues** (pervasive inline hex colors)

---

## Biarritz Theme - Critical Issues

### Color Values Used Inline

```
#082F49  - Ocean Dark Blue (background)
#0C4A6E  - Ocean Medium Blue (accents)
#D97706  - Amber Orange (hover states)
#FEF3C7  - Cream Light (text)
#0369A1  - Sky Blue (icons)
#1C1917  - Dark Text
#D4D4D8  - Light Gray
#E0F2FE  - Very Light Blue
#E7E5E4  - Border Gray
#F59E0B  - Lighter Amber
#B91C1C  - Red (destructive)
```

### File Issues

**Header (_header.html.erb):**
- Line 3: `bg-[#082F49]`, `border-[#0C4A6E]`
- Lines 12, 27, 49, 51, 57: `hover:text-[#FEF3C7]`
- Lines 18, 28, 38, 56: `bg-[#0C4A6E]`, `hover:bg-[#D97706]`
- Lines 84-126: Multiple nav color hardcodes
- 26+ total inline hex colors

**Footer (_footer.html.erb):**
- Line 3: `bg-[#082F49]`
- Lines 10, 28-29, 38-40, 56-57, 61: Multiple icon/social colors
- Lines 77, 90, 99, 104: Text and divider colors
- Line 110: Wave gradient with 3 inline hex values
- 15+ total inline hex colors

---

## Bologna Theme

### Issues
| File | Line | Colors | Problem |
|------|------|--------|---------|
| `_footer.html.erb` | 188 | `#d98e6e` | Link color hardcoded |
| `_footer.html.erb` | 190 | `#e7b5a0` | Link hover color hardcoded |

### Available CSS Variables Not Used
```css
--bologna-terra-400: #d98e6e (could replace hardcoded)
--footer-text-color: #d5d0c8 (defined but not used for links)
```

### Fix
Move footer styles to CSS variable definitions:
```css
--footer-link-color: var(--bologna-terra-400);
--footer-link-hover-color: var(--bologna-terra-300);
```

---

## Brisbane Theme

### Issues
| File | Line | Color | Expected | Problem |
|------|------|-------|----------|---------|
| `_header.html.erb` | 84-90 | `bg-blue-600`, `text-blue-600` | Should use `luxury-gold` | Wrong theme color |
| `_footer.html.erb` | 143 | `#c9a962` | Correct gold | Hardcoded inline |
| `_footer.html.erb` | 145 | `#e7b5a0` | Should be gold variant | Wrong color (terra, not gold!) |

### Critical Fix Needed
Line 145 has mismatched color scheme - uses terra brown instead of gold.

### Available CSS Variables
```css
--brisbane-gold: #c9a962
--brisbane-gold-light: (should define)
--brisbane-gold-dark: (should define)
```

---

## Barcelona Theme

### Issues
| File | Line | Colors | Problem |
|------|------|--------|---------|
| `_footer.html.erb` | 172 | `#E5B45A` | Link color hardcoded |
| `_footer.html.erb` | 174 | `#fde047` | Link hover color hardcoded |

### Note
Barcelona uses custom med-*, gold-*, warm-* color classes but the footer link colors in inline style aren't using them.

---

## Default Theme

### Status
✅ Mostly OK - uses Tailwind color system

### Could Improve
- Consider creating CSS variables for primary, secondary, accent colors
- Currently relies on Tailwind classes directly

---

## Pattern Across All Themes

### Footer Custom Content Links Problem

All three themes (Bologna, Brisbane, Barcelona) have this pattern in their footer:

```erb
<style>
  .footer-custom-content a {
    color: #HARDCODED_HEX;
  }
  .footer-custom-content a:hover {
    color: #ANOTHER_HARDCODED_HEX;
  }
</style>
```

**Solution:**
Use CSS variables instead:
```erb
<style>
  .footer-custom-content a {
    color: var(--footer-link-color);
  }
  .footer-custom-content a:hover {
    color: var(--footer-link-hover-color);
  }
</style>
```

And define in CSS files:
```css
:root {
  --footer-link-color: var(--footer-link-color);
  --footer-link-hover-color: var(--footer-link-hover-color);
}
```

---

## Action Items

### 🔴 CRITICAL - Do First
1. **Biarritz header/footer:** Create CSS variable file and convert all 40+ inline colors
2. **Brisbane header line 145:** Fix mismatched terra color to gold color
3. **Brisbane header lines 84, 88, 90:** Change `blue-600` to `luxury-gold`

### 🟡 IMPORTANT - Do Second
4. **All theme footers:** Move footer link color hardcodes to CSS variables
5. **Create standardized footer link color pattern** across all themes

### 🟢 NICE TO HAVE - Do Third
6. **Default theme:** Consider CSS variable consistency
7. **Barcelona theme:** Formalize color variable exports

---

## Testing Checklist

After fixes, verify:

- [ ] All colors respond to CSS variable changes
- [ ] Footer link colors update when CSS variables change
- [ ] No inline hex colors remain in view files
- [ ] Hover states use appropriate color variations
- [ ] Dark mode still works correctly (if enabled)
- [ ] Colors are consistent across buy/rent/search pages

---

## References

### Defined CSS Variables by Theme

**Bologna:**
- `--bologna-terra`, `--bologna-olive`, `--bologna-sand`, `--bologna-warm-gray`
- `--footer-bg-color`, `--footer-text-color`

**Brisbane:**
- `--brisbane-gold`, `--brisbane-navy`, `--brisbane-cream`, `--brisbane-charcoal`
- `--footer-bg-color`, `--footer-text-color`

**Barcelona:**
- `--med-*`, `--gold-*`, `--warm-*` color scales
- Color palette defined in CSS file

**Biarritz:**
- ❌ NO CSS VARIABLES DEFINED - All colors are inline

**Default:**
- `--primary-color`, `--secondary-color`, `--services-bg-color`, etc.
- Uses Tailwind color system

