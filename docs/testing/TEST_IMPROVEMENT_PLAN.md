# Test Coverage Improvement Plan

**Date:** 2026-02-21
**Status:** PLANNING
**Priority:** 🟠 Medium / 🟡 Low
**Related:** [Master Plan](../planning/CODE_REVIEW_2026_02_MASTER_PLAN.md)

---

## Current State

**Strengths:**
- 85+ model specs with FactoryBot
- 120+ request specs
- Dedicated multi-tenancy isolation spec (`spec/requests/api_public/v1/cross_tenant_isolation_spec.rb`)
- Auth flow coverage (Devise, Firebase, OAuth)
- Cross-tenant security tests

**Gaps identified in this review:**
- `SetupController` has no security/rate-limit tests
- `Contact#unread_messages_count` N+1 not caught by tests
- Liquid template injection not tested
- Deprecated browser drivers still in Gemfile

---

## Issue Q1 — Remove Deprecated Browser Test Drivers

### Severity: 🟡 Low

### Description

The `Gemfile` contains three deprecated/unwanted browser automation dependencies that conflict with the project's stated direction (Playwright only, per `CLAUDE.md`):

```ruby
gem "apparition"          # Deprecated headless Chrome driver for Capybara
gem "poltergeist"         # PhantomJS-based Capybara driver (PhantomJS is EOL)
gem "selenium-webdriver"  # Selenium (CLAUDE.md explicitly says "Do NOT use")
```

These create confusion, add unnecessary dependencies, and could accidentally be used in new tests.

### Proposed Fix

**Step 1: Check if any specs use these drivers**

```bash
grep -rn "Capybara.javascript_driver" spec/
grep -rn ":apparition" spec/
grep -rn ":poltergeist" spec/
grep -rn "selenium" spec/
grep -rn "js: true" spec/  # per CLAUDE.md, should be zero
```

**Step 2: If no specs use them, remove from Gemfile**

```ruby
# Remove these lines:
gem "apparition"
gem "poltergeist"
gem "selenium-webdriver"
```

**Step 3: Check spec_helper/rails_helper for driver config**

```bash
grep -rn "Capybara.default_driver" spec/
grep -rn "Capybara.javascript_driver" spec/
grep -rn "driven_by" spec/support/
```

Remove any configuration that references these drivers.

**Step 4: Ensure Playwright is the documented E2E approach**

Reference: `docs/testing/PLAYWRIGHT_TESTING.md` (already exists).

### Implementation Steps

1. Run greps above to confirm zero usage of deprecated drivers
2. Remove gems from `Gemfile`
3. Run `bundle install`
4. Run `rspec` to confirm nothing broke
5. Clean up any `spec/support/` configuration referencing old drivers

### Acceptance Criteria

- [ ] `apparition`, `poltergeist`, `selenium-webdriver` removed from Gemfile
- [ ] No specs use `js: true` or reference the old drivers
- [ ] `bundle install` succeeds
- [ ] `rspec` passes

---

## Issue Q2 — Missing: SetupController Security Tests

### Severity: 🟠 Medium

### Description

`SetupController` handles new website creation without authentication. There are no tests verifying:
- That anonymous access is properly handled
- That rate limiting works (once implemented per Security Plan S1)
- That malformed requests are rejected cleanly
- That successful setup creates a properly isolated tenant

### New Spec to Create

**File**: `spec/requests/pwb/setup_controller_spec.rb`

```ruby
require "rails_helper"

RSpec.describe "Pwb::SetupController", type: :request do
  describe "GET /setup" do
    it "returns 200 for unauthenticated users" do
      get pwb_setup_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /setup" do
    let(:valid_params) do
      {
        website: {
          subdomain: "testsite-#{SecureRandom.hex(4)}",
          email: "owner@example.com",
          name: "Test Site"
        }
      }
    end

    context "with valid params" do
      it "creates a new website" do
        expect {
          post pwb_setup_path, params: valid_params
        }.to change(Pwb::Website, :count).by(1)
      end

      it "scopes the new website as a proper tenant" do
        post pwb_setup_path, params: valid_params
        website = Pwb::Website.last
        expect(website.subdomain).to be_present
        expect(website.id).to be_present
      end
    end

    context "with duplicate subdomain" do
      let!(:existing) { create(:website, subdomain: "taken") }

      it "rejects duplicate subdomain with 422" do
        post pwb_setup_path, params: valid_params.deep_merge(website: { subdomain: "taken" })
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "rate limiting" do
      it "returns 429 after too many attempts from same IP" do
        # Only meaningful after S1 (rack-attack rule) is implemented
        4.times do
          post pwb_setup_path, params: valid_params.deep_merge(
            website: { subdomain: "test-#{SecureRandom.hex(4)}" }
          )
        end
        # Fourth attempt should be throttled
        expect(response).to have_http_status(:too_many_requests)
      end
    end

    context "with invalid params" do
      it "rejects missing subdomain" do
        post pwb_setup_path, params: { website: { email: "owner@example.com" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
```

**Note**: Rate limiting test only becomes meaningful after Security Issue S1 is implemented.

### Implementation Steps

1. Read `app/controllers/pwb/setup_controller.rb` to understand routes/actions
2. Run `rails routes | grep setup` to get correct path helpers
3. Create `spec/requests/pwb/setup_controller_spec.rb`
4. Run the spec and fix any failures
5. Add rate-limiting test once rack-attack rule is added (S1)

### Acceptance Criteria

- [ ] Spec file exists and passes
- [ ] Tests cover happy path, duplicate subdomain, and invalid params
- [ ] Rate limit test added (initially pending until S1 implemented)

---

## Issue Q3 — Missing: N+1 Regression Tests

### Severity: 🟡 Low

### Description

The N+1 issues in `Contact#unread_messages_count` and API auth were not caught by existing tests because:
1. Tests don't assert query count
2. Tests mock at controller level, not exercising the actual DB queries
3. Bullet gem is configured for development but not connected to test suite

### Add Bullet to Test Suite

**File**: `spec/support/bullet.rb`

```ruby
# spec/support/bullet.rb
if Bullet.enable?
  Bullet.start_request

  RSpec.configure do |config|
    config.before(:each) do
      Bullet.start_request
    end

    config.after(:each) do
      bullet_error = Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
      raise bullet_error if bullet_error
    end
  end
end
```

**File**: `spec/rails_helper.rb`

```ruby
# Add near the top of spec/rails_helper.rb
require "support/bullet"
```

### Add Query Count Specs for Key N+1 Hotspots

**File**: `spec/models/pwb/contact_spec.rb` (add to existing file)

```ruby
describe "#unread_messages_count" do
  let(:website) { create(:website) }
  let!(:contacts) { create_list(:contact, 5, website: website) }

  before do
    contacts.each do |contact|
      create_list(:message, 3, contact: contact, website: website, read: false)
      create_list(:message, 2, contact: contact, website: website, read: true)
    end
  end

  it "does not fire N+1 queries when called on a collection" do
    # Preload contacts
    loaded_contacts = website.contacts.to_a

    query_count = 0
    counter = ->(*, **) { query_count += 1 }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      loaded_contacts.each(&:unread_messages_count)
    end

    # Should be 0 or 1 queries (cached column), not N queries
    expect(query_count).to be <= 1
  end

  it "returns the correct count" do
    expect(contacts.first.unread_messages_count).to eq(3)
  end

  it "decrements when a message is marked as read" do
    message = contacts.first.messages.where(read: false).first
    expect {
      message.update!(read: true)
    }.to change { contacts.first.reload.unread_messages_count }.by(-1)
  end
end
```

### Add Query Count Spec for API Auth

**File**: `spec/requests/api_manage/v1/base_controller_spec.rb` (add to existing file)

```ruby
describe "API authentication query count" do
  let(:website) { create(:website) }
  let!(:integrations) { create_list(:integration, 10, website: website, enabled: true) }
  let(:api_key) { "test-api-key-abc123" }

  before do
    # Set api_key on the last integration
    integrations.last.set_credential("api_key", api_key)
  end

  it "authenticates with a bounded number of queries" do
    query_count = 0
    counter = ->(*, **) { query_count += 1 }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get api_manage_v1_some_endpoint_path,
          headers: { "X-API-Key" => api_key, "Host" => "#{website.subdomain}.example.com" }
    end

    # Should NOT scale with number of integrations
    expect(query_count).to be < 5
  end
end
```

### Implementation Steps

1. Check if `spec/support/bullet.rb` exists; create if not
2. Add Bullet configuration to enable in test environment
3. Add N+1 spec to `spec/models/pwb/contact_spec.rb`
4. Add query count spec for API auth
5. Run specs — they should FAIL before P1/P2 fixes, PASS after

### Acceptance Criteria

- [ ] Bullet is active in test suite
- [ ] N+1 regressions are caught automatically
- [ ] Query count specs exist for `Contact#unread_messages_count`
- [ ] Query count spec exists for API authentication

---

## Issue Q4 — Missing: Liquid Template Safety Tests

### Severity: 🟡 Low

### Description

No tests verify that Liquid template rendering is safe against injection. This should be addressed after the Liquid audit (Security Issue S4).

### Proposed Tests (after S4 audit)

**File**: `spec/services/pwb/liquid_rendering_spec.rb` (new file)

```ruby
require "rails_helper"

RSpec.describe "Liquid template rendering security" do
  let(:website) { create(:website) }

  describe "user-controlled content in templates" do
    it "does not execute Liquid tags from user-supplied property data" do
      # Malicious content in a property title
      malicious_title = "{{ site.pages | map: 'id' }}"
      property = create(:realty_asset, website: website, title: malicious_title)

      template = "Property: {{ property.title }}"
      result = render_liquid(template, { "property" => property.to_liquid })

      # Should render the literal string, not evaluate the nested Liquid
      expect(result).to include(malicious_title)
      expect(result).not_to include(website.pages.map(&:id).to_s)
    end

    it "does not expose internal model attributes through drops" do
      property = create(:realty_asset, website: website)
      drop = PropertyDrop.new(property)  # Adjust class name as needed

      # website_id should not be accessible via Liquid
      template = "{{ property.website_id }}"
      result = render_liquid(template, { "property" => drop })

      expect(result).to be_blank
    end
  end

  private

  def render_liquid(template_string, assigns = {})
    template = Liquid::Template.parse(template_string)
    template.render(assigns)
  end
end
```

### Implementation Steps

1. Complete S4 audit first (understand what surfaces exist)
2. Create spec file based on audit findings
3. Run spec to establish baseline
4. Fix any failures found

### Acceptance Criteria

- [ ] Liquid security spec exists
- [ ] User-supplied content cannot evaluate as Liquid code
- [ ] Drop objects don't expose internal attributes

---

## Full Testing Checklist

| Issue | Sprint | Status |
|-------|--------|--------|
| Q1 — Remove deprecated browser drivers | Sprint 4 | ⬜ TODO |
| Q2 — SetupController security tests | Sprint 3 | ⬜ TODO |
| Q3 — N+1 regression coverage (Bullet in tests) | Sprint 2 | ⬜ TODO |
| Q4 — Liquid template safety tests | Sprint 3 | ⬜ TODO |

---

## General Testing Standards to Enforce

Per `CLAUDE.md`:

1. **No `js: true` in feature specs** — Use request specs instead
2. **Playwright for E2E** — Not Capybara JS drivers
3. **Every bug fix must include a test** — See CLAUDE.md "Bug Fixing and Test Coverage"
4. **Multi-tenancy isolation must be tested** — Add to CI gate

### CI Gate Recommendations

Ensure the following run in CI:
```bash
rspec spec/requests/api_public/v1/cross_tenant_isolation_spec.rb  # Must pass
rspec spec/models/                                                  # Must pass
bundle exec brakeman --no-pager                                     # Security scan
```
