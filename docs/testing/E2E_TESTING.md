# E2E Testing Documentation

## Overview

PropertyWebBuilder has a complete, production-ready end-to-end (E2E) testing infrastructure based on **RSpec + Capybara** with headless Chrome (Apparition driver).

This documentation set provides everything you need to understand, use, and extend the E2E testing system.

## Documentation Files

### Start Here
- **[E2E_TESTING_SUMMARY.md](./E2E_TESTING_SUMMARY.md)** (5 min read)
  - Executive summary of the entire infrastructure
  - Quick reference for common tasks
  - Key metrics and status
  - **Read this first**

### How to Write Tests
- **[E2E_TESTING_QUICK_START.md](./E2E_TESTING_QUICK_START.md)** (15 min read)
  - Practical guide for developers
  - How to write your first test
  - Common patterns and examples
  - Troubleshooting guide
  - **For developers writing tests**

### How It's Configured
- **[E2E_TESTING_SETUP.md](./E2E_TESTING_SETUP.md)** (30 min read)
  - Complete infrastructure configuration
  - File-by-file breakdown
  - Database strategy explanation
  - CI/CD integration examples
  - **For developers maintaining infrastructure**

### Research & Analysis
- **[docs/claude_thoughts/E2E_TESTING_INFRASTRUCTURE_ANALYSIS.md](./claude_thoughts/E2E_TESTING_INFRASTRUCTURE_ANALYSIS.md)** (20 min read)
  - Deep technical analysis
  - Architecture decisions explained
  - Known issues and limitations
  - Future enhancement recommendations
  - **For understanding design decisions**

## Quick Start

### Run Tests in 3 Steps

```bash
# 1. Install gems
bundle install

# 2. Setup test database
RAILS_ENV=test bundle exec rake db:create db:migrate

# 3. Run E2E tests
bundle exec rspec spec/features/
```

### Write Your First Test

```ruby
# spec/features/pwb/my_first_test_spec.rb
require 'rails_helper'

module Pwb
  RSpec.describe "My Feature", type: :feature do
    let!(:website) { FactoryBot.create(:pwb_website) }
    
    scenario 'user can view home page' do
      visit('/')
      expect(page).to have_content('Welcome')
    end
  end
end
```

### Run It

```bash
bundle exec rspec spec/features/pwb/my_first_test_spec.rb
```

## What's Included

- ✅ **4 feature test files** as working examples
- ✅ **Multiple browser drivers** (Apparition, Selenium, Poltergeist)
- ✅ **Multi-tenant support** with factory-level scoping
- ✅ **Dedicated E2E environment** (config/environments/e2e.rb)
- ✅ **Separate E2E database** (pwb_e2e)
- ✅ **15+ test data factories** for creating test data
- ✅ **Test helpers** for authentication and setup
- ✅ **Database cleaning strategy** optimized for different test types
- ⚠️ **Admin tests pending** (needs CI fix)

## Key Features

### Headless Browser Testing
- Uses Apparition (Chrome DevTools Protocol)
- Runs without visible browser window
- Great for CI/CD environments
- Supports JavaScript testing

### Multi-Tenancy Support
- Test multiple tenants in same test
- Subdomain-based tenant isolation
- Factory-level scoping
- Automatic database cleanup per test

### Test Data Management
- FactoryBot factories for all models
- Simple, readable test data creation
- Easy composition of complex objects
- Support for traits and sequences

### Debugging Tools
- `save_and_open_page` - Opens page in browser
- `save_screenshot` - Take screenshots
- `binding.pry` - Interactive debugging
- `puts page.html` - Print page HTML

## Common Tasks

### Running Tests

```bash
# All feature tests
bundle exec rspec spec/features/

# Single file
bundle exec rspec spec/features/pwb/sessions_spec.rb

# Single test (by line)
bundle exec rspec spec/features/pwb/sessions_spec.rb:25

# With documentation
bundle exec rspec spec/features/ -f documentation
```

### Writing Tests

```ruby
# Create test data
let!(:website) { FactoryBot.create(:pwb_website) }

# Navigate to page
visit('/path')

# Fill forms
fill_in('Email', with: 'test@example.com')

# Click buttons
click_button('Submit')

# Make assertions
expect(page).to have_content('Success')
```

### Testing Multi-Tenant Features

```ruby
# Create separate websites
org1 = FactoryBot.create(:pwb_website, subdomain: 'org1')
org2 = FactoryBot.create(:pwb_website, subdomain: 'org2')

# Test each separately
Capybara.app_host = 'http://org1.example.com'
visit('/')  # See org1 content

Capybara.app_host = 'http://org2.example.com'
visit('/')  # See org2 content

# Reset
Capybara.app_host = nil
```

### Debugging Failed Tests

```ruby
# Open page in browser
save_and_open_page

# Print what's on page
puts page.html

# Drop into debugger
require 'pry'
binding.pry

# Find elements
page.all('button').each { |btn| puts btn.text }
```

## Existing Examples

### Session/Login Tests
- File: `spec/features/pwb/sessions_spec.rb`
- Examples:
  - Valid credentials sign-in
  - Invalid password handling
  - Multi-tenant isolation

### Contact Form Tests
- File: `spec/features/pwb/contact_forms_spec.rb`
- Examples:
  - General contact form
  - Property contact form
  - Success message verification

### Theme Rendering Tests
- File: `spec/features/pwb/theme_rendering_spec.rb`
- Examples:
  - CSS class verification
  - Dynamic content rendering
  - Page structure testing

### Admin Panel Tests (Pending)
- File: `spec/features/pwb/admin_spec.rb`
- Status: Currently broken, needs investigation

## Test Structure

```
spec/
├── features/pwb/              # Feature/integration tests
│   ├── sessions_spec.rb       # Login tests
│   ├── contact_forms_spec.rb  # Form tests
│   ├── theme_rendering_spec.rb
│   └── admin_spec.rb          # Admin tests (pending)
│
├── requests/                  # API/HTTP tests (60+ files)
├── models/                    # Unit tests
├── controllers/               # Controller tests
│
├── factories/                 # Test data factories
│   ├── pwb_users.rb
│   ├── pwb_websites.rb
│   ├── pwb_props.rb
│   └── ... (15+ total)
│
├── support/                   # Test helpers
│   ├── feature_helpers.rb
│   └── request_spec_helpers.rb
│
├── rails_helper.rb            # RSpec configuration
└── spec_helper.rb             # Capybara setup
```

## Available Factories

```ruby
FactoryBot.create(:pwb_user)           # User account
FactoryBot.create(:pwb_user, :admin)   # Admin user
FactoryBot.create(:pwb_website)        # Website/tenant
FactoryBot.create(:pwb_agency)         # Real estate agency
FactoryBot.create(:pwb_page)           # Web page
FactoryBot.create(:pwb_prop, :sale)    # Property listing
FactoryBot.create(:pwb_address)        # Address
FactoryBot.create(:pwb_page_part)      # Page content block
# ... and more
```

## Key Gems

| Gem | Version | Purpose |
|-----|---------|---------|
| `rspec-rails` | 8.0.2 | Test framework |
| `capybara` | 3.40.0 | Browser automation |
| `apparition` | 0.6.0 | Chrome driver |
| `selenium-webdriver` | 4.38.0 | Cross-browser driver |
| `factory_bot_rails` | Latest | Test data |
| `database_cleaner` | Latest | DB cleanup |
| `launchy` | Latest | Debug tools |

## Important Configuration Files

- `spec/rails_helper.rb` - RSpec Rails configuration
- `spec/spec_helper.rb` - Capybara setup
- `.rspec` - RSpec command-line defaults
- `config/environments/e2e.rb` - E2E-specific environment
- `config/database.yml` - Database configuration
- `spec/support/feature_helpers.rb` - Test helper methods
- `spec/factories/` - Test data factories

## Common Capybara Methods

```ruby
# Navigation
visit('/path')
current_path
current_url

# Finding
page.has_content?('text')
page.find('.selector')
page.all('.item')

# Filling
fill_in('field_name', with: 'value')
select('option', from: 'dropdown')
check('checkbox')

# Clicking
click_button('button_text')
click_link('link_text')

# Assertions
expect(page).to have_content('text')
expect(page).to have_css('.class')
expect(current_path).to eq('/path')

# JavaScript
expect(page).to have_content('text', wait: 5)  # Wait up to 5 seconds
find('.selector', wait: 3)
```

## Running in Different Modes

```bash
# Normal test mode
bundle exec rspec spec/features/

# E2E mode with separate database
RAILS_ENV=e2e bundle exec rspec spec/features/

# With detailed output
bundle exec rspec spec/features/ -f documentation

# With full backtrace
bundle exec rspec spec/features/ --backtrace

# With code coverage
bundle exec rspec spec/features/
open coverage/index.html  # View report
```

## Environment Setup

### Testing Environment
```yaml
# config/database.yml
test:
  database: pwb_test
  # Used for unit/integration tests
```

### E2E Environment
```yaml
# config/database.yml
e2e:
  database: pwb_e2e
  # Separate database for end-to-end tests
```

### E2E Config
```
# config/environments/e2e.rb
- Code reloading enabled
- Debug logging
- Subdomain support for multi-tenancy
- Development-like settings
```

## Known Issues

1. **Admin Panel Tests** (`spec/features/pwb/admin_spec.rb`)
   - Currently marked as pending
   - Fails on Travis CI due to asset loading
   - Needs investigation and fix

2. **Apparition Version**
   - 0.6.0 requires older Capybara
   - May limit Chrome feature support
   - Consider upgrading

3. **PhantomJS/Poltergeist**
   - Deprecated and not maintained
   - Use Apparition or Selenium instead

## Best Practices

✅ Do:
- Test user-visible behavior
- Use semantic HTML matchers
- Create realistic test data with factories
- Test critical user journeys
- Keep tests focused and independent

❌ Don't:
- Test implementation details
- Click hidden elements
- Rely on exact CSS selectors
- Test third-party code
- Create test dependencies

## Quick Troubleshooting

**Tests fail in CI but pass locally?**
- Add explicit waits: `expect(page).to have_content('text', wait: 5)`
- Check for timing issues in JavaScript tests

**Element not found?**
- Use `save_and_open_page` to inspect
- Check CSS selectors with browser DevTools
- Verify element visibility

**Database not cleaning?**
- Verify DatabaseCleaner config in spec_helper.rb
- Check that `config.after(:each) { DatabaseCleaner.clean }`

**JavaScript tests slower?**
- This is normal - they use truncation instead of transactions
- Avoid `js: true` unless needed

## Where to Go From Here

**New to E2E testing?**
→ Read [E2E_TESTING_QUICK_START.md](./E2E_TESTING_QUICK_START.md)

**Want to write tests?**
→ Check [E2E_TESTING_QUICK_START.md](./E2E_TESTING_QUICK_START.md) for patterns

**Need to understand infrastructure?**
→ Read [E2E_TESTING_SETUP.md](./E2E_TESTING_SETUP.md)

**Want deep technical details?**
→ See [docs/claude_thoughts/E2E_TESTING_INFRASTRUCTURE_ANALYSIS.md](./claude_thoughts/E2E_TESTING_INFRASTRUCTURE_ANALYSIS.md)

**Just need a summary?**
→ Check [E2E_TESTING_SUMMARY.md](./E2E_TESTING_SUMMARY.md)

## Reference

- [Capybara Docs](https://github.com/teamcapybara/capybara)
- [RSpec Rails Docs](https://relishapp.com/rspec/rspec-rails)
- [FactoryBot Docs](https://github.com/thoughtbot/factory_bot)
- [Apparition Docs](https://github.com/twalpole/apparition)

## Summary

PropertyWebBuilder has **production-ready E2E testing infrastructure** with:
- Working feature tests you can learn from
- Multiple browser drivers for different needs
- Multi-tenant test support
- Complete documentation and examples
- Ready-to-use test helpers and factories

**Start testing in 3 commands:**
```bash
bundle install
RAILS_ENV=test bundle exec rake db:create db:migrate
bundle exec rspec spec/features/
```
