# PropertyWebBuilder Documentation

Welcome to PropertyWebBuilder's documentation. This folder contains guides and references for understanding and working with the multi-tenant real estate website platform.

## Quick Start

**New to the codebase?** Start with the numbered guides at the root:

1. **[01_Overview.md](./01_Overview.md)** - High-level system overview
2. **[02_Data_Models.md](./02_Data_Models.md)** - Database models and relationships
3. **[03_Controllers.md](./03_Controllers.md)** - Controller architecture
4. **[05_Frontend.md](./05_Frontend.md)** - Frontend technologies
5. **[07_Assets_Management.md](./07_Assets_Management.md)** - Asset pipeline

## Documentation by Topic

| Folder | Description |
|--------|-------------|
| **[admin/](./admin/)** | Admin interface and tenant management |
| **[api/](./api/)** | REST and GraphQL API documentation |
| **[architecture/](./architecture/)** | System architecture, page parts, property models |
| **[authentication/](./authentication/)** | Auth flows, Devise, OAuth, Firebase |
| **[branding/](./branding/)** | Brand guidelines and CSS variables |
| **[caching/](./caching/)** | Caching strategies and performance |
| **[deployment/](./deployment/)** | Deployment guides (Render, Dokku, etc.) |
| **[email/](./email/)** | Email system and multi-tenant email |
| **[field_keys/](./field_keys/)** | Field keys system for property customization |
| **[firebase/](./firebase/)** | Firebase setup and troubleshooting |
| **[migrations/](./migrations/)** | Major migration guides (Globalize, CarrierWave) |
| **[multi_tenancy/](./multi_tenancy/)** | Multi-tenant architecture and routing |
| **[provisioning/](./provisioning/)** | Website provisioning workflows |
| **[quasar/](./quasar/)** | Quasar admin frontend docs |
| **[seeding/](./seeding/)** | Seed packs and sample data |
| **[seo/](./seo/)** | SEO implementation and meta tags |
| **[signup/](./signup/)** | Self-service signup flow |
| **[testing/](./testing/)** | Testing guides (RSpec, Playwright) |
| **[theming/](./theming/)** | Theme system and Tailwind CSS |
| **[claude_thoughts/](./claude_thoughts/)** | Claude's research notes and analysis |

## Key References

- **[DEVELOPMENT.md](./DEVELOPMENT.md)** - Development setup guide
- **[CODE_REFERENCES.md](./CODE_REFERENCES.md)** - Code snippets with file paths

## Reading Guide by Role

### For Developers
1. Start with numbered guides (01-07)
2. Then explore [architecture/](./architecture/) for system design
3. Check [multi_tenancy/](./multi_tenancy/) for tenant isolation

### For DevOps/Infrastructure
1. [deployment/](./deployment/) - Platform-specific guides
2. [provisioning/](./provisioning/) - Website provisioning
3. [caching/](./caching/) - Performance optimization

### For Frontend Developers
1. [theming/](./theming/) - Theme system
2. [quasar/](./quasar/) - Admin frontend
3. [branding/](./branding/) - Design guidelines

## Quick Commands

### Create a New Website
```bash
rake pwb:db:create_tenant[subdomain]
```

### List All Websites
```bash
rake pwb:db:list_tenants
```

### Run Tests
```bash
bundle exec rspec
```

## File Structure

```
docs/
├── 01_Overview.md          # System overview
├── 02_Data_Models.md       # Database models
├── 03_Controllers.md       # Controllers
├── 05_Frontend.md          # Frontend
├── 07_Assets_Management.md # Assets
├── DEVELOPMENT.md          # Dev setup
├── CODE_REFERENCES.md      # Code snippets
│
├── admin/                  # Admin interface
├── api/                    # API docs
├── architecture/           # System design
├── authentication/         # Auth system
├── branding/              # Brand guidelines
├── caching/               # Performance
├── deployment/            # Deploy guides
├── email/                 # Email system
├── field_keys/            # Field customization
├── firebase/              # Firebase setup
├── migrations/            # Migration guides
├── multi_tenancy/         # Tenant isolation
├── provisioning/          # Website setup
├── quasar/                # Admin frontend
├── seeding/               # Seed data
├── seo/                   # SEO guides
├── signup/                # Signup flow
├── testing/               # Test guides
├── theming/               # Theme system
└── claude_thoughts/       # Research notes
```

## Last Updated

2024-12-21 - Reorganized documentation into topic-based subfolders
