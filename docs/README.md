# PropertyWebBuilder Documentation Index

Welcome to PropertyWebBuilder's comprehensive documentation. This folder contains detailed guides and references for understanding and working with the multi-tenant website provisioning system.

## Quick Start

**New to the codebase?** Start here:

1. **[EXPLORATION_SUMMARY.md](./EXPLORATION_SUMMARY.md)** - Executive summary of findings (20 min read)
2. **[PROVISIONING_QUICK_START.md](./PROVISIONING_QUICK_START.md)** - Practical commands and examples (15 min read)
3. **[CODE_REFERENCES.md](./CODE_REFERENCES.md)** - Actual code snippets with file paths (reference)

## Documentation Folders

### Core Topics (Organized)

| Folder | Description |
|--------|-------------|
| **[signup/](./signup/)** | Self-service signup flow (4-step wizard) |
| **[api/](./api/)** | REST and GraphQL API documentation |
| **[architecture/](./architecture/)** | System architecture and design decisions |
| **[multi_tenancy/](./multi_tenancy/)** | Multi-tenant isolation patterns |
| **[seeding/](./seeding/)** | Seed packs and sample data |
| **[admin/](./admin/)** | Admin interface documentation |
| **[deployment/](./deployment/)** | Deployment guides |

### General Documentation

- **[EXPLORATION_SUMMARY.md](./EXPLORATION_SUMMARY.md)** - Key findings from codebase exploration
- **[WEBSITE_PROVISIONING_OVERVIEW.md](./WEBSITE_PROVISIONING_OVERVIEW.md)** - Comprehensive technical reference
- **[PROVISIONING_QUICK_START.md](./PROVISIONING_QUICK_START.md)** - Quick command reference and setup guides
- **[CODE_REFERENCES.md](./CODE_REFERENCES.md)** - Code snippets with file paths

## Reading Guide by Role

### For Developers
1. Start: EXPLORATION_SUMMARY.md - Overview
2. Then: WEBSITE_PROVISIONING_OVERVIEW.md - Deep dive
3. Reference: CODE_REFERENCES.md - Specific code

### For DevOps/Infrastructure
1. Start: PROVISIONING_QUICK_START.md - Commands
2. Then: WEBSITE_PROVISIONING_OVERVIEW.md - Section 15 (Configuration)
3. Reference: CODE_REFERENCES.md - Environment variables

### For Product Managers
1. Start: EXPLORATION_SUMMARY.md - Overview
2. Then: PROVISIONING_QUICK_START.md - Capabilities
3. Reference: WEBSITE_PROVISIONING_OVERVIEW.md - Section 7 (Seeding)

### For QA/Testers
1. Start: PROVISIONING_QUICK_START.md - Testing section
2. Then: EXPLORATION_SUMMARY.md - System overview
3. Reference: WEBSITE_PROVISIONING_OVERVIEW.md - Validation section

## Key Topics

### Self-Service Signup (NEW)
- **[signup/](./signup/)** - Complete signup system documentation
  - [Flow documentation](./signup/01_flow.md) - Architecture and step-by-step details
  - [API reference](./signup/02_api_reference.md) - Endpoints and contracts
  - [Extraction guide](./signup/03_extraction_guide.md) - Component isolation
  - [Quick start](./signup/04_quick_start.md) - Debugging and reference

### API Documentation
- **[api/](./api/)** - REST and GraphQL APIs
  - [REST API](./api/01_rest_api.md) - Admin panel endpoints
  - [Signup API](./signup/02_api_reference.md) - Signup flow endpoints

### Website Provisioning
- Creating new websites: PROVISIONING_QUICK_START.md - "Create a New Website"
- Website configuration: WEBSITE_PROVISIONING_OVERVIEW.md - Section 1
- Database schema: WEBSITE_PROVISIONING_OVERVIEW.md - Section 12

### User Management
- User model: WEBSITE_PROVISIONING_OVERVIEW.md - Section 2
- Memberships: WEBSITE_PROVISIONING_OVERVIEW.md - Section 3
- Multi-website access: EXPLORATION_SUMMARY.md - Section 11

### Seeding
- Basic seeding: WEBSITE_PROVISIONING_OVERVIEW.md - Section 6.1
- Seed packs: WEBSITE_PROVISIONING_OVERVIEW.md - Section 6.2
- Seed runner: WEBSITE_PROVISIONING_OVERVIEW.md - Section 6.3
- Rake tasks: WEBSITE_PROVISIONING_OVERVIEW.md - Section 7

### Domains & Routing
- Subdomain routing: WEBSITE_PROVISIONING_OVERVIEW.md - Section 4
- Custom domains: WEBSITE_PROVISIONING_OVERVIEW.md - Section 4
- DNS verification: PROVISIONING_QUICK_START.md - "Add Custom Domain"

### Multi-Tenancy
- Architecture: WEBSITE_PROVISIONING_OVERVIEW.md - Section 11
- Isolation: EXPLORATION_SUMMARY.md - Section 12
- Data scoping: WEBSITE_PROVISIONING_OVERVIEW.md - Section 11

## Quick Command Reference

### Create a New Website
```bash
rake pwb:db:create_tenant[subdomain]
```
See: PROVISIONING_QUICK_START.md - "Quick Reference Commands"

### List All Websites
```bash
rake pwb:db:list_tenants
```

### Apply a Seed Pack
```ruby
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)
```

### Preview Changes (Dry Run)
```bash
DRY_RUN=true rake pwb:db:seed_enhanced
```

## File Structure

```
PropertyWebBuilder/
├── docs/
│   ├── README.md (this file)
│   ├── signup/                          # Signup system docs
│   │   ├── README.md
│   │   ├── 01_flow.md
│   │   ├── 02_api_reference.md
│   │   ├── 03_extraction_guide.md
│   │   └── 04_quick_start.md
│   ├── api/                             # API documentation
│   │   ├── README.md
│   │   └── 01_rest_api.md
│   ├── architecture/                    # Architecture docs
│   ├── multi_tenancy/                   # Multi-tenancy docs
│   ├── seeding/                         # Seed packs docs
│   ├── EXPLORATION_SUMMARY.md
│   ├── WEBSITE_PROVISIONING_OVERVIEW.md
│   ├── PROVISIONING_QUICK_START.md
│   └── CODE_REFERENCES.md
│
├── app/models/pwb/
│   ├── website.rb (Website model - 435 lines)
│   ├── user.rb (User model - 186 lines)
│   ├── user_membership.rb (Membership model - 57 lines)
│   └── current.rb (Request context - 5 lines)
│
├── lib/pwb/
│   ├── seeder.rb (Basic seeding - 476 lines)
│   ├── seed_pack.rb (Scenario seeding - 693 lines)
│   └── seed_runner.rb (Enhanced seeding - 549 lines)
│
├── lib/tasks/
│   └── pwb_tasks.rake (Provisioning tasks - 389 lines)
│
├── db/
│   ├── yml_seeds/ (YAML seed templates)
│   │   ├── website.yml
│   │   ├── agency.yml
│   │   ├── field_keys.yml
│   │   ├── links.yml
│   │   ├── users.yml
│   │   └── prop/ (property definitions)
│   │
│   ├── seeds/packs/ (Seed pack scenarios)
│   │   ├── base/
│   │   ├── spain_luxury/
│   │   └── netherlands_urban/
│   │
│   └── migrate/ (Database migrations)
│
└── CLAUDE.md (Project instructions)
```

## Key Statistics

| Metric | Value |
|--------|-------|
| Files Examined | 30+ |
| Code Lines Analyzed | 2,500+ |
| Models Referenced | 14+ |
| Key Insights | 50+ |
| Database Tables | 40+ |
| Rake Tasks | 10+ |
| Seed Packs | 3 |
| Documentation Pages | 4 |

## What's Covered

### System Components
- Website model with subdomain & custom domain routing
- User authentication (Devise + OAuth + Firebase)
- Multi-website memberships with role-based access
- Website configuration system (themes, locales, currencies)
- Property management (RealtyAsset + Listings model)
- Agency information & contact management
- Page builder with page parts
- Navigation/link management
- Field keys for property customization

### Seeding Approaches
- Basic one-time seeding
- Scenario-based seed packs
- Enhanced seeding with safety features
- Seed pack inheritance
- Property image handling
- Multi-language content seeding

### Provisioning Tools
- Rake tasks for website creation
- Bulk seeding operations
- Dry-run previewing
- Interactive mode
- Validation tools

### Multi-Tenancy
- Subdomain-based routing
- Custom domain support with DNS verification
- Request-scoped isolation
- Data scoping via website_id
- User access control

## Common Tasks

### Setup a New Website
See: PROVISIONING_QUICK_START.md - "Step-by-Step: Create a Real Estate Website"

### Configure Website Properties
See: PROVISIONING_QUICK_START.md - "Configuring Website Properties"

### Manage Users
See: PROVISIONING_QUICK_START.md - "User Management"

### Add Properties
See: PROVISIONING_QUICK_START.md - "Property Management"

### Debug Issues
See: PROVISIONING_QUICK_START.md - "Common Issues & Solutions"

## Troubleshooting

For common issues and solutions, see:
- PROVISIONING_QUICK_START.md - "Common Issues & Solutions" section
- WEBSITE_PROVISIONING_OVERVIEW.md - Section 14 (Constraints & Validations)

## Further Reading

### Related Files in Project
- `/CLAUDE.md` - Project guidelines and instructions
- `/app/models/pwb/` - Model implementations
- `/lib/pwb/` - Seeding and utility classes
- `/lib/tasks/` - Rake task definitions
- `/db/yml_seeds/` - Seed data templates
- `/db/seeds/packs/` - Scenario configurations
- `/db/migrate/` - Database migrations

### Key Concepts
- Multi-tenancy architecture
- SaaS website provisioning
- Role-based access control (RBAC)
- Seed pack pattern
- DNS domain verification
- Rails models and associations

## Questions & Answers

**Q: How do I create a new website?**  
A: `rake pwb:db:create_tenant[subdomain]` - See PROVISIONING_QUICK_START.md

**Q: Can users access multiple websites?**  
A: Yes, via UserMemberships. See WEBSITE_PROVISIONING_OVERVIEW.md - Section 3

**Q: How does routing work?**  
A: Via subdomain or custom domain. See WEBSITE_PROVISIONING_OVERVIEW.md - Section 4

**Q: What are seed packs?**  
A: Pre-configured scenario bundles. See WEBSITE_PROVISIONING_OVERVIEW.md - Section 6.2

**Q: How is multi-tenancy implemented?**  
A: Shared database with website_id scoping. See EXPLORATION_SUMMARY.md - Section 11

**Q: Where's the actual code?**  
A: See CODE_REFERENCES.md for file paths and snippets

## Document Metadata

| Document | Created | Size | Sections | Focus |
|----------|---------|------|----------|-------|
| EXPLORATION_SUMMARY.md | 2024-12-09 | ~50 KB | 17 | Overview |
| WEBSITE_PROVISIONING_OVERVIEW.md | 2024-12-09 | ~150 KB | 17 | Reference |
| PROVISIONING_QUICK_START.md | 2024-12-09 | ~80 KB | 15 | Practical |
| CODE_REFERENCES.md | 2024-12-09 | ~40 KB | 12 | Code snippets |

## Contributing to Documentation

If you improve or expand these docs:

1. Maintain the 17-section structure format
2. Use the established naming conventions
3. Include code snippets with file paths
4. Add to this index
5. Keep examples up-to-date

## Last Updated

2024-12-09 - Added self-service tenant provisioning workflow with AASM state machines

---

**Start reading:** [EXPLORATION_SUMMARY.md](./EXPLORATION_SUMMARY.md)
