# Theming Quick Start Guide

This guide shows you how to implement the most effective and flexible theming solution for PropertyWebBuilder.

---

## Creating a New Color Palette

### Step 1: Create Palette JSON File

Create a new file: `app/themes/{your_theme}/palettes/{palette_name}.json`

```json
{
  "id": "ocean_blue",
  "name": "Ocean Blue",
  "description": "Calm and professional ocean-inspired palette",
  "preview_colors": ["#0077be", "#2c3e50", "#16a085"],
  "is_default": false,
  "colors": {
    "primary_color": "#0077be",
    "secondary_color": "#2c3e50",
    "accent_color": "#16a085",
    "background_color": "#ffffff",
    "text_color": "#333333",
    "header_background_color": "#ffffff",
    "header_text_color": "#333333",
    "footer_background_color": "#2c3e50",
    "footer_text_color": "#ffffff",
    "card_background_color": "#ffffff",
    "card_text_color": "#333333",
    "border_color": "#e2e8f0",
    "surface_color": "#f8f9fa",
    "surface_alt_color": "#e9ecef",
    "success_color": "#22c55e",
    "warning_color": "#f59e0b",
    "error_color": "#ef4444",
    "muted_text_color": "#6b7280",
    "link_color": "#0077be",
    "link_hover_color": "#005a8f",
    "button_primary_background": "#0077be",
    "button_primary_text": "#ffffff",
    "button_secondary_background": "#e9ecef",
    "button_secondary_text": "#333333",
    "input_background_color": "#ffffff",
    "input_border_color": "#cbd5e0",
    "input_focus_color": "#0077be"
  }
}
```

### Step 2: Validate Your Palette

```bash
rails runner "puts Pwb::PaletteValidator.new('app/themes/default/palettes/ocean_blue.json').validate"
```

### Step 3: Test in Browser

1. Set palette in website settings
2. Check all pages for proper color application
3. Test dark mode (if supported)
4. Verify contrast ratios for accessibility

---

## Adding Dark Mode Support

### Option 1: Auto-Generated Dark Mode

The system can automatically generate dark mode colors:

```ruby
# In your palette loader
light_colors = palette["colors"]
dark_colors = Pwb::ColorUtils.generate_dark_mode_colors(light_colors)
```

### Option 2: Manual Dark Mode Colors

Add a `modes` structure to your palette JSON:

```json
{
  "id": "ocean_blue",
  "name": "Ocean Blue",
  "modes": {
    "light": {
      "primary_color": "#0077be",
      "background_color": "#ffffff",
      "text_color": "#333333"
      // ... all colors
    },
    "dark": {
      "primary_color": "#4da6ff",
      "background_color": "#121212",
      "text_color": "#e8e8e8"
      // ... all colors
    }
  }
}
```

---

## Using Icons

### Basic Icon Usage

```erb
<%= icon(:home) %>
<%= icon(:search, size: :lg) %>
<%= icon(:star, filled: true) %>
```

### Icon with Accessibility

```erb
<%= icon(:warning, aria: { label: "Warning: Check your input" }) %>
```

### Icon Button

```erb
<%= icon_button(:close, 
  button_class: "btn-icon", 
  aria: { label: "Close dialog" }
) %>
```

### Brand/Social Icons

```erb
<%= brand_icon(:facebook) %>
<%= social_icon_link(:instagram, "https://instagram.com/yourpage") %>
```

### Available Icons

See full list in `app/helpers/pwb/icon_helper.rb` (280+ icons)

Common icons:
- Navigation: `home`, `search`, `menu`, `close`, `arrow_back`, `arrow_forward`
- Property: `bed`, `bathroom`, `local_parking`, `square_foot`
- Actions: `edit`, `delete`, `add`, `share`, `favorite`
- Status: `check`, `error`, `warning`, `info`

---

## Configuring Fonts

### Current Limitation

⚠️ **Font loading is not yet fully implemented.** See `THEMING_SYSTEM_AUDIT.md` for details.

### Temporary Workaround

Add fonts manually to your theme CSS:

```css
/* app/assets/stylesheets/tailwind-{theme}.css */

/* Option 1: Self-hosted via @fontsource */
@import "@fontsource-variable/inter";
@import "@fontsource/merriweather/400.css";

/* Option 2: Google Fonts */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');

:root {
  --pwb-font-primary: 'Inter', system-ui, sans-serif;
  --pwb-font-heading: 'Merriweather', Georgia, serif;
  --pwb-font-size-base: 16px;
}
```

### Recommended Font Pairings

**Modern & Clean:**
- Primary: Inter, Heading: Inter (same font, different weights)

**Professional:**
- Primary: Open Sans, Heading: Montserrat

**Editorial:**
- Primary: Lato, Heading: Playfair Display

**Friendly:**
- Primary: Nunito, Heading: Nunito

**Technical:**
- Primary: Roboto, Heading: Roboto Slab

---

## Best Practices

### Color Palettes

1. **Start with 3 core colors:**
   - Primary: Your brand color
   - Secondary: Complementary or neutral
   - Accent: For CTAs and highlights

2. **Ensure sufficient contrast:**
   - Text on background: 4.5:1 minimum (WCAG AA)
   - Large text: 3:1 minimum
   - Use `Pwb::ColorUtils.wcag_aa_compliant?` to check

3. **Test in both modes:**
   - Light mode (default)
   - Dark mode (if supported)
   - High contrast mode

4. **Use semantic colors:**
   - Success: Green (#22c55e)
   - Warning: Yellow/Orange (#f59e0b)
   - Error: Red (#ef4444)

### Icons

1. **Always use the icon helper:**
   ```erb
   <%= icon(:name) %>  <!-- ✅ Good -->
   <span class="material-symbols-outlined">name</span>  <!-- ❌ Bad -->
   ```

2. **Add ARIA labels for meaningful icons:**
   ```erb
   <%= icon(:delete, aria: { label: "Delete property" }) %>
   ```

3. **Use consistent sizes:**
   - `:sm` (18px) - Inline with text
   - `:md` (24px) - Default, buttons
   - `:lg` (36px) - Feature icons
   - `:xl` (48px) - Hero sections

### Fonts

1. **Limit font families:**
   - Maximum 2 font families per theme
   - Use font weights for hierarchy

2. **Optimize loading:**
   - Preload critical fonts
   - Use `font-display: swap`
   - Subset to needed characters

3. **Provide fallbacks:**
   ```css
   font-family: 'Inter', system-ui, -apple-system, sans-serif;
   ```

---

## Testing Your Theme

### Visual Testing Checklist

- [ ] Homepage renders correctly
- [ ] Property listing page
- [ ] Property detail page
- [ ] Contact forms
- [ ] Header and footer
- [ ] Mobile responsive
- [ ] Dark mode (if supported)

### Accessibility Testing

- [ ] Color contrast ratios (use browser DevTools)
- [ ] Keyboard navigation
- [ ] Screen reader compatibility
- [ ] Focus indicators visible

### Performance Testing

- [ ] Fonts load quickly
- [ ] No layout shift (CLS)
- [ ] CSS file size reasonable (<50KB)

---

## Common Issues & Solutions

### Issue: Colors not applying

**Solution:** Check that you're using standard color keys (not legacy keys like `header_bg_color`)

### Issue: Icons not showing

**Solution:** Verify icon name is in `ALLOWED_ICONS` list in `icon_helper.rb`

### Issue: Fonts falling back to system fonts

**Solution:** Add `@import` or `<link>` to load fonts (see Font Configuration section)

### Issue: Dark mode colors look wrong

**Solution:** Define custom dark mode colors instead of using auto-generated ones

---

## Next Steps

1. Read the full audit: `docs/theming/THEMING_SYSTEM_AUDIT.md`
2. Review existing themes for examples
3. Test your theme thoroughly
4. Submit for review

For questions, see the main documentation or ask the development team.

