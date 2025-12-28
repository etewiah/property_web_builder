# Contacts & Messages - Quick Reference

## Model Relationships at a Glance

```
┌─────────────────────────────────────────────────────────────┐
│                     Pwb::Website                            │
│  (Multi-tenant container - one per subdomain)               │
├─────────────────────────────────────────────────────────────┤
│ id | subdomain | email_for_general_contact_form | etc...    │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴───────────┐
        │                        │
        ▼                        ▼
   ┌─────────────┐        ┌─────────────┐
   │   Contact   │◄───┬───│   Message   │
   │             │    │   │             │
   │ has_many    │    │   │ belongs_to  │
   │  :messages  │    │   │  :contact   │
   └─────────────┘    │   └─────────────┘
   - id                │   - id
   - primary_email     │   - origin_email
   - first_name        │   - title
   - last_name         │   - content
   - phone             │   - delivered_at
   - website_id ───────┼──→ - website_id
                       │   - contact_id (optional!)
                       │   - read
                       │   - user_agent
                       │   - origin_ip
                       └──── Can exist without Contact!
```

## Data Flow: Creation Process

### Three Identical Paths (Consolidation Candidate)

```
1. GENERAL CONTACT FORM (ContactUsController)
   Form Input
      ↓
   find_or_initialize Contact by email
      ↓
   create Message (WITHOUT contact_id)
      ↓
   save Contact ✓
      ↓
   save Message (1st save - no contact)
      ↓
   assign Message.contact = Contact
      ↓
   save Message (2nd save - NOW with contact)
      ↓
   Send Email + Notification


2. PROPERTY INQUIRY (PropsController)
   [SAME FLOW AS ABOVE]


3. GRAPHQL MUTATION (SubmitListingEnquiry)
   [SAME FLOW AS ABOVE]
```

## Key Fields by Model

### Contact
```ruby
Identifiers:
  id, website_id, user_id

Contact Info:
  primary_email (UNIQUE at DB - should be (website_id, email)!)
  primary_phone_number
  first_name, last_name
  other_names, title, fax, nationality
  
Social:
  skype_id, facebook_id, linkedin_id, twitter_id
  
Address:
  primary_address_id (fk)
  secondary_address_id (fk)
  
Metadata:
  documentation_id, documentation_type
  website_url, flags, details (json)
  created_at, updated_at
```

### Message
```ruby
Identifiers:
  id, website_id, contact_id (OPTIONAL - red flag!)
  
Content:
  title, content
  
Sender Info:
  origin_email (could differ from contact.primary_email)
  user_agent, origin_ip
  
Location:
  host, url, longitude, latitude
  locale
  
Delivery:
  delivery_email (target inbox)
  delivery_success (boolean)
  delivered_at (datetime)
  delivery_error (text)
  
Status:
  read (boolean, default: false)
  
Legacy:
  client_id (unused - cleanup candidate)
  
Timestamps:
  created_at, updated_at
```

## Database Queries

### Find a Contact's Messages
```ruby
# CURRENT (PROBLEMATIC - NOT SCOPED BY WEBSITE)
contact.messages  
# Returns ALL messages for this contact across all websites!

# BETTER (WHAT IT SHOULD BE)
contact.messages.where(website_id: website_id)

# OR with scoped association:
has_many :messages, -> { where(website_id: website_id) }
```

### Find Messages for a Website
```ruby
# Current SiteAdmin approach
website.messages.where(website_id: website.id)
  .order(created_at: :desc)
  .limit(100)

# Via controller
Message.where(website_id: current_website.id)
```

### Search Messages
```ruby
# Via SiteAdminIndexable (site_admin/messages#index)
Message.where(website_id: website_id)
  .where("origin_email ILIKE ? OR content ILIKE ?", "%search%", "%search%")
  .order(created_at: :desc)
```

## Creation Code Snippets

### From ContactUsController
```ruby
# Step 1: Find or create contact
@contact = @current_website.contacts.find_or_initialize_by(
  primary_email: params[:contact][:email]
)

# Step 2: Update contact attributes
@contact.attributes = {
  primary_phone_number: params[:contact][:tel],
  first_name: params[:contact][:name]
}

# Step 3: Create message (WITHOUT contact yet)
@enquiry = Message.new({
  website: @current_website,
  title: params[:contact][:subject],
  content: params[:contact][:message],
  origin_email: params[:contact][:email],
  delivery_email: @current_agency.email_for_general_contact_form
})

# Step 4: Save both
unless @enquiry.save && @contact.save
  @error_messages += @contact.errors.full_messages
  @error_messages += @enquiry.errors.full_messages
  return render "pwb/ajax/contact_us_errors"
end

# Step 5: Link them (REDUNDANT SAVE!)
@enquiry.contact = @contact
@enquiry.save

# Step 6: Async operations
EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_later
NtfyNotificationJob.perform_later(@current_website.id, :inquiry, @enquiry.id)
```

## Site Admin URLs & Views

### Contacts
```
GET  /site_admin/contacts
  - Index of all contacts for current website
  - Search by email/name
  - Shows: email, name, created date
  - Limit: 100 records

GET  /site_admin/contacts/:id
  - Show contact details
  - Fields: email, name, created, updated
  - ❌ MISSING: Link to messages from this contact
```

### Messages
```
GET  /site_admin/messages
  - Index of all messages for current website
  - Search by email/content
  - Shows: email, date, actions
  - Limit: 100 records
  - Marks unread messages
  
GET  /site_admin/messages/:id
  - Show message details
  - Auto-marks message as read
  - Logs read action in AuthAuditLog
  - Fields: email, date, content
  - ❌ MISSING: Link to associated contact
  - ❌ MISSING: Contact information display
```

## Critical Issues Summary

| Issue | Severity | Location | Impact |
|-------|----------|----------|--------|
| No tenant scoping on Contact→Message assoc | 🔴 HIGH | Model association | Cross-tenant data access |
| Redundant message saves | 🟠 MEDIUM | Creation flow | Extra DB writes, race conditions |
| Missing FK constraint | 🟠 MEDIUM | Migration | Orphaned contact_ids |
| Email uniqueness not tenant-aware | 🟠 MEDIUM | Schema | Can't reuse email across websites |
| Optional contact on message | 🟡 LOW | Model | Orphaned messages, assumptions break |
| Views don't show relationships | 🟡 LOW | Views | Poor UX, must search manually |
| Legacy client_id field | 🟢 TRIVIAL | Schema | Tech debt |

## Migration Timeline

```
2016-11 → Message table created (pre-Contact!)
2017-09 → Contact table created
2018-01 → contact_id added to Message (2.3 years later!)
2025-12-04 → website_id added to both (multi-tenancy)
2025-12-09 → delivery tracking added
2025-12-27 → read status added
```

## Testing the Association

```ruby
# ✓ SHOULD PASS
contact = website.contacts.find(id)
message = website.messages.find(id)
message.contact == contact

# ❌ CURRENTLY INSECURE (would expose cross-tenant data)
other_contact = Contact.find(different_id)  # From another website
other_contact.messages  # Returns ALL messages!

# ✓ AFTER FIX
other_contact.messages.where(website_id: website.id)
# Returns only messages for this website
```

## Related Services

### NtfyService
- Sends push notifications when message received
- Uses `message.contact` to build notification content
- Falls back if contact missing (defensive programming)
- Link to view message: `site_admin_message_url(message)`

### EnquiryMailer
- Sends email to agency about new inquiry
- Passes both `@contact` and `@enquiry`
- Subject/template varies by form type (general vs property)

### AuthAuditLog
- Logs when messages are marked as read
- Captures: user, message, request, website
- Stored in audit trail for compliance

## Configuration

### SiteAdminIndexable
```ruby
indexable_config model: Pwb::Contact,
                 search_columns: %i[primary_email first_name last_name],
                 limit: 100

# Auto-generates:
# - @contacts instance variable
# - Website scoping via where(website_id: ...)
# - Search via ILIKE with OR conditions
# - Pagination (limit: 100)
```

## Recommended Improvements (Priority Order)

### URGENT (Do First)
1. Add FK constraint: `contact_id` → `pwb_contacts.id`
2. Scope association: `has_many :messages, -> { where(website_id: website_id) }`
3. Make contact required: `belongs_to :contact, optional: false`

### SOON (Next Sprint)
4. Fix uniqueness: Change to `(website_id, primary_email)` compound unique
5. Single-save creation: Use transaction to create contact+message atomically
6. View improvements: Show contact details on message, messages on contact

### LATER (Cleanup)
7. Remove `client_id` from Message if unused
8. Verify/document email strategy (source of truth)
9. Review PwbTenant:: variants for consistency
10. Add more comprehensive audit logging

## Quick Debugging Checklist

- [ ] Check website_id matches when accessing messages
- [ ] Verify contact exists before accessing message.contact
- [ ] Use current_website for filtering in admin context
- [ ] Don't trust contact.messages without website_id clause
- [ ] Ensure migrations run: check for contact_id, website_id columns
- [ ] Test create flow: contact should exist before message links to it
- [ ] Verify read status updates: check message.read flag
- [ ] Check audit logs: AuthAuditLog for message reads

## File Quick Links

**Models:**
- `/app/models/pwb/contact.rb` (Contact model)
- `/app/models/pwb/message.rb` (Message model)

**Controllers:**
- `/app/controllers/site_admin/contacts_controller.rb`
- `/app/controllers/site_admin/messages_controller.rb`
- `/app/controllers/pwb/contact_us_controller.rb` (General form)
- `/app/controllers/pwb/props_controller.rb` (Property inquiry)

**Concern:**
- `/app/controllers/concerns/site_admin_indexable.rb`

**Schemas:**
- Contact: primary_email, first_name, last_name, phone, website_id
- Message: origin_email, title, content, contact_id, website_id, read

---

**Last Updated:** 2025-12-28
**Purpose:** Quick lookup and navigation reference
**For Details:** See CONTACTS_AND_MESSAGES_ARCHITECTURE.md
