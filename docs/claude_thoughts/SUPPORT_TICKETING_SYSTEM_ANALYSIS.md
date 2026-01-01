# Support Ticketing System - Architecture Analysis

**Project:** PropertyWebBuilder  
**Analysis Date:** January 1, 2026  
**Purpose:** Comprehensive exploration of the codebase to understand patterns and requirements for implementing a support ticketing system

---

## Executive Summary

PropertyWebBuilder is a sophisticated multi-tenant Rails 8 application with:
- **Dual admin interfaces** for website admins (per-tenant) and platform admins (cross-tenant)
- **Established messaging system** with Contact/Message models that can serve as a foundation
- **Mature authentication & authorization** patterns with role-based access control
- **Event notification system** via ntfy.sh and email templates
- **Subscription/plan-based feature gating** system
- **Audit logging infrastructure** for security events

A support ticketing system would naturally extend the existing messaging infrastructure while adding workflow states, priority levels, and team assignment capabilities.

---

## 1. MULTI-TENANT ARCHITECTURE

### 1.1 Core Multi-Tenancy Model

**Tenant Entity:** `Pwb::Website` (represents each property website instance)

```
Pwb::Website (the tenant)
├── Users (many) - Site owners, admins, agents
├── UserMemberships (many) - Relationship between users and websites
├── Properties/RealtyAssets (many)
├── Contacts (many)
├── Messages (many)
└── Subscriptions (has_one)
```

**Key Files:**
- `/app/models/pwb/website.rb` - 600+ lines, highly featured
- `/app/models/pwb/user.rb` - Authentication with Devise, website multi-access
- `/app/models/pwb/user_membership.rb` - Links users to websites with roles

### 1.2 Tenant Scoping Mechanism

**ActsAsTenant Gem Integration:**
```ruby
# In PwbTenant::ApplicationRecord (tenant-scoped base class)
acts_as_tenant :website, class_name: 'Pwb::Website'

# All PwbTenant:: models automatically scoped to current_website
# Usage: PwbTenant::Contact.all  # => Only current tenant's contacts
```

**Two Model Hierarchies:**
1. **Pwb::** models - Cross-tenant access (use in console, cross-tenant queries)
2. **PwbTenant::** models - Auto-scoped to current tenant (use in web requests)

**Setting Tenant Context:**
```ruby
# In SiteAdminController
def set_tenant_from_subdomain
  ActsAsTenant.current_tenant = current_website
end

# In TenantAdminController (cross-tenant access)
# NO SubdomainTenant concern - explicit unscoped queries needed
unscoped_model(Pwb::Website).all
```

**File:** `/app/models/pwb_tenant/application_record.rb`

### 1.3 Accessing Current Website

**Pattern:**
```ruby
# Controllers have access via:
current_website        # From SubdomainTenant concern
Pwb::Current.website   # Global context

# Both approaches work - Current is thread-safe
```

---

## 2. EXISTING MESSAGING/CONTACT SYSTEMS

### 2.1 Contact Model

**Schema: `pwb_contacts` table**

```
Columns:
  - first_name, last_name, primary_email, primary_phone_number
  - primary_address_id, secondary_address_id (foreign keys)
  - user_id (optional - link to app user)
  - details (JSON for flexible data)
  - flags (integer for feature toggles)
  - documentation_type, documentation_id (ID verification)
  - Social: facebook_id, linkedin_id, twitter_id, skype_id
  - website_id (tenant scoping)

Key Indexes:
  - (first_name, last_name)
  - primary_email (uniqueness not enforced - allows duplicates per website)
  - website_id

Associations:
  - has_many :messages (dependent: :nullify)
  - belongs_to :primary_address (optional)
  - belongs_to :secondary_address (optional)
  - belongs_to :user (optional)
  - belongs_to :website
```

**Key Methods:**
- `display_name` - Returns formatted display name
- `unread_messages_count` - Scoped to website
- `last_message` - Most recent message for this contact

**File:** `/app/models/pwb/contact.rb`

### 2.2 Message Model

**Schema: `pwb_messages` table**

```
Columns:
  - title, content (the message)
  - origin_email, delivery_email (sender/recipient)
  - origin_ip, user_agent (request metadata)
  - url (page where message originated)
  - read (boolean)
  - delivery_success, delivered_at, delivery_error (email tracking)
  - latitude, longitude, locale, host (request context)
  - contact_id (foreign key)
  - website_id (tenant scoping)

Key Indexes:
  - website_id

Scopes:
  - unread/read
  - recent (ordered by created_at DESC)
```

**Key Methods:**
- `sender_email` - Prefers contact email, falls back to origin_email
- `sender_name` - Extracts from contact or email

**Files:** 
- `/app/models/pwb/message.rb`
- `/app/models/pwb_tenant/message.rb` (tenant-scoped version)

### 2.3 Inbox Implementation (CRM-Style View)

**Current Inbox Features (in SiteAdminController):**

```
Left Panel:
  - Contact list with unread counts
  - Search by email, first_name, last_name
  - Last message timestamp
  - Message count per contact
  - Indicator for messages without contacts (orphans)

Right Panel:
  - Contact header with avatar, email, phone
  - Chronological message thread
  - Message read/unread status
  - Delivery success/failure indicators
  - Timestamps for each message
```

**Implementation Pattern:**
```ruby
# In InboxController (site_admin/inbox_controller.rb)
def index
  base_scope = Pwb::Contact
    .where(website_id: current_website.id)
    .joins(:messages)
    .select('pwb_contacts.*', 
            'MAX(pwb_messages.created_at) as last_message_at',
            'COUNT(pwb_messages.id) as messages_count',
            'SUM(...) as unread_count')
    .group('pwb_contacts.id')
    .order('last_message_at DESC')
  
  # Automatic search filtering
  # Renders split-pane view with conversation partial
end
```

**Key Files:**
- `/app/controllers/site_admin/inbox_controller.rb`
- `/app/views/site_admin/inbox/show.html.erb`
- `/app/views/site_admin/inbox/_conversation.html.erb`

### 2.4 Messages Controller

**Routes:** `resources :messages, only: [:index, :show]`

**Features:**
- Mark message as read on view
- Log audit entry when messages are opened
- Integration with AuthAuditLog

**File:** `/app/controllers/site_admin/messages_controller.rb`

---

## 3. ADMIN AREAS & AUTHORIZATION

### 3.1 Two Separate Admin Contexts

#### A. SiteAdminController (Per-Tenant Admin)

**Purpose:** Manage a single website's content, users, and operations

**Location:** `/admin` subdomain or `/site_admin` path

**Base Controller:** `/app/controllers/site_admin_controller.rb`

**Key Features:**
- Includes `SubdomainTenant` concern (sets tenant context automatically)
- All PwbTenant:: models auto-scoped to current_website
- `set_tenant_from_subdomain` - Sets ActsAsTenant.current_tenant
- `require_admin!` - Verifies user is admin/owner for this website
- `user_is_admin_for_subdomain?` - Uses user.admin_for?(website)

**Views Directory:** `/app/views/site_admin/`

**Navigation Counts:** Set by `set_nav_counts` - tracks unread_messages_count

**Example Routes:**
```ruby
namespace :site_admin do
  root to: 'dashboard#index'
  resources :messages, only: [:index, :show]
  resources :inbox, only: [:index]
  resources :contacts, only: [:index, :show]
  # ... many more
end
```

**Authorization Pattern:**
```ruby
def require_admin!
  unless current_user && user_is_admin_for_subdomain?
    render 'pwb/errors/admin_required', layout: 'pwb/admin_panel_error', 
           status: :forbidden
  end
end

def user_is_admin_for_subdomain?
  current_user && current_user.admin_for?(current_website)
end
```

**File:** `/app/controllers/site_admin_controller.rb`

#### B. TenantAdminController (Platform-Wide Super Admin)

**Purpose:** Manage all websites, users, and platform operations

**Location:** Requires email in `TENANT_ADMIN_EMAILS` environment variable

**Base Controller:** `/app/controllers/tenant_admin_controller.rb`

**Key Features:**
- NO SubdomainTenant concern (can access all tenants)
- Cross-tenant access via `unscoped_model(Pwb::Website).all`
- Authorization: Email whitelist from ENV variable
- `tenant_admin_allowed?` - Checks user email against allowed list

**Views Directory:** `/app/views/tenant_admin/`

**Example Routes:**
```ruby
namespace :tenant_admin do
  root to: 'dashboard#index'
  resources :websites, only: [:index, :show, :edit, :update]
  resources :users, only: [:index, :show, :edit, :update]
  # ... platform-wide management
end
```

**Authorization Pattern:**
```ruby
def require_tenant_admin!
  unless tenant_admin_allowed?
    render 'pwb/errors/tenant_admin_required', layout: 'tenant_admin', 
           status: :forbidden
  end
end

def tenant_admin_allowed?
  allowed_emails = ENV.fetch('TENANT_ADMIN_EMAILS', '')
    .split(',').map(&:strip).map(&:downcase)
  allowed_emails.include?(current_user.email.downcase)
end
```

**File:** `/app/controllers/tenant_admin_controller.rb`

### 3.2 User Roles & Memberships

**Model:** `Pwb::UserMembership`

```
ROLES = %w[owner admin member viewer]

Role Hierarchy (lower = higher authority):
  owner (0)  - Full control
  admin (1)  - Admin access
  member (2) - Member access
  viewer (3) - Read-only
```

**Key Methods:**
```ruby
membership.admin?        # owner or admin
membership.owner?        # owner only
membership.can_manage?(other)  # Check if can manage another user

# User access queries
user.admin_for?(website)     # Is user admin/owner?
user.role_for(website)       # Get user's role
user.accessible_websites     # All websites user has active membership in
```

**File:** `/app/models/pwb/user_membership.rb`

### 3.3 Permissions Patterns

**Pattern 1: Per-Website Admin Check**
```ruby
# In user model
def admin_for?(website)
  user_memberships.active.where(website: website, role: ['owner', 'admin']).exists?
end

# Usage in controllers
before_action :require_admin!
def require_admin!
  unless current_user && user_is_admin_for_subdomain?
    render forbidden_error
  end
end
```

**Pattern 2: Cross-Tenant Admin Check**
```ruby
# In TenantAdminController
def require_tenant_admin!
  unless tenant_admin_allowed?
    render forbidden_error
  end
end
```

**Pattern 3: Feature-Based Access (via Subscriptions)**
```ruby
website.subscription.has_feature?(:api_access)
website.subscription.within_property_limit?(count)
```

---

## 4. EXISTING AUDIT LOGGING & NOTIFICATIONS

### 4.1 Auth Audit Log System

**Model:** `Pwb::AuthAuditLog`

**Purpose:** Security event tracking and analysis

```
Event Types:
  - login_success, login_failure
  - logout
  - oauth_success, oauth_failure
  - password_reset_request, password_reset_success
  - account_locked, account_unlocked
  - session_timeout
  - registration
  - message_read (for ticket reading audit trail)

Data Captured:
  - User ID, email
  - Event type, timestamp
  - IP address, user agent
  - Request path
  - Failure reason (if applicable)
  - Custom metadata (JSON)
  - Website ID (for multi-tenancy)
```

**Key Scopes:**
```ruby
AuthAuditLog.recent          # ORDER BY created_at DESC
AuthAuditLog.for_user(user)
AuthAuditLog.for_email(email)
AuthAuditLog.for_ip(ip)
AuthAuditLog.for_website(website)
AuthAuditLog.failures        # Failed login attempts
AuthAuditLog.last_24_hours
```

**Usage Pattern:**
```ruby
# Log events via class methods
Pwb::AuthAuditLog.log_login_success(user: current_user, request: request, website: website)
Pwb::AuthAuditLog.log_message_read(user: current_user, message: message, request: request, website: website)

# Query suspicious activity
user.suspicious_activity?(threshold: 5, since: 1.hour.ago)
AuthAuditLog.failed_attempts_for_email(email, since: 1.hour.ago)
```

**File:** `/app/models/pwb/auth_audit_log.rb`

### 4.2 Notification Systems

#### A. Email Notifications

**Mailer Pattern:**
```ruby
# EnquiryMailer - Example of custom template support
class EnquiryMailer < Pwb::ApplicationMailer
  # Standard ERB templates + custom Liquid templates
  
  def general_enquiry_targeting_agency(contact, message)
    # Try custom template first
    if custom_template_available?("enquiry.general")
      send_with_custom_template(...)
    else
      # Fall back to ERB
      mail(to: email, subject: title)
    end
  end
end
```

**Files:**
- `/app/mailers/pwb/enquiry_mailer.rb`
- `/app/mailers/pwb/application_mailer.rb`

#### B. Background Job Queue (Solid Queue)

**Pattern:**
```ruby
# Jobs are enqueued asynchronously
NtfyNotificationJob.perform_later(website_id, :notification_type, record_id)
RefreshPropertiesViewJob.perform_later
```

**TenantAwareJob:**
```ruby
class SomeJob < ActiveJob::Base
  include TenantAwareJob  # Auto-sets tenant context
  
  def perform(website_id)
    ActsAsTenant.with_tenant(website) do
      # Safe to access tenant-scoped models
    end
  end
end
```

**Files:**
- `/app/jobs/ntfy_notification_job.rb`
- `/app/jobs/concerns/tenant_aware_job.rb`

#### C. Ntfy.sh Push Notifications

**Integration:**
```ruby
# Website configuration
website.ntfy_enabled        # Enable/disable ntfy
website.ntfy_server_url     # Server URL (default: https://ntfy.sh)
website.ntfy_access_token   # Auth token
website.ntfy_topic_prefix   # Topic prefix for organization

# Notification types
website.ntfy_notify_inquiries  # Contact form submissions
website.ntfy_notify_listings   # Property changes
website.ntfy_notify_security   # Security events
website.ntfy_notify_users      # User events
```

**Notification Service:**
```ruby
# In NtfyNotificationJob
NtfyService.notify_inquiry(website, message)
NtfyService.notify_listing_change(website, listing, action)
NtfyService.notify_security_event(website, event_type, details)
NtfyService.notify_admin(website, title, message, options)
```

**Files:**
- `/app/jobs/ntfy_notification_job.rb`
- Environment: NTFY_SERVICE_URL

#### D. Email Templates (Liquid-Based)

**Model:** `Pwb::EmailTemplate`

**Features:**
- Custom Liquid templates per website
- Template variables injection
- Both HTML and text rendering
- Reusable template key system

**File:** `/app/models/pwb/email_template.rb`

---

## 5. SUBSCRIPTION & PLAN-BASED FEATURES

### 5.1 Plan Model

**Purpose:** Define tiers, pricing, and available features

```
Schema:
  - name, slug, display_name (unique)
  - price_cents, price_currency
  - billing_interval (month/year)
  - trial_days, trial_unit, trial_value (flexible trial duration)
  - property_limit, user_limit (nil = unlimited)
  - features (JSON array of feature keys)
  - active, public, position (for ordering)

Example Features:
  - default_theme, all_themes, custom_theme
  - subdomain_only, custom_domain
  - single_language, multi_language_3, multi_language_8
  - email_support, priority_support, dedicated_support
  - ssl_included, analytics, api_access, white_label
```

**Key Methods:**
```ruby
plan.has_feature?(:api_access)
plan.enabled_features        # Returns { key:, description: } array
plan.unlimited_properties?
plan.formatted_price         # "€29/month"
plan.trial_duration          # Returns ActiveSupport::Duration
plan.trial_end_date(start_date)
```

**File:** `/app/models/pwb/plan.rb`

### 5.2 Subscription Model

**Purpose:** Links websites to plans and tracks billing status

```
Status Flow:
  trialing -> active (payment received)
  trialing -> expired (trial ends, no payment)
  active -> past_due (payment failed)
  active -> canceled (user cancels)
  past_due -> active (payment succeeds)

Columns:
  - status (AASM state machine)
  - plan_id (foreign key)
  - website_id (belongs_to)
  - trial_ends_at, current_period_starts_at, current_period_ends_at
  - external_id, external_provider (for Stripe integration)
  - metadata (JSONB)
```

**Key Methods:**
```ruby
subscription.in_good_standing?      # trialing or active
subscription.allows_access?         # trialing, active, or past_due
subscription.trial_ended?
subscription.trial_days_remaining
subscription.trial_ending_soon?
subscription.within_property_limit?(count)
subscription.has_feature?(:feature_key)
subscription.change_plan(new_plan)
```

**AASM State Machine:**
```ruby
event :activate do
  transitions from: [:trialing, :past_due, :canceled], to: :active
end

event :expire_trial do
  transitions from: :trialing, to: :expired
end

event :mark_past_due do
  transitions from: :active, to: :past_due
end
```

**File:** `/app/models/pwb/subscription.rb`

---

## 6. UI PATTERNS & FRONTEND ARCHITECTURE

### 6.1 Admin UI Stack

**Technology:**
- **View Templates:** ERB (Rails standard)
- **Styling:** Tailwind CSS (Bootstrap is deprecated)
- **JavaScript:** Stimulus.js (Vue.js is deprecated)
- **Layouts:** `/app/views/layouts/site_admin.html.erb` and `/app/views/layouts/tenant_admin.html.erb`

**Note:** Vue.js and GraphQL are deprecated in v2.0. All new features use ERB + Stimulus.

### 6.2 Common List View Pattern

**Inbox Example (Split-Pane Layout):**
```erb
<div class="h-[calc(100vh-8rem)] flex">
  <!-- Left Panel: Contact List -->
  <div class="w-80 flex-shrink-0 bg-white border-r border-gray-200">
    <!-- Search form -->
    <%= form_with url: site_admin_inbox_index_path, method: :get, local: true %>
      <%= f.text_field :search, placeholder: "Search contacts..." %>
    <% end %>
    
    <!-- Contact list with badges -->
    <% @contacts.each do |contact| %>
      <div class="px-4 py-3 border-b border-gray-100 hover:bg-gray-50">
        <p class="font-medium"><%= contact.display_name %></p>
        <p class="text-xs text-gray-500"><%= contact.primary_email %></p>
        <% if contact.unread_count.to_i > 0 %>
          <span class="badge badge-blue"><%= contact.unread_count %></span>
        <% end %>
      </div>
    <% end %>
  </div>
  
  <!-- Right Panel: Detail View -->
  <div class="flex-1 flex flex-col bg-gray-50">
    <%= render 'conversation', contact: @selected_contact, messages: @messages %>
  </div>
</div>
```

### 6.3 Form Patterns

**Standard Form Pattern (ERB):**
```erb
<%= form_with model: @contact, local: true, class: "space-y-6" do |f| %>
  <div class="space-y-4">
    <div>
      <%= f.label :first_name, class: "block text-sm font-medium text-gray-700" %>
      <%= f.text_field :first_name, class: "mt-1 block w-full rounded-lg border border-gray-300" %>
    </div>
    
    <div>
      <%= f.label :primary_email %>
      <%= f.email_field :primary_email %>
    </div>
  </div>
  
  <div class="flex gap-3">
    <%= f.submit "Save", class: "btn btn-primary" %>
    <%= link_to "Cancel", site_admin_contacts_path, class: "btn btn-secondary" %>
  </div>
<% end %>
```

### 6.4 Navigation & Sidebar

**Pattern:**
- Sidebar with resource links
- Unread counts via badge system
- Link highlighting for current page
- Help text and contextual actions

---

## 7. DESIGN PATTERNS & CONVENTIONS

### 7.1 Controller Organization

**Concern Pattern:**
```ruby
module SiteAdminIndexable
  # Shared indexing logic
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    def indexable_config(model:, search_columns:, limit:)
      # Configure search/filtering
    end
  end
end

# Usage in controller
class MessagesController < SiteAdminController
  include SiteAdminIndexable
  
  indexable_config model: Pwb::Message,
                   search_columns: %i[origin_email content],
                   limit: 100
end
```

### 7.2 Model Scoping Pattern

**Tenant-Aware Queries:**
```ruby
# In PwbTenant models (auto-scoped)
class PwbTenant::Contact < Pwb::Contact
  # All queries automatically scoped to current_website
end

# In Pwb models (cross-tenant)
# Use explicit where clauses or unscoped
Pwb::Contact.where(website_id: website.id).all
ActsAsTenant.without_tenant { Pwb::Contact.all }
```

### 7.3 Error Handling Pattern

**Standardized Error Views:**
```ruby
# In controllers
rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

def record_not_found
  @resource_type = controller_name.singularize.titleize
  render 'site_admin/shared/record_not_found', status: :not_found
end
```

### 7.4 Pagination Pattern

**Pagy Integration:**
```ruby
class SomeController < SiteAdminController
  include Pagy::Method  # Adds @pagy and @items
  
  def index
    @pagy, @items = pagy(Model.all)
  end
end
```

---

## 8. TICKETING SYSTEM DESIGN RECOMMENDATIONS

### 8.1 Data Model Extensions

**New Tables Needed:**

#### `pwb_support_tickets`
```sql
CREATE TABLE pwb_support_tickets (
  id UUID PRIMARY KEY,
  
  -- Tenant scoping
  website_id BIGINT NOT NULL REFERENCES pwb_websites(id),
  
  -- Basic Info
  subject STRING NOT NULL,
  description TEXT,
  ticket_number STRING UNIQUE NOT NULL,  -- e.g., "TKT-001"
  
  -- Status & Workflow
  status STRING DEFAULT 'open',          -- open, in_progress, resolved, closed, on_hold
  priority STRING DEFAULT 'normal',      -- low, normal, high, urgent
  
  -- Assignment
  assigned_to_id BIGINT REFERENCES pwb_users(id), NULL
  assigned_at DATETIME,
  
  -- Contacts
  contact_id BIGINT REFERENCES pwb_contacts(id), NULL
  creator_user_id BIGINT REFERENCES pwb_users(id), NULL
  
  -- Metadata
  category STRING,  -- billing, technical, feature_request, bug_report, general
  tags TEXT[],
  
  -- Timestamps
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  closed_at DATETIME,
  resolved_at DATETIME,
  
  -- Tracking
  message_count INTEGER DEFAULT 0,
  last_message_at DATETIME,
  last_message_from_user BOOLEAN,  -- TRUE if last message is from admin
  
  -- SLA Tracking
  sla_expires_at DATETIME,
  sla_breached BOOLEAN DEFAULT FALSE
)
```

#### `pwb_ticket_messages`
```sql
CREATE TABLE pwb_ticket_messages (
  id UUID PRIMARY KEY,
  
  ticket_id UUID NOT NULL REFERENCES pwb_support_tickets(id),
  website_id BIGINT NOT NULL REFERENCES pwb_websites(id),
  
  -- Author
  user_id BIGINT REFERENCES pwb_users(id), NULL      -- If from admin
  contact_id BIGINT REFERENCES pwb_contacts(id), NULL  -- If from customer
  author_email STRING NOT NULL,
  
  -- Content
  content TEXT NOT NULL,
  is_internal_note BOOLEAN DEFAULT FALSE,
  
  -- Status change tracking
  status_changed_from STRING,
  status_changed_to STRING,
  
  -- Attachments (via ActiveStorage)
  has_attachments BOOLEAN DEFAULT FALSE,
  
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
  
  INDEX (ticket_id),
  INDEX (website_id, ticket_id),
  INDEX (user_id, created_at)
)
```

#### `pwb_ticket_assignments`
```sql
CREATE TABLE pwb_ticket_assignments (
  id BIGINT PRIMARY KEY,
  
  ticket_id UUID NOT NULL REFERENCES pwb_support_tickets(id),
  website_id BIGINT NOT NULL REFERENCES pwb_websites(id),
  user_id BIGINT NOT NULL REFERENCES pwb_users(id),
  
  assigned_at DATETIME NOT NULL,
  unassigned_at DATETIME,
  
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  
  UNIQUE (ticket_id, user_id, unassigned_at)
)
```

### 8.2 Model Hierarchy

```ruby
# Cross-tenant models
module Pwb
  class SupportTicket < ApplicationRecord
    belongs_to :website
    belongs_to :contact, optional: true
    belongs_to :creator_user, class_name: 'User', optional: true
    belongs_to :assigned_to_user, class_name: 'User', optional: true, foreign_key: :assigned_to_id
    
    has_many :ticket_messages, dependent: :destroy
    has_many :assignments, class_name: 'TicketAssignment', dependent: :destroy
    
    enum status: { open: 0, in_progress: 1, resolved: 2, closed: 3, on_hold: 4 }
    enum priority: { low: 0, normal: 1, high: 2, urgent: 3 }
  end
  
  class TicketMessage < ApplicationRecord
    belongs_to :support_ticket
    belongs_to :website
    belongs_to :user, optional: true
    belongs_to :contact, optional: true
    
    has_many_attached :attachments
  end
end

# Tenant-scoped models
module PwbTenant
  class SupportTicket < Pwb::SupportTicket
    # Auto-scoped to current_website
  end
  
  class TicketMessage < Pwb::TicketMessage
    # Auto-scoped to current_website
  end
end
```

### 8.3 Controller Architecture

**Routes:**
```ruby
namespace :site_admin do
  resources :support_tickets, only: [:index, :show, :new, :create, :edit, :update] do
    member do
      patch :assign_to
      patch :change_status
      patch :change_priority
    end
    
    resources :messages, only: [:create], module: 'support_tickets'
  end
end

namespace :tenant_admin do
  resources :support_tickets, only: [:index, :show] do
    member do
      patch :assign_to
      patch :change_status
    end
  end
end
```

**Controller Pattern:**
```ruby
module SiteAdmin
  class SupportTicketsController < SiteAdminController
    include SiteAdminIndexable
    
    before_action :load_ticket, only: [:show, :edit, :update, :assign_to]
    
    indexable_config model: Pwb::SupportTicket,
                     search_columns: %i[subject description ticket_number],
                     limit: 50,
                     filters: { status: :enum, priority: :enum, assigned_to_id: :user }
    
    def show
      @messages = @ticket.ticket_messages.includes(:user, :contact).order(created_at: :asc)
      mark_ticket_as_viewed if @ticket.viewed_by.exclude?(current_user.id)
    end
    
    def change_status
      old_status = @ticket.status
      @ticket.update!(status: params[:status])
      
      create_status_change_message(old_status, @ticket.status)
      notify_stakeholders(@ticket, :status_changed)
      
      respond_to do |format|
        format.json { render json: { status: @ticket.status } }
      end
    end
    
    private
    
    def load_ticket
      @ticket = current_website.support_tickets.find(params[:id])
    end
  end
end
```

### 8.4 Key Features to Implement

**1. Ticket Lifecycle:**
- ✅ Creation (from customer portal or admin)
- ✅ Status workflow (open → in_progress → resolved → closed)
- ✅ Priority management (low/normal/high/urgent)
- ✅ Assignment to team members
- ✅ On-hold status for pending customer action
- ✅ Auto-close after resolution period

**2. Communication:**
- ✅ Ticket message thread (similar to current inbox)
- ✅ Internal notes (visible only to admins)
- ✅ Customer notifications for status changes
- ✅ Admin notifications for new tickets/assignments
- ✅ Email notification preferences

**3. Search & Filtering:**
- ✅ Full-text search on subject/description
- ✅ Filter by status, priority, assigned_to
- ✅ Filter by date range
- ✅ Filter by category/tags
- ✅ Saved search filters

**4. Metrics & Reporting:**
- ✅ Tickets per status
- ✅ Average response time
- ✅ Resolution time
- ✅ Ticket volume trends
- ✅ Assigned workload view

**5. SLA Management:**
- ✅ SLA templates per plan
- ✅ SLA expiration tracking
- ✅ SLA breach alerts
- ✅ Automated escalation on breach

**6. Automation:**
- ✅ Auto-assign based on rules
- ✅ Auto-close after period of inactivity
- ✅ Automated reminder emails
- ✅ Status-based email notifications

### 8.5 Integration Points

**1. Feature Gating:**
```ruby
# Check if plan includes support ticketing
website.subscription.has_feature?(:support_tickets)

# Add to Plan.FEATURES
support_tickets: 'Support ticketing system',
priority_support: 'Priority support with SLA',
unlimited_tickets: 'Unlimited ticket history'
```

**2. Notification Integration:**
```ruby
# Use existing NtfyService
NtfyService.notify_ticket_created(website, ticket)
NtfyService.notify_ticket_assigned(website, ticket, assigned_to)
NtfyService.notify_ticket_status_changed(website, ticket)

# Use EnquiryMailer pattern or new TicketMailer
TicketMailer.ticket_created(ticket).deliver_later
TicketMailer.ticket_assigned(ticket, assigned_to).deliver_later
```

**3. Audit Logging:**
```ruby
# Extend AuthAuditLog
EVENT_TYPES = [...existing..., 'ticket_created', 'ticket_status_changed', 
                'ticket_assigned', 'ticket_closed']

# Log all ticket actions
Pwb::AuthAuditLog.log_ticket_event(
  event_type: 'ticket_status_changed',
  user: current_user,
  ticket: @ticket,
  metadata: { from_status: old_status, to_status: new_status }
)
```

**4. Contact Integration:**
```ruby
# Link to existing Contact model
ticket.contact   # Can be null for internal tickets
ticket.creator_user  # The user who created ticket

# Create tickets from contact inbox
# Option 1: Convert message to ticket
# Option 2: Create new ticket from contact
```

**5. Role-Based Access:**
```ruby
# Existing role system applies
membership.admin?  # Can view/manage all tickets
membership.role_for(website) == 'member'  # Assigned tickets only

# SLA/Priority access could be tied to roles or plan features
```

### 8.6 Views Structure

**Suggested View Hierarchy:**
```
app/views/site_admin/support_tickets/
  ├── index.html.erb          # Ticket list with filters
  ├── show.html.erb            # Ticket detail + thread
  ├── new.html.erb             # Create ticket
  ├── edit.html.erb            # Edit ticket metadata
  ├── _list.html.erb          # Shared list partial
  ├── _conversation.html.erb  # Message thread
  └── _filters.html.erb       # Search/filter form

app/views/tenant_admin/support_tickets/
  ├── index.html.erb          # Platform-wide view
  └── show.html.erb            # Detail view (read-only or limited)
```

---

## 9. DATABASE MIGRATION STRATEGY

### 9.1 Safe Multi-Tenancy Migration

**Pattern Used in Project:**
```ruby
# Migration that doesn't assume tenant scoping in constraints
class CreateSupportTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_support_tickets, id: :uuid do |t|
      # Always include website_id for tenant scoping
      t.references :website, foreign_key: { to_table: :pwb_websites }, null: false
      
      # Other columns...
      t.string :subject, null: false
      t.timestamps
    end
    
    # Index for common queries
    add_index :pwb_support_tickets, [:website_id, :status]
    add_index :pwb_support_tickets, [:website_id, :created_at], name: 'idx_tickets_by_website_and_date'
  end
end
```

### 9.2 Idempotent Seeding Pattern

**From Project's Seed Pack System:**
```ruby
# seeds/support_tickets.yml - seed pack data
support_tickets:
  - subject: "Sample Support Request"
    description: "This is a test ticket"
    status: "open"
    priority: "normal"
    category: "general"
```

---

## 10. TESTING PATTERNS

### 10.1 Request Specs Pattern (RSpec)

```ruby
describe 'POST /site_admin/support_tickets', type: :request do
  let(:website) { create(:website) }
  let(:user) { create(:user, website: website) }
  let(:membership) { create(:user_membership, user: user, website: website, role: 'admin') }
  
  before { login_as(user) }
  
  context 'when user is admin' do
    it 'creates a ticket' do
      post site_admin_support_tickets_path,
           params: { support_ticket: { subject: 'Test', description: '...' } }
      
      expect(response).to redirect_to(site_admin_support_ticket_path(assigns(:ticket)))
      expect(website.support_tickets.count).to eq(1)
    end
  end
  
  context 'when user is not admin' do
    it 'denies access' do
      membership.update!(role: 'member')
      
      post site_admin_support_tickets_path
      
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

### 10.2 Multi-Tenancy Testing

```ruby
describe 'Ticket Isolation' do
  let(:website1) { create(:website) }
  let(:website2) { create(:website) }
  
  it 'does not leak tickets between tenants' do
    ticket1 = create(:support_ticket, website: website1)
    ticket2 = create(:support_ticket, website: website2)
    
    ActsAsTenant.with_tenant(website1) do
      expect(PwbTenant::SupportTicket.count).to eq(1)
      expect(PwbTenant::SupportTicket.first.id).to eq(ticket1.id)
    end
  end
end
```

---

## 11. DEPLOYMENT CONSIDERATIONS

### 11.1 Feature Flags

**Pattern (existing):**
```ruby
# In Plan model
FEATURES = {
  support_tickets: 'Support ticketing system',
  priority_support: 'Priority support with SLA'
}

# Check before rendering UI
<% if current_website.subscription.has_feature?(:support_tickets) %>
  <%= link_to "Support Tickets", site_admin_support_tickets_path %>
<% end %>
```

### 11.2 Background Job Queue

**Use existing queue:**
```ruby
# Solid Queue already configured
class SendTicketNotificationJob < ApplicationJob
  include TenantAwareJob
  
  def perform(ticket_id, notification_type)
    ActsAsTenant.with_tenant(ticket.website) do
      # Send notification
    end
  end
end
```

### 11.3 Data Migration

**Safe approach for production:**
1. Deploy code without showing UI (feature-flagged to false)
2. Run migrations on production
3. Seed any default data (categories, SLA templates)
4. Enable feature flag once verified

---

## 12. COMPARISON WITH EXISTING MESSAGING SYSTEM

| Feature | Current Messages | Tickets (Proposed) |
|---------|------------------|-------------------|
| **Purpose** | Customer inquiries | Internal issue tracking |
| **Workflow** | Simple read/unread | Stateful workflow |
| **Priority** | None | Yes (low/normal/high/urgent) |
| **Assignment** | Auto via email config | Manual assignment |
| **Categories** | None | Yes (tags, categories) |
| **Internal Notes** | No | Yes (invisible to customer) |
| **SLA Tracking** | No | Yes |
| **Search** | By email/content | By subject/ticket #/category |
| **Metrics** | Message count | Resolution time, SLA compliance |
| **Access** | Per-website admins | Assigned team members |
| **Multi-tenancy** | ✅ Full | ✅ Full |
| **Audit Logging** | Basic | Full (every change) |

**Reuse Strategy:**
- Extend existing Contact model (tickets linked to contact)
- Follow message threading pattern for ticket messages
- Use same notification system (ntfy + email)
- Follow existing audit log patterns
- Use same role-based authorization

---

## 13. SUMMARY & RECOMMENDATIONS

### Key Architectural Patterns to Leverage

1. **Multi-Tenancy:** Use `acts_as_tenant` gem (already integrated)
   - Create Pwb:: and PwbTenant:: model pairs
   - All queries scoped to website automatically

2. **Admin Access:** Use existing role system
   - Check `user.admin_for?(website)` for per-tenant access
   - Check email whitelist for platform-wide access

3. **Notifications:** Integrate with ntfy + email
   - Use NtfyNotificationJob pattern
   - Leverage EmailTemplate system

4. **Audit Logging:** Extend AuthAuditLog
   - Log all ticket operations
   - Track status changes and assignments

5. **UI Components:** Follow existing patterns
   - Tailwind CSS + ERB templates
   - Stimulus.js for interactions
   - Split-pane pattern from inbox

6. **Background Jobs:** Use TenantAwareJob concern
   - Ensures tenant context is set
   - Safe for multi-tenant operations

### Implementation Priority

1. **Phase 1 (Core):**
   - SupportTicket + TicketMessage models
   - Basic CRUD operations
   - List/show views
   - Status workflow

2. **Phase 2 (Enhancement):**
   - Assignment system
   - Priority levels
   - Search/filtering
   - Notifications

3. **Phase 3 (Advanced):**
   - SLA tracking
   - Internal notes
   - Metrics/reporting
   - Automation rules
   - Mobile responsive views

### Risk Mitigation

- **Database:** Follow project's idempotent migration pattern
- **Testing:** Use existing RSpec patterns, test multi-tenancy isolation
- **Deployment:** Feature-flag until ready, gradual rollout by plan
- **Performance:** Index website_id + common filters, use pagination

---

## Reference Files

**Core Architecture:**
- `/app/models/pwb/website.rb` - Tenant entity
- `/app/models/pwb/user.rb` - Authentication
- `/app/models/pwb/user_membership.rb` - Authorization
- `/app/models/pwb_tenant/application_record.rb` - Tenant scoping

**Messaging System (Foundation):**
- `/app/models/pwb/contact.rb` - Contact entity
- `/app/models/pwb/message.rb` - Message entity
- `/app/controllers/site_admin/inbox_controller.rb` - Inbox implementation
- `/app/views/site_admin/inbox/show.html.erb` - UI pattern

**Notification Patterns:**
- `/app/jobs/ntfy_notification_job.rb` - Background jobs
- `/app/mailers/pwb/enquiry_mailer.rb` - Email pattern
- `/app/models/pwb/auth_audit_log.rb` - Audit logging

**Authorization & Admin:**
- `/app/controllers/site_admin_controller.rb` - Per-tenant admin
- `/app/controllers/tenant_admin_controller.rb` - Platform admin

**Feature Gating:**
- `/app/models/pwb/plan.rb` - Plan features
- `/app/models/pwb/subscription.rb` - Subscription status
