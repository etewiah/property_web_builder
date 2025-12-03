# Semantic CSS Classes for PropertyWebBuilder

This document defines the standard semantic CSS classes that all themes must support. These classes provide a consistent API for templates while allowing themes to customize the visual appearance.

## Core Principles

1. **Semantic naming**: Classes describe purpose, not appearance
2. **Theme independence**: Templates use these classes, themes style them
3. **Framework agnostic**: No framework-specific utilities (no Tailwind, Bootstrap classes)
4. **Composable**: Classes can be combined for variations

## Component Classes

### Layout

#### Grid System
```css
.pwb-grid                  /* Grid container */
.pwb-grid-cols-2           /* 2-column grid */
.pwb-grid-cols-3           /* 3-column grid */
.pwb-grid-cols-4           /* 4-column grid */
.pwb-grid-gap-small        /* Small gap between items */
.pwb-grid-gap-medium       /* Medium gap (default) */
.pwb-grid-gap-large        /* Large gap */
```

#### Container
```css
.pwb-container             /* Main content container */
.pwb-container-fluid       /* Full-width container */
.pwb-container-narrow      /* Narrow content container */
```

### Navigation

```css
.pwb-nav                   /* Navigation container */
.pwb-nav-primary           /* Primary navigation */
.pwb-nav-secondary         /* Secondary/footer navigation */
.pwb-nav-item              /* Navigation item */
.pwb-nav-link              /* Navigation link */
.pwb-nav-link-active       /* Active navigation link */
```

### Buttons

```css
.pwb-btn                   /* Base button */
.pwb-btn-primary           /* Primary action button */
.pwb-btn-secondary         /* Secondary button */
.pwb-btn-outlined          /* Outlined button */
.pwb-btn-large             /* Large button */
.pwb-btn-small             /* Small button */
.pwb-btn-block             /* Full-width button */
```

### Cards

```css
.pwb-card                  /* Card container */
.pwb-card-link             /* Clickable card */
.pwb-card-image            /* Card image container */
.pwb-card-content          /* Card content area */
.pwb-card-title            /* Card title */
.pwb-card-description      /* Card description text */
.pwb-card-footer           /* Card footer */
.pwb-card-highlight        /* Highlighted/featured card */
```

### Links

```css
.pwb-link                  /* Standard link */
.pwb-link-primary          /* Primary colored link */
.pwb-link-secondary        /* Secondary colored link */
.pwb-link-underlined       /* Underlined link */
```

### Hero/Jumbotron

```css
.pwb-hero                  /* Hero section */
.pwb-hero-title            /* Hero title */
.pwb-hero-subtitle         /* Hero subtitle */
.pwb-hero-content          /* Hero content area */
.pwb-hero-image            /* Hero background image */
.pwb-hero-actions          /* Hero CTA buttons container */
```

### Forms

```css
.pwb-form                  /* Form container */
.pwb-form-group            /* Form field group */
.pwb-form-label            /* Form label */
.pwb-form-input            /* Text input */
.pwb-form-textarea         /* Textarea */
.pwb-form-select           /* Select dropdown */
.pwb-form-checkbox         /* Checkbox */
.pwb-form-radio            /* Radio button */
.pwb-form-error            /* Error message */
.pwb-form-help             /* Help text */
```

### Content

```css
.pwb-heading-1             /* Main heading (h1) */
.pwb-heading-2             /* Secondary heading (h2) */
.pwb-heading-3             /* Tertiary heading (h3) */
.pwb-text                  /* Body text */
.pwb-text-muted            /* Muted/secondary text */
.pwb-text-small            /* Small text */
.pwb-text-large            /* Large text */
```

### Images

```css
.pwb-image                 /* Standard image */
.pwb-image-responsive      /* Responsive image */
.pwb-image-rounded         /* Rounded corners */
.pwb-image-circle          /* Circular image */
.pwb-image-thumbnail       /* Thumbnail image */
```

### Property-Specific

```css
.pwb-property-card         /* Property listing card */
.pwb-property-image        /* Property image */
.pwb-property-title        /* Property title */
.pwb-property-price        /* Property price */
.pwb-property-location     /* Property location */
.pwb-property-features     /* Property features list */
.pwb-property-grid         /* Property grid layout */
```

### Utilities

```css
.pwb-spacing-top-small     /* Small top spacing */
.pwb-spacing-top-medium    /* Medium top spacing */
.pwb-spacing-top-large     /* Large top spacing */
.pwb-spacing-bottom-small  /* Small bottom spacing */
.pwb-spacing-bottom-medium /* Medium bottom spacing */
.pwb-spacing-bottom-large  /* Large bottom spacing */
.pwb-text-center           /* Center text */
.pwb-text-left             /* Left-align text */
.pwb-text-right            /* Right-align text */
```

## Implementation Guidelines

### For Theme Developers

1. **All themes MUST implement these classes**
2. **Visual style is up to the theme** (colors, fonts, spacing can vary)
3. **Maintain responsive behavior** (mobile-first approach)
4. **Use CSS variables** for theme customization:

```css
:root {
  --pwb-color-primary: #3b82f6;
  --pwb-color-secondary: #1f2937;
  --pwb-color-background: #ffffff;
  --pwb-color-text: #1f2937;
  --pwb-font-family: 'Inter', sans-serif;
  --pwb-border-radius: 0.375rem;
}
```

### For Template Developers

1. **Only use classes from this list** in `.liquid` templates
2. **Never use framework-specific utilities** (no `text-blue-500`, `col-md-4`, etc.)
3. **Combine classes for variations**: `class="pwb-btn pwb-btn-primary pwb-btn-large"`
4. **Test templates with multiple themes** to ensure compatibility

## Migration from Framework Classes

### Bootstrap → Semantic

| Bootstrap | Semantic PWB |
|-----------|-------------|
| `btn btn-primary` | `pwb-btn pwb-btn-primary` |
| `card` | `pwb-card` |
| `row` | `pwb-grid` |
| `col-md-4` | `pwb-grid pwb-grid-cols-3` (inside grid) |
| `container` | `pwb-container` |
| `jumbotron` | `pwb-hero` |

### Tailwind → Semantic

| Tailwind | Semantic PWB |
|----------|-------------|
| `text-blue-600` | `pwb-btn-primary` (or theme CSS var) |
| `grid grid-cols-3` | `pwb-grid pwb-grid-cols-3` |
| `rounded-lg` | `pwb-image-rounded` |
| `p-4` | Use theme's spacing |

## Validation

Use the linting rake task to check templates:

```bash
bundle exec rake pwb:templates:lint
```

This will warn about:
- Framework-specific utility classes
- Non-semantic class names
- Missing required classes
