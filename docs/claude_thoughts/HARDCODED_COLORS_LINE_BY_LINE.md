# Hardcoded Colors - Line by Line Details

## Biarritz Theme - Most Critical Issues

### Header: `/app/themes/biarritz/views/pwb/_header.html.erb`

#### Top Bar Section
```
Line 3:   bg-[#082F49]              - Header background (should be CSS var)
Line 3:   border-[#0C4A6E]          - Header border color
Line 12:  hover:text-[#FEF3C7]      - Phone hover text
Line 18:  bg-[#0C4A6E]              - Phone icon background
Line 19:  group-hover:bg-[#D97706]  - Phone icon hover
Line 27:  hover:text-[#FEF3C7]      - Email hover text
Line 38:  bg-[#0C4A6E]              - Email icon background
Line 39:  group-hover:bg-[#D97706]  - Email icon hover
```

#### Language Switcher
```
Line 49:  bg-[#D97706]              - Selected language background
Line 51:  hover:bg-[#0C4A6E]        - Language hover background
Line 57:  text-white/hover:text-[#FEF3C7] - Language link hover
```

#### Navigation Bar
```
Line 71:  border-[#D97706]          - Nav bottom border (accent)
Line 84:  bg-[#0369A1]              - Logo icon background
Line 91:  text-[#1C1917]            - Logo text color
Line 92:  group-hover:text-[#0C4A6E] - Logo hover text
Line 96:  text-[#1C1917]            - Menu button text
Line 99:  focus:ring-[#0369A1]      - Focus ring color
```

#### Navigation Links
```
Line 124: bg-[#E0F2FE]              - Active nav link background
Line 125: text-[#0C4A6E]            - Active nav link text
Line 126: text-[#1C1917]            - Nav link text color
Line 128: hover:text-[#0C4A6E]      - Nav link hover text
```

#### User Dropdown
```
Line 137: text-[#1C1917]            - Dropdown text
Line 138: hover:text-[#0C4A6E]      - Dropdown hover
Line 139: border-[#0369A1]          - Dropdown border
Line 140: focus:ring-[#0369A1]      - Focus ring
Line 150: border-[#E7E5E4]          - Dropdown border
Line 155: text-[#1C1917]            - Menu item text
Line 156: hover:bg-[#E0F2FE]        - Menu item hover background
Line 157: hover:text-[#0C4A6E]      - Menu item hover text
Line 165: text-[#B91C1C]            - Sign out text (red)
```

#### Wave Accent
```
Line 110: from-[#0369A1] via-[#D97706] to-[#F59E0B] - Wave gradient (3 colors!)
```

**Total in Header: 26+ hardcoded hex colors**

---

### Footer: `/app/themes/biarritz/views/pwb/_footer.html.erb`

#### Wave Divider
```
Line 10:  text-[#082F49]            - Wave SVG color (dark ocean)
```

#### Company Info Section
```
Line 28:  bg-[#0C4A6E]              - Phone icon background
Line 29:  group-hover:bg-[#D97706]  - Phone icon hover
Line 31:  hover:text-[#FEF3C7]      - Phone link hover text
Line 38:  bg-[#0C4A6E]              - Email icon background
Line 39:  group-hover:bg-[#D97706]  - Email icon hover
Line 42:  hover:text-[#FEF3C7]      - Email link hover text
```

#### Social Media Links
```
Line 56:  bg-[#0C4A6E]              - Social icon background
Line 57:  hover:bg-[#D97706]        - Social icon hover
Line 61:  focus:ring-[#FEF3C7]      - Focus ring color
Line 61:  focus:ring-offset-[#082F49] - Focus ring offset (dark ocean)
```

#### Footer Content Text
```
Line 77:  text-[#D4D4D8]            - Main text color (light gray)
Line 84:  text-[#FEF3C7]            - Hover text color
```

#### Footer Navigation
```
Line 90:  border-[#0C4A6E]          - Divider border
Line 99:  text-[#D4D4D8]            - Copyright text
Line 104: text-[#FEF3C7]            - Link hover text
```

#### Divider Line
```
Line 110: from-[#0369A1] via-[#D97706] to-[#F59E0B] - Gradient divider
```

**Total in Footer: 15+ hardcoded hex colors**

**TOTAL BIARRITZ: 40+ hardcoded colors**

---

## Bologna Theme

### File: `/app/themes/bologna/views/pwb/_footer.html.erb`

#### Inline Style Block
```html
<style>
  .footer-custom-content a {
    color: #d98e6e;                  ← Line 188: HARDCODED (terra-400)
    transition: color 0.2s ease;
  }
  .footer-custom-content a:hover {
    color: #e7b5a0;                  ← Line 190: HARDCODED (lighter terra)
  }
  .footer-custom-content p {
    margin-bottom: 0.75rem;
  }
</style>
```

**Available but not used:**
```css
--bologna-terra-400: #d98e6e  /* Could replace line 188 */
--bologna-terra-300: #e7b5a0  /* Could replace line 190 */
```

---

## Brisbane Theme

### File: `/app/themes/brisbane/views/pwb/_header.html.erb`

#### Navigation Links (WRONG COLORS)
```html
<!-- Lines 84-90: Using Tailwind blue instead of luxury gold -->
<% is_active = current_page?(target_path) || (current_page?("/") && page.link_path == "home_path") %>
<li>
  <%= link_to page.link_title, target_path,
      target: page.href_target,
      class: "block py-3 px-5 text-xs font-medium uppercase tracking-luxury transition-all duration-300 #{is_active ? 'text-blue-600 font-semibold' : 'text-luxury-navy hover:text-luxury-gold'}" %>
                                                                     ↑ Line 84-90: SHOULD BE 'text-luxury-gold'
```

**Issue:** Active nav link uses `text-blue-600` instead of `text-luxury-gold` - inconsistent with theme!

### File: `/app/themes/brisbane/views/pwb/_footer.html.erb`

#### Inline Style Block
```html
<style>
  .footer-custom-content a {
    color: #c9a962;                  ← Line 143: HARDCODED (correct gold)
    transition: opacity 0.3s ease;
  }
  .footer-custom-content a:hover {
    color: #e7b5a0;                  ← Line 145: WRONG! (terra color, not gold!)
                                          Should be gold variant like #d4b574 or #dab572
  }
  .footer-custom-content p {
    margin-bottom: 0.75rem;
  }
</style>
```

**Critical Issue:** Line 145 uses terra color (#e7b5a0) which is:
- Copied from Bologna theme
- Wrong for Brisbane's gold color scheme
- Inconsistent with the primary gold color

---

## Barcelona Theme

### File: `/app/themes/barcelona/views/pwb/_footer.html.erb`

#### Inline Style Block
```html
<style>
  .footer-custom-content a {
    color: #E5B45A;                  ← Line 172: HARDCODED (gold variant)
    transition: color 0.2s ease;
  }
  .footer-custom-content a:hover {
    color: #fde047;                  ← Line 174: HARDCODED (bright yellow)
  }
  .footer-custom-content p {
    margin-bottom: 0.75rem;
  }
</style>
```

**Available CSS classes (not used in inline style):**
```
--gold-400: available (could use instead of #E5B45A)
--gold-300: available (could use instead of #fde047)
```

---

## Default Theme

### File: `/app/themes/default/views/pwb/_header.html.erb`

**Status:** ✅ Mostly OK - uses Tailwind system

Minor hardcoded Tailwind classes that could be improved:
```
Line 18:  bg-blue-600          - Language selector active (could be var(--primary-color))
Line 19:  hover:bg-gray-700    - Language selector hover
Line 28:  text-gray-800        - Logo text color
Line 56:  text-blue-600        - Active nav link
Line 60:  hover:text-blue-600  - Nav link hover
```

**Note:** These are not critical as they use Tailwind's built-in system, but could be more consistent with the CSS variable approach.

---

## Summary by Issue Type

### Type 1: Inline Hex Colors (Not Using CSS Variables)

**Biarritz:** 40+ instances
```
bg-[#082F49], border-[#0C4A6E], hover:bg-[#D97706], 
text-[#FEF3C7], text-[#1C1917], etc.
```

**Bologna:** 2 instances
```
#d98e6e, #e7b5a0
```

**Brisbane:** 2 instances
```
#c9a962, #e7b5a0
```

**Barcelona:** 2 instances
```
#E5B45A, #fde047
```

### Type 2: Wrong Tailwind Color Classes (Using Non-Theme Colors)

**Brisbane Header:** 3 instances
```
text-blue-600 (should be text-luxury-gold)
```

### Type 3: Color Scheme Inconsistency

**Brisbane Footer:** 1 critical instance
```
#e7b5a0 (terra brown instead of gold - copied from Bologna)
```

---

## Fix Priority Checklist

### Priority 1 - CRITICAL
- [ ] Biarritz: Create CSS variable file with 40+ color definitions
- [ ] Biarritz header: Remove all inline `bg-[#...]` and `text-[#...]` and use CSS variables
- [ ] Biarritz footer: Remove all inline `bg-[#...]` and `text-[#...]` and use CSS variables
- [ ] Brisbane header line 145: Change `#e7b5a0` to correct gold variant
- [ ] Brisbane header lines 84-90: Change `text-blue-600` to `text-luxury-gold`

### Priority 2 - IMPORTANT
- [ ] Bologna footer lines 188-190: Move to CSS variables
- [ ] Brisbane footer lines 143, 145: Move to CSS variables
- [ ] Barcelona footer lines 172-174: Move to CSS variables
- [ ] Create standardized `--footer-link-color` and `--footer-link-hover-color` variables

### Priority 3 - ENHANCEMENT
- [ ] Default theme: Consider CSS variable consistency
- [ ] Document color variable naming convention
- [ ] Create template for future themes

---

## Color Palette Export Format

Each theme should define colors like this:

```css
:root {
  /* Primary Colors */
  --theme-primary: #color1;
  --theme-secondary: #color2;
  --theme-accent: #color3;
  
  /* Semantic Colors */
  --footer-bg-color: #color4;
  --footer-text-color: #color5;
  --footer-link-color: #color6;
  --footer-link-hover-color: #color7;
  
  /* State Colors */
  --button-hover: #color8;
  --input-focus: #color9;
  --border-color: #color10;
}
```

---

## Biarritz Color Palette (Extracted from Inline Values)

```
#082F49  - Primary Dark (Ocean) - Used for: backgrounds, page bg
#0C4A6E  - Primary Medium (Ocean) - Used for: icons, accent backgrounds
#D97706  - Accent Warm (Amber) - Used for: hover states, highlights
#0369A1  - Secondary (Sky) - Used for: icons, focus states
#FEF3C7  - Light Text (Cream) - Used for: hover text, highlights
#1C1917  - Dark Text (Charcoal) - Used for: main text
#D4D4D8  - Light Gray - Used for: secondary text
#E0F2FE  - Very Light Blue - Used for: active states
#E7E5E4  - Light Border - Used for: borders
#F59E0B  - Light Amber - Used for: gradients
#B91C1C  - Danger Red - Used for: destructive actions
```

This should be formalized in CSS as:

```css
:root {
  --biarritz-dark: #082F49;
  --biarritz-medium: #0C4A6E;
  --biarritz-accent: #D97706;
  --biarritz-secondary: #0369A1;
  --biarritz-cream: #FEF3C7;
  --biarritz-text: #1C1917;
  --biarritz-gray-light: #D4D4D8;
  --biarritz-blue-light: #E0F2FE;
  --biarritz-border: #E7E5E4;
  --biarritz-amber-light: #F59E0B;
  --biarritz-danger: #B91C1C;
}
```

