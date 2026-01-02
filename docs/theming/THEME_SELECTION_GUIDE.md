# Theme Selection Guide

This guide helps you choose the right theme for your PropertyWebBuilder website based on your business needs, target audience, and visual preferences.

## Available Themes

### Production-Ready Themes

| Theme | Style | Best For | Key Features |
|-------|-------|----------|--------------|
| **Default** | Clean, modern | General purpose | Versatile, multiple palettes |
| **Brisbane** | Luxury, elegant | High-end properties | Gold accents, premium feel |
| **Bologna** | Warm, Mediterranean | European markets | Terracotta tones, classic feel |
| **Brussels** | Modern, Material Design | Urban markets | Lime green, sharp corners, shadows |

### Development/Disabled Themes

| Theme | Status | Notes |
|-------|--------|-------|
| Barcelona | Disabled | Under development |
| Biarritz | Disabled | Under development |

---

## Theme Details

### Default Theme

**Overview:** A versatile, clean theme suitable for any real estate website.

**Color Palettes:**
- Classic Red - Traditional real estate branding
- Ocean Blue - Professional, trustworthy
- Forest Green - Eco-friendly, sustainable focus
- Sunset Orange - Warm, inviting

**Best For:**
- New websites getting started
- Agencies wanting flexibility
- Custom branding requirements

**Typography:** Open Sans (clean, readable)

---

### Brisbane Theme

**Overview:** A luxury-focused theme designed for premium property listings.

**Color Palettes:**
- Gold & Navy (default) - Classic luxury
- Rose Gold - Feminine elegance
- Platinum - Modern luxury
- Emerald Luxury - Sophisticated green
- Azure Prestige - Coastal premium

**Best For:**
- Luxury real estate agencies
- High-end property markets
- Premium vacation rentals
- Exclusive developments

**Key Design Elements:**
- Elegant gold accents
- Refined typography
- Premium card styling
- Sophisticated animations

**Typography:** Playfair Display (headings), Lato (body)

---

### Bologna Theme

**Overview:** A warm, Mediterranean-inspired theme with classic European charm.

**Color Palettes:**
- Terracotta Classic (default) - Warm earth tones
- Sage Stone - Natural, calming
- Coastal Warmth - Beach-inspired
- Modern Slate - Contemporary twist

**Best For:**
- European property markets
- Mediterranean vacation rentals
- Historic property specialists
- Agencies with warm branding

**Key Design Elements:**
- Terracotta color accents
- Warm background tones
- Classic proportions
- Inviting feel

**Typography:** Merriweather (traditional, readable)

---

### Brussels Theme

**Overview:** A modern, Material Design-inspired theme with bold lime green accents and sharp geometric styling. Inspired by buenavistahomes.eu.

**Color Palettes:**
- Lime Green (default) - Bold, energetic, modern

**Best For:**
- Urban property markets
- Modern apartment rentals
- Commercial real estate
- Tech-savvy audiences
- European city markets

**Key Design Elements:**
- Lime green (#9ACD32) primary accent
- Dark semi-transparent header
- Material Design shadows (3-level elevation)
- Sharp corners (0-2px border radius)
- Catamaran font family
- High contrast color scheme

**Unique Features:**
- Material Design shadow system (`shadow-card`, `shadow-card-hover`, `shadow-card-raised`)
- Backdrop blur effects on hero section
- Bold property price badges
- Clean, minimalist property cards
- Full-width hero with integrated search

**Technical Specs:**
- Primary: #9ACD32 (Lime Green)
- Secondary: #131313 (Near Black)
- Footer: #616161 (Gray)
- WCAG AA compliant for most combinations

**Typography:** Catamaran (modern, geometric sans-serif)

---

## Choosing the Right Theme

### By Property Type

| Property Type | Recommended Theme |
|---------------|-------------------|
| Luxury homes | Brisbane |
| City apartments | Brussels |
| Vacation rentals | Bologna |
| Commercial | Brussels, Default |
| Mixed portfolio | Default |
| Historic properties | Bologna |

### By Target Market

| Market | Recommended Theme |
|--------|-------------------|
| European cities | Brussels, Bologna |
| Mediterranean coast | Bologna |
| Australian/US luxury | Brisbane |
| International | Default |
| Modern urban | Brussels |
| Traditional | Bologna, Default |

### By Brand Personality

| Personality | Recommended Theme |
|-------------|-------------------|
| Professional | Default, Brussels |
| Luxurious | Brisbane |
| Warm & welcoming | Bologna |
| Modern & bold | Brussels |
| Classic & trusted | Default, Bologna |
| Energetic | Brussels |

---

## Theme Comparison Matrix

| Feature | Default | Brisbane | Bologna | Brussels |
|---------|---------|----------|---------|----------|
| Color palettes | 4 | 5 | 4 | 1 |
| Dark mode | Yes | Yes | Yes | Yes |
| Material shadows | No | No | No | Yes |
| Sharp corners | No | No | No | Yes |
| Hero search | Yes | Yes | Yes | Yes |
| Property cards | Standard | Premium | Warm | Material |
| Border radius | 0.5rem | 0.375rem | 0.5rem | 0-0.25rem |

---

## Accessibility Considerations

All themes are designed to meet WCAG 2.1 Level AA standards:

| Theme | Contrast Rating | Notes |
|-------|----------------|-------|
| Default | Excellent | All combinations pass |
| Brisbane | Excellent | Gold on dark passes |
| Bologna | Excellent | Terracotta combinations pass |
| Brussels | Good | Lime on white advisory (use lime as background) |

### Brussels Accessibility Note

The lime green (#9ACD32) on white backgrounds has insufficient contrast for normal text. The theme uses lime as a background color with dark text, or lime on dark backgrounds, which both pass WCAG AA.

---

## Testing a Theme

### Preview Without Changing

Add `?theme=themename` to any URL:
```
https://yoursite.com/?theme=brussels
https://yoursite.com/en/buy?theme=brisbane
```

### Switching Themes

1. Go to Admin → Settings → Appearance
2. Select theme from dropdown
3. Choose palette (if available)
4. Save changes

### Running Theme Tests

```bash
# Verify all templates exist
bundle exec rspec spec/views/themes/theme_completeness_spec.rb

# Run theme component tests
bundle exec rspec spec/views/themes/theme_components_spec.rb

# Run contrast compliance tests (Brussels)
bundle exec rspec spec/views/themes/brussels_contrast_spec.rb

# Run visual E2E tests
npx playwright test tests/e2e/themes/brussels.spec.js
```

---

## Customization Options

Each theme supports these customizations:

1. **Color Palette** - Switch between pre-defined palettes
2. **Custom CSS** - Add raw CSS for additional styling
3. **Dark Mode** - Enable automatic or forced dark mode
4. **Logo/Branding** - Upload custom logo and favicon

For extensive customization, consider:
- Creating a new palette JSON file
- Adding custom CSS via admin panel
- Creating a child theme

---

## Related Documentation

- [Theme Creation Checklist](./THEME_CREATION_CHECKLIST.md)
- [Theme and Color System Architecture](./THEME_AND_COLOR_SYSTEM.md)
- [Quick Start Guide](./QUICK_START_GUIDE.md)
- [Brussels Contrast Guide](./BIARRITZ_CONTRAST_GUIDE.md)

---

**Last Updated:** 2026-01-02
