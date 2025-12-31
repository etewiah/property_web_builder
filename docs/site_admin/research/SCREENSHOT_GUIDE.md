# Admin Pages Screenshot Guide

Complete reference for capturing screenshots of all PropertyWebBuilder admin pages.

## Quick Reference: Admin Page URLs

### Site Admin URLs

```
Dashboard:
  GET /site_admin

Properties:
  GET /site_admin/props                           # Properties list
  GET /site_admin/props/:id                       # Property details
  GET /site_admin/props/:id/edit/general          # Edit general info
  GET /site_admin/props/:id/edit/text             # Edit text/descriptions
  GET /site_admin/props/:id/edit/sale_rental      # Edit sale/rental listings
  GET /site_admin/props/:id/edit/location         # Edit location/map
  GET /site_admin/props/:id/edit/labels           # Edit features/labels
  GET /site_admin/props/:id/edit/photos           # Photo management
  GET /site_admin/props/:id/sale_listings/new     # New sale listing
  GET /site_admin/props/:id/sale_listings/:id/edit # Edit sale listing
  GET /site_admin/props/:id/rental_listings/new   # New rental listing
  GET /site_admin/props/:id/rental_listings/:id/edit # Edit rental listing

Pages:
  GET /site_admin/pages                           # Pages list
  GET /site_admin/pages/:id                       # Page details
  GET /site_admin/pages/:id/edit                  # Edit page with parts
  GET /site_admin/pages/:id/settings              # Page settings
  GET /site_admin/pages/:id/page_parts/:id        # Page part details
  GET /site_admin/pages/:id/page_parts/:id/edit   # Edit page part
  GET /site_admin/page_parts                      # All page parts list
  GET /site_admin/page_parts/:id                  # Page part details

Content:
  GET /site_admin/contents                        # Contents list
  GET /site_admin/contents/:id                    # Content details

Email Templates:
  GET /site_admin/email_templates                 # Templates list
  GET /site_admin/email_templates/new?template_key=enquiry.general  # New template
  GET /site_admin/email_templates/:id             # Template details
  GET /site_admin/email_templates/:id/edit        # Edit template
  GET /site_admin/email_templates/:id/preview     # Preview template
  GET /site_admin/email_templates/preview_default?template_key=enquiry.general # Preview default

Website Settings:
  GET /site_admin/website/settings                # General settings tab
  GET /site_admin/website/settings/general        # General tab
  GET /site_admin/website/settings/appearance     # Appearance tab
  GET /site_admin/website/settings/navigation     # Navigation tab
  GET /site_admin/website/settings/home           # Home page tab
  GET /site_admin/website/settings/notifications  # Notifications tab

Properties Settings:
  GET /site_admin/properties/settings             # Settings index (all categories)
  GET /site_admin/properties/settings/:category   # Edit category (e.g., property-types)

Storage Statistics:
  GET /site_admin/storage_stats                   # Storage usage and cleanup

Analytics:
  GET /site_admin/analytics                       # Analytics overview
  GET /site_admin/analytics/traffic               # Traffic analytics
  GET /site_admin/analytics/properties            # Property analytics
  GET /site_admin/analytics/conversions           # Conversion funnel
  GET /site_admin/analytics/realtime              # Real-time visitors

Users/Messages/Contacts:
  GET /site_admin/users                           # Users list
  GET /site_admin/users/:id                       # User details
  GET /site_admin/messages                        # Messages list
  GET /site_admin/messages/:id                    # Message details
  GET /site_admin/contacts                        # Contacts list
  GET /site_admin/contacts/:id                    # Contact details

Domain:
  GET /site_admin/domain                          # Domain settings

Onboarding:
  GET /site_admin/onboarding                      # Welcome step
  GET /site_admin/onboarding/1                    # Welcome step
  GET /site_admin/onboarding/2                    # Profile step
  GET /site_admin/onboarding/3                    # Property step
  GET /site_admin/onboarding/4                    # Theme step
  GET /site_admin/onboarding/5                    # Complete step
  GET /site_admin/onboarding/complete             # Complete page
```

### Tenant Admin URLs

```
Dashboard:
  GET /tenant_admin

Websites:
  GET /tenant_admin/websites                      # Websites list
  GET /tenant_admin/websites/:id                  # Website details
  GET /tenant_admin/websites/new                  # New website
  GET /tenant_admin/websites/:id/edit             # Edit website

Users:
  GET /tenant_admin/users                         # Users list
  GET /tenant_admin/users/:id                     # User details
  GET /tenant_admin/users/new                     # New user
  GET /tenant_admin/users/:id/edit                # Edit user

Subscriptions:
  GET /tenant_admin/subscriptions                 # Subscriptions list
  GET /tenant_admin/subscriptions/:id             # Subscription details
  GET /tenant_admin/subscriptions/new             # New subscription
  GET /tenant_admin/subscriptions/:id/edit        # Edit subscription

Plans:
  GET /tenant_admin/plans                         # Plans list
  GET /tenant_admin/plans/:id                     # Plan details
  GET /tenant_admin/plans/new                     # New plan
  GET /tenant_admin/plans/:id/edit                # Edit plan

Email Templates:
  GET /tenant_admin/email_templates               # Templates list (global)
  GET /tenant_admin/email_templates/new?template_key=enquiry.general
  GET /tenant_admin/email_templates/:id
  GET /tenant_admin/email_templates/:id/edit
  GET /tenant_admin/email_templates/:id/preview

Domains:
  GET /tenant_admin/domains                       # Domains list
  GET /tenant_admin/domains/:id                   # Domain details
  GET /tenant_admin/domains/:id/edit              # Edit domain

Subdomains:
  GET /tenant_admin/subdomains                    # Subdomains list
  GET /tenant_admin/subdomains/:id                # Subdomain details
  GET /tenant_admin/subdomains/new                # New subdomain
  GET /tenant_admin/subdomains/:id/edit           # Edit subdomain

Auth Audit Logs:
  GET /tenant_admin/auth_audit_logs               # Audit logs list
  GET /tenant_admin/auth_audit_logs/:id           # Log details
  GET /tenant_admin/auth_audit_logs/user/:user_id # User login history
  GET /tenant_admin/auth_audit_logs/ip/:ip        # IP login history

Agencies:
  GET /tenant_admin/agencies                      # Agencies list
  GET /tenant_admin/agencies/:id                  # Agency details
  GET /tenant_admin/agencies/new                  # New agency
  GET /tenant_admin/agencies/:id/edit             # Edit agency

Read-Only Data Views:
  GET /tenant_admin/props                         # All properties
  GET /tenant_admin/props/:id                     # Property details
  GET /tenant_admin/pages                         # All pages
  GET /tenant_admin/pages/:id                     # Page details
  GET /tenant_admin/page_parts                    # All page parts
  GET /tenant_admin/page_parts/:id                # Page part details
  GET /tenant_admin/contents                      # All contents
  GET /tenant_admin/contents/:id                  # Content details
  GET /tenant_admin/messages                      # All messages
  GET /tenant_admin/messages/:id                  # Message details
  GET /tenant_admin/contacts                      # All contacts
  GET /tenant_admin/contacts/:id                  # Contact details
```

---

## Recommended Screenshot Capture Plan

### Phase 1: Core Admin Pages (Essential Documentation)

**Site Admin - Properties Management** (High Priority)
```bash
# Properties list
curl http://localhost:3000/site_admin/props

# Property details
curl http://localhost:3000/site_admin/props/1

# Edit general info
curl http://localhost:3000/site_admin/props/1/edit/general

# Photo management
curl http://localhost:3000/site_admin/props/1/edit/photos
```

**Site Admin - Dashboard** (Essential)
```bash
curl http://localhost:3000/site_admin
```

**Site Admin - Pages Management** (Essential)
```bash
curl http://localhost:3000/site_admin/pages
curl http://localhost:3000/site_admin/pages/1/edit
```

**Site Admin - Website Settings** (Essential)
```bash
curl http://localhost:3000/site_admin/website/settings/general
curl http://localhost:3000/site_admin/website/settings/appearance
curl http://localhost:3000/site_admin/website/settings/navigation
```

**Tenant Admin - Dashboard** (Essential)
```bash
curl http://localhost:3000/tenant_admin
```

**Tenant Admin - Websites** (Essential)
```bash
curl http://localhost:3000/tenant_admin/websites
curl http://localhost:3000/tenant_admin/websites/1
```

**Tenant Admin - Subscriptions** (Business Critical)
```bash
curl http://localhost:3000/tenant_admin/subscriptions
curl http://localhost:3000/tenant_admin/subscriptions/1
```

### Phase 2: Content Management Pages

```bash
# Email Templates
curl http://localhost:3000/site_admin/email_templates
curl http://localhost:3000/site_admin/email_templates/new?template_key=enquiry.general

# Analytics
curl http://localhost:3000/site_admin/analytics
curl http://localhost:3000/site_admin/analytics/traffic

# Onboarding
curl http://localhost:3000/site_admin/onboarding/1
curl http://localhost:3000/site_admin/onboarding/2
curl http://localhost:3000/site_admin/onboarding/4
```

### Phase 3: Management & Configuration Pages

```bash
# Tenant Admin
curl http://localhost:3000/tenant_admin/users
curl http://localhost:3000/tenant_admin/plans
curl http://localhost:3000/tenant_admin/domains

# Site Admin
curl http://localhost:3000/site_admin/properties/settings
curl http://localhost:3000/site_admin/storage_stats
```

---

## Test Data Requirements

To capture meaningful screenshots, you'll need:

### Site Admin Test Data
1. **At least 1 website** with:
   - Subdomain configured
   - Company name set
   - Theme selected
   - Subscription active (for analytics)

2. **At least 5 properties** with:
   - Reference numbers
   - Addresses/locations
   - Photos (5+ photos per property for photo gallery demo)
   - Sale and/or rental listings
   - Various property types and features

3. **At least 3-5 pages** with:
   - Different slugs (about, contact, etc.)
   - Page parts with content
   - Different visibility settings

4. **Sample email templates** (at least 1 custom template)

5. **Analytics data** (real or synthetic):
   - View events
   - Inquiry events
   - Property engagement data

### Tenant Admin Test Data
1. **At least 3-5 websites** with:
   - Different subdomains
   - Various company names
   - Mix of provisioning states

2. **At least 5-10 users** with:
   - Different roles (admin, owner, regular)
   - Different websites

3. **At least 3-5 plans** with:
   - Different pricing tiers
   - Different features
   - Different statuses (active/inactive)

4. **Multiple subscriptions** with:
   - Different statuses (active, trialing, past_due)
   - Different plans
   - Different websites

5. **Auth audit logs** (automatically generated):
   - Login/logout events
   - Failed login attempts
   - From various IP addresses

---

## Viewport Configurations

The existing screenshot scripts support:

```javascript
// Desktop (Primary)
{ name: 'desktop', width: 1440, height: 900 }

// Tablet (Secondary)
{ name: 'tablet', width: 768, height: 1024 }

// Mobile (Secondary)
{ name: 'mobile', width: 375, height: 812 }
```

**Recommendation**: 
- Capture desktop (1440x900) for all pages
- Capture mobile (375x812) only for key user-facing pages
- Skip tablet for admin pages (less commonly used for admin)

---

## Using the Screenshot Scripts

### Basic Usage

```bash
# Capture all theme pages (default theme)
node scripts/take-screenshots.js

# Capture a specific theme
SCREENSHOT_THEME=brisbane node scripts/take-screenshots.js

# Compress existing screenshots
node scripts/compress-screenshots.js

# Compress with custom max size
MAX_SIZE_MB=1.5 node scripts/compress-screenshots.js
```

### Extending for Admin Pages

The existing script currently captures frontend pages. To extend it for admin pages:

1. Add new ADMIN_PAGES array to script
2. Ensure logged-in state (set authentication cookies)
3. Use same viewport and compression settings
4. Store in separate admin subfolder: `docs/screenshots/dev/admin/`

Example:
```javascript
const ADMIN_PAGES = [
  { name: 'site-admin-dashboard', path: '/site_admin', auth: true },
  { name: 'site-admin-properties', path: '/site_admin/props', auth: true },
  { name: 'tenant-admin-dashboard', path: '/tenant_admin', auth: true, admin: true },
  // ... more pages
];
```

---

## Viewport Recommendations by Page Type

| Page Type | Desktop | Mobile | Tablet | Notes |
|-----------|---------|--------|--------|-------|
| Dashboards | Yes | Optional | No | Responsive, but landscape not needed |
| List pages (index) | Yes | Optional | No | Important to show responsive table |
| Edit forms | Yes | Yes | No | Forms critical to show on mobile |
| Settings pages | Yes | Optional | No | Usually form-heavy |
| Detail pages | Yes | Optional | No | Can have long scrolls |
| Modal dialogs | Yes | No | No | Not meant for mobile |
| Charts/Analytics | Yes | No | No | Complex visualizations for desktop |

---

## Accessibility & Consistency Notes

When capturing screenshots:

1. **Consistent Timezone**: Set to UTC for timestamps
2. **Consistent Locale**: Use English (en) for consistency
3. **Consistent Data**: Use same test data set for all screenshots
4. **Light Theme**: Capture with light/default theme (if dark mode available)
5. **No Modals**: Close any open dialogs before capturing
6. **Scrolled to Top**: All pages captured at full scroll to top
7. **Full Page**: Use fullPage: true in Playwright to capture entire scrollable content

### Example Playwright Configuration
```javascript
await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
await page.screenshot({ 
  path: filepath, 
  fullPage: true,  // Capture entire scrollable height
  type: 'png'
});
```

---

## File Naming Scheme

Recommended naming for admin page screenshots:

```
docs/screenshots/dev/admin/
├── site-admin-dashboard-desktop.png
├── site-admin-dashboard-mobile.png
├── site-admin-props-list-desktop.png
├── site-admin-props-edit-general-desktop.png
├── site-admin-pages-list-desktop.png
├── site-admin-pages-edit-desktop.png
├── site-admin-website-settings-general-desktop.png
├── site-admin-website-settings-appearance-desktop.png
├── site-admin-email-templates-desktop.png
├── site-admin-analytics-overview-desktop.png
├── site-admin-onboarding-step1-desktop.png
├── tenant-admin-dashboard-desktop.png
├── tenant-admin-websites-list-desktop.png
├── tenant-admin-subscriptions-list-desktop.png
├── tenant-admin-users-list-desktop.png
├── tenant-admin-plans-list-desktop.png
└── [... more pages]
```

**Pattern**: `{namespace}-{page}-{view}-{viewport}.png`

---

## Automation Checklist

To fully automate admin page screenshots:

- [ ] Create authentication fixture (logged-in cookie)
- [ ] Generate test data seed
- [ ] Extend screenshot script with admin pages
- [ ] Add admin URLs to ADMIN_PAGES array
- [ ] Set proper authentication headers
- [ ] Configure admin subfolder structure
- [ ] Test on local development server
- [ ] Verify compression settings (2MB max)
- [ ] Document screenshot capture in CI/CD pipeline
- [ ] Create README for regenerating screenshots

---

## Future Enhancements

Potential improvements for screenshot system:

1. **Animated GIFs**: Capture common workflows (drag-drop, form submission)
2. **Side-by-side Comparisons**: Theme comparison screenshots
3. **Highlighted Elements**: Show clickable areas or important fields
4. **Responsive Comparisons**: Desktop + Mobile side-by-side
5. **Dark Mode Variants**: If dark theme is added
6. **Localized Screenshots**: Multi-language documentation
7. **Interactive Overlays**: Click-through guides showing navigation
8. **Performance Metrics**: Include Lighthouse scores
9. **Accessibility Reports**: Screenshot with a11y violations highlighted
10. **Video Walkthroughs**: Record common admin workflows

---

## Page Categories by Purpose

### For User Onboarding Documentation
- Site Admin Dashboard
- Onboarding Wizard (all 5 steps)
- Properties List
- Property Edit (general)
- Website Settings (general & appearance)
- Email Templates

### For System Admin Documentation
- Tenant Admin Dashboard
- Websites List & Details
- Users Management
- Subscriptions List
- Plans List & Details
- Auth Audit Logs

### For Sales/Marketing Material
- Dashboard summaries (site & tenant)
- Analytics pages
- Website settings with customization examples
- Beautiful property with photos

### For Developer Documentation
- Edit forms (general, text, sale_rental, etc.)
- Page parts editor
- Properties settings configuration
- Auth audit logs (security features)

---

## Notes on Dynamic Content

Be aware these pages may have dynamic content that varies:

- **Analytics pages**: Time-based data changes daily
- **Audit logs**: New entries appear constantly
- **Subscription status**: Changes with time
- **Trial expirations**: 14-day countdown varies

For stable screenshots, consider:
1. Using synthetic/fixture data
2. Freezing time in tests
3. Mocking external data sources
4. Using consistent date ranges (e.g., "last 30 days")
