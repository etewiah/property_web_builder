# PropertyWebBuilder E2E Testing Infrastructure Analysis

## Current E2E Testing Infrastructure Summary

### 1. Existing Infrastructure Overview

The PropertyWebBuilder project has **comprehensive testing infrastructure** already established, primarily using RSpec with Capybara for feature/integration testing. While the primary testing framework is RSpec (not Playwright), the infrastructure is well-configured and suitable for end-to-end testing.

#### Infrastructure Status:
- **Feature tests:** Fully implemented with 4 existing feature test files
- **Integration tests:** Extensive request specs (60+ test files)
- **Database config:** E2E-specific database configuration already present
- **Capybara drivers:** Multiple headless browser drivers available
- **Test helpers:** Authentication helpers, multi-tenant setup helpers available
- **Factory setup:** FactoryBot factories for all major models

---

## 2. Testing Gems Available

### Testing Framework & Drivers

| Gem | Version | Purpose |
|-----|---------|---------|
| **rspec-rails** | 8.0.2 | Primary testing framework |
| **capybara** | 3.40.0 | Feature/integration testing DSL |
| **apparition** | 0.6.0 | Headless Chrome driver for Capybara (via Chrome DevTools Protocol) |
| **poltergeist** | 1.18.1 | PhantomJS driver for Capybara (older, less recommended) |
| **selenium-webdriver** | 4.38.0 | Selenium WebDriver for browser automation |
| **factory_bot_rails** | Latest | Test data factory gem |
| **database_cleaner** | Latest | Database cleanup between tests |

### Supported Drivers for E2E Testing

1. **Apparition (Recommended)**
   - Uses Chrome DevTools Protocol (more modern)
   - Headless Chrome/Chromium
   - Currently configured in `spec/spec_helper.rb`
   - Good for CI/CD environments

2. **Poltergeist**
   - Uses PhantomJS (older technology)
   - Still available but less maintained
   - Configured but commented out in spec_helper.rb

3. **Selenium WebDriver**
   - Can use Chrome, Firefox, Safari, Edge
   - More heavyweight but more flexible
   - Useful for cross-browser testing

### Supporting Test Gems

```
gem "launchy"              # save_and_open_page for debugging
gem "vcr"                  # HTTP request recording/playback
gem "webmock"              # HTTP mocking
gem "simplecov"            # Code coverage
gem "shoulda-matchers"     # RSpec matchers
gem "json_spec"            # JSON matching helpers
gem "rails-controller-testing" # Controller testing support
gem "pry-byebug"           # Debugging
```

---

## 3. Database Configuration for E2E

### E2E Database Config (config/database.yml)

```yaml
e2e:
  <<: *default
  database: pwb_e2e
```

**Status:** Already configured! The database is set up for e2e environment.

### Running E2E Tests with Specific Database

```bash
RAILS_ENV=e2e bundle exec rspec --pattern spec/features/**/*_spec.rb
```

---

## 4. E2E Environment Configuration

### config/environments/e2e.rb

A dedicated e2e environment configuration file exists with:

**Key Features:**
- Fixed secret key base for consistent testing
- Reloading enabled (code changes take effect without restart)
- Eager loading disabled for faster boot
- Full error reporting enabled
- Caching disabled for consistent test behavior
- Local file storage for uploads
- Subdomain support for multi-tenant testing:
  - `.lvh.me` (local development domain)
  - `localhost`
  - `tenant-a.e2e.localhost`
  - `tenant-b.e2e.localhost`
- Debug logging to both file and stdout
- Mailer configured for localhost:3001

**Run Rails server in e2e mode:**
```bash
RAILS_ENV=e2e rails s -p 3001
```

---

## 5. Capybara Configuration

### Current Setup (spec/spec_helper.rb)

```ruby
require "capybara/apparition"

Capybara.register_driver :apparition do |app|
  options = {}
  Capybara::Apparition::Driver.new(app, options)
end
```

### Available Capybara Configurations

- **JavaScript driver:** Apparition (headless Chrome)
- **Default driver:** Rack Test (no JavaScript)
- **Headless mode:** Yes (no visible browser window)
- **Database cleaning:** Using DatabaseCleaner with truncation strategy for JS tests

### Database Cleaning Strategy

```ruby
config.before(:each, js: true) do
  # truncation is slower but more reliable for JS tests
  DatabaseCleaner.strategy = :truncation
end
```

---

## 6. Existing Feature Test Examples

### a) Sessions/Authentication Tests
**File:** `spec/features/pwb/sessions_spec.rb`

Tests user sign-in functionality with multi-tenant awareness:
- Valid credentials sign-in
- Invalid password handling
- Subdomain-based tenant isolation

**Key Patterns:**
```ruby
before(:each) do
  Capybara.app_host = 'http://test-sessions.example.com'
end

scenario 'with valid credentials' do
  visit('/users/sign_in')
  fill_in('Email', with: @admin_user.email)
  fill_in('Password', with: @admin_user.password)
  click_button('Sign in')
  expect(current_path).to include("/admin")
end
```

### b) Contact Form Tests
**File:** `spec/features/pwb/contact_forms_spec.rb`

Tests form submissions on frontend:
- General contact form
- Property-specific contact form
- Form submission success messages

### c) Theme Rendering Tests
**File:** `spec/features/pwb/theme_rendering_spec.rb`

Tests HTML/CSS rendering across pages:
- Hero section rendering
- Services section rendering
- CSS class presence verification
- Dynamic content from PageParts

**Key Pattern:**
```ruby
scenario 'Home page renders with semantic CSS classes' do
  visit('/')
  expect(page).to have_css('.hero-section')
  expect(page).to have_css('.hero-title', text: 'Welcome to Springfield')
end
```

### d) Admin Panel Tests (Pending)
**File:** `spec/features/pwb/admin_spec.rb`

Currently marked as pending - needs fixing for Travis CI compatibility.

---

## 7. Test Setup & Helper Methods

### Feature Helpers (spec/support/feature_helpers.rb)

```ruby
module FeatureHelpers
  def sign_in_as(email, password)
    Capybara.raise_server_errors = false
    visit('/admin')
    fill_in('Email', with: email)
    fill_in('Password', with: password)
    click_button('Sign in')
  end
end

# Included in RSpec via: config.include FeatureHelpers, type: :feature
```

### Request Spec Helpers (for API testing)

```ruby
def sign_in(resource)
  login_as(resource, scope: :user)
end

def response_body_as_json
  JSON.parse(response.body)
end
```

### Database Cleaner Setup (spec/spec_helper.rb)

```ruby
config.before(:suite) do
  DatabaseCleaner.clean_with(:truncation)
end

config.before(:each, js: true) do
  DatabaseCleaner.strategy = :truncation  # More reliable for JS
end

config.before(:each) do
  DatabaseCleaner.start
end

config.after(:each) do
  DatabaseCleaner.clean
end
```

---

## 8. Factory Setup for Test Data

### User Factory (spec/factories/pwb_users.rb)

```ruby
factory :pwb_user, class: 'Pwb::User' do
  sequence(:email) { |n| "user#{n}@example.com" }
  password { 'password123' }
  association :website, factory: :pwb_website
  
  trait :admin do
    admin { true }
  end
end
```

### Website Factory (spec/factories/pwb_websites.rb)

```ruby
factory :pwb_website, class: 'Pwb::Website' do
  sequence(:subdomain) { |n| "tenant#{n}" }
  company_display_name { 'Test Company' }
  theme_name { 'default' }
  default_currency { 'EUR' }
  # ... more attributes
  
  after(:create) do |website|
    # Auto-creates agency for multi-tenant isolation
    agency = Pwb::Agency.create!(...)
    website.update(agency: agency)
  end
end
```

### Available Factories

- `pwb_user` with `:admin` trait
- `pwb_website` (auto-creates agency)
- `pwb_agency`
- `pwb_page`
- `pwb_prop` with `:sale` trait
- `pwb_address`
- `pwb_translation`
- `pwb_page_part`
- And 15+ more model factories

---

## 9. RSpec Configuration

### .rspec File

```
--color
--require byebug
--require spec_helper
```

### RSpec Configuration (spec/rails_helper.rb)

- Includes Devise test helpers for authentication
- Includes FeatureHelpers for feature specs
- Uses transactional fixtures by default
- Infers spec type from file location

### Test File Organization

```
spec/
├── features/              # Feature/integration tests (Capybara)
│   └── pwb/
│       ├── admin_spec.rb
│       ├── sessions_spec.rb
│       ├── contact_forms_spec.rb
│       └── theme_rendering_spec.rb
├── requests/              # API/request tests (60+ files)
├── models/                # Unit tests
├── controllers/           # Controller tests
├── support/               # Test helpers
│   ├── feature_helpers.rb
│   ├── request_spec_helpers.rb
│   ├── controller_helpers.rb
│   └── vcr_setup.rb
├── factories/             # FactoryBot definitions
└── rails_helper.rb        # RSpec Rails configuration
```

---

## 10. Multi-Tenancy Support in Tests

The project is multi-tenant, and test infrastructure includes:

### Subdomain-Based Tenant Testing

```ruby
before(:each) do
  Capybara.app_host = 'http://test-sessions.example.com'
end

# This allows testing tenant isolation
```

### Database Scoping

Factories include `website` associations:
```ruby
let!(:website) { FactoryBot.create(:pwb_website) }
let!(:user) { FactoryBot.create(:pwb_user, website: website) }
```

### Multi-Tenant Configuration in E2E Environment

The e2e.rb environment config includes:
```ruby
config.hosts << ".lvh.me"
config.hosts << "localhost"
config.hosts << "tenant-a.e2e.localhost"
config.hosts << "tenant-b.e2e.localhost"
```

---

## 11. Running E2E Tests

### Run All Feature Tests

```bash
bundle exec rspec spec/features/
```

### Run Specific Feature Test File

```bash
bundle exec rspec spec/features/pwb/sessions_spec.rb
```

### Run Feature Tests with E2E Database

```bash
RAILS_ENV=e2e bundle exec rspec spec/features/
```

### Run Feature Tests with Debug Output

```bash
bundle exec rspec spec/features/ -f documentation
```

### Run Feature Tests with JS Driver (Apparition)

Tests tagged with `js: true` automatically use Apparition:
```ruby
RSpec.describe "Something", type: :feature, js: true do
  # Uses Apparition headless Chrome
end
```

### Run Feature Tests with Server Running

If you need a running server (less common with feature tests):
```bash
# Terminal 1: Start server in e2e mode
RAILS_ENV=e2e rails s -p 3001

# Terminal 2: Run tests pointing to that server
CAPYBARA_SERVER_HOST=localhost CAPYBARA_SERVER_PORT=3001 \
  bundle exec rspec spec/features/
```

---

## 12. Debugging E2E Tests

### Save and Open Page

The `launchy` gem is installed, allowing:
```ruby
save_and_open_page  # Opens current page in browser
```

### Take Screenshots

```ruby
save_screenshot('path/to/screenshot.png')
```

### Pause Test Execution

```ruby
require 'pry'
binding.pry
```

### Enable Debug Logging

```ruby
Capybara.raise_server_errors = false  # Prevents errors from halting tests
```

### View Server Logs

When running tests, check:
```bash
tail -f log/test.log       # Test mode logs
tail -f log/e2e.log        # E2E mode logs
```

---

## 13. Known Issues & Limitations

### 1. Admin Panel Tests Currently Broken
- File: `spec/features/pwb/admin_spec.rb`
- Status: Marked as pending
- Issue: Fails on Travis CI due to asset loading issues
- Fix needed: Investigate asset precompilation in CI environment

### 2. Apparition Version Constraint
- Apparition 0.6.0 requires Capybara 3.13 (older version)
- May need to upgrade both for newer Chrome versions

### 3. PhantomJS/Poltergeist Deprecated
- PhantomJS development has stopped
- Poltergeist is not actively maintained
- Apparition or Selenium preferred for new tests

### 4. JavaScript Testing
- Some feature tests skip JavaScript (`type: :feature` without `js: true`)
- JS-enabled tests use truncation (slower database cleaning)

---

## 14. Architecture Decisions

### Why RSpec + Capybara vs Playwright?

The project chose RSpec + Capybara for these reasons:

**Advantages:**
- Integrated with Rails testing ecosystem
- Shared database and factories with unit/integration tests
- Simpler setup for Rails applications
- Easy to mix with request specs and model specs
- No separate test runner or fixture system needed

**Trade-offs vs Playwright:**
- Less modern compared to Playwright
- No advanced browser APIs in Apparition
- Fewer CI/CD integrations
- Less suitable for cross-browser testing at scale

### Multi-Tenant Testing Approach

The infrastructure supports multi-tenant testing through:
1. **Factory-level scoping:** All models associated with website
2. **Subdomain-based testing:** E2E environment supports `.lvh.me` and custom localhost subdomains
3. **Database isolation:** DatabaseCleaner ensures clean state between tests

---

## 15. Next Steps for E2E Enhancement

### Short Term
1. Fix the broken admin_spec.rb tests
2. Add more feature tests for critical user journeys
3. Improve documentation for E2E testing workflows

### Medium Term
1. Consider upgrading Capybara/Apparition to support newer Chrome features
2. Add E2E tests for multi-tenant scenarios
3. Implement visual regression testing (optional)

### Long Term
1. Consider migration to Playwright if requirements change
2. Integrate E2E tests into CI/CD pipeline
3. Add performance benchmarking for E2E tests

---

## 16. Quick Reference Commands

```bash
# Setup
bundle install

# Run all feature tests
bundle exec rspec spec/features/

# Run with specific pattern
bundle exec rspec spec/features/pwb/sessions_spec.rb

# Run with full output
bundle exec rspec spec/features/ -f documentation

# Run with failure details
bundle exec rspec spec/features/ --format RspecJunitXmlFormatter --out rspec.xml

# Clean test database
RAILS_ENV=test bundle exec rake db:drop db:create db:migrate

# Start server for manual testing
RAILS_ENV=e2e rails s -p 3001

# Run feature tests with e2e database
RAILS_ENV=e2e bundle exec rspec spec/features/
```

---

## Summary

PropertyWebBuilder has **well-established E2E testing infrastructure** based on RSpec + Capybara with:

- ✅ 4 existing feature test files (good examples)
- ✅ Multiple browser drivers available (Apparition, Selenium, Poltergeist)
- ✅ E2E-specific database and environment configuration
- ✅ Comprehensive factory setup for test data
- ✅ Multi-tenant testing support
- ✅ Test helpers for authentication and setup
- ✅ Database cleaning strategy optimized for different test types
- ⚠️ Admin panel tests currently pending (needs fixing)
- ⚠️ Older Capybara/Apparition versions (consider upgrade)

The infrastructure is **production-ready** and can be used immediately for writing new E2E tests following the existing patterns.
