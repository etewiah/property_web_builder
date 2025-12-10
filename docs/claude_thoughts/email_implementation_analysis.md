# PropertyWebBuilder Email Implementation Analysis

**Date:** December 9, 2025
**Scope:** Research and analysis of email handling in PropertyWebBuilder
**Status:** Complete - No code modifications made

---

## Executive Summary

PropertyWebBuilder has a **minimal but functional email implementation** focused on two core use cases:

1. **Contact form submissions** - sending enquiries to agency contact forms
2. **User authentication** - Devise-managed password resets and confirmations

The system uses **synchronous email delivery** in production with **no robust error handling**, and **does not implement background job processing for emails**. While this is acceptable for low-volume operations, it presents risks for production reliability.

---

## 1. Mailers Overview

### Existing Mailers

#### 1.1 ApplicationMailer (`app/mailers/pwb/application_mailer.rb`)
- Base mailer class extending `ActionMailer::Base`
- Uses layout: `mailer`
- **Key Issue**: Default `from` address is commented out - no default sender configured
- **Missing**: No explicit configuration for `default_url_options` or error handling

```ruby
module Pwb
  class ApplicationMailer < ActionMailer::Base
    # default from: 'service@propertywebbuilder.com'  # COMMENTED OUT
    layout "mailer"
  end
end
```

#### 1.2 EnquiryMailer (`app/mailers/pwb/enquiry_mailer.rb`)
- Handles two email scenarios:
  - **`general_enquiry_targeting_agency(contact, message)`** - Contact form submissions
  - **`property_enquiry_targeting_agency(contact, message, property)`** - Property inquiry forms

**Characteristics:**
- Dynamic sender email from `message.origin_email` with fallback
- Dynamic recipient from `message.delivery_email` (agency configured address)
- Uses internationalized titles (i18n)
- Custom template paths: `app/views/pwb/mailers/`

**Code:**
```ruby
def general_enquiry_targeting_agency(contact, message)
  from = message.origin_email.presence || 
         Pwb::ApplicationMailer.default[:from] || 
         "service@propertywebbuilder.com"
  
  @contact = contact
  @message = message
  @title = message.title.presence || 
           (I18n.t "mailers.general_enquiry_targeting_agency.title")
  
  mail(to: message.delivery_email,
       from: from,
       subject: @title,
       template_path: "pwb/mailers",
       template_name: "general_enquiry_targeting_agency")
end
```

#### 1.3 Devise Mailers
- **Implicit** - Devise gem provides default mailer
- **Customized templates** in `app/views/devise/mailer/`:
  - `confirmation_instructions.html.erb`
  - `reset_password_instructions.html.erb`
  - `password_change.html.erb`
  - `unlock_instructions.html.erb`

---

## 2. Email Configuration

### 2.1 Environment-Specific Settings

#### Development (`config/environments/development.rb`)
```ruby
config.action_mailer.raise_delivery_errors = false
config.action_mailer.perform_caching = false
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
# No delivery_method specified - defaults to :smtp
```

#### Test (`config/environments/test.rb`)
```ruby
config.action_mailer.delivery_method = :test
config.action_mailer.default_url_options = { host: "example.com" }
```

#### E2E (`config/environments/e2e.rb`)
```ruby
config.action_mailer.raise_delivery_errors = false
config.action_mailer.perform_caching = false
config.action_mailer.default_url_options = { host: "localhost", port: 3001 }
```

#### Production (`config/environments/production.rb`)
```ruby
# COMMENTED OUT - SMTP NOT CONFIGURED!
# config.action_mailer.smtp_settings = {
#   user_name: Rails.application.credentials.dig(:smtp, :user_name),
#   password: Rails.application.credentials.dig(:smtp, :password),
#   address: "smtp.example.com",
#   port: 587,
#   authentication: :plain
# }

config.action_mailer.default_url_options = { host: "example.com" }
# No raise_delivery_errors setting
```

### 2.2 Devise Configuration (`config/initializers/devise.rb`)

```ruby
config.mailer_sender = "please-change-me-at-config-initializers-devise@example.com"
```

**Critical Issues:**
- Devise sender address is placeholder, not production-ready
- No custom mailer specified - uses Devise defaults

### 2.3 Action Mailer Defaults

**Per Rails defaults when no specific config:**
- `delivery_method`: `:smtp`
- `raise_delivery_errors`: true (in production, false in dev/test)
- `perform_deliveries`: true

---

## 3. Email Templates

### 3.1 Layout (`app/views/layouts/mailer.html.erb`)
```html
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <style>
      /* Email styles need to be inline */
    </style>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

**Issues:**
- No inline CSS styling
- Very minimal HTML structure
- No responsive design or mobile optimization

### 3.2 Enquiry Email Templates

#### General Enquiry (`app/views/pwb/mailers/general_enquiry_targeting_agency.html.erb`)
- Displays message title (underlined)
- Shows timestamp
- Shows contact name and email
- Shows contact phone
- Shows full message content

#### Property Enquiry (`app/views/pwb/mailers/property_enquiry_targeting_agency.html.erb`)
- Same as general enquiry, plus:
- Property title and description
- Link to property listing

**Template Issues:**
- Basic HTML without styling
- No email client-specific optimizations
- No text-only alternative version (`.text.erb`)
- No fallback for images or styling

### 3.3 Devise Templates
- Standard Devise templates, customized for styling
- Use i18n for multilingual support
- Include dynamic links for authentication actions

---

## 4. Email Models & Data

### 4.1 Contact Model (`app/models/pwb/contact.rb`)

**Stores:** `pwb_contacts` table

**Key Fields:**
- `first_name`, `last_name`, `other_names`
- `title` (enum: mr, mrs)
- `primary_email`, `other_email` (indexed)
- `primary_phone_number`, `other_phone_number`
- `primary_address_id`, `secondary_address_id` (foreign keys)
- `user_id` (optional link to auth user)
- `fax`, `skype_id`, `facebook_id`, `linkedin_id`, `twitter_id`, `website`
- `flags` (integer, default: 0) - for status management
- `details` (JSON) - extensible data

**Multi-Tenancy:** Has `website_id` foreign key for tenant scoping

**Usage Pattern:**
- `find_or_initialize_by(primary_email: ...)` in contact forms
- Attributes updated with form submission data
- Associated with multiple messages via `has_many :messages`

### 4.2 Message Model (`app/models/pwb/message.rb`)

**Stores:** `pwb_messages` table

**Key Fields:**
- `title` - email subject
- `content` - email body/message text
- `contact_id` - foreign key to Contact
- `website_id` - tenant identifier
- `origin_email`, `delivery_email` - sender and recipient
- `origin_ip`, `host`, `url` - request metadata
- `user_agent` - browser information
- `locale` - language selection
- `longitude`, `latitude` - geolocation data
- `delivery_success` (boolean, default: false) - **NOT USED**

**Critical Issue:** `delivery_success` field exists but is **never updated** when emails are sent

---

## 5. Email Delivery Mechanisms

### 5.1 Contact Form Submission (General)

**Flow:** `ContactUsController#contact_us_ajax` → `EnquiryMailer#general_enquiry_targeting_agency`

```ruby
# In app/controllers/pwb/contact_us_controller.rb
@contact = @current_website.contacts.find_or_initialize_by(primary_email: params[:contact][:email])
@contact.attributes = { ... }

@enquiry = Message.new({
  website: @current_website,
  title: params[:contact][:subject],
  content: params[:contact][:message],
  delivery_email: @current_agency.email_for_general_contact_form,
  # ... other fields
})

unless @enquiry.save && @contact.save
  # error handling
end

EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_now

# Send push notification via ntfy (async)
if @current_website.ntfy_enabled?
  NtfyNotificationJob.perform_later(@current_website.id, :inquiry, @enquiry.id)
end
```

**Delivery Method:** `deliver_now` (synchronous, blocking)

### 5.2 Property Inquiry Forms

**Two entry points:**

#### a) Traditional Rails Controller (`PropsController#request_property_info_ajax`)
```ruby
EnquiryMailer.property_enquiry_targeting_agency(@contact, @enquiry, @property).deliver
```

**Delivery Method:** `deliver` (shorthand for `deliver_now`)

#### b) GraphQL Mutation (`Mutations::SubmitListingEnquiry#resolve`)
```ruby
Pwb::EnquiryMailer.property_enquiry_targeting_agency(@contact, @enquiry, @property).deliver
```

**Delivery Method:** `deliver` (shorthand for `deliver_now`)

**Critical Issue:** No background job wrapping - emails are sent synchronously

### 5.3 Devise Authentication Emails

**Automatic via Devise:**
- Password reset requests
- Email confirmation
- Account unlock instructions
- Password change notifications

**Delivery:** Synchronous via ActionMailer default delivery method

---

## 6. Background Job Processing

### 6.1 NtfyNotificationJob (Not Email, but Related)

**Location:** `app/jobs/ntfy_notification_job.rb`

**Purpose:** Sends push notifications via ntfy.sh service (not traditional email)

**Characteristics:**
- Queued as `:notifications`
- Retry on error with exponential backoff (3 attempts)
- Discard on `ActiveRecord::RecordNotFound`
- Async notification delivery

**Usage in Contact Forms:**
```ruby
if @current_website.ntfy_enabled?
  NtfyNotificationJob.perform_later(@current_website.id, :inquiry, @enquiry.id)
end
```

### 6.2 ApplicationJob

**Location:** `app/jobs/pwb/application_job.rb`

**Status:** Minimal - just extends `ActiveJob::Base`

**No specialized email job handling.**

---

## 7. Production Readiness Assessment

### 7.1 Critical Issues (Production Blockers)

| Issue | Severity | Impact |
|-------|----------|--------|
| **SMTP not configured** | CRITICAL | Emails will fail to send |
| **No from address configured** | CRITICAL | Emails may be rejected or flagged as spam |
| **Synchronous delivery** | HIGH | Email delays block HTTP requests |
| **No error handling** | HIGH | Silent failures, no tracking |
| **No delivery retry logic** | HIGH | Transient failures cause lost emails |
| **No delivery tracking** | MEDIUM | Cannot monitor email success/failure |

### 7.2 Functional Gaps

| Gap | Impact |
|-----|--------|
| No text-only email versions | Accessibility, client compatibility |
| No email validation/sanitization | Security risk (injection) |
| No rate limiting | Spam/abuse potential |
| No unsubscribe mechanism | Compliance risk (CAN-SPAM, GDPR) |
| No bounce handling | Accumulates invalid addresses |
| No email analytics | Cannot track opens/clicks |

### 7.3 Current Configuration Status

```
Environment      | Delivery Method | SMTP Configured | From Address | Raise Errors
-----------------|-----------------|-----------------|--------------|-------------
Development      | :smtp           | Not set         | Missing      | false
Test             | :test           | N/A             | example.com  | N/A
E2E              | :smtp           | Not set         | Missing      | false
Production       | :smtp           | COMMENTED OUT   | example.com  | Not set
```

---

## 8. Email Flow Diagram

```
User Contact Form Submission
    ↓
ContactUsController#contact_us_ajax
    ├─ Create Contact (find_or_initialize)
    ├─ Create Message (enquiry)
    ├─ Save both to DB
    ↓
EnquiryMailer#general_enquiry_targeting_agency
    ↓
[SYNCHRONOUS DELIVERY] deliver_now
    ├─ Determine from/to addresses
    ├─ Render template
    ├─ Call SMTP (or fail silently)
    ↓
HTTP Response to Client (after email sent or timeout)
    ↓
Optional: NtfyNotificationJob.perform_later (async push notification)
```

---

## 9. Internationalization (i18n) Support

### Email Translations

**File:** `config/locales/en.yml`

```yaml
mailers:
  confirm_registration: Please confirm your account through the link below
  from: From
  general_enquiry_targeting_agency:
    title: General enquiry from your website
  message: Message
  phone: Tel
  property: Property
  property_enquiry_targeting_agency:
    title: Enquiry regarding a property
  received_on: Received on
  welcome: Welcome
```

**Available Locales:** en, es, de, pt-BR, pt-PT, bg, ro (based on locale files)

**Status:** Partial i18n support for email content
- Mailer subject titles translated
- Template content partially hardcoded (not all strings i18n'd)

---

## 10. Multi-Tenancy Email Isolation

### Tenant Scoping

**Contact Model:**
```ruby
belongs_to :website, class_name: 'Pwb::Website', optional: true
```

**Message Model:**
```ruby
belongs_to :website, class_name: 'Pwb::Website', optional: true
```

**Agency Configuration:**
- `email_for_general_contact_form` - per-website setting
- `email_for_property_contact_form` - per-website setting

**Isolation Status:** Good
- Emails use website-specific contact addresses
- Contact/message data is website-scoped
- No cross-tenant email leakage observed

---

## 11. Testing

### Mailer Tests (`spec/mailers/pwb/enquiry_mailer_spec.rb`)

**Coverage:**
- ✓ General enquiry email delivers successfully
- ✓ General enquiry has correct to/from/subject
- ✓ Property enquiry email delivers successfully
- ✓ Property enquiry renders property information

**Test Delivery Method:** `:test` (accumulates in `ActionMailer::Base.deliveries`)

**Gaps:**
- No error condition testing
- No SMTP failure testing
- No timeout/retry testing
- No template rendering edge cases
- No i18n translation testing

### Mailer Preview (`spec/mailers/previews/pwb/enquiry_mailer_preview.rb`)

**Available at:** `http://localhost:3000/rails/mailers/pwb/enquiry_mailer` (when enabled)

**Methods:**
- `general_enquiry_targeting_agency` - shows sample general enquiry
- `property_enquiry_targeting_agency` - shows sample property enquiry

---

## 12. Security Considerations

### Potential Vulnerabilities

1. **Email Header Injection**
   - `delivery_email` and `origin_email` not validated before use
   - Risk: Attacker could inject arbitrary headers
   - Status: MEDIUM RISK

2. **Template Injection**
   - User-supplied data (`message.content`) rendered in template
   - Rails escapes by default, but worth monitoring
   - Status: LOW RISK (Rails auto-escapes)

3. **Information Disclosure**
   - User IP, user agent, referrer logged in message
   - Accessible to staff
   - Status: Expected, but requires staff data security

4. **No Rate Limiting**
   - Contact form submission not rate-limited
   - Risk: Spam/DoS via contact forms
   - Status: MEDIUM RISK

---

## 13. Configuration Options Available

### ApplicationMailer

- `default from:` - specify sender address (commented out)
- `layout` - email layout template (set to "mailer")

### EnquiryMailer

- Uses instance variables for data
- Custom template paths configurable via mail() parameters
- Can add `default reply_to:` or `default cc:` options

### Devise Configuration

- `config.mailer_sender` - Devise email from address (currently placeholder)
- `config.mailer` - Custom mailer class (not overridden)
- Customize templates in `app/views/devise/mailer/`

### Environment-Specific

- `config.action_mailer.delivery_method`
- `config.action_mailer.smtp_settings`
- `config.action_mailer.default_url_options`
- `config.action_mailer.raise_delivery_errors`
- `config.action_mailer.perform_caching`

---

## 14. Recommended Improvements (Not Implemented)

### Priority 1 - Blocking Issues
1. **Configure SMTP** in `config/environments/production.rb`
2. **Set proper from address** in ApplicationMailer
3. **Add email delivery jobs** to prevent blocking requests
4. **Add error handling** for delivery failures

### Priority 2 - Production Hardening
5. Add `text-only` email versions (`.text.erb`)
6. Add email validation/sanitization
7. Track delivery success in database
8. Add retry logic with exponential backoff
9. Implement rate limiting on contact forms

### Priority 3 - Enhancement
10. Add email logging/monitoring
11. Add unsubscribe mechanism (if newsletters added)
12. Add bounce handling
13. Improve email CSS/styling
14. Add email template tests

---

## 15. Key File Locations

```
Core Implementation:
├── app/mailers/
│   ├── pwb/application_mailer.rb
│   └── pwb/enquiry_mailer.rb
├── app/views/pwb/mailers/
│   ├── general_enquiry_targeting_agency.html.erb
│   └── property_enquiry_targeting_agency.html.erb
├── app/views/devise/mailer/
│   ├── confirmation_instructions.html.erb
│   ├── reset_password_instructions.html.erb
│   ├── password_change.html.erb
│   └── unlock_instructions.html.erb
├── app/views/layouts/mailer.html.erb

Configuration:
├── config/environments/
│   ├── development.rb
│   ├── test.rb
│   ├── e2e.rb
│   └── production.rb
├── config/initializers/devise.rb

Models:
├── app/models/pwb/contact.rb
├── app/models/pwb/message.rb
├── app/models/pwb/user.rb (Devise)

Controllers/Forms:
├── app/controllers/pwb/contact_us_controller.rb
├── app/controllers/pwb/props_controller.rb
├── app/graphql/mutations/submit_listing_enquiry.rb

Related Services:
├── app/services/ntfy_service.rb (push notifications)
├── app/jobs/ntfy_notification_job.rb
├── app/jobs/pwb/application_job.rb

Tests:
├── spec/mailers/pwb/enquiry_mailer_spec.rb
└── spec/mailers/previews/pwb/enquiry_mailer_preview.rb

Translations:
└── config/locales/en.yml (and other language files)
```

---

## 16. Summary Assessment

### Current State
PropertyWebBuilder has a **working but minimal email implementation** suitable for:
- Small-scale deployments
- Development/testing environments
- Low-volume contact form submissions

### Production Readiness: **NEEDS CONFIGURATION**
- Code structure is sound
- Core functionality exists
- Missing: SMTP configuration and error handling

### Risk Level: **MEDIUM-HIGH**
- Synchronous delivery can cause request timeouts
- No SMTP configured means production emails will fail
- No error tracking means silent failures

### Estimated Setup Time: **2-4 hours**
To make production-ready:
1. Configure SMTP credentials (30 min)
2. Add background job processing for emails (1-2 hours)
3. Add error handling and logging (30-60 min)
4. Test end-to-end (1 hour)

---

## Conclusion

PropertyWebBuilder's email system is **functionally complete for basic use cases** but requires configuration and hardening before production deployment. The architecture supports the multi-tenant model well, and the code is clean and maintainable. Primary concerns are around reliability and error handling rather than design issues.

The presence of `delivery_success` field in the Message model suggests prior consideration of tracking, but it's not currently implemented. This would be a valuable addition for production monitoring.

