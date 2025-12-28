# PropertyWebBuilder Inquiry & Contact System Analysis

This document provides a comprehensive overview of how the PropertyWebBuilder system currently handles leads, inquiries, contacts, and agent associations.

## Table of Contents
1. [Multi-Tenancy Architecture](#multi-tenancy-architecture)
2. [Core Models & Relationships](#core-models--relationships)
3. [Inquiry Flow](#inquiry-flow)
4. [Contact Management](#contact-management)
5. [Current Communication Features](#current-communication-features)
6. [Gaps & Opportunities](#gaps--opportunities)

---

## Multi-Tenancy Architecture

PropertyWebBuilder is a **multi-tenant SaaS platform** where each `Website` represents a tenant (real estate agency website).

### Key Concepts

**Pwb::Current.website**: The current tenant context, set at the request level for all operations
- Used for isolating data per website
- Scoped in web requests automatically
- Required for all web-facing operations

**Model Variants**:
- `Pwb::Model` - Global, non-scoped version (console work, cross-tenant operations)
- `PwbTenant::Model` - Tenant-scoped version (web requests, auto-scoped to `Pwb::Current.website`)
- Both inherit from the same model; scoping handled via `acts_as_tenant :website`

**Scope Enforcement**:
```ruby
# In web requests, scoped to current website
contact = PwbTenant::Contact.find(id)  # Auto-scoped to Pwb::Current.website

# In console, can access any website
contact = Pwb::Contact.find(id)  # Unscoped
```

---

## Core Models & Relationships

### Website (The Tenant)
**Model**: `Pwb::Website`
- Represents a real estate agency's website/tenant
- Contains all configuration, settings, and branding

**Key Associations**:
```ruby
has_many :users
has_many :contacts
has_many :messages
has_many :user_memberships (multi-website support for users)
has_many :members, through: :user_memberships, source: :user
has_one :agency  # Agency/company details
```

**Key Attributes**:
- `company_display_name` - Display name
- `email_for_property_contact_form` - Where property inquiries go
- `email_for_general_contact_form` - Where general inquiries go

### User (Agency Member)
**Model**: `Pwb::User`
- Represents a person who manages one or more websites
- Authentication via Devise

**Key Associations**:
```ruby
has_many :user_memberships
has_many :websites, through: :user_memberships

# Roles: owner, admin, member, viewer
# Access control: website_id or user_memberships
```

**Multi-Website Support**:
Users can manage multiple websites via `UserMembership` model.
- Can be an admin/member on different websites
- Each membership has a role (owner, admin, member, viewer)

### Contact (Visitor/Lead)
**Model**: `Pwb::Contact` / `PwbTenant::Contact`
- Represents a person who has inquired about properties
- Can be created automatically when someone submits an inquiry form

**Key Attributes**:
- `first_name`, `last_name`
- `primary_email`, `primary_phone_number`
- `other_email`, `other_phone_number`
- `title` (enum: mr, mrs)
- Primary & secondary addresses
- Social IDs: facebook_id, linkedin_id, twitter_id, skype_id
- `details` (JSON) - Extra data storage
- `flags` (integer) - Bit flags for various states

**Associations**:
```ruby
belongs_to :website
belongs_to :user, optional: true
has_many :messages
has_many :primary_address (Pwb::Address)
has_many :secondary_address (Pwb::Address)
```

**Important**: Contacts are **website-scoped** (`website_id` FK), not user-scoped

### Message (Inquiry/Inquiry Record)
**Model**: `Pwb::Message` / `PwbTenant::Message`
- Represents a single inquiry/message from a contact
- Stores inquiry submission details and delivery status

**Key Attributes**:
- `title` - Subject line (e.g., "Property Inquiry")
- `content` - Message body
- `origin_email` - Visitor's email
- `origin_ip` - Visitor's IP address
- `delivery_email` - Where email was sent (from Website config)
- `delivery_success` - Bool indicating delivery status
- `delivered_at` - Timestamp
- `delivery_error` - Error message if failed
- `read` - Bool for admin UI
- `locale` - Language used for inquiry
- `url` - Page where inquiry came from
- `host` - Website domain
- `user_agent` - Browser info
- `latitude`, `longitude` - Geolocation from IP
- `contact_id` - Links to the Contact
- `client_id` - Legacy field (deprecated)

**Associations**:
```ruby
belongs_to :website
belongs_to :contact, optional: true
```

### Agency (Company/Agency Details)
**Model**: `Pwb::Agency` / `PwbTenant::Agency`
- Stores agency/company contact information
- One agency per website

**Key Attributes**:
- `display_name` - Agency name for display
- `company_name` - Official company name
- `email_for_general_contact_form` - General inquiries
- `email_for_property_contact_form` - Property inquiries
- `email_primary` - Primary email
- `phone_number_primary`, `phone_number_mobile`, `phone_number_other`
- `skype` - Skype ID
- Primary & secondary addresses
- `social_media` (JSON) - Social media links

**Associations**:
```ruby
belongs_to :website
belongs_to :primary_address, optional: true
belongs_to :secondary_address, optional: true
```

### UserMembership (Multi-Website Support)
**Model**: `Pwb::UserMembership`
- Manages user access to multiple websites
- Defines user's role per website

**Attributes**:
- `role` - "owner", "admin", "member", or "viewer"
- `active` - Boolean for membership status

**Hierarchy**:
- owner > admin > member > viewer
- Used for authorization checks

---

## Inquiry Flow

### Property Inquiry Submission (via form on property page)

**Endpoint**: `POST /pwb/props/request_property_info_ajax`

**Flow**:
1. Visitor fills out property inquiry form on property detail page
2. Form data includes:
   - Name, email, phone
   - Message/inquiry content
   - Property ID
   - Locale
3. Form submits to `request_property_info_ajax` action

**Controller Logic** (`PropsController#request_property_info_ajax`):
```
1. Create/find Contact by primary_email
   - Set: first_name, primary_phone_number
   
2. Create Message with:
   - website_id (current website)
   - contact_id (from step 1)
   - title: "Property Inquiry" (i18n)
   - content: user's message
   - origin_email, origin_ip, user_agent
   - delivery_email: from Agency.email_for_property_contact_form
   
3. Validation:
   - Contact validates
   - Message validates
   - Return error if validation fails
   
4. Save both Contact and Message
   - Creates association between them
   
5. Send Email (async via Solid Queue):
   - EnquiryMailer.property_enquiry_targeting_agency()
   - To: Agency's property contact email
   - Reply-To: Visitor's email
   - Includes: contact name, property details, message
   
6. Response:
   - Success: Render JS that shows success message
   - Error: Render JS with error messages
```

### General Contact Form (on contact us page)

**Endpoint**: Similar flow to property inquiries
- Different email destination (general contact email)
- Different mailer method: `general_enquiry_targeting_agency`

---

## Contact Management

### How Contacts Are Associated

**Property Inquiries**:
- Contact found/created by `primary_email`
- Linked to Message via `contact_id`
- No direct property association (inquiry → message → property data)
- Contact history: Multiple messages can be linked to same contact

**Address Management**:
- Contacts can have primary and secondary addresses
- Addresses are separate table (`pwb_addresses`)
- Supports multi-address contacts

### Contact Information Stored

```
Primary Contact Data:
- Name (first_name, last_name)
- Email (primary_email, other_email)
- Phone (primary_phone_number, other_phone_number)
- Title (enum: mr, mrs)
- Addresses (via FK to pwb_addresses)

Extended Data:
- details (JSON) - Custom fields
- flags (integer) - Bit flags for states
- Social IDs: facebook, linkedin, twitter, skype
- Fax number
- Website URL
- Nationality
- Documentation type & ID

Relationships:
- website_id - Scoped to website
- user_id - Optional link to internal user
```

### Contact Retrieval

**In Web Requests**:
```ruby
# Tenant-scoped (recommended for web)
contacts = PwbTenant::Contact.where(website_id: Pwb::Current.website.id)
contact = PwbTenant::Contact.find_by(primary_email: email)
```

**In Console**:
```ruby
# Unscoped
contacts = Pwb::Contact.all
contacts_for_website = Pwb::Contact.where(website_id: website.id)
```

---

## Current Communication Features

### Email Delivery

**Mailer**: `Pwb::EnquiryMailer`
- `general_enquiry_targeting_agency()` - General contact form
- `property_enquiry_targeting_agency()` - Property inquiry

**Features**:
1. **Custom Email Templates** (Liquid):
   - Templates: `enquiry.general`, `enquiry.property`
   - Can define custom templates per website
   - Variables: visitor_name, email, phone, message, property details
   - Falls back to ERB templates if custom not found

2. **Delivery Tracking**:
   - Records success/failure on Message model
   - `delivery_success` - Boolean
   - `delivered_at` - Timestamp
   - `delivery_error` - Error text
   - Used for retry logic

3. **Job Queue**: Solid Queue (Rails 8)
   - `.deliver_later` - Async email delivery
   - Configurable queue, retries, error handling

4. **Features**:
   - Reply-To set to visitor email
   - Subject templated
   - HTML and text variants
   - Error handling with callbacks

### Notification System (ntfy.sh)

Website can enable ntfy.sh notifications for:
- Property inquiries (`ntfy_notify_inquiries`)
- New listings (`ntfy_notify_listings`)
- Security events (`ntfy_notify_security`)
- User activity (`ntfy_notify_users`)

**Config**:
- `ntfy_enabled` - Enable/disable
- `ntfy_server_url` - Server (default: https://ntfy.sh)
- `ntfy_access_token` - Authentication
- `ntfy_topic_prefix` - Topic name prefix

### Missing Communication Features

**NOT Currently Implemented**:
- SMS/Twilio integration
- WhatsApp messaging
- In-app messaging
- Call tracking/logging
- Agent assignment to inquiries
- Inquiry assignment/routing
- Inquiry status/pipeline tracking
- Two-way messaging (replies from agents)
- Inquiry notes/comments
- CRM-like follow-up features

---

## Agent/Team Member Associations

### Current Model

**Important**: PropertyWebBuilder does NOT have explicit "Agent" model or agent assignment to properties.

**User Management**:
- Users are website members (via `UserMembership`)
- Roles: owner, admin, member, viewer
- No property-to-user assignment
- No team model

**What Exists**:
- Users manage websites/agencies
- Can view all contacts/inquiries for their website(s)
- Can't restrict visibility of inquiries to specific properties

### Multi-Website Support

Users can:
- Be assigned to multiple websites
- Have different roles on each website
- Access only their assigned websites

```ruby
# User membership roles
owner   - Full control
admin   - Most features, can't manage users
member  - Can view/edit data, limited admin
viewer  - Read-only access
```

---

## Data Model Diagram

```
Website (Tenant)
├── has_many :users (via user_memberships)
├── has_many :user_memberships
├── has_many :contacts
│   └── Contact
│       ├── primary_address (Address)
│       ├── secondary_address (Address)
│       ├── user (optional)
│       └── has_many :messages
│           └── Message
│               ├── website_id
│               └── contact_id (optional)
├── has_many :messages
├── has_one :agency
│   └── Agency
│       ├── primary_address (Address)
│       └── secondary_address (Address)
├── has_many :listed_properties
│   └── ListedProperty (materialized view)
│       ├── sale_listings
│       ├── rental_listings
│       └── realty_assets
└── has_many :pages, :links, :contents, etc.

User
├── has_many :user_memberships
└── has_many :websites (through memberships)
```

---

## Key Database Tables

| Table | Purpose | Tenant Scoped |
|-------|---------|---------------|
| `pwb_websites` | Agency/website tenants | N/A |
| `pwb_users` | User accounts | No (can access multiple websites) |
| `pwb_user_memberships` | User → Website assignments | N/A |
| `pwb_contacts` | Visitor/lead contacts | Yes (website_id) |
| `pwb_messages` | Inquiries/communications | Yes (website_id) |
| `pwb_addresses` | Address data (shared) | No |
| `pwb_agencies` | Agency company info | Yes (website_id) |
| `pwb_contacts` | Contact records | Yes (website_id) |
| `pwb_realty_assets` | Physical properties | Yes (website_id) |
| `pwb_sale_listings` | Sale transaction data | No (via realty_asset) |
| `pwb_rental_listings` | Rental transaction data | No (via realty_asset) |
| `pwb_properties` | Materialized view (denormalized properties) | Yes (website_id) |

---

## Inquiry Routing

### Current Routing

All property inquiries for a website go to:
- `Website.email_for_property_contact_form`

**Problem**: No concept of inquiry routing:
- Can't route by agent
- Can't route by property type
- Can't route by region
- Can't assign to specific team members

### General Contact Inquiries

All general contact form submissions go to:
- `Website.email_for_general_contact_form`

---

## API Endpoints

### Contacts API

**Endpoint**: `POST /pwb/api/v1/contacts`
```ruby
{
  details: {
    first_name: "John",
    last_name: "Doe"
  }
}
```

**Available Methods**:
- `POST` - Create
- `GET /contacts/:id` - Show
- `PATCH /contacts/:id` - Update
- `GET /contacts` - Index (all for website)

### Property Inquiry (AJAX)

**Endpoint**: `POST /pwb/props/request_property_info_ajax`
- Not REST API, returns JS response
- Used by property page forms
- Returns template rendering for error/success

---

## Gaps & Opportunities for Lead Management System

### Missing Features

1. **Lead/Inquiry Management**:
   - No inquiry status tracking (new, contacted, interested, rejected, etc.)
   - No inquiry notes or comments
   - No follow-up scheduling
   - No inquiry assignment to agents
   - No inquiry routing logic

2. **Agent/Team Management**:
   - No agent model
   - No way to assign agents to properties
   - No way to route inquiries to specific agents
   - No team concept

3. **Communication**:
   - No SMS/Twilio integration
   - No WhatsApp support
   - No in-app messaging
   - No call tracking
   - No two-way messaging (agents reply)
   - Email is one-way only

4. **CRM Features**:
   - No pipeline/workflow system
   - No contact history/timeline
   - No activity logging
   - No bulk operations
   - No filtering/search for contacts
   - No contact notes
   - No tags/categories

5. **Reporting**:
   - No inquiry analytics
   - No lead conversion tracking
   - No source attribution
   - No agent performance metrics

### Integration Points for New Features

**For Lead Management**:
1. Create `Lead` model (or extend Contact)
   - Status field
   - Priority/rating
   - Assigned agent FK
   - Created/updated timestamps
   - Notes field
   - Tags/categories

2. Extend `Message` model
   - Direction (inbound/outbound)
   - Agent who sent it
   - Two-way support
   - Attachment support

3. Add `LeadActivity` model
   - Log all actions: viewed, emailed, called, etc.
   - Timestamp & actor
   - Activity type enum

4. Add `AgentAssignment` model
   - Agent → Property/Lead assignment
   - Territory/region assignment
   - Routing rules

5. Add `InquiryRoute` or settings
   - Rule-based routing logic
   - Agent availability
   - Load balancing

**For SMS/Communication**:
1. Extend Message model
   - Channel: email, sms, whatsapp, etc.
   - Phone number field (normalize)
   - Two-way conversation support

2. Add `SmsSetting` model
   - Twilio account integration
   - Phone number pool
   - Inbound webhook handling

3. Add `MessageThread`
   - Group related messages
   - Conversation history
   - Last message timestamp

### Architecture Considerations

**Multi-Tenancy**:
- All new models must include `website_id` for tenant scoping
- Use `acts_as_tenant :website` for PwbTenant variants
- Ensure proper isolation in controllers

**Authorization**:
- Respect user roles (owner, admin, member, viewer)
- Consider agent-specific views (only their assigned leads)
- Implement proper permission checks

**Scalability**:
- Message/activity tables will grow quickly
- Index on website_id + created_at for queries
- Consider archiving old messages

---

## Summary

The PropertyWebBuilder system has:
- **Solid multi-tenant foundation** with Website as tenant
- **Basic inquiry system** via Contact + Message models
- **Email delivery** with custom templates
- **User management** with multi-website support
- **One-way communication** only (email out, replies via email)

**Missing**:
- Two-way messaging
- Lead/inquiry workflow
- Agent assignment/routing
- SMS/alternative channels
- CRM features (notes, activities, pipeline)
- Communication beyond email

This foundation provides a good starting point for building a comprehensive lead management and SMS communication system.
