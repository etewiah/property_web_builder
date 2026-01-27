# WYSIWYG Editor Component Guidelines

This document captures best practices for designing Liquid templates and CSS that work well with the WYSIWYG inline editor.

## Problem Summary

When editing content inline, the editor displays a popup/popover for text editing. We encountered issues where:

1. **Popover obscured by content**: Hero buttons and other elements with `z-index` appeared above the edit popover
2. **Stacking context escape**: Child elements with `z-index: 10` escaped their container and overlapped UI elements
3. **Links navigating away**: Clicking links in edit mode navigated away from the editor

## Root Causes

### Z-Index Stacking Context Issues

CSS `z-index` only works within the same **stacking context**. A new stacking context is created by:
- `position: fixed` or `position: sticky`
- `position: absolute` or `position: relative` with `z-index` other than `auto`
- `opacity` less than 1
- `transform`, `filter`, `perspective`, `clip-path`, `mask`
- `isolation: isolate`

**The Problem**: When a hero section uses `z-index: 10` on its content wrapper, that z-index can "escape" and affect elements outside the hero if no stacking context boundary exists.

```html
<!-- PROBLEMATIC: z-10 escapes and affects popover -->
<div class="editor-preview">
  <section class="hero">
    <div class="hero-content relative z-10">  <!-- This z-10 escapes! -->
      <button>Click me</button>
    </div>
  </section>
</div>
<div class="popover z-[9999]">...</div>  <!-- Hero content appears above this! -->
```

### The Solution: Stacking Context Isolation

The editor now applies `isolation: isolate` to preview containers:

```css
.pwb-wysiwyg-editor__content {
  overflow: hidden;
  isolation: isolate;  /* Creates stacking context boundary */
  position: relative;
  z-index: 0;
}

.pwb-editable-content {
  isolation: isolate;
  position: relative;
  z-index: 0;
}
```

This ensures all child z-indexes are contained within the preview area.

---

## Liquid Template Guidelines

### 1. Avoid High Z-Index Values

**Bad**: Using arbitrary high z-index values
```html
<div class="relative z-50">
  {{ content }}
</div>
```

**Good**: Use minimal z-index, only when necessary for internal layering
```html
<div class="relative z-0">
  <div class="absolute inset-0 z-0">{{ background }}</div>
  <div class="relative z-10">{{ content }}</div>
</div>
```

### 2. Keep Z-Index Relative and Low

For hero sections with background overlays:

**Recommended Pattern**:
```liquid
<section class="hero relative">
  <!-- Background layer: z-0 -->
  <div class="absolute inset-0 z-0">
    <img src="{{ background_image }}" class="w-full h-full object-cover" />
    <div class="absolute inset-0 bg-black/50"></div>
  </div>

  <!-- Content layer: z-[1] (not z-10 or higher) -->
  <div class="relative z-[1] text-center">
    <h1>{{ title }}</h1>
    <p>{{ subtitle }}</p>
  </div>
</section>
```

### 3. Avoid Position Fixed in Editable Components

Components with `position: fixed` create new stacking contexts at the viewport level, which can interfere with the editor popover.

**Avoid in editable sections**:
```html
<!-- Don't use position:fixed in editable content -->
<div class="fixed top-0 left-0 z-50">...</div>
```

### 4. Use Semantic Class Names with PWB Prefix

Use the `pwb-` prefix for elements that the editor needs to identify:

```liquid
<section class="pwb-hero hero-section">
  <p class="pwb-hero__pretitle">{{ pretitle }}</p>
  <h1 class="pwb-hero__title">{{ title }}</h1>
  <p class="pwb-hero__subtitle">{{ subtitle }}</p>
  <div class="pwb-hero__cta-wrapper">
    <a href="{{ cta_1_url }}" class="pwb-btn pwb-hero__cta-link">
      {{ cta_1_text }}
    </a>
  </div>
</section>
```

### 5. Add data-pwb-link Attribute to Links

Links in editable content should have `data-pwb-link="true"` to allow the editor to prevent navigation during edit mode:

```liquid
<a href="{{ page_part.cta_link.content | default: '#' | localize_url }}"
   class="pwb-btn pwb-btn--primary"
   data-pwb-link="true">
  {{ page_part.cta_text.content }}
</a>
```

---

## CSS Rules for Editable Components

### Required Editor Styles

The editor applies these styles to contain component z-indexes:

```css
/* Container isolation */
.pwb-wysiwyg-editor__content {
  overflow: hidden;
  isolation: isolate;
  position: relative;
  z-index: 0;
}

.pwb-editable-content {
  isolation: isolate;
  position: relative;
  z-index: 0;
}

/* Disable link navigation in edit mode */
.pwb-editable-content a {
  cursor: default;
}

/* Popover must be highest */
.pwb-field-popover {
  z-index: 9999 !important;
}
```

### Component CSS Guidelines

1. **Never use z-index > 10** in component CSS
2. **Use z-0 through z-[5]** for internal layering
3. **Avoid position: fixed** in editable content
4. **Don't use transform on containers** that need z-index ordering
5. **Add isolation: isolate** to section containers (`.pwb-hero`, `.pwb-cta`, etc.)

### PWB Component Isolation Pattern

All PWB section components should include isolation:

```css
.pwb-hero {
  position: relative;
  overflow: hidden;
  isolation: isolate;  /* Contains all child z-indexes */
}

.pwb-cta {
  position: relative;
  isolation: isolate;
}
```

---

## Checklist for New Components

Before adding a new Liquid template:

- [ ] Z-index values are ≤ 10 (preferably ≤ 5)
- [ ] Background layers use z-0
- [ ] Content layers use z-[1] or z-[2] maximum
- [ ] No `position: fixed` elements
- [ ] PWB class prefix used for editable elements
- [ ] Links have `data-pwb-link="true"` attribute
- [ ] CSS includes `isolation: isolate` on section container
- [ ] Tested in WYSIWYG editor with popover open

---

## Troubleshooting

### Popover appears behind content

1. Check if component has high z-index values
2. Verify `isolation: isolate` is on parent containers
3. Check browser DevTools for stacking context issues

### Content escapes editor preview

1. Add `overflow: hidden` to container
2. Add `isolation: isolate` to create stacking boundary
3. Check for `position: fixed` elements

### Links navigate when clicking to edit

1. Ensure `data-pwb-link="true"` attribute is present
2. Check that click handler prevents default on links

---

## References

- [MDN: Stacking Context](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_positioned_layout/Understanding_z-index/Stacking_context)
- [CSS Tricks: Z-Index](https://css-tricks.com/almanac/properties/z/z-index/)
- [Isolation Property](https://developer.mozilla.org/en-US/docs/Web/CSS/isolation)
