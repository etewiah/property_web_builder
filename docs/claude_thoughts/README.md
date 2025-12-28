# PropertyWebBuilder Inquiry & Communication System Documentation

This directory contains comprehensive documentation of the PropertyWebBuilder inquiry and contact management system, created for understanding the codebase architecture, relationships, and data flow.

## Documents in This Directory

### 1. INQUIRY_SYSTEM_ANALYSIS.md ⭐ START HERE
**Comprehensive technical reference** - Read this first to understand the entire system

**Contents:**
- Multi-tenancy architecture (Website = tenant)
- All core models explained in detail
- Model relationships and associations
- Complete inquiry submission flow
- Contact management system
- Email delivery and tracking
- Current communication features
- Identified gaps and limitations
- Opportunities for building SMS/lead management features

**Best for:** Understanding what exists, how it works, and what's missing

---

### 2. MODEL_RELATIONSHIPS.md
**Technical deep-dive with diagrams** - For developers building on the system

**Contents:**
- Entity relationship diagrams (ASCII art)
- Detailed associations with code examples
- Inquiry creation flow (step-by-step)
- Contact discovery and enrichment
- Contact history tracking
- Tenant isolation pattern explained
- Multi-website user support
- Current limitations (agent/property binding)
- File locations for all key models

**Best for:** Understanding data flow, implementing new features, debugging relationships

---

### 3. QUICK_REFERENCE.md
**Cheat sheet and developer guide** - For quick lookups and common tasks

**Contents:**
- Model overview table
- Code examples for common operations
- Current inquiry workflow (simplified)
- What doesn't exist yet (summary)
- File locations cheat sheet
- Common database queries
- Debugging checklist
- Key architecture decisions

**Best for:** Quick lookups, copy-paste code examples, troubleshooting

---

## Quick System Overview

### Architecture Pattern
```
Website (Tenant/Agency)
├── has_many :users (via UserMembership)
├── has_many :contacts [TENANT-SCOPED]
├── has_many :messages [TENANT-SCOPED]
├── has_one :agency
└── has_many :properties

Contact (Visitor/Lead) [TENANT-SCOPED]
├── has_many :messages (inquiry history)
├── has_many :addresses (primary + secondary)
└── optional belongs_to :user

Message (Inquiry) [TENANT-SCOPED]
├── belongs_to :website
├── belongs_to :contact
└── tracks delivery status + error handling

User (Agency Staff)
└── has_many :user_memberships
    └── maps to multiple websites with roles
```

### Current Inquiry Flow
```
1. Visitor submits property inquiry form
2. Controller creates/finds Contact by email
3. Message record created with inquiry details
4. Async job queues email to agency
5. EnquiryMailer sends email (with custom template support)
6. Message delivery status tracked (success/failure)
7. Contact history maintained via message collection
```

### Key Limitation
**No agent/team assignment** - All users see all inquiries for their website; no routing or granular access control.

---

## Core Models at a Glance

| Model | Purpose | Scope | Key Fields |
|-------|---------|-------|-----------|
| Website | Real estate agency tenant | N/A | company_display_name, emails, config |
| Contact | Website visitor/lead | website_id | name, email, phone, address |
| Message | Inquiry/inquiry record | website_id | title, content, delivery_status |
| User | Agency staff member | — | email, password, roles |
| UserMembership | User→Website mapping | — | role (owner/admin/member/viewer) |
| Agency | Company details | website_id | display_name, phone, emails |
| Address | Street address | — | street, city, postal_code, lat/lng |

---

## What Exists Today

✅ Property inquiry forms → Email to agency  
✅ General contact forms → Email to agency  
✅ Contact records (by email)  
✅ Message/inquiry tracking  
✅ Email delivery status  
✅ Custom Liquid email templates  
✅ Multi-website user support  
✅ Role-based access control  
✅ Contact inquiry history  
✅ Async email delivery (Solid Queue)  

---

## What's Missing (For SMS/Lead System)

❌ Agent/team assignment  
❌ Lead status tracking (new, contacted, interested, etc.)  
❌ Lead notes and comments  
❌ Inquiry routing logic  
❌ SMS/Twilio integration  
❌ WhatsApp support  
❌ Two-way messaging (agent replies)  
❌ In-app messaging  
❌ Call tracking  
❌ CRM timeline/activity log  
❌ Contact tagging/categories  

---

## File Organization

### Models (Dual Pattern: Pwb:: + PwbTenant::)
```
app/models/
├── pwb/
│   ├── contact.rb             (unscoped)
│   ├── message.rb             (unscoped)
│   ├── website.rb             (tenant container)
│   ├── user.rb
│   ├── user_membership.rb
│   ├── agency.rb
│   └── address.rb
└── pwb_tenant/
    ├── contact.rb             (auto-scoped)
    ├── message.rb             (auto-scoped)
    └── ...other models
```

### Controllers
```
app/controllers/
├── pwb/
│   ├── props_controller.rb    (request_property_info_ajax)
│   └── api/v1/
│       └── contacts_controller.rb
```

### Mailers
```
app/mailers/
└── pwb/
    └── enquiry_mailer.rb
```

### Database
```
db/
├── schema.rb                  (full schema, search: pwb_contacts, pwb_messages)
└── migrate/                   (all migrations)
```

---

## Multi-Tenancy Model

### Key Concept: Pwb::Current.website
Every request has a current website context set via subdomain/domain:

```ruby
# In controller/view/mailer
Pwb::Current.website  # The current agency's website

# Creates automatic scoping
PwbTenant::Contact.all  # Only contacts for current website
```

### Model Variants
Every major model has two versions:

**Pwb::** (Unscoped)
- Used in console, background jobs, cross-tenant operations
- Must manually scope with `where(website_id: ...)`

**PwbTenant::** (Auto-Scoped)
- Used in web requests
- Automatically scoped to `Pwb::Current.website`
- More secure, less error-prone

---

## How to Use This Documentation

### I'm new to PropertyWebBuilder
1. Read the "Quick System Overview" section above
2. Read QUICK_REFERENCE.md for common tasks
3. Read INQUIRY_SYSTEM_ANALYSIS.md for full understanding

### I need to understand how inquiries work
1. Read "Current Inquiry Flow" section above
2. See "Inquiry Creation Flow" in MODEL_RELATIONSHIPS.md
3. Check PropsController and EnquiryMailer code

### I'm building an SMS/lead management system
1. Read INQUIRY_SYSTEM_ANALYSIS.md completely
2. Review "Gaps & Opportunities" section
3. Check MODEL_RELATIONSHIPS.md for existing patterns
4. Plan for website_id scoping and acts_as_tenant pattern

### I need to debug an issue
1. Check QUICK_REFERENCE.md "Debugging Checklist"
2. Review relevant model file (see file locations)
3. Check database schema in QUICK_REFERENCE.md
4. Consult MODEL_RELATIONSHIPS.md for expected associations

---

## Key Database Tables

```
pwb_websites         -- Agency/tenants
pwb_users            -- User accounts
pwb_user_memberships -- User → Website mapping
pwb_contacts         -- Contacts/leads (website_scoped)
pwb_messages         -- Inquiries/emails (website_scoped)
pwb_addresses        -- Addresses (shared)
pwb_agencies         -- Agency details (website_scoped)
pwb_realty_assets    -- Properties
pwb_sale_listings    -- Sales
pwb_rental_listings  -- Rentals
pwb_properties       -- Materialized view (properties)
pwb_email_templates  -- Custom email templates
```

---

## Common Tasks

### Find all inquiries for a website
```ruby
# In console
Pwb::Message.where(website_id: website.id)

# In controller
PwbTenant::Message.all  # Auto-scoped
```

### Check email delivery status
```ruby
message = Message.find(id)
if message.delivery_success
  puts "Delivered at: #{message.delivered_at}"
else
  puts "Error: #{message.delivery_error}"
end
```

### Get contact inquiry history
```ruby
contact.messages  # All inquiries from this contact
```

### Find contact by email
```ruby
contact = PwbTenant::Contact.find_by(primary_email: email)
```

### Check user roles
```ruby
user.role_for(website)          # Returns: owner, admin, member, viewer
user.admin_for?(website)        # Boolean
user.can_access_website?(site)  # Boolean
```

---

## Important Rules

1. **Always scope to website_id** - All new models need website_id for tenant isolation
2. **Use PwbTenant:: in web requests** - For automatic scoping and security
3. **Use Pwb:: in console** - For unscoped access when needed
4. **Respect user roles** - Check user permissions before operations
5. **Include website_id on creates** - Don't forget it when creating records

---

## Architecture Patterns to Follow

### Model Definition
```ruby
# Unscoped version
module Pwb
  class YourModel < ApplicationRecord
    belongs_to :website
    # ... associations
  end
end

# Scoped version
module PwbTenant
  class YourModel < Pwb::YourModel
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
```

### Controller Usage
```ruby
# In web requests
class MyController < ApplicationController
  def index
    @items = PwbTenant::YourModel.all  # Auto-scoped
  end
  
  def create
    @item = PwbTenant::YourModel.create(
      **params,
      website_id: Pwb::Current.website.id  # Explicit, good practice
    )
  end
end
```

---

## Resources & Files

- **Main schema**: `/db/schema.rb`
- **Model code**: `/app/models/pwb/` and `/app/models/pwb_tenant/`
- **Controllers**: `/app/controllers/pwb/`
- **Mailers**: `/app/mailers/pwb/`
- **Tests**: `/spec/models/`, `/spec/controllers/`, `/spec/mailers/`

---

## Related Documentation

See also in `/docs/`:
- `/docs/architecture/` - System architecture decisions
- `/docs/multi_tenancy/` - Multi-tenancy implementation details
- `/docs/seeding/` - How seed data works
- `/docs/deployment/` - Deployment guides

---

## Summary

PropertyWebBuilder has a **solid foundation** for an inquiry/contact system:
- Multi-tenant architecture with proper scoping
- Email delivery with custom templates
- Contact tracking with inquiry history
- Multi-website user support with roles

**Missing pieces** for a complete CRM/SMS system:
- Two-way messaging
- Agent/team assignment and routing
- Lead pipeline and workflow
- SMS/alternative communication channels
- Activity logging and timeline

All pieces for extending the system are in place - you just need to follow the existing patterns!

---

**Last Updated**: December 28, 2025  
**Documentation Location**: `/Users/etewiah/dev/sites-older/property_web_builder/docs/claude_thoughts/`
