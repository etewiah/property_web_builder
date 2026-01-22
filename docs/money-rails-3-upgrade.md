# Money-Rails 3.0.0 Upgrade Prep

**Date:** January 22, 2026  
**Status:** Planned

---

## Summary

Prepare to upgrade `money-rails` from 2.0.0 to 3.0.0. The primary breaking change in 3.0.0 is dropping Rails < 7.0 support, which this app already satisfies.

---

## Requirements

- Ruby >= 3.1 (repo uses 3.4.7 via `.tool-versions`)
- Rails >= 7.0 (repo uses ~> 8.1 in `Gemfile`)
- Bundler 2.6.9 (required by `Gemfile.lock`)

---

## Preflight Checks

```bash
rg -n "money-rails" Gemfile Gemfile.lock
rg -n "Monetize\\.extract_cents|extract_cents" app lib spec
```

Expected:
- `Gemfile` uses `gem "money-rails", "~> 2.0"` before the upgrade.
- No usage of `Monetize.extract_cents` (removed in Monetize 2.0).

---

## Upgrade Steps

1. Update `Gemfile`:

   ```ruby
   gem "money-rails", "~> 3.0"
   ```

2. Update the lockfile:

   ```bash
   bundle update money-rails
   ```

   If bundler is missing:

   ```bash
   gem install bundler:2.6.9
   ```

3. Verify the lockfile shows `money-rails (3.0.0)`.

---

## Touchpoints to Verify

- `config/initializers/money.rb` (MoneyRails configuration)
- `app/models/concerns/*priceable*.rb` (monetize macros)
- `app/helpers/currency_helper.rb` (Money formatting helpers)
- Views that call `Money.new(...).format`

---

## Test Plan

Run focused tests first:

```bash
bundle exec rspec spec/helpers/currency_helper_spec.rb
bundle exec rspec spec/models/concerns/pwb/property/priceable_spec.rb
bundle exec rspec spec/services/pwb/exchange_rate_service_spec.rb
```

Optional: full suite

```bash
bundle exec rspec
```

---

## Known Breaking Changes

- money-rails 3.0.0 drops Rails < 7.0 support (already satisfied here).

---

## Rollback

Revert `Gemfile` and `Gemfile.lock` to the previous versions if issues arise.
