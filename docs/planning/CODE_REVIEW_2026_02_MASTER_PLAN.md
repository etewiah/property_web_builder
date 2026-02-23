# Code Review — Master Improvement Plan

**Date:** 2026-02-21
**Reviewer:** Claude (Claude Code)
**Branch reviewed:** `develop`
**Scope:** Full codebase review — security, performance, code quality, testing, tech debt

---

## Executive Summary

PropertyWebBuilder is a mature, well-structured multi-tenant Rails 8.1 SaaS application. The core architecture is sound: solid multi-tenancy via `acts_as_tenant`, comprehensive test coverage, proper secrets management, and good database indexing. No critical vulnerabilities were found.

However, several medium-priority issues need addressing before the next major release, plus a body of tech debt that will slow down future development if not cleared systematically.

**Overall grade: B+**

---

## Issue Index

| # | Issue | Severity | Area | Planning Doc |
|---|-------|----------|------|--------------|
| S1 | Unauthenticated website creation via SetupController | 🔴 High | Security | [SECURITY_IMPROVEMENT_PLAN.md](../security/SECURITY_IMPROVEMENT_PLAN.md) |
| S2 | `Website.first` fallback silently serves wrong tenant | 🔴 High | Security | [SECURITY_IMPROVEMENT_PLAN.md](../security/SECURITY_IMPROVEMENT_PLAN.md) |
| S3 | `bypass_admin_auth?` not confirmed safe in production | 🟠 Medium | Security | [SECURITY_IMPROVEMENT_PLAN.md](../security/SECURITY_IMPROVEMENT_PLAN.md) |
| S4 | Liquid template injection risk (unverified) | 🟠 Medium | Security | [SECURITY_IMPROVEMENT_PLAN.md](../security/SECURITY_IMPROVEMENT_PLAN.md) |
| P1 | N+1: `Contact#unread_messages_count` in dashboard loops | 🟠 Medium | Performance | [N_PLUS_ONE_FIX_PLAN.md](../performance/N_PLUS_ONE_FIX_PLAN.md) |
| P2 | N+1: API auth uses Ruby `.find` on loaded integrations | 🟠 Medium | Performance | [N_PLUS_ONE_FIX_PLAN.md](../performance/N_PLUS_ONE_FIX_PLAN.md) |
| P3 | Missing composite indexes on high-traffic query patterns | 🟡 Low | Performance | [N_PLUS_ONE_FIX_PLAN.md](../performance/N_PLUS_ONE_FIX_PLAN.md) |
| P4 | Missing API cache-control headers | 🟡 Low | Performance | [N_PLUS_ONE_FIX_PLAN.md](../performance/N_PLUS_ONE_FIX_PLAN.md) |
| T1 | Tenant scoping via code comments instead of enforcement | 🟠 Medium | Tech Debt | [TECH_DEBT_PLAN.md](TECH_DEBT_PLAN.md) |
| T2 | `website.rb` is 650+ lines — needs decomposition | 🟡 Low | Tech Debt | [TECH_DEBT_PLAN.md](TECH_DEBT_PLAN.md) |
| T3 | Deprecated Vue.js and GraphQL directories still present | 🟡 Low | Tech Debt | [TECH_DEBT_PLAN.md](TECH_DEBT_PLAN.md) |
| T4 | Optional `belongs_to :website` creates scoping risks | 🟡 Low | Tech Debt | [TECH_DEBT_PLAN.md](TECH_DEBT_PLAN.md) |
| Q1 | Deprecated Capybara drivers in Gemfile | 🟡 Low | Testing | [TEST_IMPROVEMENT_PLAN.md](../testing/TEST_IMPROVEMENT_PLAN.md) |
| Q2 | Missing test: SetupController security | 🟠 Medium | Testing | [TEST_IMPROVEMENT_PLAN.md](../testing/TEST_IMPROVEMENT_PLAN.md) |
| Q3 | Missing test: N+1 regression coverage | 🟡 Low | Testing | [TEST_IMPROVEMENT_PLAN.md](../testing/TEST_IMPROVEMENT_PLAN.md) |
| Q4 | Missing test: Liquid template injection | 🟡 Low | Testing | [TEST_IMPROVEMENT_PLAN.md](../testing/TEST_IMPROVEMENT_PLAN.md) |

---

## Recommended Execution Order

### Sprint 1 — Safety (1–2 days)
Fix issues that could cause data exposure or abuse right now.

1. **S2** — Replace `Website.first` fallback with explicit error/404
2. **S3** — Audit and document `bypass_admin_auth?` production safety
3. **S1** — Add rate limiting to `SetupController` (rack-attack rule)

### Sprint 2 — Performance (1–2 days)
Fix the two confirmed N+1 issues with tests.

4. **P1** — Add `counter_cache` for `Contact#unread_messages_count`
5. **P2** — Replace Ruby `.find` block with SQL in API auth
6. **Q3** — Add Bullet-backed N+1 regression specs

### Sprint 3 — Security Hardening (2–3 days)
Audit and harden less certain risks.

7. **S4** — Audit Liquid template rendering for injection
8. **Q2** — Add security tests for SetupController
9. **P4** — Verify/add cache-control headers to public API endpoints

### Sprint 4 — Tech Debt Cleanup (2–4 days)
Clear accumulated debt to reduce future friction.

10. **Q1** — Remove deprecated `apparition`, `poltergeist`, `selenium-webdriver` from Gemfile
11. **T3** — Remove or properly archive `app/frontend/` and `app/graphql/`
12. **T1** — Convert comment-based tenant scoping to enforced `acts_as_tenant` associations
13. **T2** — Extract concerns from `website.rb`

### Sprint 5 — Index Tuning (0.5 days)
Low risk, measurable gain.

14. **P3** — Run EXPLAIN ANALYZE on key queries, add missing composite indexes

---

## What's Already Good — Do Not Change

These areas are well-implemented. Avoid touching them without strong reason:

- Multi-tenancy isolation: `acts_as_tenant` + comprehensive spec coverage
- Auth audit logging: `AuthAuditLog` model
- Database indexing: 378 indexes, GIN on JSONB, composite indexes
- Secrets management: Rails encrypted credentials, no hardcoded keys
- Background jobs: Solid Queue with rescue blocks
- Caching: Redis with namespace, compression, connection pooling
- Pagination: Pagy (correct, lightweight choice)
- Schema design: UUID PKs on listings, materialized view for reads
- API security: No SQL injection, no `permit!` calls, parameterized queries throughout

---

## Files Changed by Each Issue

See individual planning docs for exact file paths and line numbers.

| Planning Doc | Key Files Touched |
|---|---|
| SECURITY_IMPROVEMENT_PLAN.md | `app/controllers/pwb/application_controller.rb`, `app/controllers/pwb/setup_controller.rb`, `config/initializers/rack_attack.rb` |
| N_PLUS_ONE_FIX_PLAN.md | `app/models/pwb/contact.rb`, `app/controllers/api_manage/v1/base_controller.rb`, `db/migrate/` |
| TECH_DEBT_PLAN.md | `app/models/pwb/website.rb`, `Gemfile`, `app/frontend/`, `app/graphql/` |
| TEST_IMPROVEMENT_PLAN.md | `spec/requests/pwb/setup_controller_spec.rb`, `spec/models/pwb/contact_spec.rb` |
