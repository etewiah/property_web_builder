# Claude Code Instructions for PropertyWebBuilder

This file contains instructions for Claude Code instances working on this project.

## Documentation Guidelines

**IMPORTANT: Never create documentation files at the project root.**

All documentation must be placed in the `docs/` folder structure:

- `docs/` - General project documentation
- `docs/architecture/` - Architecture decisions and system design
- `docs/seeding/` - Seed data and seed packs documentation
- `docs/multi_tenancy/` - Multi-tenancy related documentation
- `docs/claude_thoughts/` - Claude's research, analysis, and exploratory notes
- `docs/deployment/` - Deployment guides and configurations
- `docs/admin/` - Admin interface documentation
- `docs/field_keys/` - Field keys system documentation

### When to use `docs/claude_thoughts/`

Use this folder for:
- Exploratory research and analysis
- Architecture investigation findings
- Decision rationale documents
- Any temporary or working documents

### Standard documentation files at root (exceptions)

Only these markdown files should exist at the project root:
- `README.md` - Main project readme
- `README_*.md` - Translated readmes (es, ru, tr, etc.)
- `CHANGELOG.md` - Version changelog
- `CONTRIBUTING.md` - Contribution guidelines
- `CLAUDE.md` - This file (Claude instructions)

## Code Style

- Use Rails conventions
- Follow existing patterns in the codebase
- Prefer editing existing files over creating new ones
- Run tests before committing significant changes

## Multi-Tenancy

This is a multi-tenant application where each website is a tenant. Always:
- Scope queries to `current_website` or `Pwb::Current.website`
- Use `website_id` foreign keys for tenant-scoped models
- Test cross-tenant isolation in specs
