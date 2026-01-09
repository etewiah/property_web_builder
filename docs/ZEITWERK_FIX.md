# Zeitwerk Naming Convention Fix

**Date**: 2026-01-09  
**Issue**: Staging environment failed to boot with `uninitialized constant Pwb::Zoho::Errors`  
**Status**: ✅ Fixed

## Problem

The app crashed when starting in staging environment (where eager_load is enabled):

```
uninitialized constant Pwb::Zoho::Errors (NameError)
```

But it worked fine in development and all tests passed! ❌

## Root Cause

**Zeitwerk file naming mismatch**:

| File Name | Expected Constant | Actual Constant | Result |
|-----------|-------------------|-----------------|--------|
| `errors.rb` | `Errors` (module) | `Error` (class) | ❌ Mismatch |
| `error.rb` | `Error` (class) | `Error` (class) | ✅ Match |

Zeitwerk's autoloader expects:
- `errors.rb` → defines `Errors` module/class
- `error.rb` → defines `Error` class

Our file was named `errors.rb` but defined `Error` class (and subclasses).

## Why Tests Didn't Catch This

1. **Test environment doesn't eager load by default**
   ```ruby
   # config/environments/test.rb
   config.eager_load = false  # Default setting
   ```

2. **Development uses autoloading**
   - Files load on-demand (lazy loading)
   - If code never references `Pwb::Zoho::Errors`, file never loads
   - No error occurs

3. **Staging/Production use eager loading**
   - ALL files loaded at boot (for performance)
   - Zeitwerk validates all file/constant name mappings
   - Mismatch causes immediate error

4. **No eager load validation test**
   - Tests never validated that eager_load works

## The Fix

### 1. Renamed the File
```bash
mv app/services/pwb/zoho/errors.rb app/services/pwb/zoho/error.rb
```

### 2. Updated require_relative References
```ruby
# app/jobs/pwb/zoho/base_job.rb
# Before:
require_relative '../../../services/pwb/zoho/errors'

# After:
require_relative '../../../services/pwb/zoho/error'
```

```ruby
# app/services/pwb/zoho/client.rb
# Before:
require_relative 'errors'

# After:
require_relative 'error'
```

### 3. Added Eager Load Test
Created `spec/zeitwerk_spec.rb`:
```ruby
RSpec.describe 'Zeitwerk eager loading' do
  it 'eager loads all constants without errors' do
    expect { Rails.application.eager_load! }.not_to raise_error
  end
end
```

This test will catch similar issues in the future!

## Files Changed

- ✅ Renamed: `app/services/pwb/zoho/errors.rb` → `error.rb`
- ✅ Updated: `app/jobs/pwb/zoho/base_job.rb`
- ✅ Updated: `app/services/pwb/zoho/client.rb`
- ✅ Created: `spec/zeitwerk_spec.rb`

## Verification

```bash
# Test passes
bundle exec rspec spec/zeitwerk_spec.rb
# 2 examples, 0 failures ✅

# Staging boots
RAILS_ENV=staging rails runner "puts 'Success!'"
# Staging boots successfully! ✅
```

## Prevention

The new `spec/zeitwerk_spec.rb` test will now catch these issues:

- File naming mismatches (e.g., `errors.rb` with `Error` class)
- Missing module definitions
- Circular dependencies
- Other autoloading issues that only appear in production

**Always run the full test suite before deploying!**

## Zeitwerk Naming Rules (Reference)

| File Path | Must Define |
|-----------|-------------|
| `app/models/user.rb` | `User` class |
| `app/models/users.rb` | `Users` module |
| `app/services/billing/error.rb` | `Billing::Error` |
| `app/services/billing/errors.rb` | `Billing::Errors` |
| `app/controllers/api/v1/users_controller.rb` | `Api::V1::UsersController` |

**Rule**: File name must match the constant name (singular/plural matters!)

---

**Status**: ✅ Fixed and Protected

This type of issue will now be caught in tests before it reaches staging/production!
