# PropertyWebBuilder Admin Area - Quick Inventory

## Current State Summary

### Admin Areas Implemented

| Area | Status | Controller | Views | Key Models | DB Tables |
|------|--------|-----------|-------|-----------|-----------|
| **Dashboard** | ✅ Complete | `SiteAdminController` `TenantAdminController` | 1 view | Website, Subscription, Plan | pwb_websites, pwb_subscriptions, pwb_plans |
| **Properties** | ✅ Complete | `PropsController` | 9 templates | RealtyAsset, SaleListing, RentalListing, PropPhoto, Feature | pwb_realty_assets, pwb_sale_listings, pwb_rental_listings, pwb_prop_photos, pwb_properties (view) |
| **Messages/Inbox** | ✅ Complete | `MessagesController`, `InboxController` | 3+ views | Message, Contact | pwb_messages, pwb_contacts |
| **Pages/CMS** | ✅ Complete | `PagesController` | 5+ views | Page, PagePart, Content | pwb_pages, pwb_page_parts, pwb_contents |
| **Media Library** | ✅ Complete | `MediaLibraryController` | 4+ views | Media, MediaFolder | pwb_media, pwb_media_folders |
| **Onboarding** | ✅ Complete | `OnboardingController` | 5 steps | User (progress fields) | Users table |
| **Subscriptions** | ✅ Complete | `SubscriptionsController`, `BillingController` | TBD | Subscription, Plan, SubscriptionEvent | pwb_subscriptions, pwb_plans, pwb_subscription_events |

---

## Feature Inventory by Area

### 1. DASHBOARD
- [x] Website statistics (properties, pages, messages, contacts)
- [x] Weekly activity metrics
- [x] Recent activity timeline (properties, messages, contacts)
- [x] Website health/setup checklist (7 checks)
- [x] Subscription status display
- [x] Trial expiry warnings
- [x] Platform-level system overview (TenantAdmin)
- [x] Subscription statistics dashboard
- [ ] Custom date range selection
- [ ] Export statistics
- [ ] Email reports

### 2. PROPERTIES
- [x] List properties (with pagination)
- [x] Search by reference/title/address/city
- [x] Create new property
- [x] Edit general info (rooms, area, year, type, state)
- [x] Edit text (titles/descriptions per locale)
- [x] Edit sale/rental listings
- [x] Edit location (coordinates)
- [x] Edit labels/amenities (features)
- [x] Photo upload (file or external URL)
- [x] Photo reordering (drag-drop)
- [x] Photo deletion
- [x] Multi-listing support (sale + rental simultaneously)
- [x] Geocoding (auto-fill from address)
- [ ] Bulk operations (edit, move, delete)
- [ ] CSV/Excel import
- [ ] Property cloning/templates
- [ ] Price history tracking
- [ ] Change audit trail in UI

### 3. MESSAGES & INBOX
- [x] Message list with search
- [x] CRM-style inbox with contact threads
- [x] Contact list with message counts
- [x] Mark messages as read
- [x] Contact details view
- [x] Sender name/email extraction
- [x] Orphan message count
- [ ] Contact status tracking
- [ ] Message labels/tags
- [ ] Reply functionality
- [ ] Auto-responder setup
- [ ] Spam filtering
- [ ] Contact merge/deduplication
- [ ] Message export/archive

### 4. PAGES/CMS
- [x] List pages (paginated, searchable)
- [x] Create/edit pages
- [x] Edit page metadata (slug, SEO, nav visibility)
- [x] Drag-drop page parts reordering
- [x] Page part visibility toggle
- [x] Multi-language support (via Mobility)
- [ ] Visual page builder
- [ ] Version history/rollback
- [ ] Scheduled publishing
- [ ] Preview/staging mode
- [ ] Page hierarchy (parent/child)
- [ ] Custom menus
- [ ] Widget system

### 5. MEDIA LIBRARY
- [x] Gallery view with pagination
- [x] Search by filename/title/alt/description
- [x] Upload single or multiple files
- [x] Edit metadata (title, alt, description, tags)
- [x] Organize with folder hierarchy
- [x] Bulk move to folder
- [x] Bulk delete
- [x] Storage stats (total, by type)
- [x] Image dimension tracking
- [x] Usage count (field exists)
- [x] Tag support
- [ ] Storage quota enforcement
- [ ] Image optimization/compression
- [ ] Image variant management UI
- [ ] Duplicate detection
- [ ] Smart folder organization (AI)
- [ ] Collaboration (comments/notes)

### 6. ONBOARDING
- [x] 5-step guided wizard
  - [x] Step 1: Welcome
  - [x] Step 2: Agency profile setup
  - [x] Step 3: First property (optional)
  - [x] Step 4: Theme selection
  - [x] Step 5: Completion summary
- [x] Progress tracking (per user)
- [x] Step skipping (property only)
- [x] Restart option
- [ ] Conditional branching
- [ ] Multi-language setup
- [ ] Domain/email verification
- [ ] Payment method setup
- [ ] Team member invitation
- [ ] Visual progress bar

### 7. SUBSCRIPTIONS & PLANS
- [x] Plan definition (name, price, limits, features)
- [x] Trial management (duration, expiry)
- [x] Subscription status tracking (AASM state machine)
- [x] Plan enforcement (property limits)
- [x] Feature gating (per-plan features)
- [x] Trial ending soon notifications
- [x] Subscription event logging
- [x] Manual status transitions (admin)
- [ ] Plan customization (custom plans)
- [ ] Proration calculation
- [ ] Add-on features
- [ ] Volume discounts
- [ ] Trial extension UI
- [ ] Payment retry logic
- [ ] Dunning management
- [ ] Churn prevention tools
- [ ] Seat-based pricing UI

---

## Database Complexity

### Tables Count by Area
- **Subscriptions**: 3 tables (plans, subscriptions, subscription_events)
- **Properties**: 5 tables (realty_assets, sale_listings, rental_listings, prop_photos, features)
- **Messages**: 2 tables (messages, contacts)
- **Pages**: 4 tables (pages, page_parts, contents, page_contents)
- **Media**: 2 tables (media, media_folders)
- **Onboarding**: 0 tables (stores in users table)

**Total Admin-Related Tables**: ~20-25 (excluding shared system tables)

### Materialized Views
- `pwb_properties` - Denormalized property search index
  - Combines: realty_assets + sale_listings + rental_listings
  - Used for: all property read operations
  - Refresh: automatic after writes (async)

---

## SQL Patterns Used

| Pattern | Example | Tables |
|---------|---------|--------|
| **Tenant Scoping** | `WHERE website_id = ?` | All main tables |
| **Aggregation** | `COUNT()`, `SUM()`, `MAX()` | Messages, Contacts |
| **Joins** | `INNER JOIN pwb_messages` | Inbox contact query |
| **Array Columns** | `WHERE tag = ANY(tags)` | Media (tags) |
| **JSONB Queries** | `WHERE translations @> ?` | Pages, Listings |
| **Index Strategies** | Composite, unique, GIN | 30+ indexes |

---

## Technology Stack (Admin)

### Backend
- **Rails 7+** - MVC framework
- **PostgreSQL 13+** - Primary database
- **AASM** - State machine (subscriptions)
- **Mobility** - Translations (JSONB)
- **Money** (Monetize) - Currency handling
- **Geocoder** - Address geocoding
- **ActiveStorage** - File uploads
- **Pagy** - Pagination

### Frontend
- **ERB** - Templates
- **Tailwind CSS** - Styling
- **Stimulus.js** - JavaScript interactions
- **Rails UJS** - AJAX, forms

### Admin Features
- **Multi-tenancy** - website_id scoping
- **i18n** - Multi-language via Mobility
- **Pagination** - 25-100 items per page
- **Search** - ILIKE on string columns
- **Drag-drop** - Stimulus for reordering
- **Soft Validations** - User-friendly errors

---

## Gaps & Opportunities

### Quick Wins (Easy to Add)
- [ ] Bulk property export (CSV)
- [ ] Contact import (CSV)
- [ ] Property cloning
- [ ] Page duplication
- [ ] Media batch tagging
- [ ] Message filters (read/unread)

### Medium-Complexity Features
- [ ] Property import UI
- [ ] Change audit trail
- [ ] Contact merge tool
- [ ] Page scheduling
- [ ] Role-based permissions
- [ ] Team task assignment

### High-Complexity Features
- [ ] Visual page builder
- [ ] Advanced property workflows
- [ ] Custom analytics dashboard
- [ ] Automation rules engine
- [ ] API management
- [ ] Webhook management

---

## View Count Summary

**Total Admin Templates**: ~90+ views

| Section | Template Count |
|---------|---|
| Dashboard | 1 |
| Properties | 9 |
| Messages/Inbox | 5 |
| Pages | 5 |
| Media Library | 4 |
| Onboarding | 5 |
| Other (settings, users, etc.) | ~60 |

---

## Performance Considerations

### Optimizations in Place
- ✅ Materialized views for property searches
- ✅ Eager loading (with_eager_loading scope)
- ✅ Database indexes on commonly filtered columns
- ✅ Pagination (avoid loading all records)
- ✅ Scoped queries (website_id)

### Performance Risks
- ⚠️ N+1 on nested associations (if not careful)
- ⚠️ Large media uploads (no async processing visible)
- ⚠️ Contact list aggregation query (complex GROUP BY)
- ⚠️ Property view refresh (possibly slow for large datasets)

---

## Multi-Tenancy Implementation

### Scoping Strategy
- **Primary**: `website_id` foreign key
- **Query Level**: `where(website_id: current_website.id)`
- **Model Level**: Scope or association
- **View Level**: `current_website` context

### Security
- ✅ Tenant isolation at query level
- ✅ No cross-website data leakage
- ✅ User membership model prevents unauthorized access

### Limitations
- No row-level permissions (all-or-nothing admin access)
- No multi-website admin (admin per website)

---

## Next Steps for Implementation Planning

1. **Review** this inventory against feature requirements
2. **Map** new features to existing patterns
3. **Design** database schema changes needed
4. **Create** implementation checklists per feature
5. **Estimate** complexity and timeline
6. **Mock** UI/UX before coding

---

## Related Documentation

- `ADMIN_AREA_RESEARCH.md` - Detailed analysis of each component
- `app/controllers/site_admin/` - Controller implementations
- `app/models/pwb/` - Model definitions
- `app/views/site_admin/` - Template files
- `/db/schema.rb` - Full database schema

