# PropertyWebBuilder - Architecture Overview

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     FRONTEND LAYER                              │
│  Vue.js 3 + Quasar (Admin) | Public Website (Theme-based)      │
│                                                                 │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐ │
│  │  Site Admin    │  │ Tenant Admin    │  │  Public Website  │ │
│  │  Dashboard     │  │  Dashboard      │  │  (Customer View) │ │
│  └────────────────┘  └────────────────┘  └──────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP/AJAX
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ROUTING LAYER                                │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Tenant-Based Routing (ActsAsTenant)                    │   │
│  │ ├─ Subdomain routing (tenant1.example.com)            │   │
│  │ ├─ /tenant_admin routes (system admin)                 │   │
│  │ ├─ /site_admin routes (website admin)                 │   │
│  │ └─ Public routes (website visitors)                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  CONTROLLER LAYER                               │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────┐   │
│  │ TenantAdmin      │  │ SiteAdmin        │  │ API v1      │   │
│  │ Controllers      │  │ Controllers      │  │ Controllers │   │
│  │ • Users          │  │ • Props          │  │ • REST      │   │
│  │ • Websites       │  │ • Pages          │  │ • GraphQL   │   │
│  │ • Audit Logs     │  │ • PageParts      │  │ • Public    │   │
│  │ • Agencies       │  │ • Contents       │  │             │   │
│  │                  │  │ • Settings       │  │             │   │
│  └──────────────────┘  └──────────────────┘  └─────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SERVICE LAYER                                 │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────┐   │
│  │ Search Service   │  │ Import Service   │  │ Theme       │   │
│  │ • Property       │  │ • MLS CSV import │  │ Service     │   │
│  │ • Filtering      │  │ • PWB import     │  │ • Render    │   │
│  │ • Ordering       │  │ • Transform data │  │ • Variables │   │
│  │                  │  │                  │  │ • Inherit   │   │
│  └──────────────────┘  └──────────────────┘  └─────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MODEL LAYER                                  │
│                                                                 │
│  Core Models (Pwb namespace - non-scoped)                       │
│  ├─ Pwb::Website                                                │
│  ├─ Pwb::User                                                   │
│  ├─ Pwb::Prop / Pwb::RealtyAsset / Pwb::SaleListing           │
│  ├─ Pwb::Page / Pwb::PagePart / Pwb::PageContent              │
│  ├─ Pwb::Content / Pwb::Contact / Pwb::Message                │
│  ├─ Pwb::Link / Pwb::Agency / Pwb::FieldKey                   │
│  └─ Pwb::AuthAuditLog / Pwb::UserMembership                   │
│                                                                 │
│  Tenant-Scoped Models (PwbTenant namespace)                    │
│  └─ PwbTenant::* (Same models, automatically scoped)          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   DATABASE LAYER                                │
│                                                                 │
│  PostgreSQL with Multi-Tenant Schema                            │
│  ├─ website_id foreign key on all tenant tables               │
│  ├─ Materialized view: pwb_listed_properties                  │
│  ├─ JSONB columns: translations, configurations              │
│  └─ Proper indexing on website_id + other keys              │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow - Property Management Example

```
┌─────────────────┐
│  Admin User     │
│  (Browser)      │
└────────┬────────┘
         │ POST /site_admin/props
         ▼
┌──────────────────────────┐
│ SiteAdminController      │
│ PropsController#create   │
│ • Validate property      │
│ • Check authorization    │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Model Associations           │
│ Pwb::Prop / RealtyAsset      │
│ • Validates attributes       │
│ • Geocodes address           │
│ • Triggers callbacks         │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Database Transaction         │
│ INSERT INTO pwb_props        │
│ (with website_id filtering)  │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Background Jobs (if enabled) │
│ • Generate photos variants   │
│ • Update ListedProperty view │
│ • Send notifications         │
└─────────────────────────────┘
```

## Multi-Tenancy Architecture

### Tenant Isolation Model

```
┌──────────────────────────────────────────────────────────────────┐
│ Multi-Tenant Application (PropertyWebBuilder)                    │
│                                                                   │
│ ┌────────────────┐  ┌────────────────┐  ┌────────────────┐      │
│ │  Tenant 1      │  │  Tenant 2      │  │  Tenant N      │      │
│ │ realtors1.com  │  │ properties.co  │  │  estate.dev    │      │
│ │ (Subdomain)    │  │ (Subdomain)    │  │ (Subdomain)    │      │
│ │                │  │                │  │                │      │
│ │ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │      │
│ │ │ Website    │ │  │ │ Website    │ │  │ │ Website    │ │      │
│ │ │ id: 1      │ │  │ │ id: 2      │ │  │ │ id: N      │ │      │
│ │ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │      │
│ │                │  │                │  │                │      │
│ │ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │      │
│ │ │Properties  │ │  │ │Properties  │ │  │ │Properties  │ │      │
│ │ │website_id:1│ │  │ │website_id:2│ │  │ │website_id:N│ │      │
│ │ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │      │
│ │                │  │                │  │                │      │
│ │ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │      │
│ │ │Users       │ │  │ │Users       │ │  │ │Users       │ │      │
│ │ │Memberships │ │  │ │Memberships │ │  │ │Memberships │ │      │
│ │ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │      │
│ └────────────────┘  └────────────────┘  └────────────────┘      │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
         │                    │                      │
         │ ActsAsTenant       │ ActsAsTenant         │ ActsAsTenant
         │ Auto-scopes        │ Auto-scopes          │ Auto-scopes
         ▼                    ▼                      ▼
    Queries are automatically filtered by website_id
```

### User & Permission Model

```
┌──────────────────────────────────────┐
│ System-Wide User                     │
│ (Pwb::User)                          │
│                                      │
│ • email                              │
│ • password                           │
│ • authentication_provider            │
│ • website (primary, optional)       │
│ • firebase_uid                       │
└──────────────────────────────────────┘
         │
         │ has_many through UserMembership
         ▼
┌──────────────────────────────────────────────────────────┐
│ Multi-Website Access                                     │
│                                                          │
│ ┌──────────────────┐  ┌──────────────────┐              │
│ │ UserMembership   │  │ UserMembership   │  ...        │
│ │                  │  │                  │              │
│ │ user_id: 5       │  │ user_id: 5       │              │
│ │ website_id: 1    │  │ website_id: 2    │              │
│ │ role: 'owner'    │  │ role: 'admin'    │              │
│ │ active: true     │  │ active: true     │              │
│ └──────────────────┘  └──────────────────┘              │
└──────────────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
    Website 1            Website 2
    (Admin)              (Admin)
    Can access all       Can access all
    Website 1 data       Website 2 data
```

## Theme System Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                  Theme Inheritance Hierarchy                      │
│                                                                   │
│                         parent_theme                             │
│                              ▲                                   │
│                              │                                   │
│  ┌────────────────────────────┴──────────────────────────────┐   │
│  │                                                           │   │
│  │ Parent Theme (Default)                                   │   │
│  │ ├─ Layout templates                                      │   │
│  │ ├─ Page parts                                            │   │
│  │ ├─ Base CSS                                              │   │
│  │ └─ Style variables                                       │   │
│  │                                                           │   │
│  │ ┌─────────────────────────────────────────────────────┐ │   │
│  │ │ Child Theme (Brisbane)                              │ │   │
│  │ │ ├─ Layout overrides                                 │ │   │
│  │ ├─ Page part overrides (if needed)                   │ │   │
│  │ ├─ Enhanced CSS                                       │ │   │
│  │ └─ Custom style variables                             │ │   │
│  │                                                       │ │   │
│  │ ┌─────────────────────────────────────────────────┐ │ │   │
│  │ │ Website Instance (tenant customization)        │ │ │   │
│  │ │ ├─ CSS variable overrides (color, fonts)      │ │ │   │
│  │ │ ├─ Custom CSS additions                       │ │ │   │
│  │ │ ├─ Logo/favicon URLs                          │ │ │   │
│  │ │ └─ Layout configuration                       │ │ │   │
│  │ └─────────────────────────────────────────────────┘ │ │   │
│  └─────────────────────────────────────────────────────┘ │   │
│                                                           │   │
└─────────────────────────────────────────────────────────────┘   │
```

### Theme Resolution Flow

```
Request for page
        │
        ▼
Determine current website
        │
        ▼
Get website's theme (e.g., 'brisbane')
        │
        ▼
Load theme configuration from config.json
        │
        ▼
Check theme inheritance chain
│ (brisbane → default → nil)
│
└─ Resolve view paths:
  1. app/themes/brisbane/views/
  2. app/themes/default/views/
  3. app/views/ (fallback)

Use first matching view file
        │
        ▼
Load CSS variables:
1. Theme defaults
2. Parent theme values
3. Website customization
4. User-defined CSS
        │
        ▼
Render page with merged styles
```

## Page Parts System

```
┌──────────────────────────────────────────────────────────────────┐
│                    Page Part Library                              │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Built-in Page Parts (20+)                                   │ │
│  │                                                             │ │
│  │ Heroes          Features        Testimonials               │ │
│  │ • Banner        • Feature list  • Quote cards              │ │
│  │ • Background    • Ordered       • Author info              │ │
│  │ • CTA           • Icons         • Stars rating             │ │
│  │                                                             │ │
│  │ CTA             Stats           Teams                      │ │
│  │ • Buttons       • Numbers       • Member cards             │ │
│  │ • Forms         • Icons         • Bios                     │ │
│  │                 • Descriptions  • Contact info             │ │
│  │                                                             │ │
│  │ Galleries       FAQs            Pricing                    │ │
│  │ • Image grid    • Accordions    • Price tables             │ │
│  │ • Lightbox      • Q&A pairs     • Columns                  │ │
│  │ • Carousel      • Expandable    • Features checklist       │ │
│  │                                                             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Page → Has Many → PageParts                                     │
│                   (associations via page_slug)                   │
│                                                                   │
│  Page Part → Has Configuration:                                 │
│  • page_part_key (unique identifier)                            │
│  • page_slug (which page)                                       │
│  • template (Liquid template)                                   │
│  • block_contents (JSONB data)                                  │
│  • visible_on_page (boolean)                                    │
│  • order_in_editor (sort order)                                 │
│  • theme_name (theme override)                                  │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Search & Filtering Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                   Search Request Flow                             │
│                                                                   │
│  User clicks "Search" on /buy or /rent                           │
│         │                                                         │
│         ▼                                                         │
│  ┌─────────────────────────────────────┐                         │
│  │ JavaScript Search Handler           │                         │
│  │ • Collects filter parameters        │                         │
│  │ • Sends AJAX request                │                         │
│  └────────┬────────────────────────────┘                         │
│           │ POST /search_ajax_for_sale                           │
│           ▼                                                       │
│  ┌─────────────────────────────────────┐                         │
│  │ SearchController                    │                         │
│  │ • Validates filters                 │                         │
│  │ • Calls apply_search_filter         │                         │
│  │ • Sets map markers                  │                         │
│  │ • Renders results                   │                         │
│  └────────┬────────────────────────────┘                         │
│           │                                                       │
│           ▼                                                       │
│  ┌─────────────────────────────────────┐                         │
│  │ Search Filters Applied              │                         │
│  │                                     │                         │
│  │ Base Query:                         │                         │
│  │ ListedProperty.visible.for_sale    │                         │
│  │                                     │                         │
│  │ Applied Filters:                    │                         │
│  │ • property_type                     │                         │
│  │ • property_state                    │                         │
│  │ • price_from / price_to            │                         │
│  │ • bedrooms_from / bathrooms_from   │                         │
│  │ • city / region                     │                         │
│  │ • furnished status                  │                         │
│  │ • highlighted_only                  │                         │
│  │                                     │                         │
│  └────────┬────────────────────────────┘                         │
│           │                                                       │
│           ▼                                                       │
│  ┌─────────────────────────────────────┐                         │
│  │ ListedProperty View Query           │                         │
│  │ (Optimized for search performance)  │                         │
│  │                                     │                         │
│  │ Returns:                            │                         │
│  │ • Property ID                       │                         │
│  │ • Price (sale/rental)               │                         │
│  │ • Location                          │                         │
│  │ • Bedrooms/bathrooms                │                         │
│  │ • Featured status                   │                         │
│  │ • Thumbnail photo                   │                         │
│  │ • Lat/Long (for map)                │                         │
│  │                                     │                         │
│  └────────┬────────────────────────────┘                         │
│           │                                                       │
│           ▼                                                       │
│  ┌─────────────────────────────────────┐                         │
│  │ Client-Side Result Rendering        │                         │
│  │ • Inject into template              │                         │
│  │ • Display list                      │                         │
│  │ • Display map markers               │                         │
│  │ • Enable client-side sorting        │                         │
│  │ • Show result count                 │                         │
│  │                                     │                         │
│  └─────────────────────────────────────┘                         │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Authentication & Authorization Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                  Authentication Methods                           │
│                                                                   │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐     │
│  │ Email/Password │  │ Firebase Auth  │  │ OAuth (Social) │     │
│  │ (Devise)       │  │                │  │                │     │
│  │ • Local DB     │  │ • Firebase API │  │ • Facebook     │     │
│  │ • Salt/Hash    │  │ • UID stored   │  │ • OmniAuth gem │     │
│  │ • Lockable     │  │ • Token-based  │  │ • Extensible   │     │
│  │ • Recoverable  │  │ • 2FA support  │  │                │     │
│  └────────────────┘  └────────────────┘  └────────────────┘     │
│           │                   │                    │             │
└───────────┴───────────────────┴────────────────────┘             │
            │                                                       │
            ▼                                                       │
┌──────────────────────────────────────────────────────────────────┐
│               Unified Auth Session Management                     │
│                                                                   │
│  • Devise session created                                        │
│  • Firebase token validated (if applicable)                      │
│  • Auth audit log entry created                                  │
│  • User context set (current_user)                              │
│  • Website context set (current_website)                         │
│  • Tenant context set (ActsAsTenant)                            │
│                                                                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                 Authorization Checks                              │
│                                                                   │
│  Check user access to resource:                                  │
│                                                                   │
│  • Is user authenticated? (unless public)                        │
│  • Does user belong to current website? (via UserMembership)    │
│  • Does user have correct role? (owner/admin/member)            │
│  • Is website_id matching? (multi-tenant isolation)             │
│                                                                   │
│  Note: Full role-based authorization in development             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

Auth Audit Trail:
┌──────────────────────────────────────────────────────────────────┐
│ Every auth event logged to pwb_auth_audit_logs table             │
│ • Event type (login, logout, registration, failed_login, etc.)   │
│ • User ID + email                                                │
│ • IP address                                                     │
│ • User agent                                                     │
│ • Request path                                                   │
│ • Timestamp                                                      │
│ • Success/failure with reason                                    │
│ • Website ID (for audit trail separation)                        │
│                                                                   │
│ Queryable by: user, IP, event type, date range, website         │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## API Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                   API Endpoints Structure                         │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ Public API (/api_public/v1)                                │  │
│  │ ├─ GET /properties/:id                                     │  │
│  │ ├─ GET /properties (search)                                │  │
│  │ ├─ GET /pages/:id                                          │  │
│  │ ├─ GET /pages/by_slug/:slug                                │  │
│  │ ├─ GET /translations                                       │  │
│  │ ├─ GET /links                                              │  │
│  │ ├─ GET /site_details                                       │  │
│  │ └─ POST /auth/firebase                                     │  │
│  │                                                            │  │
│  │ Authentication: Optional (BYPASS_API_AUTH env var)        │  │
│  │ Usage: Public website data access                         │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ Internal API (/api/v1) - Requires Authentication           │  │
│  │ ├─ CRUD /properties, /agencies, /contacts, /pages         │  │
│  │ ├─ Photo management                                        │  │
│  │ ├─ Translation management                                  │  │
│  │ ├─ Settings management                                     │  │
│  │ ├─ Bulk operations                                         │  │
│  │ └─ MLS import                                              │  │
│  │                                                            │  │
│  │ Authentication: User authentication required              │  │
│  │ Authorization: Admin/membership checks (partial)          │  │
│  │ Usage: Admin panel API calls                              │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ GraphQL API (/graphql)                                     │  │
│  │ ├─ Queries: properties, pages, agencies, contacts         │  │
│  │ ├─ Mutations: submit_listing_enquiry, etc.               │  │
│  │ ├─ Introspection available                                │  │
│  │ └─ GraphiQL IDE (development only)                        │  │
│  │                                                            │  │
│  │ Authentication: Optional                                  │  │
│  │ Usage: Modern API clients                                 │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Database Schema Highlights

### Multi-Tenancy Keys
```sql
-- Every tenant table has website_id foreign key
ALTER TABLE pwb_props ADD COLUMN website_id INTEGER;
ALTER TABLE pwb_pages ADD COLUMN website_id INTEGER;
ALTER TABLE pwb_contents ADD COLUMN website_id INTEGER;
-- ... etc for all tenant models

-- Composite unique indexes with website_id
CREATE UNIQUE INDEX index_pages_on_slug_and_website_id 
  ON pwb_pages(slug, website_id);
```

### JSONB Columns for Flexibility
```sql
-- Translations stored in JSONB
ALTER TABLE pwb_props ADD COLUMN translations JSONB DEFAULT '{}';
-- { "en-UK": { "title": "..." }, "es": { "title": "..." } }

-- Configuration stored in JSONB
ALTER TABLE pwb_websites ADD COLUMN configuration JSON;
ALTER TABLE pwb_websites ADD COLUMN style_variables_for_theme JSON;

-- Page parts store content as JSONB
ALTER TABLE pwb_page_parts ADD COLUMN block_contents JSON;

-- Metadata storage
ALTER TABLE pwb_contacts ADD COLUMN details JSON;
```

### Materialized View for Performance
```sql
-- ListedProperty: Denormalized view for search optimization
CREATE MATERIALIZED VIEW pwb_listed_properties AS
SELECT 
  p.id, p.title, p.reference,
  p.price_sale_current_cents, p.price_rental_monthly_current_cents,
  p.city, p.latitude, p.longitude,
  p.count_bedrooms, p.count_bathrooms,
  p.visible, p.highlighted, p.for_sale, p.for_rent_long_term,
  p.website_id
FROM pwb_props p
WHERE p.visible = true;

CREATE INDEX index_listed_properties_on_website_id 
  ON pwb_listed_properties(website_id);
```

## Deployment Architecture

```
┌──────────────────────────────────────────────────────────┐
│           Deployment Platform Options                    │
├──────────────────────────────────────────────────────────┤
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ Container-Based Deployments                          │ │
│ │ • Docker image (Rails standard)                      │ │
│ │ • Supported: Render, Koyeb, Northflank, Dokku       │ │
│ │ • Database: PostgreSQL (managed or custom)           │ │
│ │ • Storage: S3, Local, or R2                          │ │
│ │ • Background Jobs: Sidekiq (optional)                │ │
│ │ • Redis: For caching and jobs                        │ │
│ │                                                      │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ Platform-Specific Deployments                        │ │
│ │ • Heroku: Procfile-based (paid tier)                │ │
│ │ • Cloud66: DevOps automation                         │ │
│ │ • AlwaysData: Hosting provider                       │ │
│ │ • DomCloud: Cloud hosting                            │ │
│ │ • Coherence: Full-stack platform                     │ │
│ │ • Argonaut: Deployment automation                    │ │
│ │                                                      │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
└──────────────────────────────────────────────────────────┘

Required Infrastructure:
• Web Application Server (Puma)
• Database (PostgreSQL 12+)
• Storage (S3/R2 or local)
• Email Service (SendGrid, Mailgun, etc.)
• Redis (for caching and background jobs)
• Optional: CDN (for assets)
```

## Security Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    Security Layers                               │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Network & Transport                                      │   │
│  │ • HTTPS/TLS required in production                       │   │
│  │ • CSRF token protection (Rails default)                  │   │
│  │ • Content Security Policy (recommended)                  │   │
│  │ • CORS configuration for API                             │   │
│  │                                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Application Layer                                        │   │
│  │ • Parameterized SQL queries (Rails ORM)                 │   │
│  │ • Input validation on models                             │   │
│  │ • Password hashing (bcrypt via Devise)                  │   │
│  │ • Encrypted password storage                             │   │
│  │ • Account lockout after failed attempts                  │   │
│  │ • Session timeout support                                │   │
│  │ • Multi-tenant isolation (ActsAsTenant)                  │   │
│  │ • User membership-based authorization                    │   │
│  │ • Recaptcha protection on forms                          │   │
│  │                                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Audit & Monitoring                                       │   │
│  │ • Auth audit logs (all events tracked)                   │   │
│  │ • IP-based tracking and analysis                         │   │
│  │ • User agent logging                                     │   │
│  │ • Request path logging                                   │   │
│  │ • Failure reason tracking                                │   │
│  │ • Per-website audit trail separation                     │   │
│  │ • Logster integration for errors                         │   │
│  │ • Query performance monitoring (possible)                │   │
│  │                                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Summary

PropertyWebBuilder's architecture is built on modern Rails principles with:

1. **Clean separation of concerns**: Controllers, Services, Models
2. **Multi-tenancy first**: ActsAsTenant integration throughout
3. **Flexible data model**: JSONB for translations and configs
4. **Performance optimized**: Materialized views for search
5. **Scalable API**: Both REST and GraphQL
6. **Extensible theme system**: Inheritance and composition
7. **Strong security**: Audit logging, authentication, CSRF protection
8. **Multiple deployment options**: Works on any Rails-compatible platform
