# Testing Guide

PropertyWebBuilder uses **RSpec + Capybara** for testing, with full support for multi-tenant scenarios.

## Quick Start

```bash
# Install dependencies
bundle install

# Setup test database
RAILS_ENV=test bundle exec rake db:create db:migrate

# Run all feature tests
bundle exec rspec spec/features/

# Run unit tests
bundle exec rspec spec/models/
```

## Test Types

| Type | Location | Purpose |
|------|----------|---------|
| Feature/E2E | `spec/features/` | User journey testing with browser |
| Request | `spec/requests/` | API and controller testing |
| Model | `spec/models/` | Unit testing for models |
| Controller | `spec/controllers/` | Controller unit tests |

## Documentation

| Document | Description |
|----------|-------------|
| [E2E Testing Guide](./E2E_TESTING.md) | Complete E2E testing documentation |
| [Quick Start](./E2E_TESTING_QUICK_START.md) | How to write your first test |
| [Setup Guide](./E2E_TESTING_SETUP.md) | Infrastructure configuration |
| [User Stories](./E2E_USER_STORIES.md) | User stories for test coverage |
| [Playwright Testing](./PLAYWRIGHT_TESTING.md) | Alternative Playwright E2E approach |

## Key Features

- **Headless Chrome** via Apparition driver
- **Multi-tenant testing** with subdomain isolation
- **Factory Bot** for test data creation
- **Database Cleaner** for test isolation

## Writing a Test

```ruby
# spec/features/pwb/my_feature_spec.rb
require 'rails_helper'

module Pwb
  RSpec.describe "My Feature", type: :feature do
    let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'test') }
    
    before(:each) do
      Capybara.app_host = 'http://test.example.com'
    end
    
    after(:each) do
      Capybara.app_host = nil
    end

    scenario 'user can view page' do
      visit('/')
      expect(page).to have_content('Welcome')
    end
  end
end
```

## Multi-Tenant Testing

```ruby
# Create separate tenants
tenant_a = FactoryBot.create(:pwb_website, subdomain: 'tenant-a')
tenant_b = FactoryBot.create(:pwb_website, subdomain: 'tenant-b')

# Test tenant isolation
Capybara.app_host = 'http://tenant-a.example.com'
visit('/')  # See tenant A's content

Capybara.app_host = 'http://tenant-b.example.com'  
visit('/')  # See tenant B's content
```

## Available Factories

```ruby
FactoryBot.create(:pwb_user)           # User account
FactoryBot.create(:pwb_user, :admin)   # Admin user
FactoryBot.create(:pwb_website)        # Website/tenant
FactoryBot.create(:pwb_agency)         # Real estate agency
FactoryBot.create(:pwb_page)           # Web page
FactoryBot.create(:pwb_prop, :sale)    # Sale property
FactoryBot.create(:pwb_prop, :long_term_rent)  # Rental property
```

## Running Tests

```bash
# All feature tests
bundle exec rspec spec/features/

# Single file
bundle exec rspec spec/features/pwb/sessions_spec.rb

# Single test by line
bundle exec rspec spec/features/pwb/sessions_spec.rb:25

# With documentation format
bundle exec rspec spec/features/ -f documentation

# E2E environment (separate database)
RAILS_ENV=e2e bundle exec rspec spec/features/
```

## Debugging

```ruby
save_and_open_page    # Opens page in browser
save_screenshot('debug.png')  # Takes screenshot
binding.pry           # Interactive debugger
puts page.html        # Print page HTML
```
