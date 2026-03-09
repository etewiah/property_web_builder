# PropertyWebBuilder Documentation Index

Complete documentation for understanding the PropertyWebBuilder codebase, architecture, and integration points.

---

## Getting Started

**Start here if you're new to PropertyWebBuilder:**

1. **[architecture/EXPLORATION_SUMMARY.md](./architecture/EXPLORATION_SUMMARY.md)** (5 min read)
   - High-level overview of what was explored
   - Key insights and takeaways
   - Data model summary
   - AI integration opportunities

---

## Main Documentation

### Architecture & System Design

2. **[architecture/CODEBASE_STRUCTURE.md](./architecture/CODEBASE_STRUCTURE.md)** (Comprehensive, 45 min read)
   - **14 major sections** covering:
     1. Property model structure (RealtyAsset, SaleListing, RentalListing, ListedProperty)
     2. Property photos & media
     3. Features system
     4. Content management (Page, Content, PageContent, PagePart)
     5. Content translations & i18n
     6. Enquiries & contacts
     7. Website configuration
     8. Admin interfaces (site_admin vs tenant_admin)
     9. Data flow & content pipeline
     10. Tenant scoping (multi-tenancy)
     11. File storage & images
     12. Key integration points for AI
     13. Database relationships
     14. Configuration classes

3. **[architecture/ARCHITECTURE_DIAGRAMS.md](./architecture/ARCHITECTURE_DIAGRAMS.md)** (Visual, 30 min read)
   - **10 detailed ASCII diagrams** showing:
     - Property model architecture & relationships
     - Content management system structure
     - Enquiries & contacts flow
     - Media library hierarchy
     - Translation & localization pipeline
     - Multi-tenancy architecture
     - Website structure & navigation
     - Admin interface tiers
     - Data storage & locations
     - Translation data flow in system

---

## Quick Reference & Practical Guides

4. **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** (Practical, 20 min read)
   - **Model Quick Lookup** - All 20+ models in table format
   - **Common Queries** - 30+ real-world query examples
   - **Tenancy Patterns** - Web, console, background job contexts
   - **Translation Patterns** - How to access and modify translations
   - **Image/Media Handling** - PropPhoto, ContentPhoto, Media examples
   - **Refresh Materialized View** - When and how to refresh
   - **Website Configuration** - Accessing settings and configuration
   - **Pagination & Performance** - N+1 prevention, indexing strategies
   - **Messaging System** - Creating and tracking enquiries
   - **Admin Controllers** - Routes and purposes
   - **Integration Points** - Hooks for AI features
   - **Useful Scopes & Methods** - Common operations
   - **Database Indexes** - What's indexed and why

---

## Specialized Guides (Optional)

5. **[site_admin/features/ADMIN_QUICK_REFERENCE.md](./site_admin/features/ADMIN_QUICK_REFERENCE.md)** (Admin focus)
   - Website admin operations (`site_admin`)
   - Cross-tenant/platform operations (`tenant_admin`)
   - User management
   - Subscription/billing workflows
   - Website provisioning

6. **[theming/THEME_QUICK_REFERENCE.md](./theming/THEME_QUICK_REFERENCE.md)** (Frontend/theming)
   - Theme structure and organization
   - Tailwind CSS customization
   - Color palettes and variables
   - Template rendering

---

## How to Use This Documentation

### I Want To...

**Understand how properties work**
→ Read `architecture/CODEBASE_STRUCTURE.md` section 1, then `architecture/ARCHITECTURE_DIAGRAMS.md` section 1

**Query properties for search**
→ Read `QUICK_REFERENCE.md` "Properties" section + `architecture/CODEBASE_STRUCTURE.md` section 1

**Add translations to new model**
→ Read `architecture/CODEBASE_STRUCTURE.md` section 5 + `QUICK_REFERENCE.md` "Translation Attribute Patterns"

**Work with images/media**
→ Read `QUICK_REFERENCE.md` "Image/Media Handling" section + `architecture/CODEBASE_STRUCTURE.md` section 2

**Integrate AI features**
→ Read `architecture/CODEBASE_STRUCTURE.md` section 12 + `QUICK_REFERENCE.md` "Integration Points for AI Features"

**Understand multi-tenancy**
→ Read `architecture/ARCHITECTURE_DIAGRAMS.md` section 6 + `QUICK_REFERENCE.md` "Tenancy Patterns"

**Set up a new website**
→ Read `architecture/CODEBASE_STRUCTURE.md` section 7 + `site_admin/features/ADMIN_QUICK_REFERENCE.md`

**Add new admin page**
→ Read `QUICK_REFERENCE.md` "Admin Controllers" + `architecture/ARCHITECTURE_DIAGRAMS.md` section 8

**Debug a query**
→ QUICK_REFERENCE.md "Common Queries" + "Pagination & Performance"

**Understand data flow**
→ Read `architecture/ARCHITECTURE_DIAGRAMS.md` section 3 (enquiries), section 10 (translations), or section 9 (storage)

---

## Key Concepts at a Glance

### Property Structure (Normalized Schema)
- **RealtyAsset** = Physical property (immutable)
- **SaleListing** = Sale transaction (price, marketing text)
- **RentalListing** = Rental transaction (price, marketing text)
- **ListedProperty** = Optimized view for queries
- Only **ONE active listing per property per type**

### Content System
- **Page** = CMS page (About, Contact, etc.)
- **Content** = Reusable block (Hero, Testimonial, CTA)
- **PageContent** = Join table (allows same content on multiple pages)
- **PagePart** = Template definition (page sections)

### Multi-Tenancy
- **Pwb::*** = Global models (require manual scoping)
- **PwbTenant::\*** = Scoped models (auto-scoped in web context)
- **website_id** = Tenant identifier on all models
- **ActsAsTenant** = Middleware for automatic scoping

### Translations
- **Mobility gem** = Translation framework
- **JSONB column** = Single translations column per model
- **Locale accessors** = title_en, title_es, title_de (auto-generated)
- **Fallback chain** = All languages → English

### File Storage
- **ActiveStorage** = Rails file attachment system
- **Development** = Local disk (/storage)
- **Production** = Cloudflare R2 (S3-compatible)
- **Variants** = On-demand image resizing
- **CDN Support** = Direct URLs when configured

---

## File Locations in Codebase

### Models
- Properties: `/app/models/pwb/realty_asset.rb`, `sale_listing.rb`, `rental_listing.rb`, `listed_property.rb`
- Content: `/app/models/pwb/page.rb`, `content.rb`, `page_content.rb`, `page_part.rb`
- Contacts: `/app/models/pwb/contact.rb`, `message.rb`
- Media: `/app/models/pwb/media.rb`, `media_folder.rb`
- Configuration: `/app/models/pwb/website.rb`, `field_key.rb`, `plan.rb`, `subscription.rb`

### Controllers
- Site Admin: `/app/controllers/site_admin/`
- Tenant Admin: `/app/controllers/tenant_admin/`
- APIs: `/app/controllers/pwb/api/`, `/app/controllers/api_public/`

### Views
- Site Admin: `/app/views/site_admin/`
- Tenant Admin: `/app/views/tenant_admin/`
- Public: `/app/views/` (theme templates)

### Configuration
- Mobility: `/config/initializers/mobility.rb`
- Database: `/db/schema.rb`
- Migrations: `/db/migrate/`

---

## Documentation Statistics

| File | Size | Focus | Read Time |
|------|------|-------|-----------|
| architecture/EXPLORATION_SUMMARY.md | 12K | Overview | 5 min |
| architecture/CODEBASE_STRUCTURE.md | 25K | Comprehensive | 45 min |
| architecture/ARCHITECTURE_DIAGRAMS.md | 58K | Visual | 30 min |
| QUICK_REFERENCE.md | 17K | Practical | 20 min |
| site_admin/features/ADMIN_QUICK_REFERENCE.md | 13K | Admin | 15 min |
| theming/THEME_QUICK_REFERENCE.md | 3.8K | Theming | 10 min |
| **TOTAL** | **129K** | **All aspects** | **2+ hours** |

---

## Recommended Reading Order

### Quick Start (30 minutes)
1. architecture/EXPLORATION_SUMMARY.md
2. QUICK_REFERENCE.md (skim tables)

### Thorough Understanding (1-2 hours)
1. architecture/EXPLORATION_SUMMARY.md
2. architecture/CODEBASE_STRUCTURE.md (sections 1, 5, 6, 10)
3. architecture/ARCHITECTURE_DIAGRAMS.md (sections 1, 6)
4. QUICK_REFERENCE.md (all sections)

### Deep Dive (2+ hours)
1. All sections of architecture/CODEBASE_STRUCTURE.md
2. All diagrams in architecture/ARCHITECTURE_DIAGRAMS.md
3. All examples in QUICK_REFERENCE.md
4. Relevant sections of site_admin/features/ADMIN_QUICK_REFERENCE.md

### For Specific Tasks
- **AI Integration**: `architecture/CODEBASE_STRUCTURE.md` section 12 → `QUICK_REFERENCE.md` "Integration Points"
- **Admin Work**: `site_admin/features/ADMIN_QUICK_REFERENCE.md` → `architecture/ARCHITECTURE_DIAGRAMS.md` section 8
- **Frontend Dev**: `theming/THEME_QUICK_REFERENCE.md` → `architecture/ARCHITECTURE_DIAGRAMS.md` section 5
- **Database Work**: `QUICK_REFERENCE.md` "Database Indexes" → `architecture/CODEBASE_STRUCTURE.md` section 14

---

## Key Takeaways

PropertyWebBuilder is a **production-ready real estate SaaS platform** with:

1. **Clean Architecture**: Normalized property schema (Asset + Listings) vs legacy monolithic models
2. **Proper Multi-Tenancy**: ActsAsTenant pattern with website_id isolation
3. **Flexible Translations**: JSONB-backed translations with automatic fallbacks
4. **Optimized Queries**: Materialized view for fast property searches
5. **Media Management**: Centralized library with hierarchical folders
6. **Professional Admin UI**: Two-tier system (platform + tenant)
7. **Enterprise Features**: Subscriptions, multi-user access, custom domains

**Ready for AI Integration** with clear hooks for:
- Description generation
- Image analysis
- Content creation
- SEO optimization
- Smart search
- Enquiry processing

---

## Getting Help

If you need to understand something specific:

1. **Check the index** of `architecture/CODEBASE_STRUCTURE.md`
2. **Search `QUICK_REFERENCE.md`** for the model/query you need
3. **Look at `architecture/ARCHITECTURE_DIAGRAMS.md`** to see how components relate
4. **Review actual models** in `/app/models/pwb/` for implementation details

---

## Documentation Version

- **Created**: 2025-12-27
- **Coverage**: Complete exploration of PropertyWebBuilder codebase
- **Scope**: 14 major systems, 20+ key models, 100+ queries and patterns
- **Status**: Ready for immediate use in development and AI feature planning

---

## Next Steps

1. **Start with `architecture/EXPLORATION_SUMMARY.md`** for overview
2. **Keep QUICK_REFERENCE.md nearby** for day-to-day development
3. **Refer to `architecture/CODEBASE_STRUCTURE.md`** for deep understanding
4. **Use `architecture/ARCHITECTURE_DIAGRAMS.md`** to visualize system flows
5. **Consult specialized guides** (`site_admin/features/ADMIN_QUICK_REFERENCE.md`, `theming/THEME_QUICK_REFERENCE.md`) as needed

---

**Happy coding!** The PropertyWebBuilder codebase is well-structured and thoroughly documented here.
