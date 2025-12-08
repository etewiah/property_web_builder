# Multi-Tenancy Routing Architecture Diagram

## High-Level Request Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INCOMING REQUEST                            │
│  (Browser, API, or GraphQL client)                                  │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│              SUBDOMAIN EXTRACTION & RESOLUTION                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 1. Check X-Website-Slug header (API clients)               │   │
│  │    └─ Website.find_by(slug: header_value)                  │   │
│  │                                                             │   │
│  │ 2. Extract request.subdomain                               │   │
│  │    └─ Filter out: www, api, admin                          │   │
│  │    └─ Website.find_by_subdomain(subdomain)                 │   │
│  │       (case-insensitive lookup)                             │   │
│  │                                                             │   │
│  │ 3. Fallback to Website.first                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                    [SubdomainTenant concern]                         │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
                       ▼ Sets Pwb::Current.website
┌─────────────────────────────────────────────────────────────────────┐
│                    WEBSITE IDENTIFIED                               │
│  Pwb::Current.website = Website[id: 1, subdomain: "myagency", ...]  │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
                       ▼ Sets ActsAsTenant.current_tenant
┌─────────────────────────────────────────────────────────────────────┐
│              TENANT CONTEXT ESTABLISHED                             │
│  ActsAsTenant.current_tenant = current_website                      │
│                                                                     │
│  All PwbTenant:: queries now automatically scoped:                 │
│  PwbTenant::Contact.all =>                                          │
│    SELECT * FROM pwb_contacts WHERE website_id = 1                 │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┬──────────────┐
        │                             │              │
        ▼                             ▼              ▼
    PUBLIC ROUTES           SITE ADMIN ROUTES    TENANT ADMIN ROUTES
 (Pwb::ApplicationController) (SiteAdminController) (TenantAdminController)
        │                             │              │
        ├─ Subdomain scoped      ├─ Subdomain scoped   ├─ CROSS-TENANT
        ├─ No auth required      ├─ Auth required  ├─ No SubdomainTenant
        ├─ Theme per website     ├─ Locale per web     ├─ TENANT_ADMIN_EMAILS
        └─ Tenant isolation      └─ Admin only     └─ Full cross-tenant
                                                        access
```

## Controller Hierarchy

```
┌──────────────────────────────────────────┐
│   Rails ActionController::Base           │
└──────────────────────────────────────────┘
         │                    │
         ▼                    ▼
    ┌─────────────┐    ┌──────────────────────┐
    │ SiteAdmin   │    │ TenantAdminController│
    │ Controller  │    │                      │
    └─────────────┘    └──────────────────────┘
         │                    │
    includes:             includes:
    └─ Subdomain       └─ AdminAuthBypass
       Tenant          └─ NO Subdomain
    ├─ AdminAuth        Tenant
       Bypass       └─ Pagy::Backend
    ├─ Pagy::Backend
    └─ AuthHelper
         │
    sets:
    └─ ActsAsTenant.current_tenant
       = current_website
         │
    result:
    └─ PwbTenant:: models auto-scoped
    └─ Single website access


                │
                ▼
┌──────────────────────────────────┐
│  Pwb::ApplicationController      │
│  (Public website routes)         │
└──────────────────────────────────┘
    includes: NO concerns
    
    uses:
    ├─ current_website_from_subdomain
    ├─ current_website fallback
    └─ set_theme_path per website
    
    result:
    └─ Public website content
       scoped to subdomain
```

## Data Flow for Scoped Queries

### Auto-Scoped Query (PwbTenant:: models)

```
Request: https://site1.example.com/contacts

Pwb::Current.website = Website[id: 1, subdomain: "site1"]
ActsAsTenant.current_tenant = Website[id: 1]

Code:
  PwbTenant::Contact.all

Generated SQL:
  SELECT * FROM pwb_contacts WHERE website_id = 1

Result: Only contacts for site1
```

### Cross-Tenant Query (TenantAdminController)

```
Request: https://admin.example.com/tenant_admin/websites

(TenantAdminController - NO SubdomainTenant concern)

Code:
  Website.all

Generated SQL:
  SELECT * FROM pwb_websites

Result: All websites (cross-tenant)

Alternative with explicit scoping bypass:
  ActsAsTenant.without_tenant do
    PwbTenant::Contact.all
  end
  
  Generated SQL:
    SELECT * FROM pwb_contacts  (no WHERE clause)
```

### Manual Scoping (Pwb:: models)

```
Code:
  Pwb::Prop.where(website_id: current_website.id)

Generated SQL:
  SELECT * FROM pwb_props WHERE website_id = 1
  
Result: Only props for site1
```

## Website Lookup Flow

```
┌────────────────────────────────────────┐
│     Request arrives at application     │
└────────────────────────────────────────┘
                │
                ▼
        ┌───────────────────┐
        │ SubdomainTenant   │
        │ concern included? │
        └─────┬─────────────┘
              │
        YES   │   NO
              ▼   ▼
        ┌─────────────────────────────────┐
        │  set_current_website_from_      │
        │  subdomain called               │
        │                                 │
        │  Priority:                      │
        │  1. X-Website-Slug header       │
        │  2. request.subdomain           │
        │  3. Website.first (fallback)    │
        │                                 │
        └─────────┬───────────────────────┘
                  │
              Sets:
              Pwb::Current.website
              │
              ▼
        ┌──────────────────────────┐
        │ Set tenant context       │
        │ (if SiteAdminController) │
        └──────────┬───────────────┘
                   │
              ActsAsTenant.
              current_tenant =
              current_website
                   │
                   ▼
        ┌──────────────────────────┐
        │ All PwbTenant:: queries  │
        │ auto-scoped to this      │
        │ website                  │
        └──────────────────────────┘
```

## Database Schema: Multi-Tenancy Fields

```
┌─────────────────────────────┐
│     pwb_websites            │
├─────────────────────────────┤
│ id (PK)                     │
│ subdomain (unique) ◄───┐    │
│ slug (unique)      ◄───┼─ Routing identifiers
│ company_display_   ◄───┘    │
│   name                      │
│ theme_name                  │
│ ...config fields...         │
└─────────────────────────────┘
         │
         │ has_many
         │
         ├─────────────────────────────────┐
         │                                 │
         ▼                                 ▼
┌─────────────────────┐        ┌─────────────────────┐
│ pwb_props           │        │ pwb_contacts        │
├─────────────────────┤        ├─────────────────────┤
│ id (PK)             │        │ id (PK)             │
│ website_id (FK) ◄───┼────┐   │ website_id (FK) ◄───┼───┐
│ reference           │    │   │ first_name          │   │
│ title               │    │   │ email               │   │
│ ...                 │    │   │ ...                 │   │
└─────────────────────┘    │   └─────────────────────┘   │
                           │                             │
         ┌─────────────────┼─────────────────────────┐   │
         │                 │                         │   │
    Automatic scoping patterns:                      │   │
                                                    │   │
    SELECT * FROM pwb_props                        │   │
    WHERE website_id = 1 ◄─── Acts as tenant ─────┘   │
                                                       │
    SELECT * FROM pwb_contacts                        │
    WHERE website_id = 1 ◄─── Acts as tenant ─────────┘

Models using this pattern:
├─ PwbTenant::Prop
├─ PwbTenant::Contact
├─ PwbTenant::Message
├─ PwbTenant::FieldKey
├─ PwbTenant::PagePart
└─ ... all PwbTenant:: models
```

## Request Routing Decision Tree

```
                    Request arrives
                          │
                          ▼
                  Does request have
                  X-Website-Slug header?
                    /                    \
                  YES                    NO
                  │                       │
                  ▼                       ▼
          Extract slug from    Extract subdomain from
          header value         request.subdomain
          │                    │
          ▼                    ▼
       Is slug             Is subdomain
       blank?              blank or reserved?
      /      \            /              \
    YES      NO         YES              NO
    │        │          │                │
    │        ▼          │                ▼
    │   Website.       │            Website.find_by_
    │   find_by        │            subdomain(subdom)
    │   (slug: X)      │            (case-insensitive)
    │        │         │                │
    │        ▼         │                ▼
    │      Found?      │             Found?
    │     /    \       │            /      \
    │   YES    NO      │          YES      NO
    │   │      │       │          │        │
    └───┼──────┼───────┘          │        │
        │      │                  │        │
        └──────┴─────────┬────────┘        │
                         │                │
                  Set current_website     │
                         │                │
                         ▼                ▼
                   Website found    Fallback to
                   for this request Website.first
                         │                │
                         └────┬───────────┘
                              │
                              ▼
                    Set Pwb::Current.website
                              │
                              ▼
                    Continue request processing
                    (authentication, controller dispatch)
```

## Authorization Levels

```
┌─────────────────────────────────────────┐
│            REQUEST HIERARCHY             │
└─────────────────────────────────────────┘

LEVEL 1: PUBLIC ROUTES
├─ Path: /properties, /pages, /buy, /rent
├─ Controller: Pwb::*Controller (public)
├─ Auth Required: NO
├─ Tenant Scope: YES (via subdomain)
├─ Access: Anyone
└─ Data: Public website content only

LEVEL 2: SITE ADMIN ROUTES
├─ Path: /site_admin/*
├─ Controller: SiteAdmin::*Controller
├─ Auth Required: YES (Devise + admin for website)
├─ Tenant Scope: YES (via subdomain)
├─ Access: Users with admin/owner role for that website
└─ Data: Single website data only

LEVEL 3: TENANT ADMIN ROUTES
├─ Path: /tenant_admin/*
├─ Controller: TenantAdmin::*Controller
├─ Auth Required: YES (Email in TENANT_ADMIN_EMAILS)
├─ Tenant Scope: NO (cross-tenant by design)
├─ Access: Super administrators (restricted via environment)
└─ Data: ALL website data across all tenants

LEVEL 4: PROTECTED ENGINES
├─ Path: /active_storage_dashboard, /logs
├─ Constraint: TenantAdminConstraint
├─ Auth Required: YES (same as Level 3)
├─ Tenant Scope: NO
├─ Access: Same super-admin email list
└─ Data: System-wide information
```

## Environment Variable Configuration

```
┌───────────────────────────────────────────────────┐
│        ENVIRONMENT CONFIGURATION                  │
├───────────────────────────────────────────────────┤

TENANT_ADMIN_EMAILS=admin@example.com,super@example.com
│
├─ Controls access to:
│  ├─ /tenant_admin/* routes
│  ├─ /active_storage_dashboard
│  ├─ /logs (Logster)
│  └─ Cross-tenant queries
│
├─ Format: Comma-separated email list
├─ Case-insensitive matching
└─ If empty or unset: Nobody has access

BYPASS_ADMIN_AUTH=true (Development only)
│
├─ When set (any value):
│  ├─ SiteAdmin authorization skipped
│  ├─ TenantAdmin authorization skipped
│  └─ Route constraints bypassed
│
├─ Safety: Auto-disabled in production
└─ Use case: E2E testing, local development

EXAMPLE:
TENANT_ADMIN_EMAILS="admin@company.com,devops@company.com"
BYPASS_ADMIN_AUTH=false
```

## Cross-Tenant Data Isolation Example

```
Database state:
┌─────────────────────────────────────┐
│ pwb_websites                        │
├─────────────────────────────────────┤
│ id│ subdomain      │ company_name   │
│ 1 │ myagency       │ My Agency Inc  │
│ 2 │ competitor     │ Comp Agency    │
└─────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ pwb_contacts                               │
├────────────────────────────────────────────┤
│ id│ website_id │ name      │ email         │
│ 1 │ 1          │ Alice     │ alice@...     │
│ 2 │ 1          │ Bob       │ bob@...       │
│ 3 │ 2          │ Charlie   │ charlie@...   │
│ 4 │ 2          │ Diana     │ diana@...     │
└────────────────────────────────────────────┘

Request 1: GET https://myagency.example.com/site_admin/contacts

Routing:
├─ Subdomain: "myagency"
├─ Website lookup: Website.find_by_subdomain("myagency") => Website[id: 1]
├─ Set: Pwb::Current.website = Website[id: 1]
└─ Set: ActsAsTenant.current_tenant = Website[id: 1]

Query:
  PwbTenant::Contact.all
  
SQL:
  SELECT * FROM pwb_contacts WHERE website_id = 1

Result: [Contact[id: 1, name: "Alice"], Contact[id: 2, name: "Bob"]]
         (Charlie and Diana NOT returned - different website)

---

Request 2: GET https://competitor.example.com/site_admin/contacts

Routing:
├─ Subdomain: "competitor"
├─ Website lookup: Website.find_by_subdomain("competitor") => Website[id: 2]
├─ Set: Pwb::Current.website = Website[id: 2]
└─ Set: ActsAsTenant.current_tenant = Website[id: 2]

Query:
  PwbTenant::Contact.all
  
SQL:
  SELECT * FROM pwb_contacts WHERE website_id = 2

Result: [Contact[id: 3, name: "Charlie"], Contact[id: 4, name: "Diana"]]
         (Alice and Bob NOT returned - different website)
```
