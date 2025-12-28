# PropertyWebBuilder Inquiry System - Quick Reference

## Absolute Basics

**What is PropertyWebBuilder?**
- Multi-tenant real estate agency website builder
- Each agency = 1 Website (tenant)
- Multiple users can work on multiple websites

**Inquiry System Basics**
- Visitors fill form on property page → Creates Contact + Message
- System emails agency automatically
- Message tracked (delivery success/failure)
- Contact history maintained via Messages

---

## Essential Models

| Model | Purpose | Tenant-Scoped? | Key Fields |
|-------|---------|---|---|
| Website | Agency/Tenant | N/A | company_display_name, emails, config |
| Contact | Visitor/Lead | YES | first_name, primary_email, phone, addresses |
| Message | Inquiry/Email | YES | title, content, origin_email, delivery_status |
| User | Agency Staff | NO | email, password, roles |
| UserMembership | User↔Website | N/A | user_id, website_id, role, active |
| Agency | Company Info | YES | display_name, phone, emails, address |
| Address | Street Address | NO | street, city, postal_code, lat/lng |

---

## Quick Code Examples

### Create a Contact (in web request)
```ruby
# In controller (auto-scoped to current website)
contact = PwbTenant::Contact.create(
  first_name: "John",
  last_name: "Doe",
  primary_email: "john@example.com",
  primary_phone_number: "+1234567890"
)
```

### Create a Message
```ruby
# In controller
message = PwbTenant::Message.create(
  title: "Property Inquiry",
  content: "I'm interested in the penthouse",
  origin_email: "john@example.com",
  origin_ip: request.ip,
  contact_id: contact.id,
  delivery_email: current_website.email_for_property_contact_form
)
```

### Send Email
```ruby
# Async (queued job)
EnquiryMailer.property_enquiry_targeting_agency(contact, message, property).deliver_later

# Sync (immediate)
EnquiryMailer.property_enquiry_targeting_agency(contact, message, property).deliver_now
```

### Query Contacts
```ruby
# In web request (auto-scoped)
contacts = PwbTenant::Contact.all  # Only current website
by_email = PwbTenant::Contact.find_by(primary_email: email)

# In console (manual scope)
contacts = Pwb::Contact.where(website_id: website.id)
```

### Get Contact Inquiry History
```ruby
contact.messages  # All inquiries from this contact
message.contact   # Which contact submitted this
```

---

## Current Inquiry Workflow

```
1. Visitor on property page fills form:
   - Name, Email, Phone, Message

2. Form POST to /pwb/props/request_property_info_ajax

3. Controller:
   - Finds/creates Contact by email
   - Creates Message record
   - Saves both
   - Queues email job

4. EnquiryMailer (async):
   - Sends email to: Website.email_for_property_contact_form
   - Reply-To: Visitor email
   - Updates Message: delivery_success, delivered_at

5. Result:
   - Contact record exists with history
   - Message shows delivery status
   - Agency received email
```

---

## Important Constraints

### Multi-Tenancy
```ruby
# ALWAYS include website_id when creating models in web requests
Contact.create(
  primary_email: email,
  website_id: Pwb::Current.website.id  # REQUIRED
)

# In console, you can omit it but should scope
Pwb::Contact.where(website_id: website.id)
```

### Scoping
```ruby
# Web requests (GOOD)
PwbTenant::Contact.find(id)  # Auto-scoped

# Web requests (BAD)
Pwb::Contact.find(id)  # UNSCOPED - security issue!

# Console (OK)
Pwb::Contact.find(id)  # OK - careful work
```

### User Roles
```ruby
# Check user role for website
user.role_for(website)  # Returns: owner, admin, member, viewer

# Check if admin
user.admin_for?(website)

# Can access?
user.can_access_website?(website)
```

---

## What DOESN'T Exist (Yet)

**No Agent Assignment**
- No way to assign contacts/inquiries to specific agents
- All website users see all inquiries
- No territory/region routing

**No Lead Pipeline**
- No status field (new, contacted, interested, rejected)
- No priority/rating
- No notes or comments
- No follow-ups or reminders

**No SMS/Alternative Channels**
- Email only (one-way)
- No Twilio/SMS integration
- No WhatsApp
- No in-app messaging
- Replies come back via email only

**No Two-Way Messaging**
- Agents can't reply within system
- No message threads
- No attachment support

---

## File Locations Cheat Sheet

```
Models:
  app/models/pwb/contact.rb
  app/models/pwb/message.rb
  app/models/pwb/website.rb
  app/models/pwb/user.rb
  app/models/pwb/agency.rb
  app/models/pwb_tenant/contact.rb (scoped version)
  app/models/pwb_tenant/message.rb (scoped version)

Controllers:
  app/controllers/pwb/props_controller.rb (form handling)
  app/controllers/pwb/api/v1/contacts_controller.rb (API)

Mailers:
  app/mailers/pwb/enquiry_mailer.rb

Database:
  db/schema.rb (search: pwb_contacts, pwb_messages)

Tests:
  spec/models/pwb/contact_spec.rb
  spec/models/pwb/message_spec.rb
  spec/mailers/pwb/enquiry_mailer_spec.rb
```

---

## Common Tasks

### Check If Email Was Delivered
```ruby
message = Message.find(id)
if message.delivery_success
  puts "Email sent successfully at #{message.delivered_at}"
else
  puts "Email failed: #{message.delivery_error}"
end
```

### Find All Unread Inquiries
```ruby
unread = PwbTenant::Message.where(read: false)
unread.count
```

### Get Contact by Phone
```ruby
contact = PwbTenant::Contact.find_by(primary_phone_number: "+1234567890")
```

### Mark Message as Read
```ruby
message.update(read: true)
```

### Check User Websites
```ruby
user.websites  # All websites user has access to
user.user_memberships  # Membership records
user.admin_for?(website)  # Check if admin on website
```

### Get Agency Contact Info
```ruby
website.agency.email_for_property_contact_form
website.agency.phone_number_primary
website.agency.primary_address
```

---

## Important Database Tables

```sql
pwb_websites        -- Agency tenants
pwb_users           -- User accounts
pwb_user_memberships -- User → Website mapping
pwb_contacts        -- Contact/Lead records (website_scoped)
pwb_messages        -- Inquiries/emails (website_scoped)
pwb_addresses       -- Address records (shared)
pwb_agencies        -- Agency details (website_scoped)
pwb_realty_assets   -- Properties
pwb_sale_listings   -- Sale transactions
pwb_rental_listings -- Rental transactions
```

---

## Common Queries

```ruby
# All contacts for website
Pwb::Contact.where(website_id: website_id)

# Recent inquiries (last 7 days)
Pwb::Message.where(website_id: website_id, created_at: 7.days.ago..)

# Undelivered emails
Pwb::Message.where(website_id: website_id, delivery_success: false)

# Contact with most inquiries
Pwb::Contact.where(website_id: website_id).find_by("(SELECT COUNT(*) FROM pwb_messages WHERE pwb_messages.contact_id = pwb_contacts.id) = (SELECT MAX(cnt) FROM (SELECT COUNT(*) as cnt FROM pwb_messages GROUP BY contact_id) AS counts)")

# Better: Group by contact
Pwb::Message.where(website_id: website_id).group(:contact_id).count

# Find contact inquiries
contact.messages  # or
Pwb::Message.where(contact_id: contact_id)
```

---

## Debugging Checklist

**Contact Not Found After Inquiry?**
- Check website_id matches Pwb::Current.website.id
- Check primary_email (case sensitivity)
- Check database directly: `SELECT * FROM pwb_contacts WHERE primary_email = '...'`

**Email Not Sent?**
- Check Message.delivery_success = true/false
- Check Message.delivery_error for error details
- Check Agency.email_for_property_contact_form is set
- Check Solid Queue jobs: `SolidQueue::Job.where(class_name: 'EnquiryMailer*')`

**Can't Find Message?**
- Verify website_id (might be different website)
- Use Pwb::Message for console (unscoped)
- Check message was actually saved (validate before save)

**Authorization Issues?**
- Check user.role_for(website)
- Check UserMembership.active = true
- Check user has access with: user.can_access_website?(website)

---

## Key Architecture Decisions

1. **Website = Tenant**: Everything scoped to website_id
2. **Contact = Lead**: No separate lead model, contacts are leads
3. **Message = Inquiry + Status**: One model for everything
4. **Email Only**: No SMS/messaging yet, just email outbound
5. **One-Way**: Agencies receive email, replies come back via email
6. **Flexible User**: UserMembership enables multi-website per user
7. **No Agent Assignment**: All users see all inquiries
8. **JSON Fields**: Contact.details and Website.config for extensibility

