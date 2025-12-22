# Vue.js Frontend - REMOVED

**Status**: Removed as of December 2024

**Replacement**: Server-rendered ERB views with Stimulus.js

## Overview

The Vue.js applications that were previously in this directory have been **removed**. The project now uses a server-rendered approach with:

- **ERB templates** - Rails view templates
- **Liquid templates** - For dynamic page parts and theming
- **Tailwind CSS** - For styling
- **Stimulus.js** - For JavaScript interactions
- **Alpine.js** - For simple UI interactions in admin panels

## Removed Applications

| Directory | Description | Status |
|-----------|-------------|--------|
| `v-public-app/` | Public-facing Vue SPA | Removed |
| `v-public-2-app/` | Alternative public Vue app | Removed |
| `v-admin-app/` | Admin panel Vue SPA | Removed |
| `entrypoints/` | Vite entrypoints for Vue apps | Removed |

## Current Architecture

### For Public Pages
- ERB views in `app/views/pwb/`
- Theme templates in `app/themes/`
- Stimulus controllers in `app/javascript/controllers/`
- Tailwind CSS for styling

### For Admin Pages
- ERB views in `app/views/site_admin/` and `app/views/tenant_admin/`
- Alpine.js for simple interactivity
- Standard Rails form helpers

## Migration Complete

All functionality has been migrated to server-rendered templates with Stimulus.js.
GraphQL API has also been deprecated (see `app/graphql/DEPRECATED.md`).
