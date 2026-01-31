# PropertyWebBuilder Improvement Sprint Plan

**Created**: 2026-01-31
**Last Updated**: 2026-01-31
**Status**: Planning
**Author**: Development Team

---

## Executive Summary

This document outlines a prioritized improvement plan for the PropertyWebBuilder codebase based on a comprehensive analysis conducted on 2026-01-31. The improvements are organized into three sprints focusing on security, test coverage, and code quality.

**Key Metrics at Time of Analysis**:
- Total Ruby Files: 937 (482 app + 455 spec)
- Test Coverage: ~65% of models, ~22% of controllers, ~36% of jobs
- Known TODOs/FIXMEs: 45+ comments
- Critical Security Issues: 3 identified

---

## Sprint 1: Critical Security Fixes

**Duration**: 1 week (2026-02-01 to 2026-02-07)
**Priority**: CRITICAL
**Estimated Effort**: 12-16 hours

### 1.1 Implement API Authentication in ApiManage Controllers

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 4-6 hours

#### Problem
The `ApiManage::V1::BaseController` lacks authentication, allowing unauthenticated access to AI features, CMA reports, and content management APIs.

#### Files to Modify
- [ ] `app/controllers/api_manage/v1/base_controller.rb`
- [ ] `app/controllers/api_manage/v1/ai_descriptions_controller.rb`
- [ ] `app/controllers/api_manage/v1/reports/cmas_controller.rb`
- [ ] `app/controllers/api_manage/v1/ai/social_posts_controller.rb`

#### Tasks
- [ ] Implement Firebase token validation in `BaseController`
- [ ] Add fallback API key authentication for server-to-server calls
- [ ] Implement `current_user` method that extracts user from auth token
- [ ] Add `current_website` resolution from authenticated user context
- [ ] Add request logging with user attribution

#### Implementation Notes
```ruby
# app/controllers/api_manage/v1/base_controller.rb
class ApiManage::V1::BaseController < ActionController::API
  before_action :authenticate_request!
  before_action :set_current_website

  private

  def authenticate_request!
    # Option 1: Firebase token
    if request.headers['Authorization']&.start_with?('Bearer ')
      authenticate_firebase_token!
    # Option 2: API key for server-to-server
    elsif request.headers['X-API-Key'].present?
      authenticate_api_key!
    else
      render json: { error: 'Authentication required' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def set_current_website
    @current_website = current_user&.primary_website
    return render_unauthorized unless @current_website
  end
end
```

#### Acceptance Criteria
- [ ] All ApiManage endpoints require authentication
- [ ] Unauthenticated requests return 401
- [ ] `current_user` returns actual user object (not nil)
- [ ] Audit log captures user_id for all API requests
- [ ] Tests added for authentication flow

#### Tests to Add
- [ ] `spec/requests/api_manage/v1/authentication_spec.rb`
- [ ] Update existing API specs to include auth headers

---

### 1.2 Re-enable Editor Authentication

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 2-3 hours

#### Problem
The page editor and theme settings controllers have authentication commented out, allowing any user to modify website content.

#### Files to Modify
- [ ] `app/controllers/pwb/editor_controller.rb`
- [ ] `app/controllers/pwb/editor/page_parts_controller.rb`
- [ ] `app/controllers/pwb/editor/theme_settings_controller.rb`

#### Tasks
- [ ] Uncomment `before_action :authenticate_admin_user!` in all editor controllers
- [ ] Implement `authenticate_admin_user!` method if missing
- [ ] Verify user has admin role for current_website (not just any website)
- [ ] Add proper error responses for unauthorized access

#### Implementation Notes
```ruby
# app/controllers/pwb/editor_controller.rb
class Pwb::EditorController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin_user!

  private

  def authenticate_admin_user!
    unless current_user&.admin_for_website?(current_website)
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Admin access required' }
        format.json { render json: { error: 'Forbidden' }, status: :forbidden }
      end
    end
  end
end
```

#### Acceptance Criteria
- [ ] Non-authenticated users cannot access /editor routes
- [ ] Non-admin users get 403 Forbidden
- [ ] Admin users can only edit their own website
- [ ] Tests verify authentication requirements

#### Tests to Add
- [ ] `spec/requests/pwb/editor_authentication_spec.rb`

---

### 1.3 Add Explicit Tenant Validation to API Endpoints

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 3-4 hours

#### Problem
Some API queries use `current_website&.id` which returns nil if tenant isn't set, potentially returning records from all tenants.

#### Files to Audit and Fix
- [ ] `app/controllers/api_manage/v1/reports/cmas_controller.rb`
- [ ] `app/controllers/api_public/v1/properties_controller.rb`
- [ ] `app/controllers/api_public/v1/theme_settings_controller.rb`
- [ ] All controllers using `current_website&.id` pattern

#### Tasks
- [ ] Search codebase for `current_website&.id` pattern
- [ ] Add explicit nil check before any tenant-scoped query
- [ ] Return 400 Bad Request if website context cannot be determined
- [ ] Add integration tests for cross-tenant isolation

#### Implementation Pattern
```ruby
# Before (vulnerable)
def index
  reports = Pwb::MarketReport.where(website_id: current_website&.id)
end

# After (safe)
def index
  return render_website_required unless current_website
  reports = current_website.market_reports
end

private

def render_website_required
  render json: { error: 'Website context required' }, status: :bad_request
end
```

#### Acceptance Criteria
- [ ] No queries use `current_website&.id` pattern
- [ ] All API endpoints validate website context
- [ ] Cross-tenant tests pass
- [ ] 400 returned when website context missing

#### Tests to Add
- [ ] Expand `spec/requests/api_public/v1/cross_tenant_isolation_spec.rb`
- [ ] Add tenant isolation tests for ApiManage endpoints

---

### 1.4 Fix current_user Nil in AI Services

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 2-3 hours

#### Problem
AI controllers return `nil` for `current_user`, breaking audit trails and billing attribution.

#### Files to Modify
- [ ] `app/controllers/api_manage/v1/ai_descriptions_controller.rb` (lines 91-93)
- [ ] `app/controllers/api_manage/v1/ai/social_posts_controller.rb`

#### Tasks
- [ ] Remove stub `current_user` methods that return nil
- [ ] Inherit proper authentication from BaseController (after 1.1 is complete)
- [ ] Update AI service calls to pass user context
- [ ] Add user attribution to AI generation audit logs

#### Acceptance Criteria
- [ ] `current_user` never returns nil in authenticated endpoints
- [ ] AI generation requests logged with user_id
- [ ] Rate limiting can be applied per-user

---

## Sprint 2: Test Coverage & Code Cleanup

**Duration**: 2 weeks (2026-02-08 to 2026-02-21)
**Priority**: HIGH
**Estimated Effort**: 30-40 hours

### 2.1 Add Missing Job Specs

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 12-16 hours

#### Problem
Only 36% of background jobs have test coverage. Critical operations run untested.

#### Jobs Requiring Specs (Priority Order)

**Critical - Data Integrity**:
- [ ] `app/jobs/cleanup_orphaned_blobs_job.rb`
- [ ] `app/jobs/refresh_properties_view_job.rb`
- [ ] `app/jobs/subscription_lifecycle_job.rb`

**High - Core Features**:
- [ ] `app/jobs/batch_url_import_job.rb`
- [ ] `app/jobs/download_scraped_images_job.rb`
- [ ] `app/jobs/image_variant_generator_job.rb`
- [ ] `app/jobs/search_alert_job.rb`

**Medium - Operational**:
- [ ] `app/jobs/update_exchange_rates_job.rb`
- [ ] `app/jobs/sla_monitoring_job.rb`
- [ ] `app/jobs/generate_sitemap_job.rb`

**Lower Priority**:
- [ ] `app/jobs/demo_reset_job.rb`
- [ ] `app/jobs/property_image_processor_job.rb`
- [ ] `app/jobs/webhook_delivery_job.rb`

#### Spec Template
```ruby
# spec/jobs/cleanup_orphaned_blobs_job_spec.rb
require 'rails_helper'

RSpec.describe CleanupOrphanedBlobsJob, type: :job do
  describe '#perform' do
    context 'with orphaned blobs' do
      let!(:orphaned_blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('test'),
          filename: 'orphan.txt'
        )
      end

      it 'removes blobs without attachments' do
        expect {
          described_class.perform_now
        }.to change(ActiveStorage::Blob, :count).by(-1)
      end
    end

    context 'with attached blobs' do
      # Test that attached blobs are preserved
    end

    context 'with recent orphans' do
      # Test that recently created orphans are not deleted (grace period)
    end
  end
end
```

#### Acceptance Criteria
- [ ] All critical jobs have specs
- [ ] Job specs test success and failure scenarios
- [ ] Job specs verify side effects (emails sent, records updated)
- [ ] CI passes with new job specs

---

### 2.2 Remove Deprecated Vue.js and GraphQL Code

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 2-3 hours

#### Problem
Deprecated code directories still exist, causing confusion and maintenance burden.

#### Directories to Remove
- [ ] `app/frontend/` - Entire directory (Vue.js apps)
- [ ] `app/graphql/` - Entire directory (GraphQL API)

#### Files to Update
- [ ] Remove GraphQL gem from `Gemfile` if present
- [ ] Remove Vue-related entries from `package.json` if present
- [ ] Update any documentation referencing these

#### Pre-Removal Checklist
- [ ] Verify no production code imports from these directories
- [ ] Search for any remaining references: `grep -r "app/frontend" .`
- [ ] Search for GraphQL references: `grep -r "graphql" app/`
- [ ] Backup directories before deletion (git handles this)

#### Commands
```bash
# Verify no imports
grep -r "from.*frontend" app/
grep -r "graphql" app/controllers app/models

# Remove directories
git rm -rf app/frontend/
git rm -rf app/graphql/

# Commit
git commit -m "Remove deprecated Vue.js and GraphQL code"
```

#### Acceptance Criteria
- [ ] Directories removed from repository
- [ ] Application still boots and all tests pass
- [ ] No broken imports or references
- [ ] Documentation updated

---

### 2.3 Implement User Invitation Email System

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 6-8 hours

#### Problem
Users aren't notified when added to websites. Multiple TODOs in `users_controller.rb`.

#### Files to Create
- [ ] `app/mailers/user_invitation_mailer.rb`
- [ ] `app/views/user_invitation_mailer/invitation.html.erb`
- [ ] `app/views/user_invitation_mailer/invitation.text.erb`
- [ ] `app/views/user_invitation_mailer/added_to_website.html.erb`

#### Files to Modify
- [ ] `app/controllers/site_admin/users_controller.rb`
- [ ] `app/models/pwb/user.rb` (add invitation token methods)

#### Tasks
- [ ] Create `UserInvitationMailer` with invitation template
- [ ] Add `invitation_token` and `invitation_sent_at` columns to users table
- [ ] Implement `send_invitation!` method on User model
- [ ] Update `UsersController#create` to send invitation email
- [ ] Update `UsersController#resend_invitation` to actually send email
- [ ] Add background job for email delivery

#### Implementation
```ruby
# app/mailers/user_invitation_mailer.rb
class UserInvitationMailer < ApplicationMailer
  def invitation(user, website, inviter)
    @user = user
    @website = website
    @inviter = inviter
    @accept_url = accept_invitation_url(token: user.invitation_token)

    mail(
      to: user.email,
      subject: "You've been invited to #{website.display_name}"
    )
  end

  def added_to_website(user, website, role)
    @user = user
    @website = website
    @role = role

    mail(
      to: user.email,
      subject: "You've been added to #{website.display_name}"
    )
  end
end
```

#### Database Migration
```ruby
class AddInvitationFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :pwb_users, :invitation_token, :string
    add_column :pwb_users, :invitation_sent_at, :datetime
    add_column :pwb_users, :invitation_accepted_at, :datetime

    add_index :pwb_users, :invitation_token, unique: true
  end
end
```

#### Acceptance Criteria
- [ ] New users receive invitation email
- [ ] Existing users receive "added to website" email
- [ ] Resend invitation actually sends email
- [ ] Invitation token is secure and expires
- [ ] Tests cover email delivery

#### Tests to Add
- [ ] `spec/mailers/user_invitation_mailer_spec.rb`
- [ ] Update `spec/requests/site_admin/users_spec.rb` with email expectations

---

### 2.4 Improve Error Handling and Logging

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 6-8 hours

#### Problem
59 `rescue StandardError` blocks are too broad; many rescue blocks lack logging.

#### Files to Audit
Run this command to find problematic patterns:
```bash
grep -rn "rescue StandardError" app/
grep -rn "rescue =>" app/ | grep -v "Rails.logger"
```

#### Tasks
- [ ] Replace `rescue StandardError` with specific exceptions
- [ ] Add structured logging to all rescue blocks
- [ ] Create custom exception classes where appropriate
- [ ] Add error tracking integration (Sentry/Rollbar) if not present

#### Error Handling Pattern
```ruby
# Before
def process_payment
  # ... payment logic
rescue StandardError => e
  flash[:error] = "Payment failed"
end

# After
def process_payment
  # ... payment logic
rescue Stripe::CardError => e
  Rails.logger.warn("Payment declined", {
    user_id: current_user&.id,
    error_code: e.code,
    message: e.message
  })
  flash[:error] = "Your card was declined: #{e.message}"
rescue Stripe::RateLimitError => e
  Rails.logger.error("Stripe rate limit", { retry_after: e.retry_after })
  flash[:error] = "Payment service busy. Please try again."
rescue StandardError => e
  Rails.logger.error("Unexpected payment error", {
    error_class: e.class.name,
    message: e.message,
    backtrace: e.backtrace.first(5)
  })
  flash[:error] = "An unexpected error occurred"
  raise if Rails.env.development? # Re-raise in dev for debugging
end
```

#### Custom Exceptions to Create
```ruby
# app/errors/application_error.rb
module Errors
  class ApplicationError < StandardError
    attr_reader :code, :details

    def initialize(message = nil, code: nil, details: {})
      @code = code
      @details = details
      super(message)
    end
  end

  class TenantNotFoundError < ApplicationError; end
  class FeatureNotEnabledError < ApplicationError; end
  class RateLimitExceededError < ApplicationError; end
  class ExternalServiceError < ApplicationError; end
end
```

#### Acceptance Criteria
- [ ] No `rescue StandardError` without specific handling
- [ ] All rescue blocks include logging
- [ ] Custom exceptions used for domain-specific errors
- [ ] Error logs include context (user_id, website_id, request_id)

---

## Sprint 3: Performance & Data Integrity

**Duration**: 2 weeks (2026-02-22 to 2026-03-07)
**Priority**: MEDIUM
**Estimated Effort**: 25-35 hours

### 3.1 Add Missing Database Indexes

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 4-6 hours

#### Problem
Missing composite indexes on frequently queried columns causing slow queries.

#### Indexes to Add

**High Priority - Frequently Queried**:
```ruby
# Migration: AddPerformanceIndexes
add_index :pwb_auth_audit_logs, [:website_id, :created_at]
add_index :pwb_auth_audit_logs, [:website_id, :event_type, :created_at]
add_index :pwb_realty_assets, [:website_id, :created_at]
add_index :pwb_realty_assets, [:website_id, :reference]
add_index :pwb_pages, [:website_id, :slug]
add_index :pwb_user_memberships, [:user_id, :website_id, :active]
```

**Medium Priority - API Queries**:
```ruby
add_index :ai_generation_requests, [:request_type, :status]
add_index :ai_generation_requests, [:website_id, :created_at]
add_index :pwb_listing_videos, [:website_id, :status]
add_index :pwb_cma_reports, [:website_id, :created_at]
```

#### Analysis Commands
```bash
# Find slow queries in development
tail -f log/development.log | grep -E "^\s+[A-Z].*\([0-9]+\.[0-9]+ms\)"

# Check existing indexes
rails db:migrate:status
rails runner "puts ActiveRecord::Base.connection.indexes('pwb_realty_assets').map(&:name)"
```

#### Acceptance Criteria
- [ ] Migration created and tested
- [ ] No duplicate indexes
- [ ] Query performance improved (measure before/after)
- [ ] Tests pass with new indexes

---

### 3.2 Fix N+1 Query Issues

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 6-8 hours

#### Problem
Only 28 files use `.includes` across the entire app. Many list endpoints have N+1 queries.

#### Detection
Add Bullet gem to development:
```ruby
# Gemfile
group :development do
  gem 'bullet'
end

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
end
```

#### Known N+1 Patterns to Fix

**Site Admin Controllers**:
```ruby
# Before
def index
  @properties = current_website.realty_assets
end

# After
def index
  @properties = current_website.realty_assets
    .includes(:sale_listing, :rental_listing, :prop_photos)
end
```

**API Endpoints**:
```ruby
# Before
def index
  @listings = Pwb::ListedProperty.where(website_id: current_website.id)
end

# After
def index
  @listings = Pwb::ListedProperty
    .where(website_id: current_website.id)
    .includes(:features, :photos)
end
```

#### Files to Review
- [ ] `app/controllers/site_admin/props_controller.rb`
- [ ] `app/controllers/api_public/v1/properties_controller.rb`
- [ ] `app/controllers/site_admin/media_library_controller.rb`
- [ ] `app/controllers/site_admin/users_controller.rb`
- [ ] `app/controllers/site_admin/pages_controller.rb`

#### Acceptance Criteria
- [ ] Bullet gem reports no N+1 issues in development
- [ ] List endpoints use appropriate `.includes`
- [ ] API response times improved
- [ ] No over-eager loading (only load what's needed)

---

### 3.3 Add Model Validations

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 8-10 hours

#### Problem
Only 55% of models have proper validations. Missing validations can lead to data integrity issues.

#### Models to Audit

**Critical - User-Facing**:
- [ ] `Pwb::User` - email format, presence checks
- [ ] `Pwb::RealtyAsset` - reference uniqueness per website
- [ ] `Pwb::Page` - slug format, uniqueness per website
- [ ] `Pwb::Website` - subdomain format, uniqueness

**High - Financial**:
- [ ] `Pwb::Subscription` - status inclusion, dates present
- [ ] `Pwb::SaleListing` - price validation (positive number)
- [ ] `Pwb::RentalListing` - price validation

**Medium - Content**:
- [ ] `Pwb::EmailTemplate` - subject and body presence
- [ ] `Pwb::Integration` - category inclusion
- [ ] `Pwb::Media` - filename presence, content_type format

#### Validation Patterns
```ruby
# app/models/pwb/email_template.rb
class Pwb::EmailTemplate < ApplicationRecord
  validates :name, presence: true, uniqueness: { scope: :website_id }
  validates :subject, presence: true
  validates :body, presence: true
  validates :template_type, inclusion: { in: TEMPLATE_TYPES }
end

# app/models/pwb/integration.rb
class Pwb::Integration < ApplicationRecord
  CATEGORIES = %w[analytics marketing crm ai payment].freeze

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :api_key, presence: true, if: :requires_api_key?
end
```

#### Acceptance Criteria
- [ ] All models have appropriate presence validations
- [ ] Uniqueness constraints match database indexes
- [ ] Inclusion validations for enum-like fields
- [ ] Format validations for emails, URLs, slugs
- [ ] Tests cover validation errors

---

### 3.4 Add Cross-Tenant Security Tests

**Status**: [ ] Not Started
**Assignee**: TBD
**Estimated Time**: 4-6 hours

#### Problem
Limited integration testing for multi-tenancy isolation.

#### Test Scenarios to Add

**Data Isolation Tests**:
```ruby
# spec/requests/multi_tenancy/data_isolation_spec.rb
RSpec.describe 'Multi-tenancy Data Isolation', type: :request do
  let!(:website_a) { create(:pwb_website, subdomain: 'tenant-a') }
  let!(:website_b) { create(:pwb_website, subdomain: 'tenant-b') }
  let!(:admin_a) { create(:pwb_user, :admin, website: website_a) }
  let!(:property_b) { create(:pwb_realty_asset, website: website_b) }

  before { sign_in admin_a }

  describe 'property access' do
    it 'cannot view properties from other tenants' do
      get site_admin_prop_path(property_b),
          headers: { 'HTTP_HOST' => 'tenant-a.test.localhost' }

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot update properties from other tenants' do
      patch site_admin_prop_path(property_b),
            params: { pwb_realty_asset: { reference: 'HACKED' } },
            headers: { 'HTTP_HOST' => 'tenant-a.test.localhost' }

      expect(response).to have_http_status(:not_found)
      expect(property_b.reload.reference).not_to eq('HACKED')
    end

    it 'cannot delete properties from other tenants' do
      expect {
        delete site_admin_prop_path(property_b),
               headers: { 'HTTP_HOST' => 'tenant-a.test.localhost' }
      }.not_to change(Pwb::RealtyAsset, :count)
    end
  end

  # Similar tests for: users, pages, media, reports, videos, etc.
end
```

**API Isolation Tests**:
```ruby
# spec/requests/api_public/v1/tenant_isolation_spec.rb
RSpec.describe 'API Tenant Isolation', type: :request do
  describe 'property listing API' do
    it 'only returns properties for requested subdomain' do
      # ...
    end

    it 'returns 404 for non-existent subdomain' do
      # ...
    end
  end
end
```

#### Acceptance Criteria
- [ ] Tests cover all major resources (properties, users, pages, media, reports)
- [ ] Tests verify read, write, and delete isolation
- [ ] Tests cover both site_admin and API endpoints
- [ ] All tests pass

---

## Appendix A: File Reference

### Security-Related Files
```
app/controllers/api_manage/v1/base_controller.rb
app/controllers/api_manage/v1/ai_descriptions_controller.rb
app/controllers/api_manage/v1/reports/cmas_controller.rb
app/controllers/pwb/editor_controller.rb
app/controllers/pwb/editor/page_parts_controller.rb
app/controllers/pwb/editor/theme_settings_controller.rb
```

### Deprecated Directories
```
app/frontend/           # Vue.js (DEPRECATED)
app/graphql/            # GraphQL API (DEPRECATED)
```

### Test Directories
```
spec/jobs/              # Job specs (needs expansion)
spec/requests/          # Request specs
spec/services/          # Service specs
spec/models/            # Model specs
```

---

## Appendix B: Commands Reference

### Find TODOs
```bash
grep -rn "TODO" app/ --include="*.rb" | wc -l
grep -rn "FIXME" app/ --include="*.rb"
```

### Find Security Patterns
```bash
grep -rn "current_website&.id" app/
grep -rn "rescue StandardError" app/
grep -rn "skip_before_action.*authenticate" app/
```

### Run Specific Test Groups
```bash
# Run all job specs
bundle exec rspec spec/jobs/

# Run all request specs
bundle exec rspec spec/requests/

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Check Database Indexes
```bash
rails runner "ActiveRecord::Base.connection.tables.each { |t| puts t; puts ActiveRecord::Base.connection.indexes(t).map(&:name).join(', '); puts }"
```

---

## Appendix C: Progress Tracking

### Sprint 1 Progress
| Task | Status | Assignee | Completed |
|------|--------|----------|-----------|
| 1.1 API Authentication | [ ] Not Started | TBD | - |
| 1.2 Editor Authentication | [ ] Not Started | TBD | - |
| 1.3 Tenant Validation | [ ] Not Started | TBD | - |
| 1.4 Fix current_user nil | [ ] Not Started | TBD | - |

### Sprint 2 Progress
| Task | Status | Assignee | Completed |
|------|--------|----------|-----------|
| 2.1 Job Specs | [ ] Not Started | TBD | - |
| 2.2 Remove Deprecated Code | [ ] Not Started | TBD | - |
| 2.3 User Invitation Emails | [ ] Not Started | TBD | - |
| 2.4 Error Handling | [ ] Not Started | TBD | - |

### Sprint 3 Progress
| Task | Status | Assignee | Completed |
|------|--------|----------|-----------|
| 3.1 Database Indexes | [ ] Not Started | TBD | - |
| 3.2 N+1 Query Fixes | [ ] Not Started | TBD | - |
| 3.3 Model Validations | [ ] Not Started | TBD | - |
| 3.4 Security Tests | [ ] Not Started | TBD | - |

---

## Document History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-31 | Development Team | Initial document creation |
