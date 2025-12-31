# Tenant Admin Structure Analysis

This document provides a comprehensive overview of the PropertyWebBuilder tenant admin interface, including existing features, current model associations, and recommendations for future enhancements.

## Executive Summary

The tenant_admin section is a comprehensive Rails admin interface for managing:
- Users and user memberships
- Websites and subdomains
- Agencies and contacts
- Email templates and domains
- Authentication audit logs
- Content and properties

The architecture uses:
- **Multi-tenancy model**: Websites are tenants, users can belong to multiple websites via memberships
- **Subscription system**: Plans, subscriptions, and subscription events already exist
- **State machines**: Websites have provisioning states, subdomains have allocation states, subscriptions have billing states
- **Role-based access**: User memberships include role hierarchies (owner > admin > member > viewer)

---

## 1. Tenant Admin Controllers

### Existing Controllers
```
app/controllers/tenant_admin/
├── dashboard_controller.rb           # Overview dashboard
├── users_controller.rb               # User management (CRUD)
├── website_admins_controller.rb      # Add/remove admins to websites
├── websites_controller.rb            # Website management with provisioning
├── subdomains_controller.rb          # Subdomain pool management & reservation
├── agencies_controller.rb            # Agency/contact management
├── auth_audit_logs_controller.rb     # Authentication audit logs
├── domains_controller.rb             # Custom domain management
├── email_templates_controller.rb     # Email template management
├── pages_controller.rb               # Page management
├── page_parts_controller.rb          # Page parts (content blocks)
├── props_controller.rb               # Properties (legacy)
├── contents_controller.rb            # Content management
└── (additional specialized controllers)
```

### Key Features by Controller

#### **Users Controller** (`users_controller.rb`)
**Features:**
- List all users across all tenants (uses `.unscoped`)
- Search by email
- Filter by admin status (disabled due to no direct association)
- Create/edit/delete users
- No website filtering (noted as disabled)

**Notes:**
- Uses `Pwb::User.unscoped` for admin view (cross-tenant)
- Permits: `email`, `password`, `password_confirmation`, `admin`, `website_id`
- No current support for filtering by website (commented as "DISABLED")

#### **Websites Controller** (`websites_controller.rb`)
**Features:**
- List websites with search
- CRUD operations
- Website seeding with optional properties
- Provisioning retry logic
- Shows user count, property count, page count

**Advanced Features:**
- Calls `Pwb::ProvisioningService` for complex provisioning logic
- Integrates with seeders for data setup
- Supports website state transitions

#### **Subdomains Controller** (`subdomains_controller.rb`)
**Features:**
- Pool management with statistics (available, reserved, allocated, expired)
- Search/filter by state
- Create/edit/delete subdomains
- Release individual subdomains
- Bulk release expired reservations
- Populate subdomain pool (generator)
- Pending signups tracking (users with reserved subdomains)
- Pagination support

**Unique Features:**
- Shows pending signup data with reservation status
- Calculates expiration times
- Tracks which emails have reserved subdomains

#### **Website Admins Controller** (`website_admins_controller.rb`)
**Features:**
- List admins for a specific website
- Add users as admins to websites
- Remove admin status
- Creates/modifies UserMembership records with role='admin'

#### **Agencies Controller** (`agencies_controller.rb`)
**Features:**
- List all agencies
- Search by company name or display name
- Create/edit/delete agencies
- Link agencies to websites

#### **Auth Audit Logs Controller** (`auth_audit_logs_controller.rb`)
**Features:**
- View authentication events
- Filter by user
- Filter by IP address
- Event type visualization

---

## 2. Views Structure

### Views Hierarchy
```
app/views/tenant_admin/
├── layouts/
│   ├── _header.html.erb       # Top navigation
│   ├── _navigation.html.erb   # Sidebar navigation
│   └── _flash.html.erb        # Flash messages
├── users/
│   ├── index.html.erb         # User list with search
│   ├── show.html.erb          # Detailed user profile
│   ├── new.html.erb           # User creation form
│   ├── edit.html.erb          # User editing form
│   └── _form.html.erb         # Reusable form partial
├── websites/
│   ├── index.html.erb         # Website list
│   ├── show.html.erb          # Website details
│   ├── new.html.erb           # Website creation
│   ├── edit.html.erb          # Website editing
│   └── _form.html.erb         # Website form
├── subdomains/
│   ├── index.html.erb         # Subdomain pool with stats
│   ├── show.html.erb          # Subdomain details
│   ├── new.html.erb           # Add subdomain
│   ├── edit.html.erb          # Edit subdomain
│   └── _form.html.erb         # Subdomain form
├── website_admins/
│   └── index.html.erb         # Manage website admins
├── agencies/
├── auth_audit_logs/
├── domains/
├── email_templates/
└── (other resources)
```

### UI Technology Stack
- **Styling**: Tailwind CSS with responsive design
- **Icons**: SVG and Font Awesome
- **Forms**: Rails form helpers with Tailwind styling
- **Pagination**: Uses `pagy` gem with result counts

### Key Views Features

#### User Show View (`users/show.html.erb`)
Comprehensive user profile showing:
- **User Information**: Email, admin status, confirmation status, timestamps
- **Activity**: Sign-in count, current/last sign-in times and IPs
- **Website Memberships**: Table with:
  - Website link
  - Subdomain details
  - Custom domain
  - Role (owner/admin/member/viewer) with color coding
  - Membership status (active/inactive)
  - Join date
- **Pending Subdomain Reservations**: 
  - Shows subdomains reserved by email but not fully allocated
  - Tracks expiration dates
  - Indicates if reservation has expired

#### Subdomains Index View (`subdomains/index.html.erb`)
Displays:
- **Statistics Cards**: Total, available, reserved, allocated, expired reservations
- **Search/Filter**: By name or reserved email, state filtering
- **Pending Signups**: Separate section for incomplete signups

---

## 3. Subscription & Billing Models

### Pwb::Plan Model
**Location**: `app/models/pwb/plan.rb`

**Attributes**:
- `name`, `slug`, `display_name` (unique, indexed)
- `price_cents`, `price_currency`
- `billing_interval` (enum: month/year)
- `trial_days` (for trial duration)
- `property_limit` (nil for unlimited)
- `user_limit` (nil for unlimited)
- `features` (JSON array of feature keys)
- `active`, `public`, `position` (for ordering)

**Key Methods**:
- `has_feature?(feature_key)` - Check if feature enabled
- `enabled_features` - Get features with descriptions
- `unlimited_properties?` / `unlimited_users?`
- `formatted_price` - Display price with currency symbol
- `monthly_price_cents` - Calculate monthly equivalent
- `self.find_by_slug(slug)`
- `self.default_plan` - Get starter plan

**Feature Keys**:
```ruby
FEATURES = {
  basic_themes: 'Access to basic themes',
  premium_themes: 'Access to premium themes',
  analytics: 'Website analytics dashboard',
  custom_domain: 'Use your own custom domain',
  api_access: 'API access for integrations',
  white_label: 'Remove PropertyWebBuilder branding',
  priority_support: 'Priority email support',
  dedicated_support: 'Dedicated account manager'
}
```

**Associations**:
```ruby
has_many :subscriptions, dependent: :restrict_with_error
```

### Pwb::Subscription Model
**Location**: `app/models/pwb/subscription.rb`

**Status States** (AASM):
- `trialing` (initial) - Free trial period
- `active` - Paid subscription or post-trial
- `past_due` - Payment failed but grace period
- `canceled` - User canceled
- `expired` - Trial ended without payment or cancellation ended

**Attributes**:
- `status` (AASM state)
- `trial_ends_at` (DateTime)
- `current_period_starts_at`, `current_period_ends_at` (billing period)
- `canceled_at`, `cancel_at_period_end` (cancellation tracking)

**Key Methods**:
- `in_good_standing?` - trialing or active
- `allows_access?` - includes grace period (past_due)
- `trial_ended?`, `trial_days_remaining`, `trial_ending_soon?`
- `within_property_limit?(count)` / `within_user_limit?(count)`
- `remaining_properties` - Calculate remaining slots
- `has_feature?(feature_key)` - Delegate to plan
- `change_plan(new_plan)` - Switch to different plan
- `start_trial(days)` - Initialize trial

**State Transitions**:
- Trial → Active (via `activate`)
- Trial → Expired (via `expire_trial`)
- Active → Past Due (via `mark_past_due`)
- Any → Canceled (via `cancel`)
- Canceled/Expired → Active (via `reactivate`)

**Associations**:
```ruby
belongs_to :website
belongs_to :plan
has_many :events, class_name: 'Pwb::SubscriptionEvent', dependent: :destroy
```

### Pwb::SubscriptionEvent Model
**Location**: `app/models/pwb/subscription_event.rb`

**Attributes**:
- `event_type` (string) - Type of event (activated, trial_started, etc.)
- `metadata` (jsonb) - Additional event data

**Used For**: Audit trail of subscription changes

### Website Integration with Subscriptions
**Location**: `app/models/pwb/website.rb` (lines 782-852)

**Helper Methods**:
```ruby
def plan
  subscription&.plan
end

def has_active_subscription?
  subscription&.in_good_standing? || false
end

def in_trial?
  subscription&.trialing? || false
end

def trial_days_remaining
  subscription&.trial_days_remaining
end

def has_feature?(feature_key)
  subscription&.has_feature?(feature_key) || false
end

def can_add_property?
  return true unless subscription  # No subscription = no limits (legacy)
  subscription.within_property_limit?(realty_assets.count + 1)
end

def remaining_properties
  subscription&.remaining_properties
end

def property_limit
  plan&.property_limit
end
```

---

## 4. User Model

### Pwb::User Model
**Location**: `app/models/pwb/user.rb`

**Key Attributes**:
- `email` (unique, indexed)
- `encrypted_password` (Devise)
- `admin` (boolean) - Global platform admin flag
- `website_id` (optional FK for primary website)
- `onboarding_state` (AASM) - Signup flow tracking
- `onboarding_step`, `onboarding_started_at`, `onboarding_completed_at`
- `firebase_uid` - OAuth/Firebase authentication

**Devise Modules**:
```ruby
devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :trackable,
  :validatable, :lockable, :timeoutable,
  :omniauthable, omniauth_providers: [:facebook]
```

Provides: Email/password auth, registration, password reset, remember me, sign-in tracking, validation, account lockout, session timeout, OAuth (Facebook)

**Onboarding States** (AASM):
- `lead` (initial) - Just provided email
- `registered` - Account created but not verified
- `email_verified` - Email verified
- `onboarding` - Going through signup wizard
- `active` - Fully onboarded
- `churned` - Abandoned signup

**Key Associations**:
```ruby
belongs_to :website, optional: true
has_many :authorizations
has_many :auth_audit_logs, dependent: :destroy
has_many :user_memberships, dependent: :destroy
has_many :websites, through: :user_memberships
```

**Important Methods**:
- `admin_for?(website)` - Check if admin for specific website
- `role_for(website)` - Get role on website
- `accessible_websites` - Websites where user is active member
- `active_for_authentication?` - Devise hook for multi-website auth
- `can_access_website?(website)` - Verify website access
- `recent_auth_activity(limit)` - Get recent auth logs
- `suspicious_activity?(threshold, since)` - Detect failed logins

**Deletion Considerations**:
- Has `dependent: :destroy` on:
  - `user_memberships` - Cascades to remove all website relationships
  - `auth_audit_logs` - Cleans up authentication history
- **Does NOT have cascading delete on**: `authorizations` (OAuth providers)
- **Does NOT have cascading delete on**: `websites` (as primary owner)

---

## 5. Subdomain Model

### Pwb::Subdomain Model
**Location**: `app/models/pwb/subdomain.rb`

**States** (AASM):
- `available` (initial) - Available for reservation
- `reserved` - Reserved by user email for limited time
- `allocated` - Assigned to a website
- `released` - Released back to pool

**Key Attributes**:
- `name` (unique, lowercase alphanumeric + hyphens, 5-40 chars)
- `aasm_state` (state machine column)
- `website_id` (FK to allocated website, nullable)
- `reserved_by_email` (email that reserved it)
- `reserved_at`, `reserved_until` (reservation time window)

**Validations**:
- Name must be unique (case-insensitive)
- Format: lowercase, alphanumeric, hyphens only
- Length: 5-40 characters
- Cannot be in RESERVED_NAMES list
- Cannot be profane (via Obscenity gem)

**RESERVED_NAMES**:
```ruby
%w[www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test]
```

**State Transitions**:
```
available --reserve--> reserved --allocate--> allocated
                          ↓                       ↓
                      release              release/make_available
                          ↓                       ↓
                      released --make_available--> available
```

**Key Methods**:
- `self.reserve_for_email(email, duration)` - Auto-select random available, reserve
- `self.reserve_specific(name, email, duration)` - Reserve specific name
- `self.allocate_to_website(name_or_email, website)` - Allocate to website
- `self.release_expired!` - Release all expired reservations
- `self.name_available?(name)` - Check if available or doesn't exist

**Associations**:
```ruby
belongs_to :website, optional: true
```

**Pending Signup Tracking**:
In SubdomainsController, method `pending_signups_data`:
- Finds reserved subdomains with emails
- Matches to users
- Shows reservation expiry and completion status
- Indicates whether user has completed website creation

---

## 6. User Membership Model

### Pwb::UserMembership Model
**Location**: `app/models/pwb/user_membership.rb`

**Roles** (Hierarchical):
```ruby
ROLES = %w[owner admin member viewer]
# Hierarchy: owner (0) > admin (1) > member (2) > viewer (3)
```

**Key Attributes**:
- `role` (string enum)
- `active` (boolean) - Whether membership is currently active
- `user_id`, `website_id` (FKs)

**Validations**:
- User can only have one membership per website (unique: [:user_id, :website_id])
- Role must be valid
- Active must be boolean

**Key Methods**:
- `admin?` - Check if owner or admin
- `owner?` - Check if owner
- `active?` - Check if active
- `role_level` - Get numeric hierarchy level
- `can_manage?(other_membership)` - Check if can manage other member

**Scopes**:
- `active` - Where active = true
- `admins` - Where role in ['owner', 'admin']
- `owners` - Where role = 'owner'
- `for_website(website)` - Filter by website
- `for_user(user)` - Filter by user

**Associations**:
```ruby
belongs_to :user, class_name: 'Pwb::User'
belongs_to :website, class_name: 'Pwb::Website'
```

---

## 7. Website Model - Key Relationships

### Pwb::Website Model
**Location**: `app/models/pwb/website.rb`

**Multi-Tenancy Structure**:
```ruby
# Direct associations (owned by website)
has_many :users
has_many :pages
has_many :links
has_many :contacts
has_many :messages
has_many :email_templates, dependent: :destroy

# Multi-website membership support
has_many :user_memberships, dependent: :destroy
has_many :members, through: :user_memberships, source: :user

# Subscription
has_one :subscription, dependent: :destroy

# Subdomain allocation
has_one :allocated_subdomain, class_name: 'Pwb::Subdomain', foreign_key: 'website_id'

# Agency
has_one :agency, class_name: 'Pwb::Agency'
```

**Provisioning State Machine**:
States track website setup progress from pending → live:
- `pending` → `owner_assigned` → `agency_created` → `links_created`
- → `field_keys_created` → `properties_seeded` → `ready`
- → `locked_pending_email_verification` → `locked_pending_registration` → `live`

**Subdomain**:
- `subdomain` (virtual, stored via Subdomain model relationship)
- `custom_domain` (custom domain with verification)
- `custom_domain_verification_token`, `custom_domain_verified`

---

## 8. Deletion Impact Analysis

### If User is Deleted

**Direct Cascades** (destroyed):
1. **UserMemberships** - All website relationships removed
   - User no longer admin/member of any website
   - Website keeps data, just loses this user
2. **AuthAuditLogs** - Authentication history cleaned up

**What Remains**:
1. **Websites** - Remain intact, no cascade
   - If user was owner, website needs new owner (no enforce)
2. **Subdomains** (reserved) - With `reserved_by_email`
   - Not directly associated with user
   - Admin can still see pending signups
3. **Authorizations** - May remain (depends on dependent clause)
4. **Messages/Contacts** - Remain if created on websites

**Missing Protections**:
- No check if user is website owner (sole owner deletion risk)
- No validation of at least one active admin per website

### If Subdomain is Deleted

- Released back to deleted state
- Can be recovered via `make_available` state transition

### If Website is Deleted

**Direct Cascades** (dependent: :destroy):
1. **UserMemberships** - All users lose access
2. **Subscription** - Subscription deleted
3. **EmailTemplates** - All templates deleted
4. **Pages, Links, Contacts, Messages, etc** - All content deleted
5. **Allocated Subdomain** - Remains but loses website reference

### If Subscription is Deleted

- Website loses billing relationship
- But `has_active_subscription?` returns false, not error
- No protective checks prevent deletion

---

## 9. What Exists vs. What Needs Creation

### Already Exists ✅

#### Models
- ✅ User model with Devise and AASM onboarding
- ✅ UserMembership model with roles
- ✅ Website model with multi-tenancy
- ✅ Subdomain model with state machine
- ✅ Plan model with features
- ✅ Subscription model with state machine
- ✅ SubscriptionEvent model (audit trail)
- ✅ Agency model
- ✅ AuthAuditLog model

#### Admin Features
- ✅ User CRUD with search
- ✅ Website CRUD with seeding
- ✅ Subdomain pool management with statistics
- ✅ Website admins management
- ✅ Auth audit logs viewing
- ✅ Agency management

#### Billing/Subscription Features
- ✅ Plan model with features and limits
- ✅ Subscription status tracking (AASM)
- ✅ Trial management
- ✅ Property limits per plan
- ✅ Feature flags per plan
- ✅ Subscription event logging

### Needs Creation / Enhancement ❌

#### Admin Interface Features

1. **Subscription Management Console**
   - View all subscriptions and their status
   - Change plans for websites
   - View subscription history/events
   - Trigger manual events (activate, cancel, etc.)
   - Trial extension capability

2. **Plan Management**
   - Admin UI for creating/editing plans
   - Feature management UI
   - Pricing and limits configuration
   - Plan ordering/visibility toggle

3. **User Deletion with Safety Checks**
   - Check if sole owner of websites
   - Option to transfer ownership before deletion
   - Orphaned website handling strategy

4. **Website Ownership Management**
   - Change primary owner
   - Enforce minimum one active owner
   - Transfer all websites on user deletion

5. **Subdomain Management Enhancements**
   - Manual cleanup of expired reservations
   - Batch operations (release expired, populate pool)
   - Mapping view of subdomain to website/user

6. **Advanced Reporting**
   - Subscription dashboard (revenue, churn, trial-to-paid)
   - User activity reports
   - Website provisioning funnel
   - Feature usage analytics

#### Models/Database

1. **Subscription Webhooks** (for payment processor)
   - Handle incoming webhook events
   - Automatic status updates

2. **Plan Promotions** (optional enhancement)
   - Discount codes
   - Promotional pricing

3. **User Activity Tracking** (optional enhancement)
   - Last active date per website
   - Feature usage metrics

#### Tenant Admin Navigation

- Add Subscriptions section to sidebar
- Add Plans section to sidebar  
- Add Reports section to sidebar

---

## 10. Architecture Notes

### Multi-Tenancy Pattern

The app uses a **shared database** multi-tenancy model with tenant scoping:

1. **Websites are tenants** - Each website is a separate tenant
2. **Current website context** - Set via `Pwb::Current.website`
3. **Scoped queries** - Models use `current_website` for filtering
4. **Shared User Pool** - Users exist across tenants via memberships
5. **Global Admin** - Tenant admin uses `.unscoped` to see all data

### Authentication Context

- `TenantAdminController` provides global admin access
- Regular user routes scope to current website
- Users authenticated via Devise
- OAuth/Firebase support for public signup

### State Machine Usage

Multiple models use AASM for state tracking:
- **User.onboarding_state** - Signup flow
- **Website.provisioning_state** - Setup process
- **Subdomain.aasm_state** - Allocation lifecycle
- **Subscription.status** - Billing status

### Dependency Management

Key cascading deletes to consider:
- User → UserMemberships (cascade delete)
- Website → UserMemberships, Subscriptions, EmailTemplates, etc. (cascade delete)
- Plan → Subscriptions (restrict - can't delete if in use)

---

## 11. Recommended Next Steps

### High Priority
1. **Implement Subscription Management Console**
   - View/search subscriptions
   - Change plans manually
   - View subscription events
   
2. **Add Plan Management UI**
   - CRUD for plans
   - Feature assignment
   - Pricing configuration

3. **Enhance User Deletion Safety**
   - Check for sole website ownership
   - Add confirmation dialogs
   - Option to transfer ownership

### Medium Priority
1. **Add subscription dashboard** with KPIs
2. **Implement webhook handlers** for payment processor
3. **Add advanced filtering** to existing views
4. **Create subscription reporting** views

### Lower Priority
1. Feature usage analytics
2. Promotional code system
3. Advanced segmentation reports

---

## File Locations Reference

| Component | Location |
|-----------|----------|
| Users Controller | `app/controllers/tenant_admin/users_controller.rb` |
| Users Views | `app/views/tenant_admin/users/` |
| Websites Controller | `app/controllers/tenant_admin/websites_controller.rb` |
| Subdomains Controller | `app/controllers/tenant_admin/subdomains_controller.rb` |
| User Model | `app/models/pwb/user.rb` |
| User Membership Model | `app/models/pwb/user_membership.rb` |
| Website Model | `app/models/pwb/website.rb` |
| Subdomain Model | `app/models/pwb/subdomain.rb` |
| Subscription Model | `app/models/pwb/subscription.rb` |
| Plan Model | `app/models/pwb/plan.rb` |
| SubscriptionEvent Model | `app/models/pwb/subscription_event.rb` |
