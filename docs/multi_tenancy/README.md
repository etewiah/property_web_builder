# Multi-Tenancy Documentation

This folder contains comprehensive documentation about PropertyWebBuilder's multi-tenant architecture, including routing, data isolation, and development patterns.

## Documentation Files

### 1. [routing_implementation.md](./routing_implementation.md) - Technical Reference

**Purpose:** Comprehensive technical reference of all multi-tenancy components.

**Contains:**
- Website model and database schema details
- SubdomainTenant concern implementation
- Current attributes pattern explanation
- Controller architecture (SiteAdmin, TenantAdmin, Public)
- Acts-as-tenant configuration
- Model hierarchy (Pwb:: vs PwbTenant::)
- Route constraints and structure
- Data isolation and scoping mechanisms
- Subdomain resolution priority
- Detailed file listing with line numbers

**Best for:** Developers who need to understand implementation details, debugging issues, or making changes to the multi-tenancy system.

### 2. [routing_architecture.md](./routing_architecture.md) - Visual Diagrams

**Purpose:** Visual representations of the multi-tenancy system.

**Contains:**
- High-level request flow diagram
- Controller hierarchy tree
- Data flow for scoped queries
- Website lookup flow chart
- Database schema relationships
- Request routing decision tree
- Authorization levels visualization
- Environment variable configuration
- Cross-tenant data isolation example

**Best for:** Quick visual understanding, onboarding new developers, or explaining the system to stakeholders.

### 3. [multi_tenancy_guide.md](./multi_tenancy_guide.md) - Development Guide

**Purpose:** Practical guide for working with multi-tenancy as a developer.

**Contains:**
- Quick start for different controller types
- Model patterns and usage examples
- Routing patterns and examples
- Query examples for common scenarios
- Controller best practices
- Common pitfalls and how to avoid them
- Testing strategies with code examples
- Debugging techniques
- Summary comparison table

**Best for:** Developers writing code, adding new features, or learning the patterns used in PropertyWebBuilder.

## Quick Navigation

### I want to...

- **Understand how requests are routed to tenants** → Read [routing_implementation.md](./routing_implementation.md) "Subdomain-Based Routing Concern" section

- **See a visual overview** → Look at [routing_architecture.md](./routing_architecture.md) "High-Level Request Flow" diagram

- **Create a new controller** → Follow [multi_tenancy_guide.md](./multi_tenancy_guide.md) "Quick Start" section

- **Write a query** → Check [multi_tenancy_guide.md](./multi_tenancy_guide.md) "Query Examples" section

- **Debug a tenant isolation issue** → See [multi_tenancy_guide.md](./multi_tenancy_guide.md) "Debugging Multi-Tenancy Issues"

- **Understand data scoping** → Read [routing_implementation.md](./routing_implementation.md) "Data Isolation & Scoping" section

- **Set up cross-tenant access** → Check [routing_implementation.md](./routing_implementation.md) "TenantAdminController" section and [multi_tenancy_guide.md](./multi_tenancy_guide.md) "Cross-Tenant Queries"

- **Add a new model** → Follow [multi_tenancy_guide.md](./multi_tenancy_guide.md) "Model Patterns" section

## Key Concepts Quick Reference

### Subdomain-Based Routing

Each tenant is identified by a unique subdomain (e.g., `myagency.example.com`). The `SubdomainTenant` concern extracts and resolves the subdomain to a `Pwb::Website` record.

**Priority:**
1. `X-Website-Slug` header (for API clients)
2. Request subdomain (for browsers)
3. First website (fallback)

### Automatic Tenant Scoping

Models inheriting from `PwbTenant::ApplicationRecord` are automatically scoped to the current tenant via `acts_as_tenant`. No manual WHERE clauses needed for tenant isolation.

```ruby
PwbTenant::Contact.all  # => Auto-scoped to current website
```

### Two Model Namespaces

- **Pwb::** - Non-scoped models (Website, User). Global access, manual scoping needed.
- **PwbTenant::** - Scoped models (Contact, Prop). Auto-scoped to current tenant.

### Three Controller Types

| Type | Scope | Use Case |
|------|-------|----------|
| Pwb::* | Single website (public) | Public website content |
| SiteAdmin::* | Single website (admin) | Admin dashboard for one website |
| TenantAdmin::* | All websites | Super-admin cross-tenant management |

### Authorization

- **Public:** No authentication needed
- **Site Admin:** User must be authenticated + admin for that website
- **Tenant Admin:** User email must be in `TENANT_ADMIN_EMAILS` environment variable

## Architecture Layers

```
┌─────────────────────────────────────────┐
│         ROUTING LAYER                   │
│  SubdomainTenant concern                │
│  - Extracts subdomain/header            │
│  - Sets Pwb::Current.website            │
└─────────────────────────────────────────┘
              ▼
┌─────────────────────────────────────────┐
│         CONTROLLER LAYER                │
│  - SiteAdminController (single tenant)  │
│  - TenantAdminController (cross-tenant) │
│  - Pwb::ApplicationController (public)  │
└─────────────────────────────────────────┘
              ▼
┌─────────────────────────────────────────┐
│         TENANT CONTEXT LAYER            │
│  ActsAsTenant.current_tenant            │
│  - Set in controller before_action      │
└─────────────────────────────────────────┘
              ▼
┌─────────────────────────────────────────┐
│         MODEL LAYER                     │
│  - Pwb:: models (non-scoped)            │
│  - PwbTenant:: models (auto-scoped)     │
└─────────────────────────────────────────┘
              ▼
┌─────────────────────────────────────────┐
│         DATABASE LAYER                  │
│  - website_id foreign key on all tables │
│  - Unique indexes per-website where needed
└─────────────────────────────────────────┘
```

## Common Tasks

### Creating a New Controller for Single Website Admin

1. Create controller inheriting from `SiteAdminController`
2. It automatically:
   - Resolves website from subdomain
   - Requires authentication + authorization
   - Sets tenant context for models
3. Use `PwbTenant::` models for auto-scoped queries

See example in [multi_tenancy_guide.md](./multi_tenancy_guide.md)

### Adding a New Tenant-Scoped Model

1. Create model in `app/models/pwb_tenant/` namespace
2. Inherit from `PwbTenant::ApplicationRecord`
3. Ensure table has `website_id` column (indexed)
4. Queries are automatically scoped

See example in [multi_tenancy_guide.md](./multi_tenancy_guide.md)

### Cross-Tenant Admin Query

1. Use `TenantAdminController` (no SubdomainTenant concern)
2. For PwbTenant:: models, use `ActsAsTenant.with_tenant(website)` or `ActsAsTenant.without_tenant`
3. Or manually use Pwb:: models with `where(website_id: ...)`

See example in [multi_tenancy_guide.md](./multi_tenancy_guide.md)

### Testing Multi-Tenancy

1. Create fixtures with multiple websites
2. Set host/subdomain in request specs
3. Verify queries are scoped correctly
4. Test authorization boundaries

See examples in [multi_tenancy_guide.md](./multi_tenancy_guide.md)

## File Reference

**Controllers:**
- `/app/controllers/pwb/application_controller.rb` - Public website base
- `/app/controllers/site_admin_controller.rb` - Single-tenant admin base
- `/app/controllers/tenant_admin_controller.rb` - Cross-tenant admin base

**Models:**
- `/app/models/pwb/website.rb` - Website model (tenant identifier)
- `/app/models/pwb/application_record.rb` - Non-scoped model base
- `/app/models/pwb/current.rb` - Request-scoped current attributes
- `/app/models/pwb_tenant/application_record.rb` - Scoped model base

**Concerns:**
- `/app/controllers/concerns/subdomain_tenant.rb` - Subdomain routing logic

**Configuration:**
- `/config/routes.rb` - Route definitions
- `/config/initializers/acts_as_tenant.rb` - Acts_as_tenant config
- `/lib/constraints/tenant_admin_constraint.rb` - Route constraint

**Schema:**
- `/db/schema.rb` - Database schema (see pwb_websites table)

## Related Documentation

- [Architecture decisions](../architecture/) - Design decisions and patterns
- [Seed packs](../seeding/) - Multi-tenant seed data
- [Field keys system](../field_keys/) - Tenant-scoped configuration

## Troubleshooting

### Issue: Wrong website data showing

**Cause:** Not using auto-scoped models or missing WHERE clause

**Solution:** 
- Use `PwbTenant::` models for auto-scoping
- Or manually add `where(website_id: current_website.id)`

### Issue: Subdomain not resolving

**Cause:** 
- DNS not configured
- Rails domain configuration issue
- Reserved subdomain being used

**Solution:**
- Check DNS A/CNAME records
- Verify `config.hosts` in environment file
- See reserved subdomains list in Website model

### Issue: Authorization failing

**Cause:** 
- Not authenticated
- User not admin for website
- Not in TENANT_ADMIN_EMAILS list

**Solution:**
- Check authentication status
- Verify user role with `user.admin_for?(website)`
- Check TENANT_ADMIN_EMAILS environment variable

## More Information

For implementation details, see the individual documentation files:
- **Technical details:** [routing_implementation.md](./routing_implementation.md)
- **Visual diagrams:** [routing_architecture.md](./routing_architecture.md)
- **Development guide:** [multi_tenancy_guide.md](./multi_tenancy_guide.md)

For questions or contributions, follow the project's CONTRIBUTING guidelines.
