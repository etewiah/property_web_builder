# Multi-Tenancy Architecture Diagram

## Request Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            INCOMING REQUEST                                 │
│                    https://site1.example.com/admin/pages                    │
└────────────────────────────────────┬────────────────────────────────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │   Extract Subdomain (Rails)    │
                    │  request.subdomain = "site1"   │
                    └────────────────────┬───────────┘
                                         │
                                         ▼
                         ┌───────────────────────────────┐
                         │   SubdomainTenant Concern     │
                         │ (included in SiteAdminCtrl)   │
                         └───────────┬───────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
                    ▼                                 ▼
        ┌─────────────────────┐         ┌──────────────────────┐
        │ Check X-Website-    │         │  Find Website by     │
        │ Slug header (API)   │         │  Subdomain           │
        │                     │         │                      │
        │ Pwb::Website.find_  │         │ Pwb::Website.find_by │
        │ by(slug: header)    │         │ _subdomain('site1')  │
        └─────────────────────┘         └──────────────┬───────┘
                    │                                   │
                    └───────────────┬───────────────────┘
                                    │
                                    ▼
                     ┌──────────────────────────────┐
                     │  Set Pwb::Current.website    │
                     │  (Thread-local storage)      │
                     │                              │
                     │  Pwb::Current.website = <    │
                     │    Pwb::Website#site1 >      │
                     └────────────┬─────────────────┘
                                  │
                                  ▼
                     ┌──────────────────────────────┐
                     │  Controller Action Executes  │
                     │                              │
                     │  @pages = Pwb::Page.where(   │
                     │    website_id:               │
                     │    current_website.id        │
                     │  )                           │
                     └────────────┬─────────────────┘
                                  │
                                  ▼
                     ┌──────────────────────────────┐
                     │  Query Database              │
                     │                              │
                     │  SELECT * FROM pwb_pages     │
                     │  WHERE website_id = 1        │
                     │  (Only site1's pages!)       │
                     └────────────┬─────────────────┘
                                  │
                                  ▼
                     ┌──────────────────────────────┐
                     │  Clear Pwb::Current          │
                     │  (Between requests)          │
                     └──────────────────────────────┘
```

---

## Data Model Relationships

```
┌─────────────────────────────────────────────────────────────────────┐
│                          MULTI-TENANT SETUP                         │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────┐
│      Pwb::Website            │ ◄─── THE TENANT (ROOT)
│      (Tenant)                │
├──────────────────────────────┤
│ id                           │
│ slug (unique)                │
│ subdomain (unique)           │
│ company_display_name         │
│ theme_name                   │
└──────────────────┬───────────┘
                   │
    ┌──────────────┼──────────────┬────────────────┬──────────────┐
    │              │              │                │              │
    ▼              ▼              ▼                ▼              ▼
┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐  ┌────────────┐
│  Page   │  │ Content  │  │ Message  │  │ ListedProp  │  │  Agency    │
│         │  │          │  │          │  │   erty      │  │            │
├─────────┤  ├──────────┤  ├──────────┤  ├─────────────┤  ├────────────┤
│ id      │  │ id       │  │ id       │  │ id          │  │ id         │
│ website │  │ website  │  │ website  │  │ website_id  │  │ website_id │
│ _id     │  │ _id      │  │ _id      │  │ (mat view)  │  │            │
│ slug    │  │ key      │  │ origin   │  │             │  │            │
│         │  │          │  │ _email   │  │             │  │            │
└────┬────┘  └────┬─────┘  └────┬─────┘  └─────────────┘  └────────────┘
     │            │             │
     └────┬───────┴─────────────┘
          │
          ▼
   Scoped by website_id!
   (Must filter in queries)


┌──────────────────────────────────────────────────────────────────┐
│                   SPECIAL MODELS (NOT DIRECTLY SCOPED)           │
└──────────────────────────────────────────────────────────────────┘

┌──────────────┐         ┌───────────────────────┐
│  Pwb::User   │─────────│ Pwb::UserMembership   │
│              │         │                       │
├──────────────┤         ├───────────────────────┤
│ id           │         │ id                    │
│ email        │         │ user_id (FK)          │
│ website_id   │         │ website_id (FK)       │
│  (optional)  │         │ role (owner/admin)    │
│              │         │ active (boolean)      │
└──────────────┘         └───────────────────────┘
      │
      │ Can access multiple websites
      │ through UserMembership
      │
      ▼
   Admin can manage users
   across all websites
```

---

## Tenant Resolution Flow (Detailed)

```
REQUEST ARRIVES
    │
    ▼
┌─────────────────────────────────────────┐
│ SubdomainTenant Concern                 │
│ before_action :set_current_website_     │
│ _from_subdomain                         │
└──────────┬──────────────────────────────┘
           │
           ├─ 1. Check X-Website-Slug header (API clients)
           │   ├─ If present: find Website by slug
           │   └─ If found: Pwb::Current.website = website
           │
           ├─ 2. Extract request.subdomain
           │   ├─ Return nil if blank
           │   ├─ Ignore "www", "api", "admin" subdomains
           │   └─ Take first part of multi-level subdomains
           │
           ├─ 3. Find Website by subdomain
           │   └─ WHERE LOWER(subdomain) = LOWER(request_subdomain)
           │
           ├─ 4. Fallback to first website (if not found)
           │   └─ Website.first
           │
           ▼
┌─────────────────────────────────────────┐
│ Pwb::Current.website = <Website>        │
│ (Now available throughout request)      │
└─────────────────────────────────────────┘
```

---

## Controller Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                    ActionController::Base                       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
                ▼                         ▼
    ┌───────────────────────┐  ┌──────────────────────┐
    │ ApplicationController │  │  AdminPanelCtrl      │
    │ (Public site)         │  │  (Legacy admin)      │
    ├───────────────────────┤  ├──────────────────────┤
    │ • Manual subdomain    │  │ • Manual subdomain   │
    │   resolution          │  │   resolution         │
    │ • Fallback to first   │  │ • Manual auth checks │
    │   website             │  │ • Unscoped queries   │
    │ • current_website     │  └──────────┬───────────┘
    │   from helper         │             │
    └─────────┬─────────────┘             │
              │                           │
              ▼                           ▼
    ┌──────────────────────────────────────────┐
    │       PublicControllers                  │
    │  (Pages, Props, Search, Contact Us)      │
    │                                          │
    │  • Inherits from ApplicationController   │
    │  • Uses current_website automatically    │
    │  • Renders public website pages          │
    └──────────────────────────────────────────┘


                ┌──────────────────────────────┐
                │ SiteAdminController          │
                │ (Single-tenant admin)        │
                ├──────────────────────────────┤
                │ • INCLUDES SubdomainTenant   │
                │   concern (automatic!)       │
                │ • Requires authentication    │
                │ • Requires admin role        │
                │ • Scopes queries by website  │
                │ • current_website from       │
                │   Pwb::Current.website       │
                └──────────┬───────────────────┘
                           │
                           ▼
            ┌─────────────────────────────┐
            │   SiteAdmin::* Controllers  │
            │                             │
            │  • MessagesController       │
            │  • ContentsController       │
            │  • PagesController          │
            │  • PropsController          │
            │  • LinksController          │
            │  etc.                       │
            │                             │
            │  All inherit SiteAdmin      │
            │  tenancy + authorization    │
            └─────────────────────────────┘


                ┌──────────────────────────────┐
                │ TenantAdminController        │
                │ (Multi-tenant admin)         │
                ├──────────────────────────────┤
                │ • NO SubdomainTenant concern │
                │ • Deliberately uses .unscoped│
                │ • Manages all websites       │
                │ • Admin-only access          │
                │ • Explicit website selection │
                └──────────┬───────────────────┘
                           │
                           ▼
            ┌─────────────────────────────┐
            │  TenantAdmin::* Controllers │
            │                             │
            │  • WebsitesController       │
            │  • UsersController          │
            │  • PagesController (all)    │
            │  • ContentController (all)  │
            │  etc.                       │
            │                             │
            │  Use .unscoped() to see all │
            │  websites and their data    │
            └─────────────────────────────┘
```

---

## Query Scoping Pattern

```
SCOPED CORRECTLY                 vs           SCOPED INCORRECTLY
════════════════════════════════════════════════════════════════════

Pwb::Page.where(                             Pwb::Page.all
  website_id: current_website.id
)                                            Pwb::Page.find(params[:id])

     │                                            │
     │ Database sees:                             │ Database sees:
     │ SELECT * FROM pwb_pages                    │ SELECT * FROM pwb_pages
     │ WHERE website_id = 1                       │
     │       ▲                                    │
     │       │ website_id matches                 │
     │       │ current tenant!                    │
     │                                            │
     ▼                                            ▼
Only site1 pages returned              ALL pages returned!
SAFE! ✅                               LEAKS DATA! ❌


SAFE PATTERN EXAMPLES:
═══════════════════════════════════════════════════════════════════

Via association (implicit scoping):
  current_website.pages
  current_website.messages
  current_website.contacts

Explicit filtering:
  Pwb::Page.where(website_id: current_website.id)
  Pwb::Message.where(website_id: current_website&.id)

Combining scopes:
  Pwb::Page.where(website_id: current_website.id)
           .visible
           .order(created_at: :desc)

Finding specific record:
  Pwb::Page.where(website_id: current_website.id).find(params[:id])
```

---

## Database Schema: Multi-Tenancy Columns

```
pwb_websites
├── id (PK)
├── slug (UNIQUE) ◄─── For X-Website-Slug header
├── subdomain (UNIQUE) ◄─── For subdomain resolution
├── company_display_name
└── theme_name

pwb_pages
├── id (PK)
├── website_id (FK, INDEX) ◄─── REQUIRED for scoping
├── slug
├── visible
└── ...

pwb_contents
├── id (PK)
├── website_id (FK, INDEX) ◄─── REQUIRED for scoping
├── key
├── sort_order
└── ...

pwb_messages
├── id (PK)
├── website_id (FK, INDEX) ◄─── REQUIRED for scoping
├── origin_email
├── content
└── ...

pwb_user_memberships
├── id (PK)
├── user_id (FK)
├── website_id (FK, INDEX) ◄─── Links users to websites
├── role (owner/admin/member)
└── active (boolean)

KEY PATTERN: Every tenant-scoped model has:
  • website_id column (bigint, nullable for backwards compat)
  • Index on website_id for fast filtering
  • Foreign key to pwb_websites (optional)
```

---

## Tenancy Safety Checklist

### When Creating New Models

```ruby
class MyModel < ApplicationRecord
  # ✅ 1. Add website association
  belongs_to :website, optional: true  # or: required: true for full safety
  
  # ✅ 2. Set website on creation
  before_validation :set_current_website
  
  # ✅ 3. Consider if optional: true is needed
  # Use required: true if model is ALWAYS scoped to a website
  
  private
  def set_current_website
    self.website_id ||= Pwb::Current.website&.id
  end
end

# ✅ 4. In migration:
class CreateMyModel < ActiveRecord::Migration[6.0]
  def change
    create_table :my_models do |t|
      t.references :website, foreign_key: { to_table: :pwb_websites }, index: true
      # other columns...
      t.timestamps
    end
  end
end

# ✅ 5. In controller:
class MyController < SiteAdminController
  def index
    @records = Pwb::MyModel.where(website_id: current_website.id)
  end
  
  def create
    @record = current_website.my_models.build(my_model_params)
    @record.save
  end
end
```

### When Adding New Queries

For EVERY query on a tenant-scoped model:

```ruby
# BEFORE writing any query, ask yourself:
# "Does this query need to be filtered by website?"

# If YES (99% of the time):
Model.where(website_id: current_website&.id)

# If NO (only for TenantAdmin features):
Model.unscoped.where(website_id: admin_selected_website.id)

# If UNSURE:
# → Ask a senior developer
# → Add a comment explaining why it's unscoped
# → Consider adding a test to verify safety
```

---

## Performance Characteristics

```
OPERATION                    COMPLEXITY    EXAMPLES
═══════════════════════════════════════════════════════════════════

Finding website by subdomain  O(1)         Website.find_by_subdomain('site1')
                                           (indexed column)

Listing current website's     O(n log n)   website.pages.order(:created_at)
records                                    (index on website_id)

Searching across all          O(m log m)   Pwb::Page.unscoped.where(...)
websites (TenantAdmin)                     (no scoping filter)

Creating record with          O(1)         current_website.pages.create(...)
auto-assignment                            (just sets FK)

Finding record with           O(1)         website.pages.find(id)
website check                              (WHERE website_id AND id)

Materializing property        Variable     Pwb::ListedProperty.refresh
view after updates                         (refreshes m-view,
                                           can take 10-30 seconds)
```

---

## Current Request vs Admin Request

```
PUBLIC REQUEST (e.g., site1.example.com/pages)
│
├─ SubdomainTenant extracts 'site1'
├─ Finds Website with subdomain='site1'
├─ Sets Pwb::Current.website
├─ No authentication required
├─ All queries filtered by website_id
└─ Returns site1's data only ✅


SITE ADMIN REQUEST (e.g., site1.example.com/admin/pages)
│
├─ SubdomainTenant extracts 'site1'
├─ Finds Website with subdomain='site1'
├─ Sets Pwb::Current.website
├─ Requires authentication via Devise
├─ Requires admin role for website
├─ All queries filtered by website_id
└─ Returns site1's data only ✅


TENANT ADMIN REQUEST (e.g., admin.example.com/websites)
│
├─ Subdomain = 'admin' (ignored by SubdomainTenant)
├─ Falls back to first website
├─ But uses TenantAdminController (NOT SubdomainTenant)
├─ Requires authentication + admin role
├─ EXPLICITLY uses .unscoped() for multi-website view
├─ Must specify website_id in queries
└─ Can see all websites' data (authorized admins only) ✅
```

---

## Summary

This architecture uses:
1. **Subdomain routing** for natural tenant isolation
2. **Thread-local storage** (CurrentAttributes) for implicit context
3. **Manual filtering** in controllers (explicit but error-prone)
4. **Association traversal** for safe implicit scoping
5. **Unscoped access** for administrative features (controlled & intentional)

The approach is **sound but requires discipline** - always remember to filter by website_id when querying tenant models!
