# PropertyWebBuilder Model Relationships & Data Flow

This document visualizes the relationships between core models involved in inquiry handling and contact management.

## Entity Relationship Diagram

```
┌──────────────────┐
│    Website       │  (Tenant/Agency)
│  ─────────────   │
│  id              │
│  company_...     │
│  email_for_*     │
│  theme_name      │
│  config (JSON)   │
└────────┬─────────┘
         │
    ┌────┴──────────────────────────────────────┐
    │                                            │
    ▼                                            ▼
┌──────────────────┐                 ┌──────────────────┐
│     Contact      │ has_many         │     Message      │
│  ──────────────  │ ◄──────────────► │  ──────────────  │
│  id              │ has_one          │  id              │
│  first_name      │ belongs_to       │  title           │
│  last_name       │                  │  content         │
│  primary_email   │                  │  origin_email    │
│  primary_phone   │                  │  origin_ip       │
│  primary_addr_id │                  │  delivery_email  │
│  secondary_...   │                  │  delivery_...    │
│  user_id         │                  │  read            │
│  website_id      │                  │  contact_id (FK) │
│  details (JSON)  │                  │  website_id      │
│  flags           │                  │  locale          │
│  social_ids      │                  │  url, host       │
└────────┬─────────┘                  │  lat, long       │
         │                            └──────────────────┘
    ┌────┴──────────────┐
    │                   │
    ▼                   ▼
┌─────────────┐    ┌──────────────┐
│   Address   │    │   User       │
│ ─────────── │    │ ──────────── │
│ id          │    │ id           │
│ street_...  │    │ email        │
│ city        │    │ password     │
│ postal_code │    │ first_names  │
│ region      │    │ last_names   │
│ country     │    │ website_id   │
│ lat, long   │    │ roles        │
└─────────────┘    │ provider     │
                   │ created_at   │
                   └──────┬───────┘
                          │
                   ┌──────┴──────────┐
                   │                 │
                   ▼                 ▼
            ┌──────────────┐  ┌──────────────────┐
            │ UserMembership
            │ ──────────── │  │ Authorization    │
            │ id           │  │ ──────────────── │
            │ user_id (FK) │  │ id               │
            │ website_id   │  │ user_id          │
            │ role         │  │ provider         │
            │ active       │  │ uid              │
            └──────────────┘  └──────────────────┘

    └──────────────────────────────────────────────────┬──────────────────┘
                                                       │
    Website ◄─────────────────────────────────────────┘
    (Many users can belong to many websites)
```

## Key Relationships Summary

### Website → Contact
```
Website.has_many :contacts
Contact.belongs_to :website
```
- One-to-many relationship
- Contacts are scoped to website (multi-tenant isolation)
- `website_id` foreign key on contacts table

### Website → Message
```
Website.has_many :messages
Message.belongs_to :website
```
- One-to-many relationship
- Messages are scoped to website
- `website_id` foreign key on messages table
- Multiple messages can be for inquiries, form submissions, etc.

### Contact → Message
```
Contact.has_many :messages
Message.belongs_to :contact, optional: true
```
- One-to-many relationship
- Multiple messages can belong to one contact
- Tracks conversation history per contact
- Contact can exist without messages (pre-filled contact records)
- Message can exist without contact (contact creation optional)

### Contact → User (Optional)
```
Contact.belongs_to :user, optional: true
User.has_many :contacts (not explicitly defined, but implied)
```
- Optional relationship
- Contacts can be linked to internal users
- Useful for: agent contacts, customer accounts, etc.
- Most website visitor contacts won't have user_id

### Contact → Address (Multiple)
```
Contact.belongs_to :primary_address, optional: true
Contact.belongs_to :secondary_address, optional: true
Address.has_one :agency (foreign_key: 'primary_address_id')
Address.has_one :agency_as_secondary (foreign_key: 'secondary_address_id')
```
- Two optional foreign keys
- Addresses are shared resources (not contact-specific)
- Can create flexible multi-address support
- Addresses also used by Agency model

### Website → User (Multi-Website Support)
```
Website.has_many :users (via user_memberships)
Website.has_many :user_memberships
Website.has_many :members, through: :user_memberships, source: :user

User.has_many :user_memberships
User.has_many :websites, through: :user_memberships
```
- Many-to-many relationship via `UserMembership` join table
- Each membership has a role (owner, admin, member, viewer)
- Each membership has active flag
- Supports users managing multiple websites
- Supports websites having multiple users

### Website → Agency (One-to-One)
```
Website.has_one :agency
Agency.belongs_to :website
```
- One-to-one relationship
- Each website has one agency with company details
- Agency stores contact emails for form submissions
- `website_id` foreign key on agencies table

---

## Inquiry Creation Flow - Detailed

### Step 1: Form Submission (Property Inquiry)
```
Visitor fills form on property page:
  - Name
  - Email
  - Phone
  - Message
  - Property ID
  - Locale
```

### Step 2: Controller Processing
```
PropsController#request_property_info_ajax
  ↓
  1. Find or create Contact
     Contact.find_or_initialize_by(primary_email: params[:email])
     └─ Sets: first_name, primary_phone_number
  
  2. Create Message
     Message.create(
       website_id: current_website.id,
       contact_id: contact.id,
       title: "Property Inquiry",
       content: visitor_message,
       origin_email: visitor_email,
       origin_ip: request.ip,
       delivery_email: website.email_for_property_contact_form,
       ...
     )
  
  3. Send Email (async)
     EnquiryMailer
       .property_enquiry_targeting_agency(contact, message, property)
       .deliver_later
  
  4. Return Response
     - Success: JavaScript alert "Thank you"
     - Error: JavaScript alert with validation errors
```

### Step 3: Email Delivery
```
EnquiryMailer#property_enquiry_targeting_agency
  ├─ To: Agency.email_for_property_contact_form
  ├─ Reply-To: contact.primary_email
  ├─ Subject: "Property Inquiry" (i18n)
  └─ Body includes:
     ├─ Visitor name & contact info
     ├─ Property details
     ├─ Message content
     └─ Custom template or ERB fallback
```

### Step 4: Email Success/Failure
```
After delivery:
  ├─ Success: Update Message
  │  ├─ delivery_success = true
  │  └─ delivered_at = Time.current
  └─ Failure: Update Message
     ├─ delivery_success = false
     └─ delivery_error = "Error message"
```

---

## Data Flow for Contact Management

### Contact Discovery
```
Visitor submits inquiry
  ↓
System looks up Contact by email
  ├─ Found? → Use existing contact
  └─ Not found? → Create new contact
```

### Contact Enrichment
```
Contact fields that can be populated:
  - Basic: first_name, last_name
  - Contact: primary_email, primary_phone_number, other_email, other_phone_number
  - Social: facebook_id, linkedin_id, twitter_id, skype_id
  - Address: primary_address_id, secondary_address_id
  - Extra: details (JSON), flags (integer)
  - System: user_id, website_id, title, documentation_type
```

### Contact History
```
Contact.messages → All inquiries from this contact
  └─ Each Message includes:
     ├─ What they inquired about (title, content)
     ├─ How they contacted (origin_email, origin_ip)
     ├─ When (created_at, updated_at)
     ├─ Where (url, host)
     └─ Delivery status (delivery_success, delivery_error)
```

---

## Tenant Isolation Pattern

### Model Variants

Every major model has two versions:

**Pwb:: Version (Unscoped)**
```ruby
# In console or background jobs
contact = Pwb::Contact.find(id)  # Unscoped
contacts = Pwb::Contact.where(website_id: website.id)  # Manual scope
```

**PwbTenant:: Version (Auto-Scoped)**
```ruby
# In web requests (automatically scoped)
contact = PwbTenant::Contact.find(id)  # Auto-scoped to Pwb::Current.website
contacts = PwbTenant::Contact.all  # Only from current website
```

### Implementation Pattern
```ruby
# app/models/pwb/contact.rb
module Pwb
  class Contact < ApplicationRecord
    self.table_name = 'pwb_contacts'
    belongs_to :website
    has_many :messages
    ...
  end
end

# app/models/pwb_tenant/contact.rb
module PwbTenant
  class Contact < Pwb::Contact
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
```

### Current Website Context
```ruby
# Set in controller before_action
Pwb::Current.website = website_from_subdomain_or_domain

# Used in models/mailers
@current_website = Pwb::Current.website
```

---

## Multi-Website Support: User Perspective

### Example Scenario
```
User "John" belongs to 2 websites:
  ├─ Website A (London Properties)
  │  └─ Role: owner
  │     └─ Can: Create/edit properties, users, config
  │
  └─ Website B (Paris Properties)
     └─ Role: admin
        └─ Can: Create/edit properties, but not manage users
```

### Data Visibility
```
When John logs in to Website A:
  ├─ Pwb::Current.website = Website A
  ├─ Sees: All contacts, messages, properties for A only
  └─ Cannot see: Website B data

When John logs in to Website B:
  ├─ Pwb::Current.website = Website B
  ├─ Sees: All contacts, messages, properties for B only
  └─ Cannot see: Website A data
```

### Role-Based Access
```
OWNER
  ├─ Full control
  ├─ Can manage users
  └─ Can modify settings

ADMIN
  ├─ Can create/edit properties & contacts
  ├─ Cannot manage users (except viewers)
  └─ Cannot modify critical settings

MEMBER
  ├─ Can create/edit properties & contacts
  ├─ Cannot add users
  └─ Limited settings access

VIEWER
  ├─ Read-only access
  └─ Cannot create/edit anything
```

---

## Current Limitations: Agent/Property Binding

### What's Missing
```
Currently:
  Website → has many Contacts/Messages
  User → associated with Website
  Property → associated with Website
  
Missing:
  ┌─────────────────┐
  │ Property        │
  │ ─────────────── │
  │ ...             │
  │ agent_id ← MISSING
  │ team_id  ← MISSING
  └─────────────────┘
  
  ┌─────────────────┐
  │ Contact/Message │
  │ ─────────────── │
  │ ...             │
  │ assigned_to ← MISSING
  │ status ← MISSING
  │ notes ← MISSING
  └─────────────────┘
```

### For Lead Management System, Would Need:
```
1. Agent Model or Property-Agent Assignment
   ├─ Property → agent assignment
   ├─ Territory/region assignment
   └─ Inquiry routing rules

2. Lead Status & Pipeline
   ├─ Lead status field
   ├─ Assigned agent field
   ├─ Notes/comments
   └─ Activity timeline

3. Two-Way Communication
   ├─ Message direction (in/out)
   ├─ Agent field on messages
   ├─ Multiple channels (SMS, WhatsApp, etc.)
   └─ Conversation threads
```

---

## Key Takeaways

1. **Multi-Tenancy**: Website is the tenant boundary, everything scoped via website_id
2. **Contact = Lead**: Contacts are the leads, Messages are the inquiries
3. **One-Way Communication**: Currently email only, no agent replies in system
4. **No Agent Assignment**: All users see all inquiries, no routing or assignment
5. **Contact History**: Track via Message collection on Contact
6. **Flexible Design**: Address model allows multiple addresses, JSON fields for custom data
7. **Role-Based Access**: UserMembership provides granular role-based control
8. **Growth Ready**: Schema designed to add messaging, routing, and CRM features

---

## File Locations

| File | Purpose |
|------|---------|
| `/app/models/pwb/contact.rb` | Contact model (unscoped) |
| `/app/models/pwb_tenant/contact.rb` | Contact model (scoped) |
| `/app/models/pwb/message.rb` | Message model (unscoped) |
| `/app/models/pwb_tenant/message.rb` | Message model (scoped) |
| `/app/models/pwb/website.rb` | Website model (tenant) |
| `/app/models/pwb/user.rb` | User model |
| `/app/models/pwb/user_membership.rb` | Multi-website support |
| `/app/models/pwb/agency.rb` | Agency company details |
| `/app/models/pwb/address.rb` | Address model (shared) |
| `/app/controllers/pwb/props_controller.rb` | Property inquiries |
| `/app/controllers/pwb/api/v1/contacts_controller.rb` | Contact API |
| `/app/mailers/pwb/enquiry_mailer.rb` | Email delivery |
| `/db/schema.rb` | Database structure |

