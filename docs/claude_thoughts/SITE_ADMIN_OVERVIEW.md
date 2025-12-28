# Site Admin Section - Comprehensive Overview

## Overview

The Site Admin section is the core management dashboard for PropertyWebBuilder users. It provides a comprehensive interface for managing properties, content, communications, users, website settings, and analytics for a specific website/tenant. The section is:

- **Multi-tenant aware**: Uses SubdomainTenant to isolate data by website
- **Role-based**: Requires admin or owner role for the current website
- **Feature-rich**: Manages properties, pages, messaging, users, analytics, and more
- **Accessible**: Includes guided tour system and mobile-responsive design

## Directory Structure

```
app/
├── controllers/site_admin/
│   ├── site_admin_controller.rb (base controller)
│   ├── dashboard_controller.rb
│   ├── props_controller.rb (properties)
│   ├── property_import_export_controller.rb
│   ├── pages_controller.rb
│   ├── page_parts_controller.rb
│   ├── messages_controller.rb
│   ├── contacts_controller.rb
│   ├── users_controller.rb
│   ├── activity_logs_controller.rb
│   ├── analytics_controller.rb
│   ├── domains_controller.rb
│   ├── billing_controller.rb
│   ├── agency_controller.rb
│   ├── email_templates_controller.rb
│   ├── onboarding_controller.rb
│   ├── media_library_controller.rb
│   ├── website/
│   │   └── settings_controller.rb
│   ├── pages/ (nested resources)
│   ├── properties/ (nested resources)
│   └── props/ (nested resources)
│
└── views/site_admin/
    ├── layouts/site_admin.html.erb (main layout)
    ├── layouts/site_admin/
    │   ├── _navigation.html.erb (sidebar nav)
    │   ├── _header.html.erb (top header)
    │   └── _flash.html.erb (alerts)
    ├── dashboard/
    ├── props/ (property management)
    ├── pages/ (page management)
    ├── messages/ (message inbox)
    ├── contacts/ (contact database)
    ├── users/ (team management)
    ├── analytics/ (visitor analytics)
    ├── website/ (website settings)
    ├── onboarding/ (setup wizard)
    └── [other feature directories]
```

## Main Layout & Navigation

### Layout File: `site_admin.html.erb`

The main layout provides:
- **Page structure**: Flex layout with sidebar navigation and main content area
- **CDN libraries**: Alpine.js, Flowbite, Chart.js, Shepherd.js (tour guide)
- **Mobile responsiveness**: Collapsible sidebar with mobile menu button
- **Guided tour**: Shepherd.js integration for first-time user onboarding

### Layout Components

#### 1. Header (`_header.html.erb`)
- Displays website information ("Managing: [subdomain]")
- Mobile menu toggle button
- User dropdown (View Site, Sign Out)
- Responsive design (h-16 height, hidden text on mobile)

#### 2. Navigation Sidebar (`_navigation.html.erb`)
- **Fixed position** on desktop, slide-out on mobile
- **Collapsible sections** with localStorage persistence:
  - Content Management
  - Communication
  - Insights
  - User Management
  - Website Settings
- **Tour IDs**: Each navigation item has `id="tour-[feature]"` for guided tour

#### 3. Flash Messages (`_flash.html.erb`)
- Success/notice alerts with green checkmark
- Error/alert messages with red X icon
- Info messages with info icon
- Consistent styling across the app

---

## Main Sections & Features

### 1. Dashboard (Home)
**Controller**: `DashboardController#index`  
**Route**: `/site_admin/`  
**View**: `dashboard/index.html.erb`

Shows an overview of the website with:

#### Statistics Cards
- Total Properties (with property limit if applicable)
- Total Pages
- Total Messages
- Total Contacts
- Total Contents

#### Subscription Status
- Plan name and pricing
- Status badge (Active, Trial, Past Due, Canceled, Expired)
- Property usage and limits
- Trial period countdown with warnings
- Plan features list
- Access status indicator

#### Recent Activity Widgets
- **Recent Properties**: 5 most recently created properties with links
- **Recent Messages**: 5 most recent customer inquiries
- **Recent Contacts**: 5 newest contact database entries

**Key Data**:
- Scoped by `current_website&.id` for multi-tenant isolation
- Uses `Pwb::ListedProperty` materialized view for optimized property counts
- Displays subscription info from `Pwb::Subscription`
- Shows trial days remaining and warnings

---

### 2. Properties (Content Management → Properties)
**Controller**: `PropsController`  
**Routes**:
- `GET /site_admin/props` → index (list properties)
- `GET /site_admin/props/new` → new (create property)
- `POST /site_admin/props` → create
- `GET /site_admin/props/:id` → show (view property details)
- `GET /site_admin/props/:id/edit_general` → edit_general (edit basic info)
- `GET /site_admin/props/:id/edit_text` → edit_text (edit descriptions)
- `GET /site_admin/props/:id/edit_sale_rental` → edit_sale_rental
- `GET /site_admin/props/:id/edit_location` → edit_location
- `GET /site_admin/props/:id/edit_labels` → edit_labels (features/tags)
- `GET /site_admin/props/:id/edit_photos` → edit_photos
- `POST /site_admin/props/:id/upload_photos` → upload_photos
- `DELETE /site_admin/props/:id/remove_photo` → remove_photo
- `PATCH /site_admin/props/:id/reorder_photos` → reorder_photos
- `PATCH /site_admin/props/:id` → update

#### Features
- **Search**: Search by reference, title, street address, city
- **Pagination**: 25 properties per page
- **Multi-step editing**: Properties broken into logical sections:
  - General (reference, type, bedrooms, bathrooms, etc.)
  - Text (descriptions and SEO content per locale)
  - Sale/Rental (pricing, visibility, furnished status)
  - Location (address, coordinates, mapping)
  - Labels (features/categories for property)
  - Photos (upload, reorder, delete photos)
- **Dual data models**:
  - `Pwb::ListedProperty` (materialized view) for fast reads/listing
  - `Pwb::RealtyAsset` (main table) for writes/updates
- **Transaction handling**: Updates use transactions for consistency
- **External image support**: Can use external URLs for images instead of uploads

---

### 3. Property Import/Export
**Controller**: `PropertyImportExportController`  
**Route**: `/site_admin/property_import_export`  
**View**: `property_import_export/index.html.erb`

Bulk import/export capabilities for properties.

---

### 4. Property Settings (Labels)
**Controller**: `SiteAdmin::PropsController#edit_labels`  
**Route**: `/site_admin/properties/settings`  
**View**: `properties/settings/`

Manage property field keys and labels organized by category:
- Property types
- Property states
- Features/amenities
- Custom labels

---

### 5. Pages (Content Management → Pages)
**Controller**: `PagesController`  
**Routes**:
- `GET /site_admin/pages` → index
- `GET /site_admin/pages/:id` → show
- `GET /site_admin/pages/:id/edit` → edit (edit page parts with drag-drop)
- `PATCH /site_admin/pages/:id` → update
- `GET /site_admin/pages/:id/settings` → settings
- `PATCH /site_admin/pages/:id/settings` → update_settings
- `POST /site_admin/pages/:id/reorder_parts` → reorder_parts

#### Features
- **Page creation/editing**: Manage content pages (About, Services, etc.)
- **Page parts**: Drag-drop ordering of page sections
- **Visibility controls**: Show/hide in navigation, set sort order
- **Search**: Search by page slug
- **Metadata**: Slug, visibility in top nav/footer, sort order

---

### 6. Media Library (Content Management → Media Library)
**Controller**: `MediaLibraryController`  
**Route**: `/site_admin/media_library`  
**Views**:
- `media_library/index.html.erb`
- `media_library/folders.html.erb`
- `media_library/show.html.erb`
- `media_library/new.html.erb`
- `media_library/edit.html.erb`

Centralized media management for images and files.

---

### 7. Messages (Communication → Messages)
**Controller**: `MessagesController`  
**Routes**:
- `GET /site_admin/messages` → index
- `GET /site_admin/messages/:id` → show

#### Features
- Uses `SiteAdminIndexable` mixin for index functionality
- **Search**: By origin email or message content
- **Limit**: 100 messages per page
- Shows inquiries from website contact forms
- Website-scoped with `Pwb::Message` model

---

### 8. Contacts (Communication → Contacts)
**Controller**: `ContactsController`  
**Routes**:
- `GET /site_admin/contacts` → index
- `GET /site_admin/contacts/:id` → show

#### Features
- Uses `SiteAdminIndexable` mixin
- **Search**: By email, first name, last name
- **Limit**: 100 contacts per page
- Contact database from form submissions
- Website-scoped with `Pwb::Contact` model

---

### 9. Email Templates (Communication → Email Templates)
**Controller**: `EmailTemplatesController`  
**Routes**:
- `GET /site_admin/email_templates` → index
- `GET /site_admin/email_templates/new` → new
- `POST /site_admin/email_templates` → create
- `GET /site_admin/email_templates/:id` → show
- `GET /site_admin/email_templates/:id/edit` → edit
- `PATCH /site_admin/email_templates/:id` → update
- `DELETE /site_admin/email_templates/:id` → destroy
- `GET /site_admin/email_templates/:id/preview` → preview
- `GET /site_admin/email_templates/preview_default` → preview_default

#### Features
- **Template management**: Customize inquiry email templates
- **Allowed templates**: Only enquiry-related templates (enquiry.general, enquiry.property)
- **Preview**: See rendered template with sample data
- **Default templates**: Pre-populated defaults available
- **Variable system**: Email templates support variables like {{website_name}}, {{visitor_name}}, etc.

---

### 10. Users (User Management → Users)
**Controller**: `UsersController`  
**Routes**:
- `GET /site_admin/users` → index
- `GET /site_admin/users/new` → new
- `POST /site_admin/users` → create
- `GET /site_admin/users/:id` → show
- `GET /site_admin/users/:id/edit` → edit
- `PATCH /site_admin/users/:id` → update
- `DELETE /site_admin/users/:id` → destroy
- `POST /site_admin/users/:id/resend_invitation` → resend_invitation
- `PATCH /site_admin/users/:id/role` → update_role
- `PATCH /site_admin/users/:id/deactivate` → deactivate
- `PATCH /site_admin/users/:id/reactivate` → reactivate

#### Features
- **Team management**: Invite users and manage permissions
- **Roles**: owner, admin, member
- **Membership**: Users can be members of multiple websites
- **Activation**: Can activate/deactivate team members
- **Search**: By email
- **Permissions**: Only admins can manage users, can't manage users with equal/higher roles

#### User Flow
1. Create new user by email (existing user gets membership, new user gets invitation)
2. Assign role to user (owner, admin, member)
3. Edit user profile (first/last name, phone)
4. Deactivate/reactivate access
5. Remove user from team

---

### 11. Activity Logs (User Management → Activity Logs)
**Controller**: `ActivityLogsController`  
**Route**: `/site_admin/activity_logs`

#### Features
- **Security audit log**: Tracks authentication events
- **Filters**: By event type, user, date range (1h, 24h, 7d, 30d)
- **Stats**: Today's logins, failures, unique IPs
- **Event types**: login_success, login_failure, logout, etc.
- **Pagination**: 50 logs per page

---

### 12. Analytics (Insights → Analytics)
**Controller**: `AnalyticsController`  
**Routes**:
- `GET /site_admin/analytics` → show (overview)
- `GET /site_admin/analytics/traffic` → traffic
- `GET /site_admin/analytics/properties` → properties
- `GET /site_admin/analytics/conversions` → conversions
- `GET /site_admin/analytics/realtime` → realtime

#### Features
- **Feature gating**: Requires analytics feature in plan
- **Period selection**: 7, 14, 30, 60, 90 days
- **Overview**: Visits, visitors, traffic sources, device breakdown
- **Traffic**: Daily visits/visitors, traffic sources, UTM campaigns, geography
- **Properties**: Top properties, property views, popular searches
- **Conversions**: Inquiry funnel, conversion rates, inquiries by day
- **Real-time**: Active visitors, recent pageviews (JSON API)
- **Charts**: Chart.js integration via Chartkick

**Service**: `Pwb::AnalyticsService` (encapsulates analytics logic)

---

### 13. Website Settings
**Controller**: `SiteAdmin::Website::SettingsController`  
**Routes**:
- `GET /site_admin/website/settings` → show (default to general tab)
- `GET /site_admin/website/settings/:tab` → show
- `PATCH /site_admin/website/settings/:tab` → update

#### Tabs & Settings

##### General Tab
- Company display name
- Default client locale and currency
- Supported locales (multi-language)
- Area unit preference
- Analytics ID and type
- External image mode (use URLs vs. uploads)

##### Appearance Tab
- Theme selection (from `Pwb::Theme.all`)
- Color palette/style variables
- Dark mode setting
- Custom CSS

##### Home Tab
- Home page title
- Carousel content management
- Display toggles:
  - Hide "For Rent" section
  - Hide "For Sale" section
  - Hide search bar

##### Navigation Tab
- Top navigation links
- Footer links
- Link titles, visibility, sort order
- Multi-language title support (via Mobility)

##### Notifications Tab
- Ntfy.sh integration
- Server URL, topic prefix, access token
- Notification types:
  - Notify inquiries
  - Notify listings
  - Notify users
  - Notify security

##### SEO Tab
- Default SEO title
- Default meta description
- Favicon URL
- Main logo URL
- Social media metadata

##### Social Tab
- Social media links (Facebook, Twitter, Instagram, LinkedIn, etc.)
- URLs for each platform

---

### 14. Agency Profile
**Controller**: `AgencyController`  
**Route**: `/site_admin/agency`  
**View**: `agency/edit.html.erb`

Edit company/agency information:
- Display name
- Email address
- Phone number
- Company name

---

### 15. Billing
**Controller**: `BillingController`  
**Route**: `/site_admin/billing`  
**View**: `billing/show.html.erb`

Display subscription and usage information:
- Current plan details
- Property usage and limits
- User usage and limits
- Pricing information

---

### 16. Domain Management
**Controller**: `DomainsController`  
**Routes**:
- `GET /site_admin/domain` → show
- `PATCH /site_admin/domain` → update
- `POST /site_admin/domain/verify` → verify

#### Features
- **Custom domain setup**: Attach custom domain to website
- **DNS verification**: TXT record verification for domain ownership
- **Platform domains**: List of available platform domains
- **Verification token**: Auto-generated for domain ownership proof
- **Verification status**: Track verification state and timestamp

---

### 17. Onboarding (Setup Wizard)
**Controller**: `OnboardingController`  
**Routes**:
- `GET /site_admin/onboarding` → show (current step)
- `GET /site_admin/onboarding/:step` → show (specific step)
- `POST /site_admin/onboarding/:step` → update
- `POST /site_admin/onboarding/:step/skip` → skip_step
- `GET /site_admin/onboarding/complete` → complete
- `POST /site_admin/onboarding/restart` → restart

#### Steps
1. **Welcome**: Introduction to the platform
2. **Profile**: Set up agency details and default currency
3. **Property**: Add first property (optional, can skip)
4. **Theme**: Choose website theme
5. **Complete**: Summary of setup

#### Features
- **Step tracking**: User's onboarding progress stored on `current_user`
- **Completion marker**: `site_admin_onboarding_completed_at` timestamp
- **Skip logic**: Only property step is skippable
- **Restart**: Users can restart the wizard
- **Progress indicator**: Visual progress bar

---

## Navigation Structure

### Sidebar Navigation (Alpine.js/Collapse)
The navigation uses Alpine.js with localStorage persistence for collapsed/expanded states:

```
Dashboard
  └─ Dashboard (home link)

Content Management
  ├─ Properties (list/manage)
  ├─ Import/Export
  ├─ Labels (property settings)
  ├─ Pages (content pages)
  └─ Media Library

Communication
  ├─ Messages (inbox)
  ├─ Contacts (database)
  └─ Email Templates

Insights
  └─ Analytics (traffic, properties, conversions, realtime)

User Management
  ├─ Users (team members)
  └─ Activity Logs (security audit)

Website
  ├─ Appearance (theme, styling)
  ├─ SEO (meta tags, social)
  ├─ Settings (general, notifications, navigation, home)
  ├─ Agency Profile
  ├─ Billing (subscription info)
  ├─ Domain (custom domain setup)
  ├─ Setup Wizard (onboarding)
  └─ View Site (external link to public site)

Take a Tour (button - starts guided tour)
```

---

## Guided Tour System

### Technology
- **Library**: Shepherd.js
- **Triggers**: Manual via "Take a Tour" button (not automatic)
- **Storage**: localStorage for completion tracking

### Tour Steps
The tour guides users through major sections with highlighted elements:

1. Welcome
2. Dashboard
3. Properties
4. Labels
5. Pages
6. Messages
7. Contacts
8. Users
9. Website Settings
10. Domain
11. View Site
12. Take a Tour (button)

Each step has:
- Title
- Description text
- Target element (tour IDs on nav items)
- Navigation (Previous/Next/Skip/Finish buttons)

---

## Key Architecture Decisions

### Multi-Tenancy
- **Scoping**: All queries scoped by `website_id: current_website&.id`
- **Tenant context**: `SubdomainTenant` concern sets `Pwb::Current.website`
- **acts_as_tenant**: All `PwbTenant::` models auto-scoped via `ActsAsTenant` gem
- **Request isolation**: Each subdomain is a separate tenant

### Authentication & Authorization
- **Devise**: User authentication
- **Admin check**: `require_admin!` before_action (skippable with `BYPASS_ADMIN_AUTH=true` for testing)
- **Role-based**: Admin/owner roles required for site_admin
- **User membership**: Users can have different roles on different websites

### Data Models Used
- `Pwb::Website` - The website/tenant
- `Pwb::RealtyAsset` - Properties (write operations)
- `Pwb::ListedProperty` - Properties view (optimized reads)
- `Pwb::Page` - Website pages
- `Pwb::PagePart` - Page sections/components
- `Pwb::Message` - Customer inquiries
- `Pwb::Contact` - Contact database
- `Pwb::User` - Team members
- `Pwb::UserMembership` - User-website relationships
- `Pwb::Subscription` - Plan/billing
- `Pwb::EmailTemplate` - Customizable email templates
- `PwbTenant::FieldKey` - Property labels and categories
- `Pwb::AuthAuditLog` - Security audit trail

### Responsive Design
- **Layout**: Flex with sidebar + main content
- **Mobile**: Collapsible sidebar, hidden labels
- **Breakpoints**: md (768px) is primary breakpoint
- **CSS Framework**: Tailwind CSS (no Bootstrap)

### Performance
- **Pagination**: Pagy gem, typical 25-100 items per page
- **Eager loading**: Explicit loading of related records to avoid N+1
- **Views**: Materialized views (ListedProperty) for complex queries
- **Caching**: localStorage for nav state, no server-side caching shown

### Flash Messages
Four types with icons:
- Success (green checkmark)
- Error (red X)
- Alert (orange warning)
- Info (blue info icon)

---

## Key Controllers Base Class

**SiteAdminController** provides:
- Tenant isolation via `SubdomainTenant`
- Admin authorization via `require_admin!`
- Helper method `current_website`
- 404 error handling with custom page
- Layout: `site_admin.html.erb`
- Pagy pagination support

---

## Frontend Technologies

- **HTML/ERB**: Server-rendered templates
- **CSS**: Tailwind CSS (compiled per theme)
- **JavaScript**: 
  - Alpine.js (navigation collapse, interactive components)
  - Flowbite (UI components library)
  - Chart.js (analytics charts)
  - Shepherd.js (guided tour)
  - Chartkick (chart helper)
- **HTTP**: Turbo/Turbolinks for fast navigation
- **Forms**: Standard Rails form helpers

---

## Common Patterns

### Indexable Mixin Pattern
Used by Messages and Contacts controllers:

```ruby
include SiteAdminIndexable

indexable_config model: Pwb::Message,
                 search_columns: %i[origin_email content],
                 limit: 100
```

Provides automatic index action with search and pagination.

### Nested Resources
Some resources have nested routes under their parent:
- Properties have nested page parts
- Pages have page parts

### Transaction Handling
Multi-step updates (like property editing) use transactions:

```ruby
ActiveRecord::Base.transaction do
  @prop.update!(asset_params)
  sale_listing.update!(sale_listing_params)
  rental_listing.update!(rental_listing_params)
end
```

### View/Materialized View Pattern
Properties use two models:
- Read: `Pwb::ListedProperty` (view for optimized queries)
- Write: `Pwb::RealtyAsset` (actual table)

---

## Feature Flags & Gating

### Analytics
Behind feature gate: Only available on paid plans with "analytics" feature.

```ruby
def check_analytics_feature
  return if analytics_enabled?
  redirect_to site_admin_root_path, alert: "Analytics requires a paid plan"
end
```

### Email Templates
Limited to enquiry-related templates in site_admin:
- enquiry.general
- enquiry.property

(Other templates managed in tenant_admin)

---

## Developer Notes

### Locale Support
Website supports multi-language content:
- `supported_locales` array on website
- `default_client_locale` for preferred language
- Mobility gem for translated fields
- Locale-specific rendering in templates

### Area Units
Configurable area measurement units:
- Square meters
- Square feet
- Other custom units

### Currency Support
Multiple currencies supported:
- `default_currency` on website
- `Pwb::Config::CURRENCIES` for valid values
- Price fields stored in cents

### Custom CSS
Raw CSS support in appearance settings:
- `raw_css` field on website
- Loaded in theme templates
- Allows custom styling beyond theme

---

## Summary Table

| Section | Controller | Routes | Key Features |
|---------|-----------|--------|--------------|
| Dashboard | DashboardController | /site_admin/ | Stats, subscription, recent activity |
| Properties | PropsController | /site_admin/props/* | CRUD, photos, multi-step editing |
| Pages | PagesController | /site_admin/pages/* | Manage content pages, drag-drop parts |
| Messages | MessagesController | /site_admin/messages/* | Message inbox, search |
| Contacts | ContactsController | /site_admin/contacts/* | Contact database, search |
| Users | UsersController | /site_admin/users/* | Team management, roles, invites |
| Analytics | AnalyticsController | /site_admin/analytics* | Traffic, properties, conversions, realtime |
| Website Settings | Website::SettingsController | /site_admin/website/settings* | Multi-tab configuration |
| Domain | DomainsController | /site_admin/domain* | Custom domain setup, verification |
| Billing | BillingController | /site_admin/billing | Subscription info, usage |
| Onboarding | OnboardingController | /site_admin/onboarding* | Setup wizard, 5 steps |
| Email Templates | EmailTemplatesController | /site_admin/email_templates* | Customize inquiry emails |
| Activity Logs | ActivityLogsController | /site_admin/activity_logs* | Security audit trail |
| Agency | AgencyController | /site_admin/agency* | Company profile |

---

## Next Steps for Enhancement

1. **Add missing views**: Some features exist in controllers but views not shown
2. **Expand properties subdirectory**: Details on pages and props nested resources
3. **Email template variables documentation**: Complete variable reference
4. **Analytics API**: Details on JSON endpoints for real-time data
5. **Theme customization**: How themes work and what can be customized
6. **Localization examples**: How multi-language content is managed

