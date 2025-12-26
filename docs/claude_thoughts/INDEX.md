# PropertyWebBuilder Property Model Documentation Index

## Overview

Complete exploration and analysis of the PropertyWebBuilder property (RealtyAsset) model architecture and existing import/export functionality, created December 26, 2024.

---

## Documentation Files

### Start Here

**[QUICKSTART.md](./QUICKSTART.md)** ⭐ **START HERE** (10 min read)
- 30-second summary of property model
- Essential file paths
- Field cheat sheets
- Code examples
- Common operations
- Debugging tips
- **Best for:** Quick reference and understanding the big picture

---

### Deep Dives

**[property_model_analysis.md](./property_model_analysis.md)** (60 min read, 500+ lines)
- Complete RealtyAsset model structure (section 1)
- SaleListing and RentalListing transaction models (sections 2-3)
- PropPhoto and Feature models (sections 4-5)
- ListedProperty materialized view (section 6)
- Related models (section 7)
- Database schema overview (section 8)
- Data relationships and constraints (section 9)
- Current import/export gaps (section 10)
- Implementation strategy for bulk import/export (section 11)
- File structure summary (section 12)
- Key implementation considerations (section 13)
- Summary table of all models (section 14)
- Next steps for implementation (section 15)
- **Best for:** Complete understanding of the architecture

**[property_files_reference.md](./property_files_reference.md)** (30 min read, 300+ lines)
- Critical files table (with line counts)
- Import/export services and utilities
- Controllers and related models
- Import configuration files
- Database migrations
- Key data structures and enumerables
- Field groups and classifications
- Import/export workflow elements
- Method signatures for implementation
- Database connection points
- Important constraints and validations
- Development checklist for bulk import
- **Best for:** Locating files and understanding method signatures

**[property_schema_diagram.md](./property_schema_diagram.md)** (40 min read, 400+ lines)
- ER diagram (ASCII art)
- Data flow diagrams (Create, Read, Update flows)
- Multi-tenancy scoping diagram
- Listing uniqueness constraints
- Internationalization (i18n) structure
- Complete database table structures (SQL-like)
- Import data structure mapping
- Key validation points
- Summary table of relationships
- **Best for:** Database schema understanding and visual diagrams

**[SUMMARY.md](./SUMMARY.md)** (15 min read, 300+ lines)
- Key findings summary
- Property model architecture overview
- RealtyAsset structure summary
- SaleListing & RentalListing overview
- PropPhoto model summary
- Feature model summary
- ListedProperty overview
- Existing import/export functionality status
- What's missing (gaps)
- Database schema overview
- Import/export strategy
- Files to reference (with paths)
- Key implementation tips
- Next steps for implementation
- **Best for:** Executive summary and implementation planning

---

## Quick Navigation

### If You Need To...

**Understand the property model architecture**
→ Start with QUICKSTART.md (10 min)
→ Then read property_model_analysis.md section 1 (20 min)

**Implement bulk import**
→ Read QUICKSTART.md examples (10 min)
→ Review property_files_reference.md sections (15 min)
→ Study property_model_analysis.md sections 11-13 (30 min)
→ Reference actual model files listed in property_files_reference.md

**Understand the database schema**
→ Read property_schema_diagram.md (40 min)
→ Reference SQL-like table structures (section 6)
→ Check ER diagram (section 1)

**Find a specific file**
→ Use property_files_reference.md "Critical Files" table
→ All paths are absolute and verified

**Understand data relationships**
→ Read property_schema_diagram.md sections 1-5
→ Check property_model_analysis.md section 9
→ Review QUICKSTART.md "Key Constraints & Rules"

**Get code examples**
→ QUICKSTART.md (simple examples)
→ property_files_reference.md method signatures
→ PropsController source code (/app/controllers/site_admin/props_controller.rb)

**Plan import/export implementation**
→ Read SUMMARY.md sections 4-7
→ Review property_model_analysis.md section 11
→ Check property_files_reference.md "Development Checklist"

---

## Document Statistics

| Document | Size | Lines | Read Time | Best For |
|----------|------|-------|-----------|----------|
| QUICKSTART.md | 10K | 300 | 10 min | Quick reference |
| property_model_analysis.md | 23K | 500+ | 60 min | Complete understanding |
| property_files_reference.md | 11K | 300+ | 30 min | File locations & signatures |
| property_schema_diagram.md | 27K | 400+ | 40 min | Database & diagrams |
| SUMMARY.md | 11K | 300+ | 15 min | Executive summary |
| **TOTAL** | **82K** | **1800+** | **155 min** | Complete reference |

---

## Key Content Areas

### 1. Models & Associations

**Core Models:**
- RealtyAsset (physical property) - 277 lines
- SaleListing (sale transaction) - 71 lines
- RentalListing (rental transaction) - 83 lines
- PropPhoto (images) - 40 lines
- Feature (amenities) - 44 lines
- ListedProperty (materialized view) - 243 lines

**Related Models:**
- Website (multi-tenant anchor)
- Address (location reference)
- FieldKey (feature definitions)

### 2. Services & Utilities

- ImportProperties (CSV/TSV parsing - INCOMPLETE)
- ImportMapper (field mapping orchestration)
- ImportSource (RETS source definitions)
- ImportMapping (JSON-based field mappings)
- ScraperMapping (scraper field mappings)

### 3. Controllers

- PropsController (CRUD operations, photo management)

### 4. Configuration

- `/config/import_mappings/api_pwb.json` - **RECOMMENDED FOR BULK IMPORT**
- `/config/import_mappings/mls_interealty.json`
- `/config/import_mappings/mls_mris.json`
- `/config/import_mappings/mls_csv_jon.json`
- `/config/import_mappings/mls_olr.json`

### 5. Database

- `pwb_realty_assets` - Physical property data
- `pwb_sale_listings` - Sale transactions
- `pwb_rental_listings` - Rental transactions
- `pwb_prop_photos` - Images
- `pwb_features` - Amenities
- `pwb_properties` - Materialized view (read-only, optimized)

---

## Key Findings Summary

### Architecture Highlights

✓ Normalized design with separate RealtyAsset + Listing models
✓ Supports both sale AND rental listings simultaneously
✓ Multi-tenant scoping via website_id
✓ Multi-locale support via Mobility gem (JSONB translations)
✓ Materialized view for optimized property search
✓ ActiveStorage for images + external URL support
✓ Feature-based amenity system with FieldKey definitions

### Import/Export Status

✗ ImportProperties service is incomplete (parsing only, no creation)
✗ No image download/attachment handling
✗ No feature import logic
✗ No transaction data (listing) creation
✗ No export functionality at all
✓ Field mapping system in place (ImportMapper, JSON configs)
✓ Multiple MLS format support configured

### Critical Implementation Gaps

1. No bulk property creation from CSV
2. No image handling for bulk imports
3. No feature/amenity import
4. No export service
5. No async job support for bulk operations
6. No progress tracking or error recovery
7. No UI for import/export forms
8. No duplicate detection/merge

---

## Implementation Roadmap

### Phase 1: Core Import (Extends Existing Code)
- Extend ImportProperties service
- Create PropertyBuilder for atomic creation
- Add image download/attach
- Handle features array
- Write comprehensive tests

### Phase 2: UI & Async
- Add import form controller actions
- Create Sidekiq/SolidQueue job
- Track progress
- Handle errors gracefully

### Phase 3: Export
- Create BulkExporter service
- Add export controller actions
- Support CSV/JSON formats

### Phase 4: Polish
- Duplicate detection
- Custom mapping UI
- Validation messages
- Comprehensive documentation

---

## Essential Code References

All absolute paths verified and working:

**Core Property Models:**
```
/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/realty_asset.rb
/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/sale_listing.rb
/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/rental_listing.rb
/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/prop_photo.rb
/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/feature.rb
/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/listed_property.rb
```

**Import Services:**
```
/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/import_properties.rb
/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/import_mapper.rb
```

**Controller Reference:**
```
/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/props_controller.rb
```

**Import Configs:**
```
/Users/etewiah/dev/sites-older/property_web_builder/config/import_mappings/api_pwb.json (BEST FOR BULK)
/Users/etewiah/dev/sites-older/property_web_builder/config/import_mappings/mls_olr.json
```

---

## Reading Guide by Role

### For Developers Implementing Bulk Import

1. QUICKSTART.md (10 min) - Get oriented
2. property_files_reference.md (30 min) - Know what exists
3. property_model_analysis.md sections 1, 11-13 (40 min) - Understand design
4. Code examples section of QUICKSTART.md (5 min)
5. Reference actual model files in /app/models/pwb/
6. **Total time:** ~90 minutes to get started

### For Architects Planning Feature

1. SUMMARY.md (15 min) - Executive overview
2. property_model_analysis.md sections 1-5 (30 min) - Understand current state
3. property_schema_diagram.md sections 1-3 (20 min) - Visual understanding
4. property_model_analysis.md sections 10-11 (30 min) - Understand gaps & strategy
5. property_files_reference.md development checklist (5 min)
6. **Total time:** ~100 minutes for comprehensive planning

### For Database Administrators

1. property_schema_diagram.md (entire document, 40 min)
2. property_model_analysis.md section 8 (20 min)
3. property_files_reference.md constraint section (10 min)
4. **Total time:** ~70 minutes for schema understanding

### For Project Managers/Product

1. SUMMARY.md sections 1-4 (15 min) - Current state
2. SUMMARY.md sections 8-10 (10 min) - What's missing & strategy
3. property_files_reference.md development checklist (5 min)
4. **Total time:** ~30 minutes for business context

---

## Key Takeaways

1. **Architecture:** PropertyWebBuilder uses normalized design with separate RealtyAsset + Listing models
2. **Technology:** Uses Mobility (i18n), Monetize (pricing), Scenic (views), ActiveStorage (images)
3. **Status:** Partial import infrastructure exists; full import/export needs to be built
4. **Complexity:** Moderate - existing models and services provide good foundation
5. **Dependencies:** Multi-tenancy, subscription limits, materialized view refresh
6. **Critical:** Use transactions for atomic operations, handle slug uniqueness, refresh views

---

## Document Revision History

- **Created:** December 26, 2024
- **Scope:** Complete property model architecture + import/export analysis
- **Coverage:** 6 core models, 3 services, 1 controller, 5 import configs, full database schema
- **Total Content:** 82KB, 1800+ lines across 5 documents
- **Status:** ✅ Complete and ready for implementation

---

## Contact/Questions

For clarification on any section:
1. Check the referenced source code files (all paths are absolute)
2. Read the related section in the comprehensive documents
3. Review code examples in QUICKSTART.md

All documentation is self-contained and cross-referenced.
