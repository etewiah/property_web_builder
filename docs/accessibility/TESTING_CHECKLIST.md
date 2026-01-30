# Accessibility Testing Checklist

**Standard:** WCAG 2.1 Level AA
**Last Updated:** January 2026

This document provides comprehensive testing procedures for verifying PropertyWebBuilder's accessibility compliance.

---

## Table of Contents

1. [Automated Testing](#automated-testing)
2. [Manual Testing Procedures](#manual-testing-procedures)
3. [Screen Reader Testing Guide](#screen-reader-testing-guide)
4. [Theme-Specific Testing](#theme-specific-testing)
5. [Component Testing Matrix](#component-testing-matrix)
6. [Regression Testing](#regression-testing)

---

## Automated Testing

### Recommended Tools

| Tool | Purpose | Integration |
|------|---------|-------------|
| **axe-core** | WCAG compliance checking | Playwright, Jest |
| **Lighthouse** | Overall accessibility score | Chrome DevTools, CI |
| **Pa11y** | CI/CD accessibility testing | Command line |
| **WAVE** | Visual accessibility report | Browser extension |
| **Accessibility Insights** | Detailed issue analysis | Edge extension |

### Setting Up axe-core with Playwright

**Installation:**
```bash
npm install @axe-core/playwright --save-dev
```

**Test Example:**
```javascript
// e2e/accessibility.spec.js
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility', () => {
  test('Home page has no critical accessibility issues', async ({ page }) => {
    await page.goto('/');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('Search page is accessible', async ({ page }) => {
    await page.goto('/en/search/buy');

    const results = await new AxeBuilder({ page })
      .include('.search-form')
      .include('.search-results')
      .analyze();

    // Log violations for debugging
    if (results.violations.length > 0) {
      console.log('Violations:', JSON.stringify(results.violations, null, 2));
    }

    expect(results.violations.filter(v => v.impact === 'critical')).toEqual([]);
  });

  test('Property detail page is accessible', async ({ page }) => {
    await page.goto('/en/properties/1');

    const results = await new AxeBuilder({ page })
      .disableRules(['color-contrast']) // May need manual verification for dynamic images
      .analyze();

    expect(results.violations).toEqual([]);
  });
});
```

### Lighthouse CI Configuration

**.lighthouserc.js:**
```javascript
module.exports = {
  ci: {
    collect: {
      url: [
        'http://localhost:3000/',
        'http://localhost:3000/en/search/buy',
        'http://localhost:3000/en/contact_us'
      ],
      numberOfRuns: 3
    },
    assert: {
      assertions: {
        'categories:accessibility': ['error', { minScore: 0.9 }],
        'color-contrast': 'error',
        'heading-order': 'warn',
        'link-name': 'error',
        'button-name': 'error',
        'image-alt': 'error',
        'form-field-multiple-labels': 'error'
      }
    },
    upload: {
      target: 'temporary-public-storage'
    }
  }
};
```

### Pa11y CI Integration

**.pa11yci:**
```json
{
  "defaults": {
    "standard": "WCAG2AA",
    "timeout": 30000,
    "wait": 1000,
    "chromeLaunchConfig": {
      "args": ["--no-sandbox"]
    }
  },
  "urls": [
    "http://localhost:3000/",
    "http://localhost:3000/en/search/buy",
    "http://localhost:3000/en/search/rent",
    "http://localhost:3000/en/contact_us"
  ]
}
```

---

## Manual Testing Procedures

### 1. Keyboard Navigation Testing

**Test Scenario: Complete Site Navigation**

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Press Tab from page load | Skip link becomes visible |  |
| 2 | Press Enter on skip link | Focus moves to main content |  |
| 3 | Continue Tab through page | All interactive elements receive focus in logical order |  |
| 4 | Press Shift+Tab | Focus moves backwards through elements |  |
| 5 | Press Enter on links | Link activates |  |
| 6 | Press Enter/Space on buttons | Button activates |  |
| 7 | Press Escape on modal | Modal closes, focus returns |  |
| 8 | Press Arrow keys on dropdown | Options navigate correctly |  |

**Test Scenario: Search Form**

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Tab to search form | First input receives focus |  |
| 2 | Tab through all fields | Each field receives focus in order |  |
| 3 | Use Arrow keys in select | Options change |  |
| 4 | Press Enter on submit | Form submits |  |
| 5 | Tab to results | Can reach result links |  |

**Test Scenario: Image Gallery**

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Tab to gallery | Gallery container receives focus |  |
| 2 | Press Right Arrow | Next image shows |  |
| 3 | Press Left Arrow | Previous image shows |  |
| 4 | Press Home | First image shows |  |
| 5 | Press End | Last image shows |  |
| 6 | Tab to nav buttons | Prev/Next buttons focusable |  |

### 2. Focus Visibility Testing

**Visual Checklist:**

- [ ] All focusable elements have visible focus indicator
- [ ] Focus indicator has sufficient contrast (3:1 minimum)
- [ ] Focus indicator is clearly visible against all backgrounds
- [ ] Focus ring is at least 2px wide
- [ ] Focus moves logically through the page
- [ ] Focus doesn't get trapped (except in modals)
- [ ] Focus returns to trigger after modal closes

**CSS Focus Check:**
```css
/* Ensure these styles exist */
:focus-visible {
  outline: 3px solid var(--focus-color, #005fcc);
  outline-offset: 2px;
}
```

### 3. Color Contrast Testing

**Tools:**
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- Chrome DevTools Accessibility pane
- Firefox Accessibility Inspector

**Minimum Requirements:**

| Element Type | Minimum Ratio | Example Pass | Example Fail |
|--------------|---------------|--------------|--------------|
| Normal text | 4.5:1 | #595959 on #ffffff | #767676 on #ffffff |
| Large text (>18pt) | 3:1 | #767676 on #ffffff | #a0a0a0 on #ffffff |
| UI components | 3:1 | Button borders, icons | |
| Focus indicators | 3:1 | | |

**Test Each Theme:**

| Theme | Hero Text | Body Text | Links | Buttons | Icons |
|-------|-----------|-----------|-------|---------|-------|
| Default |  |  |  |  |  |
| Barcelona |  |  |  |  |  |
| Biarritz |  |  |  |  |  |
| Bologna |  |  |  |  |  |
| Brisbane |  |  |  |  |  |
| Brussels |  |  |  |  |  |

### 4. Content Structure Testing

**Heading Hierarchy Check:**

Use the WAVE extension or browser inspector to verify:

- [ ] Single `<h1>` per page (page title)
- [ ] Headings follow logical order (no skipping levels)
- [ ] Headings describe section content
- [ ] No headings used purely for styling

**Landmark Structure Check:**

Required landmarks:
- [ ] `<main>` or `role="main"` (one per page)
- [ ] `<nav>` or `role="navigation"` with `aria-label`
- [ ] `<header>` or `role="banner"`
- [ ] `<footer>` or `role="contentinfo"`

### 5. Form Accessibility Testing

**For Each Form:**

| Check | Method | Pass/Fail |
|-------|--------|-----------|
| All inputs have associated labels | `<label for="">` or `aria-label` |  |
| Required fields indicated | Visual + `aria-required` |  |
| Error messages linked to fields | `aria-describedby` |  |
| Errors announced to screen readers | `role="alert"` or `aria-live` |  |
| Autocomplete attributes present | `autocomplete="email"`, etc. |  |
| Form can be submitted via keyboard | Enter key works |  |
| Validation errors are descriptive | Not just "invalid" |  |

### 6. Image & Media Testing

**For Each Image:**

| Check | Pass/Fail |
|-------|-----------|
| Decorative images have `alt=""` or `role="presentation"` |  |
| Informative images have descriptive alt text |  |
| Complex images have detailed descriptions |  |
| Icons have text alternatives or are hidden from AT |  |
| Background images don't convey information |  |

### 7. Dynamic Content Testing

**For AJAX Updates:**

| Check | Method | Pass/Fail |
|-------|--------|-----------|
| Loading states announced | `aria-live="polite"` |  |
| Results announced | Live region updates |  |
| Errors announced | `role="alert"` |  |
| Focus managed appropriately | Focus moves to new content |  |

---

## Screen Reader Testing Guide

### Testing Tools

| Screen Reader | OS | Browser | Primary Users |
|---------------|-----|---------|---------------|
| **NVDA** | Windows | Firefox, Chrome | Free, widely used |
| **VoiceOver** | macOS/iOS | Safari | Built into Apple devices |
| **JAWS** | Windows | Chrome, Edge | Enterprise, most powerful |
| **TalkBack** | Android | Chrome | Mobile Android users |

### NVDA Quick Commands

```
Tab           - Next focusable element
Shift+Tab     - Previous focusable element
Enter         - Activate link/button
Space         - Toggle checkbox, activate button
Arrow Down    - Next item in list/menu
Arrow Up      - Previous item in list/menu
H             - Next heading
Shift+H       - Previous heading
D             - Next landmark
Shift+D       - Previous landmark
F             - Next form field
B             - Next button
Insert+F7     - List of links
Insert+F6     - List of headings
```

### VoiceOver Quick Commands (macOS)

```
VO = Control + Option

Tab             - Next focusable element
VO + Right      - Next item
VO + Left       - Previous item
VO + Space      - Activate
VO + U          - Rotor (navigate by type)
VO + Cmd + H    - Next heading
VO + Cmd + J    - Next control
Escape          - Exit current mode
```

### Screen Reader Test Scenarios

**Test 1: Page Load Announcement**

1. Navigate to page
2. Verify page title is announced
3. Verify main landmark is reachable
4. Check skip link functionality

**Expected:** "Home Page - PropertyWebBuilder" or similar

**Test 2: Navigation Menu**

1. Navigate to main menu
2. Verify menu items are announced
3. Test dropdown opening/closing
4. Verify submenu announcements

**Expected:**
- "Navigation" landmark announced
- "Buy, link" / "Rent, link" items announced
- Dropdown state announced ("expanded"/"collapsed")

**Test 3: Search Form**

1. Navigate to search form
2. Fill out each field
3. Submit the form
4. Verify results announcement

**Expected:**
- Form identified
- Each field label announced
- Required fields indicated
- Results count announced after search

**Test 4: Property Listing**

1. Navigate to property card
2. Verify all content is readable
3. Check image alt text
4. Test link announcement

**Expected:**
- Property title announced
- Price announced
- Features (beds, baths, etc.) announced with context
- Link purpose clear

**Test 5: Image Gallery**

1. Navigate to gallery
2. Test navigation controls
3. Verify slide announcements
4. Test thumbnail navigation

**Expected:**
- "Carousel" or "Image gallery" announced
- "Slide 1 of 5" announced on navigation
- Next/Previous buttons announced

**Test 6: Contact Form**

1. Navigate to contact form
2. Complete all fields
3. Submit with errors
4. Fix errors and resubmit

**Expected:**
- All labels announced
- Required fields indicated
- Errors announced on submit
- Success message announced

### Screen Reader Testing Checklist

| Page | NVDA | VoiceOver | Notes |
|------|------|-----------|-------|
| Home |  |  |  |
| Search (Buy) |  |  |  |
| Search (Rent) |  |  |  |
| Property Detail |  |  |  |
| Contact Us |  |  |  |
| Login/Register |  |  |  |

---

## Theme-Specific Testing

### Color Contrast Matrix

Test each theme's palette against WCAG requirements:

#### Default Theme

| Element | Foreground | Background | Ratio | Pass? |
|---------|------------|------------|-------|-------|
| Body text | #1f2937 | #ffffff | | |
| Primary button | #ffffff | #3b82f6 | | |
| Secondary button | #3b82f6 | #ffffff | | |
| Link text | #2563eb | #ffffff | | |
| Error text | #dc2626 | #fef2f2 | | |
| Muted text | #6b7280 | #ffffff | | |

#### Barcelona Theme

| Element | Foreground | Background | Ratio | Pass? |
|---------|------------|------------|-------|-------|
| Body text | | | | |
| Primary button | | | | |
| Hero text | | image overlay | | |

#### Biarritz Theme

| Element | Foreground | Background | Ratio | Pass? |
|---------|------------|------------|-------|-------|
| Body text | | | | |
| Primary button | | | | |
| Hero text | | image overlay | | |

#### Bologna Theme

| Element | Foreground | Background | Ratio | Pass? |
|---------|------------|------------|-------|-------|
| Body text | | | | |
| Primary button | | | | |
| Hero text | | image overlay | | |

#### Brisbane Theme

| Element | Foreground | Background | Ratio | Pass? |
|---------|------------|------------|-------|-------|
| Body text | | | | |
| Gold accent | | white | | |
| Hero text | | image overlay | | |

#### Brussels Theme

| Element | Foreground | Background | Ratio | Pass? |
|---------|------------|------------|-------|-------|
| Body text | | | | |
| Lime accent | | | | |
| Hero text | | image overlay | | |

---

## Component Testing Matrix

### Critical Components

| Component | Keyboard | Screen Reader | Focus | ARIA | Notes |
|-----------|----------|---------------|-------|------|-------|
| Skip Link | | | | | |
| Main Nav | | | | | |
| Mobile Menu | | | | | |
| Language Switcher | | | | | |
| Search Form | | | | | |
| Custom Dropdown | | | | | |
| Image Gallery | | | | | |
| Tabs | | | | | |
| Modal Dialog | | | | | |
| Contact Form | | | | | |
| Property Cards | | | | | |
| Breadcrumbs | | | | | |
| Footer | | | | | |

### Status Key
- ✅ Passes all checks
- ⚠️ Minor issues
- ❌ Critical issues
- ⏳ Not tested yet

---

## Regression Testing

### Pre-Release Checklist

Before each release, run through:

1. **Automated Tests**
   - [ ] axe-core tests pass
   - [ ] Lighthouse accessibility score >= 90
   - [ ] Pa11y reports no critical issues

2. **Manual Smoke Tests**
   - [ ] Keyboard navigation works on home page
   - [ ] Skip link functions correctly
   - [ ] Search form is accessible
   - [ ] Contact form is accessible
   - [ ] Property detail page is accessible

3. **Screen Reader Quick Check**
   - [ ] Page titles announce correctly
   - [ ] Navigation is usable
   - [ ] Forms are labeled
   - [ ] Dynamic content announces

### After Major Changes

When modifying these areas, run full accessibility test suite:

- [ ] Layout/CSS changes
- [ ] Form modifications
- [ ] JavaScript controller changes
- [ ] New component additions
- [ ] Theme palette changes

---

## Reporting Issues

### Issue Template

```markdown
## Accessibility Issue

**WCAG Criterion:** [e.g., 1.4.3 Contrast]
**Severity:** [Critical/Major/Minor]
**Component:** [e.g., Custom Dropdown]
**Browser/AT:** [e.g., Chrome + NVDA]

### Steps to Reproduce
1. Navigate to...
2. Tab to...
3. Observe...

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Screenshot/Recording
[If applicable]

### Suggested Fix
[If known]
```

### Severity Definitions

- **Critical:** Prevents user from completing task or accessing content
- **Major:** Significant barrier that requires workaround
- **Minor:** Inconvenience but content is still accessible

---

## Resources

### Testing Tools
- [axe Browser Extension](https://www.deque.com/axe/)
- [WAVE Browser Extension](https://wave.webaim.org/)
- [Accessibility Insights](https://accessibilityinsights.io/)
- [Colour Contrast Analyser](https://www.tpgi.com/color-contrast-checker/)

### Documentation
- [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)
- [WebAIM Articles](https://webaim.org/articles/)

### Screen Reader Downloads
- [NVDA (Free)](https://www.nvaccess.org/)
- [VoiceOver (Built into macOS/iOS)](https://support.apple.com/guide/voiceover/)
- [JAWS (Commercial)](https://www.freedomscientific.com/products/software/jaws/)
