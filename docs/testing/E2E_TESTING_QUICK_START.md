# E2E Testing Quick Start Guide

## What is E2E Testing in PropertyWebBuilder?

PropertyWebBuilder uses **RSpec with Capybara** for end-to-end (feature/integration) testing. This means testing the application from a user's perspective using a real (headless) browser.

## Quick Setup

```bash
# Install dependencies
bundle install

# Create and prepare test database
RAILS_ENV=test bundle exec rake db:create db:migrate

# Create e2e database (optional, for e2e environment)
RAILS_ENV=e2e bundle exec rake db:create db:migrate
```

## Running E2E Tests

```bash
# Run all feature tests
bundle exec rspec spec/features/

# Run specific test file
bundle exec rspec spec/features/pwb/sessions_spec.rb

# Run with detailed output
bundle exec rspec spec/features/ -f documentation

# Run a single test (by line number)
bundle exec rspec spec/features/pwb/sessions_spec.rb:25

# Run with failure messages and backtrace
bundle exec rspec spec/features/ --format documentation --backtrace
```

## Writing Your First E2E Test

### Basic Test Structure

```ruby
# spec/features/pwb/my_feature_spec.rb
require 'rails_helper'

module Pwb
  RSpec.describe "My Feature", type: :feature do
    # Setup test data before each test
    before(:each) do
      @website = FactoryBot.create(:pwb_website)
      @user = FactoryBot.create(:pwb_user, :admin, website: @website)
    end

    # Write individual test scenarios
    scenario 'user can perform action' do
      # Navigate to a page
      visit('/admin')

      # Fill in a form
      fill_in('Email', with: @user.email)
      fill_in('Password', with: @user.password)

      # Click a button
      click_button('Sign in')

      # Assert the result
      expect(page).to have_content('Dashboard')
      expect(current_path).to include('/admin')
    end
  end
end
```

### Common Capybara Methods

```ruby
# Navigation
visit('/path')                          # Navigate to URL
current_path                            # Get current URL path
current_url                             # Get full current URL

# Finding elements
page.has_content?('text')               # Check if text exists
page.has_css?('.class')                 # Check if CSS selector exists
page.find('.selector')                  # Find element by selector
page.all('.item')                       # Find all matching elements

# Filling forms
fill_in('Email', with: 'test@example.com')
fill_in('field_id', with: 'value')
select('Option', from: 'dropdown_id')
check('checkbox_id')
uncheck('checkbox_id')

# Clicking
click_button('Sign in')
click_link('Home')
click_on('Something')                   # Works for buttons and links

# Assertions (use with expect)
expect(page).to have_content('text')
expect(page).to have_css('.selector')
expect(page).to have_link('text')
expect(current_path).to eq('/path')
expect(current_url).to include('example.com')
```

## Using Multi-Tenancy in Tests

PropertyWebBuilder is multi-tenant. Here's how to test it:

```ruby
scenario 'user can access their tenant' do
  # Create website (tenant)
  @website = FactoryBot.create(:pwb_website, subdomain: 'my-agency')
  
  # Create user for that website
  @user = FactoryBot.create(:pwb_user, website: @website)
  
  # Set the host for subdomain testing
  Capybara.app_host = 'http://my-agency.example.com'
  
  visit('/users/sign_in')
  # ... test sign in
  
  # Reset app host after test
  Capybara.app_host = nil
end
```

## Using Factories to Create Test Data

```ruby
# Create a single object
website = FactoryBot.create(:pwb_website)

# Create with custom attributes
user = FactoryBot.create(:pwb_user, email: 'custom@example.com')

# Create with traits
admin = FactoryBot.create(:pwb_user, :admin)

# Use let! to create before each test (lazy-loaded)
let!(:website) { FactoryBot.create(:pwb_website) }
let!(:user) { FactoryBot.create(:pwb_user, website: website) }

# Available factories
:pwb_user          # User account
:pwb_website       # Website/tenant
:pwb_agency        # Agency/company
:pwb_page          # Web page
:pwb_prop          # Property listing
:pwb_address       # Address
:pwb_page_part     # Page content block
```

## Testing JavaScript-Heavy Features

For features that require JavaScript (clicking, async operations, etc):

```ruby
RSpec.describe "JavaScript Feature", type: :feature, js: true do
  # This test uses Apparition (headless Chrome)
  scenario 'JavaScript works' do
    visit('/page')
    
    # Wait for element to appear (up to 5 seconds)
    expect(page).to have_content('Loaded', wait: 5)
    
    # Click something that triggers JS
    click_link('Load More')
    
    # Assert JS result appeared
    expect(page).to have_content('More items')
  end
end
```

## Debugging Tests

### Save and Open Page

```ruby
save_and_open_page  # Opens current page in your browser
```

### Take a Screenshot

```ruby
save_screenshot('debug.png')  # Saves to tmp/screenshots/
```

### Use Debugger

```ruby
require 'pry'
binding.pry  # Pauses test, drop into debugger
```

### Print Page HTML

```ruby
puts page.html  # Print entire page HTML to console
```

### Find Elements

```ruby
# Check what's actually on the page
page.all('button').each { |btn| puts btn.text }

# Print all links
page.all('a').each { |link| puts link['href'] }
```

### Disable Server Errors

```ruby
Capybara.raise_server_errors = false  # Prevents test from failing on 500 errors
```

## Test File Organization

```
spec/features/
├── pwb/
│   ├── admin_spec.rb           # Admin panel tests
│   ├── sessions_spec.rb        # Login/logout tests
│   ├── contact_forms_spec.rb   # Contact form tests
│   └── theme_rendering_spec.rb # Frontend rendering tests
├── support/
│   ├── feature_helpers.rb      # Helper methods for feature tests
│   └── ...
└── factories/
    ├── pwb_users.rb            # User factory
    ├── pwb_websites.rb         # Website factory
    └── ...
```

## Running Tests with Different Environments

```bash
# Test environment (default)
bundle exec rspec spec/features/

# E2E environment (uses e2e database)
RAILS_ENV=e2e bundle exec rspec spec/features/

# With E2E server running separately
RAILS_ENV=e2e rails s -p 3001
bundle exec rspec spec/features/ --pattern spec/features/**/*_spec.rb
```

## Common Patterns

### Test Authentication

```ruby
scenario 'authenticated user sees dashboard' do
  # Sign in
  visit('/users/sign_in')
  fill_in('Email', with: @user.email)
  fill_in('Password', with: 'password123')
  click_button('Sign in')
  
  # Assert authenticated
  expect(current_path).to include('/admin')
  expect(page).to have_content(@user.email)
end
```

### Test Form Submission

```ruby
scenario 'form submission works' do
  visit('/contact')
  
  fill_in('Name', with: 'John')
  fill_in('Email', with: 'john@example.com')
  fill_in('Message', with: 'Hello!')
  
  click_button('Send')
  
  expect(page).to have_content('Thank you')
  # Or check that user was redirected
  expect(current_path).to eq('/contact')
end
```

### Test Multi-Tenant Isolation

```ruby
scenario 'tenants are isolated' do
  website1 = FactoryBot.create(:pwb_website, subdomain: 'tenant1')
  website2 = FactoryBot.create(:pwb_website, subdomain: 'tenant2')
  
  prop1 = FactoryBot.create(:pwb_prop, website: website1)
  prop2 = FactoryBot.create(:pwb_prop, website: website2)
  
  # Visit tenant1 and check only their property shows
  Capybara.app_host = 'http://tenant1.example.com'
  visit("/properties/#{prop1.id}")
  expect(page).to have_content(prop1.title)
  
  # Visit tenant2 and check different property shows
  Capybara.app_host = 'http://tenant2.example.com'
  visit("/properties/#{prop2.id}")
  expect(page).to have_content(prop2.title)
  
  Capybara.app_host = nil
end
```

## Existing Test Examples

Look at these files for real examples:

1. **spec/features/pwb/sessions_spec.rb** - Login testing
2. **spec/features/pwb/contact_forms_spec.rb** - Form testing
3. **spec/features/pwb/theme_rendering_spec.rb** - Frontend rendering

## Troubleshooting

### Test Hangs or Times Out
- Add `wait: 10` to your expectation: `expect(page).to have_content('text', wait: 10)`
- Check that elements have proper IDs or data attributes
- Ensure JavaScript is completing (use network inspection)

### Element Not Found
```ruby
# Debug what's actually on the page
puts page.html

# Or use pry to inspect
require 'pry'
binding.pry
```

### Sign In Not Working
- Check that Devise is configured correctly
- Verify user credentials in factories
- Check for CSRF token issues (usually only in non-feature tests)

### Database Not Cleaned Between Tests
- This is automatic for feature tests
- Each test gets a clean database
- If data persists, check your factory definitions

## Performance Tips

1. **Use `let!` sparingly** - Only create data that's actually needed
2. **Avoid JavaScript when possible** - Tests with `js: true` are slower
3. **Reuse test data** - Create once in `before(:all)`, use in multiple scenarios
4. **Minimize navigation** - Test as much as possible on one page

## Best Practices

✅ Do:
- Test user-visible behavior
- Use semantic HTML matchers (text, visible elements)
- Create realistic test data with factories
- Test critical user journeys
- Keep tests focused and independent

❌ Don't:
- Test implementation details
- Click hidden elements
- Rely on exact CSS selectors (use semantic classes)
- Test third-party code (mock it)
- Create dependencies between tests

## Resources

- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [RSpec Rails Guide](https://relishapp.com/rspec/rspec-rails)
- [FactoryBot Documentation](https://github.com/thoughtbot/factory_bot)
- [Apparition Driver Docs](https://github.com/twalpole/apparition)

## Getting Help

- Check existing tests: `spec/features/pwb/`
- Review spec_helper.rb for test configuration
- Look at factories: `spec/factories/`
- Check feature_helpers.rb for reusable test methods
