# Change Log for PropertyWebBuilder
All notable changes to this project will be documented in this file.

## Unreleased

## 2.1.0 / 2025-12-16

### Major Features
* **Subscription & Plans Management**: Full tenant admin UI for managing subscription plans, pricing, and website subscriptions with AASM state machine
* **User Management**: User deletion with safety checks (prevents deleting sole website owners), ownership transfer functionality
* **Email Verification Flow**: New websites enter locked state pending owner email verification before going live
* **Granular Provisioning**: State machine with validation guards tracks each provisioning step (owner_assigned → agency_created → links_created → field_keys_created → properties_seeded → ready → live)
* **Subdomain Pool System**: Pre-generated Heroku-style subdomains with reservation, allocation, and release lifecycle
* **Email Template Management**: Customizable email templates at both site and tenant admin levels with Liquid templating

### New Features
* Custom domain management with DNS TXT verification
* TLS certificate checking rake tasks
* Amazon SES integration with delivery tracking and bounce handling
* Rails Performance dashboard and Mission Control for Solid Queue
* Bulk provisioning rake task for batch user creation
* Verification rake tasks for managing locked websites
* Signup API with token-based tracking for cross-domain flows
* Storage stats dashboard for ActiveStorage monitoring

### Infrastructure
* Upgrade Rails 8.0.4 → 8.1.1
* Replace firebase_id_token gem with custom FirebaseTokenVerifier
* Add Solid Queue for async email delivery
* Comprehensive Playwright E2E test suite (migrated from Capybara/Selenium)
* Structured logging for critical operations
* Mail delivery observer for email tracking

### Bug Fixes
* Fix navigation links not rendering for new websites (missing link_path attribute)
* Fix owner_email not being set during bulk provisioning
* Fix duplicate subdomain reservations per email
* Fix form routing for namespaced Pwb:: models
* Fix SSL CRL errors in seed images availability check
* Fix N+1 queries detected by Bullet gem

### Removed
* Cloudinary gem (replaced by ActiveStorage)
* ruby_odata gem and OData MLS import support
* firebase_id_token gem (replaced by custom verifier)

## 2.0.0 / 2025-12-09

### Breaking Changes
* Convert from Rails engine to standalone application
* Migrate from `Prop` model to `RealtyAsset` with separate Sale/Rental listings
* Implement namespace-based multi-tenancy (`Pwb::` base, `PwbTenant::` tenant-scoped)
* Migrate from Bootstrap to Tailwind CSS for public themes
* Migrate from Globalize gem to Mobility for translations

### Major Features
* **Multi-tenancy**: Full acts_as_tenant integration with cross-tenant admin
* **Dual admin interfaces**: `site_admin` (super admin) and `tenant_admin` (per-tenant)
* **Seed packs system**: Scenario-based seeding for quick site setup
* **Firebase authentication**: Unified auth with configurable Firebase/Devise provider
* **New themes**: Brisbane (luxury), Bologna, Bristol with Tailwind CSS
* **Enhanced theming**: CSS variables, Liquid templates, page part library
* **Faceted search**: Field key-based filtering with URL-friendly parameters

### New Features
* Custom domain support for tenant deployments
* Quill HTML editor with image picker for page parts
* Audit logging for all authentication events
* Push notifications via ntfy.sh
* External image URL support per tenant
* Comprehensive SEO strategy implementation
* Health checks and Sentry error tracking
* Mobile responsive admin layouts
* Auto-fetch Firebase certificates on NoCertificatesError

### Infrastructure
* Upgrade Rails from 5.2 → 6.1 → 7.0 → 8.0
* Add Vite with Vue 3 for modern frontend builds
* Implement structured logging with Logster
* Add comprehensive test coverage
* Replace Cloudinary with ActiveStorage (S3/R2 compatible)

### Removed
* Deprecated themes (chic, matt, vic, squares, airbnb)
* jsonapi-resources gem dependency
* Cloudinary dependency

## 1.4.0 / 2020-02-09

* Enable geocoding of addresses with geocoder gem
* Add support for facebook authentication using omniauth
* Fix issue with sending emails (#48)
* Add Dutch, Korean, Polish, Bulgarian and Romanian translations
* Fix issue with updating logo
* Update Loofah gem to address CVE-2018-8048

## 1.3.0 / 2017-12-04

* New CMS functionality (#22)
* Add Portuguese as an admin language
* Add preset color palettes
* Require Rails 5.1.0 or above
* Fix issue with seeding content (#38)
* Add Italian translations
* Use property-web-scraper to import from web pages

## 1.2.0 / 2017-08-23

* Add Vue.js
* Add search results map
* Display infowindow on maps
* Add social sharing buttons
* Add Turkish and Vietnamese translations
* Fix Rails 5.1.0 issue with seed task (#29)
* Fix language picker redirecting to root
* Set open graph meta tags
* Support Rails 5.1.0

## 1.1.1 / 2017-07-25

* Yanked previous release and re-released due to error in cleaning up tmp files

## 1.1.0 / 2017-07-25

* Fix Rails 5.1.0 issue with paloma gem (#28)
* Optimise cloudinary images
* Google PageSpeed improvements
* Support for adding CSS directly
* Support for Google Analytics script
* Increase valid price range in admin UI (#21)
* Allow setting of search widget price options
* Add Russian as an admin language

## 1.0.0 / 2017-05-25

* Minor fixes for admin UI (#16 & #17)
* Russian translation improvements
* Stable version tried and tested in production

## 0.2.0 / 2017-05-03

* Experimental support for import of properties from web pages
* Add German, Russian and Portuguese translations
* Enable management of navigation links

## 0.1.1 / 2017-04-25

* Fix bug where invalid theme_name could be set
* Experimental RETS integration

## 0.1.0 / 2017-04-10

* Add ability to change currency through admin panel
* Initial support for uploading CSV file
* Allow image upload to file system where cloudinary is not used
* Support for sending emails via SendGrid
* Add French translations

## 0.0.2 / 2017-02-16

* Add tests
* Add api_public/v1/props endpoint that can be used for a client app
* Enable selection of locale variants


## 0.0.1 / 2016-12-24

Initial release with

* Multilingual support
* Ability to deploy to heroku with one click
* Storage of image files with cloudinary
* Full support for property listings
* Admin panel built with EmberJS
* Fully responsive
* Google maps integration
* Customisable look and feel


