# PropertyWebBuilder: Quick Improvement Checklist

A prioritized action list extracted from the comprehensive codebase analysis.

## Critical Issues (Fix Immediately)

### [ ] Remove Debug Statements
**Status:** 42 debug statements found (byebug, binding.pry)
**Files:** 10+ model files
**Effort:** 1-2 hours
**Command:** `grep -r "byebug\|binding.pry" app --include="*.rb" -n`

### [ ] Review BYPASS_ADMIN_AUTH Usage
**Status:** Dev-only safety feature, document clearly
**Risk:** Could be accidentally enabled in production
**Files:** `SiteAdminController`, `TenantAdminController`
**Action:** Add environment-specific warnings in logs

## High Priority (Next Sprint)

### [ ] Implement Role-Based Access Control (RBAC)
**Current Gap:** All admins have equal permissions
**Missing Roles:** 
- Admin (full access)
- Editor (manage properties, pages)
- Viewer (read-only)
- Support Agent (manage tickets)

**Implementation:**
```ruby
class UserMembership < ApplicationRecord
  enum role: { admin: 0, editor: 1, viewer: 2, support_agent: 3 }
end
```

**Files to Create:**
- `app/policies/` - Pundit authorization policies
- Migration: add_role_to_user_memberships.rb

**Tests:** 
- `spec/policies/property_policy_spec.rb`
- `spec/policies/user_policy_spec.rb`

### [ ] Add Comprehensive Request Specs
**Current Coverage:** 62 request spec files (good)
**Gaps:** Support ticket workflow, widget embedding, SEO audit
**Effort:** 3-5 days

**Missing Specs:**
- [ ] `spec/requests/site_admin/widgets_spec.rb`
- [ ] `spec/requests/site_admin/seo_audit_spec.rb`
- [ ] `spec/requests/site_admin/external_feeds_spec.rb`
- [ ] `spec/requests/tenant_admin/auth_audit_logs_spec.rb`

### [ ] Clean Up Code Quality
**Issues Found:**
- 42 debug statements
- Unused variables in services
- Inconsistent error handling

**Commands:**
```bash
# Find debug statements
grep -r "byebug\|binding.pry\|console\|debugger" app --include="*.rb" -l

# Check for unused variables
brakeman -q

# Run rubocop
rubocop -a
```

## Medium Priority (1-2 Weeks)

### [ ] Build E2E Test Suite with Playwright
**Current Status:** Framework ready, <10% of tests written
**Focus Areas:**
- [ ] Property CRUD workflow
- [ ] Search and filtering
- [ ] Subscription lifecycle
- [ ] Widget embedding
- [ ] Support ticket workflow

**Setup:**
```bash
# Install Playwright
npm install --save-dev @playwright/test

# Create tests/
mkdir -p tests/e2e

# Run tests in container
container-use create
container-use run "npx playwright test"
```

### [ ] Optimize Database Queries
**Issues:**
- Materialized view refresh could be faster
- Some N+1 queries remain in admin views
- Missing composite indexes

**Actions:**
```bash
# Find slow queries
# Enable slow query log in PostgreSQL
# Run: SELECT * FROM pg_stat_statements WHERE mean_time > 1000

# Add missing indexes
rails db:migrate
```

### [ ] Implement API Rate Limiting
**Current Status:** Rack::Attack configured but unused
**Target:** 300 requests/5 minutes per IP

```ruby
# config/rack_attack.rb
Rack::Attack.throttle('api/ip', limit: 300, period: 5.minutes) do |req|
  req.ip if req.path.start_with?('/api')
end
```

### [ ] Add Admin Health Dashboard
**Data Points:**
- Database connection pool usage
- Background job queue depth
- Storage usage
- Failed subscription renewals
- Support ticket SLA breaches

**Location:** `app/controllers/site_admin/health_dashboard_controller.rb`

## Medium-Low Priority (2-4 Weeks)

### [ ] Responsive Mobile Admin Interface
**Current Status:** Desktop-only
**Effort:** 1-2 weeks
**Approach:** 
- Mobile-first CSS refactor
- Tailwind breakpoints (md:, lg:)
- Mobile hamburger menu
- Touch-friendly button sizes

**Files to Modify:**
- `app/views/layouts/site_admin.html.erb`
- `app/themes/*/stylesheets/`

### [ ] Expand Service Layer
**Current Services:**
- `SignupStatusPresenter` (only one)

**New Services Needed:**
- `Services::PropertyImport` - CSV/URL import
- `Services::SubscriptionLifecycle` - Trial/renewal/cancellation
- `Services::WebsiteProvisioning` - New site setup
- `Services::SupportTicketEscalation` - SLA monitoring
- `Services::ReportGeneration` - Analytics reports

**Benefit:** Cleaner controllers, more testable code

### [ ] Complete Dark Mode Implementation
**Current Status:** 50% - CSS variables prepared
**Remaining Work:**
- Test all admin pages with dark mode
- User preference storage and retrieval
- Smooth theme transitions
- CSS variable adjustments

**Files:**
- `app/views/site_admin/` - All templates need review
- `app/themes/*/dark_mode.css`

## Low Priority (3+ Months)

### [ ] APM/Monitoring Integration
**Recommended Tools:**
- New Relic or Datadog for application metrics
- Sentry for error tracking
- LogStash for centralized logging
- Prometheus for metrics export

**Key Metrics to Track:**
- Response times by controller
- Database query times
- Background job failures
- Error rate
- User activity

### [ ] Comprehensive Search Optimization
**Current Implementation:** Materialized view (good)
**Enhancement:** PostgreSQL full-text search

```sql
-- Add full-text search index
CREATE INDEX idx_properties_search_tsvector 
ON pwb_properties USING GiST(
  to_tsvector('english', 
    coalesce(title, '') || ' ' || 
    coalesce(description, '')
  )
);
```

### [ ] Caching Layer Enhancement
**Current Status:** Redis optional, underutilized
**Opportunities:**
- Cache frequently accessed properties
- Cache website settings
- Cache user preferences
- Cache theme configurations

```ruby
scope :for_website, ->(website_id) {
  Rails.cache.fetch("website:#{website_id}:active_properties", 
    expires_in: 1.hour) do
    where(website_id: website_id, active: true)
  end
}
```

### [ ] Contract Testing for APIs
**Purpose:** Consumer-driven contract testing
**Tool:** Pact gem
**Benefit:** Prevent API breaking changes

### [ ] Backup & Disaster Recovery Testing
**Critical:** Test that backups actually work
**Process:**
1. Document backup procedure
2. Test restore process monthly
3. Measure recovery time objective (RTO)
4. Measure recovery point objective (RPO)

## Stretch Goals (6+ Months)

### [ ] Native Mobile Apps
**Platforms:** iOS (Swift) + Android (Kotlin)
**MVP:** Property search, details, contact

### [ ] VR/360° Tour Integration
**Integration:** Matterport or Zillow 3D tours
**UX:** Embedded viewer on property detail page

### [ ] CRM Integrations
**Target Systems:** HubSpot, Salesforce, Pipedrive
**Data Sync:** Automatic contact/property sync

### [ ] AI Property Descriptions
**Integration:** OpenAI API
**Use Case:** Auto-generate SEO-optimized descriptions

---

## Testing Checklist

Before each release, run:

```bash
# Unit tests
bundle exec rspec spec/models/

# Controller/request tests
bundle exec rspec spec/requests/

# Integration tests
bundle exec rspec spec/integration/

# All tests
bundle exec rspec

# Security audit
brakeman -q
bundle audit

# Code quality
rubocop

# Coverage report
simplecov
```

## Pre-Deployment Checklist

- [ ] All debug statements removed
- [ ] Database migrations tested
- [ ] Environment variables documented
- [ ] CHANGELOG.md updated
- [ ] Security audit passed
- [ ] Performance tests run
- [ ] E2E tests passing
- [ ] Load tests completed
- [ ] Backup tested
- [ ] Rollback procedure documented

---

## Feature Flags (Coming Soon)

Consider implementing feature flags for:

```ruby
# Safe rollout of new features
Features.enabled?(:dark_mode)         # 50% of users
Features.enabled?(:new_search_ui)     # Beta testers only
Features.enabled?(:ai_descriptions)   # Enterprise plans
```

**Implementation:** Flipper or LaunchDarkly gem

---

## Documentation TODOs

- [ ] Authorization system documentation
- [ ] Service layer patterns guide
- [ ] Theme customization advanced guide
- [ ] API error response catalog
- [ ] Deployment troubleshooting guide
- [ ] Admin panel user manual
- [ ] Upgrade guide from v1.x → v2.x

---

## Performance Optimization Checklist

- [ ] Database query optimization (includes, eager_load)
- [ ] N+1 query elimination
- [ ] Index analysis and addition
- [ ] Connection pool tuning
- [ ] Cache warming strategies
- [ ] Asset compression
- [ ] Image optimization
- [ ] CDN integration for static assets

---

## Security Hardening Checklist

- [ ] Remove debug statements
- [ ] RBAC implementation
- [ ] API rate limiting
- [ ] CORS policy review
- [ ] SQL injection audit
- [ ] XSS vulnerability scan
- [ ] CSRF token validation
- [ ] Session security review
- [ ] Password strength requirements
- [ ] Two-factor authentication (optional)

---

*Last Updated: January 4, 2026*
*Priorities Based On: Impact × Urgency × Effort*
