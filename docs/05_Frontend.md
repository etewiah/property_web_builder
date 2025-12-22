# Frontend Documentation

This document provides an overview of the frontend architecture for PropertyWebBuilder.

## Architecture

The frontend uses a **server-rendered** approach with:

| Technology | Purpose |
|------------|---------|
| **ERB Templates** | Rails view templates |
| **Liquid Templates** | Dynamic page parts and theming |
| **Tailwind CSS** | Styling (responsive, utility-first) |
| **Stimulus.js** | JavaScript interactions |
| **Importmap** | ES module loading (no build step) |

### Deprecated

The following are deprecated and should not be used for new development:

- **Vue.js** - See `app/frontend/DEPRECATED.md`
- **GraphQL API** - See `app/graphql/DEPRECATED.md`
- **Bootstrap CSS** - See `vendor/assets/stylesheets/bootstrap/DEPRECATED.md`

---

## JavaScript with Stimulus

Stimulus provides modest JavaScript for server-rendered HTML. See [Stimulus Guide](./frontend/STIMULUS_GUIDE.md) for full documentation.

### Available Controllers

| Controller | Purpose |
|------------|---------|
| `toggle` | Show/hide elements |
| `tabs` | Tabbed interfaces |
| `gallery` | Property photo carousels |
| `dropdown` | Dropdown menus |
| `filter` | Search filter panels |

### Example Usage

```erb
<div data-controller="toggle">
  <button data-action="toggle#toggle">Show Details</button>
  <div data-toggle-target="content" class="hidden">
    Property details here...
  </div>
</div>
```

### Creating Controllers

```bash
rails generate stimulus my_controller
```

---

## Public Pages

| Route | Controller | Description |
|-------|------------|-------------|
| `/` | `welcome_controller` | Home page with featured properties |
| `/buy` | `search_controller` | Property search (for sale) |
| `/rent` | `search_controller` | Property search (for rent) |
| `/properties/:id/:title` | `props_controller` | Property detail page |
| `/p/:page_slug` | `pages_controller` | Custom CMS pages |
| `/about-us` | `pages_controller` | About page |
| `/contact-us` | `contact_us_controller` | Contact form |

---

## Admin Panel

The admin panel is located at `/site_admin` and uses server-rendered ERB views with Stimulus for interactivity.

### Sections

| Section | Description |
|---------|-------------|
| Dashboard | Website activity overview |
| Properties | Manage property listings |
| Pages | Manage custom pages |
| Content | Manage reusable content blocks |
| Messages | View contact form submissions |
| Settings | Website and agency configuration |

---

## Theming

Themes are located in `app/themes/` and use:

- **Liquid templates** for page parts
- **Tailwind CSS** for styling
- **CSS variables** for customization

See [Theming System](./theming/11_Theming_System.md) for details.

---

## Assets

### CSS
- Tailwind CSS (primary)
- SCSS via Dart Sass (legacy)

### JavaScript
- Stimulus controllers in `app/javascript/controllers/`
- Loaded via importmap (no build step required)

### Images
- Stored via Active Storage
- Served from CDN when configured

---

## Resources

- [Stimulus Guide](./frontend/STIMULUS_GUIDE.md)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Liquid Templates](https://shopify.github.io/liquid/)
