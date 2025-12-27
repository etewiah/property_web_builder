# Push Notifications - Code Locations Reference

## Core Models

### Contact & Message Models
```
File: app/models/pwb/contact.rb
- Has many messages
- Associations: website, user, addresses
- Key attributes: primary_email, first_name, last_name, phone_number

File: app/models/pwb/message.rb
- Belongs to contact, website
- Key attributes: title, content, origin_email, delivery_email, delivery_success
- Status tracking: delivery_success flag
```

### User & Authentication
```
File: app/models/pwb/user.rb
- Devise authentication with 7 modules
- Multi-website support via user_memberships
- Callbacks: after_create :log_registration, after_update :log_lockout_events
- Key methods: admin_for?(website), role_for(website), accessible_websites
- Firebase auth support

File: app/models/pwb/auth_audit_log.rb
- Complete authentication event tracking
- Event types: login_success/failure, oauth_success/failure, password_reset_*, 
  account_locked/unlocked, session_timeout, registration
- Multi-tenant scoped logging
- Scopes: recent, for_user, for_email, for_ip, failures, successes, today, last_hour, last_24_hours
- Security methods: failed_attempts_for_email, suspicious_ips, recent_activity_for_user
```

### Property & Listing Models
```
File: app/models/pwb/listed_property.rb
- Read-only materialized view model
- Aggregates realty_asset + sale_listing + rental_listing
- Key attributes: reference, website, price, bedrooms, bathrooms, address
- Methods: realty_asset, sale_listing, rental_listing accessors
- Materialized view refresh: self.refresh(concurrently: true)

File: app/models/pwb/rental_listing.rb
- Callback: after_commit :refresh_properties_view
- Callback: before_save :deactivate_other_listings, if: :will_activate?
- Callback: after_save :ensure_active_listing_visible, if: :saved_change_to_active?
- Methods: activate!, deactivate!, archive!, unarchive!
- Scopes: visible, highlighted, active_listing, active, archived, not_archived

File: app/models/pwb/sale_listing.rb
- Same callback pattern as rental_listing.rb
- Callback: after_commit :refresh_properties_view
- Callback: before_save :deactivate_other_listings, if: :will_activate?
- Callback: after_save :ensure_active_listing_visible, if: :saved_change_to_active?
- Methods: activate!, deactivate!, archive!, unarchive!
```

### Website & Tenant Models
```
File: app/models/pwb/website.rb
- Multi-tenant root model
- Has many: contacts, messages, users, properties, listings
- Tenant isolation via website_id foreign keys

File: app/models/pwb/user_membership.rb
- Join table for users and websites
- Role enum: owner, admin, member
- Scope: active members
```

---

## Controllers

### Contact/Message Management
```
File: app/controllers/pwb/contact_us_controller.rb
Line 92: EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_now
  - contact_us_ajax action - handles form submission
  - Creates Contact and Message records
  - Sends email via EnquiryMailer
  - Error handling and flash messages
  
  Key lines:
  - 57: Find or create contact
  - 63-76: Create message with context data
  - 77-89: Validation and save
  - 92: Email delivery

File: app/controllers/site_admin/contacts_controller.rb
- index: Lists contacts for current website (scoped, sorted, searchable)
- show: Displays single contact with message history
- All queries scoped to current_website for multi-tenant isolation

File: app/controllers/site_admin/messages_controller.rb
- index: Lists messages for current website
- show: Displays single message with full context
- Search functionality for origin_email and content
- All queries scoped to current_website
```

### Admin Dashboard
```
File: app/controllers/site_admin/dashboard_controller.rb
Lines 8-26:
- @stats hash: total_properties, total_pages, total_contents, total_messages, total_contacts
- @recent_properties: Last 5 properties (materialized view)
- @recent_messages: Last 5 messages with ordering
- @recent_contacts: Last 5 contacts with ordering
- All scoped by website_id for multi-tenant isolation

Key metrics available:
- Pwb::Message.count (by website)
- Pwb::Contact.count (by website)
- Pwb::ListedProperty.count (by website)
```

### API Endpoints
```
File: app/controllers/pwb/api/v1/contacts_controller.rb
- create: Create contact via API
- update: Update contact (scoped to website)
- show: Get single contact (scoped to website)
- index: List contacts (scoped to website)
- Response format: JSON

File: app/controllers/pwb/api/v1/properties_controller.rb
(Similar pattern for property management via API)
```

---

## Mailers

### Email Templates & Delivery
```
File: app/mailers/pwb/enquiry_mailer.rb
- general_enquiry_targeting_agency(contact, message)
  - Sends to message.delivery_email
  - Template: pwb/mailers/general_enquiry_targeting_agency
  
- property_enquiry_targeting_agency(contact, message, property)
  - Sends to message.delivery_email
  - Template: pwb/mailers/property_enquiry_targeting_agency
  - Includes property details

File: app/mailers/pwb/application_mailer.rb
- Base mailer class
- Defines default from address
- Can be extended with additional mailers

Templates location: app/views/pwb/mailers/
- general_enquiry_targeting_agency.*
- property_enquiry_targeting_agency.*
```

---

## Database Migrations

### Contact & Message Schema
```
File: db/migrate/20161128200709_create_pwb_messages.rb
- Creates pwb_messages table
- Columns: title, content, origin_ip, user_agent, locale, host, url,
  delivery_success (default: false), delivery_email, origin_email

File: db/migrate/20170923195321_create_pwb_contacts.rb
- Creates pwb_contacts table
- Columns: first_name, last_name, title, phone numbers, emails, social IDs,
  address references, user reference, documentation info
- Indexes on: first_name, last_name, phone_number, email, documentation_id

File: db/migrate/20251204141849_add_website_to_contacts_messages_and_photos.rb
- Adds website_id to contacts and messages
- Enables multi-tenant scoping
```

### Auth Audit Log Schema
```
File: db/migrate/* (AuthAuditLog)
- Columns: event_type, user_id, email, ip_address, user_agent, 
  failure_reason, provider, metadata (JSON), request_path, website_id
- Indexes on: user_id, website_id, email, ip_address, event_type, created_at
```

---

## Key Patterns & Hooks

### Multi-Tenancy Pattern
```ruby
# Scoping queries to current website
@contacts = Pwb::Contact.where(website_id: current_website&.id)
@messages = Pwb::Message.where(website_id: current_website&.id)

# Using tenant context
website = Pwb::Current.website

# Tenant-scoped models for web requests
PwbTenant::Contact
PwbTenant::Message
PwbTenant::ListedProperty
```

### Permission Checking
```ruby
# Admin check
user.admin_for?(website)  # => true/false
user.role_for(website)    # => 'owner', 'admin', or 'member'

# Multi-website access
user.accessible_websites  # => websites with active memberships
```

### Callback Locations for Notifications

**Contact/Message Creation**:
```
app/controllers/pwb/contact_us_controller.rb:77-89
- After successful save, trigger notification
```

**Property Listing Changes**:
```
app/models/pwb/rental_listing.rb:42-43
- before_save :deactivate_other_listings, if: :will_activate?
- after_save :ensure_active_listing_visible, if: :saved_change_to_active?

app/models/pwb/sale_listing.rb:39-40
- Same callback pattern
```

**User Registration**:
```
app/models/pwb/user.rb:33-34
- after_create :log_registration
- after_update :log_lockout_events
```

**Security Events**:
```
app/models/pwb/user.rb:156-169
- after_update :log_lockout_events
- Fires on: locked_at changes, unlock_token changes
```

---

## Service Architecture Points

### Where to Add Notification Services

#### 1. In Contact Controller (Real-time)
```ruby
Location: app/controllers/pwb/contact_us_controller.rb:92

Current:
  EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_now

Add:
  Pwb::PushNotificationService.notify_inquiry(@enquiry)
  # OR async:
  Pwb::SendPushNotificationJob.perform_later(message_id: @enquiry.id)
```

#### 2. In Listing Models (Post-save)
```ruby
Location: app/models/pwb/rental_listing.rb:43 & app/models/pwb/sale_listing.rb:40

Current:
  after_save :ensure_active_listing_visible, if: :saved_change_to_active?

Add notification callback:
  after_save :notify_activation, if: :saved_change_to_active?
  
  def notify_activation
    Pwb::NotifyListingActivationJob.perform_later(id, self.class.name)
  end
```

#### 3. In User Model (Registration)
```ruby
Location: app/models/pwb/user.rb:33

Current:
  after_create :log_registration

Add:
  after_create :notify_registration
  
  def notify_registration
    Pwb::NotifyUserRegistrationJob.perform_later(id)
  end
```

#### 4. In Auth Audit Log (Security Events)
```ruby
Location: app/models/pwb/auth_audit_log.rb:196-213

In create_log method or as separate callback:
  notify_on_security_event(event_type, user)
```

---

## Testing Locations

### Existing Specs to Reference
```
File: spec/models/pwb/contact_spec.rb
- Contact model tests

File: spec/models/pwb/message_spec.rb
- Message model tests

File: spec/mailers/pwb/enquiry_mailer_spec.rb
- Email mailer tests
- Pattern: test rendering, recipients, subject

File: spec/controllers/site_admin/contacts_controller_spec.rb
- Admin controller tests
- Pattern: multi-tenant scoping, authorization

File: spec/factories/pwb_contacts.rb
File: spec/factories/pwb_messages.rb
- Test data factories
```

### New Test Structure for Notifications
```
spec/services/pwb/push_notification_service_spec.rb
spec/jobs/pwb/send_push_notification_job_spec.rb
spec/models/pwb/push_notification_spec.rb
spec/models/pwb/push_notification_subscription_spec.rb
spec/models/pwb/notification_preference_spec.rb
spec/controllers/site_admin/push_notification_subscriptions_controller_spec.rb
```

---

## Configuration & Constants

### Application Configuration
```
File: app/jobs/pwb/application_job.rb
- Base class for all background jobs
- Can set queue_as, retry_on, discard_on

File: config/environments/*.rb
- ActionCable configuration (for WebSocket)
- Sidekiq configuration (for background jobs)
```

### Locale Keys (for notification text)
```
File: config/locales/
- Look for existing notification/mailer keys
- Pattern: mailers.general_enquiry_targeting_agency.title
- Add new: notifications.inquiry_received.title, etc.
```

---

## Summary: Implementation Integration Points

| Component | File | Line(s) | Action |
|-----------|------|---------|--------|
| **Inquiry Notification** | `pwb/contact_us_controller.rb` | 92 | Add push after email |
| **Listing Activation** | `pwb/rental_listing.rb` | 43 | Add callback |
| **Listing Activation** | `pwb/sale_listing.rb` | 40 | Add callback |
| **Registration Alert** | `pwb/user.rb` | 33 | Add callback |
| **Security Event** | `pwb/auth_audit_log.rb` | 196-213 | Add in create_log |
| **Dashboard Listener** | `site_admin/dashboard_controller.rb` | 8-26 | Add real-time feed |
| **Preference Storage** | database | new migration | Create tables |
| **Service Logic** | `app/services/` | new | Create service |
| **Job Handler** | `app/jobs/` | new | Create job |

