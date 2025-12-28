# Test Coverage Gaps - Quick Reference

## At a Glance

**Total Gaps:** ~166 test scenarios across ~50 controllers/services
**Coverage:** ~50% of critical paths tested
**Priority Distribution:** P1=40%, P2=25%, P3=20%, P4=15%

---

## One-Page Priority List

### MUST HAVE (Do First)

```
1. Site Admin Dashboard
   File: app/controllers/site_admin/dashboard_controller.rb
   Gap: NO TESTS (15 scenarios)
   Impact: Main admin interface
   Effort: 2 hours
   
2. Contact Form Integration
   File: app/controllers/pwb/contact_us_controller.rb
   Gap: NO TESTS (12 scenarios)
   Impact: Lead generation
   Effort: 2.5 hours
   
3. Site Setup Flow
   File: app/controllers/pwb/setup_controller.rb
   Gap: NO TESTS (10 scenarios)
   Impact: Customer onboarding
   Effort: 2 hours
   
4. Analytics Dashboard
   File: app/controllers/site_admin/analytics_controller.rb
   Gap: NO TESTS (12 scenarios)
   Impact: Premium feature access
   Effort: 2.5 hours
   
5. Email Template System
   File: app/controllers/site_admin/email_templates_controller.rb
   Gap: NO TESTS (12 scenarios)
   Impact: Communications
   Effort: 2.5 hours
```

### SHOULD HAVE (Do Next)

```
6. Activity Logs
   Gap: NO TESTS (10 scenarios)
   Effort: 1.5 hours

7. Billing/Usage Display
   Gap: NO TESTS (6 scenarios)
   Effort: 1 hour

8. Tenant Subscriptions
   Gap: PARTIAL (10 scenarios)
   Effort: 2 hours

9. Tenant Plans Management
   Gap: NO TESTS (12 scenarios)
   Effort: 2 hours

10. Search Filtering
    Gap: NO TESTS (12 scenarios)
    Effort: 2 hours
```

### NICE TO HAVE (Do Eventually)

```
11. API Endpoints (5 gaps)
12. Service Layer Tests (8 gaps)
13. View/Template Tests (10 gaps)
14. Job Tests (5 gaps)
15. E2E Browser Tests (20+ scenarios)
```

---

## Quick Filing Guide

### By Directory

**spec/requests/site_admin/**
- [ ] dashboard_spec.rb (15 tests)
- [ ] analytics_spec.rb (12 tests)
- [ ] activity_logs_spec.rb (10 tests)
- [ ] email_templates_spec.rb (12 tests)
- [ ] billing_spec.rb (6 tests)
- [ ] contents_spec.rb (8 tests)

**spec/requests/tenant_admin/**
- [ ] subscriptions_comprehensive_spec.rb (10 tests)
- [ ] plans_spec.rb (12 tests)
- [ ] domains_spec.rb (8 tests)
- [ ] subdomains_spec.rb (8 tests)

**spec/requests/pwb/**
- [ ] setup_spec.rb (10 tests)
- [ ] contact_us_spec.rb (12 tests)
- [ ] property_filtering_spec.rb (12 tests)
- [ ] api/properties_spec.rb (8 tests)
- [ ] api/select_values_spec.rb (6 tests)
- [ ] api/mls_spec.rb (8 tests)

**spec/services/pwb/**
- [ ] email_template_renderer_spec.rb (8 tests)
- [ ] mls_connector_spec.rb (8 tests)

**spec/integration/**
- [ ] setup_flow_spec.rb (8 tests)
- [ ] contact_form_email_spec.rb (6 tests)
- [ ] multi_tenancy_comprehensive_spec.rb (10 tests)

---

## Controller Coverage Matrix

### site_admin Controllers

| Controller | Lines | Methods | Tests | Status |
|-----------|-------|---------|-------|--------|
| dashboard | 170 | 8 | 0 | **CRITICAL GAP** |
| analytics | 65 | 6 | 0 | **CRITICAL GAP** |
| onboarding | 285 | 15 | ~8 | Partial |
| billing | 20 | 2 | 0 | **GAP** |
| activity_logs | 45 | 2 | 0 | **GAP** |
| email_templates | 100 | 7 | 0 | **GAP** |
| contents | 8 | 0 | 0 | Minimal (uses concern) |
| agency | ? | ? | ? | Unknown |
| contacts | ? | ? | ? | Unknown |
| messages | ? | ? | ? | Unknown |
| pages | ? | ? | ? | Unknown |
| props | ? | ? | ? | Unknown |
| tour | 12 | 1 | 0 | Minor feature |
| domains | ? | ? | ? | Unknown |
| images | ? | ? | ? | Unknown |
| media_library | ? | ? | ? | Has tests |
| page_parts | ? | ? | ? | Unknown |
| users | ? | ? | ? | Unknown |
| storage_stats | ? | ? | ? | Unknown |
| property_import_export | ? | ? | ? | Has tests |

### tenant_admin Controllers

| Controller | Lines | Methods | Tests | Status |
|-----------|-------|---------|-------|--------|
| subscriptions | ~200 | 12 | ~6 | Partial |
| plans | ? | ? | 0 | **GAP** |
| domains | ? | ? | 0 | **GAP** |
| subdomains | ? | ? | 0 | **GAP** |
| dashboard | ? | ? | Has tests | OK |
| users | ? | ? | Has tests | OK |
| websites | ? | ? | Has tests | OK |
| props | ? | ? | Has tests | OK |
| agencies | ? | ? | ? | Unknown |
| contents | ? | ? | ? | Unknown |
| pages | ? | ? | ? | Unknown |
| page_parts | ? | ? | ? | Unknown |
| website_admins | ? | ? | ? | Unknown |
| email_templates | ? | ? | ? | Unknown |
| auth_audit_logs | ? | ? | ? | Unknown |

### pwb Controllers

| Controller | Tests | Status |
|-----------|-------|--------|
| setup | 0 | **CRITICAL GAP** |
| contact_us | 0 | **CRITICAL GAP** |
| search | Has tests | OK |
| props | Has tests | OK |
| pages | Has tests | OK |
| welcome | Has tests | OK |
| editor | Has tests | OK |
| firebase_login | Has tests | OK |
| theme_settings | Has tests | OK |
| auth | ? | Unknown |
| config | ? | Unknown |
| css | ? | Unknown |
| currencies | Has tests | OK |
| omniauth_callbacks | ? | Unknown |
| devise_sessions | Has tests | OK |
| devise_passwords | ? | Unknown |
| devise_registrations | ? | Unknown |
| signup | ? | Unknown |
| locked | Has tests | OK |
| tls | Has tests | OK |
| contact_us | 0 | **CRITICAL GAP** |
| api/\* | Partial | Some gaps |

---

## Data by Impact Level

### High Impact (Blocking Features)

```
FEATURE: Dashboard Statistics
Status: 0/1 tested
Controllers: dashboard_controller.rb
Services: None
Models: All stats models
Multi-tenancy: Critical
Risk: High (wrong data shown)
Est. Time: 2 hours, 15 tests

FEATURE: Contact Form
Status: 0/1 tested
Controllers: contact_us_controller.rb
Services: EnquiryMailer, NtfyNotificationJob
Models: Contact, Message
Multi-tenancy: Critical
Risk: High (lost leads)
Est. Time: 2.5 hours, 12 tests

FEATURE: Site Setup
Status: 0/1 tested
Controllers: setup_controller.rb
Services: ProvisioningService, SeedPack
Models: Website, Subdomain
Multi-tenancy: Critical
Risk: High (provisioning fails)
Est. Time: 2 hours, 10 tests

FEATURE: Analytics
Status: 0/1 tested
Controllers: analytics_controller.rb
Services: AnalyticsService
Models: Visit, Event
Multi-tenancy: Critical
Risk: High (premium feature)
Est. Time: 2.5 hours, 12 tests
```

### Medium Impact (Core Features)

```
FEATURE: Onboarding
Status: 50% (8/16 tests)
Gap: Integration flow, currency, state transitions
Est. Time: 1.5 hours, 8 tests

FEATURE: Subscriptions
Status: 60% (6/10 tests)
Gap: State machine transitions, plan changes
Est. Time: 2 hours, 10 tests

FEATURE: Email Templates
Status: 0% tested
Gap: Preview, validation, Liquid rendering
Est. Time: 2.5 hours, 12 tests

FEATURE: Search/Filtering
Status: 50% (services only)
Gap: Controller integration, UI parameters
Est. Time: 2 hours, 12 tests

FEATURE: Activity Logs
Status: 0% tested
Gap: All CRUD, filtering, isolation
Est. Time: 1.5 hours, 10 tests
```

### Lower Impact (Supporting Features)

```
FEATURE: API Endpoints (5 gaps)
FEATURE: Service Layer (8 gaps)
FEATURE: Templates/Views (10 gaps)
FEATURE: Jobs (5 gaps)
FEATURE: E2E Flows (20+ scenarios)
```

---

## Test Writing Checklist

For each test spec, verify:

### Controller Tests
- [ ] Happy path works
- [ ] Authorization enforced
- [ ] Multi-tenancy isolation
- [ ] Error handling
- [ ] Validation errors displayed
- [ ] Redirect/response correct
- [ ] Proper HTTP status codes

### Service Tests
- [ ] Main functionality works
- [ ] Error cases handled
- [ ] Validations enforced
- [ ] Edge cases covered
- [ ] External dependencies mocked

### Model Tests
- [ ] Validations work
- [ ] Associations correct
- [ ] Scopes return expected data
- [ ] State machine transitions valid
- [ ] Callbacks executed
- [ ] Multi-tenancy scoping enforced

### Integration Tests
- [ ] Full flow works end-to-end
- [ ] Data persists correctly
- [ ] Emails/notifications sent
- [ ] Async jobs triggered
- [ ] Side effects occur

---

## Estimated Effort

| Category | Tests | Hours | Status |
|----------|-------|-------|--------|
| P1 (Critical) | 82 | 14 | TODO |
| P2 (Important) | 48 | 9 | TODO |
| P3 (Nice to Have) | 26 | 5 | TODO |
| P4 (Polish) | 10 | 2 | TODO |
| **TOTAL** | **166** | **30** | |

---

## Definition of Done for Test Spec

A test spec is "done" when:

1. ✓ All scenarios from gap analysis covered
2. ✓ Both happy path and error paths tested
3. ✓ Multi-tenancy isolation verified
4. ✓ Authorization/authentication tested
5. ✓ All HTTP status codes verified
6. ✓ Database state verified
7. ✓ Associations/relationships tested
8. ✓ Edge cases handled
9. ✓ Code review approved
10. ✓ Tests pass locally and in CI

---

## Resource Links

**Documentation:** `/docs/testing/` (if exists)
**Guidelines:** Check CLAUDE.md for test practices
**Fixtures:** `/spec/factories/`
**Helpers:** `/spec/support/`

---

## Questions & Decisions

**Q: Should we test all controllers?**
A: No. Focus on P1/P2 first. Minimal features can skip testing.

**Q: How much E2E vs unit testing?**
A: 70% unit/integration, 30% E2E. Browser tests only for critical flows.

**Q: Should we add code coverage reporting?**
A: Yes. Add SimpleCov and set minimum 70% threshold for future code.

**Q: How to handle flaky tests?**
A: Use WebMock, Timecop, database transactions. Avoid real external calls.

**Q: Testing legacy code?**
A: Wrap in tests before refactoring. Incremental improvement OK.

---

## Last Updated

Analysis Date: 2025-12-28
Scope: PropertyWebBuilder Rails Application
Coverage Baseline: ~50% of critical paths
Next Review: After P1 tests complete
