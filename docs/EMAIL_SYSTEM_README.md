# PropertyWebBuilder Email System Documentation

Complete documentation of the email system has been generated. Start here to understand the current email infrastructure.

## Documentation Files

### 1. Quick Reference (Start Here)
**File**: `docs/email_system_summary.md`

Quick overview of components, configuration, and troubleshooting. Best for:
- Quick lookups
- Configuration reference
- Common problems
- Component listing

**Contents**:
- Mailers and templates overview
- SMTP configuration examples
- Email routing flow
- Common troubleshooting

### 2. Complete Exploration Report
**File**: `docs/email_system_exploration.md`

Comprehensive analysis of the entire email system. Best for:
- Understanding the full architecture
- Learning about current capabilities
- Identifying limitations and gaps
- Planning enhancements

**Contents**:
- All 13 mailer methods documented
- Email template breakdown
- Configuration options
- Per-tenant customization features
- Database schema details
- I18n setup
- Testing coverage
- 12 key insights and opportunities

### 3. Multi-Tenancy Architecture
**File**: `docs/email_multi_tenant_architecture.md`

Deep dive into how email interacts with the multi-tenant system. Best for:
- Understanding tenant isolation
- Cross-tenant security
- Tenant-scoped configurations
- Data flow between tenants
- Testing tenant isolation

**Contents**:
- Tenant identification in emails
- Per-website email configuration
- Data isolation mechanisms
- Tenant-aware email journey
- Multi-tenant scenarios
- Security considerations
- Improvement suggestions

### 4. File Reference Guide
**File**: `docs/email_file_reference.md`

Complete index of all email-related files with line numbers and descriptions. Best for:
- Finding specific code
- Understanding code organization
- Locating configuration files
- Referencing migration files
- Finding tests and previews

**Contents**:
- Every mailer class with line references
- Every template file location
- Configuration files with specific line numbers
- All model files
- All controller entry points
- Test and preview files
- Summary table of all components

---

## Quick Facts

### Current Email System

**Mailers**: 2 classes
- `Pwb::ApplicationMailer` - Base class
- `Pwb::EnquiryMailer` - Inquiry notifications (2 methods)

**Templates**: 2 custom (+ 4 Devise)
- General inquiry
- Property inquiry
- (No per-website customization)

**Delivery**: 
- Async via Solid Queue
- Success/failure tracked on Message record
- Error logging to database and Rails logs

**Configuration**:
- SMTP via environment variables
- Supports any provider (SendGrid, Mailgun, SES, Postmark, etc.)
- Per-website recipient email via Agency model
- Global from address via DEFAULT_FROM_EMAIL

**Tenant Support**:
- Emails routed to per-website address
- Message records tagged with website_id
- Data isolated via acts_as_tenant
- Templates NOT per-website (global)

### Key Limitations

- No per-website email template customization
- No admin UI for email configuration
- No email preview before sending
- No website branding in emails
- No HTML/CSS email optimization
- No plain text versions
- No email scheduling
- No email analytics

### What Works Well

- Async delivery (non-blocking)
- Error tracking (database + logs)
- Provider agnostic (SMTP)
- Multi-tenant ready (routing)
- Structured logging
- Internationalization (I18n)
- AWS SES integration
- Comprehensive specs

---

## Getting Started

### 1. Understanding Current System (15 minutes)

Read in order:
1. `email_system_summary.md` - Get overview
2. `email_system_exploration.md` (sections 1-5) - Learn components

### 2. Configuration Review (10 minutes)

Check these files:
1. `config/environments/production.rb` - SMTP setup
2. `config/initializers/amazon_ses.rb` - SES integration
3. `config/initializers/devise.rb` - Devise email config

### 3. Email Sending Flow (10 minutes)

Trace the flow:
1. `/app/controllers/pwb/contact_us_controller.rb` (line 106)
   └─ `EnquiryMailer.general_enquiry_targeting_agency`
2. `/app/mailers/pwb/enquiry_mailer.rb` (lines 11-24)
   └─ Calls template
3. `/app/views/pwb/mailers/general_enquiry_targeting_agency.html.erb`
   └─ Rendered and sent

### 4. Testing in Development (5 minutes)

```bash
# Preview emails in browser
http://localhost:3000/rails/mailers/pwb/enquiry_mailer

# Run mailer specs
rspec spec/mailers/pwb/enquiry_mailer_spec.rb

# Check test email delivery (if SMTP configured)
# Look in ActionMailer::Base.deliveries
```

### 5. Multi-Tenant Understanding (20 minutes)

Read `email_multi_tenant_architecture.md`:
- How tenant isolation works
- Per-website email configuration
- Data flow across tenants
- Security considerations

---

## Configuration Reference

### Minimal Production Setup

```bash
# SMTP for any provider
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your-key

# Email settings
DEFAULT_FROM_EMAIL="My Site <noreply@mysite.com>"
MAILER_HOST=mysite.com

# Database must have Agency configured:
# Agency.email_for_general_contact_form
# Agency.email_for_property_contact_form
```

### AWS SES Setup

```bash
# SMTP (recommended for most cases)
SMTP_ADDRESS=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_USERNAME=your-ses-username
SMTP_PASSWORD=your-ses-password

# API (optional, for advanced features)
AWS_SES_ACCESS_KEY_ID=AKIA...
AWS_SES_SECRET_ACCESS_KEY=...
AWS_SES_REGION=us-east-1
```

### Per-Website Configuration

Update via admin panel or API:
```ruby
Agency.find_by(website_id: 1).update(
  email_for_general_contact_form: "contact@site1.com",
  email_for_property_contact_form: "properties@site1.com"
)
```

---

## Code Examples

### Sending an Email

```ruby
# General inquiry
contact = Contact.find(123)
message = Message.find(456)
EnquiryMailer.general_enquiry_targeting_agency(contact, message).deliver_later

# Property inquiry
property = ListedProperty.find(789)
Pwb::EnquiryMailer.property_enquiry_targeting_agency(contact, message, property).deliver_later
```

### Checking Delivery Status

```ruby
# View message delivery info
message = Message.find(123)
message.delivery_success    # => true/false
message.delivered_at        # => 2024-12-12 10:30:00
message.delivery_error      # => nil or error message
```

### Testing Email Configuration

```ruby
# Check SES is configured
Pwb::SES.smtp_configured?   # => true
Pwb::SES.api_configured?    # => true

# Get account info
Pwb::SES.account_info
# => { production_access: true, sending_enabled: true, ... }

# List verified identities
Pwb::SES.verified_identities

# Send test email
Pwb::SES.send_test_email(to: "test@example.com")
```

### Template Variables

```erb
<!-- Available in templates -->
<%= @title %>                   # Email subject
<%= @contact.first_name %>     # Contact name
<%= @contact.primary_email %>  # Contact email
<%= @message.content %>        # Message body
<%= @message.url %>            # Referrer URL
<%= @property.title %>         # Property name (property inquiry only)
<%= @property.description %>   # Property description (property inquiry only)

<!-- I18n translations -->
<%= t('mailers.received_on') %>
<%= t('mailers.from') %>
<%= t('mailers.property_enquiry_targeting_agency.title') %>
```

---

## Database Schema Reference

### pwb_messages table

```sql
CREATE TABLE pwb_messages (
  id SERIAL PRIMARY KEY,
  website_id BIGINT NOT NULL,           -- Tenant ID
  contact_id INTEGER,
  content TEXT,
  title VARCHAR,
  origin_email VARCHAR,                 -- Visitor's email
  delivery_email VARCHAR,               -- Where to send
  delivery_success BOOLEAN DEFAULT false,
  delivered_at DATETIME,
  delivery_error TEXT,
  url VARCHAR,                          -- Referrer
  host VARCHAR,
  origin_ip VARCHAR,
  user_agent TEXT,
  locale VARCHAR,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX (website_id)
);
```

### pwb_agencies table (email fields)

```sql
CREATE TABLE pwb_agencies (
  id SERIAL PRIMARY KEY,
  website_id BIGINT UNIQUE,
  email_primary VARCHAR,
  email_for_general_contact_form VARCHAR,
  email_for_property_contact_form VARCHAR,
  -- ... other fields
);
```

---

## Common Tasks

### Task: Change Global From Address

1. Set environment variable:
   ```bash
   DEFAULT_FROM_EMAIL="Support Team <support@mycompany.com>"
   ```

2. Restart app

### Task: Change Website Email Address

1. Via API:
   ```ruby
   agency = Website.find(1).agency
   agency.update(email_for_general_contact_form: "new@company.com")
   ```

2. Or via admin UI: TenantAdmin::AgenciesController

### Task: Test Email Delivery

1. Use Rails mailer preview:
   ```
   http://localhost:3000/rails/mailers/pwb/enquiry_mailer
   ```

2. Or send test email via SES:
   ```ruby
   Pwb::SES.send_test_email(to: "test@example.com")
   ```

### Task: Debug Email Not Sending

1. Check SMTP configured:
   ```bash
   ENV["SMTP_ADDRESS"]  # Should be set
   ENV["SMTP_USERNAME"] # Should be set
   ENV["SMTP_PASSWORD"] # Should be set
   ```

2. Check per-website config:
   ```ruby
   Agency.find_by(website_id: X).email_for_general_contact_form  # Should not be nil
   ```

3. Check delivery tracking:
   ```ruby
   Message.find(X).delivery_error  # Any error message?
   ```

4. Check logs:
   ```
   grep "[EnquiryMailer]" log/production.log
   ```

### Task: Add Custom Email Field

1. Modify template (not recommended - affects all websites):
   ```erb
   <%= t('mailers.custom_field') %>
   ```

2. Add I18n translation

3. Test with mailer preview

**Better approach**: Build template customization system first

---

## Next Steps

### For Enhancement Planning

1. Read `email_system_exploration.md` (sections 10-13)
2. Review "Limitations & Gaps" section
3. Consider "Improvements for Better Tenant Support"
4. Start with short-term improvements

### For Implementation

1. Consult file paths in `email_file_reference.md`
2. Review test examples in `email_system_exploration.md` (section 8)
3. Reference code examples in this README
4. Follow existing code patterns in `app/mailers/` and `app/controllers/`

### For Understanding Multi-Tenancy

1. Read `email_multi_tenant_architecture.md`
2. Review tenant scoping examples
3. Understand `acts_as_tenant` pattern
4. Check data isolation test examples

---

## Documentation Index

| Document | Purpose | Length | Time to Read |
|----------|---------|--------|--------------|
| THIS FILE | Start here, overview | 3 pages | 5 min |
| email_system_summary.md | Quick reference | 4 pages | 10 min |
| email_system_exploration.md | Comprehensive deep dive | 20 pages | 30 min |
| email_multi_tenant_architecture.md | Multi-tenancy details | 15 pages | 25 min |
| email_file_reference.md | Code location index | 16 pages | Lookup reference |

---

## Questions?

- **How do I send a test email?** See "Testing Email Delivery" in Quick Reference
- **Where's the email configuration?** See `email_file_reference.md` - Configuration Files section
- **How does tenant isolation work?** See `email_multi_tenant_architecture.md`
- **What are the limitations?** See `email_system_exploration.md` - Section 10
- **How do I customize emails per-website?** Not currently supported - see "Opportunities" in exploration report

---

## File Navigation

```
docs/
├── EMAIL_SYSTEM_README.md (THIS FILE)
│   └─ Start here for overview
├── email_system_summary.md
│   └─ Quick reference and checklists
├── email_system_exploration.md
│   └─ Complete analysis (sections 1-13)
├── email_multi_tenant_architecture.md
│   └─ Tenant-specific details
└── email_file_reference.md
    └─ Code file index with line numbers
```

---

## Last Updated

Created: December 12, 2024

This documentation was generated by exploring the PropertyWebBuilder codebase to provide a complete understanding of the current email system architecture, configuration, and usage patterns.
