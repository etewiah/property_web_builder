# Admin Pages Exploration Summary

## Quick Stats

| Metric | Count |
|--------|-------|
| Total Admin Pages | 109 |
| Site Admin Pages | 56 |
| Tenant Admin Pages | 53 |
| Site Admin Controllers | 20 |
| Tenant Admin Controllers | 15 |
| Admin Views (.erb files) | 75+ |
| Existing Screenshot Scripts | 3 |
| Screenshot Folder Versions | 3 (dec_23, dec_24, dev) |

## Two-Tier Admin Architecture

### Site Admin (Single Tenant)
- **URL Prefix**: `/site_admin`
- **Scope**: Current website only
- **Use Case**: Website owners managing their own properties, pages, settings
- **Controllers**: 20 (props, pages, contents, email_templates, analytics, storage_stats, onboarding, etc.)
- **Authorization**: To be implemented (currently any logged-in user)
- **Key Pages**: Dashboard, Properties list/edit, Pages editor, Website settings, Analytics, Email templates

### Tenant Admin (Multi-Tenant)
- **URL Prefix**: `/tenant_admin`
- **Scope**: All websites globally (unscoped)
- **Use Case**: System administrators managing multiple tenant websites
- **Controllers**: 15 (websites, users, subscriptions, plans, domains, subdomains, agencies, auth_audit_logs, etc.)
- **Authorization**: TENANT_ADMIN_EMAILS environment variable only (Phase 2)
- **Key Pages**: Dashboard, Websites management, Subscriptions/Plans, Users, Security audit logs

## File Locations

All admin code organized by namespace:

```
app/controllers/
├── site_admin/                    # 20 controllers
│   ├── dashboard_controller.rb
│   ├── props_controller.rb        # Properties: list, show, 6 edit views
│   ├── pages_controller.rb
│   ├── props/
│   │   ├── sale_listings_controller.rb
│   │   └── rental_listings_controller.rb
│   ├── pages/
│   │   └── page_parts_controller.rb
│   ├── website/
│   │   └── settings_controller.rb  # 5 tabs: general, appearance, navigation, home, notifications
│   ├── properties/
│   │   └── settings_controller.rb
│   ├── analytics_controller.rb     # 5 views: overview, traffic, properties, conversions, realtime
│   ├── email_templates_controller.rb
│   ├── storage_stats_controller.rb
│   ├── onboarding_controller.rb    # 5 steps: welcome, profile, property, theme, complete
│   ├── contents_controller.rb
│   ├── messages_controller.rb
│   ├── contacts_controller.rb
│   ├── users_controller.rb
│   ├── page_parts_controller.rb
│   ├── tour_controller.rb
│   ├── domains_controller.rb
│   └── images_controller.rb
│
├── tenant_admin/                  # 15 controllers
│   ├── dashboard_controller.rb
│   ├── websites_controller.rb
│   ├── users_controller.rb
│   ├── subscriptions_controller.rb
│   ├── plans_controller.rb
│   ├── email_templates_controller.rb
│   ├── domains_controller.rb       # Custom domain verification
│   ├── subdomains_controller.rb    # Subdomain pool management
│   ├── auth_audit_logs_controller.rb # Security audit trail
│   ├── agencies_controller.rb
│   ├── props_controller.rb         # Read-only data view
│   ├── pages_controller.rb         # Read-only data view
│   ├── page_parts_controller.rb    # Read-only data view
│   ├── contents_controller.rb      # Read-only data view
│   └── website_admins_controller.rb
│
├── site_admin_controller.rb        # Base controller
└── tenant_admin_controller.rb      # Base controller

app/views/
├── site_admin/                     # 50+ ERB templates
│   ├── dashboard/
│   ├── props/                      # Properties views
│   │   ├── index, show
│   │   ├── edit_general, edit_text, edit_sale_rental, edit_location, edit_labels, edit_photos
│   │   ├── sale_listings/
│   │   └── rental_listings/
│   ├── pages/                      # Pages views
│   │   ├── index, show, edit, settings
│   │   └── page_parts/
│   ├── website/settings/           # 5 tabs
│   ├── properties/settings/        # Settings config
│   ├── analytics/                  # 5 analytics views
│   ├── email_templates/            # Template management
│   ├── onboarding/                 # 5 steps + complete
│   ├── storage_stats/
│   ├── [... other views]
│
└── tenant_admin/                   # 25+ ERB templates
    ├── dashboard/
    ├── websites/
    ├── users/
    ├── subscriptions/
    ├── plans/
    ├── domains/
    ├── subdomains/
    ├── auth_audit_logs/
    ├── agencies/
    ├── [... data views]
```

## Existing Screenshot Infrastructure

### Scripts

1. **`scripts/take-screenshots.js`** (Main script)
   - Captures frontend pages across themes and viewports
   - Supports mobile, tablet, desktop viewports
   - Auto-compresses with Sharp
   - Features: Theme support, dynamic page discovery, full-page capture
   - Environment variables: BASE_URL, SCREENSHOT_THEME, MAX_SIZE_MB

2. **`scripts/compress-screenshots.js`** (Standalone compression)
   - Compresses PNG to max size (default 2MB)
   - Intelligent resizing and color palette optimization
   - Fallback to JPEG conversion if needed
   - Can compress specific themes

3. **`scripts/take-screenshots-prod.js`** (Not examined)
   - Production variant, likely for CI/CD

### Screenshot Structure
```
docs/screenshots/
├── README.md                      # Documentation
├── dec_23/                        # Archived
├── dec_24/                        # Archived
└── dev/
    ├── default/                   # Default theme screenshots
    ├── brisbane/                  # Brisbane theme screenshots
    └── bologna/                   # Bologna theme screenshots
```

### Naming Convention
- Pattern: `{page}-{viewport}.png`
- Pages: home, home-en, buy, rent, contact, about, property-sale, property-rent
- Viewports: desktop, tablet, mobile

## Key Findings

### High-Priority Pages for Documentation

**Site Admin** (Most important):
1. Dashboard - First impression, statistics overview
2. Properties List - Most-used page
3. Property Edit (General) - Core editing interface
4. Pages List & Edit - Content management
5. Website Settings - Configuration hub
6. Analytics Dashboard - Key business metrics
7. Onboarding Wizard - User journey

**Tenant Admin** (Important for system admins):
1. Dashboard - System overview
2. Websites List - Tenant management
3. Subscriptions List - Business critical
4. Plans List - Configuration
5. Users List - User management
6. Auth Audit Logs - Security feature

### Page Rendering Details

All admin pages use:
- **ERB templates** for server-side rendering
- **Tailwind CSS** for styling (no Bootstrap)
- **Stimulus.js** for interactive elements
- **Pagy gem** for pagination
- **Responsive design** (mobile, tablet, desktop)

### Missing Features

Pages not yet implemented:
- Advanced user roles/permissions UI
- Theme builder/customizer (visual editor)
- Bulk import/export UI
- Email campaign management
- Advanced reporting/dashboards

### Multi-Tenant Isolation

Security patterns used:
- Site Admin: Scoped to `current_website` (SubdomainTenant concern)
- Tenant Admin: Unscoped (uses `Pwb::Website.unscoped`)
- Foreign keys: `website_id` on tenant-scoped models
- Access control: Based on user membership/admin status

## Recommendations for Screenshot Capture

### Immediate (Phase 1)

Priority pages to capture for documentation:
1. Site Admin Dashboard
2. Properties list and edit (general info)
3. Pages list and editor
4. Website Settings (general, appearance tabs)
5. Tenant Admin Dashboard
6. Websites and Subscriptions management

**Effort**: ~15-20 screenshots with high documentation value

### Short-term (Phase 2)

Additional pages for comprehensive coverage:
- Email templates and customization
- Analytics pages
- Onboarding wizard flow
- Settings configuration
- Admin list pages (users, domains, etc.)

**Effort**: ~30-40 additional screenshots

### Long-term (Phase 3)

Complete documentation set:
- All detail/show pages
- All edit pages
- All filter/search variations
- All tab variants
- Mobile views for key pages

**Effort**: ~50+ additional screenshots

## Test Data Needs

To capture meaningful admin screenshots, prepare:

### Site Admin Data
- 1+ websites with company info, theme, subscription
- 5+ properties with photos, addresses, listings
- 3-5 pages with different content
- Email templates (custom examples)
- Analytics data (real or synthetic)

### Tenant Admin Data
- 3-5 websites with different states
- 5-10 users with different roles
- 3-5 plans with different features
- Multiple subscriptions (various statuses)
- Auth audit logs (auto-generated)

## Integration with CI/CD

The screenshot system should:
1. Run on every main branch commit (for visual regression testing)
2. Store in git (small, compressed PNG format)
3. Generate before documentation builds
4. Support manual regeneration via script
5. Include compression to keep repo size manageable

## Related Documentation

- `CLAUDE.md` - Project-specific Claude instructions
- `docs/authentication/` - Auth system documentation
- `docs/multi_tenancy/` - Multi-tenant architecture
- `docs/field_keys/` - Field configuration system
- `docs/admin/` - Admin UI documentation (if exists)

---

## Actions Taken

1. **Created `docs/admin_pages_inventory.md`**
   - Comprehensive listing of all 109 admin pages
   - Grouped by functional area (Dashboard, Properties, Pages, etc.)
   - Includes routes, controllers, views, purpose, and key features
   - Statistics on page counts by section

2. **Created `docs/admin_pages_screenshot_guide.md`**
   - Complete URL reference for all admin pages
   - Recommended screenshot capture plan (3 phases)
   - Test data requirements
   - Viewport recommendations
   - File naming scheme
   - Automation checklist
   - Future enhancement ideas

3. **Created `docs/admin_pages_summary.md`** (this document)
   - Quick reference statistics
   - Architecture overview
   - File location guide
   - Key findings and recommendations
   - Test data needs

---

## Next Steps (for implementation team)

1. **Review** these documentation files for completeness
2. **Extend** the existing screenshot script to capture admin pages
3. **Prepare** test data fixtures for consistent screenshots
4. **Capture** Phase 1 screenshots (15-20 high-priority pages)
5. **Store** screenshots in `docs/screenshots/dev/admin/` folder
6. **Document** how to regenerate screenshots
7. **Consider** adding admin page screenshots to CI/CD pipeline
8. **Plan** future phases for complete coverage

---

## Files Created

Located in `/Users/etewiah/dev/sites-older/property_web_builder/docs/`:

1. **admin_pages_inventory.md** (5000+ words)
   - Complete reference for all 109 admin pages
   - Organized by section with routes, controllers, views

2. **admin_pages_screenshot_guide.md** (3000+ words)
   - Screenshot capture strategies
   - Complete URL listing
   - Test data requirements
   - Implementation checklist

3. **admin_pages_summary.md** (this file)
   - Quick reference statistics
   - Architecture overview
   - Key findings and next steps
