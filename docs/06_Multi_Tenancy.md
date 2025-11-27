# Multi-tenancy Support

Property Web Builder supports multi-tenancy, allowing a single instance of the application to serve multiple websites. Each website has its own isolated data, including properties, pages, content, and configuration.

## Architecture

The multi-tenancy implementation uses a **Shared Database, Shared Schema** approach. All tenants (websites) share the same database tables, but data is scoped by a `website_id` column.

### Key Components

1.  **Pwb::Website Model**: Represents a tenant. It has a `slug` and `subdomain` which are used as unique identifiers.
2.  **Pwb::Current**: An `ActiveSupport::CurrentAttributes` model that stores the current website for the duration of a request.
3.  **Data Scoping**: Models such as `Prop`, `Page`, `Content`, `Link`, and `Agency` belong to a `Website`.

## Tenant Resolution

The current tenant can be resolved in two ways:

### 1. Subdomain-based Resolution (Recommended)

Tenants are automatically identified by the subdomain of the request URL:
- `tenant1.yourdomain.com` → resolves to website with `subdomain: "tenant1"`
- `tenant2.yourdomain.com` → resolves to website with `subdomain: "tenant2"`

Reserved subdomains that are ignored: `www`, `api`, `admin`

### 2. Header-based Resolution

For API requests, the `X-Website-Slug` HTTP header can be used:

```
X-Website-Slug: my-site-slug
```

**Priority Order:**
1. `X-Website-Slug` header (highest priority)
2. Request subdomain
3. Default website fallback

## Data Isolation

Data isolation is enforced at the application level, specifically within the GraphQL resolvers.

### Scoped Models

The following models are scoped to a website:

*   **Properties (`Pwb::Prop`)**: Listings are specific to a site.
*   **Pages (`Pwb::Page`)**: Site structure and content pages.
*   **Content (`Pwb::Content`)**: Text snippets and translations.
*   **Links (`Pwb::Link`)**: Navigation menus (Top Nav, Footer).
*   **Agency (`Pwb::Agency`)**: Contact details and branding configuration.

### GraphQL Queries

All GraphQL queries in `Types::QueryType` are updated to use `Pwb::Current.website` as the starting point.

**Example:**

```ruby
# Old (Single-tenant)
def search_properties(**args)
  Pwb::Prop.properties_search(**args)
end

# New (Multi-tenant)
def search_properties(**args)
  Pwb::Current.website.props.properties_search(**args)
end
```

This ensures that a query for properties only returns those belonging to the identified tenant.

## Usage

### Creating a New Tenant

#### Using Rake Task (Recommended)

```bash
# Create a new tenant with seeded data
rake pwb:db:create_tenant[my-subdomain,my-slug,"My Company Name"]

# List all tenants
rake pwb:db:list_tenants
```

#### Using Rails Console

```ruby
Pwb::Website.create!(
  subdomain: "my-subdomain",
  slug: "my-site-slug",
  company_display_name: "My New Site"
)
```

### Seeding Data for Tenants

The seed rake tasks now support multi-tenancy:

```bash
# Seed the default website
rake pwb:db:seed

# Seed a specific tenant by subdomain or slug
rake pwb:db:seed_tenant[my-subdomain]

# Seed all tenants
rake pwb:db:seed_all_tenants

# Create and seed a new tenant
rake pwb:db:create_tenant[subdomain,slug,Company Name]

# List all tenants
rake pwb:db:list_tenants
```

### API Requests

When making requests to the GraphQL API, include the header:

```
X-Website-Slug: my-new-site
```

### Frontend Configuration

The frontend application (Quasar) is configured to send this header automatically. In `src/boot/urql.js`, the client is set up with:

```javascript
fetchOptions: () => {
  return {
    headers: {
      'X-Website-Slug': 'standard' // Or dynamically determined slug
    },
  }
},
```

## Database Schema Changes

The following columns were added to support this feature:

*   `pwb_websites.slug` (String, Indexed, Unique)
*   `pwb_websites.subdomain` (String, Indexed, Unique)
*   `pwb_props.website_id` (Integer, Indexed)
*   `pwb_pages.website_id` (Integer, Indexed)
*   `pwb_contents.website_id` (Integer, Indexed)
*   `pwb_links.website_id` (Integer, Indexed)
*   `pwb_agencies.website_id` (Integer, Indexed)

## Development Testing

For local development, use `lvh.me` which resolves to localhost and supports subdomains:

```
http://tenant1.lvh.me:3000  → tenant1's website
http://tenant2.lvh.me:3000  → tenant2's website
http://lvh.me:3000          → default website
```

The development environment is configured to allow these hosts automatically.
