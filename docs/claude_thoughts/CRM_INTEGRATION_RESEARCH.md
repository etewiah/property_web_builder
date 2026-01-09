# PropertyWebBuilder CRM Integration Research

**Document Version:** 1.0  
**Date:** January 9, 2025  
**Status:** Research Complete

## Overview

This document summarizes findings from research into PropertyWebBuilder's user registration, website creation, subscription system, and available data for CRM integration.

---

## 1. User Registration Flow

### Entry Point
- **File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/signup_controller.rb`
- **Route:** `/signup` - Multi-step signup wizard

### Registration Process (4 Steps)

#### Step 1: Email Capture
- **Method:** `SignupController#new` → `SignupController#start`
- **Input:** Email address
- **Actions:**
  - Validate email format (RFC 3339)
  - Create "lead" user with `onboarding_state: 'lead'`
  - Temporary password generated (SecureRandom.hex(16))
  - Reserve subdomain for 10 minutes
  - Return suggested subdomain name

#### Step 2: Site Configuration
- **Method:** `SignupController#configure` → `SignupController#save_configuration`
- **Inputs:**
  - Subdomain (custom name or suggested)
  - Site type (residential, commercial, vacation_rental)
- **Actions:**
  - Validate subdomain availability
  - Validate site type
  - Create `Website` record in 'pending' state
  - Allocate reserved subdomain to website
  - Create `UserMembership` record (user as 'owner')
  - Update user's `website_id`
  - User transitions to `onboarding_state: 'onboarding'`

#### Step 3: Provisioning
- **Method:** `SignupController#provisioning` → `SignupController#provision`
- **Handler:** `ProvisioningService#provision_website`
- **Actions:**
  - Create agency record
  - Create navigation links
  - Create field keys
  - Create pages and page parts
  - Optionally seed sample properties
  - Send email verification link
  - Website transitions to 'locked_pending_email_verification' state

#### Step 4: Completion
- **Method:** `SignupController#complete`
- **Display:** Success page, login link
- **Next Step:** Email verification

### User Model Key Fields

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user.rb`

**Critical Fields for CRM:**
```ruby
# Identity
email                          # Primary contact email
first_names                    # User's first name(s)
last_names                     # User's last name(s)
display_name                   # Derived from first_names + last_names or email

# Contact Information
phone_number_primary           # Primary phone number
skype                         # Skype username

# Onboarding State Machine
onboarding_state              # lead → registered → email_verified → onboarding → active
                              # Also tracks: churned, reactivate
onboarding_completed_at       # When user completed full onboarding
onboarding_started_at         # When user started onboarding
onboarding_step               # Current step (1-4)

# Authentication & Activity
sign_in_count                 # Total login count
current_sign_in_at            # Most recent login
current_sign_in_ip            # Most recent IP
last_sign_in_at               # Previous login timestamp
last_sign_in_ip               # Previous IP
confirmed_at                  # Email confirmation timestamp
confirmation_token            # Verification token
reset_password_token          # Password reset token

# Account Status
admin                         # Is site admin
locked_at                     # Account locked timestamp
failed_attempts               # Failed login count

# System Fields
website_id                    # Primary website (for multi-website support)
firebase_uid                  # Firebase authentication ID
created_at                    # Registration timestamp
updated_at                    # Last modification timestamp
```

### User Memberships (Multi-Website Support)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user_membership.rb`

```ruby
# Relationships
has_many :user_memberships    # Links to multiple websites
has_many :websites            # All accessible websites through memberships

# Membership Fields
user_id                       # User reference
website_id                    # Website reference
role                         # owner | admin | member | viewer
active                       # Boolean - is membership active?
created_at                   # Membership creation date
updated_at                   # Membership last update

# Role Hierarchy
ROLES = %w[owner admin member viewer]  # lower index = higher authority
```

---

## 2. Website/Tenant Creation Flow

### Website Model

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/website.rb`

**Key Fields for CRM:**
```ruby
# Site Identity
subdomain                     # Unique subdomain (e.g., "my-agency")
custom_domain                 # Custom domain if configured
slug                          # Always "website" (not unique)

# Company Information
company_display_name          # Display name for agency
owner_email                   # Owner's email address
email_for_general_contact_form   # Where inquiries are sent
email_for_property_contact_form  # Where property inquiries are sent

# Configuration
site_type                     # residential | commercial | vacation_rental
theme_name                    # Selected theme
default_currency              # EUR, USD, etc.
default_client_locale         # en-UK, es-ES, etc.

# Provisioning Status
provisioning_state            # pending → owner_assigned → agency_created → links_created
                              # → field_keys_created → pages_created → properties_seeded
                              # → ready → locked_pending_email_verification → live → failed
provisioning_started_at       # When provisioning began
provisioning_completed_at     # When provisioning finished
provisioning_failed_at        # When provisioning failed
provisioning_error            # Error message if failed
email_verified_at             # When owner verified email

# Demo Mode
demo_mode                     # Is this a demo website?
demo_seed_pack                # Which seed pack was used
demo_last_reset_at            # Last demo reset
demo_reset_interval           # How often to reset

# Subscription
subscription (has_one)        # Link to Pwb::Subscription
realty_assets_count           # Count of properties

# Users & Team
users (has_many)              # All users on this website
user_memberships (has_many)   # Team member relationships
admins (method)               # Only admin/owner members

# System
shard_name                    # Database shard (for multi-tenant scaling)
created_at                    # Website creation date
updated_at                    # Last modification
```

### Website Creation via ProvisioningService

**Key Steps:**
1. Create Website record in 'pending' state
2. Create UserMembership (user as owner)
3. Assign owner to website
4. Seed provisioning data (agency, links, field keys, pages, properties)
5. Send email verification
6. After email verification, website becomes 'live'

---

## 3. Subscription & Plan System

### Plan Model

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/plan.rb`

**Fields:**
```ruby
# Identification
name                          # Internal identifier (e.g., 'starter')
slug                          # URL-friendly slug (unique, lowercase)
display_name                  # User-facing name (e.g., 'Starter')
description                   # Marketing description
position                      # Display order

# Pricing
price_cents                   # Price in cents (9900 = $99.00)
price_currency                # Currency code (USD, EUR, GBP)
billing_interval              # 'month' or 'year'

# Trial Period
trial_value                   # Number of trial periods (14)
trial_unit                    # 'days', 'weeks', or 'months'
trial_days                    # DEPRECATED - use trial_value/trial_unit

# Limits
property_limit                # Max properties (nil = unlimited)
user_limit                    # Max team members (nil = unlimited)

# Features
features                      # JSONB array of feature keys
active                        # Is plan available?
public                        # Show on pricing page?
```

### Available Plans (from `/config/subscription_plans.yml`)

#### Starter Plan
- **Price:** $99/month
- **Trial:** 1 month
- **Limits:** 50 properties, 2 users
- **Features:** default_theme, subdomain_only, single_language, ssl_included, email_support

#### Professional Plan
- **Price:** $299/month
- **Trial:** 1 month
- **Limits:** 200 properties, 5 users
- **Features:** all_themes, custom_domain, multi_language_3, ssl_included, priority_support, analytics

#### Enterprise Plan
- **Price:** $2,499/month
- **Trial:** 1 month
- **Limits:** Unlimited properties, unlimited users
- **Features:** custom_theme, custom_domain, multi_language_8, ssl_included, dedicated_support, analytics, custom_integrations, api_access, white_label

### Subscription Model

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/subscription.rb`

**Fields:**
```ruby
# Identification
website_id                    # Which website (unique per website)
plan_id                       # Which plan

# Status State Machine
status                        # trialing → active → past_due → canceled → expired
                              # Can also: reactivate (canceled/expired → active)

# Billing Period
current_period_starts_at      # Billing period start
current_period_ends_at        # Billing period end
trial_ends_at                 # When trial ends

# Cancellation
canceled_at                   # When user canceled
cancel_at_period_end          # Cancel at end of period?

# External Integration
external_provider             # Stripe, etc.
external_id                   # Provider subscription ID
external_customer_id          # Provider customer ID

# Additional Data
metadata                      # JSONB for storing extra info
created_at                    # Subscription creation
updated_at                    # Last modification
```

**Status Flow:**
- **trialing:** In trial period (default for new subscriptions)
- **active:** Paid/active subscription
- **past_due:** Payment failed but within grace period
- **canceled:** User canceled subscription
- **expired:** Trial or subscription ended

### Subscription Events

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/subscription_event.rb`

Logs all subscription state changes with metadata for audit trail.

---

## 4. Contact & Inquiry Management

### Contact Model (Visitors/Leads)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/contact.rb`

**Fields for CRM:**
```ruby
# Name & Title
first_name                    # Contact's first name
last_name                     # Contact's last name
title                         # Mr., Mrs. enum
other_names                   # Additional names

# Email & Phone
primary_email                 # Main email address
other_email                   # Secondary email
primary_phone_number          # Main phone
other_phone_number            # Secondary phone
fax                           # Fax number

# Web Presence
website_url                   # Their website
facebook_id, twitter_id       # Social IDs
linkedin_id, skype_id

# Location
primary_address_id            # Home/office address
secondary_address_id          # Alternative address
nationality                   # Country

# Documentation
documentation_type            # ID type enum
documentation_id              # ID number
other documentation

# Relationships
website_id                    # Which website (tenant scoped)
user_id                       # Associated user account (optional)
has_many :messages            # All inquiries from this contact

# Tracking
created_at                    # Contact creation date
updated_at                    # Last update
```

**Key Methods:**
```ruby
display_name                  # Returns formatted name or email
unread_messages_count         # Count of unread inquiries
last_message                  # Most recent inquiry
```

### Message Model (Inquiries/Inquiries)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/message.rb`

**Fields for CRM:**
```ruby
# Content
title                         # Message subject
content                       # Message body

# Sender Information
contact_id                    # Who sent it
origin_email                  # Email if contact not recorded
origin_ip                     # Sender's IP address

# Delivery Status
delivered_at                  # When forwarded to agent
delivery_email                # Which email was used
delivery_success              # Did delivery succeed?
delivery_error                # Error if failed

# Status
read                          # Has agent read this?
created_at                    # When message received

# Technical
host                          # Source host
url                           # Page URL where sent
latitude, longitude           # Geolocation
locale                        # Language
user_agent                    # Browser info

# Relationships
website_id                    # Which website (tenant)
```

**Scopes:**
```ruby
unread                        # Unread messages
read                          # Read messages
recent                        # Ordered by created_at desc
```

---

## 5. Activity & Analytics Tracking

### Ahoy Analytics Integration

**Files:**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/ahoy/visit.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/ahoy/event.rb`

**Visit Model (User Sessions):**
```ruby
# Session Info
visit_token                   # Unique session ID
visitor_token                 # Unique visitor ID
user_id                       # Logged-in user (optional)
website_id                    # Which website

# Traffic Source
landing_page                  # First page visited
referrer                      # HTTP referrer
referring_domain              # Referrer domain

# UTM Parameters
utm_source, utm_medium        # Campaign tracking
utm_campaign, utm_content
utm_term

# Device & Geo
device_type                   # Desktop, Mobile, Tablet
browser, os                   # Browser and OS
country, region, city         # Location

# Tracking
started_at                    # Session start time
has_many :events              # Page views and custom events
```

**Event Model (Page Views & Actions):**
```ruby
# Event Info
name                          # Event type (page_view, click, etc.)
properties                    # Event-specific data (JSONB)
time                          # When event occurred

# Relationships
visit_id                      # Which session
user_id                       # Which user (optional)
website_id                    # Which website

# Tracking
created_at                    # Event timestamp
```

**Sample Scopes:**
```ruby
Visit.unique_visitors         # Count unique visitors
Visit.by_day                  # Visits per day
Visit.by_referrer             # Traffic by source
Visit.by_country              # Geographic breakdown
Visit.by_device               # Device breakdown
Visit.from_search             # Search traffic
Visit.from_social             # Social traffic
Visit.direct                  # Direct traffic
Visit.mobile                  # Mobile visits
Visit.desktop                 # Desktop visits
```

### Authentication Audit Log

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/auth_audit_log.rb`

**Fields:**
```ruby
# Event Info
event_type                    # login_success, login_failure, oauth_success, etc.
ip_address                    # Login IP
user_agent                    # Browser info

# User Info
user_id                       # User logging in
email                         # User email
website_id                    # Website context

# Tracking
created_at                    # Event timestamp

# Available Events
EVENT_TYPES = [
  'registration',             # New user signup
  'login_success',            # Successful login
  'login_failure',            # Failed login
  'oauth_success',            # OAuth login success
  'oauth_failure',            # OAuth login failure
  'account_locked',           # Account locked
  'account_unlocked',         # Account unlocked
  'password_changed',         # Password change
  'email_verified'            # Email verification
]
```

---

## 6. Data Available for CRM Integration

### Relationship Data

#### User-Website Relationship
- User can own multiple websites
- Each website has an owner (user with 'owner' role in membership)
- Multi-team support: multiple users per website

#### Contact-Message Relationship
- One contact can have many messages
- Each message tracked separately
- Read/unread status per message
- Chronological ordering available

#### Website-Subscription Relationship
- One subscription per website
- Tracks plan, status, trial period, billing dates
- Events log all state changes

### Key Metrics Available

**User/Onboarding:**
- Onboarding completion rate
- Onboarding step distribution
- Time to completion (started_at → completed_at)
- Active vs. churned users

**Website/Tenant:**
- Properties count (realty_assets_count)
- Website status (live, pending, failed, etc.)
- Time to live (created_at → provisioning_completed_at)
- Provisioning failure tracking

**Engagement:**
- Message/inquiry count per contact
- Unread messages
- Last message date (recency)
- Website visits (Ahoy)
- Page views by type

**Subscription:**
- Plan tier distribution
- Trial status and duration
- Subscription status breakdown
- Plan change history (events)

**Activity:**
- Sign-in frequency (sign_in_count)
- Last login (current_sign_in_at)
- Login location (current_sign_in_ip)
- Device type distribution (from Ahoy)
- Geographic distribution (from Ahoy)

### Data Isolation

**Tenant Isolation:**
- Every record is scoped to `website_id`
- Queries should always filter by current website
- PwbTenant namespace provides tenant-scoped models
- Multi-tenant queries unsafe without filtering

---

## 7. Integration Touchpoints

### Existing Integration Patterns

**Twilio Integration Example:**
- Location: `docs/integrations/TWILIO_INTEGRATION_PLAN.md`
- Pattern: Per-tenant configuration
- Storage: Environment variables
- Graceful degradation when not configured

**External Feed Integration:**
- Per-tenant feed configuration
- Provider selection and credentials
- Polling and webhook support
- Feed management methods on Website model

### CRM Integration Opportunities

**Push Events to Capture:**
1. **New User Registration** → Lead created
   - Triggered: Step 1 complete
   - Data: email, first_names, last_names, phone_number_primary

2. **Website Created** → Account created
   - Triggered: Step 2 complete
   - Data: company_display_name, site_type, subdomain, owner info

3. **Website Live** → Account activated
   - Triggered: Email verified, website goes live
   - Data: website_id, subdomain, live_at

4. **Subscription Created/Changed** → Plan assigned
   - Triggered: Website provisioning complete
   - Data: plan_id, plan name, price, limits, features

5. **New Inquiry/Message** → Lead/opportunity created
   - Triggered: Contact form submitted
   - Data: contact info, message content, property (optional)

6. **User Activity** → Engagement metrics
   - Triggered: User signs in, visits pages, etc.
   - Data: user_id, website_id, activity type, timestamp

### Required Infrastructure

For CRM integration:
1. **Webhook endpoint** on CRM side to receive events
2. **Authentication** (API key, OAuth, webhook signatures)
3. **Per-website configuration** (store webhook URL, credentials, mapping)
4. **Retry logic** for failed webhook deliveries
5. **Event queue** for async delivery reliability
6. **Data mapping** between PWB fields and CRM fields

---

## 8. Files Reference Summary

### Core Models
| Model | File | Key Fields |
|-------|------|-----------|
| User | `app/models/pwb/user.rb` | email, first_names, last_names, phone_number_primary, onboarding_state, sign_in_count |
| Website | `app/models/pwb/website.rb` | subdomain, company_display_name, site_type, provisioning_state, owner_email |
| Subscription | `app/models/pwb/subscription.rb` | website_id, plan_id, status, trial_ends_at, current_period_ends_at |
| Plan | `app/models/pwb/plan.rb` | slug, display_name, price_cents, property_limit, user_limit, features |
| Contact | `app/models/pwb/contact.rb` | first_name, last_name, primary_email, primary_phone_number, website_id |
| Message | `app/models/pwb/message.rb` | title, content, contact_id, origin_email, origin_ip, read |
| UserMembership | `app/models/pwb/user_membership.rb` | user_id, website_id, role, active |
| AuthAuditLog | `app/models/pwb/auth_audit_log.rb` | event_type, user_id, email, ip_address |
| Ahoy::Visit | `app/models/ahoy/visit.rb` | user_id, website_id, landing_page, device_type, utm_* |
| Ahoy::Event | `app/models/ahoy/event.rb` | name, properties, visit_id, user_id |

### Controllers
| Controller | File | Key Actions |
|-----------|------|------------|
| SignupController | `app/controllers/pwb/signup_controller.rb` | new, start, configure, save_configuration, provisioning, provision, complete |
| RegistrationsController | `app/controllers/pwb/devise/registrations_controller.rb` | edit, update (Devise) |

### Services
| Service | File | Key Methods |
|---------|------|------------|
| ProvisioningService | `app/services/pwb/provisioning_service.rb` | start_signup, configure_site, provision_website, retry_provisioning |

### Configuration
| Config | File |
|--------|------|
| Plans | `/config/subscription_plans.yml` |
| Devise | `/config/initializers/devise.rb` |

---

## 9. CRM Data Mapping Examples

### Prospect/Lead Record
```
PWB Field → CRM Field
user.first_names → First Name
user.last_names → Last Name
user.email → Email
user.phone_number_primary → Phone
user.created_at → Date Entered
```

### Account Record
```
PWB Field → CRM Field
website.subdomain → Account Name / ID
website.company_display_name → Company Name
website.site_type → Industry / Type
website.owner_email → Account Owner Email
subscription.plan.display_name → Plan Type
subscription.status → Account Status
website.provisioning_state → Account Phase
website.created_at → Account Created Date
website.provisioning_completed_at → Go-Live Date
```

### Contact Record
```
PWB Field → CRM Field
contact.first_name → First Name
contact.last_name → Last Name
contact.primary_email → Email
contact.primary_phone_number → Phone
contact.primary_address → Address
website_id → Associated Account
```

### Activity Record
```
PWB Field → CRM Field
message.title → Activity Subject
message.content → Activity Notes
message.contact_id → Contact
message.created_at → Activity Date
message.read → Activity Status
message.origin_email → Email Address
```

---

## 10. Key Insights for CRM Strategy

1. **Multi-Tenant Architecture:** All data must be filtered by `website_id`. Each website is completely isolated.

2. **Onboarding State Machine:** Users go through distinct states (lead → registered → email_verified → onboarding → active). This is ideal for CRM pipeline stages.

3. **Provisioning State Machine:** Websites have detailed provisioning states that track progress through setup. Valuable for tracking customer implementation status.

4. **Subscription Model:** Clean separation between plan definition and subscription instance. Multiple plan tiers available.

5. **Team Support:** Multiple users can be on one website with role-based access (owner, admin, member, viewer).

6. **Activity Tracking:** Ahoy integration provides rich session and event data. Separate from authentication logging (AuthAuditLog).

7. **Contact Management:** Distinct contact and message models enable lead tracking separate from user accounts.

8. **Audit Logging:** Authentication events are logged separately for security/compliance tracking.

---

## Next Steps for Implementation

1. **API Endpoint Planning:** Design endpoints to expose CRM-relevant data
2. **Webhook Implementation:** Create event publishing system for real-time sync
3. **Zoho/Zendesk Connectors:** Build specific integrations for target CRM platforms
4. **Data Mapping:** Define exact field-to-field mappings for each platform
5. **Authentication:** Implement OAuth or API key management for per-website credentials
6. **Retry Logic:** Queue system for reliable webhook delivery
7. **Testing:** E2E tests for signup → CRM record flow
