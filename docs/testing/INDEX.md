# Playwright E2E Testing Documentation - Complete Index

## Documentation Overview

This folder contains comprehensive documentation for PropertyWebBuilder's Playwright E2E testing framework. The documentation has been organized into multiple files serving different purposes.

---

## NEW COMPREHENSIVE GUIDES (Created in this exploration)

### Core Documentation (Recommended Reading Order)

#### 1. [README.md](./README.md) - START HERE
**Size:** 12 KB | **Time:** 5-10 minutes

The main index and navigation guide for all testing documentation.

**Contains:**
- Quick navigation by use case
- Quick start TL;DR
- Test structure overview
- Test data reference
- Common test patterns
- Helper functions quick guide
- Debugging & troubleshooting
- Contribution guidelines

**Best for:** First-time users, quick orientation, navigation

---

#### 2. [playwright-e2e-overview.md](./playwright-e2e-overview.md) - COMPREHENSIVE REFERENCE
**Size:** 14 KB | **Time:** 20-30 minutes

Complete architectural overview of the Playwright E2E test structure.

**Contains:**
- Directory structure (all test locations)
- Configuration details (playwright.config.js)
- Environment setup instructions
- Test data fixtures (tenants, users, routes, properties)
- All 11 helper functions documented
- Global setup verification process
- 4 existing admin tests explained in detail
- Authentication patterns (normal + bypass modes)
- Multi-tenancy design and patterns
- Common test patterns with examples
- Comprehensive troubleshooting guide
- File locations quick reference
- Key takeaways and design principles

**Best for:** Understanding the complete architecture, deep learning, reference

---

#### 3. [playwright-quick-reference.md](./playwright-quick-reference.md) - QUICK LOOKUP
**Size:** 10 KB | **Time:** 5 minutes per lookup

Fast reference guide with cheat sheets and quick commands.

**Contains:**
- Quick start setup commands
- Test execution commands
- Test data constants (URLs, credentials, routes)
- Helper function cheat sheet (copy-paste ready)
- Test structure templates with code examples
- Common CSS selectors
- Environment variables reference
- Existing test suite overview (12 test files)
- Debugging tips and commands
- Common issues and solutions table
- Performance notes
- File locations quick map

**Best for:** During development, quick lookups, copy-paste templates

---

#### 4. [playwright-patterns.md](./playwright-patterns.md) - CODE EXAMPLES
**Size:** 20 KB | **Time:** Browse as needed

Detailed code examples and patterns for common testing scenarios.

**Contains 18 Pattern Examples:**
- Authentication Patterns (3)
  - Login and verify access
  - Verify access denied without login
  - Test login form validation
- Multi-Tenant Isolation Patterns (2)
  - Verify cross-tenant access denied
  - Verify settings are tenant-specific
- Admin Integration Test Patterns (3)
  - Admin setting changes appear on public site
  - Theme change applied to public site
  - Navigation visibility toggle
- Form Interaction Patterns (3)
  - Fill and submit form
  - Add new entry with modal
  - Edit and update entry
- Navigation and Page Structure Patterns (2)
  - Verify page has required sections
  - Navigation menu works
- Error Handling and Edge Cases (2)
  - Handle potential missing elements
  - Graceful fallback for assertions
- Performance and Optimization Patterns (2)
  - Reuse page state for multiple tests
  - Wait only when necessary

Each pattern includes:
- Explanation of when to use it
- Complete working code example
- Key implementation details
- Comments explaining the flow

**Best for:** Writing new tests, understanding patterns, copy-paste examples

---

#### 5. [EXPLORATION_SUMMARY.md](./EXPLORATION_SUMMARY.md) - COMPLETE FINDINGS
**Size:** 18 KB | **Time:** 20-30 minutes

Comprehensive summary of the complete exploration findings.

**Contains:**
- Executive summary
- Directory structure with annotations
- Configuration files detailed
- Fixtures and test data breakdown
- Global setup process
- Existing test suites documented (admin, auth, public)
- Authentication patterns explained
- Multi-tenancy support details
- Test execution commands
- Common test patterns (4 patterns shown)
- Key implementation details
- Database and seed data information
- File locations reference table
- Strengths of current setup
- Areas for potential enhancement
- Documentation created list
- Conclusion and next steps

**Best for:** Getting a complete picture, understanding design decisions, progress tracking

---

#### 6. [STRUCTURE_VISUAL_MAP.md](./STRUCTURE_VISUAL_MAP.md) - VISUAL REFERENCE
**Size:** 24 KB | **Time:** Reference as needed

Visual diagrams and maps of the test structure.

**Contains:**
- Complete directory and file hierarchy (ASCII tree)
- Test execution flow diagram
- Authentication and tenant flow diagrams
- Helper function usage map
- Test fixtures data structure
- Configuration and setup chain
- Test category overview
- Common test workflow diagram
- Deployment and CI/CD integration flow
- Port and network configuration
- Summary: Quick lookup by use case

**Best for:** Visual learners, system understanding, CI/CD setup

---

## EXISTING DOCUMENTATION (From Previous Work)

These files were already in the codebase and provide additional context:

### Additional Resources

- **E2E_TESTING_QUICK_START.md** (9.7 KB) - Earlier quick start guide
- **E2E_TESTING_SETUP.md** (17 KB) - Detailed setup guide
- **E2E_TESTING_SUMMARY.md** (12 KB) - Previous summary
- **E2E_TESTING.md** (11 KB) - General E2E testing info
- **E2E_USER_STORIES.md** (20 KB) - User story examples
- **PLAYWRIGHT_TESTING.md** (4 KB) - Overview

These provide supplementary information but the new comprehensive guides (above) are recommended as primary reference.

---

## Quick Navigation by Need

### I want to get started RIGHT NOW
1. Read: [README.md](./README.md) - Quick Start section (2 minutes)
2. Run: Commands in "Getting Started (Quick Steps)"
3. Run: `npx playwright test`

### I want to understand the architecture
1. Read: [playwright-e2e-overview.md](./playwright-e2e-overview.md) - Complete guide
2. Reference: [STRUCTURE_VISUAL_MAP.md](./STRUCTURE_VISUAL_MAP.md) - Visual diagrams
3. Explore: Actual test files in `tests/e2e/`

### I want to write a new test
1. Review: [playwright-patterns.md](./playwright-patterns.md) - Find similar pattern
2. Copy: Code example and adapt
3. Reference: [playwright-quick-reference.md](./playwright-quick-reference.md) - Cheat sheets
4. Debug: Use `npx playwright test --ui` if needed

### I'm debugging a failing test
1. Check: [playwright-quick-reference.md](./playwright-quick-reference.md) - Debugging Tips section
2. Run: `npx playwright test --debug` or `npx playwright test --ui`
3. View: HTML report with `npx playwright show-report`
4. Reference: [playwright-e2e-overview.md](./playwright-e2e-overview.md) - Troubleshooting section

### I want to understand tenant isolation
1. Read: [playwright-e2e-overview.md](./playwright-e2e-overview.md) - Multi-Tenancy section
2. Review: [playwright-patterns.md](./playwright-patterns.md) - Multi-Tenant Isolation Patterns
3. Look at: `tests/e2e/auth/admin_login.spec.js` - Real test examples

### I want to set up CI/CD
1. Read: [STRUCTURE_VISUAL_MAP.md](./STRUCTURE_VISUAL_MAP.md) - Deployment & CI/CD section
2. Reference: [playwright.config.js](../playwright.config.js) - Configuration
3. Reference: [lib/tasks/playwright.rake](../lib/tasks/playwright.rake) - Rails tasks

### I need to quickly look up something
1. Use: [playwright-quick-reference.md](./playwright-quick-reference.md) - Organized for quick lookup
2. Search: Ctrl+F for specific terms
3. Copy-paste: From relevant section

### I want to understand specific test files
1. Check: [README.md](./README.md) - Existing Test Suites section
2. Read: Actual test file in `tests/e2e/[category]/`
3. Reference: [playwright-patterns.md](./playwright-patterns.md) - Similar patterns

---

## File Organization

### Documentation Files Locations
```
docs/testing/
├── INDEX.md                          ← You are here
├── README.md                          ← Start here (main index)
├── playwright-e2e-overview.md        ← Comprehensive reference
├── playwright-quick-reference.md     ← Quick lookup/cheat sheets
├── playwright-patterns.md             ← Code examples (18 patterns)
├── EXPLORATION_SUMMARY.md            ← Complete findings
├── STRUCTURE_VISUAL_MAP.md           ← Visual diagrams
└── [Other files from previous work]  ← Supplementary
```

### Test Files Locations
```
tests/e2e/
├── global-setup.js                   ← Runs before tests
├── fixtures/
│   ├── test-data.js                  ← Tenants, users, routes
│   └── helpers.js                    ← 11 reusable helpers
├── admin/                            ← 3 admin test files
├── auth/                             ← 3 auth test files
└── public/                           ← 6 public test files
```

### Configuration Files Locations
```
playwright.config.js                  ← Main config
lib/tasks/playwright.rake             ← Rails tasks
```

---

## Quick Reference: Test Files Count

| Category | Files | Total Tests | Purpose |
|----------|-------|-------------|---------|
| Admin | 3 | ~166+ | Admin feature integration |
| Auth | 3 | ~15+ | Authentication & isolation |
| Public | 6 | ~50+ | Public site features |
| **Total** | **12** | **231+** | Complete test coverage |

---

## Quick Reference: Helper Functions

11 Reusable helpers available in `tests/e2e/fixtures/helpers.js`:

**Authentication (4):** loginAsAdmin, goToAdminPage, expectToBeLoggedIn, expectToBeOnLoginPage

**Navigation (2):** goToTenant, waitForPageLoad

**Forms (4):** fillField, getCsrfToken, submitFormWithCsrf, saveAndWait

**Content (1):** expectPageToHaveAnyContent

---

## Quick Reference: Test Data Constants

Available from `tests/e2e/fixtures/test-data.js`:

- **TENANTS:** Tenant A & B configuration (baseURL, subdomain, name)
- **ADMIN_USERS:** Login credentials for each tenant
- **ROUTES:** URL paths (home, admin pages, etc.)
- **PROPERTIES:** Sample property data

---

## Getting Started - 3 Commands

```bash
# 1. Reset E2E database
RAILS_ENV=e2e bin/rails playwright:reset

# 2. Start server
RAILS_ENV=e2e bin/rails playwright:server

# 3. Run tests (in another terminal)
npx playwright test
```

Then check results with:
```bash
npx playwright show-report
```

---

## Documentation Highlights

### What You'll Learn

**From README.md:**
- How to run tests quickly
- Navigation by use case
- Common patterns summary
- Troubleshooting quick tips

**From playwright-e2e-overview.md:**
- Complete system architecture
- All configuration details
- Helper functions reference
- Authentication modes explained
- Multi-tenancy design
- Troubleshooting comprehensive guide

**From playwright-quick-reference.md:**
- Cheat sheets for quick lookup
- Test structure templates
- Helper function recipes
- Common selectors
- Environment variables
- Existing test suite overview

**From playwright-patterns.md:**
- 18 complete code examples
- When to use each pattern
- Real implementation details
- Copy-paste ready code

**From EXPLORATION_SUMMARY.md:**
- Complete findings summary
- Architecture overview
- Design decisions explained
- Strengths and enhancement areas
- Complete context

**From STRUCTURE_VISUAL_MAP.md:**
- ASCII directory trees
- Flow diagrams
- Setup sequences
- Network configuration
- Visual reference maps

---

## Key Concepts Summary

### Two Authentication Modes

1. **Normal Mode** - Tests actual login
   ```bash
   RAILS_ENV=e2e bin/rails playwright:server
   ```
   Use for: auth tests, login verification

2. **Bypass Mode** - Skips admin login
   ```bash
   RAILS_ENV=e2e bin/rails playwright:server_bypass_auth
   ```
   Use for: integration tests (admin -> public)

### Multi-Tenancy

- **Two test tenants:** tenant-a, tenant-b
- **Separate credentials:** Each has own admin user
- **Subdomain isolation:** Sessions are subdomain-scoped
- **Test pattern:** Verify cross-tenant access is denied

### Test Categories

- **Admin Tests:** Verify settings changes apply to public site
- **Auth Tests:** Verify login, logout, cross-tenant isolation
- **Public Tests:** Verify public site functionality

### Architecture Pattern

1. **Fixtures** (test-data.js) - Centralized test data
2. **Helpers** (helpers.js) - Reusable functions
3. **Tests** - Use fixtures and helpers
4. **Global Setup** - Verify database exists

---

## Documentation Statistics

| Document | Size | Time | Purpose |
|----------|------|------|---------|
| README.md | 12 KB | 5-10m | Main index & navigation |
| playwright-e2e-overview.md | 14 KB | 20-30m | Comprehensive reference |
| playwright-quick-reference.md | 10 KB | 5m | Quick lookup/cheat sheets |
| playwright-patterns.md | 20 KB | Browse | 18 code examples |
| EXPLORATION_SUMMARY.md | 18 KB | 20-30m | Complete findings |
| STRUCTURE_VISUAL_MAP.md | 24 KB | Reference | Visual diagrams |
| **Total** | **98 KB** | **Varies** | Complete documentation |

---

## Recommended Reading Path

For different roles:

### Test Writer (New to codebase)
1. README.md (5 min)
2. playwright-patterns.md (browse relevant patterns, 10 min)
3. Start writing tests!

### Test Maintainer
1. playwright-e2e-overview.md (30 min)
2. STRUCTURE_VISUAL_MAP.md (15 min)
3. Review existing test files
4. Update as needed

### DevOps/CI Engineer
1. STRUCTURE_VISUAL_MAP.md - Deployment section (10 min)
2. playwright-e2e-overview.md - Configuration section (15 min)
3. Review playwright.config.js and playwright.rake (10 min)

### Architecture Review
1. EXPLORATION_SUMMARY.md (30 min)
2. playwright-e2e-overview.md (30 min)
3. STRUCTURE_VISUAL_MAP.md (15 min)

### Bug Investigator
1. playwright-quick-reference.md - Debugging section (5 min)
2. Run: `npx playwright test --ui`
3. Check: HTML report
4. Reference: Relevant pattern in playwright-patterns.md

---

## Creating New Tests - Checklist

When writing a new test:

- [ ] Choose correct directory (admin/auth/public)
- [ ] Import fixtures: `const { TENANTS, ADMIN_USERS, ROUTES } = require('../fixtures/test-data');`
- [ ] Import helpers: `const { loginAsAdmin, waitForPageLoad } = require('../fixtures/helpers');`
- [ ] Review similar pattern in playwright-patterns.md
- [ ] Use TENANTS for baseURL (not hardcoded)
- [ ] Use ROUTES for paths (not hardcoded)
- [ ] Use helpers for common tasks (not raw Playwright)
- [ ] Test tenant isolation if applicable
- [ ] Add comments explaining test purpose
- [ ] Run locally before committing
- [ ] Check: `npx playwright show-report`

---

## Troubleshooting Quick Guide

### Most Common Issues

| Issue | Solution |
|-------|----------|
| Tests won't run | Run `RAILS_ENV=e2e bin/rails playwright:reset` first |
| Auth bypass not working | Start server with `RAILS_ENV=e2e bin/rails playwright:server_bypass_auth` |
| Port 3001 in use | Kill process: `lsof -i :3001 \| kill -9 <PID>` |
| Can't find hostname | Add to `/etc/hosts`: `127.0.0.1 tenant-a.e2e.localhost` |
| Test failing | Use `npx playwright test --ui` to debug |
| Can't find test data | Import from `../fixtures/test-data.js` |
| Need to debug | Run `npx playwright test --debug` |

See [playwright-e2e-overview.md](./playwright-e2e-overview.md#troubleshooting) for comprehensive troubleshooting.

---

## Additional Resources

### Internal Documentation
- [Main README](../../README.md)
- [Architecture Documentation](../architecture/)
- [Multi-Tenancy Documentation](../multi_tenancy/)
- [Seed Data Documentation](../seeding/)

### External Resources
- [Playwright Official Docs](https://playwright.dev)
- [Playwright Test API](https://playwright.dev/docs/api/class-test)
- [Locator Guide](https://playwright.dev/docs/locators)

---

## Contributing & Updates

To update documentation:

1. Update relevant markdown file in `docs/testing/`
2. Keep examples up-to-date with code changes
3. Update this INDEX.md if adding new files
4. Cross-reference between documents

---

## Version History

**Created:** 2025-12-14

**Documentation Files Created:**
1. README.md - Main index
2. playwright-e2e-overview.md - Comprehensive reference
3. playwright-quick-reference.md - Quick lookup
4. playwright-patterns.md - Code examples (18 patterns)
5. EXPLORATION_SUMMARY.md - Complete findings
6. STRUCTURE_VISUAL_MAP.md - Visual diagrams
7. INDEX.md - This file

**Total Documentation Created:** 98 KB across 7 files

---

## Summary

PropertyWebBuilder has a **mature, well-organized Playwright E2E testing framework** with:

- 12 test spec files across 3 categories
- Centralized fixtures and reusable helpers
- Multi-tenant architecture support
- Two authentication modes (normal + bypass)
- Comprehensive documentation (now complete)

**Start here:** [README.md](./README.md) → Choose path based on your role

**Questions?** Consult the relevant documentation file from this index.

---

Last Updated: 2025-12-14
