# Admin Screenshots Plan

This document outlines the plan for capturing screenshots of all PropertyWebBuilder admin pages.

## Overview

PropertyWebBuilder has two admin sections with approximately **109 pages total**:

| Section | Pages | Description |
|---------|-------|-------------|
| **Site Admin** | ~56 | Single website management (properties, pages, settings) |
| **Tenant Admin** | ~53 | Multi-tenant system administration (websites, subscriptions, plans) |

---

## Folder Structure

```
docs/screenshots/dev/admin/
├── site-admin/
│   ├── dashboard/
│   │   └── index-desktop.png
│   ├── properties/
│   │   ├── list-desktop.png
│   │   ├── show-desktop.png
│   │   ├── edit-general-desktop.png
│   │   ├── edit-text-desktop.png
│   │   ├── edit-sale-rental-desktop.png
│   │   ├── edit-location-desktop.png
│   │   ├── edit-labels-desktop.png
│   │   └── edit-photos-desktop.png
│   ├── pages/
│   │   ├── list-desktop.png
│   │   ├── show-desktop.png
│   │   ├── edit-desktop.png
│   │   └── settings-desktop.png
│   ├── settings/
│   │   ├── general-desktop.png
│   │   ├── appearance-desktop.png
│   │   ├── navigation-desktop.png
│   │   ├── home-desktop.png
│   │   └── notifications-desktop.png
│   ├── analytics/
│   │   ├── overview-desktop.png
│   │   ├── traffic-desktop.png
│   │   ├── properties-desktop.png
│   │   ├── conversions-desktop.png
│   │   └── realtime-desktop.png
│   ├── email-templates/
│   │   ├── list-desktop.png
│   │   ├── new-desktop.png
│   │   ├── edit-desktop.png
│   │   └── preview-desktop.png
│   ├── onboarding/
│   │   ├── step1-welcome-desktop.png
│   │   ├── step2-profile-desktop.png
│   │   ├── step3-property-desktop.png
│   │   ├── step4-theme-desktop.png
│   │   └── step5-complete-desktop.png
│   ├── users/
│   │   ├── list-desktop.png
│   │   └── show-desktop.png
│   ├── messages/
│   │   ├── list-desktop.png
│   │   └── show-desktop.png
│   ├── contacts/
│   │   ├── list-desktop.png
│   │   └── show-desktop.png
│   ├── storage-stats/
│   │   └── index-desktop.png
│   └── domain/
│       └── index-desktop.png
│
└── tenant-admin/
    ├── dashboard/
    │   └── index-desktop.png
    ├── websites/
    │   ├── list-desktop.png
    │   ├── show-desktop.png
    │   ├── new-desktop.png
    │   └── edit-desktop.png
    ├── subscriptions/
    │   ├── list-desktop.png
    │   ├── show-desktop.png
    │   ├── new-desktop.png
    │   └── edit-desktop.png
    ├── plans/
    │   ├── list-desktop.png
    │   ├── show-desktop.png
    │   ├── new-desktop.png
    │   └── edit-desktop.png
    ├── users/
    │   ├── list-desktop.png
    │   ├── show-desktop.png
    │   ├── new-desktop.png
    │   └── edit-desktop.png
    ├── domains/
    │   ├── list-desktop.png
    │   ├── show-desktop.png
    │   └── edit-desktop.png
    ├── subdomains/
    │   ├── list-desktop.png
    │   ├── show-desktop.png
    │   ├── new-desktop.png
    │   └── edit-desktop.png
    ├── audit-logs/
    │   ├── list-desktop.png
    │   ├── show-desktop.png
    │   ├── user-logs-desktop.png
    │   └── ip-logs-desktop.png
    ├── agencies/
    │   ├── list-desktop.png
    │   ├── show-desktop.png
    │   ├── new-desktop.png
    │   └── edit-desktop.png
    └── email-templates/
        ├── list-desktop.png
        ├── new-desktop.png
        ├── edit-desktop.png
        └── preview-desktop.png
```

---

## Implementation Phases

### Phase 1: High Priority (20 pages) - ~3 hours

Core pages that showcase main functionality:

**Site Admin (11 pages):**
| Page | URL | Screenshot Name |
|------|-----|-----------------|
| Dashboard | `/site_admin` | `dashboard/index-desktop.png` |
| Properties List | `/site_admin/props` | `properties/list-desktop.png` |
| Property Edit General | `/site_admin/props/:id/edit/general` | `properties/edit-general-desktop.png` |
| Property Edit Photos | `/site_admin/props/:id/edit/photos` | `properties/edit-photos-desktop.png` |
| Pages List | `/site_admin/pages` | `pages/list-desktop.png` |
| Page Edit | `/site_admin/pages/:id/edit` | `pages/edit-desktop.png` |
| Settings General | `/site_admin/website/settings/general` | `settings/general-desktop.png` |
| Settings Appearance | `/site_admin/website/settings/appearance` | `settings/appearance-desktop.png` |
| Settings Navigation | `/site_admin/website/settings/navigation` | `settings/navigation-desktop.png` |
| Onboarding Welcome | `/site_admin/onboarding/1` | `onboarding/step1-welcome-desktop.png` |
| Onboarding Theme | `/site_admin/onboarding/4` | `onboarding/step4-theme-desktop.png` |

**Tenant Admin (9 pages):**
| Page | URL | Screenshot Name |
|------|-----|-----------------|
| Dashboard | `/tenant_admin` | `dashboard/index-desktop.png` |
| Websites List | `/tenant_admin/websites` | `websites/list-desktop.png` |
| Website Details | `/tenant_admin/websites/:id` | `websites/show-desktop.png` |
| Subscriptions List | `/tenant_admin/subscriptions` | `subscriptions/list-desktop.png` |
| Subscription Details | `/tenant_admin/subscriptions/:id` | `subscriptions/show-desktop.png` |
| Plans List | `/tenant_admin/plans` | `plans/list-desktop.png` |
| Plan Edit | `/tenant_admin/plans/:id/edit` | `plans/edit-desktop.png` |
| Users List | `/tenant_admin/users` | `users/list-desktop.png` |
| Audit Logs List | `/tenant_admin/auth_audit_logs` | `audit-logs/list-desktop.png` |

### Phase 2: Medium Priority (30 pages) - ~4 hours

Secondary pages for complete documentation:

**Site Admin:**
- Analytics pages (5): overview, traffic, properties, conversions, realtime
- Email template pages (4): list, new, edit, preview
- Property edit remaining tabs (4): text, sale_rental, location, labels
- Settings remaining tabs (2): home, notifications
- Onboarding remaining steps (3): profile, property, complete

**Tenant Admin:**
- Website new/edit forms
- Subscription new/edit forms
- Domain management pages
- Subdomain management pages

### Phase 3: Complete Coverage (50+ pages) - ~8 hours

All remaining pages:
- All show/detail pages
- All create/new forms
- Users/messages/contacts pages
- Storage stats
- Mobile variants for key pages

---

## Test Data Requirements

### For Site Admin Screenshots

1. **Website** with:
   - Company name: "Coastal Properties"
   - Theme: brisbane or bologna
   - Active subscription
   - Analytics data (views, inquiries)

2. **Properties** (5+ recommended):
   - Different types (villa, apartment, penthouse)
   - Photos (5+ per property)
   - Sale and rental listings
   - Various features/labels

3. **Pages** (3+ recommended):
   - Home, About, Contact pages
   - Page parts with content
   - Different visibility settings

4. **Messages/Contacts** (3+ recommended):
   - Sample inquiry messages
   - Different read/unread states

### For Tenant Admin Screenshots

1. **Websites** (5+ recommended):
   - Different subdomains
   - Various provisioning states
   - Mix of themes

2. **Users** (5+ recommended):
   - Admin and regular users
   - Associated with different websites

3. **Subscriptions** (5+ recommended):
   - Different statuses (active, trialing, past_due, canceled)
   - Different plans

4. **Plans** (3+ recommended):
   - Free, Basic, Premium tiers
   - Different feature sets

5. **Auth Audit Logs** (auto-generated):
   - Login/logout events
   - Failed login attempts

---

## Running the Screenshot Script

### Prerequisites

```bash
# Install dependencies
npm install playwright sharp

# Ensure database is seeded
RAILS_ENV=development bin/rails db:seed
```

### Basic Usage

```bash
# Capture all admin pages (uses logged-in session)
node scripts/take-admin-screenshots.js

# Capture specific phase only
PHASE=1 node scripts/take-admin-screenshots.js

# Capture with custom base URL
BASE_URL=http://localhost:3000 node scripts/take-admin-screenshots.js

# Capture mobile variants too
INCLUDE_MOBILE=true node scripts/take-admin-screenshots.js
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_URL` | `http://localhost:3000` | Base URL of the app |
| `ADMIN_EMAIL` | `admin@example.com` | Admin user email for login |
| `ADMIN_PASSWORD` | `pwb123456` | Admin user password |
| `PHASE` | (all) | Capture phase 1, 2, or 3 only |
| `INCLUDE_MOBILE` | `false` | Also capture mobile viewport |
| `MAX_SIZE_MB` | `2` | Max file size before compression |

### Authentication

The script automatically:
1. Navigates to `/users/sign_in`
2. Fills in admin credentials
3. Submits the login form
4. Stores session cookies for subsequent requests

---

## Naming Convention

```
{section}/{page}-{viewport}.png

Examples:
site-admin/properties/list-desktop.png
site-admin/properties/edit-general-desktop.png
site-admin/settings/appearance-desktop.png
tenant-admin/subscriptions/show-desktop.png
tenant-admin/audit-logs/list-desktop.png
```

### Viewport Suffixes

| Suffix | Resolution | Use Case |
|--------|------------|----------|
| `-desktop` | 1440x900 | Primary documentation |
| `-mobile` | 375x812 | Mobile responsiveness |

---

## Updating Screenshots

### When to Update

- After UI changes to admin pages
- After adding new admin features
- Before major releases
- When documentation needs refresh

### Update Process

```bash
# 1. Ensure dev server is running
bin/rails s

# 2. Run screenshot script
node scripts/take-admin-screenshots.js

# 3. Review changes
git diff docs/screenshots/

# 4. Commit if satisfactory
git add docs/screenshots/dev/admin/
git commit -m "Update admin screenshots"
```

---

## Troubleshooting

### Common Issues

**Login fails:**
- Check admin credentials in environment variables
- Ensure user exists: `User.find_by(email: 'admin@example.com')`
- Check for CSRF token issues

**Page not found (404):**
- Ensure database is seeded with test data
- Check that required records exist (properties, pages, etc.)

**Timeout errors:**
- Increase timeout in script (default 30s)
- Check if server is running and responsive

**Large file sizes:**
- Sharp compression is automatic
- Reduce `MAX_SIZE_MB` if needed
- Consider reducing screenshot quality

### Debug Mode

```bash
# Run with visible browser
DEBUG=true node scripts/take-admin-screenshots.js

# Run with verbose logging
VERBOSE=true node scripts/take-admin-screenshots.js
```

---

## Related Documentation

- [Frontend Screenshots README](./README.md)
- [Admin Pages Inventory](../admin_pages_inventory.md)
- [Admin Pages Screenshot Guide](../admin_pages_screenshot_guide.md)

---

## Changelog

| Date | Changes |
|------|---------|
| 2024-12-25 | Initial plan created |
