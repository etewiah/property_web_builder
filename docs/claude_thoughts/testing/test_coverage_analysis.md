# PropertyWebBuilder Test Coverage Analysis

## Executive Summary

The PropertyWebBuilder Rails project has **good foundational test coverage** (42 request specs, 56 model specs) covering critical multi-tenancy, authentication, and API functionality. However, there are significant gaps in key user-facing features, admin workflows, and business logic that would benefit from additional testing.

**Total Controllers Analyzed:**
- site_admin: 20 controllers
- tenant_admin: 15 controllers  
- pwb (public): 44 controllers
- API controllers: 12+ additional

**Current Test Coverage Summary:**
- Request Specs: 42 files
- Model Specs: 56 files
- Integration Specs: 1 file
- Service Specs: 19 files
- View Specs: 6 files
- Controller Specs: 11 files

---

## Priority 1: Critical Missing Test Coverage (High Impact)

These gaps affect core business flows and user experience.

### 1.1 Site Admin Dashboard & Analytics
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/dashboard_controller.rb`
**Status:** NO TESTS
**Impact:** HIGH - Dashboard is the main interface for site administrators

**Missing Test Scenarios:**
- Dashboard index loads correctly with website statistics
- Stats calculation includes properties, pages, contents, messages, contacts
- Weekly activity stats aggregate correctly (new messages, new contacts, new properties)
- Unread messages count is accurate
- Recent activity timeline includes last 10 items in correct order
- Website health checklist calculates percentage correctly
- Subscription information displays correctly (status, plan, trial days)
- "Getting started" guide shows/hides based on health score (<70%) and property count (<3)
- Multi-tenant isolation: only shows data for current_website
- Stats calculations handle edge cases (no data, deleted items)

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/site_admin/dashboard_spec.rb`

---

### 1.2 Site Admin Analytics
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/analytics_controller.rb`
**Status:** NO TESTS
**Impact:** HIGH - Analytics visibility is a premium feature

**Missing Test Scenarios:**
- Analytics feature check - redirects if not enabled
- Traffic dashboard loads with visits chart
- Traffic source breakdown (organic, direct, referral, social)
- Device breakdown (mobile, desktop, tablet)
- Properties dashboard - top properties by views
- Top searches aggregation
- Conversions dashboard - inquiry funnel
- Real-time dashboard with active visitors and recent pageviews
- Period parameter filtering (7, 14, 30, 60, 90 days)
- Plan feature check - analytics not available on basic plans
- JSON response format for real-time updates
- Multi-tenant isolation for all analytics queries

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/site_admin/analytics_spec.rb`

---

### 1.3 Site Admin Onboarding Flow
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/onboarding_controller.rb`
**Status:** PARTIAL - Controller spec exists but integration tests missing
**Impact:** HIGH - Critical user activation flow

**Existing Tests:** Basic controller spec covers all steps
**Missing Test Scenarios:**
- Integration test: User can complete full onboarding flow from step 1-5
- Currency selection persists to website default_currency
- Agency creation with multiple phone numbers
- Property seeding during onboarding
- Multiple properties created in succession
- Theme selection actually applies theme to website
- User state transitions (onboarding_state, onboarding_step)
- Email verification email sent after completion
- Edge case: user goes back and modifies earlier steps
- Edge case: user restarts onboarding and starts from step 1
- Validation errors properly displayed for each step
- User without website access cannot access onboarding

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/site_admin/onboarding_flow_spec.rb`

---

### 1.4 Site Admin Billing
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/billing_controller.rb`
**Status:** NO TESTS
**Impact:** MEDIUM-HIGH - Users need to see subscription status

**Missing Test Scenarios:**
- Billing page shows current subscription
- Subscription plan information displays correctly
- Usage calculation for properties vs limit
- Usage calculation for users vs limit
- Unlimited properties/users flags display correctly
- Displays link to upgrade if near limits
- Handles case where no subscription exists (free mode)
- Gracefully handles missing plan information

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/site_admin/billing_spec.rb`

---

### 1.5 Site Admin Activity Logs / Auth Audit Logs
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/activity_logs_controller.rb`
**Status:** NO TESTS
**Impact:** MEDIUM - Security audit trail

**Missing Test Scenarios:**
- Activity logs index displays auth events
- Filtering by event type (login_success, login_failure, etc.)
- Filtering by user
- Date range filtering (1h, 24h, 7d, 30d)
- Pagination of logs (50 per page)
- Stats calculation (logins today, failures today, unique IPs)
- Show action displays individual log details
- Log contains IP address and user agent
- Multi-tenant isolation - only shows website's logs

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/site_admin/activity_logs_spec.rb`

---

### 1.6 Site Admin Email Templates
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/email_templates_controller.rb`
**Status:** NO TESTS
**Impact:** MEDIUM - Business-critical communications

**Missing Test Scenarios:**
- Email templates index shows allowed templates (enquiry.general, enquiry.property)
- New template form pre-populates with default template content
- Create custom template saves subject and body_html
- Update modifies template content
- Delete custom template - defaults back to default template
- Preview action renders template with sample data
- Preview default shows default template with sample variables
- Sample data generation for all template variables
- Liquid variable rendering in subject and body
- HTML to text conversion for body_text
- Only enquiry templates visible in site_admin (not alerts or user emails)

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/site_admin/email_templates_spec.rb`

---

### 1.7 Site Admin Contents Management
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/contents_controller.rb`
**Status:** NO TESTS (uses SiteAdminIndexable concern)
**Impact:** MEDIUM - Content management

**Missing Test Scenarios:**
- Index displays all web contents for current website
- Search by tag filters contents
- Multi-tenant isolation - only shows website's contents
- Pagination works correctly
- CRUD operations (create, read, update, delete)
- Associations to website maintained

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/site_admin/contents_spec.rb`

---

## Priority 2: Critical Tenant Admin & Public Features (High Impact)

### 2.1 Tenant Admin Subscriptions Management
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/subscriptions_controller.rb`
**Status:** HAS TESTS - But incomplete
**Impact:** HIGH - Core billing operations

**Existing Tests:** Partial subscription spec exists
**Missing Test Scenarios:**
- Full CRUD operations for subscriptions
- State machine transitions (trialing -> active, active -> past_due, etc.)
- Trial expiration flow
- Plan changes and pricing adjustments
- Bulk operations: expire_trials action
- Trial ending soon notifications
- Subscription feature access (property limits, user limits)
- Events logging for all transitions
- External provider integration (Stripe, etc.)
- Metadata storage and retrieval

**Recommended Addition:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/tenant_admin/subscriptions_spec.rb`

---

### 2.2 Tenant Admin Plans Management
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/plans_controller.rb`
**Status:** NO TESTS
**Impact:** MEDIUM-HIGH - Business model configuration

**Missing Test Scenarios:**
- List all plans with filters (active status)
- Create new plan with all attributes
- Edit plan details
- Delete plan (soft/hard delete)
- Enable/disable features per plan
- Plan pricing updates
- Trial days configuration
- Property limits and user limits
- Plan ordering for display

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/tenant_admin/plans_spec.rb`

---

### 2.3 Tenant Admin Email Templates
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/email_templates_controller.rb` (if exists)
**Status:** Unknown (likely no tests)
**Impact:** MEDIUM - Multi-website email customization

**Missing Test Scenarios:**
- Different templates available for different websites
- Alert templates (new property, price change)
- User templates (welcome, password reset)
- Template variables documented and tested
- Default fallback when custom template missing

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/tenant_admin/email_templates_spec.rb`

---

### 2.4 Tenant Admin Domains/Subdomains
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/domains_controller.rb`
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/subdomains_controller.rb`
**Status:** NO TESTS
**Impact:** MEDIUM - Multi-domain feature critical

**Missing Test Scenarios:**
- Domain management CRUD
- Subdomain management CRUD
- Validation of custom domains
- DNS configuration verification
- Primary domain selection
- SSL certificate handling
- Domain uniqueness across tenants
- Subdomain availability checking
- Domain transfer workflows

**Recommended Test Files:**
- `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/tenant_admin/domains_spec.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/tenant_admin/subdomains_spec.rb`

---

### 2.5 Public Site Setup Controller
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/setup_controller.rb`
**Status:** NO TESTS
**Impact:** HIGH - Initial site provisioning

**Missing Test Scenarios:**
- Setup form displays available seed packs
- Subdomain validation and availability
- Website creation from seed pack
- Seed pack application (properties, pages, content)
- Redirect to home after successful setup
- Error handling for invalid seed packs
- Error handling for invalid subdomains
- Prevents setup if website already exists
- Proper error messages displayed to user

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/pwb/setup_spec.rb`

---

### 2.6 Public Contact Us Form
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/contact_us_controller.rb`
**Status:** NO TESTS
**Impact:** HIGH - Core lead generation

**Missing Test Scenarios:**
- Contact form loads with page content
- Contact form submission saves Contact and Message
- Email delivery to agency email address
- Auto-reply email to visitor
- Push notification via ntfy if enabled
- Form validation - required fields
- Error handling and error messages displayed
- Success message on successful submission
- Honeypot/spam protection
- Request metadata captured (IP, user agent, referer)
- Multi-tenancy isolation
- Message tagged with website and agency
- Structured logging for debugging

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/pwb/contact_us_spec.rb`

---

## Priority 3: Important Service & Model Tests (Medium Impact)

### 3.1 Email Template Renderer Service
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/email_template_renderer.rb`
**Status:** NO TESTS
**Impact:** MEDIUM - Email delivery reliability

**Missing Test Scenarios:**
- Render with custom template
- Render with default template
- Liquid variable substitution
- HTML to text conversion
- Template fallback when custom not found
- Variable escaping for HTML safety
- Missing variable handling
- Sample data generation for preview
- Default variables (website_name)
- All template types work correctly

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/services/pwb/email_template_renderer_spec.rb`

---

### 3.2 Provisioning Service - Email & Verification
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/provisioning_service.rb`
**Status:** PARTIAL - Some tests exist
**Impact:** HIGH - New customer onboarding

**Existing Tests:** Basic provisioning service spec exists
**Missing Test Scenarios:**
- Complete provisioning flow with email verification
- Subdomain reservation during signup
- Email verification email sent
- Multiple provisioning retries
- Error recovery and rollback
- Webhook handling for email verification
- Cross-step validation
- Seed pack variation testing
- Agency creation fallback when pack unavailable
- Link creation with all required attributes
- Field keys default creation
- Page seeding and content
- Property seeding from pack vs fallback
- Feature flag behaviors

**Recommended Addition:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/services/pwb/provisioning_integration_spec.rb`

---

### 3.3 Search Service & Filtering
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/search_params_service.rb`
**Status:** HAS TESTS
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/concerns/search/property_filtering.rb`
**Status:** NO TESTS
**Impact:** MEDIUM - Property search core functionality

**Missing Test Scenarios:**
- Property filtering by type (buy/rent)
- Price range filtering
- Bedroom/bathroom filtering
- Location/area filtering
- Feature filtering
- Search facets calculation
- URL parameter parsing and generation
- Empty/null parameter handling
- Multi-locale support in search
- Map markers generation for search results
- Pagination of search results
- Sorting by price, date, relevance

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/pwb/property_filtering_spec.rb`

---

### 3.4 MLS Connector Service
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/mls_connector.rb`
**Status:** NO TESTS
**Impact:** MEDIUM - External data integration

**Missing Test Scenarios:**
- MLS API connection and authentication
- Property data import from MLS
- Mapping MLS fields to internal models
- Update existing properties from MLS
- Handle MLS API errors gracefully
- Rate limiting compliance
- Data transformation and validation
- Scheduled sync job
- Error logging and alerts

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/services/pwb/mls_connector_spec.rb`

---

### 3.5 Firebase Authentication Service
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/firebase_auth_service.rb`
**Status:** HAS TESTS
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/firebase_token_verifier.rb`
**Status:** HAS TESTS
**Impact:** MEDIUM - Auth system

**Missing Test Scenarios (Likely):**
- Token refresh and renewal
- Token expiration handling
- Multi-tenant user isolation
- Custom claims verification
- Error responses for invalid tokens

---

## Priority 4: API Endpoint Coverage (Medium Impact)

### 4.1 API Endpoints with Missing/Incomplete Tests

**Public API Endpoints (Good Coverage):**
- /api/v1/properties - spec exists
- /api/v1/pages - spec exists
- /api/v1/site_details - spec exists
- /api/v1/translations - spec exists
- /api/v1/auth - spec exists
- /api/v1/links - spec exists

**PWB API Endpoints (Partial Coverage):**

| Endpoint | Controller | Test Status | Notes |
|----------|-----------|-------------|-------|
| /api/v1/lite_properties | lite_properties_controller | HAS TESTS | |
| /api/v1/properties | properties_controller | NO TESTS | |
| /api/v1/select_values | select_values_controller | NO TESTS | Dropdown options |
| /api/v1/mls | mls_controller | NO TESTS | MLS integration |
| /api/v1/web_contents | web_contents_controller (API) | NO TESTS | Content API |
| /api/v1/website | website_controller | NO TESTS | Website settings API |

**Recommended Test Files:**
- `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/pwb/api/properties_spec.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/pwb/api/select_values_spec.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/pwb/api/mls_spec.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/pwb/api/web_contents_spec.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/pwb/api/website_spec.rb`

---

## Priority 5: Model & Validation Tests (Medium Impact)

### 5.1 Subscription Model - State Machine
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/subscription.rb`
**Status:** HAS TESTS
**Impact:** HIGH - Business critical

Existing tests likely cover basic functionality, but verify comprehensive coverage of:
- All state transitions with guards
- Trial expiration guard conditions
- Feature access checks
- Remaining property calculations
- Plan change validation and logging

### 5.2 Plan Model
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/plan.rb`
**Status:** HAS TESTS
**Impact:** MEDIUM - Pricing structure

Verify tests cover:
- Feature flag activation/deactivation
- Property limit enforcement
- User limit enforcement
- Trial period handling
- Billing interval validation

### 5.3 Email Template Model
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/email_template.rb` (if exists)
**Status:** Unknown
**Impact:** MEDIUM

Ensure tests cover:
- Template key validation
- Variable substitution
- HTML/text generation
- Custom vs default behavior

---

## Priority 6: Integration & Flow Tests

### 6.1 End-to-End Setup Flow
**Current State:** NO INTEGRATION TEST
**Impact:** HIGH

**Scenario:** User signs up → Provisioning starts → Seed pack applied → Setup complete

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/integration/setup_flow_spec.rb`

**Test Scenario Outline:**
```
Given a new user at signup
When they complete signup process
Then their website is provisioned
And seed pack is applied
And they can access their site
```

---

### 6.2 Contact Form to Email Flow
**Current State:** NO INTEGRATION TEST
**Impact:** MEDIUM-HIGH

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/integration/contact_form_email_spec.rb`

**Test Scenario Outline:**
```
Given a user fills out contact form
When they submit
Then contact record is created
And message is saved
And email is queued for delivery
And notifier (ntfy) is triggered if enabled
```

---

### 6.3 Multi-Tenancy Isolation Verification
**Current State:** Some tests exist but incomplete
**Impact:** HIGH - Data security critical

**Recommended Enhancements:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/integration/multi_tenancy_comprehensive_spec.rb`

**Additional Scenarios to Test:**
- Cross-website data access prevention
- Scoped query isolation
- API endpoint isolation
- Admin access patterns
- User membership scoping
- Notification isolation
- Seed pack isolation

---

## Missing Test Categories

### View/Template Tests
**Current:** 6 view specs
**Missing:** 
- Property detail page rendering
- Search results page rendering
- Theme-specific page rendering
- Email template rendering (HTML and text)

### Mailer Tests
**Current:** Some mailer specs exist
**Missing:**
- Enquiry mailer integration
- Confirmation emails
- Notification emails
- Bulk email scenarios

### Job Tests
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/jobs/`
**Status:** Minimal coverage

**Missing Job Tests:**
- UpdateExchangeRatesJob
- RefreshPropertiesViewJob
- CleanupOrphanedBlobsJob
- Any NtfyNotificationJob comprehensive tests

**Recommended Test File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/jobs/`

### Helper Tests
**Current:** Some helper specs exist
**Status:** Mostly complete but verify:
- Locale helper
- Navigation helper
- Auth helper
- Site admin helper
- Tenant admin helper

---

## Test Infrastructure Gaps

### 1. E2E/Browser Testing
**Current State:** Playwright tests exist at `/tests/e2e/search.spec.js`
**Missing Scenarios:**
- Full setup flow with browser automation
- Contact form submission
- Login/authentication flow
- Admin dashboard navigation
- Property creation workflow
- Search and filter interactions

### 2. Performance Testing
**Current State:** None
**Recommended:** Load testing for:
- Search with large datasets
- Dashboard with many properties
- Analytics calculations
- Concurrent user access

### 3. Security Testing
**Current State:** Some authorization specs exist
**Missing:**
- CSRF protection verification
- SQL injection prevention
- XSS protection in templates
- API authentication edge cases
- Admin access control bypass attempts

---

## Recommendations by Timeline

### Week 1 (Quick Wins - 5-10 tests)
1. ✓ Site Admin Dashboard spec
2. ✓ Contact Us form integration test
3. ✓ Setup flow integration test
4. ✓ Email Template Renderer service test
5. ✓ Site Admin Analytics spec

### Week 2 (Core Features - 5 tests)
6. Tenant Admin Subscriptions management spec
7. Search filtering spec
8. Email template CRUD operations
9. Onboarding complete flow integration test
10. Activity logs spec

### Week 3 (Supporting Features - 5 tests)
11. Site Admin Contents management
12. Billing page spec
13. Domain/subdomain management
14. MLS connector service
15. API endpoint missing tests (lite_properties, web_contents, etc.)

### Ongoing (Low Priority - 10+ tests)
- View/template rendering tests
- Mailer comprehensive tests
- Job execution tests
- Browser automation tests
- Security validation tests

---

## Code Examples for Test Structure

### Request Spec Template (RSpec)
```ruby
# spec/requests/site_admin/dashboard_spec.rb
require 'rails_helper'

RSpec.describe "Site Admin Dashboard", type: :request do
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user, website: website) }
  let!(:membership) { create(:pwb_user_membership, user: user, website: website, role: 'admin') }

  before do
    sign_in user
  end

  describe "GET /site_admin/dashboard" do
    context "when user is admin" do
      it "returns successful response" do
        get "/site_admin"
        expect(response).to have_http_status(:success)
      end

      it "displays website statistics" do
        create_list(:pwb_realty_asset, 5, website: website)
        get "/site_admin"
        expect(response.body).to include("5")
      end

      it "isolates data by website" do
        other_website = create(:pwb_website)
        create_list(:pwb_realty_asset, 10, website: other_website)
        get "/site_admin"
        expect(response.body).to include("0") # Current website has 0 properties
      end
    end

    context "when user lacks admin access" do
      it "returns unauthorized" do
        membership.update(role: 'viewer')
        get "/site_admin"
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
```

### Service Spec Template
```ruby
# spec/services/pwb/email_template_renderer_spec.rb
require 'rails_helper'

RSpec.describe Pwb::EmailTemplateRenderer, type: :service do
  let(:website) { create(:pwb_website) }
  let(:renderer) { described_class.new(website: website, template_key: 'enquiry.general') }

  describe "#render" do
    it "renders with default template when custom not found" do
      variables = { visitor_name: "John", visitor_email: "john@example.com", message: "Hi" }
      result = renderer.render(variables)

      expect(result[:subject]).to include("John")
      expect(result[:body_html]).to include("Hi")
      expect(result[:body_text]).to include("Hi")
    end

    it "escapes HTML in variables" do
      variables = { message: "<script>alert('xss')</script>" }
      result = renderer.render(variables)

      expect(result[:body_html]).not_to include("<script>")
    end

    it "converts HTML to text for body_text" do
      variables = { message: "Test" }
      result = renderer.render(variables)

      expect(result[:body_text]).not_to include("<")
      expect(result[:body_text]).not_to include(">")
    end
  end

  describe "#custom_template_exists?" do
    it "returns true when custom template exists" do
      create(:pwb_email_template, website: website, template_key: 'enquiry.general')
      expect(renderer.custom_template_exists?).to be true
    end

    it "returns false when no custom template" do
      expect(renderer.custom_template_exists?).to be false
    end
  end
end
```

### Integration Spec Template
```ruby
# spec/integration/contact_form_email_spec.rb
require 'rails_helper'

RSpec.describe "Contact Form Email Flow", type: :integration do
  let(:website) { create(:pwb_website) }

  it "creates contact and sends email when form submitted" do
    expect {
      post "/contact-us", params: {
        contact: {
          name: "John Smith",
          email: "john@example.com",
          message: "Interested in your property"
        }
      }
    }.to change(Pwb::Contact, :count).by(1)
     .and change(Pwb::Message, :count).by(1)

    expect(ActionMailer::Base.deliveries).not_to be_empty
    last_email = ActionMailer::Base.deliveries.last
    expect(last_email.to).to include(website.agency.email_primary)
  end
end
```

---

## Testing Tools & Configuration

**Already in Use:**
- RSpec (unit/integration testing)
- FactoryBot (test data)
- Playwright (E2E testing)
- VCR (HTTP mocking)

**Recommended Additions:**
- Shoulda Matchers (enhanced matchers)
- Webmock (advanced HTTP mocking)
- Timecop/Freezegun (time travel)
- DatabaseCleaner (transaction management)

---

## Summary Table: Test Coverage by Module

| Module | Controllers | Test Coverage | Priority | Est. Tests Needed |
|--------|-------------|----------------|----------|-------------------|
| site_admin/dashboard | 1 | 0% | P1 | 15 |
| site_admin/analytics | 1 | 0% | P1 | 12 |
| site_admin/onboarding | 1 | 50% | P1 | 8 |
| site_admin/billing | 1 | 0% | P1 | 6 |
| site_admin/activity_logs | 1 | 0% | P1 | 10 |
| site_admin/email_templates | 1 | 0% | P1 | 12 |
| site_admin/contents | 1 | 0% | P1 | 8 |
| tenant_admin/subscriptions | 1 | 60% | P2 | 10 |
| tenant_admin/plans | 1 | 0% | P2 | 12 |
| tenant_admin/domains | 1 | 0% | P2 | 8 |
| pwb/setup | 1 | 0% | P2 | 10 |
| pwb/contact_us | 1 | 0% | P2 | 12 |
| Services | 20 | 60% | P3 | 8 |
| API endpoints | 12 | 50% | P4 | 15 |
| **TOTAL** | **~50+** | **~50%** | | **~166** |

---

## Risk Assessment

**High Risk (No Tests):**
- Dashboard statistics accuracy
- Analytics feature access
- Contact form submission
- Email delivery
- Setup provisioning
- Multi-tenancy data isolation

**Medium Risk (Partial Tests):**
- Onboarding flow
- Subscription management
- Search filtering
- API responses

**Low Risk (Good Tests):**
- Authentication
- Multi-tenancy scoping
- API public endpoints
- Model validations

---

## Next Steps

1. **Prioritize P1 items** - Focus on user-facing features and business-critical flows
2. **Create test templates** - Establish consistent patterns for new tests
3. **Set up CI metrics** - Track coverage improvements over time
4. **Code review practices** - Require tests for new features
5. **Schedule test sprints** - Allocate 20-30% of sprint capacity to testing
