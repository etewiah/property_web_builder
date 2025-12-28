# PropertyWebBuilder Codebase Exploration Summary

**Date**: 2025-12-27  
**Project**: PropertyWebBuilder Real Estate Platform  
**Architecture**: Rails 8 + PostgreSQL + Tailwind CSS  
**Key Pattern**: Multi-tenant SaaS with normalized property schema

---

## What Was Explored

### 1. Property Model Architecture
- **Normalized Schema** (not legacy monolithic model)
  - `RealtyAsset` = Physical property (the building/land)
  - `SaleListing` = Sale transaction details (pricing, marketing text)
  - `RentalListing` = Rental transaction details (pricing, marketing text)
  - `ListedProperty` = Materialized view for optimized queries
- **Key Innovation**: Multiple listings over time per property (audit trail)
- **Features System**: Property amenities stored in separate table
- **Photos**: ActiveStorage-backed with support for external URLs

### 2. Content Management System
- **Page Model**: CMS pages with multi-language support
- **Content Blocks**: Reusable content (hero sections, testimonials, CTAs)
- **PageContent**: Join table allowing same content on multiple pages
- **Translations**: JSONB via Mobility gem (no separate translation table)
- **Images**: ContentPhoto for block-level images with variants

### 3. Enquiry & Contact Management
- **Contact Model**: Stores visitor information (visitor tracking)
- **Message Model**: Enquiry submissions with metadata (IP, user agent, location)
- **Delivery Tracking**: Email delivery status, error logging
- **Ntfy Integration**: Optional push notifications to admins

### 4. Media Library System
- **Centralized Media Management**: Single library for all files
- **Hierarchical Folders**: Parent-child folder structure
- **File Metadata**: Auto-extracted dimensions, checksums, content type
- **Usage Tracking**: Records usage count and last used time
- **Variant Support**: On-demand image variants (thumb, small, medium, large)
- **External Image Mode**: Option to use external URLs instead of uploads

### 5. Translations & Localization
- **Mobility JSONB Backend**: All translations in single column
- **Auto-Generated Accessors**: title_en, title_es, title_de, etc.
- **Fallback Chain**: All languages fall back to English
- **FieldKey System**: Dynamic translation keys for dropdowns (property types, states, features)
- **Supported Languages**: en, es, de, fr, nl, pt, it

### 6. Multi-Tenancy Architecture
- **Single Database, Multiple Websites**: All tenants in one DB
- **Dual Model Stack**: Pwb::* (global) vs PwbTenant::* (scoped)
- **ActsAsTenant Pattern**: Automatic scoping in web context
- **website_id Isolation**: All models have website_id column for data isolation
- **User Memberships**: Users can manage multiple websites with different roles

### 7. Admin Interfaces
- **Two-Tier System**:
  - **site_admin**: Platform admins (manage websites, plans, users)
  - **tenant_admin**: Website admins (manage their website's content)
- **Dashboard, Media Library, Pages, Content, Contacts, Domains, Email Templates**
- **Onboarding System**: Step-by-step setup wizard for new websites

### 8. Image & File Storage
- **ActiveStorage Integration**:
  - Development: Local disk
  - Production: Cloudflare R2 (S3-compatible)
- **URL Strategy**: Rails blob URLs (work across all backends)
- **CDN Support**: Direct CDN URLs when configured
- **Variant Processing**: On-demand image variants with size optimization

---

## Key Files Created

1. **`docs/CODEBASE_STRUCTURE.md`** (Comprehensive)
   - Detailed explanation of all 14 core sections
   - Property model architecture breakdown
   - Photo/media handling
   - Features system
   - Content management
   - Translations
   - Enquiries/contacts
   - Website configuration
   - Admin interfaces
   - Data flow
   - Tenant scoping
   - File storage
   - Integration points for AI

2. **`docs/ARCHITECTURE_DIAGRAMS.md`** (Visual)
   - 10 detailed ASCII diagrams showing:
     - Property model relationships
     - Content management system
     - Enquiry flow
     - Media library hierarchy
     - Translation pipeline
     - Multi-tenancy isolation
     - Website structure
     - Admin tiers
     - Data storage stack
     - Translation data flow

3. **`docs/QUICK_REFERENCE.md`** (Practical)
   - Model lookup table
   - Common queries (10+ examples)
   - Tenancy patterns
   - Translation patterns
   - Image/media handling
   - Website configuration access
   - Pagination/performance tips
   - Messaging system
   - Admin controller routes
   - AI integration points
   - Useful scopes & methods
   - Database indexes

---

## Critical System Insights

### Architecture Strengths
1. **Normalized Schema** - RealtyAsset + Listing model separation allows proper audit trails
2. **Materialized View** - ListedProperty view optimizes property search queries
3. **JSONB Translations** - Single column per model, GIN indexed, no join table overhead
4. **Media Centralization** - Single media library instead of scattered file storage
5. **Multi-Tenancy** - Proper isolation with acts-as-tenant pattern
6. **Flexible Configuration** - JSON columns for extensibility without migrations

### Design Patterns Used
- **Multi-Tenancy**: ActsAsTenant gem with website_id scoping
- **Translations**: Mobility gem with JSONB container backend
- **File Storage**: ActiveStorage with S3/R2 support
- **Money Handling**: money-rails gem for prices (stored as cents)
- **Bitwise Flags**: FlagShihTzu for compact boolean storage
- **Materialized View**: Scenic gem for query optimization

### Important Constraints
- Only **ONE active listing per property per type** (sale or rental)
- Listings can be archived (history preserved)
- Photos have explicit `sort_order` for display sequence
- All admin access is website-scoped via ActsAsTenant
- Translations stored in JSONB with fallback to English

---

## Data Model Summary

```
Website (Tenant)
├── Properties (RealtyAsset)
│   ├── Sale Transaction (SaleListing) [0-1]
│   ├── Rental Transaction (RentalListing) [0-1]
│   ├── Images (PropPhoto) [0+]
│   └── Features (Feature) [0+]
├── Pages & Content
│   ├── Page (CMS)
│   ├── Content Block (Reusable)
│   └── PageContent (Join)
├── Visitors & Enquiries
│   ├── Contact (Visitor Record)
│   └── Message (Enquiry)
├── Media Library
│   ├── MediaFolder (Hierarchy)
│   └── Media (File)
├── Admin Configuration
│   ├── FieldKey (Translation Keys)
│   ├── Link (Navigation)
│   ├── User (Admin)
│   └── Subscription (Billing)
└── Settings
    ├── Locales
    ├── Theme
    ├── Colors
    └── Integrations
```

---

## Integration Points for AI Features

### Recommended Hooks
1. **Property Descriptions** → SaleListing.after_create
2. **Image Analysis** → PropPhoto.after_create_commit
3. **Content Generation** → Page.create_fragment_html
4. **SEO Optimization** → Before saving listing
5. **Feature Suggestions** → On property edit
6. **Enquiry Processing** → After Message.create
7. **Translation Assistance** → Content block editor

### Data to Leverage
- **JSONB Translations Column** → Store AI metadata
- **Website Configuration** → AI feature flags
- **Materialized View** → Search similar properties
- **Features Table** → Learn property types
- **Media Library** → Analyze image patterns
- **Message Content** → Process enquiries

---

## Performance Considerations

### Indexing
- GIN indexes on JSONB translation columns
- B-tree indexes on frequently filtered fields (for_sale, for_rent, price, highlighted)
- Unique indexes on slugs and scoped keys
- Partial indexes for conditional data

### Query Optimization
- Use `ListedProperty` view for searches (denormalized)
- Include associations to prevent N+1 queries
- Pagination for large datasets
- Cache frequently accessed translations

### Caching Strategy
- Materialized view refreshes on property updates
- Optional: Cache FieldKey dropdowns
- Optional: Cache website configuration

---

## Multi-Language Support Examples

### Setting Translations
```ruby
listing = Pwb::SaleListing.first
listing.title_en = "Beautiful Apartment"
listing.title_es = "Apartamento Hermoso"
listing.title_de = "Wunderschöne Wohnung"
listing.save!
```

### Displaying Translations
```erb
<!-- In view -->
<h1><%= listing.title %></h1>  <!-- Uses current I18n.locale -->

<!-- Specific locale -->
<%= listing.title_es %>  <!-- Spanish version -->

<!-- Translation missing? Falls back to English -->
<%= listing.title_fr %>  <!-- Returns title_en if fr not set -->
```

### Field Keys for Dropdowns
```ruby
# Admin wants to customize property types for their website
options = Pwb::FieldKey.get_options_by_tag("property-types")
# Each website can have different labels (translated per tenant)
```

---

## Key Tables Quick Reference

| Table | Rows | Purpose |
|-------|------|---------|
| `pwb_realty_assets` | 1000s | Physical properties |
| `pwb_sale_listings` | 1000s | Sale transactions |
| `pwb_rental_listings` | 1000s | Rental transactions |
| `pwb_properties` | (view) | Query-optimized view |
| `pwb_pages` | 10-100 | CMS pages per website |
| `pwb_contents` | 100-1000 | Reusable content blocks |
| `pwb_contacts` | 100s-1000s | Visitor/lead records |
| `pwb_messages` | 1000s | Enquiries |
| `pwb_media` | 1000s | Media library files |
| `pwb_websites` | 10s | Tenants |
| `pwb_users` | 100s | Platform users |
| `pwb_field_keys` | 100-1000 | Translation keys (per tenant) |

---

## What's NOT Here

### Deprecated/Legacy
- `Pwb::Prop` model (being phased out)
- Vue.js frontend (`app/frontend/` - marked DEPRECATED)
- GraphQL API (`app/graphql/` - marked DEPRECATED)
- Bootstrap CSS (replaced with Tailwind)
- Capybara/Selenium (replaced with Playwright)

### External Systems (Optional)
- Ntfy.sh (push notifications)
- Google Maps API
- reCAPTCHA
- Analytics (Ahoy, Google Analytics)
- Stripe (subscriptions)

---

## Next Steps for Implementation

### To Build AI Features:
1. Choose integration points from CODEBASE_STRUCTURE.md section 12
2. Reference QUICK_REFERENCE.md for common patterns
3. Use ARCHITECTURE_DIAGRAMS.md to understand data flows
4. Hook into model callbacks for automation
5. Store AI metadata in JSON columns (details, configuration, admin_config)
6. Test tenancy isolation thoroughly
7. Use background jobs for heavy AI API calls

### To Extend the System:
1. Always scope queries to current_website
2. Add website_id to new models
3. Add translations to user-facing text (use JSONB translates)
4. Store settings in JSON columns, not new columns
5. Add unique constraints with website_id for tenant safety
6. Use acts-as-tenant pattern for new models

---

## Documentation Files Location

All exploration documentation is in `/Users/etewiah/dev/sites-older/property_web_builder/docs/`:

- `CODEBASE_STRUCTURE.md` - Comprehensive technical breakdown
- `ARCHITECTURE_DIAGRAMS.md` - Visual architecture with ASCII diagrams
- `QUICK_REFERENCE.md` - Practical quick-lookup guide
- `EXPLORATION_SUMMARY.md` - This file (high-level overview)

**Total Documentation**: 8,000+ lines covering all major systems

---

## Key Takeaway

PropertyWebBuilder is a **well-architected, production-ready real estate SaaS platform** with:
- Clean separation of concerns (RealtyAsset vs Listings)
- Proper multi-tenancy isolation
- Flexible translation system
- Optimized materialized views for performance
- Professional admin interfaces
- Enterprise-grade file handling

The codebase is **ready for AI integration** with clear hooks for:
- Description generation
- Image analysis
- Content suggestions
- Smart search
- Enquiry processing
- SEO optimization

**Recommendation**: Use the QUICK_REFERENCE.md for day-to-day work, CODEBASE_STRUCTURE.md for deep dives, and ARCHITECTURE_DIAGRAMS.md to understand system flows.
