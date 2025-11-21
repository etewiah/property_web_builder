# Multi-tenancy Support

Property Web Builder supports multi-tenancy, allowing a single instance of the application to serve multiple websites. Each website has its own isolated data, including properties, pages, content, and configuration.

## Architecture

The multi-tenancy implementation uses a **Shared Database, Shared Schema** approach. All tenants (websites) share the same database tables, but data is scoped by a `website_id` column.

### Key Components

1.  **Pwb::Website Model**: Represents a tenant. It has a `slug` which is used as a unique identifier.
2.  **Pwb::Current**: An `ActiveSupport::CurrentAttributes` model that stores the current website for the duration of a request.
3.  **Data Scoping**: Models such as `Prop`, `Page`, `Content`, `Link`, and `Agency` belong to a `Website`.

## Tenant Resolution

The current tenant is resolved based on the `X-Website-Slug` HTTP header sent with each request.

1.  **Request Arrival**: When a request hits the `GraphqlController`, a `before_action` triggers `set_current_website`.
2.  **Header Inspection**: The controller looks for the `X-Website-Slug` header.
3.  **Lookup**: It attempts to find a `Pwb::Website` with a matching `slug`.
4.  **Context Setting**: If found, `Pwb::Current.website` is set to that website instance.
5.  **Fallback**: If the header is missing or the slug is invalid, it falls back to the default website (typically the first one created or a specific "default" instance).

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

To create a new website, use the Rails console:

```ruby
Pwb::Website.create!(slug: "my-new-site", company_display_name: "My New Site")
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

*   `pwb_websites.slug` (String, Indexed)
*   `pwb_props.website_id` (Integer, Indexed)
*   `pwb_pages.website_id` (Integer, Indexed)
*   `pwb_contents.website_id` (Integer, Indexed)
*   `pwb_links.website_id` (Integer, Indexed)
*   `pwb_agencies.website_id` (Integer, Indexed)
