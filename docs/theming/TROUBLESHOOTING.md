# Theming Troubleshooting Guide

## Issue: Selected Palette Not Reflecting on Page

**Symptoms:**
- You select a new palette in the admin UI.
- The page reloads but colors remain unchanged or partially unchanged.
- Inspecting the CSS shows hardcoded hex values instead of dynamic variables.

**Cause:**
Some legacy theme CSS files (e.g., `_bologna.css.erb`) may have hardcoded color values or shade generation logic that ignores the global PWB CSS variables.

**Solution:**
Update the theme's `_theme_name.css.erb` file to map its internal variables to the standard PWB CSS variables.

**Example Fix (Bologna Theme):**

*Before:*
```css
:root {
  --bologna-terra: <%= @current_website.style_variables["primary_color"] || "#c45d3e" %>;
  /* Hardcoded shades */
  --bologna-terra-50: #fdf8f6; 
}
```

*After:*
```css
:root {
  /* Map to standard PWB variables */
  --bologna-terra: var(--pwb-primary-color);
  /* Map to dynamic shades */
  --bologna-terra-50: var(--pwb-primary-50);
}
```

## Issue: Missing Colors (Footer, etc.)

**Symptoms:**
- Primary colors update, but footer or header backgrounds do not.

**Cause:**
Legacy themes often use legacy keys (e.g., `footer_bg_color`) while new palettes use standard keys (e.g., `footer_background_color`).

**Solution:**
Ensure the theme CSS uses the standard keys or maps the legacy keys to the standard PWB variables (e.g., `var(--pwb-footer-background-color)`).

## Issue: Tailwind Utility Classes (e.g., bg-primary) Not Updating

**Symptoms:**
- You use classes like `bg-primary` or `text-primary` in your HTML.
- Changing the palette does not update these colors.
- Inspecting the element shows the class is using a hardcoded hex value.

**Cause:**
The Tailwind CSS build process may be using hardcoded values in the `@theme` configuration block within `app/assets/stylesheets/tailwind-*.css`.

**Solution:**
1. Update the `app/assets/stylesheets/tailwind-theme_name.css` file to use CSS variables in the `@theme` block.

```css
@theme {
  --color-primary: var(--pwb-primary-color);
  --color-secondary: var(--pwb-secondary-color);
  --color-accent: var(--pwb-accent-color);
}
```

2. Rebuild the Tailwind CSS assets:
```bash
npm run tailwind:build
```
