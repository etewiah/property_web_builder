# PropertyWebBuilder Admin Architecture

## High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Rails Admin System                       │
│  PropertyWebBuilder v2 - Multi-Tenant Real Estate Platform      │
└─────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│                       Admin Controllers Layer                      │
├─────────────────────────────────┬────────────────────────────────┤
│                                 │                                │
│  SiteAdmin Namespace            │   TenantAdmin Namespace       │
│  (Per-Website Admin)            │   (Platform Admin)            │
├─────────────────────────────────┼────────────────────────────────┤
│ • DashboardController          │ • DashboardController          │
│ • PropsController              │ • SubscriptionsController      │
│ • MessagesController           │ • PlansController              │
│ • InboxController              │ • WebsitesController           │
│ • PagesController              │ • UsersController              │
│ • MediaLibraryController       │                                │
│ • OnboardingController         │                                │
│ • BillingController            │                                │
│ • AgencyController             │                                │
│ • DomainController             │                                │
│ • AnalyticsController          │                                │
└─────────────────────────────────┴────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│                     Models & Business Logic                      │
├──────────────┬──────────────────┬──────────────┬────────────────┤
│              │                  │              │                │
│ Tenant/      │ Subscription &   │ Content      │ File Storage   │
│ Website      │ Billing          │ Management   │                │
├──────────────┼──────────────────┼──────────────┼────────────────┤
│ • Website    │ • Plan           │ • Page       │ • Media        │
│ • Agency     │ • Subscription   │ • PagePart   │ • MediaFolder  │
│ • User       │ • SubEvent       │ • Content    │ • PropPhoto    │
│              │                  │ • Link       │ • ActiveStore  │
└──────────────┴──────────────────┴──────────────┴────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│            Property Management Domain Models                     │
├──────────────────┬──────────────────┬──────────────────┬────────┤
│                  │                  │                  │        │
│ Physical Props   │ Listings         │ Feature/Labels   │ Search │
├──────────────────┼──────────────────┼──────────────────┼────────┤
│ • RealtyAsset    │ • SaleListing    │ • Feature        │        │
│                  │ • RentalListing  │ • FieldKey       │        │
│                  │ • PropPhoto      │                  │        │
└──────────────────┴──────────────────┴──────────────────┴────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│              Messaging & Contact Domain                         │
├──────────────────────────────────────────────────────────────────┤
│ • Message (inquiries, form submissions)                         │
│ • Contact (prospects, leads, clients)                           │
│ • Address (associated with contacts)                            │
│ • AuthAuditLog (interaction audit trail)                        │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│                     Database Layer                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PostgreSQL 13+ with Multi-Tenant Scoping                       │
│                                                                  │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ Properties  │  │ Subscriptions │  │ Content      │           │
│  ├─────────────┤  ├──────────────┤  ├──────────────┤           │
│  │ realty_     │  │ pwb_plans    │  │ pwb_pages   │           │
│  │ assets      │  │              │  │              │           │
│  │ (UUID PK)   │  │ pwb_         │  │ pwb_        │           │
│  │             │  │ subscriptions│  │ contents    │           │
│  │ sale_       │  │              │  │              │           │
│  │ listings    │  │ pwb_         │  │ pwb_        │           │
│  │             │  │ subscription_│  │ page_parts  │           │
│  │ rental_     │  │ events       │  │              │           │
│  │ listings    │  │              │  │              │           │
│  │             │  │              │  │              │           │
│  │ prop_       │  │              │  │              │           │
│  │ photos      │  │              │  │              │           │
│  │             │  │              │  │              │           │
│  └─────────────┘  └──────────────┘  └──────────────┘           │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Messaging    │  │ Media Lib    │  │ Tenants      │          │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤          │
│  │ pwb_        │  │ pwb_media   │  │ pwb_        │          │
│  │ messages    │  │              │  │ websites    │          │
│  │             │  │ pwb_media_   │  │              │          │
│  │ pwb_        │  │ folders      │  │ pwb_        │          │
│  │ contacts    │  │              │  │ agencies    │          │
│  │             │  │              │  │              │          │
│  │ pwb_        │  │              │  │ pwb_users   │          │
│  │ addresses   │  │              │  │              │          │
│  │             │  │              │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  All tables scoped by: website_id (foreign key)                 │
│  Materialized Views: pwb_properties (for search optimization)   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                            ↑
┌──────────────────────────────────────────────────────────────────┐
│              Data Access & Query Layer                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Tenant-Scoped Query Classes (PwbTenant namespace)               │
│ • Pwb::ListedProperty (materialized view reads)                 │
│ • Pwb::CurrentWebsite (context helper)                          │
│ • Pwb::Current (thread-safe tenant context)                     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                            ↑
┌──────────────────────────────────────────────────────────────────┐
│                     View/Template Layer                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  app/views/site_admin/                                          │
│  ├── dashboard/                   (1 view)                      │
│  ├── props/                        (9 templates)                │
│  ├── messages/                     (show template)              │
│  ├── inbox/                        (contact list + conversation)│
│  ├── pages/                        (list, edit, settings)       │
│  ├── media_library/                (gallery, metadata edit)     │
│  ├── onboarding/                   (5 step wizard)              │
│  └── [others]/                     (billing, settings, etc)     │
│                                                                  │
│  • ERB templates (server-rendered)                              │
│  • Tailwind CSS (all styling)                                   │
│  • Stimulus.js (drag-drop, forms, modals)                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: Example - Create Property

```
Admin User
    ↓
GET /site_admin/props/new
    ↓
SiteAdminController#new
    ├── Create empty RealtyAsset
    ├── Set current_website
    └── Render edit_general view
    ↓
User fills form (reference, type, rooms)
    ↓
POST /site_admin/props
    ↓
SiteAdminController#create
    ├── new_prop_params (whitelist)
    ├── RealtyAsset.new(params)
    ├── @prop.website = current_website  [TENANT SCOPING]
    ├── @prop.save
    │   ├── Validate within_subscription_property_limit
    │   └── Geocode address
    ├── Trigger: RefreshesPropertiesView
    │   └── Schedule async refresh of pwb_properties view
    └── Redirect to edit_general
    ↓
RefreshPropertiesViewJob (async)
    └── REFRESH MATERIALIZED VIEW pwb_properties
        [Updates ListedProperty query results]
    ↓
View Updated
    ├── ListedProperty count increases
    ├── Dashboard stats update
    └── Property list refresh
```

---

## Data Flow: Example - Property Search

```
Admin Views /site_admin/props?search=apartment
    ↓
GET /site_admin/props?search=apartment
    ↓
PropsController#index
    ├── ListedProperty.with_eager_loading  [Read optimization]
    ├── where(website_id: current_website.id)  [TENANT ISOLATION]
    ├── where('reference ILIKE ? OR title ILIKE ...')
    ├── order(created_at: :desc)
    ├── pagy(..., limit: 25)  [Pagination]
    └── Render index.html.erb
    ↓
Database Query (materialzed view)
    SELECT * FROM pwb_properties
    WHERE website_id = 123
      AND (reference ILIKE '%apartment%' OR ...)
    ORDER BY created_at DESC
    LIMIT 25 OFFSET 0
    ↓
Results returned
    ├── 25 properties with metadata
    ├── Pagination info
    └── Display in gallery/list view
```

---

## Multi-Tenancy Isolation Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                    Single Database                          │
│              (All websites coexist)                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Website 1 (website_id=1)                  │
├──────────────────┬──────────────────┬──────────────────────┤
│ Admin User: Alice│ Properties: 25   │ Messages: 42         │
│ Subscription:    │ Pages: 8         │ Contacts: 18         │
│ Pro Plan         │ Media: 500 files │ Storage: 50GB        │
└──────────────────┴──────────────────┴──────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Website 2 (website_id=2)                  │
├──────────────────┬──────────────────┬──────────────────────┤
│ Admin User: Bob  │ Properties: 12   │ Messages: 8          │
│ Subscription:    │ Pages: 5         │ Contacts: 4          │
│ Starter Plan     │ Media: 100 files │ Storage: 5GB         │
└──────────────────┴──────────────────┴──────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Website 3 (website_id=3)                  │
├──────────────────┬──────────────────┬──────────────────────┤
│ Admin User: Carol│ Properties: 50   │ Messages: 200        │
│ Subscription:    │ Pages: 20        │ Contacts: 85         │
│ Enterprise Plan  │ Media: 2000 files│ Storage: 200GB       │
└──────────────────┴──────────────────┴──────────────────────┘

Isolation Mechanism:
├── Query Level: WHERE website_id = current_website.id
├── Association Level: belongs_to :website
├── Controller Level: current_website context
└── Security: Authenticated user associated with website(s)
```

---

## Subscription State Machine

```
┌─────────────────────────────────────────────────────────────┐
│         Subscription Lifecycle (AASM States)                │
└─────────────────────────────────────────────────────────────┘

                       ┌─────────────┐
                       │   trialing  │  ← Initial state
                       │ (Day 1-14)  │
                       └──────┬──────┘
                              │
                    ┌─────────┴──────────┐
                    │                    │
             Payment received      No payment
                    │                    │
                    ▼                    ▼
            ┌──────────────┐      ┌────────────┐
            │   active     │      │  expired   │
            │ (Good status)│      │ (Trial end)│
            └──────┬───────┘      └────────────┘
                   │
         ┌─────────┴────────────┐
         │                      │
    User pays          Payment fails
         │                      │
         │                      ▼
         │             ┌──────────────┐
         │             │  past_due    │
         │             │(Grace period)│
         │             └──────┬───────┘
         │                    │
         │         ┌──────────┴──────────┐
         │         │                     │
    (no action) Payment succeeded    Keeps failing
         │         │                     │
         │         ▼                     ▼
         │      [active]           [expired]
         │
    User cancels
         │
         ▼
    ┌──────────┐
    │ canceled │
    │ (at end) │
    └────┬─────┘
         │
    Period ends
         │
         ▼
    ┌──────────┐
    │ expired  │
    └──────────┘

Key Fields Tracked:
├── status: (enum) Current state
├── trial_ends_at: DateTime
├── current_period_ends_at: DateTime
├── canceled_at: DateTime
├── cancel_at_period_end: Boolean
└── metadata: JSONB (audit trail stored in pwb_subscription_events)
```

---

## Property Model Normalization

```
Normalized Structure:

┌─────────────────────────┐
│    RealtyAsset          │  (The physical property)
│  (UUID primary key)     │
├─────────────────────────┤
│ • reference             │
│ • street_address        │
│ • count_bedrooms        │
│ • constructed_area      │
│ • year_construction     │
│ • prop_type_key         │
│ • slug                  │
│ • created_at            │
└────────┬────────────────┘
         │
    ┌────┴────┬──────────────┐
    │          │              │
    ▼          ▼              ▼
┌──────────────────┐ ┌──────────────────┐
│  SaleListing     │ │ RentalListing    │
│ (UUID PK)        │ │ (UUID PK)        │
├──────────────────┤ ├──────────────────┤
│ • visible        │ │ • visible        │
│ • active         │ │ • active         │
│ • price_cents    │ │ • price_monthly  │
│ • translations   │ │ • for_rent_short │
│ • furnished      │ │ • for_rent_long  │
│ • highlighted    │ │ • translations   │
└──────────────────┘ └──────────────────┘
         │                    │
         └────────┬───────────┘
                  │
                  ▼
         ┌────────────────────┐
         │  ListedProperty    │
         │  (Materialized View)
         │ [Read Optimization]│
         ├────────────────────┤
         │ Denormalized:      │
         │ • for_sale: bool   │
         │ • for_rent: bool   │
         │ • Both prices      │
         │ • All asset fields │
         │ • Visible status   │
         └────────────────────┘

Why This Pattern?

Writes:  Use RealtyAsset/Listings (normalized)
         ├── Reduces duplication
         ├── Atomic transactions
         └── Maintains data integrity

Reads:   Use ListedProperty (denormalized view)
         ├── Single query (no joins)
         ├── Indexed for search
         └── Better performance
```

---

## Email/Notification Flow (Messages)

```
Website Visitor
    ↓
Submits contact form
    ↓
Pwb::Message.create
    ├── origin_email: visitor@example.com
    ├── content: Message text
    ├── url: Source page
    ├── website_id: Scoped to website
    ├── contact_id: Auto-match or nil (orphan)
    └── read: false
    ↓
InboxController
    ├── Groups by contact
    ├── Counts unread
    └── Displays in CRM view
    ↓
Admin Views Message
    ├── Mark as read
    ├── Log audit entry
    └── (No reply/draft features yet)
```

---

## Feature Gating Example

```
Admin Creates 26th Property
    ↓
PropsController#create
    ├── RealtyAsset.validate
    │   ├── Get subscription: Pwb::Subscription.find_by(website_id)
    │   ├── Get plan limit: subscription.plan.property_limit
    │   ├── Count current: website.realty_assets.count
    │   └── Check: count < limit or unlimited?
    │
    └── If over limit:
        ├── Add error: "You have reached your property limit"
        ├── Suggest upgrade
        └── Render with status 422
    ↓
Dashboard Show:
    ├── remaining_properties: subscription.remaining_properties
    │   = property_limit - current_count
    └── Display in warning banner
```

---

## Admin Context & Current Website

```
Request Flow:

Admin User logs in
    ↓
Authentication sets: current_user
    ↓
SiteAdminController before_action
    ├── Find website from session/subdomain
    ├── Verify user has access
    └── Set: Pwb::Current.website = website
    ↓
All Models/Views/Helpers
    ├── Access current_website
    ├── Scope queries automatically
    └── Assume single tenant context
    ↓
Response rendered with correct data
```

---

## Performance Optimization Points

```
┌──────────────────────────────────────────────────────┐
│     Performance Considerations & Optimizations       │
└──────────────────────────────────────────────────────┘

1. LIST VIEWS (Property, Pages, Media)
   ├── Pagination: 25-100 items per page (avoid huge queries)
   ├── Search indexing: ILIKE on frequently searched columns
   ├── Eager loading: with_eager_loading to avoid N+1
   └── Scoping: website_id index for fast filtering

2. MATERIALIZED VIEW (ListedProperty)
   ├── Async refresh: After property/listing writes
   ├── Pre-computed columns: Denormalized for fast reads
   ├── Indexed for search: Multiple search indexes
   └── Avoids costly JOINs at query time

3. CONTACTS & MESSAGES
   ├── Aggregation query: GROUP BY with COUNT/SUM
   ├── Indexes on (website_id, created_at)
   └── Pagination: Limit 100 contacts in inbox

4. MEDIA LIBRARY
   ├── Pagination: 24 items per gallery page
   ├── File metadata caching: width, height pre-computed
   ├── Tag search: GIN index on JSONB array
   └── Folder hierarchy: Efficient tree traversal

5. POTENTIAL BOTTLENECKS
   ├── Large media uploads: No async processing visible
   ├── Unscoped queries: TenantAdmin dashboard
   ├── Complex aggregations: Contact + Message joins
   └── View refresh timing: If many properties updated
```

---

## API Surface for Admin

```
REST Routes (Standard Rails Conventions):

Sites Admin Routes:
/site_admin/props
  GET    index (list properties)
  POST   create (new property)
  
/site_admin/props/:id
  GET    show (view property)
  POST   update (save changes)

/site_admin/props/:id/edit_general
  GET    edit_general (form)
  POST   update (with asset_params)

/site_admin/props/:id/edit_photos
  GET    edit_photos (form)
  POST   upload_photos (with photo files)

/site_admin/messages/:id
  GET    show (view message)
  POST   update (mark as read, audit log)

/site_admin/inbox
  GET    index (contact list with search)

/site_admin/inbox/:id
  GET    show (conversation thread)

/site_admin/pages
  GET    index
  POST   create

/site_admin/pages/:id/reorder_parts
  POST   reorder_parts (drag-drop save)

/site_admin/media_library
  GET    index (gallery view, HTML or JSON)
  POST   create (bulk upload)

/site_admin/media_library/:id
  PATCH  update (metadata)
  DELETE destroy

/site_admin/media_library/bulk_destroy
  DELETE bulk_destroy (multiple files)

/site_admin/media_library/bulk_move
  POST   bulk_move (to folder)

Response Formats:
├── HTML: Full page renders
├── JSON: For AJAX/SPA (media library)
└── Redirects: Most form submissions
```

---

## Security Architecture

```
┌────────────────────────────────────────────────────────┐
│              Admin Security Layers                      │
└────────────────────────────────────────────────────────┘

Layer 1: Authentication
├── User must be logged in
├── Current_user set by Devise (assumed)
└── Session/token verified

Layer 2: Authorization
├── require_admin! before_action
├── Must be admin user for website
└── Skipped for onboarding flow

Layer 3: Tenant Isolation
├── website_id scoping in queries
├── current_website context set
└── No cross-website data access

Layer 4: CSRF Protection
├── Rails UJS CSRF token
├── Form token validation
└── State-changing requests via POST/PATCH/DELETE

Layer 5: Audit Logging
├── AuthAuditLog for sensitive actions
├── Message reads logged
└── User association with changes

Layer 6: Data Validation
├── Model validations (presence, uniqueness, etc)
├── Strong parameters (permit whitelist)
└── Business rule validation (subscription limits)
```

---

## Conclusion

The PropertyWebBuilder admin architecture provides:

✅ **Scalable multi-tenancy** - Proven isolation pattern with website_id scoping
✅ **Performance optimization** - Materialized views, eager loading, pagination
✅ **Flexible feature gating** - Plan-based access control
✅ **Extensible models** - Concerns, callbacks, state machines
✅ **Clean separation of concerns** - Controllers, models, views clearly divided
✅ **Standard Rails patterns** - Familiar conventions for Rails developers

