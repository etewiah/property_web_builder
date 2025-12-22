# GraphQL API - DEPRECATED

**Status**: Deprecated as of December 2024

## Notice

The GraphQL API in this directory is **deprecated** and will no longer be actively maintained. While the code remains functional, new features should use the REST API endpoints instead.

## Recommendations

- **For new integrations**: Use the REST API at `/api/v1/` or `/api_public/v1/`
- **For existing integrations**: Continue using GraphQL, but plan migration to REST
- **For contributors**: Do not add new GraphQL types or mutations

## Endpoints

- `POST /graphql` - GraphQL endpoint (deprecated)
- `GET /graphiql` - GraphiQL IDE (development only, deprecated)

## Migration Path

The following REST endpoints provide equivalent functionality:

| GraphQL Query | REST Equivalent |
|--------------|-----------------|
| `search_properties` | `GET /api_public/v1/properties` |
| `find_property` | `GET /api_public/v1/properties/:id` |
| `get_site_details` | `GET /api_public/v1/website` |
| `get_top_nav_links` | `GET /api_public/v1/links?position=top_nav` |
| `get_footer_links` | `GET /api_public/v1/links?position=footer` |

## Why Deprecated?

- REST API provides simpler integration for most use cases
- Reduces maintenance burden
- Better alignment with standard Rails patterns

## Future

This code may be removed in a future major version. If you have a use case that requires GraphQL, please open an issue to discuss.
