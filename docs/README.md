# PropertyWebBuilder Documentation

Welcome to the PropertyWebBuilder v2.0.0 documentation - a modern, open-source multi-tenant platform for creating real estate websites.

## What's New in v2.0.0

PropertyWebBuilder 2.0 is a major release representing 5 years of development:

- **Multi-Tenancy:** Host multiple websites from a single installation with `acts_as_tenant`
- **Dual Admin:** `site_admin` (super admin) and `tenant_admin` (per-tenant) interfaces
- **Modern Stack:** Rails 8, Tailwind CSS, Vue.js 3, Vite, ActiveStorage
- **New Property Model:** `RealtyAsset` with separate `SaleListing`/`RentalListing` records
- **Firebase Auth:** Optional Firebase authentication with Devise fallback
- **Seed Packs:** Scenario-based seeding for quick site setup

See the full [CHANGELOG](../CHANGELOG.md) for details.

## Quick Start

| I want to... | Go to... |
|--------------|----------|
| Set up development environment | [Development Guide](./DEVELOPMENT.md) |
| Understand the architecture | [Overview](./01_Overview.md) |
| Deploy the application | [Deployment Guides](#deployment) |
| Create a new theme | [Theming System](./11_Theming_System.md) |
| Write tests | [Testing Guide](./testing/README.md) |
| Understand multi-tenancy | [Multi-Tenancy Guide](./multi_tenancy/README.md) |
| Set up authentication | [Authentication Guide](./12_Authentication_Authorization.md) |
| Use seed packs | [Seeding Guide](./seeding/) |

---

## Core Documentation

These numbered guides provide a comprehensive walkthrough of the system:

| # | Document | Description |
|---|----------|-------------|
| 1 | [Overview](./01_Overview.md) | High-level architecture and main components |
| 2 | [Data Models](./02_Data_Models.md) | Database schema, models, and associations |
| 3 | [Controllers](./03_Controllers.md) | Controller actions and request handling |
| 4 | [API](./04_API.md) | RESTful and GraphQL API documentation |
| 5 | [Frontend](./05_Frontend.md) | Vue.js applications and UI components |
| 6 | [Multi-Tenancy](./06_Multi_Tenancy.md) | Multi-tenant architecture overview |
| 7 | [Assets Management](./07_Assets_Management.md) | Asset pipeline and file management |
| 8 | [PagePart System](./08_PagePart_System.md) | CMS content with Liquid templates |
| 9 | [Field Keys](./09_Field_Keys.md) | Property labeling and categorization |
| 10 | [Page Part Routes](./10_Page_Part_Routes.md) | Page part routing system |
| 11 | [Theming System](./11_Theming_System.md) | Theme creation and customization |
| 12 | [Authentication](./12_Authentication_Authorization.md) | Firebase and Devise authentication |

---

## Topic Guides

### Architecture

| Document | Description |
|----------|-------------|
| [Property Models](./architecture/ARCHITECTURE_PROPERTY_MODELS.md) | RealtyAsset, SaleListing, RentalListing design |
| [Property Models Quick Ref](./architecture/PROPERTY_MODELS_QUICK_REFERENCE.md) | Common patterns and queries |
| [Normalization Guide](./architecture/migrations/pwb_props_normalization.md) | Prop to RealtyAsset migration |

### Multi-Tenancy

| Document | Description |
|----------|-------------|
| [Overview](./multi_tenancy/README.md) | Start here for multi-tenancy |
| [Quick Reference](./multi_tenancy/MULTI_TENANCY_QUICK_REFERENCE.md) | Common patterns and gotchas |
| [Architecture](./multi_tenancy/MULTI_TENANCY_ARCHITECTURE.md) | Deep dive into implementation |
| [PwbTenant Models](./PWB_TENANT_MODELS.md) | Tenant-scoped model documentation |

### Themes & Styling

| Document | Description |
|----------|-------------|
| [Theme System](./THEME_SYSTEM.md) | How themes work |
| [Theme Creation Guide](./THEME_CREATION_GUIDE.md) | Step-by-step theme creation |
| [Semantic CSS Classes](./SEMANTIC_CSS_CLASSES.md) | CSS class conventions |
| [Tailwind Helpers](./TAILWIND_HELPERS.md) | Tailwind utility reference |

### Admin Panel

| Document | Description |
|----------|-------------|
| [Implementation Details](./admin/01_Implementation_Details.md) | Admin panel architecture |
| [Quasar Frontend](./admin/02_Quasar_Frontend_Implementation.md) | Vue.js 3 + Quasar setup |
| [Property Settings](./admin/properties_settings/README.md) | Property configuration UI |

### Quasar Framework

| Document | Description |
|----------|-------------|
| [Introduction](./quasar/introduction.md) | Getting started with Quasar |
| [API Integration](./quasar/api_integration.md) | Connecting to Rails backend |
| [GraphQL](./quasar/graphql.md) | GraphQL data fetching |
| [Deployment](./quasar/deployment.md) | Deploying the frontend |

### Testing

| Document | Description |
|----------|-------------|
| [Testing Guide](./testing/README.md) | Overview of testing approach |
| [E2E User Stories](./testing/E2E_USER_STORIES.md) | User stories for e2e tests |

### Seeding & Data

| Document | Description |
|----------|-------------|
| [Seeding Guide](./seeding/SEEDING_QUICK_REFERENCE.md) | Quick reference for seeding |
| [Seeding Architecture](./seeding/SEEDING_ARCHITECTURE.md) | How seeding works |
| [Seed Packs](./seeding/seed_packs_plan.md) | Seed pack system |

### Field Keys

| Document | Description |
|----------|-------------|
| [Field Keys Overview](./09_Field_Keys.md) | Property categorization system |
| [Search Implementation](./field_keys/field_key_search_implementation.md) | Using field keys in search |

---

## Deployment

PropertyWebBuilder can be deployed to multiple platforms:

### Recommended
- **[Render](./deployment/render.md)** - Easy deployment with free tier
- **[Dokku](./deployment/dokku.md)** - Self-hosted PaaS

### Other Platforms
- [Cloud66](./deployment/cloud66.md) | [Northflank](./deployment/northflank.md) | [Coherence](./deployment/withcoherence.md) | [Argonaut](./deployment/argonaut.md)
- [Koyeb](./deployment/koyeb.md) | [Qoddi](./deployment/qoddi.md) | [AlwaysData](./deployment/alwaysdata.md) | [DomCloud](./deployment/domcloud.md)

---

## Migration Guides

| Document | Description |
|----------|-------------|
| [Globalize to Mobility](./GLOBALIZE_TO_MOBILITY_MIGRATION.md) | I18n migration guide |
| [CarrierWave to ActiveStorage](./carrierwave_to_activestorage_migration.md) | File upload migration |
| [Multiple Listings](./MULTIPLE_LISTINGS.md) | Property listing architecture |

---

## Tech Stack

- **Backend**: Ruby on Rails 8.0, Ruby 3.4.7
- **Database**: PostgreSQL
- **Multi-Tenancy**: acts_as_tenant gem
- **Frontend**: Vue.js 3 with Quasar Framework (admin), Tailwind CSS (public themes)
- **Build Tool**: Vite with vite-plugin-ruby
- **APIs**: RESTful and GraphQL
- **Authentication**: Firebase ID Token + Devise
- **File Storage**: ActiveStorage with S3/Cloudflare R2
- **Translations**: Mobility gem
- **Maps**: Google Maps integration

## External Resources

- [GitHub Repository](https://github.com/etewiah/property_web_builder)
- [DeepWiki Docs](https://deepwiki.com/etewiah/property_web_builder)
- [Gitter Chat](https://gitter.im/property_web_builder/Lobby)

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/etewiah/property_web_builder/issues)
- **Contributing**: [CONTRIBUTING.md](../CONTRIBUTING.md)

---

## Internal Notes

The `claude_thoughts/` folder contains working documents and analysis from Claude AI sessions. These include:
- Architecture exploration findings
- Multi-tenancy analysis and recommendations
- E2E testing infrastructure analysis
- Migration planning documents

These documents provide valuable context but may be more detailed than typical user-facing documentation.

---

*Last Updated: December 2025*
