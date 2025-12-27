# Test Coverage Gap Analysis - PropertyWebBuilder

**Date:** December 2024  
**Scope:** Rails multi-tenant application covering critical business logic, seeding, and multi-tenancy isolation  
**Focus:** High-priority gaps impacting business logic and tenant isolation, not just coverage percentages

---

## Executive Summary

The test suite has **171 spec files** covering **~2,000+ test cases**, with good coverage of core domain models and API endpoints. However, significant gaps exist in:

1. **Recent Seeding Infrastructure** - New normalized seeding (seeder.rb, seed_runner.rb) has basic tests but lacks edge cases
2. **Controller Concerns** - SiteAdminIndexable and LocalizedSerializer have minimal integration tests
3. **Services** - 3 critical services without tests; several lack cross-tenant validation
4. **Models without Tests** - 9 key models including ImportSource, EmailTemplate, SubscriptionEvent
5. **Cross-Tenant Isolation** - While 30 files mention tenancy, only basic multi-tenancy tests exist
6. **ListingStateable Concern** - Complex state machine logic needs more edge case coverage

---

## What's Currently Tested Well ✓

### Models & Core Domain Logic
- **RealtyAsset** (229 lines of tests) - Physical property data, slug generation, feature management
- **ListedProperty** (462 lines of tests) - Materialized view queries, property filtering, materialization
- **SaleListing & RentalListing** - State transitions, active listing management, monetization
- **Tenant Scoping** - Website isolation, multi-tenancy uniqueness validation (3 dedicated specs)
- **User & Authorization** - User creation, membership associations, authentication
- **Agency & Contact** - Basic CRUD, website scoping
- **Page & Page Parts** - Rendering, translations, Liquid templates
- **Listings** - Visibility, archiving, pricing (good ListingStateable coverage)

### Controllers & Integration
- **API Controllers** - Property listing endpoints, pagination, serialization
- **Site Admin** - Basic controller actions, authorization checks
- **Public/Tenant Routes** - Welcome, search, browsing functionality
- **Jobs** - Notification job with proper scoping

### Business Logic
- **Search & Filtering** - Facets, location-based queries, state filtering
- **User Memberships** - Multi-role support, website associations
- **Firebase Auth** - Token verification, user provisioning
- **Rake Tasks** - Seed task execution, update workflows

---

## High-Priority Gaps to Address

### 1. **CRITICAL: Seeding Architecture (Seeder/SeedRunner) - Incomplete Edge Cases**

**File:** `lib/pwb/seeder.rb` (400+ LOC), `lib/pwb/seed_runner.rb` (350+ LOC)

**Current Test Coverage:**
- ✓ Basic seeding works (`spec/libraries/pwb/seeder_spec.rb` - 11 assertions)
- ✓ SeedRunner modes tested (`spec/lib/pwb/seed_runner_spec.rb` - 40 tests)
- ✓ Integration test (`spec/integration/seeding_integration_spec.rb`)

**Critical Gaps:**
- [ ] **Property normalization edge cases**: Seeder creates RealtyAsset + SaleListing/RentalListing (normalized schema). Missing tests:
  - What happens when seeding for website with >3 properties? (skip_properties logic)
  - Bilingual property title/description handling across locales
  - Photo attachment failure handling (external URLs vs local files)
  - Materialized view refresh failures post-property-create
  
- [ ] **Locale-specific filtering** (`filter_supported_locale_attrs`): No test coverage
  - Removing unsupported locale attributes before model creation
  - Behavior when YAML contains future languages
  
- [ ] **Transaction safety**: 
  - Rollback if property creation fails partway through
  - Orphaned photos when RealtyAsset creation fails
  
- [ ] **Seed file validation**:
  - Missing or malformed YAML files
  - Photo URL/file availability
  - Field key translation consistency
  
- [ ] **Multi-tenancy in seeding**:
  - ProvisioningService uses seed_properties_only! - never explicitly tested
  - Website association for user creation (website_id assignment)
  - Cross-website isolation during seeding

- [ ] **SeedRunner interactive mode**:
  - User choice between create-only/update-all modes is stubbed in tests
  - Actual TTY interaction never tested
  - Error handling when user presses Ctrl+C during seeding

**Recommendation:** Add 20-30 tests covering property normalization, locale handling, transaction rollback, and seed file validation.

---

### 2. **HIGH: Controller Concerns - Minimal Testing**

#### 2a. **SiteAdminIndexable** (`app/controllers/concerns/site_admin_indexable.rb`)

**Current Coverage:** `spec/controllers/concerns/site_admin_indexable_spec.rb` - 13 tests

**Gaps:**
- [ ] **Search functionality**: Only basic ILIKE search tested
  - Case-insensitive search edge cases
  - Special characters in search (SQL injection attempts)
  - Empty/whitespace-only searches
  - Performance with large result sets (limit behavior)

- [ ] **Scope isolation**:
  - Verify search is scoped to `current_website`
  - Cross-tenant query leakage? (Mock testing only, no integration test)
  
- [ ] **Collection name derivation**:
  - Pluralization of unusual model names
  - Namespaced models (Pwb::Contact should give `@contacts`)
  
- [ ] **Error handling**:
  - Invalid model_class in config
  - Missing required columns for search
  - Database errors during query

**Recommendation:** Add 8-10 integration tests with actual requests across multiple websites.

#### 2b. **LocalizedSerializer** (`app/controllers/concerns/localized_serializer.rb`)

**Current Coverage:** `spec/controllers/concerns/localized_serializer_spec.rb` - 12 tests

**Gaps:**
- [ ] **BASE_LOCALES consistency**: Tests mock object responses; never tests against real models with Mobility
  - Does serialize_translated_attributes work with SaleListing/RentalListing translations?
  - Nil vs empty string handling
  
- [ ] **Missing accessor handling**:
  - Object responds to some accessors but not others
  - Partial locale support (some locales filled, some empty)
  
- [ ] **Integration with API serialization**:
  - Used in API controllers but no controller-level tests
  - Real property serialization flow untested

**Recommendation:** Add 5-8 tests with real SaleListing/RentalListing objects using Mobility.

---

### 3. **HIGH: Services Without Tests (3 critical)**

#### 3a. **EmailTemplateRenderer** (`app/services/pwb/email_template_renderer.rb`)
- 200+ LOC with complex Liquid rendering logic
- **No tests**
- **Business impact:** Customer email notifications rely on this
- **Gaps:**
  - [ ] Default template rendering with variables
  - [ ] Custom template fallback logic
  - [ ] Liquid syntax error handling
  - [ ] HTML-to-text conversion edge cases (nested tags, entities)
  - [ ] Missing template graceful degradation
  - [ ] Locale-specific variable substitution

#### 3b. **MlsConnector** (`app/services/pwb/mls_connector.rb`)
- RETS client wrapper for MLS data
- **No tests**
- **Business impact:** Property import feature depends on this
- **Gaps:**
  - [ ] RETS client initialization
  - [ ] Query result parsing
  - [ ] Error handling (network failures, auth errors)
  - [ ] Photo retrieval (commented out but should be tested when enabled)

#### 3c. **SignupApiService** (`app/services/pwb/signup_api_service.rb`)
- External API client
- **No tests**
- **Business impact:** Tenant provisioning workflow
- **Gaps:**
  - [ ] API request/response handling
  - [ ] Timeout and retry logic
  - [ ] Error response parsing
  - [ ] Integration with ProvisioningService

**Recommendation:** Add 15-20 tests per service using VCR cassettes for external APIs.

---

### 4. **HIGH: Models Without Direct Test Files (9 models)**

While many are tested indirectly through associations, these lack dedicated test files:

| Model | LOC | Business Impact | Gap |
|-------|-----|-----------------|-----|
| **EmailTemplate** | ~150 | Customer notification customization | No validation tests, template_key enum not tested |
| **ImportSource** | ~50 | Property import configuration | ActiveHash data; no validation of details JSON |
| **ImportMapping** | ~100 | Field mapping for imports | Complex transformation logic untested |
| **SubscriptionEvent** | ~50 | Billing/notification events | Event creation/processing flow untested |
| **PresetStyle** | ~80 | Theme customization | Serialization/validation untested |
| **Property** | ~150 | Legacy Prop compatibility | Cross-model relationship untested |
| **ClientSetup** | ~100 | Multi-tenant configuration | Configuration validation untested |
| **Scraper** | - | Data import tool | Complete absence |

**Recommendation:** Create minimal specs for each (5-10 tests per model) covering validation and associations.

---

### 5. **HIGH: Cross-Tenant Isolation - Incomplete Coverage**

**Current Coverage:**
- ✓ 30 files mention multi-tenancy
- ✓ 3 dedicated multi-tenancy specs (agency, website, uniqueness)
- ✓ BasicSiteAdminController scope checks

**Gaps:**
- [ ] **Index/Search isolation**: SiteAdminIndexable tests don't verify cross-tenant data leakage
- [ ] **Service-level isolation**:
  - ImportProperties: Does it respect website scope?
  - SearchFacetsService: Cross-tenant facet leakage possible?
  - ProvisioningService: Seed data isolation during provisioning
  
- [ ] **Listing state machine across tenants**:
  - Can activate listing from tenant A affect tenant B?
  - Archive/unarchive isolation
  
- [ ] **Association scoping**:
  - Field keys website isolation (also tested in seeder)
  - Contact website isolation
  
- [ ] **Query scoping through Current.website**:
  - Prop queries in PublicWeb::PropsController - actually scoped?
  - API queries properly filtered?

**Recommendation:** Add 10-15 "negative tests" verifying data isolation; e.g., "User from Website A cannot see Website B's contacts."

---

### 6. **MEDIUM: ListingStateable Concern - State Machine Edge Cases**

**File:** `app/models/concerns/listing_stateable.rb`

**Current Coverage:** Tested in sale_listing_spec.rb & rental_listing_spec.rb - ~60 tests

**Gaps:**
- [ ] **Concurrent activation**: Two simultaneous requests activating different listings
- [ ] **Archiving an active listing**: Properly prevented via validation
- [ ] **Validation ordering**: active? validation with active_changed?
- [ ] **View refresh failure handling**: If ListedProperty.refresh fails, is it caught?
- [ ] **Database transaction rollback**: activate! transaction tested?
- [ ] **Scope chaining**: `.active_listing.visible.not_archived` combinations

**Recommendation:** Add 8-10 tests for concurrency, transaction safety, and complex scope chains.

---

### 7. **MEDIUM: Missing Integration Tests**

**What's missing:**
- [ ] **End-to-end property lifecycle**: Create RealtyAsset → Add SaleListing → Visibility toggle → Archive → Unarchive
- [ ] **Multi-property scenarios**: One website with 20 properties; search/filter/sort all work?
- [ ] **Import workflow**: Upload CSV → ImportProperties service → Listed property appears in frontend
- [ ] **Notification flow**: Message created → Email template rendered → Email sent → Tracked
- [ ] **Cross-browser/locale tests**: Search with French locale; results correct?

**Recommendation:** Add 5-10 integration tests covering complete user workflows.

---

## Test Coverage Summary by Area

| Area | Coverage | Priority |
|------|----------|----------|
| Models (Core Domain) | ~80% | ✓ Good |
| API Controllers | ~75% | ✓ Good |
| Site Admin Controllers | ~70% | ⚠️ Adequate |
| Controller Concerns | ~40% | 🔴 **Needs work** |
| Services | ~70% (missing 3) | 🔴 **Critical gaps** |
| Integration Tests | ~40% | ⚠️ Minimal |
| Multi-Tenancy Isolation | ~50% | 🔴 **High priority** |
| Seeding Infrastructure | ~60% | 🔴 **Edge cases missing** |
| Jobs & Tasks | ~80% | ✓ Good |
| Concerns & Mixins | ~45% | 🔴 **High priority** |

---

## Recommendations - Prioritized Action Plan

### Phase 1: Critical (1-2 weeks) - Do First
1. **Add EmailTemplateRenderer tests** (20 tests) - customer-facing feature
2. **Add email-related service tests** (MlsConnector, SignupApiService) - blocking external integrations
3. **Improve SiteAdminIndexable cross-tenant tests** (10 tests) - potential data leak
4. **Add property normalization edge case tests** (15 tests) - recent feature

### Phase 2: High Priority (2-3 weeks)
5. **Add test files for 9 untested models** (50 tests) - domain completeness
6. **Improve ListingStateable edge cases** (8 tests) - state safety
7. **Add cross-tenant isolation negative tests** (15 tests) - security
8. **Improve SeedRunner interactive mode testing** (10 tests) - manual operations

### Phase 3: Medium Priority (1 month)
9. **End-to-end integration tests** (10 tests) - user workflows
10. **Import workflow testing** (10 tests) - feature completeness
11. **LocalizedSerializer real model tests** (8 tests) - API correctness

---

## Key Recommendations

### 1. **Test New Seeding Infrastructure Thoroughly**
The normalized property schema (RealtyAsset + SaleListing/RentalListing) is recent and complex. Edge cases around:
- Transaction rollback on photo upload failure
- Locale-specific attribute filtering
- Materialized view refresh concurrency
- Should have comprehensive coverage before production use.

### 2. **Strengthen Multi-Tenancy Testing**
30 files mention tenancy, but integration-level isolation tests are sparse. Recommend:
- Parameterized tests that run same scenario across 2+ websites
- Negative tests verifying data isolation explicitly
- SQL query auditing (ensure WHERE website_id is present)

### 3. **Add Service Layer Tests**
Current service test coverage is ~70%, but 3 critical services have zero tests. Prioritize:
- EmailTemplateRenderer (customer impact)
- MlsConnector (integration point)
- SignupApiService (provisioning flow)

### 4. **Document Tenant Scoping Strategy**
Models are scoped via:
- `belongs_to :website` + `website_id` foreign key
- `ActsAsTenant` gem for automatic scoping
- `Pwb::Current.website` in controllers

Recommend documenting which models use each pattern and adding tests to verify it works end-to-end.

### 5. **Create Fast Subset of Tests**
Add tags to mark:
- `:unit` - No I/O, pure logic (~200ms)
- `:integration` - Database, external calls (~5s)
- `:slow` - VCR cassettes, API mocking (~20s)

This enables faster feedback loop during development.

---

## Notes for Test Authors

### Writing Tests for This App
1. **Multi-tenancy**: Always create test data with explicit `website_id`
2. **Seeding**: Mock external file I/O; use factories for happy path
3. **Services**: Use VCR cassettes for external APIs
4. **Listings**: Use `activate!` method, not direct `active = true`
5. **Materialized view**: Clear/refresh between tests if ListedProperty is involved

### Test Data Patterns
- Factories exist for all core models (in `spec/factories/`)
- Use `create(:pwb_website)` not raw SQL
- Scoped queries: always verify result is scoped to test website

---

## Related Files
- **Test suite root:** `/spec/`
- **Models:** `/app/models/pwb/`
- **Services:** `/app/services/pwb/`
- **Seeding:** `/lib/pwb/seeder.rb`, `/lib/pwb/seed_runner.rb`
- **Integration tests:** `/spec/integration/`

---

**Generated:** 2024-12-19  
**Last Updated:** See git log  
**Status:** Analysis complete; ready for implementation
