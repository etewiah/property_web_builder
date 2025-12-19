# High-Priority Test Implementation Checklist

Copy this checklist into your project management system and track progress.

---

## Critical Phase (1-2 weeks) - DO FIRST

### ✓ Module 1: EmailTemplateRenderer Service Tests
- **File:** `spec/services/pwb/email_template_renderer_spec.rb` (NEW)
- **Target:** 20 tests
- **Effort:** 3-4 hours
- **Business Impact:** CRITICAL (customer notifications)

- [ ] Create spec file
- [ ] Test default template rendering (enquiry.general, enquiry.property, enquiry.auto_reply)
- [ ] Test alert templates (new_property, price_change)
- [ ] Test user templates (welcome, password_reset)
- [ ] Test variable substitution with missing variables
- [ ] Test Liquid syntax error handling
- [ ] Test HTML-to-text conversion (br, p, h1-h6, a tags)
- [ ] Test HTML entity conversion (&nbsp;, &amp;, &lt;, &gt;)
- [ ] Test custom template fallback
- [ ] Test locale-specific rendering
- [ ] Test website_name injection
- [ ] Test link click tracking variables (if applicable)
- [ ] Run: `bundle exec rspec spec/services/pwb/email_template_renderer_spec.rb`
- [ ] All green? ✓ Move to next module

### ✓ Module 2: MlsConnector Service Tests
- **File:** `spec/services/pwb/mls_connector_spec.rb` (NEW)
- **Target:** 15 tests
- **Effort:** 3-4 hours
- **Business Impact:** HIGH (property import feature)

- [ ] Create spec file
- [ ] Mock Rets::Client initialization
- [ ] Test RETS source handling
- [ ] Test RETS query execution
- [ ] Test response parsing
- [ ] Test unsupported source type error
- [ ] Test RETS auth failures
- [ ] Test RETS timeout handling
- [ ] Test malformed response handling
- [ ] Test photo retrieval (commented code)
- [ ] Test multiple connector instances
- [ ] Test query caching (if implemented)
- [ ] Run: `bundle exec rspec spec/services/pwb/mls_connector_spec.rb`
- [ ] All green? ✓ Move to next module

### ✓ Module 3: Seeding Normalization Edge Cases
- **File:** `spec/libraries/pwb/seeder_spec.rb` (EXTEND)
- **Target:** 15 new tests (in addition to existing 11)
- **Effort:** 4-5 hours
- **Business Impact:** CRITICAL (recent feature stability)

- [ ] Test RealtyAsset + SaleListing creation
- [ ] Test RealtyAsset + RentalListing creation
- [ ] Test both SaleListing AND RentalListing for same asset
- [ ] Test property with translations (title_en, title_es, description_en, description_es)
- [ ] Test photo attachment to RealtyAsset
- [ ] Test materialized view refresh triggered
- [ ] Test graceful error if RealtyAsset creation fails (partial transaction rollback)
- [ ] Test duplicate reference handling (skip if exists)
- [ ] Test locale filtering (remove unsupported locale attributes)
- [ ] Test nil/empty field handling
- [ ] Test price currency consistency
- [ ] Test listing visibility flags
- [ ] Test listing archive flags
- [ ] Test photo URL handling in test environment (should skip)
- [ ] Test photo file handling in test environment (should skip)
- [ ] Run: `bundle exec rspec spec/libraries/pwb/seeder_spec.rb`
- [ ] All green? ✓ Move to next module

### ✓ Module 4: SiteAdminIndexable Cross-Tenant Isolation Tests
- **File:** `spec/controllers/concerns/site_admin_indexable_spec.rb` (EXTEND)
- **Target:** 10 new integration tests
- **Effort:** 2-3 hours
- **Business Impact:** HIGH (data security/isolation)

- [ ] Create 2 test websites (tenant-a, tenant-b)
- [ ] Create test admin users for each
- [ ] Create test contacts for each website
- [ ] Test tenant A cannot see tenant B contacts in index
- [ ] Test search is scoped to current tenant
- [ ] Test pagination respects tenant scope
- [ ] Test order/limit respect scope
- [ ] Test show action rejects cross-tenant access (404)
- [ ] Test includes/joins don't leak data
- [ ] Test empty result set doesn't show other tenant's data
- [ ] Run: `bundle exec rspec spec/controllers/concerns/site_admin_indexable_spec.rb`
- [ ] All green? ✓ CRITICAL PHASE COMPLETE

---

## High-Priority Phase (2-3 weeks) - SECOND

### ✓ Module 5: Create Model Test Files (9 total)
- **Target:** 5-10 tests each, 45-50 total
- **Effort:** 4-6 hours

#### 5a. EmailTemplate
- **File:** `spec/models/pwb/email_template_spec.rb` (NEW)
- **Tests:**
  - [ ] Validates template_key presence
  - [ ] Validates website association
  - [ ] Validates subject present
  - [ ] Validates body_html present
  - [ ] find_for_website scope works
  - [ ] Can be customized per website

#### 5b. ImportSource
- **File:** `spec/models/pwb/import_source_spec.rb` (NEW)
- **Tests:**
  - [ ] Validates source_type presence
  - [ ] Validates details JSON structure
  - [ ] RETS source has required details
  - [ ] default_property_class used correctly

#### 5c. ImportMapping
- **File:** `spec/models/pwb/import_mapping_spec.rb` (NEW)
- **Tests:**
  - [ ] Belongs to import source
  - [ ] Validates field mapping
  - [ ] Transformation logic works
  - [ ] Value conversions correct

#### 5d. SubscriptionEvent
- **File:** `spec/models/pwb/subscription_event_spec.rb` (NEW)
- **Tests:**
  - [ ] Associates with subscription
  - [ ] event_type validated
  - [ ] payload JSONB handling
  - [ ] Timestamps recorded
  - [ ] Event tracking works

#### 5e. PresetStyle
- **File:** `spec/models/pwb/preset_style_spec.rb` (NEW)
- **Tests:**
  - [ ] Associates with theme
  - [ ] Serialization works
  - [ ] CSS generation works

#### 5f. Property (legacy compatibility)
- **File:** `spec/models/pwb/property_spec.rb` (NEW)
- **Tests:**
  - [ ] Legacy prop model compatibility
  - [ ] Associations with realty asset
  - [ ] Cross-model relationship integrity

#### 5g. ClientSetup
- **File:** `spec/models/pwb/client_setup_spec.rb` (NEW)
- **Tests:**
  - [ ] Configuration validation
  - [ ] Multi-tenant setup
  - [ ] Default configuration

#### 5h. ScraperMapping
- **File:** `spec/models/pwb/scraper_mapping_spec.rb` (NEW)
- **Tests:**
  - [ ] Xpath/CSS selector validation
  - [ ] Field extraction logic

#### 5i. ApplicationRecord
- **File:** `spec/models/pwb/application_record_spec.rb` (NEW)
- **Tests:**
  - [ ] Base model validations
  - [ ] Timestamp behavior

- [ ] Run: `bundle exec rspec spec/models/pwb/email_template_spec.rb` (test 1)
- [ ] Run: `bundle exec rspec spec/models/pwb/` (test all)
- [ ] All green? ✓ Move to next module

### ✓ Module 6: ListingStateable Edge Cases
- **File:** `spec/models/pwb/sale_listing_spec.rb` + `rental_listing_spec.rb` (EXTEND)
- **Target:** 8 new tests
- **Effort:** 2-3 hours

- [ ] Test activate! with transaction safety
- [ ] Test validation ordering with active? callbacks
- [ ] Test archive prevents active listing
- [ ] Test unarchive restores listing
- [ ] Test materialized view refresh failure handling
- [ ] Test scope chaining (.active_listing.visible.not_archived)
- [ ] Test can_destroy? checks
- [ ] Test concurrent activations
- [ ] Run: `bundle exec rspec spec/models/pwb/sale_listing_spec.rb`
- [ ] Run: `bundle exec rspec spec/models/pwb/rental_listing_spec.rb`
- [ ] All green? ✓ Move to next module

### ✓ Module 7: Cross-Tenant Isolation Negative Tests
- **File:** `spec/integration/cross_tenant_isolation_spec.rb` (NEW)
- **Target:** 10 tests
- **Effort:** 2-3 hours

- [ ] Create 2 websites
- [ ] Create users for each website
- [ ] Create properties for each website
- [ ] Test tenant A cannot query tenant B properties
- [ ] Test API endpoint scoped correctly
- [ ] Test search results don't leak
- [ ] Test show action rejects cross-tenant
- [ ] Test edit action rejects cross-tenant
- [ ] Test index lists only scoped records
- [ ] Test associations scoped properly
- [ ] Run: `bundle exec rspec spec/integration/cross_tenant_isolation_spec.rb`
- [ ] All green? ✓ Move to next module

### ✓ Module 8: LocalizedSerializer Real Model Tests
- **File:** `spec/controllers/concerns/localized_serializer_spec.rb` (EXTEND)
- **Target:** 5 new tests
- **Effort:** 1 hour

- [ ] Test with real SaleListing object
- [ ] Test with real RentalListing object
- [ ] Test Mobility translation accessors work
- [ ] Test missing translations return nil
- [ ] Test current_translation with I18n.locale
- [ ] Run: `bundle exec rspec spec/controllers/concerns/localized_serializer_spec.rb`
- [ ] All green? ✓ HIGH PRIORITY PHASE COMPLETE

---

## Medium-Priority Phase (1 month) - THEN

### Module 9: SignupApiService Tests
- **File:** `spec/services/pwb/signup_api_service_spec.rb` (NEW)
- **Target:** 15 tests
- **Effort:** 3-4 hours

- [ ] Test API client initialization
- [ ] Test provisioning request format
- [ ] Test response parsing
- [ ] Test timeout handling
- [ ] Test retry logic
- [ ] Test error response parsing
- [ ] Test integration with ProvisioningService

### Module 10: End-to-End Integration Tests
- **File:** `spec/integration/property_lifecycle_spec.rb` (NEW)
- **Target:** 10 tests
- **Effort:** 4-5 hours

Complete workflows:
- [ ] Create RealtyAsset → Add SaleListing → Publish → Archive
- [ ] Create property → Search finds it → Click through → See details
- [ ] Import properties → Listed → Search filters → Export
- [ ] Multi-property scenarios: sorting, pagination, filtering all work

### Module 11: Import Workflow Tests
- **File:** `spec/integration/import_workflow_spec.rb` (NEW)
- **Target:** 10 tests
- **Effort:** 4-5 hours

- [ ] Upload CSV → Import service processes → Properties appear
- [ ] MLS query → Connector retrieves → Properties imported
- [ ] Duplicate handling (update vs skip)
- [ ] Failure recovery (partial import)

---

## Verification Checklist

### After Each Module
- [ ] All new tests pass: `bundle exec rspec spec/...`
- [ ] No regressions: `bundle exec rspec` (full suite)
- [ ] No warnings or deprecations
- [ ] Code coverage improved (check with simplecov if enabled)

### After Critical Phase (4 modules)
- [ ] 85 new tests written
- [ ] All tests passing
- [ ] No regressions in existing tests
- [ ] Team agrees on test patterns
- [ ] PR merged with code review

### After High-Priority Phase (8 modules)
- [ ] 155+ new tests written total
- [ ] Critical business logic covered
- [ ] Cross-tenant isolation verified
- [ ] Services tested with mocks/VCR
- [ ] All controller concerns integration tested

### Final Verification
- [ ] Code coverage report generated
- [ ] Critical paths tested (user workflows)
- [ ] Edge cases documented
- [ ] Team trained on test patterns
- [ ] CI pipeline passing

---

## Test Running Commands

```bash
# Run critical phase tests
bundle exec rspec spec/services/pwb/email_template_renderer_spec.rb
bundle exec rspec spec/services/pwb/mls_connector_spec.rb
bundle exec rspec spec/libraries/pwb/seeder_spec.rb
bundle exec rspec spec/controllers/concerns/site_admin_indexable_spec.rb

# Run high-priority phase tests
bundle exec rspec spec/models/pwb/email_template_spec.rb
bundle exec rspec spec/models/pwb/rental_listing_spec.rb
bundle exec rspec spec/models/pwb/sale_listing_spec.rb
bundle exec rspec spec/integration/cross_tenant_isolation_spec.rb

# Run all tests
bundle exec rspec

# Run with coverage report
bundle exec rspec --format RspecJunitFormatter

# Run only fast unit tests
bundle exec rspec --tag :unit

# Watch for changes (if guard installed)
guard -i
```

---

## Notes

- **Target Completion:** 30-41 hours total work
- **Team Size:** Can be 1 developer working 2-3 weeks, or distributed across team
- **Blocking Issues:** None identified
- **Dependencies:** None
- **Risk Level:** Low (tests don't change production code)

---

## Sign-Off

- [ ] Tech Lead: Reviewed and approved implementation plan
- [ ] Developer: Understands scope and effort estimates
- [ ] Team: Aware of test patterns and expectations
- [ ] Scheduled: Added to sprint/roadmap

---

**Status:** Ready for implementation  
**Last Updated:** 2024-12-19  
**Next Review:** After Critical Phase completion
