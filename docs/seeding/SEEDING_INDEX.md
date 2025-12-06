# PropertyWebBuilder Seeding Documentation Index

## Overview

This directory contains comprehensive documentation of the PropertyWebBuilder seeding architecture, including how seed data is structured, loaded, and managed across multiple languages and tenants.

---

## Documentation Files

### 1. **SEEDING_SUMMARY.md** - Start Here!
**Best for**: Quick visual understanding of the architecture
- Visual diagrams of the seeding flow
- Component breakdown with ASCII diagrams
- Key concepts explained visually
- Quick stats and common tasks
- ~400 lines, very readable

### 2. **SEEDING_ARCHITECTURE.md** - Deep Dive
**Best for**: Complete understanding of every component
- Detailed explanation of all 9 major components
- Complete file directory structure
- Translation system explained in depth
- YAML file format documentation
- Property data models explained
- E2E testing setup details
- Factory patterns documented
- Multi-tenancy patterns
- ~600 lines, comprehensive reference

### 3. **SEEDING_QUICK_REFERENCE.md** - Hands-On
**Best for**: Quick lookup while coding
- Command reference
- Code snippets for common tasks
- Component cheat sheet
- Locale reference table
- Factory patterns with examples
- Common pitfalls and solutions
- ~350 lines, practical guide

---

## Quick Navigation by Topic

### Getting Started
- Want to understand the system? → Read **SEEDING_SUMMARY.md**
- Need to seed your first database? → See "Quick Commands" in **SEEDING_QUICK_REFERENCE.md**
- Want complete implementation details? → Study **SEEDING_ARCHITECTURE.md**

### Specific Topics

#### Seeding Data
- How seeding works: SEEDING_SUMMARY.md → "Data Seeding Flow" section
- Seeder classes: SEEDING_ARCHITECTURE.md → "Main Seeder Classes"
- Commands: SEEDING_QUICK_REFERENCE.md → "Quick Commands"

#### Languages & Locales
- Supported languages: SEEDING_SUMMARY.md → "Language & Translation System"
- Complete locale config: SEEDING_ARCHITECTURE.md → "Locale & Language Configuration"
- Translation file examples: SEEDING_ARCHITECTURE.md → "YAML Seed Files"

#### Property Management
- Data model: SEEDING_SUMMARY.md → "Property Data Model"
- Complete documentation: SEEDING_ARCHITECTURE.md → "Property Data Models"
- Property YAML format: SEEDING_ARCHITECTURE.md → "Property YAML" under "YAML Seed Files"

#### Multi-Tenancy
- Overview: SEEDING_SUMMARY.md → "Multi-Tenancy Pattern"
- Complete explanation: SEEDING_ARCHITECTURE.md → "Multi-tenancy Support" throughout
- Example code: SEEDING_QUICK_REFERENCE.md → "Common Seeding Scenarios"

#### Testing with FactoryBot
- Overview: SEEDING_SUMMARY.md → "Test Data with FactoryBot"
- Detailed guide: SEEDING_ARCHITECTURE.md → "Factory Patterns"
- Code examples: SEEDING_QUICK_REFERENCE.md → "Factory Patterns for Testing"

#### E2E Testing
- Quick overview: SEEDING_SUMMARY.md → "E2E Test Setup"
- Complete details: SEEDING_ARCHITECTURE.md → "E2E Testing Seeds"
- Usage: SEEDING_QUICK_REFERENCE.md → "E2E Test Data Structure"

---

## File Structure Reference

```
PROJECT ROOT
├── SEEDING_INDEX.md ............................ This file
├── SEEDING_SUMMARY.md .......................... Visual overview
├── SEEDING_ARCHITECTURE.md ..................... Complete reference
├── SEEDING_QUICK_REFERENCE.md ................. Practical guide
│
├── db/
│   ├── seeds/ ................................. Ruby seed files
│   │   ├── e2e_seeds.rb ........................ E2E test setup
│   │   ├── translations_*.rb (15 files) ....... Language translations
│   │   ├── spain/ .............................. Region-specific seeds
│   │   └── images/ ............................. Property seed images
│   │
│   └── yml_seeds/ .............................. YAML configuration
│       ├── agency.yml
│       ├── website.yml
│       ├── users.yml
│       ├── contacts.yml
│       ├── field_keys.yml
│       ├── links.yml
│       ├── pages/ .............................. Page definitions
│       ├── page_parts/ ......................... Page components
│       ├── content_translations/ .............. Page content (14 locales)
│       ├── prop/ ............................... Standard properties
│       └── prop_spain/ ......................... Region-specific properties
│
├── lib/pwb/
│   ├── seeder.rb .............................. Main seeder
│   ├── pages_seeder.rb ........................ Page seeding
│   └── contents_seeder.rb ..................... Content seeding
│
├── spec/
│   └── factories/ ............................. Test data factories
│       ├── pwb_websites.rb
│       ├── pwb_realty_assets.rb
│       ├── pwb_sale_listings.rb
│       └── ... (19 more factory files)
│
└── config/
    └── initializers/
        ├── i18n_globalise.rb ................. Locale configuration
        ├── i18n_backend.rb ................... I18n backend setup
        └── mobility.rb ....................... Translation storage
```

---

## Key Concepts at a Glance

| Concept | What It Is | Where to Learn |
|---------|-----------|-----------------|
| **Seeding** | Initializing database with sample data | SEEDING_SUMMARY.md |
| **Multi-tenancy** | Multiple websites with isolated data | SEEDING_ARCHITECTURE.md |
| **RealtyAsset** | Physical property data (immutable) | SEEDING_ARCHITECTURE.md → Property Models |
| **SaleListing** | Sale-specific data (editable) + translations | SEEDING_ARCHITECTURE.md → Property Models |
| **Materialized View** | Read-only optimized query view | SEEDING_ARCHITECTURE.md → Property Models |
| **I18n** | Field key translations (15 languages) | SEEDING_ARCHITECTURE.md → Locale Config |
| **Mobility** | Listing title/description translations | SEEDING_ARCHITECTURE.md → Locale Config |
| **FactoryBot** | Test data builder with traits | SEEDING_ARCHITECTURE.md → Factory Patterns |
| **E2E Seeds** | Complete test environment setup | SEEDING_ARCHITECTURE.md → E2E Testing |
| **Field Keys** | Property taxonomy (types, states, features) | SEEDING_ARCHITECTURE.md → Translation Seeds |

---

## Common Questions

### "How do I seed a new tenant?"
See: SEEDING_QUICK_REFERENCE.md → "Common Seeding Scenarios" → "Add new tenant with complete setup"

### "What languages are supported?"
See: SEEDING_SUMMARY.md → "Language & Translation System" or SEEDING_QUICK_REFERENCE.md → "Supported Languages"

### "How do I create test data?"
See: SEEDING_QUICK_REFERENCE.md → "Factory Patterns for Testing"

### "What's the difference between RealtyAsset and Listing?"
See: SEEDING_SUMMARY.md → "Property Data Model" or SEEDING_ARCHITECTURE.md → "Property Data Models"

### "How does multi-tenancy work?"
See: SEEDING_ARCHITECTURE.md → "Multi-tenancy Support" throughout or SEEDING_SUMMARY.md → "Multi-Tenancy Pattern"

### "What are the seeder classes?"
See: SEEDING_ARCHITECTURE.md → "Main Seeder Classes" (3 classes documented)

### "How do I set up E2E testing?"
See: SEEDING_ARCHITECTURE.md → "E2E Testing Seeds" or SEEDING_QUICK_REFERENCE.md → "E2E Test Data Structure"

### "What's a materialized view?"
See: SEEDING_ARCHITECTURE.md → "Property Data Models" → "ListedProperty"

### "How does the translation system work?"
See: SEEDING_SUMMARY.md → "Language & Translation System" with diagram

### "Where are the seed files?"
See: SEEDING_ARCHITECTURE.md → "Directory Structure" section

---

## Document Usage Guide

### For Visual Learners
1. Read **SEEDING_SUMMARY.md** first
2. Look at the ASCII diagrams
3. Refer to **SEEDING_ARCHITECTURE.md** for details
4. Use **SEEDING_QUICK_REFERENCE.md** for code examples

### For Hands-On Learners
1. Start with **SEEDING_QUICK_REFERENCE.md** → "Quick Commands"
2. Try commands in Rails console
3. Read **SEEDING_ARCHITECTURE.md** when you need to understand why
4. Use **SEEDING_SUMMARY.md** for big-picture context

### For Academic/Complete Understanding
1. Read **SEEDING_ARCHITECTURE.md** completely
2. Study the file structure
3. Review source code in `lib/pwb/` and `spec/factories/`
4. Use **SEEDING_SUMMARY.md** for visualization
5. Use **SEEDING_QUICK_REFERENCE.md** for command reference

### For Debugging Seeding Issues
1. Consult **SEEDING_QUICK_REFERENCE.md** → "Important Gotchas"
2. See "Debugging Seeding" section
3. Check **SEEDING_ARCHITECTURE.md** for component details
4. Review relevant seeder class in `lib/pwb/`

---

## File Statistics

| Document | Lines | Best For | Reading Time |
|----------|-------|----------|--------------|
| SEEDING_INDEX.md | ~300 | Navigation, overview | 15 min |
| SEEDING_SUMMARY.md | ~400 | Visual learners, quick understanding | 20 min |
| SEEDING_ARCHITECTURE.md | ~600 | Complete reference, implementation details | 45 min |
| SEEDING_QUICK_REFERENCE.md | ~350 | Practical use, code examples, commands | 25 min |

**Total documentation**: ~1,650 lines providing comprehensive coverage of the seeding system.

---

## Key Source Files

| File | Purpose | Lines | Section |
|------|---------|-------|---------|
| `lib/pwb/seeder.rb` | Main seeding orchestrator | 476 | SEEDING_ARCHITECTURE.md → Seeder Classes |
| `lib/pwb/pages_seeder.rb` | Page structure seeding | 114 | SEEDING_ARCHITECTURE.md → Seeder Classes |
| `lib/pwb/contents_seeder.rb` | Page content seeding | 99 | SEEDING_ARCHITECTURE.md → Seeder Classes |
| `db/seeds/e2e_seeds.rb` | E2E test setup | 670 | SEEDING_ARCHITECTURE.md → E2E Testing |
| `db/seeds/translations_en.rb` | English translations | 3,500+ | SEEDING_ARCHITECTURE.md → Translation Seeds |
| `db/yml_seeds/field_keys.yml` | Property taxonomy | 389 | SEEDING_ARCHITECTURE.md → YAML Files |
| `spec/factories/` | Test factories (22 files) | 1,000+ | SEEDING_ARCHITECTURE.md → Factory Patterns |

---

## Learning Path

### Beginner (30 minutes)
1. Read SEEDING_SUMMARY.md
2. Skim SEEDING_QUICK_REFERENCE.md → "Quick Commands" & "Supported Languages"
3. Try: `bin/rails app:pwb:db:seed`

### Intermediate (2 hours)
1. Read SEEDING_ARCHITECTURE.md (skip deep technical sections)
2. Study file structure in db/yml_seeds/
3. Review a YAML seed file (e.g., website.yml)
4. Try: Create a seeded database and explore
5. Read SEEDING_QUICK_REFERENCE.md → "Common Seeding Scenarios"
6. Try: Seed a test website programmatically

### Advanced (4+ hours)
1. Read all documentation completely
2. Study source code in lib/pwb/
3. Review spec/factories/ implementations
4. Understand I18n backend chain
5. Study Mobility configuration
6. Implement custom seeding for your use case

---

## Related Documentation

Also see:
- **docs/09_Field_Keys.md** - Detailed property taxonomy documentation
- **Rails Guides** - I18n & Database seeding
- **Mobility Gem Docs** - Translation storage system
- **FactoryBot Docs** - Test data building
- **Globalize Gem Docs** - Translations (legacy, some still used)

---

## Quick Links

### Essential Files
- Main seeder: `/lib/pwb/seeder.rb`
- YAML configs: `/db/yml_seeds/`
- Test factories: `/spec/factories/`

### Key Classes
- `Pwb::Seeder` - Main orchestrator
- `Pwb::PagesSeeder` - Page structure
- `Pwb::ContentsSeeder` - Page content
- `Pwb::RealtyAsset` - Property model
- `Pwb::SaleListing` - Sale listing
- `Pwb::RentalListing` - Rental listing

### Commands
```bash
bin/rails app:pwb:db:seed                    # Seed database
RAILS_ENV=e2e bin/rails db:seed             # E2E test setup
bin/rails pwb:db:update_page_parts          # Update page parts
rails console                                # Interactive seeding
```

---

## Feedback & Questions

If you find information missing or unclear:
1. Check if another documentation file covers it
2. Review the source code in lib/pwb/
3. Look for examples in spec/factories/
4. Examine YAML files in db/yml_seeds/

---

**Last Updated**: December 5, 2024
**Documentation Status**: Complete and Comprehensive
**Seeding System Status**: Production-Ready
