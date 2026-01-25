# Claude Code Instructions for PropertyWebBuilder

This file contains instructions for Claude Code instances working on this project.

## Critical Rules

### Git Commit Safety

**NEVER commit changes you did not make in this session.**

**ALWAYS ask for user confirmation before committing.** Do not commit automatically. Show the user:
1. The files that will be committed
2. The proposed commit message
3. Wait for explicit approval (e.g., "yes", "ok", "commit it") before running `git commit`

Before committing:
1. Run `git status` to see ALL modified and untracked files
2. Identify which files YOU modified vs files that were already modified before your session
3. Only stage files YOU explicitly created or modified
4. If you see untracked files or modifications you didn't make, DO NOT add them

When staging files:
- Use specific file paths: `git add path/to/file.rb` instead of `git add .` or `git add -A`
- After staging, verify with `git diff --cached --stat` that only your changes are included
- If unsure, ask the user before committing

Common mistakes to avoid:
- Using `git add .` which adds ALL changes including other sessions' work
- Using `git add folder/` when other files in that folder were modified by someone else
- Not checking `git status` before committing

### No Direct Database Changes

**NEVER make direct database changes to fix issues.** All fixes must be made in code (seed files, migrations, rake tasks, etc.) that can be committed to git.

- If you modify database records directly (e.g., via `rails runner`, `rails console`, or any SQL), you have NOT fixed the issue
- Always find and edit the source files (seed YAML files, migrations, etc.) that populate the database
- If the only solution appears to be a direct database edit, you MUST explicitly ask for permission first and explain why a code-based solution isn't possible
- Never claim an issue is "fixed" when only database records were changed - such changes are lost on reseed/reset

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

## Frontend Architecture

**IMPORTANT: Vue.js is DEPRECATED. Do not use or extend Vue components.**

The frontend uses server-rendered pages:

- **ERB templates** - Standard Rails views (`app/views/`)
- **Liquid templates** - Dynamic page parts and theming (`app/themes/`)
- **Tailwind CSS** - All styling (no Bootstrap)
- **Stimulus.js** - For JavaScript interactions (preferred)

### Deprecated (Do Not Use)
- `app/frontend/` - Vue.js apps (see `app/frontend/DEPRECATED.md`)
- `app/graphql/` - GraphQL API (see `app/graphql/DEPRECATED.md`)
- Bootstrap CSS (see `vendor/assets/stylesheets/bootstrap/DEPRECATED.md`)

## Testing

### Browser/E2E Testing

**IMPORTANT: Use Playwright for all browser/E2E testing. Do NOT use Selenium or Capybara JS drivers.**

- **Playwright** is the preferred browser automation tool
- Use `container-use` environments to run Playwright tests in isolation
- Do NOT add Selenium WebDriver or Capybara JS drivers (apparition, poltergeist, etc.)

### Unit/Integration Testing

- Use RSpec for Ruby unit and integration tests
- Use FactoryBot for test data
- Feature specs should NOT use `js: true` - keep them as request/controller specs

### Running Playwright Tests

Use container-use to set up and run Playwright tests:
```bash
container-use create  # Create isolated environment
container-use run "npx playwright test"  # Run tests
```

## Multi-Tenancy

This is a multi-tenant application where each website is a tenant. Always:
- Scope queries to `current_website` or `Pwb::Current.website`
- Use `website_id` foreign keys for tenant-scoped models
- Test cross-tenant isolation in specs

## Container Use (Isolated Environments)

When using container-use for isolated development:

- ALWAYS use ONLY Environments for ANY and ALL file, code, or shell operations—NO EXCEPTIONS—even for simple or generic requests.
- DO NOT install or use the git CLI with the environment_run_cmd tool. All environment tools will handle git operations for you. Changing ".git" yourself will compromise the integrity of your environment.
- You MUST inform the user how to view your work using `container-use log <env_id>` AND `container-use checkout <env_id>`. Failure to do this will make your work inaccessible to others.
