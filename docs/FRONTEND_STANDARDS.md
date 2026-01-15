# Frontend Coding Standards & CSS Naming Convention

## Accessibility Standards

All components must use semantic HTML elements and support ARIA roles where appropriate. Ensure:
- Sufficient color contrast for text and UI elements
- Keyboard navigation for all interactive elements
- Use of `alt` attributes for images and descriptive labels for form fields
- Avoid tabindex except for custom navigation

## Theme Integration & CSS Variables

Themes should use CSS variables for colors, spacing, and typography. Example:
```css
:root {
  --pwb-primary-color: #0055a5;
  --pwb-accent-color: #eab308;
}
.pwb-btn--primary {
  background: var(--pwb-primary-color);
}
```
Document how to override variables for each theme and palette. Always use semantic classes with variables.

## Responsive Design Standards

Follow mobile-first principles. Use Tailwind breakpoints or custom media queries. Example:
```html
<div class="pwb-prop-card w-full lg:w-1/3">
  ...
</div>
```
Specify breakpoints for:
- Property cards
- Search forms
- Navigation

## Testing & Automation

All major components must have E2E and visual regression tests. Use semantic classes as selectors in Playwright/Cypress. Example:
```js
page.locator('.pwb-prop-card__cta').click();
```
Add accessibility tests for color contrast and keyboard navigation.

## Seed Data Consistency

All seed HTML (YAML, JSON, etc.) must include semantic classes. Use automated linting to check compliance. Example:
```yaml
section_html: '<div class="pwb-header__logo-img">Logo</div>'
```

## Component Documentation

For each major component, add a short description, usage notes, and link to screenshots or live examples. Example:
- **Property Card**: Displays summary info for a property. Used in search results and featured lists. [Screenshot](../screenshots/dev/default/home-desktop.png)

## Versioning & Change Log

Track changes to standards and conventions in this document. Add a changelog section at the end.

---

## Core Principle: Namespaced BEM

We use a modified **BEM (Block Element Modifier)** convention with a project-specific namespace.

**Format:** `.pwb-<block>__<element>--<modifier>`

*   **Namespace (`pwb-`)**: All custom classes must begin with this prefix. This avoids conflicts with external libraries (e.g., Bootstrap, Tailwind, Leaflet).
*   **Block**: The high-level component context (e.g., `header`, `listing-card`, `search-box`).
*   **Element**: A distinct part of the block (e.g., `logo`, `title`, `submit-button`).
*   **Modifier**: A variation or state (e.g., `primary`, `active`, `large`).

### Examples

| Component | Standard BEM Class |
| :--- | :--- |
| **Site Header** | `.pwb-header` |
| **Header Logo** | `.pwb-header__logo-img` |
| **Primary Button** | `.pwb-btn--primary` |
| **Active Nav Link** | `.pwb-nav__link--active` |
| **Property Price** | `.pwb-prop-card__price` |

---

## Standard Class Registry

Use these defined class names for standard components to maintain consistency across the application.

### 1. Global Layout

| Element | Class Name | Description |
| :--- | :--- | :--- |
| `<body>` | `.pwb-body` | Root body element |
| `<main>` | `.pwb-main` | Main content wrapper |
| Footer | `.pwb-footer` | Site footer container |
| Container | `.pwb-container` | Standard width container (if not using utility only) |

### 2. Header & Navigation (`pwb-header`, `pwb-nav`)

| Element | Class Name | Notes |
| :--- | :--- | :--- |
| Header Wrapper | `.pwb-header` | |
| Top Bar | `.pwb-header__top-bar` | Optional area above main nav |
| Logo Wrapper | `.pwb-header__logo-wrapper` | |
| Logo Image | `.pwb-header__logo-img` | |
| Logo Text | `.pwb-header__logo-text` | Fallback if no image |
| Main Nav | `.pwb-header__nav` | |
| Nav List | `.pwb-header__menu-list` | `<ul>` |
| Nav Item | `.pwb-header__menu-item` | `<li>` |
| Nav Link | `.pwb-header__menu-link` | `<a>` |
| Mobile Toggle | `.pwb-header__mobile-toggle` | Hamburger menu button |

### 3. Property Cards (`pwb-prop-card`)

Used in search results and "Featured Properties" lists.

| Element | Class Name | Notes |
| :--- | :--- | :--- |
| Card Wrapper | `.pwb-prop-card` | |
| Image Wrapper | `.pwb-prop-card__img-wrapper` | |
| Image | `.pwb-prop-card__img` | |
| Content Body | `.pwb-prop-card__body` | |
| Title | `.pwb-prop-card__title` | |
| Price | `.pwb-prop-card__price` | |
| Address | `.pwb-prop-card__address` | |
| Features List | `.pwb-prop-card__features` | Bed/Bath/Sqft counts |
| Feature Item | `.pwb-prop-card__feature-item` | |
| Action Button | `.pwb-prop-card__cta` | "View Details" button |

### 4. Property Details Page (`pwb-prop-detail`)

| Element | Class Name | Notes |
| :--- | :--- | :--- |
| Wrapper | `.pwb-prop-detail` | |
| Title | `.pwb-prop-detail__title` | |
| Price | `.pwb-prop-detail__price` | |
| Description | `.pwb-prop-detail__desc` | |
| Gallery | `.pwb-prop-detail__gallery` | |
| Map Container | `.pwb-prop-detail__map` | |
| Agent Info | `.pwb-prop-detail__agent` | |

### 5. Search Components (`pwb-search`)

| Element | Class Name | Notes |
| :--- | :--- | :--- |
| Search Box | `.pwb-search-box` | Main search container |
| Input Field | `.pwb-search-box__input` | Text inputs |
| Select Dropdown | `.pwb-search-box__select` | Dropdowns |
| Submit Button | `.pwb-search-box__submit` | |
| Advanced Toggle | `.pwb-search-box__advanced-toggle`| |

### 6. Forms (`pwb-form`)

Generic styles for contact forms, inquiry forms, etc.

| Element | Class Name | Notes |
| :--- | :--- | :--- |
| Form Wrapper | `.pwb-form` | |
| Field Group | `.pwb-form__group` | Wrapper for label + input |
| Label | `.pwb-form__label` | |
| Input | `.pwb-form__input` | Text, Email, Tel types |
| Textarea | `.pwb-form__textarea` | |
| Checkbox | `.pwb-form__checkbox` | |
| Submit Button | `.pwb-form__submit` | |

---

## Utility vs. Semantic Classes

We use **Tailwind CSS** for utility styling, but **Semantic Classes** (`pwb-*`) are required for:
1.  **Theming:** Allowing a client theme to override styles without fighting Tailwind specificity.
2.  **JavaScript Hooks:** Providing stable selectors for JS functionality.
3.  **Testing:** Reliable selectors for E2E tests.

**Rule:** Always include the semantic class *before* utility classes.

**Good:**
```html
<button class="pwb-btn--primary bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded">
  Search
</button>
```

**Bad:**
```html
<button class="bg-blue-500 text-white py-2 px-4"> <!-- No semantic class -->
  Search
</button>
```

---

## Implementation Checklist

### 1. View Templates (`app/views/`)
Iterate through all Layouts and Partials. Add `pwb-*` classes to all structural elements.

*   [ ] `layouts/application.html.erb`
*   [ ] `pwb/shared/_header.html.erb`
*   [ ] `pwb/shared/_footer.html.erb`
*   [ ] `pwb/search/_search_box.html.erb`
*   [ ] `pwb/props/_prop_card.html.erb`

### 2. Seed Data (`db/yml_seeds/`)
Update the HTML templates stored in YAML files for page parts.

*   [ ] `page_parts/home__heroes_*.yml` (Hero sections)
*   [ ] `page_parts/home__content_*.yml` (Content blocks)
*   [ ] `page_parts/contact-us__*.yml` (Contact forms)

### 3. JavaScript
Ensure Stimulus controllers and other scripts use these standard classes where possible, or dedicated `js-*` classes if state management is complex.
