# Contacts and Messages Architecture Analysis

## Overview

This document provides a comprehensive analysis of the Contact and Message models in PropertyWebBuilder, including their relationships, creation flows, and architectural patterns.

---

## 1. Model Definitions

### 1.1 Contact Model (`app/models/pwb/contact.rb`)

**Purpose:** Represents a person or entity that interacts with the website.

**Schema:**
```
Table: pwb_contacts

Primary Columns:
- id (bigint, primary key)
- first_name (string)
- last_name (string)
- other_names (string)
- title (integer, enum: mr, mrs, default: mr)
- primary_phone_number (string)
- other_phone_number (string)
- fax (string)
- nationality (string)
- primary_email (string) - INDEXED, UNIQUE
- other_email (string)
- documentation_id (string) - INDEXED, UNIQUE
- documentation_type (integer)
- website_url (string)

Social IDs:
- skype_id (string)
- facebook_id (string)
- linkedin_id (string)
- twitter_id (string)

Address Relations:
- primary_address_id (integer, FK -> Pwb::Address)
- secondary_address_id (integer, FK -> Pwb::Address)

Tenant & User:
- website_id (bigint, FK -> Pwb::Website) - INDEXED
- user_id (integer, FK -> Pwb::User)

Flexible Storage:
- details (json)
- flags (integer, default: 0, not null)
- created_at, updated_at (timestamps)
```

**Indexes:**
- `first_name`
- `last_name`
- `first_name` + `last_name` (compound)
- `primary_email`
- `primary_phone_number`
- `documentation_id`
- `title`
- `website_id` (tenant scoping)

**Associations:**
```ruby
belongs_to :website, class_name: 'Pwb::Website', optional: true
belongs_to :primary_address, optional: true, class_name: 'Pwb::Address'
belongs_to :secondary_address, optional: true, class_name: 'Pwb::Address'
belongs_to :user, optional: true, class_name: 'Pwb::User'
has_many :messages, class_name: 'Pwb::Message'
```

**Key Methods:**
- `street_number`: Delegates to `primary_address.street_number`
- `street_address`: Delegates to `primary_address.street_address`
- `city`: Delegates to `primary_address.city`
- `postal_code`: Delegates to `primary_address.postal_code`

**Note:** This model is **NOT tenant-scoped**. Use `PwbTenant::Contact` for tenant-scoped queries in web requests.

---

### 1.2 Message Model (`app/models/pwb/message.rb`)

**Purpose:** Represents messages/inquiries from website visitors (contact form submissions, property inquiries, etc.)

**Schema:**
```
Table: pwb_messages

Core Content:
- id (integer, primary key)
- title (string)
- content (text)
- locale (string)

Contact Information:
- origin_email (string)
- origin_ip (string)
- user_agent (string)

Location:
- longitude (float)
- latitude (float)
- host (string)
- url (string)

Delivery Tracking:
- delivery_email (string)
- delivery_success (boolean, default: false)
- delivered_at (datetime)
- delivery_error (text)

Message Status:
- read (boolean, default: false, not null) - Added 2025-12-27

Tenant & Relations:
- website_id (bigint, FK -> Pwb::Website) - INDEXED
- contact_id (integer, FK -> Pwb::Contact)
- client_id (integer) - Legacy field, appears unused

Timestamps:
- created_at, updated_at (timestamps)
```

**Indexes:**
- `website_id` (tenant scoping)

**Associations:**
```ruby
belongs_to :website, class_name: 'Pwb::Website', optional: true
belongs_to :contact, optional: true, class_name: 'Pwb::Contact'
```

**Note:** This model is **NOT tenant-scoped**. Use `PwbTenant::Message` for tenant-scoped queries in web requests.

---

## 2. Relationship Between Contact and Message

### 2.1 Association Structure

```
Contact (1) ──────→ (N) Message
```

- **One Contact can have many Messages** (via `has_many :messages`)
- **One Message belongs to one Contact** (via `belongs_to :contact, optional: true`)
- **The relationship is optional**: A Message can be created without a Contact (contact_id can be NULL)

### 2.2 Key Characteristics

| Aspect | Value |
|--------|-------|
| Cardinality | One-to-Many |
| Optional | Yes (messages can exist without contacts) |
| Foreign Key | `messages.contact_id` → `contacts.id` |
| Cascade | No explicit cascade configured |
| Tenant Scoping | Both have website_id, but association doesn't use it |

### 2.3 Data Flow

```
Website
  │
  ├──→ has_many :contacts
  │     └─→ Contact (website_id, primary_email, ...)
  │           └─→ has_many :messages
  │                 └─→ Message (website_id, contact_id, origin_email, ...)
  │
  └──→ has_many :messages
        └─→ Message (website_id, contact_id, origin_email, ...)
```

---

## 3. Creation Flows

### 3.1 General Contact Form (`ContactUsController`)

**File:** `app/controllers/pwb/contact_us_controller.rb`

**Action:** `contact_us_ajax`

**Flow:**
```ruby
1. Find or create Contact by primary_email
   @contact = @current_website.contacts.find_or_initialize_by(primary_email: params[:contact][:email])
   
2. Assign contact attributes from form
   @contact.attributes = {
     primary_phone_number: params[:contact][:tel],
     first_name: params[:contact][:name]
   }
   
3. Create Message (initially WITHOUT contact association)
   @enquiry = Message.new({
     website: @current_website,
     title: params[:contact][:subject],
     content: params[:contact][:message],
     locale: params[:contact][:locale],
     url: request.referer,
     host: request.host,
     origin_ip: request.ip,
     origin_email: params[:contact][:email],
     user_agent: request.user_agent,
     delivery_email: @current_agency.email_for_general_contact_form
   })
   
4. Save both Contact and Message
   unless @enquiry.save && @contact.save
     # Handle errors
   end
   
5. Link Message to Contact AFTER both are saved
   @enquiry.contact = @contact
   @enquiry.save
   
6. Send emails and notifications
   EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_later
   NtfyNotificationJob.perform_later(@current_website.id, :inquiry, @enquiry.id)
```

**Issues Identified:**
1. **Two-phase association:** Message is created without Contact, then linked afterward
2. **Redundant save:** Message is saved twice (once without contact, once with contact)
3. **No explicit transaction:** Multiple saves could fail partially
4. **Email duplication:** `origin_email` on Message vs. `primary_email` on Contact

---

### 3.2 Property Inquiry (`PropsController`)

**File:** `app/controllers/pwb/props_controller.rb`

**Action:** `request_property_info_ajax`

**Flow:**
Same as Contact Form (lines 83-124):
```ruby
1. Find/create Contact by primary_email
2. Assign contact attributes
3. Create Message (without contact)
4. Save both
5. Link Message to Contact
6. Send emails
```

**Pattern:** Identical to `ContactUsController`

---

### 3.3 GraphQL Mutation (`SubmitListingEnquiry`)

**File:** `app/graphql/mutations/submit_listing_enquiry.rb`

**Flow:**
Same pattern as above (lines 23-58):
```ruby
1. Find/create Contact
2. Create Message (without contact)
3. Save both
4. Link Message to Contact
5. Send email
```

**All three creation paths use identical pattern:**
- Find or initialize Contact
- Create Message separately
- Save both independently
- Link them together with `@enquiry.contact = @contact; @enquiry.save`

---

## 4. Site Admin Controllers

### 4.1 ContactsController (`app/controllers/site_admin/contacts_controller.rb`)

**Configuration:**
```ruby
class ContactsController < SiteAdminController
  include SiteAdminIndexable

  indexable_config model: Pwb::Contact,
                   search_columns: %i[primary_email first_name last_name],
                   limit: 100
end
```

**Capabilities:**
- Index (with search by email/name)
- Show (read-only)

**Scoping:**
- Uses `SiteAdminIndexable` concern
- Automatically scoped to `website_id: current_website.id`
- Search uses ILIKE on email/name columns

---

### 4.2 MessagesController (`app/controllers/site_admin/messages_controller.rb`)

**Configuration:**
```ruby
class MessagesController < SiteAdminController
  include SiteAdminIndexable

  indexable_config model: Pwb::Message,
                   search_columns: %i[origin_email content],
                   limit: 100

  def show
    @message = find_scoped_resource
    unless @message.read?
      @message.update(read: true)
      Pwb::AuthAuditLog.log_message_read(
        user: current_user,
        message: @message,
        request: request,
        website: current_website
      )
    end
  end
end
```

**Capabilities:**
- Index (with search by email/content)
- Show with automatic read tracking
- Audit logging for message reads

**Scoping:**
- Uses `SiteAdminIndexable` concern
- Automatically scoped to `website_id: current_website.id`
- Search uses ILIKE on email/content columns
- Read status tracking with audit log

---

## 5. Tenant Scoping Pattern

### 5.1 SiteAdminIndexable Concern (`app/controllers/concerns/site_admin_indexable.rb`)

**How Scoping Works:**
```ruby
def base_index_scope
  scope = indexable_model_class.where(website_id: current_website&.id)
  scope = scope.includes(*indexable_includes) if indexable_includes.any?
  scope = scope.order(indexable_order)
  scope = scope.limit(indexable_limit) if indexable_limit
  scope
end

def find_scoped_resource
  indexable_model_class.where(website_id: current_website&.id).find(params[:id])
end
```

**Key Points:**
- All queries explicitly filter by `website_id: current_website.id`
- Both Contact and Message models have `website_id` column
- Scoping happens at the database query level (not ORM)
- No use of `acts_as_tenant` for these models (only for PwbTenant:: variants)

### 5.2 Cross-Tenant Data Risk

**CRITICAL ISSUE:** The Contact-Message association lacks tenant awareness:

```ruby
# This returns ALL messages for a contact, regardless of website_id
@contact.messages

# A malicious user could:
1. Know contact ID of user from another website
2. Call @contact.messages without website scoping
3. Access messages from other websites that share the same contact email
```

**Example Scenario:**
- Website A and Website B both have a user with email "john@example.com"
- If both use the same Contact record (duplicated across websites)
- Accessing `@contact.messages` could return messages from BOTH websites

---

## 6. Views

### 6.1 Contacts Index (`app/views/site_admin/contacts/index.html.erb`)

```erb
<div class="max-w-7xl mx-auto">
  <h1>Contacts</h1>
  
  <!-- Search Form -->
  <form with search parameter>
  
  <!-- Table showing: Email, Name, Created Date, Actions -->
  <table>
    <% @contacts.each do |contact| %>
      <tr>
        <td><%= contact.primary_email %></td>
        <td><%= [contact.first_name, contact.last_name].join(' ') %></td>
        <td><%= format_date(contact.created_at) %></td>
        <td><%= link_to 'View', site_admin_contact_path(contact) %></td>
      </tr>
    <% end %>
  </table>
</div>
```

---

### 6.2 Contacts Show (`app/views/site_admin/contacts/show.html.erb`)

```erb
<div class="max-w-4xl mx-auto">
  <dl>
    <div>Email: <%= @contact.primary_email %></div>
    <div>Name: <%= [@contact.first_name, @contact.last_name].join(' ') %></div>
    <div>Created: <%= format_date(@contact.created_at) %></div>
    <div>Updated: <%= format_date(@contact.updated_at) %></div>
  </dl>
</div>
```

**Issue:** No link to view related messages for this contact

---

### 6.3 Messages Index (`app/views/site_admin/messages/index.html.erb`)

```erb
<div class="max-w-7xl mx-auto">
  <h1>Messages</h1>
  
  <!-- Search Form -->
  <form with search parameter>
  
  <!-- Table showing: Email, Date, Actions -->
  <table>
    <% @messages.each do |message| %>
      <tr>
        <td><%= message.origin_email %></td>
        <td><%= format_date(message.created_at) %></td>
        <td><%= link_to 'View', site_admin_message_path(message) %></td>
      </tr>
    <% end %>
  </table>
</div>
```

---

### 6.4 Messages Show (`app/views/site_admin/messages/show.html.erb`)

```erb
<div class="max-w-4xl mx-auto">
  <dl>
    <div>Email: <%= @message.origin_email %></div>
    <div>Date: <%= format_date(@message.created_at) %></div>
    <div>Message: <%= @message.content %></div>
  </dl>
</div>
```

**Issue:** No link to associated contact, no contact information displayed

---

## 7. Integration with Services

### 7.1 NtfyService (`app/services/ntfy_service.rb`)

**Inquiry Notification (lines 39-50):**
```ruby
def notify_inquiry(website, message)
  return unless enabled_for?(website, :inquiries)
  publish(
    website: website,
    channel: CHANNEL_INQUIRIES,
    title: "New Inquiry: #{message.title.presence || 'Property Inquiry'}",
    message: build_inquiry_message(message),  # Uses message.contact
    priority: PRIORITY_HIGH,
    tags: ['house', 'incoming_envelope'],
    click_url: site_admin_message_url(message, host: website_host(website))
  )
end

def build_inquiry_message(message)
  parts = []
  if message.contact.present?
    parts << "From: #{message.contact.first_name}" if message.contact.first_name.present?
    parts << "Email: #{message.contact.primary_email}" if message.contact.primary_email.present?
    parts << "Phone: #{message.contact.primary_phone_number}" if message.contact.primary_phone_number.present?
  end
  parts << ""
  parts << message.content.to_s.truncate(200) if message.content.present?
  parts.join("\n")
end
```

**Key Observation:** Service assumes `message.contact` is always present (with optional fallback)

---

## 8. Database Migrations

### 8.1 Timeline of Migrations

| Migration | Date | Change |
|-----------|------|--------|
| `20170923195321_create_pwb_contacts.rb` | 2017-09-23 | Initial Contact table creation |
| `20161128200709_create_pwb_messages.rb` | 2016-11-28 | Initial Message table (pre-dates Contacts!) |
| `20180109133855_add_contact_id_to_pwb_messages.rb` | 2018-01-09 | Added `contact_id` to Message (2+ years later) |
| `20251204141849_add_website_to_contacts_messages_and_photos.rb` | 2025-12-04 | Added `website_id` to both (multi-tenancy) |
| `20251209181022_add_delivery_tracking_to_messages.rb` | 2025-12-09 | Added `delivered_at`, `delivery_error` |
| `20251227234829_add_read_to_messages.rb` | 2025-12-27 | Added `read` boolean status |

### 8.2 Key Migration Code

**Initial Contact Creation (2017):**
```ruby
create_table :pwb_contacts do |t|
  t.string :first_name, index: true
  t.string :last_name, index: true
  t.string :primary_email, index: true, unique: true
  # ... other fields
  t.timestamps null: false
end
```

**Add Contact to Message (2018):**
```ruby
add_column :pwb_messages, :contact_id, :integer, index: true
```

**Add Website Scoping (2025-12-04):**
```ruby
add_reference :pwb_contacts, :website, foreign_key: { to_table: :pwb_websites }
rename_column :pwb_contacts, :website, :website_url  # Careful renaming!

add_reference :pwb_messages, :website, foreign_key: { to_table: :pwb_websites }
```

---

## 9. Identified Issues and Concerns

### 9.1 CRITICAL ISSUES

#### 1. Cross-Tenant Data Access Risk

**Problem:** No explicit tenant scoping on the Contact-Message association
```ruby
# Message model
belongs_to :contact, optional: true  # No website_id check!

# This query ignores tenant boundaries:
@contact.messages  # Could return messages from other websites
```

**Risk:** If two websites share a contact (via duplicate email), accessing `message.contact.messages` could expose cross-tenant data

**Mitigation Required:**
- Add explicit `where(website_id: self.website_id)` in association
- Use has_many scopes to enforce tenant boundaries
- Add foreign key constraint on (contact_id, website_id) pair

#### 2. Redundant Message Saves During Creation

**Problem:** Messages are saved twice in creation flow
```ruby
# First save (without contact)
@enquiry = Message.new({...})
@enquiry.save  # Save 1

# Second save (with contact)
@enquiry.contact = @contact
@enquiry.save  # Save 2
```

**Impact:**
- Unnecessary database writes
- Potential race conditions if async jobs fire between saves
- Audit logs would show two separate creation events

**Improvement:** Use single transaction with contact association in initial creation

#### 3. Email Address Duplication

**Problem:** Email stored in multiple places
- `Contact.primary_email` (unique index at model level)
- `Message.origin_email` (no uniqueness)

**Issues:**
- Contact email can be NULL, Message email must exist
- Inconsistent source of truth for contact lookup
- Potential for email change mismatches

#### 4. No Contact-Message Link in Views

**Problem:** View details don't show the relationship
- Contact show view: No link to related messages
- Message show view: No link to associated contact or contact details
- Makes admin UX confusing

**Impact:** Admins must manually search to find related records

#### 5. Optional Contact Association

**Problem:** `belongs_to :contact, optional: true` allows orphaned messages
```ruby
Message.create(website_id: 123, origin_email: "test@example.com")
# Creates message with no contact_id - breaks assumptions
```

**Issues:**
- NtfyService assumes `message.contact.present?` (has fallback, but suggests design debt)
- Message creation forms might not enforce contact creation
- Orphaned messages lack contact metadata

---

### 9.2 MODERATE CONCERNS

#### 1. Contact Uniqueness Constraint Issue

**Problem:** `primary_email` is UNIQUE at database level, but website-agnostic
```
Index: index_pwb_contacts_on_primary_email UNIQUE
```

**Implication:** If two websites want to manage the same person's email, they can't.
- The migration added `website_id`, but didn't update uniqueness constraint
- Index should be: `(website_id, primary_email)` compound unique index

#### 2. Missing Foreign Key Constraint

**Problem:** `contact_id` in messages has no explicit foreign key constraint
```ruby
add_column :pwb_messages, :contact_id, :integer, index: true
# Note: No add_foreign_key call
```

**Risk:** Orphaned contact_ids if Contact is deleted without cascade

#### 3. SiteAdminIndexable Scoping Pattern

**Observation:** Uses explicit `where(website_id: ...)` rather than `acts_as_tenant`
```ruby
scope = indexable_model_class.where(website_id: current_website&.id)
```

**Why This Matters:**
- Different from PwbTenant:: models which use `acts_as_tenant`
- Easy to accidentally forget scoping in custom queries
- Pwb:: models aren't protected by ORM-level tenant enforcement

#### 4. Legacy Client ID Field

**Problem:** Message model has unused `client_id` field
```ruby
# Schema shows:
# client_id (integer) - appears unused
```

**Cleanup Needed:** Either remove or document purpose

---

### 9.3 DESIGN CONSIDERATIONS

#### 1. Contact as Aggregate Root

**Current Pattern:** Contact-Message is loosely coupled
```ruby
Contact <- optional -> Message
```

**Alternative Consideration:** Should Contact be an aggregate root?
- Would validate that Message always has Contact
- Would simplify lookups via `@contact.messages` with guaranteed scoping

#### 2. Contact Creation on Message Submission

**Current Flow:**
```
Form -> find_or_initialize Contact -> Create Message -> Link together
```

**Better Flow:**
```
Form -> Create Message with contact attributes in single transaction
        Message.create_with_contact! accepts all attrs
```

#### 3. Separation of Concerns

**Question:** Should Contact data be attached to Message directly?
- `Message.origin_email` vs `Message.contact.primary_email`
- `Message.user_agent` (original requester) is already captured
- Could Message be the source of truth instead of Contact?

---

## 10. Audit & Compliance

### 10.1 Tracking

- **Message Reads:** Logged via `AuthAuditLog.log_message_read` in MessagesController
- **Contact Creation:** No explicit audit logging observed
- **Message Creation:** Logged via StructuredLogger in controllers

### 10.2 Privacy Concerns

- **Email Storage:** Emails stored in both Contact and Message models
- **IP Tracking:** `origin_ip` stored on Message
- **User Agent:** Full user-agent string stored
- **Geolocation:** Latitude/Longitude stored (if available)

**Note:** No explicit GDPR compliance mechanisms observed (deletion, anonymization)

---

## 11. Summary Table

| Aspect | Status | Notes |
|--------|--------|-------|
| Models Exist | ✓ | Pwb::Contact, Pwb::Message |
| Association Defined | ✓ | has_many/belongs_to |
| Tenant Scoped | ⚠️ | website_id exists, but association not scoped |
| Creation Pattern | ✓ | Consistent across 3 entry points |
| Admin Views | ✓ | Index/Show for both models |
| Relationships Visible | ✗ | Views don't show Contact↔Message links |
| Uniqueness Constraints | ✗ | Should be (website_id, primary_email) |
| Foreign Keys | ✗ | contact_id lacks FK constraint |
| Transaction Safety | ✗ | Double-save during creation |
| Validation | ✓ | Assumed present (not verified) |
| Audit Trail | ✓ | Message reads logged, creation logged |

---

## 12. Recommendations

### Immediate Fixes (High Priority)

1. **Add Tenant-Scoped Association**
   ```ruby
   # In Contact model
   has_many :messages, -> { where(website_id: website_id) }, 
            class_name: 'Pwb::Message'
   ```

2. **Add Foreign Key Constraint**
   ```ruby
   # New migration
   add_foreign_key :pwb_messages, :pwb_contacts, column: :contact_id
   ```

3. **Fix Uniqueness Constraint**
   ```ruby
   # New migration
   remove_index :pwb_contacts, :primary_email
   add_index :pwb_contacts, [:website_id, :primary_email], unique: true
   ```

4. **Single-Phase Message Creation**
   ```ruby
   # Refactor to create both in one transaction
   Contact.transaction do
     contact = @current_website.contacts.find_or_initialize_by(...)
     message = contact.messages.create!(...)
   end
   ```

### Medium-term Improvements

5. **Link Message to Contact in Views**
   - Add contact info card to message show page
   - Add link to related messages on contact show page
   - Show contact status (exists/new) in message table

6. **Enforce Contact Presence**
   - Validate `contact` is present on Message
   - Update creation flows to guarantee association

7. **Document Email Strategy**
   - Choose single source of truth (Contact or Message)
   - Clarify when to read from which field
   - Plan sync/consistency strategy

### Long-term Refactoring

8. **Consider Aggregate Pattern**
   - Treat Contact as aggregate root
   - All Messages must belong to Contact
   - Simplifies scoping and reduces orphaning

9. **Review PwbTenant:: Variants**
   - Ensure PwbTenant::Contact and PwbTenant::Message exist
   - Verify they're used consistently in web request contexts
   - Document when to use Pwb:: vs PwbTenant::

10. **Cleanup Legacy Fields**
    - Remove `client_id` if unused
    - Verify all fields in both models are necessary
    - Document field purposes for future maintainers

---

## 13. Testing Considerations

**Key Test Cases to Verify:**

1. **Tenant Isolation**
   ```ruby
   website_a = create(:website, subdomain: 'a')
   website_b = create(:website, subdomain: 'b')
   
   contact_a = create(:contact, website: website_a, email: 'test@example.com')
   contact_b = create(:contact, website: website_b, email: 'test@example.com')
   
   message_a = create(:message, website: website_a, contact: contact_a)
   message_b = create(:message, website: website_b, contact: contact_b)
   
   # Verify: contact_a.messages should ONLY contain message_a
   ```

2. **Creation Flow**
   ```ruby
   # Verify single transaction/save
   expect {
     create_inquiry_from_form(website, email: 'new@example.com')
   }.to change(Message, :count).by(1)
    .and change(Contact, :count).by(1)
   ```

3. **Message Read Tracking**
   ```ruby
   # Verify read status updates correctly
   message = create(:message, read: false)
   get site_admin_message_path(message)
   expect(message.reload.read).to be true
   ```

4. **Cross-Tenant Protection**
   ```ruby
   # Verify access control works
   login_as user_for_website_a
   expect { get site_admin_message_path(message_from_website_b) }
     .to raise ActiveRecord::RecordNotFound
   ```

---

## Appendix: File Locations

### Models
- `/app/models/pwb/contact.rb`
- `/app/models/pwb/message.rb`

### Controllers
- `/app/controllers/site_admin/contacts_controller.rb`
- `/app/controllers/site_admin/messages_controller.rb`
- `/app/controllers/pwb/contact_us_controller.rb`
- `/app/controllers/pwb/props_controller.rb`

### Views
- `/app/views/site_admin/contacts/index.html.erb`
- `/app/views/site_admin/contacts/show.html.erb`
- `/app/views/site_admin/messages/index.html.erb`
- `/app/views/site_admin/messages/show.html.erb`

### Migrations
- `/db/migrate/20170923195321_create_pwb_contacts.rb`
- `/db/migrate/20161128200709_create_pwb_messages.rb`
- `/db/migrate/20180109133855_add_contact_id_to_pwb_messages.rb`
- `/db/migrate/20251204141849_add_website_to_contacts_messages_and_photos.rb`
- `/db/migrate/20251209181022_add_delivery_tracking_to_messages.rb`
- `/db/migrate/20251227234829_add_read_to_messages.rb`

### Services & Concerns
- `/app/services/ntfy_service.rb`
- `/app/controllers/concerns/site_admin_indexable.rb`
- `/app/controllers/site_admin_controller.rb`

### Tests
- `/spec/models/pwb/contact_spec.rb`
- `/spec/models/pwb/message_spec.rb`
- `/spec/requests/pwb/contact_us_spec.rb`
- `/spec/requests/site_admin/contacts_spec.rb`
- `/spec/requests/site_admin/messages_spec.rb`
- `/tests/e2e/public/contact-forms.spec.js`

---

**Document Generated:** 2025-12-28
**Analyzed Codebase Version:** PropertyWebBuilder (current develop branch)
**Status:** Complete Architecture Analysis
