# Email System & Multi-Tenancy Architecture

## Overview

The email system is partially tenant-aware. While emails are routed per-website (tenant), the template content and branding are global. This document explains the current architecture and how multi-tenancy relates to email functionality.

---

## 1. Tenant Identification in Email System

### By Website Association

Every email is associated with a specific website (tenant) through the Message model:

```ruby
class Pwb::Message < ApplicationRecord
  self.table_name = 'pwb_messages'
  belongs_to :website, class_name: 'Pwb::Website', optional: true
  belongs_to :contact, optional: true, class_name: 'Pwb::Contact'
end

# Tenant-scoped version for web requests
class PwbTenant::Message < Pwb::Message
  include RequiresTenant
  acts_as_tenant :website, class_name: 'Pwb::Website'
end
```

### Tenant Isolation

**Code Path for General Inquiry**:
```ruby
# ContactUsController (in web request context)
def contact_us_ajax
  # Current website is set by request router
  # (subdomain routing identifies the tenant)
  
  @contact = @current_website.contacts.find_or_initialize_by(primary_email: params[:contact][:email])
  # ...
  @enquiry = Message.new({
    website: @current_website,  # <- TENANT IDENTIFIER
    delivery_email: @current_agency.email_for_general_contact_form,
    # ... other fields
  })
  
  @enquiry.save
  EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_later
end
```

**Isolation Method**:
- `@current_website` set by middleware/before_action
- Message tagged with website_id
- When retrieving: PwbTenant::Message filters by `acts_as_tenant`

### Database Schema

```sql
CREATE TABLE pwb_messages (
  id SERIAL PRIMARY KEY,
  website_id BIGINT NOT NULL,  -- TENANT IDENTIFIER
  contact_id INTEGER,
  content TEXT,
  delivery_email VARCHAR,
  delivery_success BOOLEAN DEFAULT false,
  delivered_at DATETIME,
  delivery_error TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX (website_id)
);

CREATE TABLE pwb_agencies (
  id SERIAL PRIMARY KEY,
  website_id BIGINT UNIQUE,  -- One agency per website
  email_primary VARCHAR,
  email_for_property_contact_form VARCHAR,
  email_for_general_contact_form VARCHAR,
  -- ... other fields
);

CREATE TABLE pwb_contacts (
  id SERIAL PRIMARY KEY,
  website_id BIGINT,  -- TENANT IDENTIFIER
  primary_email VARCHAR,
  primary_phone_number VARCHAR,
  -- ... other fields
  INDEX (website_id)
);
```

---

## 2. Per-Tenant Email Configuration

### Agency Model - Email Settings

Each website has exactly one Agency with email configuration:

```ruby
class Pwb::Website < ApplicationRecord
  has_one :agency, class_name: 'Pwb::Agency'
end

class Pwb::Agency < ApplicationRecord
  belongs_to :website, class_name: 'Pwb::Website', optional: true
  
  # Email configuration fields
  # email_primary              - Primary agency email
  # email_for_property_contact_form    - Routes property inquiries here
  # email_for_general_contact_form     - Routes general inquiries here
end
```

### Tenant Email Routing

```
Website A (abc.com)
  └─ Agency
      ├─ email_for_general_contact_form: general@companyA.com
      └─ email_for_property_contact_form: props@companyA.com

Website B (xyz.com)
  └─ Agency
      ├─ email_for_general_contact_form: hello@companyB.com
      └─ email_for_property_contact_form: inquiries@companyB.com

Website C (inactive tenant)
  └─ Agency
      ├─ email_for_general_contact_form: (not set)
      └─ email_for_property_contact_form: (not set)
```

### Configuration Admin

**Where Email Addresses Are Set**:
- Admin panel: `TenantAdmin::AgenciesController`
  - Params: `:email_for_general_contact_form`, `:email_for_property_contact_form`
  - Only accessible by tenant admins (authenticated users with website membership)

**Fallback Behavior**:
```ruby
unless @current_agency.email_for_general_contact_form.present?
  @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"
  # Email still sent, but to fallback address
  # Logged as warning: "No delivery email configured"
end
```

---

## 3. Tenant-Scoped Access Control

### Request Routing

**Subdomain-Based Tenant Identification**:
```ruby
# Subdomain: abc.propertywebbuilder.com
# ↓
# Before action sets: @current_website = Website.find_by_subdomain('abc')
# ↓
# Controller uses @current_website for all queries
```

**Multi-Website Users**:
```ruby
class Pwb::User < ApplicationRecord
  has_many :user_memberships
  has_many :websites, through: :user_memberships
end

# User with 2 websites:
# User.websites = [Website A, Website B]
# Each website has separate email configuration
```

### Scope Isolation

**Web Request Context** (uses PwbTenant models):
```ruby
# In web request for Website A
PwbTenant::Message.all  # Only messages for Website A
  # Due to: acts_as_tenant :website, class_name: 'Pwb::Website'

# In web request for Website B
PwbTenant::Message.all  # Only messages for Website B
```

**Console Context** (uses Pwb models, no scoping):
```ruby
# In Rails console
Pwb::Message.all  # All messages from all websites
Pwb::Message.where(website_id: website.id)  # Explicitly scope if needed
```

---

## 4. Email Template Architecture

### Current Limitation: Global Templates

**Templates Are Not Tenant-Scoped**:
```ruby
# All tenants use identical template
EnquiryMailer.general_enquiry_targeting_agency(contact, message)
# ↓
# Uses: /app/views/pwb/mailers/general_enquiry_targeting_agency.html.erb
# This is the SAME template for ALL websites
```

### Tenant-Specific Content Not Supported

| Feature | Supported? | Location | Notes |
|---------|-----------|----------|-------|
| Email subject customization | No | - | Subject from I18n (global) |
| Email body customization | No | - | Template is hard-coded |
| Website branding in email | No | - | No website name/logo |
| Website-specific signature | No | - | No custom closing |
| Custom inquiry fields | No | - | Limited template variables |

### Why Templates Are Global

1. **File-Based Storage**: Templates are ERB files in `/app/views/`
2. **Not Database-Backed**: Can't query per-tenant configurations
3. **No Admin UI**: No interface to manage per-tenant templates
4. **Backwards Compatibility**: Changing this would be a significant refactor

---

## 5. Data Flow - Tenant-Aware Email Journey

### General Inquiry Flow

```
1. Visitor accesses: abc.propertywebbuilder.com/contact-us
   └─ Request identifies tenant: Website A

2. Form submission → ContactUsController#contact_us_ajax
   └─ @current_website = Website A (from subdomain)
   └─ @current_agency = Website A's agency

3. Create Contact & Message records
   ├─ Contact.website_id = Website A.id
   ├─ Message.website_id = Website A.id
   └─ Message.delivery_email = Website A's agency email

4. Trigger: EnquiryMailer.general_enquiry_targeting_agency(@contact, @message).deliver_later
   └─ Solid Queue jobs table stores job

5. Background worker processes job
   ├─ No tenant context! (separate process)
   ├─ Uses Message.delivery_email (configured per-tenant)
   └─ Email sent to: Website A's email address

6. Callback: after_deliver :mark_delivery_success
   ├─ Updates Message.delivery_success = true
   ├─ Updates Message.delivered_at = Time.current
   └─ Logs: "Successfully delivered email for message #X"

7. Email received
   ├─ To: Website A's agency email (correct tenant's email)
   ├─ From: DEFAULT_FROM_EMAIL (global)
   ├─ Subject: I18n translated (global)
   └─ Body: Standard template (global)
```

### Cross-Tenant Data Leakage Prevention

**Protected By**:
1. **Request Router**: Subdomain determines tenant before controller runs
2. **@current_website**: Controller always uses @current_website for queries
3. **acts_as_tenant**: PwbTenant models automatically scope by website_id
4. **Database Constraints**: Contacts/Messages tied to website_id

**Risk Areas**:
- Background jobs don't have tenant context (but use delivery_email from Message)
- Admin users can switch between websites (by changing subdomain)

---

## 6. Multi-Tenant Email Scenarios

### Scenario A: Same Email Address for Multiple Websites

```
Website A (abc.com): email_for_general_contact_form = contact@example.com
Website B (xyz.com): email_for_general_contact_form = contact@example.com

Inquiry from abc.com → Message.website_id = A
  ↓
  Email sent to: contact@example.com
  └─ Recipient can't tell which website sent it

Solution: Use different email addresses per website, or include website info in subject
```

### Scenario B: User Admin of Multiple Websites

```
User Jane is admin of Website A and Website B

Request 1: jane.propertywebbuilder.com/admin/...
  └─ Sets @current_website = Website A
  └─ Can only see Website A's messages
  └─ Can only modify Website A's agency email

Request 2: Different subdomain for Website B
  └─ Sets @current_website = Website B
  └─ Can see Website B's messages
  └─ Can modify Website B's agency email
```

### Scenario C: No Agency Email Configured

```
Website C has no email configured

Inquiry submitted → Message created

Delivery Email Logic:
  if @current_agency.email_for_general_contact_form.present?
    @enquiry.delivery_email = @current_agency.email_for_general_contact_form
  else
    @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"  # Fallback
    # Logged as warning
  end

Email still sends to fallback address (but warning logged)
```

---

## 7. Tenant Data in Message Records

### Fields That Create Tenant Context

```ruby
Message.find(123)
# {
#   id: 123,
#   website_id: 5,           # <- TENANT IDENTIFIER
#   contact_id: 456,
#   content: "I'm interested...",
#   delivery_email: "abc@company.com",
#   delivery_success: true,
#   delivered_at: 2024-12-12 10:30:00,
#   origin_email: "visitor@example.com",
#   url: "https://abc.propertywebbuilder.com/properties/789",
#   host: "abc.propertywebbuilder.com",    # <- Embedded tenant identifier
#   origin_ip: "192.168.1.1",
#   locale: "en",
#   created_at: 2024-12-12 10:29:00
# }
```

### Tenant Identification Options

1. **Direct**: `Message.website_id` (explicit)
2. **Implicit**: `Message.host` (embedded in subdomain)
3. **Derived**: `Message.contact.website_id` (via relationship)

---

## 8. Improvements for Better Tenant Support

### Short Term (No Architecture Changes)

1. **Include Website Name in Email Subject**
   - Modify templates to use `@current_website.name` (if available in context)
   - Update EnquiryMailer to pass website

2. **Include Website Branding in Email Body**
   - Add website URL/logo to email template
   - Include company name from Agency

3. **Improve Email Failure Tracking**
   - Add website_id to error logs
   - Admin dashboard for email delivery status per-website

### Medium Term (Moderate Changes)

1. **Database-Backed Email Templates**
   - Create `EmailTemplate` model with website_id
   - Admin UI to customize templates per-website
   - Fallback to global template if not customized

2. **Email Configuration Dashboard**
   - Admin UI to test email delivery
   - View email delivery history per-website
   - Configure reply-to, sender name, subject prefix

3. **Email Preview Interface**
   - Show preview of email before saving
   - Test with sample data per-website

### Long Term (Major Refactor)

1. **Email Service Refactor**
   - Separate email service from controllers
   - Support multiple email templates per inquiry type
   - Template inheritance (base + overrides)

2. **Tenant-Scoped Email Configuration**
   - Custom SMTP per-tenant (if needed)
   - Custom from address per-tenant
   - Custom branding assets

3. **Email Analytics**
   - Track delivery status per-website
   - Reply tracking
   - Email performance metrics

---

## 9. Security Considerations

### Data Isolation

**Risk**: Admin user sees another tenant's emails
**Mitigation**: 
- Subdomain routing ensures @current_website is set correctly
- All queries use @current_website or acts_as_tenant
- Code review: Never use Pwb:: models directly in web context

**Testing**: 
- Test cross-tenant queries blocked
- Verify @current_website isolation
- Check admin access control by website membership

### Email Address Exposure

**Risk**: Email addresses in Message records visible to admins
**Mitigation**:
- Only website admins can view their messages
- Email addresses tied to website_id
- No cross-tenant email address visibility in UI

### Delivery to Wrong Tenant

**Risk**: Email sent to wrong website's address
**Mitigation**:
- Delivery address from Message.delivery_email (set at inquiry time)
- Cannot be modified after inquiry created
- Each website's email configured separately in Agency

---

## 10. Testing Tenant Isolation in Email System

### Unit Test Template

```ruby
RSpec.describe Pwb::EnquiryMailer do
  let(:website_a) { FactoryBot.create(:pwb_website) }
  let(:website_b) { FactoryBot.create(:pwb_website) }
  
  describe 'tenant isolation' do
    it 'sends to website A agency email' do
      message_a = FactoryBot.create(:pwb_message, 
        website: website_a, 
        delivery_email: "a@company.com"
      )
      contact_a = FactoryBot.create(:pwb_contact, website: website_a)
      
      mail = Pwb::EnquiryMailer.general_enquiry_targeting_agency(contact_a, message_a).deliver_now
      expect(mail.to).to eq(["a@company.com"])
    end
    
    it 'sends to website B agency email' do
      message_b = FactoryBot.create(:pwb_message, 
        website: website_b, 
        delivery_email: "b@company.com"
      )
      contact_b = FactoryBot.create(:pwb_contact, website: website_b)
      
      mail = Pwb::EnquiryMailer.general_enquiry_targeting_agency(contact_b, message_b).deliver_now
      expect(mail.to).to eq(["b@company.com"])
    end
  end
end
```

### Integration Test Template

```ruby
RSpec.describe 'Contact Form Submission', type: :request do
  let(:website_a) { FactoryBot.create(:pwb_website, subdomain: 'a') }
  let(:website_b) { FactoryBot.create(:pwb_website, subdomain: 'b') }
  
  it 'routes email to website A' do
    ActsAsTenant.with_tenant(website_a) do
      FactoryBot.create(:pwb_agency, 
        website: website_a, 
        email_for_general_contact_form: "a@company.com"
      )
    end
    
    post 'https://a.propertywebbuilder.com/pwb/contact_us_ajax', params: { ... }
    
    # Message should have website_a.id
    # Email should be sent to a@company.com
  end
end
```

---

## Summary

The email system is **tenant-aware for delivery** but **not customizable per-tenant**:

- ✓ Each website routes emails to its own address (via Agency)
- ✓ Messages are tagged with website_id (tenant identifier)
- ✓ Request routing ensures proper tenant context
- ✓ acts_as_tenant provides data isolation in web context
- ✗ Email templates are global (not per-website)
- ✗ Email content/subject not customizable per-website
- ✗ Website branding not included in emails
- ✗ No admin UI for email configuration

**For enhanced tenant support**, consider implementing database-backed email templates and a per-website email configuration dashboard.
