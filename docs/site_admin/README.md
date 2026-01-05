# Site Admin Documentation

Comprehensive documentation for the PropertyWebBuilder admin system.

---

## Quick Links

| Document | Purpose |
|----------|---------|
| [ROADMAP.md](./ROADMAP.md) | Product & UX roadmap with priorities |
| [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) | Detailed technical implementation plan |

---

## Documentation Structure

```
docs/site_admin/
├── README.md                    # This file
├── ROADMAP.md                   # Product roadmap (0-6 months)
├── IMPLEMENTATION_PLAN.md       # Detailed technical plan
│
├── architecture/                # System design & structure
│   ├── ADMIN_ARCHITECTURE.md    # System diagrams & data flows
│   ├── TENANT_ADMIN_STRUCTURE.md # Multi-tenant admin structure
│   └── 01_Implementation_Details.md
│
├── research/                    # Inventory & analysis
│   ├── ADMIN_AREA_RESEARCH.md   # Comprehensive research document
│   ├── ADMIN_INVENTORY_SUMMARY.md # Quick reference checklist
│   ├── CONTROLLER_ACTIONS.md    # Controller action matrix
│   ├── PAGES_INVENTORY.md       # All admin pages inventory
│   ├── PAGES_SUMMARY.md         # Pages summary
│   ├── SCREENSHOT_GUIDE.md      # Screenshot capture guide
│   ├── SCREENSHOTS_PLAN.md      # Screenshot automation plan
│   └── admin_functionality_gap_analysis.md
│
├── features/                    # Feature documentation
│   ├── ADMIN_FEATURES_GUIDE.md  # Feature implementation guide
│   ├── ADMIN_USE_CASES.md       # User journey documentation
│   ├── ADMIN_QUICK_REFERENCE.md # Quick reference card
│   ├── ADMIN_SETTINGS_CONSOLIDATION_PLAN.md
│   └── SITE_ADMIN_GAP_PLAN.md   # Gap analysis & plan
│
└── properties_settings/         # Properties settings module
    ├── README.md
    ├── admin_interface_documentation.md
    ├── developer_guide.md
    └── user_guide.md
```

---

## Overview

The Site Admin is a multi-tenant Rails application where each website operates as an isolated tenant with its own admin panel.

### Key Components

| Component | Description |
|-----------|-------------|
| Dashboard | Overview widgets, activity feed, subscription status |
| Properties | Listing management (sale/rent), photos, pricing |
| Pages | CMS page management, SEO settings |
| Messages | Contact form submissions, conversations |
| Contacts | Lead management, CRM-lite features |
| Media | Image library, usage tracking |
| Settings | Website configuration, branding, integrations |
| Onboarding | Guided setup wizard for new users |

### Technology Stack

- **Backend:** Rails 7.2, PostgreSQL
- **Frontend:** ERB templates, Tailwind CSS, Stimulus.js
- **Icons:** Material Symbols
- **Testing:** RSpec (unit), Playwright (E2E)

---

## Getting Started

### For Developers

1. Read [architecture/ADMIN_ARCHITECTURE.md](./architecture/ADMIN_ARCHITECTURE.md) for system overview
2. Review [research/CONTROLLER_ACTIONS.md](./research/CONTROLLER_ACTIONS.md) for route reference
3. Check [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) for current work

### For Product/Planning

1. Start with [ROADMAP.md](./ROADMAP.md) for priorities
2. See [features/ADMIN_USE_CASES.md](./features/ADMIN_USE_CASES.md) for user journeys
3. Review [research/ADMIN_INVENTORY_SUMMARY.md](./research/ADMIN_INVENTORY_SUMMARY.md) for feature matrix

---

## Admin Routes

All site admin routes are prefixed with `/site_admin`:

```
/site_admin                     # Dashboard
/site_admin/props               # Properties list
/site_admin/props/:id/edit      # Edit property
/site_admin/pages               # Pages list
/site_admin/messages            # Messages/inbox
/site_admin/contacts            # Contacts
/site_admin/media               # Media library
/site_admin/website/settings    # Website settings
/site_admin/onboarding          # Setup wizard
```

---

## Related Documentation

- [../architecture/](../architecture/) - Overall system architecture
- [../deployment/](../deployment/) - Deployment guides
- [../seeding/](../seeding/) - Seed data documentation

---

*Last updated: 2025-12-31*
