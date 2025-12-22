# Vue.js Frontend - DEPRECATED

**Status**: Deprecated as of December 2024

**Replacement**: Server-rendered ERB views with Liquid templates

## Overview

The Vue.js applications in this directory are **deprecated** and will no longer be actively maintained. The project has transitioned to a server-rendered approach using:

- **ERB templates** - Rails view templates
- **Liquid templates** - For dynamic page parts and theming
- **Tailwind CSS** - For styling
- **Vanilla JavaScript** - For simple interactions (consider Stimulus for organization)

## Deprecated Applications

| Directory | Description | Status |
|-----------|-------------|--------|
| `v-public-app/` | Public-facing Vue SPA | Deprecated |
| `v-public-2-app/` | Alternative public Vue app | Deprecated |
| `v-admin-app/` | Admin panel Vue SPA | Deprecated |
| `entrypoints/` | Vite entrypoints for Vue apps | Deprecated |

## What to Use Instead

### For Public Pages
- Use ERB views in `app/views/pwb/`
- Use Liquid templates for page parts in `app/themes/`
- Use Tailwind CSS for styling

### For Admin Pages
- Use ERB views in `app/views/site_admin/`
- Use standard Rails form helpers
- Consider Stimulus.js for interactive components

### For API Communication
- Use REST API endpoints (see `docs/api/`)
- GraphQL is also deprecated (see `app/graphql/DEPRECATED.md`)

## Why Deprecated?

1. **Simpler architecture** - Server-rendered pages reduce complexity
2. **Better SEO** - No JavaScript required for content indexing
3. **Faster initial load** - No large JavaScript bundle to download
4. **Easier theming** - Liquid templates are more accessible
5. **Reduced maintenance** - One technology stack instead of two

## Migration Path

New features should be built using:
1. ERB/Liquid templates for markup
2. Tailwind CSS for styling
3. Stimulus.js for JavaScript interactions (optional)
4. Turbo for page transitions (optional)

## Timeline

- **December 2024**: Deprecated, no new features
- **Future**: Will be removed once all functionality is migrated

## Questions?

See `docs/05_Frontend.md` for current frontend architecture.
