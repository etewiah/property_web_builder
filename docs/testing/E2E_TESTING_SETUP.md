# E2E Testing Infrastructure Setup & Configuration

## Overview

This document details how the E2E testing infrastructure is configured in PropertyWebBuilder and how to extend it.

## Architecture

```
┌─────────────────────────────────────────────────┐
│   RSpec Test Suite                              │
│   spec/features/**/*_spec.rb                    │
└────────────┬────────────────────────────────────┘
             │
             ├──► spec/rails_helper.rb (RSpec config)
             ├──► spec/spec_helper.rb (feature setup)
             └──► spec/support/** (helpers & fixtures)
                  ├── feature_helpers.rb
                  ├── controller_helpers.rb
                  └── vcr_setup.rb

             ├──► Factories (spec/factories/**)
             │    └── Create test data
             │
             ├──► Database Cleaner
             │    └── Ensures clean state
             │
             └──► Capybara + Apparition
                  ├── Browser automation
                  ├── Forms & navigation
                  └── Assertions

┌─────────────────────────────────────────────────┐
│   Application Layer                             │
│   Rails 8.0 + PostgreSQL                        │
│   Multi-tenant architecture                     │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│   Test Database (pwb_test or pwb_e2e)          │
│   PostgreSQL - Clean state per test             │
└─────────────────────────────────────────────────┘
```

## Configuration Files

### 1. spec/rails_helper.rb

**Purpose:** Main RSpec Rails configuration

**Key Settings:**
```ruby
ENV["RAILS_ENV"] ||= "test"

# Load RSpec framework
require "rspec/rails"
require "devise"
require "rails-controller-testing"

# Configure Capybara
RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include FeatureHelpers, type: :feature
  config.include RequestSpecHelpers, type: :request
end
```

**What it does:**
- Loads Rails test environment
- Includes Devise testing helpers
- Registers custom test helpers for different spec types
- Enables transactional fixtures for database isolation

### 2. spec/spec_helper.rb

**Purpose:** Capybara and feature testing setup

**Key Components:**

#### SimpleCov (Code Coverage)
```ruby
require "simplecov"
SimpleCov.start :rails do
  add_filter do |source_file|
    source_file.lines.count < 5  # Ignore tiny files
  end
end
```

#### Capybara Apparition (Headless Chrome)
```ruby
require "capybara/apparition"

Capybara.register_driver :apparition do |app|
  options = {}
  Capybara::Apparition::Driver.new(app, options)
end
```

#### Database Cleaner
```ruby
config.before(:each, js: true) do
  DatabaseCleaner.strategy = :truncation  # Slower but reliable for JS
end

config.before(:each) do
  DatabaseCleaner.start
end

config.after(:each) do
  DatabaseCleaner.clean
end
```

**What it does:**
- Sets up headless Chrome browser driver
- Configures database cleanup strategy
- Enables code coverage tracking
- Loads all support files

### 3. .rspec

**Purpose:** RSpec command-line defaults

```
--color                    # Colorized output
--require byebug           # Load debugger
--require spec_helper      # Load spec_helper automatically
```

### 4. config/environments/e2e.rb

**Purpose:** Environment config for E2E testing

**Key Settings:**

```ruby
# Code reloading for development-like testing
config.enable_reloading = true
config.eager_load = false

# Disable caching for consistent test behavior
config.action_controller.perform_caching = false
config.cache_store = :null_store

# Mailer configuration
config.action_mailer.default_url_options = { 
  host: "localhost", 
  port: 3001 
}

# Multi-tenant domain support
config.hosts << ".lvh.me"
config.hosts << "localhost"
config.hosts << "tenant-a.e2e.localhost"
config.hosts << "tenant-b.e2e.localhost"

# Debug logging
config.logger = ActiveSupport::BroadcastLogger.new(
  file_logger,     # Log to file
  stdout_logger    # Log to console
)
config.log_level = :debug
```

**What it does:**
- Provides an isolated environment for E2E tests
- Allows testing with code reloading
- Enables subdomain testing for multi-tenant features
- Logs to both file and console

### 5. config/database.yml

**E2E Database Configuration:**
```yaml
e2e:
  <<: *default
  database: pwb_e2e
```

**What it does:**
- Defines separate database for E2E tests
- Keeps E2E data isolated from unit/integration tests
- Uses same PostgreSQL connection as other environments

## Test Data Management

### Factory Bot Structure

```
spec/factories/
├── pwb_users.rb           # User accounts
├── pwb_websites.rb        # Tenants/websites
├── pwb_agencies.rb        # Real estate agencies
├── pwb_props.rb           # Property listings
├── pwb_pages.rb           # Web pages
├── pwb_page_parts.rb      # Page content blocks
├── pwb_addresses.rb       # Addresses
├── pwb_translations.rb    # Translations
└── ...
```

### Factory Definitions Pattern

```ruby
FactoryBot.define do
  factory :pwb_user, class: 'Pwb::User' do
    # Required attributes
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    association :website, factory: :pwb_website
    
    # Optional traits for variations
    trait :admin do
      admin { true }
    end
    
    trait :inactive do
      confirmed_at { nil }
    end
  end
end
```

### Using Factories in Tests

```ruby
# Create single object
user = FactoryBot.create(:pwb_user)

# Create with custom attributes
admin = FactoryBot.create(:pwb_user, :admin, email: 'admin@example.com')

# Use in before(:each) block
before(:each) do
  @user = FactoryBot.create(:pwb_user)
end

# Use with let! (created before test)
let!(:user) { FactoryBot.create(:pwb_user) }

# Build without saving (for testing validations)
user = FactoryBot.build(:pwb_user)
```

## Database Cleaning Strategy

### Strategy Selection

```ruby
# Default: Transaction strategy (fast, simple)
config.before(:each) do
  DatabaseCleaner.strategy = :transaction
end

# For JavaScript tests: Truncation strategy (slower, more reliable)
config.before(:each, js: true) do
  DatabaseCleaner.strategy = :truncation
end

# Before entire test suite
config.before(:suite) do
  DatabaseCleaner.clean_with(:truncation)
end

# After each test
config.after(:each) do
  DatabaseCleaner.clean
end
```

**Why the difference:**
- **Transaction:** Fast, rolls back database changes at end of test
  - Problem: JavaScript tests run in separate thread, can't see transaction rollback
  
- **Truncation:** Slower, but deletes all data (visible to all threads)
  - Used for JS tests where Capybara/Apparition runs in separate thread

## Multi-Tenancy in Tests

### Tenant Scoping Pattern

```ruby
# 1. Create website (tenant)
website = FactoryBot.create(:pwb_website, subdomain: 'acme')

# 2. Create records scoped to that website
user = FactoryBot.create(:pwb_user, website: website)
agency = FactoryBot.create(:pwb_agency, website: website)
prop = FactoryBot.create(:pwb_prop, website: website)

# 3. All records are automatically scoped
# User can only see properties in their website
```

### Subdomain Testing

```ruby
# Test tenant isolation via subdomains
scenario 'different tenants see different data' do
  # Create two tenants
  acme = FactoryBot.create(:pwb_website, subdomain: 'acme')
  globex = FactoryBot.create(:pwb_website, subdomain: 'globex')
  
  prop_acme = FactoryBot.create(:pwb_prop, website: acme)
  prop_globex = FactoryBot.create(:pwb_prop, website: globex)
  
  # Test ACME tenant
  Capybara.app_host = 'http://acme.example.com'
  visit("/properties/#{prop_acme.id}")
  expect(page).to have_content(prop_acme.title)
  
  # Test GLOBEX tenant
  Capybara.app_host = 'http://globex.example.com'
  visit("/properties/#{prop_globex.id}")
  expect(page).to have_content(prop_globex.title)
  
  # Reset
  Capybara.app_host = nil
end
```

### Multi-Tenant Domain Support in E2E

The e2e.rb environment allows these domain patterns:

```ruby
config.hosts << ".lvh.me"              # *.lvh.me (all subdomains)
config.hosts << "localhost"            # localhost (main domain)
config.hosts << "tenant-a.e2e.localhost"  # Specific subdomain
config.hosts << "tenant-b.e2e.localhost"  # Another subdomain
```

**Using in tests:**
```ruby
# .lvh.me approach (most flexible)
Capybara.app_host = 'http://tenant-name.lvh.me'

# Or with custom setup in e2e.rb
Capybara.app_host = 'http://tenant-a.e2e.localhost'
```

## Test Helpers

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

# Automatically included in feature specs
# Usage:
RSpec.describe "Something", type: :feature do
  scenario 'test' do
    sign_in_as('user@example.com', 'password')
  end
end
```

### Request Spec Helpers (spec/support/request_spec_helpers.rb)

```ruby
module RequestSpecHelpers
  include Warden::Test::Helpers
  
  def sign_in(resource)
    scope = Devise::Mapping.find_scope!(resource.class)
    login_as(resource, scope: scope)
  end
  
  def response_body_as_json
    JSON.parse(response.body)
  end
end

# Usage in request specs:
RSpec.describe "API", type: :request do
  it 'authenticates user' do
    user = FactoryBot.create(:pwb_user)
    sign_in(user)
    get '/api/users'
    expect(response).to be_successful
  end
end
```

## Running Tests

### Command Examples

```bash
# Run all feature tests
bundle exec rspec spec/features/

# Run specific file
bundle exec rspec spec/features/pwb/sessions_spec.rb

# Run specific test (by line number)
bundle exec rspec spec/features/pwb/sessions_spec.rb:25

# Run with different output format
bundle exec rspec spec/features/ --format documentation
bundle exec rspec spec/features/ --format json --out rspec.json

# Run with failure details
bundle exec rspec spec/features/ --backtrace --fail-fast

# Run with code coverage
bundle exec rspec spec/features/
# Check coverage: open coverage/index.html
```

### Environment Variables

```bash
# Use e2e database
RAILS_ENV=e2e bundle exec rspec spec/features/

# Disable raise on server errors (for debugging)
CAPYBARA_RAISE_SERVER_ERRORS=false bundle exec rspec spec/features/

# Set JavaScript driver explicitly
CAPYBARA_JAVASCRIPT_DRIVER=apparition bundle exec rspec spec/features/

# Run with verbose logging
DEBUG=true bundle exec rspec spec/features/
```

## Adding New Feature Tests

### 1. Create Test File

```ruby
# spec/features/pwb/my_feature_spec.rb
require 'rails_helper'

module Pwb
  RSpec.describe "My Feature", type: :feature do
    # Test body
  end
end
```

### 2. Set Up Test Data

```ruby
before(:each) do
  @website = FactoryBot.create(:pwb_website)
  @user = FactoryBot.create(:pwb_user, :admin, website: @website)
end
```

### 3. Write Scenarios

```ruby
scenario 'user can perform action' do
  # Test implementation
end
```

### 4. Run Test

```bash
bundle exec rspec spec/features/pwb/my_feature_spec.rb
```

## Debugging Tests

### Interactive Debugging

```ruby
require 'pry'

scenario 'debug test' do
  visit('/page')
  binding.pry  # Pauses here, drops into debugger
  # Now you can inspect page, try commands, etc.
end
```

### Save Page for Inspection

```ruby
scenario 'save page debug' do
  visit('/page')
  save_and_open_page  # Opens page in browser
end
```

### Print Page HTML

```ruby
scenario 'inspect html' do
  visit('/page')
  puts page.html  # Print full page HTML to console
  puts page.body  # Alternative
end
```

### Find Elements

```ruby
# Print all buttons
page.all('button').each { |btn| puts "#{btn.text} -> #{btn['id']}" }

# Print all links
page.all('a').each { |link| puts "#{link.text} -> #{link['href']}" }

# Find by text
element = page.find(:text, 'Click me')
```

### Network Inspection

For debugging AJAX/API calls:

```ruby
# Use save_and_open_page and inspect network tab in browser
save_and_open_page

# Or add debugging in your test
scenario 'with network inspection' do
  visit('/page')
  
  # Manually check requests
  # (Open developer console with Apparition)
  
  click_button('Load Data')
  
  # Wait for and inspect result
  expect(page).to have_content('Data loaded', wait: 5)
end
```

## Performance Considerations

### Slow Tests

```ruby
# JavaScript tests are slower - avoid when possible
scenario 'fast test' do  # Uses transaction, fast
  visit('/page')
  expect(page).to have_content('text')
end

scenario 'slow test', js: true do  # Uses truncation, slow
  visit('/page')
  find('.dynamic-element')  # JS required
end
```

### Optimize Test Data Creation

```ruby
# Bad: Create in each test
before(:each) do
  @website = FactoryBot.create(:pwb_website)
end

# Better: Create once for all tests in group
before(:all) do
  @website = FactoryBot.create(:pwb_website)
end

# Then clean up after
after(:all) do
  @website.destroy
end
```

### Reuse Factories

```ruby
# Bad: Separate creation per test
scenario 'test 1' do
  user = FactoryBot.create(:pwb_user, :admin)
end

scenario 'test 2' do
  user = FactoryBot.create(:pwb_user, :admin)
end

# Better: Create once with let!
let!(:admin) { FactoryBot.create(:pwb_user, :admin) }

scenario 'test 1' do
  expect(admin).to be_admin
end

scenario 'test 2' do
  expect(admin).to be_valid
end
```

## Common Issues & Solutions

### Test Database Not Cleaning

**Problem:** Data from previous tests shows up in next test

**Solution:** Verify DatabaseCleaner config in spec_helper.rb
```ruby
config.after(:each) do
  DatabaseCleaner.clean
end
```

### Element Not Found in JavaScript Tests

**Problem:** Element exists but test can't find it

**Solution:** Add wait time
```ruby
expect(page).to have_content('text', wait: 10)  # Wait up to 10 seconds
find('.selector', wait: 5)
```

### Tests Pass Locally, Fail in CI

**Problem:** Timing issues in CI environment

**Solution:** Add explicit waits
```ruby
# Instead of just clicking
click_button('Submit')

# Wait for result
expect(page).to have_content('Success', wait: 5)
```

### Capybara Can't Find Element by Exact Text

**Problem:** Text matching is exact and case-sensitive

**Solution:** Use partial matches or regex
```ruby
# Exact (fails if case differs)
expect(page).to have_content('Exact Text')

# Partial
expect(page).to have_text('Exact Text', exact: false)

# Regex
expect(page).to have_text(/exact text/i)
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: pwb_test
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.4.7'
          bundler-cache: true
      
      - name: Setup Database
        run: RAILS_ENV=test bundle exec rake db:create db:migrate
      
      - name: Run E2E Tests
        run: bundle exec rspec spec/features/
      
      - name: Upload Coverage
        if: always()
        uses: codecov/codecov-action@v3
```

## Best Practices

✅ **Do:**
- Write tests from user's perspective
- Test critical user journeys
- Keep tests independent
- Use factories for test data
- Add `js: true` only when needed
- Use semantic HTML attributes

❌ **Don't:**
- Test implementation details
- Create dependencies between tests
- Use `sleep()` for waiting (use Capybara waits)
- Click invisible elements
- Rely on CSS class names in tests
- Test third-party code (mock external APIs)

## Resources

- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [RSpec Rails](https://relishapp.com/rspec/rspec-rails)
- [FactoryBot](https://github.com/thoughtbot/factory_bot)
- [Apparition Driver](https://github.com/twalpole/apparition)
- [DatabaseCleaner](https://github.com/DatabaseCleaner/database_cleaner)

## Next Steps

1. Review existing tests: `spec/features/pwb/`
2. Create your first feature test following the patterns
3. Run tests with `bundle exec rspec spec/features/`
4. Check coverage with `open coverage/index.html`
