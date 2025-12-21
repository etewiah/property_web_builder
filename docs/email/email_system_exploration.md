# Email System Exploration Report

## Overview

PropertyWebBuilder has a basic email system for sending inquiry notifications. The current setup is relatively simple with:
- Two mailer classes handling inquiry notifications
- Environment variable-based SMTP configuration
- Per-tenant email delivery addresses (via Agency model)
- Async email delivery via Solid Queue
- Email delivery tracking (success/error logging)

---

## 1. Current Mailer Classes

### Location: `/app/mailers/pwb/`

#### **Pwb::ApplicationMailer** 
- Base class for all mailers
- Located at: `/Users/etewiah/dev/sites-older/property_web_builder/app/mailers/pwb/application_mailer.rb`
- Features:
  - Default `from` address configured via `DEFAULT_FROM_EMAIL` env variable
  - Fallback: `"PropertyWebBuilder <noreply@propertywebbuilder.com>"`
  - Uses standard Rails layout: `mailer.html.erb`
  
```ruby
# Default from address pattern: "Name <email@example.com>" or just "email@example.com"
default from: -> { default_from_address }
```

#### **Pwb::EnquiryMailer**
- Located at: `/Users/etewiah/dev/sites-older/property_web_builder/app/mailers/pwb/enquiry_mailer.rb`
- Methods:
  1. **`general_enquiry_targeting_agency(contact, message)`**
     - For general contact form inquiries
     - Sends to: `message.delivery_email` (from Agency)
     - Reply-to: `message.origin_email` (from visitor)
     - Subject: I18n-based with fallback
     
  2. **`property_enquiry_targeting_agency(contact, message, property)`**
     - For property-specific inquiries
     - Includes property details in email
     - Sends to: `message.delivery_email` (from Agency)
     - Reply-to: `message.origin_email` (from visitor)
     - Subject: I18n-based with fallback

- Features:
  - Callbacks: `after_deliver :mark_delivery_success`
  - Error handling: `rescue_from StandardError, with: :handle_delivery_error`
  - Delivery tracking: Updates message with delivery status and timestamps
  - Logging: Uses `Rails.logger` for delivery success/failure

### Summary
- **Total Mailers**: 2 (1 base + 1 functional)
- **Total Email Methods**: 2
- **Email Types**: General inquiry, Property inquiry (to agency)

---

## 2. Email Templates

### Location: `/app/views/`

#### Main Application Mailer Views
**Path**: `/app/views/pwb/mailers/`

1. **`general_enquiry_targeting_agency.html.erb`** (30 lines)
   - Template path: `pwb/mailers`
   - Variables used:
     - `@title` - Email subject/title
     - `@message` - Message object (created_at, content)
     - `@contact` - Contact object (first_name, primary_email, primary_phone_number)
   - Content: Structured inquiry details with translations

2. **`property_enquiry_targeting_agency.html.erb`** (46 lines)
   - Template path: `pwb/mailers`
   - Variables used:
     - `@title` - Email subject/title
     - `@message` - Message object (created_at, content, url)
     - `@contact` - Contact object (first_name, primary_email, primary_phone_number)
     - `@property` - Property object (title, description)
   - Content: Inquiry details plus property information with clickable URL

#### Layout Template
**Path**: `/app/views/layouts/mailer.html.erb` (13 lines)
- Basic HTML5 structure
- Single yield statement
- Empty style block (inline styles needed for email)
- Comment: "Email styles need to be inline"

#### Devise Mailer Templates
**Path**: `/app/views/devise/mailer/`
- `confirmation_instructions.html.erb` - Account confirmation
- `reset_password_instructions.html.erb` - Password reset
- `password_change.html.erb` - Password changed notification
- `unlock_instructions.html.erb` - Account unlock

### Summary
- **Total Custom Templates**: 2 (+ 1 layout)
- **Total Devise Templates**: 4
- **Template Language**: ERB with I18n translations
- **Email Format**: HTML only (no text version)
- **Customization Level**: Basic static templates per email type

---

## 3. Email Configuration

### Environment Configuration

#### Production (`config/environments/production.rb`)
- **Email Delivery**: Async via Solid Queue
- **Queue Name**: `:mailers`
- **Error Handling**: `raise_delivery_errors = true`
- **Host Configuration**: 
  - `MAILER_HOST` env var (primary)
  - Fallback: `APP_HOST` env var
  - Default: `"example.com"`
- **SMTP Configuration**:
  - Required env vars:
    - `SMTP_ADDRESS` (e.g., smtp.sendgrid.net)
    - `SMTP_PORT` (default: 587)
    - `SMTP_USERNAME` (API key)
    - `SMTP_PASSWORD` (API secret)
  - Optional env vars:
    - `SMTP_DOMAIN` (defaults to MAILER_HOST)
    - `SMTP_AUTH` (default: "plain")
  - Fallback: `:test` delivery method (no actual delivery)

#### Development (`config/environments/development.rb`)
- **Priority Order**:
  1. SMTP (if `SMTP_ADDRESS` is set) - for testing with real providers
  2. letter_opener gem (if installed) - preview emails in browser
  3. :test delivery method (default) - log emails
- **Error Handling**: `raise_delivery_errors = false`
- **Host**: `localhost:3000`

#### Test (`config/environments/test.rb`)
- **Delivery Method**: `:test`
- **Behavior**: Accumulates emails in `ActionMailer::Base.deliveries` array

### Default Configuration
**Location**: `/app/config/initializers/devise.rb`
- **Devise From Address**: 
  - Env var: `DEVISE_MAILER_SENDER`
  - Fallback: `DEFAULT_FROM_EMAIL`
  - Default: `"PropertyWebBuilder <noreply@propertywebbuilder.com>"`

### Amazon SES Integration
**Location**: `/config/initializers/amazon_ses.rb`

**Features**:
- SMTP configuration support
- SES API client for advanced features
- Account information retrieval
- Verified identity management
- Test email sending capability

**Configuration Methods**:
```ruby
Pwb::SES.smtp_configured?        # Check SMTP setup
Pwb::SES.api_configured?          # Check API setup
Pwb::SES.region                   # Get AWS region
Pwb::SES.client                   # Get SESV2 client
Pwb::SES.account_info             # Get account details
Pwb::SES.verified_identities      # List verified emails/domains
Pwb::SES.identity_verified?(id)   # Check if verified
Pwb::SES.send_test_email(...)     # Send test email
Pwb::SES.configuration_summary    # Get config details
```

**Environment Variables**:
- **SMTP**:
  - `SMTP_ADDRESS` - SES SMTP endpoint
  - `SMTP_PORT` - Typically 587
  - `SMTP_USERNAME` - SES SMTP username
  - `SMTP_PASSWORD` - SES SMTP password
  - `SMTP_AUTH` - Authentication type (default: login)
  - `SMTP_DOMAIN` - HELO domain (default: MAILER_HOST)

- **SES API**:
  - `AWS_SES_ACCESS_KEY_ID` - AWS access key
  - `AWS_SES_SECRET_ACCESS_KEY` - AWS secret key
  - `AWS_SES_REGION` - AWS region (default: us-east-1)
  - Falls back to default AWS credential chain if not set

### Summary
- **Email Providers Supported**: Any SMTP provider (SendGrid, Mailgun, Postmark, SES, etc.)
- **Async Delivery**: Yes (Solid Queue)
- **Delivery Tracking**: Yes (success/error logging)
- **Per-Provider Configuration**: Via environment variables
- **Default From Address**: Customizable via env var

---

## 4. Email Template Management

### Current Approach
- **Hard-coded Templates**: All templates are static ERB files in `/app/views/pwb/mailers/`
- **No Admin UI**: No interface for editing templates
- **No Template Versioning**: No history or drafts
- **No Template Variables Documentation**: Implicit in templates

### Template Variables (Hard-coded)
All templates use I18n for user-facing strings:
- `t('mailers.received_on')`
- `t('mailers.from')`
- `t('mailers.phone')`
- `t('mailers.message')`
- `t('mailers.property')`
- `t('mailers.general_enquiry_targeting_agency.title')`
- `t('mailers.property_enquiry_targeting_agency.title')`

### Limitations
1. **No Per-Tenant Customization**: All websites use identical templates
2. **No Dynamic Content**: Templates are static code
3. **No Preview Interface**: Need to use Rails mailer preview
4. **No Template Inheritance**: Each template is standalone
5. **No CSS Management**: Inline styles recommended but not implemented

### Summary
- **Template Management**: Code-based (no database)
- **Customization**: None (all websites identical)
- **Admin Interface**: None
- **Flexibility**: Low

---

## 5. Per-Tenant Email Customization

### Current Tenant-Aware Email Settings

#### Agency Model
**Location**: `/app/models/pwb/agency.rb`

**Email-Related Fields** (stored in `pwb_agencies` table):
1. `email_primary` - Primary agency email
2. `email_for_property_contact_form` - Where property inquiries are sent
3. `email_for_general_contact_form` - Where general inquiries are sent

These are used by:
- `ContactUsController.contact_us_ajax` - General inquiries
- `PropsController.request_property_info_ajax` - Property inquiries
- `SubmitListingEnquiry` GraphQL mutation - GraphQL-based property inquiries

#### Message Model
**Location**: `/app/models/pwb/message.rb` and `/app/models/pwb_tenant/message.rb`

**Email-Related Fields** (from schema):
```
delivery_email      - Where to send the email (from Agency)
delivery_success    - Boolean flag (success/failure)
delivered_at        - Timestamp of delivery
delivery_error      - Error message if failed
origin_email        - Visitor's email (for reply-to)
```

**Tenant Isolation**:
- `Pwb::Message` - Not tenant-scoped (for console/cross-tenant)
- `PwbTenant::Message` - Tenant-scoped (for web requests)
- Uses `acts_as_tenant :website`

#### Email Routing Flow
```
Contact Form Submission
       ↓
ContactUsController.contact_us_ajax
       ↓
Gets delivery_email from: @current_agency.email_for_general_contact_form
       ↓
Creates Message with: delivery_email = @current_agency.email_for_general_contact_form
       ↓
EnquiryMailer.general_enquiry_targeting_agency(contact, message)
       ↓
mail(to: message.delivery_email, reply_to: message.origin_email, ...)
```

### Customization Points
1. **Delivery Email**: Per-agency (per-website/tenant)
2. **Reply-To Email**: Per-visitor (dynamically from inquiry)
3. **From Address**: Global (via DEFAULT_FROM_EMAIL env var)
4. **Subject**: Via I18n locale (can be per-website if translations managed per-tenant)

### Limitations
1. **No Template Customization**: All websites see identical email content
2. **No Branding**: No website name/logo in emails
3. **No Subject Customization**: Only via I18n (global)
4. **No HTML Layout Customization**: All websites use same layout
5. **No Custom Fields**: No ability to include custom inquiry fields in emails

### Summary
- **Tenant Awareness**: Partial (delivery address only)
- **Customization Options**: Limited to recipient email
- **Branding**: Not supported
- **Content Customization**: Not supported

---

## 6. Email Delivery Process

### Sending Flow
```
1. Contact Form Submission
   ↓
2. Create Message & Contact records
   ↓
3. EnquiryMailer.method_name(contact, message, ...).deliver_later
   ↓
4. Solid Queue picks up job
   ↓
5. ActionMailer sends via SMTP
   ↓
6. after_deliver callback: mark_delivery_success
   OR
   rescue_from StandardError: handle_delivery_error
   ↓
7. Message record updated with status
```

### Job Configuration
- **Queue Adapter**: Solid Queue (production) / In-process (test/dev)
- **Queue Name**: `:mailers`
- **Retry Behavior**: Configurable via Solid Queue
- **Error Handling**: Captured on Message record

### Integration Points
1. **ContactUsController.contact_us_ajax** (line 106)
   - Sends: `EnquiryMailer.general_enquiry_targeting_agency`
   - Trigger: Form submission

2. **PropsController.request_property_info_ajax** (line 133)
   - Sends: `EnquiryMailer.property_enquiry_targeting_agency`
   - Trigger: Property inquiry form

3. **SubmitListingEnquiry GraphQL Mutation** (line 60)
   - Sends: `Pwb::EnquiryMailer.property_enquiry_targeting_agency`
   - Trigger: GraphQL API call

### Logging
- **Success**: `Rails.logger.info "[EnquiryMailer] Successfully delivered email for message ##{@message.id}"`
- **Error**: `Rails.logger.error "[EnquiryMailer] Failed to deliver email for message ##{@message.id}: #{exception.message}"`
- **Structured Logging**: Also uses `StructuredLogger` in controllers

### Summary
- **Delivery**: Async (fire-and-forget)
- **Tracking**: Yes (success/error with timestamp)
- **Reliability**: Solid Queue handles retries
- **Observability**: Good logging coverage

---

## 7. Models & Database Schema

### Message Model (`pwb_messages` table)

**Schema Fields**:
```
id              - Primary key
website_id      - Foreign key (tenant identification)
contact_id      - Foreign key (who sent inquiry)
client_id       - Legacy field (deprecated?)
content         - Message body text
title           - Message subject/title
origin_email    - Visitor's email address
delivery_email  - Where email should be sent (from Agency)
delivery_success - Boolean (success flag)
delivered_at    - Timestamp of delivery
delivery_error  - Error message if delivery failed
url             - Referrer URL (where inquiry came from)
host            - Host/domain
origin_ip       - Visitor IP address
user_agent      - Visitor browser info
latitude        - Geographic location
longitude       - Geographic location
locale          - Language locale
created_at      - Record creation timestamp
updated_at      - Record update timestamp
```

**Associations**:
- `belongs_to :website` (tenant identification)
- `belongs_to :contact` (visitor info)
- Tenant-scoped via `acts_as_tenant :website` (in PwbTenant::Message)

### Contact Model (`pwb_contacts` table)

**Email-Related Fields**:
```
primary_email   - Contact's email address
primary_phone_number - Contact's phone
first_name      - Contact's name
```

**Associations**:
- `belongs_to :website` (tenant)
- `has_many :messages`
- Address relationships (primary_address, secondary_address)

### Agency Model (`pwb_agencies` table)

**Email Configuration Fields**:
```
email_primary   - Primary agency email
email_for_property_contact_form - Where property inquiries go
email_for_general_contact_form - Where general inquiries go
```

**Association**:
- `belongs_to :website` (one-to-one with Website)

### Summary
- **Schema**: Well-structured for tenant isolation
- **Tracking**: Comprehensive delivery tracking
- **Audit Trail**: IP, user-agent, referrer captured
- **Extensibility**: Room for additional fields

---

## 8. Testing

### Mailer Specs
**Location**: `/spec/mailers/pwb/enquiry_mailer_spec.rb`

**Test Coverage**:
1. **General Enquiry Tests**:
   - Subject line matches I18n key
   - Recipient is delivery_email
   - From address is DEFAULT_FROM_EMAIL
   - Reply-to is origin_email

2. **Property Enquiry Tests**:
   - Subject line matches I18n key
   - Recipient is delivery_email
   - From address is DEFAULT_FROM_EMAIL
   - Reply-to is origin_email
   - Body includes property title and description
   - Body includes clickable property URL

**Mailer Preview**
**Location**: `/spec/mailers/previews/pwb/enquiry_mailer_preview.rb`
- Provides preview URL: `http://localhost:3000/rails/mailers/pwb/enquiry_mailer`
- Methods:
  - `general_enquiry_targeting_agency`
  - `property_enquiry_targeting_agency`

### Summary
- **Test Level**: Good coverage of happy paths
- **Preview Support**: Yes (Rails mailer preview)
- **Edge Cases**: Limited testing of error scenarios
- **Integration Tests**: Not visible in mailer specs

---

## 9. Internationalization (I18n)

### Translation Keys Used
From email templates:
- `mailers.received_on` - "Received on" label
- `mailers.from` - "From" label
- `mailers.phone` - "Phone" label
- `mailers.message` - "Message" label
- `mailers.property` - "Property" label
- `mailers.general_enquiry_targeting_agency.title` - General inquiry subject
- `mailers.property_enquiry_targeting_agency.title` - Property inquiry subject

### I18n Features
- Dynamic locale setting from form: `I18n.locale = params["contact"]["locale"]`
- Fallback to default locale: `I18n.default_locale`
- Per-message locale tracking: `Message.locale` field

### Translation File Location
Not examined in this exploration, but referenced via:
- `I18n.t(key)` calls in templates and controllers

### Summary
- **Multilingual Support**: Yes
- **Per-Message Locale**: Tracked on Message record
- **Locale Awareness**: Dynamic based on form input
- **Translation Scope**: Email subjects and labels

---

## 10. Current Limitations & Gaps

### Template Customization
- [ ] No per-website email templates
- [ ] No admin interface to edit templates
- [ ] No template preview before sending
- [ ] HTML/CSS not optimized for emails
- [ ] No plain text versions

### Personalization
- [ ] No website branding in emails
- [ ] No custom inquiry fields
- [ ] No email signatures with website info
- [ ] Subject lines not customizable per-website

### Advanced Features
- [ ] No email scheduling
- [ ] No email templates for other scenarios (welcome, password reset customization)
- [ ] No email analytics/tracking
- [ ] No A/B testing
- [ ] No email queuing with retry logic visibility
- [ ] No email frequency/throttling controls

### Admin Interface
- [ ] No email template management UI
- [ ] No email configuration UI
- [ ] No email testing interface (beyond mailer preview)
- [ ] No email delivery dashboard

### Documentation
- [ ] No email template variable documentation
- [ ] No email configuration guide
- [ ] No troubleshooting guide for delivery issues
- [ ] No API documentation for email-related endpoints

---

## 11. Related Code Files

### Email Sending Entry Points
1. `/app/controllers/pwb/contact_us_controller.rb` - Line 106 (general inquiry)
2. `/app/controllers/pwb/props_controller.rb` - Line 133 (property inquiry)
3. `/app/graphql/mutations/submit_listing_enquiry.rb` - Line 60 (GraphQL)

### Configuration Files
1. `/config/environments/production.rb` - Email delivery config
2. `/config/environments/development.rb` - Dev email config
3. `/config/initializers/devise.rb` - Devise email config
4. `/config/initializers/amazon_ses.rb` - SES integration

### Models
1. `/app/models/pwb/message.rb` - Message model
2. `/app/models/pwb_tenant/message.rb` - Tenant-scoped Message
3. `/app/models/pwb/contact.rb` - Contact model
4. `/app/models/pwb/agency.rb` - Agency model (email config)
5. `/app/models/pwb/website.rb` - Website model (tenant)

### Mailers
1. `/app/mailers/pwb/application_mailer.rb` - Base mailer
2. `/app/mailers/pwb/enquiry_mailer.rb` - Inquiry mailer

### Views
1. `/app/views/pwb/mailers/general_enquiry_targeting_agency.html.erb`
2. `/app/views/pwb/mailers/property_enquiry_targeting_agency.html.erb`
3. `/app/views/layouts/mailer.html.erb`
4. `/app/views/devise/mailer/*.html.erb` - Devise templates (4 files)

### Tests & Previews
1. `/spec/mailers/pwb/enquiry_mailer_spec.rb`
2. `/spec/mailers/previews/pwb/enquiry_mailer_preview.rb`

---

## 12. Summary Statistics

| Metric | Count |
|--------|-------|
| Mailer Classes | 2 |
| Email Methods | 2 |
| Email Templates (custom) | 2 |
| Devise Templates | 4 |
| Email Configuration Methods | ~10 |
| Email-Related Models | 4 |
| Email Delivery Integrations | 3 |
| Test Files | 1 |
| Configuration Files | 3 |

---

## 13. Key Insights

### Strengths
1. **Multi-Tenant Ready**: Database schema supports per-website email addresses
2. **Async Delivery**: Uses Solid Queue for non-blocking email sending
3. **Error Tracking**: Comprehensive delivery error logging on Message records
4. **Provider Agnostic**: Supports any SMTP provider via environment variables
5. **SES Integration**: Built-in AWS SES support with API access
6. **Structured Logging**: Uses both Rails logger and StructuredLogger
7. **Internationalization**: I18n support with dynamic locale selection

### Weaknesses
1. **Limited Customization**: No per-website template customization
2. **No Admin Interface**: Template management is code-based
3. **Basic Templates**: No CSS optimization, no plain text versions
4. **No Personalization**: Website branding not supported
5. **Hard-coded Content**: Template content not in database
6. **Limited Email Types**: Only inquiry notifications (no transactional emails)

### Opportunities
1. Build template customization system (database-backed)
2. Create admin UI for template editing
3. Add HTML email template builder with preview
4. Support custom inquiry fields in emails
5. Add email analytics/tracking
6. Create email configuration dashboard
7. Support HTML and plain text versions
8. Add website branding to email templates

---

## Conclusion

PropertyWebBuilder has a **functional but basic** email system primarily designed for inquiry notifications. It's well-integrated with the multi-tenant architecture but lacks flexibility for different website branding and customization. The current setup is production-ready for standard use cases but would benefit significantly from a template management system that allows per-tenant customization.
