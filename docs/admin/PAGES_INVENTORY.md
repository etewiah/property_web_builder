# PropertyWebBuilder Admin Pages Inventory

## Overview

PropertyWebBuilder has two main admin sections:

1. **Site Admin** (`/site_admin`) - Single website/tenant management dashboard
   - For managing properties, pages, settings of a specific website
   - Available to any logged-in user (authorization to be added in Phase 2)
   - Scope: Current website via SubdomainTenant concern

2. **Tenant Admin** (`/tenant_admin`) - Cross-tenant management dashboard
   - For system administrators managing multiple websites/tenants
   - Currently authentication-only (authorization in Phase 2)
   - Scope: All websites globally (unscoped)

## Screenshot Infrastructure

### Existing Scripts

- **`scripts/take-screenshots.js`** - Main screenshot capture script using Playwright
  - Captures pages across themes and viewports
  - Supports mobile (375x812), tablet (768x1024), and desktop (1440x900) viewports
  - Auto-compresses images to stay under 2MB using Sharp
  - Supports theme parameter for multi-theme comparison
  - Theme support: default, brisbane, bologna

- **`scripts/compress-screenshots.js`** - Standalone compression utility
  - Compresses PNG screenshots to configurable max size (default 2MB)
  - Resizes oversized images intelligently
  - Can convert to JPEG and back if needed
  - Supports per-theme compression

- **`scripts/take-screenshots-prod.js`** - Production variant (not yet examined)

### Screenshot Folder Structure

```
docs/screenshots/
├── README.md              # Documentation of screenshots
├── dec_23/               # Archived screenshots from Dec 2023
├── dec_24/               # Archived screenshots from Dec 2024
└── dev/                  # Current development screenshots
    ├── default/          # Default theme
    ├── brisbane/         # Brisbane theme
    └── bologna/          # Bologna theme
```

**Naming Convention**: `{page}-{viewport}.png`
- Pages: home, home-en, buy, rent, contact, about, property-sale, property-rent
- Viewports: desktop, tablet, mobile

## Site Admin Pages

Site admin is for managing a single website. All pages are scoped to `current_website`.

### Dashboard

- **Route**: `/site_admin`
- **Controller**: `SiteAdminController` (DashboardController)
- **View**: `dashboard/index.html.erb`
- **Purpose**: Overview of website statistics and recent activity
- **Data Shown**:
  - Total properties, pages, contents, messages, contacts
  - Recent activity (last 5 of each)
  - Subscription info (status, plan, trial days remaining, property limits)

### Properties Management

#### Properties List
- **Route**: `/site_admin/props`
- **Controller**: `PropsController#index`
- **View**: `props/index.html.erb`
- **Purpose**: Browse all properties with search/filtering
- **Features**:
  - Search by reference, title, address, city
  - Pagination (25 per page)
  - Action links to edit

#### Property Details
- **Route**: `/site_admin/props/:id`
- **Controller**: `PropsController#show`
- **View**: `props/show.html.erb`
- **Purpose**: View property details (read-only)

#### Property Edit - General
- **Route**: `/site_admin/props/:id/edit/general` (default)
- **Controller**: `PropsController#edit_general`
- **View**: `props/edit_general.html.erb`
- **Purpose**: Edit basic property info
- **Fields**: Reference, bedrooms, bathrooms, garages, toilets, plot area, built area, year, energy rating, address, postal code, city, region, country, coordinates

#### Property Edit - Text
- **Route**: `/site_admin/props/:id/edit/text`
- **Controller**: `PropsController#edit_text`
- **View**: `props/edit_text.html.erb`
- **Purpose**: Edit property titles and descriptions (sale & rental listings)

#### Property Edit - Sale & Rental
- **Route**: `/site_admin/props/:id/edit/sale_rental`
- **Controller**: `PropsController#edit_sale_rental`
- **View**: `props/edit_sale_rental.html.erb`
- **Purpose**: Manage listing status (visible, highlighted, archived), prices, furnished status

#### Property Edit - Location
- **Route**: `/site_admin/props/:id/edit/location`
- **Controller**: `PropsController#edit_location`
- **View**: `props/edit_location.html.erb`
- **Purpose**: Set property coordinates on map

#### Property Edit - Labels
- **Route**: `/site_admin/props/:id/edit/labels`
- **Controller**: `PropsController#edit_labels`
- **View**: `props/edit_labels.html.erb`
- **Purpose**: Manage property features/labels organized by category

#### Property Edit - Photos
- **Route**: `/site_admin/props/:id/edit/photos`
- **Controller**: `PropsController#edit_photos`
- **View**: `props/edit_photos.html.erb`
- **Purpose**: Upload, reorder, and remove property photos
- **Features**:
  - Drag-drop photo reordering
  - Supports file uploads or external URLs (external_image_mode)

#### Sale Listings (Nested)
- **Route**: `/site_admin/props/:id/sale_listings/new`
- **Route**: `/site_admin/props/:id/sale_listings/:listing_id/edit`
- **Controller**: `Props::SaleListingsController` (new, create, edit, update, destroy)
- **Views**: `props/sale_listings/new.html.erb`, `edit.html.erb`
- **Purpose**: Create/edit sale listings for a property

#### Rental Listings (Nested)
- **Route**: `/site_admin/props/:id/rental_listings/new`
- **Route**: `/site_admin/props/:id/rental_listings/:listing_id/edit`
- **Controller**: `Props::RentalListingsController` (new, create, edit, update, destroy)
- **Views**: `props/rental_listings/new.html.erb`, `edit.html.erb`
- **Purpose**: Create/edit rental listings for a property

### Pages Management

#### Pages List
- **Route**: `/site_admin/pages`
- **Controller**: `PagesController#index`
- **View**: `pages/index.html.erb`
- **Purpose**: Browse all website pages
- **Features**:
  - Search by slug
  - Pagination
  - Create, edit, delete actions

#### Page Details
- **Route**: `/site_admin/pages/:id`
- **Controller**: `PagesController#show`
- **View**: `pages/show.html.erb`
- **Purpose**: View page content (read-only)

#### Page Edit
- **Route**: `/site_admin/pages/:id/edit`
- **Controller**: `PagesController#edit`
- **View**: `pages/edit.html.erb`
- **Purpose**: Edit page and manage page parts
- **Features**:
  - Drag-drop page part reordering
  - Toggle page part visibility
  - Edit individual page parts inline or modal

#### Page Settings
- **Route**: `/site_admin/pages/:id/settings`
- **Controller**: `PagesController#settings`
- **View**: `pages/settings.html.erb`
- **Purpose**: Edit page metadata
- **Fields**: Slug, visibility, navigation settings, sort order

#### Page Parts (nested under pages)
- **Route**: `/site_admin/pages/:id/page_parts/:part_id`
- **Controller**: `Pages::PagePartsController#show`
- **View**: `pages/page_parts/show.html.erb`

- **Route**: `/site_admin/pages/:id/page_parts/:part_id/edit`
- **Controller**: `Pages::PagePartsController#edit`
- **View**: `pages/page_parts/edit.html.erb`
- **Purpose**: Edit page part content (full editor)

#### Page Parts List
- **Route**: `/site_admin/page_parts`
- **Controller**: `PagePartsController#index`
- **View**: `page_parts/index.html.erb`
- **Purpose**: Browse all page parts (read-only)

#### Page Part Details
- **Route**: `/site_admin/page_parts/:id`
- **Controller**: `PagePartsController#show`
- **View**: `page_parts/show.html.erb`
- **Purpose**: View page part (read-only)

### Content Management

#### Contents List
- **Route**: `/site_admin/contents`
- **Controller**: `ContentsController#index`
- **View**: `contents/index.html.erb`
- **Purpose**: Browse all website content (carousel, photos, text blocks, etc.)

#### Content Details
- **Route**: `/site_admin/contents/:id`
- **Controller**: `ContentsController#show`
- **View**: `contents/show.html.erb`
- **Purpose**: View content details (read-only)

### Email Templates

#### Email Templates List
- **Route**: `/site_admin/email_templates`
- **Controller**: `EmailTemplatesController#index`
- **View**: `email_templates/index.html.erb`
- **Purpose**: Manage custom email templates
- **Templates Available** (site admin only):
  - enquiry.general - General inquiry emails
  - enquiry.property - Property-specific inquiry emails

#### New Email Template
- **Route**: `/site_admin/email_templates/new?template_key=...`
- **Controller**: `EmailTemplatesController#new`
- **View**: `email_templates/new.html.erb`
- **Purpose**: Create new custom email template

#### Email Template Details
- **Route**: `/site_admin/email_templates/:id`
- **Controller**: `EmailTemplatesController#show`
- **View**: `email_templates/show.html.erb`
- **Purpose**: View template (read-only)

#### Email Template Edit
- **Route**: `/site_admin/email_templates/:id/edit`
- **Controller**: `EmailTemplatesController#edit`
- **View**: `email_templates/edit.html.erb`
- **Purpose**: Edit template HTML/text content and subject

#### Email Template Preview
- **Route**: `/site_admin/email_templates/:id/preview`
- **Controller**: `EmailTemplatesController#preview`
- **View**: `email_templates/preview.html.erb`
- **Purpose**: Preview rendered template with sample data

#### Email Template Preview Default
- **Route**: `/site_admin/email_templates/preview_default?template_key=...`
- **Controller**: `EmailTemplatesController#preview_default`
- **View**: `email_templates/preview_default.html.erb`
- **Purpose**: Preview default template before customizing

### Website Settings

#### Settings (All Tabs)
- **Route**: `/site_admin/website/settings`
- **Controller**: `Website::SettingsController#show`
- **View**: `website/settings/show.html.erb`
- **Purpose**: Tab-based settings interface with multiple sections

##### General Settings Tab
- **Tab Path**: `/site_admin/website/settings/general`
- **Fields**:
  - Company display name
  - Default client locale
  - Default currency
  - Default area unit
  - Supported locales (multi-select)
  - Analytics ID and ID type
  - External image mode toggle

##### Appearance Settings Tab
- **Tab Path**: `/site_admin/website/settings/appearance`
- **Fields**:
  - Theme selection
  - Style variables (CSS custom properties)
  - Custom CSS editor

##### Navigation Settings Tab
- **Tab Path**: `/site_admin/website/settings/navigation`
- **Features**:
  - Top navigation link management
  - Footer navigation link management
  - Drag-drop reordering
  - Toggle link visibility
  - Multilingual link titles

##### Home Page Settings Tab
- **Tab Path**: `/site_admin/website/settings/home`
- **Features**:
  - Homepage title (multilingual)
  - Display toggles (hide for-rent, hide for-sale, hide search bar)
  - Carousel content preview

##### Notifications Settings Tab
- **Tab Path**: `/site_admin/website/settings/notifications`
- **Features**:
  - Ntfy.sh integration configuration
  - Server URL, topic prefix, access token
  - Notification type toggles (inquiries, listings, users, security)
  - Test notification button

### Properties Settings (Configuration)

- **Route**: `/site_admin/properties/settings`
- **Controller**: `Properties::SettingsController#index`
- **View**: `properties/settings/index.html.erb`
- **Purpose**: Configure property field options
- **Categories Managed**:
  - Property types
  - Property states (condition)
  - Property features/amenities
  - etc.

#### Properties Settings Category
- **Route**: `/site_admin/properties/settings/:category`
- **Controller**: `Properties::SettingsController#show`
- **View**: `properties/settings/show.html.erb`
- **Purpose**: View/manage options for a specific category

### Storage Statistics

- **Route**: `/site_admin/storage_stats`
- **Controller**: `StorageStatsController#show`
- **View**: `storage_stats/show.html.erb`
- **Purpose**: View storage usage and manage orphaned files
- **Features**:
  - Storage usage breakdown
  - Orphan file detection
  - Cleanup button

### Analytics Dashboard

#### Analytics Overview
- **Route**: `/site_admin/analytics`
- **Controller**: `AnalyticsController#show`
- **View**: `analytics/show.html.erb`
- **Purpose**: Overview dashboard with key metrics
- **Data**:
  - Visits overview
  - Visits by day chart
  - Traffic sources breakdown
  - Device breakdown

#### Analytics - Traffic
- **Route**: `/site_admin/analytics/traffic`
- **Controller**: `AnalyticsController#traffic`
- **View**: `analytics/traffic.html.erb`
- **Purpose**: Detailed traffic analysis
- **Data**:
  - Visits by day
  - Visitors by day
  - Traffic sources
  - UTM campaigns
  - Geographic data

#### Analytics - Properties
- **Route**: `/site_admin/analytics/properties`
- **Controller**: `AnalyticsController#properties`
- **View**: `analytics/properties.html.erb`
- **Purpose**: Property engagement metrics
- **Data**:
  - Top properties by views
  - Property views by day
  - Top searches

#### Analytics - Conversions
- **Route**: `/site_admin/analytics/conversions`
- **Controller**: `AnalyticsController#conversions`
- **View**: `analytics/conversions.html.erb`
- **Purpose**: Inquiry funnel and conversion tracking
- **Data**:
  - Inquiry funnel breakdown
  - Conversion rates
  - Inquiries by day

#### Analytics - Realtime
- **Route**: `/site_admin/analytics/realtime`
- **Controller**: `AnalyticsController#realtime`
- **View**: `analytics/realtime.html.erb`
- **Purpose**: Real-time visitor tracking
- **Data**:
  - Active visitors count
  - Recent page views
  - Live updates (JSON endpoint available)

### Users

#### Users List
- **Route**: `/site_admin/users`
- **Controller**: `UsersController#index`
- **View**: `users/index.html.erb`
- **Purpose**: Browse website users

#### User Details
- **Route**: `/site_admin/users/:id`
- **Controller**: `UsersController#show`
- **View**: `users/show.html.erb`
- **Purpose**: View user profile (read-only)

### Messages & Contacts

#### Messages List
- **Route**: `/site_admin/messages`
- **Controller**: `MessagesController#index`
- **View**: `messages/index.html.erb`
- **Purpose**: Browse contact form messages

#### Message Details
- **Route**: `/site_admin/messages/:id`
- **Controller**: `MessagesController#show`
- **View**: `messages/show.html.erb`
- **Purpose**: View message details (read-only)

#### Contacts List
- **Route**: `/site_admin/contacts`
- **Controller**: `ContactsController#index`
- **View**: `contacts/index.html.erb`
- **Purpose**: Browse contact inquiries

#### Contact Details
- **Route**: `/site_admin/contacts/:id`
- **Controller**: `ContactsController#show`
- **View**: `contacts/show.html.erb`
- **Purpose**: View inquiry details (read-only)

### Domain Management

- **Route**: `/site_admin/domain`
- **Controller**: `DomainsController#show`
- **View**: `domains/show.html.erb`
- **Purpose**: Manage custom domain configuration
- **Actions**:
  - Update domain
  - Verify domain ownership

### Onboarding Wizard

#### Welcome Step
- **Route**: `/site_admin/onboarding` or `/site_admin/onboarding/1`
- **Controller**: `OnboardingController#show`
- **View**: `onboarding/welcome.html.erb`
- **Step**: 1/5

#### Profile Step
- **Route**: `/site_admin/onboarding/2`
- **Controller**: `OnboardingController#show`
- **View**: `onboarding/profile.html.erb`
- **Purpose**: Setup company/agency details
- **Step**: 2/5

#### Property Step
- **Route**: `/site_admin/onboarding/3`
- **Controller**: `OnboardingController#show`
- **View**: `onboarding/property.html.erb`
- **Purpose**: Add first property (optional, can skip)
- **Step**: 3/5

#### Theme Step
- **Route**: `/site_admin/onboarding/4`
- **Controller**: `OnboardingController#show`
- **View**: `onboarding/theme.html.erb`
- **Purpose**: Choose and customize theme
- **Step**: 4/5

#### Complete Step
- **Route**: `/site_admin/onboarding/5` or `/site_admin/onboarding/complete`
- **Controller**: `OnboardingController#complete`
- **View**: `onboarding/complete.html.erb`
- **Purpose**: Summary and next steps
- **Step**: 5/5

---

## Tenant Admin Pages

Tenant admin is for system administrators managing multiple websites. All pages are unscoped (access all data).

### Dashboard

- **Route**: `/tenant_admin`
- **Controller**: `TenantAdminController` (DashboardController)
- **View**: `dashboard/index.html.erb`
- **Purpose**: System overview with cross-tenant statistics
- **Data Shown**:
  - Total websites, users, properties
  - Active tenants (updated in last 30 days)
  - Recent websites, users, properties, messages
  - Subscription statistics (total, active, trialing, past due, canceled, expiring soon)
  - Plan statistics
  - Subscriptions expiring soon

### Websites Management

#### Websites List
- **Route**: `/tenant_admin/websites`
- **Controller**: `WebsitesController#index`
- **View**: `websites/index.html.erb`
- **Purpose**: Browse all websites
- **Features**:
  - Search by subdomain or company name
  - Pagination (20 per page)
  - Create, show, edit, delete actions

#### Website Details
- **Route**: `/tenant_admin/websites/:id`
- **Controller**: `WebsitesController#show`
- **View**: `websites/show.html.erb`
- **Purpose**: View website details and stats
- **Stats Shown**:
  - Properties count
  - Pages count

#### New Website
- **Route**: `/tenant_admin/websites/new`
- **Controller**: `WebsitesController#new`
- **View**: `websites/new.html.erb`
- **Purpose**: Create new website/tenant
- **Options**:
  - Seed data checkbox
  - Skip property seeding checkbox

#### Website Edit
- **Route**: `/tenant_admin/websites/:id/edit`
- **Controller**: `WebsitesController#edit`
- **View**: `websites/edit.html.erb`
- **Purpose**: Edit website configuration
- **Fields**:
  - Subdomain
  - Company display name
  - Theme name
  - Default currency, area unit, locale
  - Analytics ID and type
  - Custom CSS
  - Landing page visibility toggles
  - Supported locales

#### Website Seed Data
- **Route**: `/tenant_admin/websites/:id/seed` (POST)
- **Controller**: `WebsitesController#seed`
- **Purpose**: Populate website with demo/seed data

#### Website Retry Provisioning
- **Route**: `/tenant_admin/websites/:id/retry_provisioning` (POST)
- **Controller**: `WebsitesController#retry_provisioning`
- **Purpose**: Retry provisioning for failed websites

### Users Management

#### Users List
- **Route**: `/tenant_admin/users`
- **Controller**: `UsersController#index`
- **View**: `users/index.html.erb`
- **Purpose**: Browse all system users
- **Features**:
  - Search by email
  - Filter by admin status
  - Pagination

#### User Details
- **Route**: `/tenant_admin/users/:id`
- **Controller**: `UsersController#show`
- **View**: `users/show.html.erb`
- **Purpose**: View user details (read-only)

#### New User
- **Route**: `/tenant_admin/users/new`
- **Controller**: `UsersController#new`
- **View**: `users/new.html.erb`
- **Purpose**: Create new user

#### User Edit
- **Route**: `/tenant_admin/users/:id/edit`
- **Controller**: `UsersController#edit`
- **View**: `users/edit.html.erb`
- **Purpose**: Edit user email, password, admin status

#### Transfer User Ownership
- **Route**: `/tenant_admin/users/:id/transfer_ownership` (POST)
- **Controller**: `UsersController#transfer_ownership`
- **Purpose**: Transfer website ownership to another user

### Subscription Management

#### Subscriptions List
- **Route**: `/tenant_admin/subscriptions`
- **Controller**: `SubscriptionsController#index`
- **View**: `subscriptions/index.html.erb`
- **Purpose**: Browse all subscriptions
- **Features**:
  - Filter by status (active, trialing, past due, canceled)
  - Filter by plan
  - Search by website subdomain
  - Pagination (20 per page)
  - Subscription statistics cards

#### Subscription Details
- **Route**: `/tenant_admin/subscriptions/:id`
- **Controller**: `SubscriptionsController#show`
- **View**: `subscriptions/show.html.erb`
- **Purpose**: View subscription details and event history
- **Data**:
  - Plan information
  - Trial/billing period dates
  - Recent events (last 20)

#### New Subscription
- **Route**: `/tenant_admin/subscriptions/new`
- **Controller**: `SubscriptionsController#new`
- **View**: `subscriptions/new.html.erb`
- **Purpose**: Create new subscription for a website

#### Subscription Edit
- **Route**: `/tenant_admin/subscriptions/:id/edit`
- **Controller**: `SubscriptionsController#edit`
- **View**: `subscriptions/edit.html.erb`
- **Purpose**: Edit subscription details

#### Subscription Activate
- **Route**: `/tenant_admin/subscriptions/:id/activate` (POST)
- **Controller**: `SubscriptionsController#activate`
- **Purpose**: Manually activate a subscription

#### Subscription Cancel
- **Route**: `/tenant_admin/subscriptions/:id/cancel` (POST)
- **Controller**: `SubscriptionsController#cancel`
- **Purpose**: Manually cancel a subscription

#### Subscription Change Plan
- **Route**: `/tenant_admin/subscriptions/:id/change_plan` (POST)
- **Controller**: `SubscriptionsController#change_plan`
- **Purpose**: Change subscription to different plan

#### Expire Trials (Bulk)
- **Route**: `/tenant_admin/subscriptions/expire_trials` (POST)
- **Controller**: `SubscriptionsController#expire_trials`
- **Purpose**: Expire all trial subscriptions that have ended

### Plans Management

#### Plans List
- **Route**: `/tenant_admin/plans`
- **Controller**: `PlansController#index`
- **View**: `plans/index.html.erb`
- **Purpose**: Browse all plans
- **Features**:
  - Filter by active status
  - Search by name or display name
  - Plan statistics cards

#### Plan Details
- **Route**: `/tenant_admin/plans/:id`
- **Controller**: `PlansController#show`
- **View**: `plans/show.html.erb`
- **Purpose**: View plan details
- **Data Shown**:
  - Plan features
  - Recent subscriptions on this plan (last 10)

#### New Plan
- **Route**: `/tenant_admin/plans/new`
- **Controller**: `PlansController#new`
- **View**: `plans/new.html.erb`
- **Purpose**: Create new subscription plan

#### Plan Edit
- **Route**: `/tenant_admin/plans/:id/edit`
- **Controller**: `PlansController#edit`
- **View**: `plans/edit.html.erb`
- **Purpose**: Edit plan details
- **Fields**:
  - Name and slug
  - Display name and description
  - Price and currency
  - Billing interval
  - Trial days
  - Property/user limits
  - Active/public status
  - Features list
  - Position (sort order)

#### Delete Plan
- **Route**: `/tenant_admin/plans/:id/delete` (POST)
- **Controller**: `PlansController#destroy`
- **Purpose**: Delete plan (only if no active subscriptions)

### Email Templates (Cross-Tenant)

#### Email Templates List
- **Route**: `/tenant_admin/email_templates`
- **Controller**: `EmailTemplatesController#index`
- **View**: `email_templates/index.html.erb`
- **Purpose**: Manage global email templates
- **Templates Available**:
  - enquiry.general, enquiry.property - Inquiry templates
  - alert.* - Alert templates
  - user.* - User notification templates
  - (site admin only has enquiry.* access)

#### Template Details, Edit, Preview, etc.
- Similar routes and views as site admin version but global scope

### Domains Management

#### Domains List
- **Route**: `/tenant_admin/domains`
- **Controller**: `DomainsController#index`
- **View**: `domains/index.html.erb`
- **Purpose**: Browse custom domains across all websites
- **Features**:
  - Filter by verification status (verified, pending)
  - Search by domain or subdomain
  - Statistics cards
  - Preview of websites without domains

#### Domain Details
- **Route**: `/tenant_admin/domains/:id`
- **Controller**: `DomainsController#show`
- **View**: `domains/show.html.erb`
- **Purpose**: View domain details

#### Edit Domain
- **Route**: `/tenant_admin/domains/:id/edit`
- **Controller**: `DomainsController#edit`
- **View**: `domains/edit.html.erb`
- **Purpose**: Update custom domain
- **Fields**:
  - Custom domain name
  - DNS verification token (auto-generated)

#### Verify Domain
- **Route**: `/tenant_admin/domains/:id/verify` (POST)
- **Controller**: `DomainsController#verify`
- **Purpose**: Trigger DNS verification

#### Remove Domain
- **Route**: `/tenant_admin/domains/:id/remove` (DELETE)
- **Controller**: `DomainsController#remove`
- **Purpose**: Remove custom domain from website

### Subdomains Management

#### Subdomains List
- **Route**: `/tenant_admin/subdomains`
- **Controller**: `SubdomainsController#index`
- **View**: `subdomains/index.html.erb`
- **Purpose**: Manage subdomain pool for signup system
- **Features**:
  - Filter by state (available, reserved, allocated)
  - Search by name or email
  - Statistics cards showing state breakdown
  - Pending signups preview

#### Subdomain Details
- **Route**: `/tenant_admin/subdomains/:id`
- **Controller**: `SubdomainsController#show`
- **View**: `subdomains/show.html.erb`
- **Purpose**: View subdomain details

#### New Subdomain
- **Route**: `/tenant_admin/subdomains/new`
- **Controller**: `SubdomainsController#new`
- **View**: `subdomains/new.html.erb`
- **Purpose**: Create new subdomain

#### Edit Subdomain
- **Route**: `/tenant_admin/subdomains/:id/edit`
- **Controller**: `SubdomainsController#edit`
- **View**: `subdomains/edit.html.erb`
- **Purpose**: Edit subdomain state

#### Release Subdomain
- **Route**: `/tenant_admin/subdomains/:id/release` (POST)
- **Controller**: `SubdomainsController#release`
- **Purpose**: Release reserved/allocated subdomain back to available pool

#### Release Expired Reservations (Bulk)
- **Route**: `/tenant_admin/subdomains/release_expired` (POST)
- **Controller**: `SubdomainsController#release_expired`
- **Purpose**: Release all expired reservation holds

#### Populate Subdomain Pool
- **Route**: `/tenant_admin/subdomains/populate` (POST)
- **Controller**: `SubdomainsController#populate`
- **Purpose**: Generate new random subdomains to fill pool

### Authentication Audit Logs

#### Audit Logs List
- **Route**: `/tenant_admin/auth_audit_logs`
- **Controller**: `AuthAuditLogsController#index`
- **View**: `auth_audit_logs/index.html.erb`
- **Purpose**: Security audit trail of all authentication events
- **Features**:
  - Filter by event type (login, logout, failed login, etc.)
  - Filter by email or IP address
  - Filter by user ID
  - Filter by date range
  - Pagination (50 per page)
  - Security statistics cards

#### Audit Log Details
- **Route**: `/tenant_admin/auth_audit_logs/:id`
- **Controller**: `AuthAuditLogsController#show`
- **View**: `auth_audit_logs/show.html.erb`
- **Purpose**: View specific audit log entry
- **Data**:
  - Event details (type, email, IP, timestamp)
  - Related logs (same email/IP) for context

#### User Login History
- **Route**: `/tenant_admin/auth_audit_logs/user/:user_id` (GET)
- **Controller**: `AuthAuditLogsController#user_logs`
- **View**: `auth_audit_logs/user_logs.html.erb`
- **Purpose**: View login history for specific user

#### IP Login History
- **Route**: `/tenant_admin/auth_audit_logs/ip/:ip` (GET)
- **Controller**: `AuthAuditLogsController#ip_logs`
- **View**: `auth_audit_logs/ip_logs.html.erb`
- **Purpose**: View login history from specific IP address
- **Data**:
  - All logs from that IP
  - Failure count for suspicious activity detection

### Agencies Management

#### Agencies List
- **Route**: `/tenant_admin/agencies`
- **Controller**: `AgenciesController#index`
- **View**: `agencies/index.html.erb`
- **Purpose**: Browse all agencies
- **Features**:
  - Search by company name or display name

#### Agency Details
- **Route**: `/tenant_admin/agencies/:id`
- **Controller**: `AgenciesController#show`
- **View**: `agencies/show.html.erb`
- **Purpose**: View agency details (read-only)

#### New Agency
- **Route**: `/tenant_admin/agencies/new`
- **Controller**: `AgenciesController#new`
- **View**: `agencies/new.html.erb`
- **Purpose**: Create new agency

#### Edit Agency
- **Route**: `/tenant_admin/agencies/:id/edit`
- **Controller**: `AgenciesController#edit`
- **View**: `agencies/edit.html.erb`
- **Purpose**: Edit agency details

### Data Views (Read-Only)

These pages provide views into tenant-scoped data (from a specific website):

#### Pages (in context of a website)
- **Route**: `/tenant_admin/websites/:website_id/pages`
- **Controller**: `PagesController#index`
- **View**: `pages/index.html.erb`

#### Page Details
- **Route**: `/tenant_admin/websites/:website_id/pages/:id`
- **Controller**: `PagesController#show`

#### Properties
- **Route**: `/tenant_admin/props`
- **Controller**: `PropsController#index`

#### Property Details
- **Route**: `/tenant_admin/props/:id`
- **Controller**: `PropsController#show`

#### Messages
- **Route**: `/tenant_admin/messages`
- **Controller**: `MessagesController#index`

#### Message Details
- **Route**: `/tenant_admin/messages/:id`
- **Controller**: `MessagesController#show`

#### Contacts
- **Route**: `/tenant_admin/contacts`
- **Controller**: `ContactsController#index`

#### Contact Details
- **Route**: `/tenant_admin/contacts/:id`
- **Controller**: `ContactsController#show`

#### Page Parts
- **Route**: `/tenant_admin/page_parts`
- **Controller**: `PagePartsController#index`

#### Page Part Details
- **Route**: `/tenant_admin/page_parts/:id`
- **Controller**: `PagePartsController#show`

#### Contents
- **Route**: `/tenant_admin/contents`
- **Controller**: `ContentsController#index`

#### Content Details
- **Route**: `/tenant_admin/contents/:id`
- **Controller**: `ContentsController#show`

---

## Summary Statistics

### Site Admin Page Groups
- **Dashboard**: 1 page
- **Properties Management**: 11 pages (list, show, 6 edit views, 2 nested listing types)
- **Pages Management**: 7 pages (list, show, edit, settings, page parts management)
- **Content Management**: 2 pages (list, show)
- **Email Templates**: 5 pages (list, new, show, edit, preview variants)
- **Website Settings**: 5 tab pages (general, appearance, navigation, home, notifications)
- **Properties Settings**: 2 pages (index, category view)
- **Storage Statistics**: 1 page
- **Analytics Dashboard**: 5 pages (overview, traffic, properties, conversions, realtime)
- **Users/Messages/Contacts**: 6 pages (users list/show, messages list/show, contacts list/show)
- **Domain Management**: 1 page
- **Onboarding Wizard**: 5 steps

**Total Site Admin Pages: ~56 pages**

### Tenant Admin Page Groups
- **Dashboard**: 1 page
- **Websites Management**: 4 pages (list, show, new, edit)
- **Users Management**: 4 pages (list, show, new, edit)
- **Subscriptions Management**: 7 pages (list, show, new, edit)
- **Plans Management**: 5 pages (list, show, new, edit)
- **Email Templates**: 5 pages (global scope)
- **Domains Management**: 4 pages (list, show, edit)
- **Subdomains Management**: 5 pages (list, show, new, edit)
- **Authentication Audit Logs**: 4 pages (list, show, user_logs, ip_logs)
- **Agencies Management**: 4 pages (list, show, new, edit)
- **Data Views**: 10 pages (read-only views into website data)

**Total Tenant Admin Pages: ~53 pages**

**Grand Total: ~109 admin pages** (excluding API and non-page actions like POST-only endpoints)

---

## Pages Most Useful for Documentation Screenshots

Priority for screenshot capture (documentation value):

### High Priority (Core admin functionality)

**Site Admin**:
1. Dashboard - Shows what users see first
2. Properties List - Most used admin page
3. Property Edit (General) - Most common editing task
4. Pages List - Page management interface
5. Website Settings (General tab) - Key configuration
6. Website Settings (Appearance tab) - Theme customization
7. Email Templates List - Email customization
8. Analytics Dashboard - Key feature for users
9. Onboarding (Welcome, Profile, Theme) - User journey

**Tenant Admin**:
1. Dashboard - System overview
2. Websites List - Core management
3. Subscriptions List - Business critical
4. Plans List - Configuration
5. Users List - User management
6. Auth Audit Logs - Security feature

### Medium Priority

- Property photos/labels editing
- Page parts editing
- Navigation settings
- Domain management
- Email template preview
- Property search/filter interface

### Lower Priority (Rarely accessed)

- Storage statistics
- Individual read-only detail pages
- Audit log filtering views
- API/non-page actions

---

## Notes

### Page Rendering Patterns

All admin pages use:
- **ERB templates** in `app/views/site_admin/` and `app/views/tenant_admin/`
- **Tailwind CSS** for styling
- **Stimulus.js** for interactive elements
- **Pagy** gem for pagination (with `:items` parameter customizable)

### Missing Admin Pages (Not Yet Implemented)

- Website-specific user roles/permissions UI
- Advanced analytics/reporting
- Email campaign management
- Bulk import/export UI
- Theme builder/customizer UI (separate from settings)
