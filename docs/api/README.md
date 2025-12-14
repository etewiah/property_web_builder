# API Documentation

Documentation for PropertyWebBuilder's REST and GraphQL APIs.

## Contents

| Document | Description |
|----------|-------------|
| [01_rest_api.md](01_rest_api.md) | REST API endpoints for admin panel |
| [Signup API](../signup/02_api_reference.md) | Signup flow endpoints |

## API Overview

PropertyWebBuilder provides two API interfaces:

### REST API (`/api/v1/`)

Used by the admin panel for managing website content:

- **Properties** - CRUD operations for property listings
- **Agency** - Agency information management
- **Contacts** - Contact form submissions
- **Links** - Navigation link management
- **Pages** - Page content management
- **Themes** - Theme selection
- **Translations** - Multi-language content

### GraphQL API (`/graphql`)

Public API for frontend applications:

- `search_properties` - Property search with filters
- `find_property` - Single property lookup
- `get_site_details` - Website configuration
- `get_translations` - Locale translations
- `get_top_nav_links` / `get_footer_links` - Navigation

### Signup API (`/signup/`)

Self-service website creation flow - see [Signup API Reference](../signup/02_api_reference.md).

## Authentication

REST API endpoints require authentication via session cookie or API token.
GraphQL public queries are unauthenticated but scoped to the current website.
