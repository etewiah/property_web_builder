# Email System - File Reference Guide

Complete list of all files related to the email system with absolute paths, line numbers for key functionality, and descriptions.

---

## Mailer Classes

### ApplicationMailer Base Class

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/mailers/pwb/application_mailer.rb`

```ruby
# Lines 1-21
module Pwb
  class ApplicationMailer < ActionMailer::Base
    # Line 7: Default from address - can be overridden via DEFAULT_FROM_EMAIL env var
    default from: -> { default_from_address }
    
    # Line 9: Layout used by all mailers
    layout "mailer"
    
    # Lines 13-15: Get default from address from env or fallback
    def self.default_from_address
      ENV.fetch("DEFAULT_FROM_EMAIL") { "PropertyWebBuilder <noreply@propertywebbuilder.com>" }
    end
```

### EnquiryMailer

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/mailers/pwb/enquiry_mailer.rb`

**Key Lines**:
- Line 4: Class definition
- Line 5-6: Callbacks for delivery tracking
- Line 11-24: `general_enquiry_targeting_agency` method
- Line 28-42: `property_enquiry_targeting_agency` method
- Line 47-55: `mark_delivery_success` callback - updates message on success
- Line 58-71: `handle_delivery_error` callback - logs errors to message record

```ruby
def general_enquiry_targeting_agency(contact, message)
  # Lines 12-14: Set instance variables for template
  @contact = contact
  @message = message
  @title = message.title.presence || I18n.t("mailers.general_enquiry_targeting_agency.title")
  
  # Lines 17-23: Send mail with proper from/to/reply-to
  mail(
    to: message.delivery_email,                    # Recipient
    reply_to: message.origin_email,               # Enquirer's email
    subject: @title,
    template_path: "pwb/mailers",
    template_name: "general_enquiry_targeting_agency"
  )
end

def property_enquiry_targeting_agency(contact, message, property)
  # Similar structure for property inquiries
  # Additional: @property = property
end
```

---

## Email Templates

### Main Application Templates

#### general_enquiry_targeting_agency.html.erb

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/mailers/general_enquiry_targeting_agency.html.erb`

**Content** (30 lines):
- Lines 1-8: Header with title
- Lines 10-22: Contact information (from, phone)
- Lines 24-30: Message content

**Variables Used**:
```erb
<%= @title %>                           # Email subject
<%= @message.created_at %>             # Timestamp
<%= @contact.first_name %>             # Contact name
<%= @contact.primary_email %>          # Contact email (display)
<%= @contact.primary_phone_number %>   # Contact phone
<%= @message.content %>                # Message body
```

**I18n Keys Used**:
- `mailers.received_on`
- `mailers.from`
- `mailers.phone`
- `mailers.message`

#### property_enquiry_targeting_agency.html.erb

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/mailers/property_enquiry_targeting_agency.html.erb`

**Content** (46 lines):
- Lines 1-30: Same as general inquiry (header, contact, message)
- Lines 33-45: Property information section

**Additional Variables**:
```erb
<%= @property.title %>             # Property name
<%= @property.description %>       # Property description
<a href="<%= @message.url %>">     # Clickable URL back to property
```

**I18n Key Added**:
- `mailers.property`

### Layout Template

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/views/layouts/mailer.html.erb`

**Content** (13 lines):
```erb
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

### Devise Mailer Templates

**Directory**: `/Users/etewiah/dev/sites-older/property_web_builder/app/views/devise/mailer/`

**Files** (4 total):
1. `confirmation_instructions.html.erb` - Account confirmation email
2. `reset_password_instructions.html.erb` - Password reset email
3. `password_change.html.erb` - Password changed notification
4. `unlock_instructions.html.erb` - Account unlock email

---

## Configuration Files

### Production Environment

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/config/environments/production.rb`

**Email Configuration** (Lines 59-103):
- Lines 59-62: Enable email delivery, async via Solid Queue
- Lines 65: Queue name for mailer jobs
- Lines 69-72: Host configuration for links in emails
- Lines 74-103: SMTP configuration from environment variables

```ruby
# Line 65: Queue for async delivery
config.action_mailer.deliver_later_queue_name = :mailers

# Lines 69-72: Host for email links
config.action_mailer.default_url_options = {
  host: ENV.fetch("MAILER_HOST") { ENV.fetch("APP_HOST", "example.com") },
  protocol: "https"
}

# Lines 87-97: SMTP configuration
if ENV["SMTP_ADDRESS"].present?
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV["SMTP_ADDRESS"],
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    domain: ENV.fetch("SMTP_DOMAIN") { ENV.fetch("MAILER_HOST") { ENV.fetch("APP_HOST", "example.com") } },
    authentication: ENV.fetch("SMTP_AUTH", "plain").to_sym,
    enable_starttls_auto: true
  }
else
  # Line 102: Fallback to test delivery (no actual sending)
  config.action_mailer.delivery_method = :test
end
```

### Development Environment

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/config/environments/development.rb`

**Email Configuration** (Lines 34-69):
- Line 40: Host for email links (localhost:3000)
- Lines 47-69: Three options for email delivery:
  1. SMTP (if SMTP_ADDRESS set)
  2. letter_opener (if gem installed)
  3. test (default - log emails)

```ruby
# Line 40: Development host
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

# Lines 47-69: Dev email delivery configuration
if ENV["SMTP_ADDRESS"].present?
  # Option 1: Test with real SMTP (e.g., Amazon SES)
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  # ... SMTP settings
elsif defined?(LetterOpener)
  # Option 2: Use letter_opener to preview emails in browser
  config.action_mailer.delivery_method = :letter_opener
else
  # Option 3: Default - log emails (not sent)
  config.action_mailer.delivery_method = :test
end
```

### Test Environment

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/config/environments/test.rb`

**Email Configuration**:
```ruby
# ActionMailer::Base.deliveries array accumulates sent emails in the :test delivery method
# This is set automatically for test environment
```

### Devise Configuration

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/devise.rb`

**Email Configuration** (Lines 11-25):
- Lines 16-19: Set mailer sender from env var or DEFAULT_FROM_EMAIL

```ruby
# Lines 16-19: Devise mailer from address
config.mailer_sender = ENV.fetch("DEVISE_MAILER_SENDER") {
  ENV.fetch("DEFAULT_FROM_EMAIL") { "PropertyWebBuilder <noreply@propertywebbuilder.com>" }
}
```

### Amazon SES Configuration

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/amazon_ses.rb`

**Key Methods** (Lines 1-193):
- Lines 40-45: `smtp_configured?` - Check SMTP setup
- Lines 47-51: `api_configured?` - Check API setup
- Lines 53-56: `region` - Get AWS region
- Lines 58-80: `client` - Get SESV2 client
- Lines 82-102: `account_info` - Get account details
- Lines 104-121: `verified_identities` - List verified emails/domains
- Lines 123-137: `identity_verified?(identity)` - Check if verified
- Lines 139-166: `send_test_email(to:, from:)` - Send test email
- Lines 168-190: `configuration_summary` - Get config details

```ruby
# Module: Pwb::SES
# Usage: Pwb::SES.smtp_configured? Pwb::SES.account_info Pwb::SES.verified_identities
```

---

## Model Files

### Message Model

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/message.rb`

**Content** (16 lines):
```ruby
class Pwb::Message < ApplicationRecord
  self.table_name = 'pwb_messages'
  
  belongs_to :website, class_name: 'Pwb::Website', optional: true
  belongs_to :contact, optional: true, class_name: 'Pwb::Contact'
end
```

**Key Fields** (from schema):
- `website_id` - Tenant identifier
- `contact_id` - Who sent the inquiry
- `delivery_email` - Where to send
- `delivery_success` - Success flag
- `delivered_at` - Delivery timestamp
- `delivery_error` - Error message
- `origin_email` - Visitor's email (reply-to)

### Tenant-Scoped Message

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb_tenant/message.rb`

**Content** (15 lines):
```ruby
class PwbTenant::Message < Pwb::Message
  include RequiresTenant
  acts_as_tenant :website, class_name: 'Pwb::Website'
end
```

### Contact Model

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/contact.rb`

**Email-Related Fields**:
- `primary_email` - Contact's email
- `primary_phone_number` - Contact's phone
- `first_name` - Contact's name
- `website_id` - Tenant identifier

### Agency Model

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/agency.rb`

**Email Configuration Fields** (Lines 19-23):
```ruby
# From as_json method showing email-related fields
only: %w[
  display_name company_name
  phone_number_primary phone_number_mobile phone_number_other
  email_primary email_for_property_contact_form email_for_general_contact_form
]
```

**Key Methods** (Lines 17-33):
- Line 22: `email_primary`
- Line 22: `email_for_property_contact_form`
- Line 22: `email_for_general_contact_form`

---

## Controller Files

### Contact Us Controller

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/contact_us_controller.rb`

**Email Sending** (Line 106):
```ruby
# Line 106: Send general inquiry email async
EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_later
```

**Email Configuration** (Lines 78, 94-100):
```ruby
# Line 78: Get delivery email from agency
delivery_email: @current_agency.email_for_general_contact_form

# Lines 94-100: Handle missing email config
unless @current_agency.email_for_general_contact_form.present?
  @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"
  StructuredLogger.warn('[ContactForm] No delivery email configured', ...)
end
```

### Props Controller

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/props_controller.rb`

**Email Sending** (Line 133):
```ruby
# Line 133: Send property inquiry email async
EnquiryMailer.property_enquiry_targeting_agency(@contact, @enquiry, @property).deliver_later
```

**Email Configuration** (Line 92):
```ruby
delivery_email: @current_agency.email_for_property_contact_form
```

### GraphQL Mutation

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/graphql/mutations/submit_listing_enquiry.rb`

**Email Sending** (Line 60):
```ruby
# Line 60: Send property inquiry email via GraphQL
Pwb::EnquiryMailer.property_enquiry_targeting_agency(@contact, @enquiry, @property).deliver_later
```

**Email Configuration** (Line 39):
```ruby
delivery_email: current_agency.email_for_property_contact_form
```

---

## Test & Preview Files

### Mailer Spec

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/spec/mailers/pwb/enquiry_mailer_spec.rb`

**Test Coverage** (65 lines):
- Lines 13-26: General enquiry tests
  - Subject line
  - Recipient (delivery_email)
  - From address
  - Reply-to address
- Lines 29-59: Property enquiry tests
  - Same as above plus body content check

**Key Assertions**:
```ruby
# Line 19: Subject verification
expect(mail.subject).to eq("General enquiry from your website")

# Line 20: Recipient verification
expect(mail.to).to eq(["test@test.com"])

# Line 22: From address verification
expect(mail.from.first).to eq(default_from_email)

# Line 24: Reply-to verification
expect(mail.reply_to).to eq(["jd@example.com"])

# Line 53: Body content check
expect(mail.body.encoded).to include 'Charming flat for sale'
```

### Mailer Preview

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/spec/mailers/previews/pwb/enquiry_mailer_preview.rb`

**Methods** (26 lines):
- Line 12-16: `general_enquiry_targeting_agency` preview
- Line 18-24: `property_enquiry_targeting_agency` preview

**Access**: http://localhost:3000/rails/mailers/pwb/enquiry_mailer

---

## Migration Files

### Message Table Schema

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/db/migrate/20161128200709_create_pwb_messages.rb`

Initial message table creation

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/db/migrate/20180109133855_add_contact_id_to_pwb_messages.rb`

Added contact relationship

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/db/migrate/20251204141849_add_website_to_contacts_messages_and_photos.rb`

Added website_id (tenant field)

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/db/migrate/20251209181022_add_delivery_tracking_to_messages.rb`

Added delivery tracking fields:
- `delivery_success` - Boolean
- `delivered_at` - Timestamp
- `delivery_error` - Text

---

## GraphQL Files

### Agency Type

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/graphql/types/agency_type.rb`

**Email Fields**:
```ruby
field :email_for_property_contact_form, String, null: true
field :email_for_general_contact_form, String, null: true
```

### Agency Controller (REST API)

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/api/v1/agency_controller.rb`

**Permitted Params**:
```ruby
:email_for_property_contact_form
:email_for_general_contact_form
```

### Tenant Admin Agencies Controller

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/agencies_controller.rb`

**Permitted Params**:
```ruby
:email_for_general_contact_form
```

---

## Summary Table

| Component | File Path | Lines | Purpose |
|-----------|-----------|-------|---------|
| ApplicationMailer | `/app/mailers/pwb/application_mailer.rb` | 21 | Base mailer class |
| EnquiryMailer | `/app/mailers/pwb/enquiry_mailer.rb` | 73 | Inquiry mailers |
| General Inquiry Template | `/app/views/pwb/mailers/general_enquiry_targeting_agency.html.erb` | 30 | Email template |
| Property Inquiry Template | `/app/views/pwb/mailers/property_enquiry_targeting_agency.html.erb` | 46 | Email template |
| Mailer Layout | `/app/views/layouts/mailer.html.erb` | 13 | Email layout |
| Production Config | `/config/environments/production.rb` | ~120 | SMTP config |
| Development Config | `/config/environments/development.rb` | ~80 | Dev email config |
| Devise Config | `/config/initializers/devise.rb` | ~50+ | Devise email |
| SES Config | `/config/initializers/amazon_ses.rb` | 193 | AWS SES integration |
| Message Model | `/app/models/pwb/message.rb` | 16 | Message entity |
| Tenant Message | `/app/models/pwb_tenant/message.rb` | 15 | Scoped message |
| Contact Model | `/app/models/pwb/contact.rb` | 41 | Contact entity |
| Agency Model | `/app/models/pwb/agency.rb` | 33 | Agency config |
| Contact Controller | `/app/controllers/pwb/contact_us_controller.rb` | 142 | Contact form |
| Props Controller | `/app/controllers/pwb/props_controller.rb` | ~150+ | Property inquiry |
| GraphQL Mutation | `/app/graphql/mutations/submit_listing_enquiry.rb` | 74 | GraphQL inquiry |
| Mailer Spec | `/spec/mailers/pwb/enquiry_mailer_spec.rb` | 65 | Tests |
| Mailer Preview | `/spec/mailers/previews/pwb/enquiry_mailer_preview.rb` | 26 | Preview emails |

---

## How to Find Things

**Email Sending**:
1. Start: `ContactUsController.contact_us_ajax` (line 106) or `PropsController.request_property_info_ajax` (line 133)
2. Mailer: `app/mailers/pwb/enquiry_mailer.rb`
3. Template: `app/views/pwb/mailers/*.html.erb`
4. Error Handling: Line 47-71 in `enquiry_mailer.rb`

**Email Configuration**:
1. SMTP: `config/environments/production.rb` (line 87-103)
2. From Address: `DEFAULT_FROM_EMAIL` env var
3. Per-Website Address: `Agency.email_for_*_contact_form`

**Database**:
1. Schema: `db/schema.rb` (search "pwb_messages")
2. Migrations: `db/migrate/*messages*.rb` (4 files)

**Testing**:
1. Preview: http://localhost:3000/rails/mailers/pwb/enquiry_mailer
2. Spec: `spec/mailers/pwb/enquiry_mailer_spec.rb`

**Documentation**:
1. This file: `/docs/email_file_reference.md`
2. Full exploration: `/docs/email_system_exploration.md`
3. Quick ref: `/docs/email_system_summary.md`
4. Multi-tenant: `/docs/email_multi_tenant_architecture.md`
