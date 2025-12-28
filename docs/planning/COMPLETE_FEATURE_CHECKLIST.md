# PropertyWebBuilder Complete Feature Checklist

**Date**: December 28, 2025  
**Purpose**: Comprehensive inventory of all features, grouped by category  
**Format**: Checklist with status, location, and notes

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Fully implemented, production-ready |
| ⚠️ | Partially implemented or in progress |
| ❌ | Not implemented |
| 🔨 | Framework exists, needs setup/configuration |
| 💡 | Possible with custom code |
| 📌 | Documented in `/docs/` folder |

---

## 1. ADMIN INTERFACE

### 1.1 Dashboard & Navigation
- ✅ Site admin dashboard (`/site_admin`)
  - Location: `app/controllers/site_admin/`
  - Features: Key metrics, recent activity, subscription info
- ✅ Tenant admin dashboard (`/tenant_admin`)
  - Location: `app/controllers/tenant_admin/`
  - Features: Cross-tenant management, website seeding
- ✅ Onboarding wizard
  - Location: `concerns/site_admin_onboarding.rb`
  - Features: Step-by-step setup, skip options, completion tracking
- ✅ Guided tour
  - Features: Tutorial for new users

### 1.2 Navigation & Settings
- ✅ Top navigation management
- ✅ Footer navigation management
- ✅ Breadcrumb navigation
- ✅ Mobile navigation (responsive)
- ✅ Settings page (`/site_admin/website/settings`)
- ✅ Help/support links

### 1.3 Admin Features
- ✅ Activity logs
  - Location: `site_admin/activity_logs_controller.rb`
  - Model: `Pwb::ActivityLog`
- ✅ Auth audit logs
  - Location: `tenant_admin/auth_audit_logs_controller.rb`
  - Model: `Pwb::AuthAuditLog`
  - Features: IP tracking, user agent, event types
- ✅ Tour completion tracking
- ✅ Onboarding progress tracking

---

## 2. PROPERTY MANAGEMENT

### 2.1 Core Property Features
- ✅ Property CRUD (Create, Read, Update, Delete)
  - Location: `site_admin/props_controller.rb`
  - Model: `PwbTenant::Prop`, `Pwb::RealtyAsset`
  - Schema: 50+ attributes
- ✅ Property listing view
  - Search by reference, title, address, city
  - Pagination (25 per page)
  - Quick actions
- ✅ Property creation
  - Tabbed interface with sections:
    - General (bedrooms, bathrooms, area, etc.)
    - Text (descriptions, titles, SEO)
    - Sale/Rental (pricing, status)
    - Location (address, GPS)
    - Features (labels, amenities)
    - Photos (upload, order, delete)
- ✅ Property editing (multi-section)
  - Location: `site_admin/props#edit_general`, `edit_text`, etc.
- ✅ Property deletion (soft delete)

### 2.2 Property Attributes
- ✅ Reference/ID
- ✅ Title (multi-language)
- ✅ Description (multi-language)
- ✅ Property type (configurable via field keys)
- ✅ Bedrooms count
- ✅ Bathrooms count
- ✅ Toilets count
- ✅ Garages count
- ✅ Plot area (sqm/sqft)
- ✅ Constructed area (sqm/sqft)
- ✅ Year of construction
- ✅ Energy rating & performance
- ✅ Furnished flag
- ✅ Street address
- ✅ Postal code
- ✅ City
- ✅ Region
- ✅ Country
- ✅ Latitude & Longitude (GPS)
- ✅ Property state (configurable)
- ✅ Property origin (configurable)

### 2.3 Sale Listing Features
- ✅ For sale flag
- ✅ Sale price
- ✅ Original price
- ✅ Currency selection
- ✅ Commission amount
- ✅ Service charges
- ✅ Commission type
- ✅ Sale title (multi-language)
- ✅ Sale description (multi-language)
- ✅ SEO title (multi-language)
- ✅ Meta description (multi-language)
- ✅ Visibility toggle
- ✅ Highlighted flag
- ✅ Archive/unarchive
- ✅ Reserved flag
- ✅ Sold flag
- ✅ Activate/deactivate listing

### 2.4 Rental Listing Features
- ✅ For rent flag
- ✅ Monthly rental price
- ✅ Low season price
- ✅ High season price
- ✅ Standard season price
- ✅ Currency selection
- ✅ Rental title (multi-language)
- ✅ Rental description (multi-language)
- ✅ SEO title (multi-language)
- ✅ Meta description (multi-language)
- ✅ Short-term rental flag
- ✅ Long-term rental flag
- ✅ Availability dates
- ✅ Visibility toggle
- ✅ Highlighted flag
- ✅ Archive/unarchive
- ✅ Activate/deactivate listing

### 2.5 Property Photos
- ✅ Multiple photos per property
- ✅ Photo upload (batch)
- ✅ External photo URLs (if enabled)
- ✅ Photo ordering (drag-drop)
- ✅ Photo deletion
- ✅ Photo descriptions
- ✅ Photo variants (thumbnails, etc.)
- ✅ Photo limit enforcement
- ✅ Batch operations
- Location: `site_admin/props#upload_photos`, `remove_photo`, `reorder_photos`

### 2.6 Property Features/Labels
- ✅ Configurable features system
  - Location: `models/pwb_tenant/feature.rb`
- ✅ Feature key-based organization
- ✅ Multi-language feature names
- ✅ Feature visibility control
- ✅ Property feature assignments
- ✅ Predefined categories:
  - Property types (apartment, house, villa, etc.)
  - Amenities (AC, heating, dishwasher, etc.)
  - Features (pool, terrace, garden, etc.)
  - Status (new, renovated, needs update)
  - Highlights (luxury, investment, etc.)

### 2.7 Property Import/Export
- ✅ CSV import
  - Location: `site_admin/property_import_export_controller.rb`
  - Features: Field mapping, template download, dry-run
  - Supported fields: reference, address, city, property type, pricing, etc.
- ✅ CSV export
  - Options: Include inactive, include archived
- ✅ MLS import (TSV format)
  - Location: `pwb/import/mls_controller.rb`
  - Note: Basic import only, no auto-sync
- ✅ Template download
- ✅ Import results/error logging
- ✅ Update existing by reference

### 2.8 Property Search (Frontend)
- ✅ For sale search (`/buy`)
- ✅ For rent search (`/rent`)
- ✅ AJAX-based filtering
- ✅ Advanced filters:
  - Property type
  - Price range
  - Bedrooms/bathrooms
  - Location/city
  - Property state
  - Furnished status
  - Highlighted properties
- ✅ Real-time results
- ✅ URL-based search parameters (bookmarkable)
- ✅ Materialized view optimization (ListedProperty)
- ❌ Saved searches
- ❌ Email alerts for new properties
- ❌ Search suggestions/autocomplete

### 2.9 Property Display
- ✅ Property detail page
- ✅ Photo gallery
- ✅ Price display
- ✅ Specs display
- ✅ Location/map
- ✅ Features list
- ✅ Multi-language titles/descriptions
- ✅ Contact form on property page
- ✅ Social sharing buttons
- ⚠️ Open Graph/Twitter Card meta tags (framework exists)
- ❌ Image alt-text management

---

## 3. CONTENT MANAGEMENT

### 3.1 Pages
- ✅ Page CRUD
  - Location: `site_admin/pages_controller.rb`
  - Model: `PwbTenant::Page`
- ✅ Page listing view
- ✅ Page creation
- ✅ Page editing
  - Tabbed interface
  - General settings
  - Parts/blocks management
  - Reordering
- ✅ Page deletion
- ✅ Custom page slugs
- ✅ Page visibility controls
- ✅ Navigation integration (top/footer)
- ✅ Page titles (multi-language)
- ✅ Page descriptions (meta)
- ✅ Link titles for navigation
- ✅ Metadata storage
- ❌ Scheduled publishing
- ❌ Revision history
- ❌ Collaborative editing

### 3.2 Page Parts (Content Blocks)
- ✅ 20+ pre-built templates
  - Location: `app/views/pwb/page_parts/`
  - Categories:
    - Heroes (banner sections)
    - Features (feature lists)
    - Testimonials (quotes)
    - CTAs (calls-to-action)
    - Stats (statistics)
    - Teams (team members)
    - Galleries (image galleries)
    - FAQs (Q&A)
    - Pricing (tables)
    - And more...
- ✅ Page part management
  - Location: `site_admin/pages/page_parts_controller.rb`
- ✅ Custom page part creation
- ✅ Theme-aware page parts
- ✅ Locale-specific templates
- ✅ Block visibility toggles
- ✅ Block reordering
- ✅ Block editing
- ✅ Liquid template support
- ✅ In-context editing support

### 3.3 Content Blocks (Web Contents)
- ✅ Content CRUD
  - Location: `site_admin/contents_controller.rb`
  - Model: `PwbTenant::Content`
- ✅ Content listing view
- ✅ Content creation
- ✅ Content editing
- ✅ Content deletion
- ✅ Content photos
  - Model: `Pwb::ContentPhoto`
  - Features: Upload, ordering, deletion
- ✅ Tag-based organization
  - Tags: carousel, logos, testimonials, etc.
- ✅ Sort ordering
- ✅ Multi-language support
- ✅ JSONB data storage

### 3.4 In-Context Editor
- ✅ Frontend editing (`/edit` routes)
  - Location: `pwb/editor_controller.rb`
- ✅ Page editing from frontend
- ✅ Page parts editing from frontend
- ✅ Theme settings customization
- ✅ Image library integration
- ✅ Inline saving
- ✅ Visual feedback
- ⚠️ Partial implementation noted in docs

### 3.5 Media Library
- ✅ Media listing view
  - Location: `site_admin/media_library_controller.rb`
- ✅ Media upload
- ✅ Hierarchical folders
  - Model: `Pwb::MediaFolder`
- ✅ Folder management (create, update, delete)
- ✅ File browsing
- ✅ Media deletion
- ✅ Bulk operations
  - Bulk delete
  - Bulk move
- ✅ Media metadata
  - Dimensions, checksums, content type, usage count
- ✅ Image variants (thumbnail, small, medium, large)
- ✅ Usage tracking
- ✅ Last used timestamp
- ✅ Folder tree view
- Location: `site_admin/media_library_controller.rb`

---

## 4. TRANSLATIONS & LOCALIZATION

### 4.1 Multi-Language Support
- ✅ 7 languages built-in
  - en, es, de, fr, nl, pt, it
- ✅ Configurable per website
- ✅ Default locale selection
- ✅ Locale-based URL routing
  - Format: `/:locale/page/...`
- ✅ Admin locale preference per user
- ✅ Client locale preference per user
- ✅ Language fallback chain
  - All languages → English

### 4.2 Translation System (Mobility)
- ✅ JSONB-backed translations
  - Column: `translations` (jsonb)
  - Models: All CMS models
- ✅ Container backend (single column)
- ✅ Auto-generated accessors
  - Example: `title_en`, `title_es`, `title_de`
- ✅ Translation management
  - Location: Models use Mobility
- ✅ GIN indexing for performance
- ✅ Fallback mechanism

### 4.3 Translatable Models
- ✅ Property (title, description, SEO title, meta description)
- ✅ Page (title, link_title, slug)
- ✅ Content (title, description)
- ✅ PagePart (description)
- ✅ PageContent (description)
- ✅ Link (title, url)
- ✅ Feature (name)
- ✅ FieldKey (name, description)
- ✅ Agency (company_name, display_name)
- ✅ User (preferred_language preference stored)

### 4.4 Translation Management
- ✅ Translation editing per model
- ✅ Bulk translation operations
  - Location: `api_public/v1/translations_controller.rb`
- ✅ Translation export
  - Location: `pwb/export/translations_controller.rb`
- ✅ Translation import
  - Location: `pwb/import/translations_controller.rb`
- ✅ FieldKey translation system
  - Dynamic translation keys for dropdowns
  - Per-website configuration

### 4.5 Multi-Currency Support
- ✅ Money gem integration
- ✅ Currency per website
- ✅ User currency preference
- ✅ Admin currency preference
- ✅ Price display in multiple currencies
- ✅ Exchange rates support
- ✅ Currency symbols per locale

---

## 5. USER MANAGEMENT & AUTHENTICATION

### 5.1 Authentication Methods
- ✅ Email/password (Devise)
  - Location: `pwb/devise/` controllers
- ✅ Firebase authentication
  - Location: `pwb/firebase_login_controller.rb`
  - Features: Email, password via Firebase
- ✅ OAuth (Facebook)
  - Location: `pwb/devise/omniauth_callbacks_controller.rb`
- ✅ OmniAuth integration (extensible)

### 5.2 User Model
- ✅ Email (unique)
- ✅ Password (encrypted via Devise)
- ✅ First name
- ✅ Last name
- ✅ Skype handle
- ✅ Phone number
- ✅ Preferred language/locale
- ✅ Preferred currency
- ✅ Firebase UID
- ✅ Account lockout after failed attempts
- ✅ Sign-in tracking
  - Current/last sign-in timestamps
  - Current/last sign-in IP
  - Sign-in count

### 5.3 User Roles & Access
- ✅ Multi-website support (UserMembership)
  - Location: `Pwb::UserMembership`
  - Features: One user, multiple websites, different roles
- ✅ Role-based access per website
  - Roles: owner, admin, member
- ✅ Active/inactive membership
- ✅ User activation/deactivation
- ✅ User invitation system
  - Resend invitations
- ✅ Role updates
- ✅ Role-based dashboard access
- ⚠️ Authorization system in progress (noted in code)

### 5.4 Security Features
- ✅ Password encryption (Devise)
- ✅ Account lockout
- ✅ Session timeout
- ✅ Remember-me cookie
- ✅ CSRF protection
- ✅ Recaptcha support (configurable per website)
- ✅ Failed login tracking
- ✅ IP address tracking
- ⚠️ Two-factor authentication (Firebase capable but not UI)

### 5.5 Audit Logging
- ✅ Auth audit logs
  - Location: `Pwb::AuthAuditLog`
  - Features:
    - Event types: login, logout, registration, failed_login, password_reset, etc.
    - IP address logging
    - User agent logging
    - Request path
    - Failure reasons
    - Metadata storage
- ✅ Queryable by user, IP, event type, date range
- ✅ Cross-tenant visibility (tenant admin)
- ✅ Detailed timestamp tracking
- Location: `tenant_admin/auth_audit_logs_controller.rb`

### 5.6 User Management (Admin)
- ✅ User listing
  - Location: `site_admin/users_controller.rb`
  - Scoped per website
- ✅ User creation
- ✅ User editing
- ✅ User deletion
- ✅ Resend invitation
- ✅ Update role
- ✅ Deactivate/reactivate users
- ✅ User detail view
- Location: `site_admin/users_controller.rb`

---

## 6. CONTACTS & LEAD MANAGEMENT

### 6.1 Contact Model
- ✅ Contact CRUD
  - Location: `Pwb::Contact`, `PwbTenant::Contact`
- ✅ Contact listing
  - Location: `site_admin/contacts_controller.rb`
- ✅ Contact details
  - First name
  - Last name
  - Title (Mr., Mrs., etc.)
  - Email (primary & secondary)
  - Phone (primary & secondary)
  - Skype ID
  - Facebook ID
  - LinkedIn ID
  - Twitter ID
  - Website URL
  - Nationality
  - Documentation ID
  - Address components
  - Contact status flags
- ✅ Contact deletion
- ✅ Contact history

### 6.2 Message/Inquiry Model
- ✅ Message CRUD
  - Location: `Pwb::Message`, `PwbTenant::Message`
- ✅ Message listing
  - Location: `site_admin/messages_controller.rb`
- ✅ Inquiry storage
  - Model: `Pwb::Message`
- ✅ Message details
  - Sender information
  - Message content
  - Origin IP
  - User agent
  - Timestamp
  - Locale
  - Associated property (optional)
  - Associated contact
- ✅ Message deletion
- ✅ Delivery status tracking
  - Status: sent, delivered, failed, bounced
- ✅ Delivery email logging

### 6.3 Forms
- ✅ Contact form
  - Location: `/contact-us`
  - Features: Name, email, phone, message
  - Recipient configurable in settings
- ✅ Property inquiry form
  - Features: On property detail page
  - Sends inquiry to admin
- ✅ Recaptcha protection (optional)
- ✅ Email notifications to admin
- ✅ Inquiry delivery status tracking

### 6.4 CRM Features (Current)
- ✅ Contact database
- ✅ Lead capture
- ✅ Email storage
- ✅ Phone tracking
- ✅ Address management
- ✅ Social media handles storage
- ✅ Documentation tracking
- ✅ Custom details (JSONB)
- ✅ Basic activity tracking (inquiries/messages)
- ❌ Lead scoring
- ❌ Lead qualification workflow
- ❌ Sales pipeline/Kanban view
- ❌ Task assignment
- ❌ Email integration
- ❌ Activity timeline
- ❌ Bulk actions

### 6.5 CRM Integrations
- ❌ HubSpot integration
- ❌ Salesforce integration
- ❌ Pipedrive integration
- 💡 Custom API integration possible

---

## 7. EMAIL MANAGEMENT

### 7.1 Email Templates
- ✅ Email template CRUD
  - Location: `site_admin/email_templates_controller.rb`
  - Cross-tenant: `tenant_admin/email_templates_controller.rb`
- ✅ Template customization
  - Model: `Pwb::EmailTemplate`
- ✅ Template preview
- ✅ Default templates
- ✅ Custom templates per website
- ✅ Template variables/placeholders
- ✅ Multi-language support
- Location: `models/pwb/email_template.rb`

### 7.2 Email Notifications
- ✅ User registration confirmations
- ✅ Password reset emails
- ✅ Contact form notifications
- ✅ Property inquiry notifications
- ✅ Custom recipient configuration
  - General contact form recipient
  - Property inquiry form recipient
  - Admin notifications
- ✅ Delivery tracking
- ✅ Error logging
- ✗ No scheduled/automated emails
- ✗ No drip campaigns
- ✗ No newsletter system

### 7.3 Email Services
- 🔨 Generic mailer support (Rails configured)
- 🔨 Sendgrid/Mailgun integration (via config)
- ❌ Mailchimp/Brevo integration
- ❌ HubSpot email integration
- Location: `app/mailers/`

---

## 8. ANALYTICS & REPORTING

### 8.1 Visitor Tracking
- ✅ Ahoy analytics gem integrated
  - Location: `app/models/ahoy/`
  - Models: `Ahoy::Visit`, `Ahoy::Event`
- ✅ Visit tracking per website
- ✅ Visitor identification
  - Unique visitor tokens
  - User association (optional)
- ✅ Session tracking
- ✅ Geolocation tracking
  - Country, region, city
- ✅ Device tracking
  - Device type (desktop, mobile, tablet)
  - Browser
  - OS
- ✅ Traffic source tracking
  - Referrer domain
  - Landing page
  - UTM parameters (source, medium, campaign, content, term)

### 8.2 Analytics Dashboard
- ✅ Analytics dashboard
  - Location: `site_admin/analytics_controller.rb`
  - Views: show, traffic, properties, conversions, realtime
- ✅ Overview metrics
  - Total visitors
  - Unique visitors
  - Total visits
  - Average session duration
- ✅ Traffic charts
  - Visits by day
  - Visitors by day
  - Traffic sources
  - Device breakdown
  - Geographic data
- ✅ Property analytics
  - Top properties
  - Property views by day
  - Top searches
- ✅ Conversion analytics
  - Inquiry funnel
  - Funnel conversion rates
  - Inquiries by day
- ✅ Real-time dashboard
  - Active visitors
  - Recent page views
  - JSON API for updates

### 8.3 Analytics Features
- ✅ Period selection (7, 14, 30, 60, 90 days)
- ✅ Time-based filtering
- ✅ Traffic source analysis
- ✅ Device breakdown
- ✅ Geographic analysis
- ✅ Search term tracking
- ✅ Property engagement tracking
- ✅ Real-time visitor view
- ✅ Subscription feature-gating (analytics on paid plans)
- ⚠️ Google Analytics integration (framework, needs UI)
- ❌ Custom events tracking
- ❌ Conversion goals
- ❌ Cohort analysis
- ❌ Behavior flow tracking
- ❌ Email reports
- ❌ Export/report generation
- ❌ Comparison reports
- Location: `site_admin/analytics_controller.rb`

### 8.4 Analytics API
- ✅ Ahoy.js integration
- ✅ Event tracking API
- ✅ Real-time data JSON endpoint
- ✅ Analytics service
  - Location: `Pwb::AnalyticsService`

---

## 9. THEME & CUSTOMIZATION

### 9.1 Theme System
- ✅ Theme model
  - Location: `Pwb::Theme`
  - Loaded from `config.json` in theme directory
- ✅ Multiple built-in themes
  - Default theme
  - Brisbane theme
  - Bologna theme
- ✅ Per-website theme selection
- ✅ Theme versioning
- ✅ Theme inheritance
  - Parent theme support
  - Inheritance chain resolution
  - View path fallback

### 9.2 Theme Customization
- ✅ CSS customization
  - Location: `app/stylesheets/`
- ✅ CSS custom properties (variables)
  - Theme-specific color schemes
  - Light/dark mode support
  - Per-tenant override
- ✅ Style variables system
  - Location: `style_variables` JSONB column
  - JSON schema-based UI
  - Default values per theme
  - Per-website customization
- ✅ Tailwind CSS customization
- ✅ Google Font selection per theme
- ✅ Raw CSS injection (advanced)
- ✅ Custom CSS per website
  - Route: `/custom_css/:theme_name`

### 9.3 Logo & Branding
- ✅ Logo upload
- ✅ Favicon upload
- ✅ Primary color selection
- ✅ Company branding
- ✅ Social media customization
- ✅ Website photo management
  - Model: `Pwb::WebsitePhoto`
  - Photo keys for different usage

### 9.4 Page Parts (Templates)
- ✅ 20+ pre-built page part templates (see section 3.2)
- ✅ Custom page part creation
- ✅ Theme-aware templates
- ✅ Liquid template support
- ✅ Template customization

### 9.5 Liquid Templates
- ✅ Liquid template engine
- ✅ Custom property tags
- ✅ Featured properties tags
- ✅ Contact form tags
- ✅ Page part inclusion tags
- ✅ Dynamic content rendering

### 9.6 Per-Tenant Customization
- ✅ Theme style variables override
- ✅ Website-specific color schemes
- ✅ Logo and favicon URLs
- ✅ Social media customization
- ✅ Raw CSS injection
- ✅ Recaptcha configuration

---

## 10. SEO FEATURES

### 10.1 Technical SEO
- ✅ SEO-friendly URLs
  - Property: `/properties/for-sale/:id/:url_friendly_title`
  - Pages: `/p/:page_slug`
  - Custom slugs supported
- ✅ Dynamic sitemap generation
  - Route: `/sitemap.xml`
  - Includes pages, properties, regions
  - Location: `sitemaps_controller.rb`
- ✅ Dynamic robots.txt
  - Route: `/robots.txt`
  - Dynamic per-tenant
  - Location: `robots_controller.rb`
- ✅ Canonical link support
  - Via layout template
- ✅ Google Analytics setup
  - Configuration via website settings
  - Not integrated in UI yet
- ✅ Responsive design
  - Mobile-friendly
  - Viewport meta tags

### 10.2 Meta Tags
- ✅ Page titles
  - Per-page configuration
  - Multi-language support
- ✅ Page descriptions (meta)
  - Per-page configuration
- ✅ Property-specific meta
  - Title, description per property
  - Per listing (sale/rental)
- ✅ Favicon support
- ⚠️ Open Graph meta tags (framework, needs templates)
- ⚠️ Twitter Card tags (framework, needs templates)
- ❌ Image alt-text management UI
- 📌 SEO guides in `/docs/seo/`

### 10.3 Structured Data
- ✅ JSON-LD support (via Liquid tags)
- ✅ Schema.org capability
- 💡 Property schema markup possible
- ⚠️ Implementation guides in `/docs/seo/`

### 10.4 Multi-Language SEO
- ✅ Locale URL support (`/:locale/...`)
- ✅ hreflang tags (via helpers)
- ✅ Multi-language content
- ✅ Per-locale sitemap
- ❌ Language switcher UI (can implement)

### 10.5 SEO Status
- ⚠️ Partial implementation
- 📌 Guide: `/docs/seo/SEO_IMPLEMENTATION_GUIDE.md`
- 📌 Quick ref: `/docs/seo/SEO_QUICK_REFERENCE.md`
- Missing tools:
  - No comprehensive SEO audit
  - No keyword optimization
  - No readability analysis
  - No internal linking suggestions
  - No 404 monitoring

---

## 11. API INTEGRATION

### 11.1 GraphQL API
- ✅ GraphQL endpoint
  - Route: `/graphql`
  - Location: `graphql_controller.rb`
- ✅ GraphQL schema
  - Types: PropertyType, AgencyType, PageType, UserType, WebsiteType, LinkType, TranslationType
- ✅ Queries
  - Property queries
  - Page queries
  - User queries
  - Website queries
- ✅ Mutations
  - Listing Enquiry submission
  - Extensible for more mutations
- ✅ Pagination support
- ✅ Connection/cursor-based pagination
- ✅ GraphiQL IDE (development mode)
- Location: `app/graphql/`

### 11.2 REST API (Public)
- ✅ Public API v1
  - Route: `/api_public/v1`
  - Location: `api_public/v1/`
- ✅ Endpoints:
  - Properties: GET list, GET detail, search, filters
  - Pages: GET list, GET detail
  - Translations: GET available translations
  - Site details: GET website configuration
  - Links: GET navigation links
- ✅ Read-only access (mostly)
- ✅ Authentication optional (for public data)
- ✅ Pagination support
- ✅ JSONAPI compatible response format
- ✅ OpenAPI/Swagger documentation
  - Route: `/api-docs`
  - Documentation: RSwag integration
- Location: `api_public/v1/`

### 11.3 REST API (Internal)
- ✅ Internal API v1
  - Route: `/api/v1`
  - Location: `api/v1/`
- ✅ Endpoints:
  - Properties: CRUD
  - Agency: CRUD
  - Contacts: CRUD
  - Links: CRUD
  - Pages: CRUD
  - Translations: CRUD
  - Web contents: CRUD
  - File upload/management
- ✅ Authentication required
- ✅ Tenant-scoped
- Location: `api/v1/`

### 11.4 API Documentation
- ✅ OpenAPI/Swagger UI
  - Route: `/api-docs`
  - Generated via RSwag
- ✅ Public API docs
  - Route: `/api-public-docs`

### 11.5 External Integrations
- ✅ Google Maps API
  - Configuration via website settings
  - Location/geocoding support
  - Map display on property pages
- ✅ Google Analytics
  - Configuration in website settings
  - Not integrated in reporting yet
- ✅ Firebase
  - Authentication
  - Cloud messaging capable
- ✅ Recaptcha
  - Per-website configuration
  - Form protection available
- ✅ OAuth (Facebook)
  - OmniAuth integration
- ✅ Email services
  - Configurable (Sendgrid, Mailgun, etc.)
- ✅ Active Storage
  - S3 support
  - Cloudflare R2 support
  - Local disk support
- ✅ MLS import
  - TSV file format
  - Basic mapping
  - No auto-sync
- ❌ Mailchimp/Brevo
- ❌ HubSpot
- ❌ Salesforce
- ❌ RETS protocol
- ❌ Zillow/Redfin APIs
- ❌ IDX feed consumption

---

## 12. MULTI-TENANCY

### 12.1 Core Multi-Tenancy
- ✅ Website model as tenant
  - Location: `Pwb::Website`
  - One website = one tenant
- ✅ Data isolation
  - Website ID foreign key on all tenant-scoped models
  - Composite indexes (website_id + field)
- ✅ Subdomain-based routing
  - Unique subdomain per website
  - Case-insensitive lookup
- ✅ Slug-based routing alternative
- ✅ Database-level isolation
  - Single database, all tenants

### 12.2 ActsAsTenant Integration
- ✅ acts_as_tenant gem
  - Automatic tenant scoping
  - Web request context
  - Configuration in ApplicationRecord
- ✅ Tenant-scoped models
  - Namespace: `PwbTenant::`
  - Auto-scoped in web context
  - Safe without manual scoping

### 12.3 Tenant-Scoped Models
- ✅ PwbTenant::Prop
- ✅ PwbTenant::RealtyAsset
- ✅ PwbTenant::SaleListing
- ✅ PwbTenant::RentalListing
- ✅ PwbTenant::Page
- ✅ PwbTenant::PagePart
- ✅ PwbTenant::PageContent
- ✅ PwbTenant::Content
- ✅ PwbTenant::Contact
- ✅ PwbTenant::Message
- ✅ PwbTenant::User
- ✅ PwbTenant::Agency
- ✅ PwbTenant::Link
- ✅ PwbTenant::FieldKey
- ✅ PwbTenant::Feature
- ✅ PwbTenant::WebsitePhoto
- ✅ PwbTenant::UserMembership
- ✅ PwbTenant::ListedProperty

### 12.4 Tenant Configuration
- ✅ Website settings
  - Location: `/site_admin/website/settings`
  - Configurable via UI
- ✅ Properties settings
  - Location: `/site_admin/properties/settings`
  - Field key customization
  - Feature configuration
- ✅ Theme selection
- ✅ Domain configuration
- ✅ Email recipient configuration
- ✅ Localization settings
- ✅ Currency settings
- ✅ Feature flags per tenant
  - Via subscription plan

### 12.5 Tenant Admin Features
- ✅ Cross-tenant management
  - Location: `tenant_admin/`
- ✅ Website management and seeding
- ✅ User management across tenants
- ✅ Agency management
- ✅ Subscription management
- ✅ Plan management
- ✅ Domain management
- ✅ Subdomain pool management
- ✅ Email template management
- ✅ Activity monitoring
- ✅ Auth audit logs

### 12.6 User Membership
- ✅ UserMembership model
  - Location: `Pwb::UserMembership`
  - Join table between User and Website
- ✅ Multiple websites per user
- ✅ Role per website (owner, admin, member)
- ✅ Active/inactive membership
- ✅ Role management per website

---

## 13. SUBSCRIPTIONS & BILLING

### 13.1 Plans
- ✅ Plan model
  - Location: `Pwb::Plan`
  - Attributes: name, display_name, price, billing_interval, trial_days, features, property_limit, user_limit
- ✅ Plan CRUD (admin)
  - Location: `tenant_admin/plans_controller.rb`
- ✅ Active/inactive plans
- ✅ Public/private plans
- ✅ Pricing
  - Price in cents
  - Currency per plan
  - Billing interval (monthly/annual)
- ✅ Feature flags
  - JSON array of feature keys
  - FEATURES constant with descriptions
  - Custom feature definitions
- ✅ Property limits
  - Unlimited support
  - Per-plan configuration
- ✅ User limits
  - Unlimited support
  - Per-plan configuration
- ✅ Trial period
  - Per-plan configuration
  - Customizable duration

### 13.2 Subscriptions
- ✅ Subscription model
  - Location: `Pwb::Subscription`
  - One subscription per website
- ✅ Subscription CRUD
  - Location: `tenant_admin/subscriptions_controller.rb`
- ✅ Status management
  - States: trialing, active, past_due, canceled, expired
  - AASM state machine
- ✅ Subscription actions
  - Activate
  - Cancel
  - Reactivate
  - Change plan
  - Expire trial
- ✅ Billing periods
  - current_period_starts_at
  - current_period_ends_at
  - Configurable interval
- ✅ Trial management
  - Trial period dates
  - Trial days remaining
  - Trial ending soon detection
- ✅ Feature access
  - Plan feature availability
  - Feature gating in app
- ✅ Limit enforcement
  - Property count enforcement
  - User count enforcement
  - Remaining limits calculation

### 13.3 Payment Integration
- 🔨 External payment provider support
  - Fields for external IDs and customer IDs
  - Metadata JSONB for provider data
- 🔨 Stripe integration possible
  - Framework: external_id, external_customer_id, external_provider
  - Requires webhook setup
- ✗ No built-in payment processor
- ✗ No invoice generation
- ✗ No dunning/retry logic

### 13.4 Subscription Management
- ✅ Subscription listing
- ✅ Subscription creation
- ✅ Subscription editing
  - Plan changes
  - Status updates
- ✅ Subscription activation
- ✅ Subscription cancellation
- ✅ Subscription reactivation
- ✅ Bulk trial expiration
- ✅ Subscription event logging
  - Model: `Pwb::SubscriptionEvent`
  - Event types: activated, trial_started, trial_expired, past_due, canceled, expired, plan_changed, reactivated
- ✅ Feature gating
  - Analytics on paid plans
  - Custom features per plan
  - Configurable in subscription model

### 13.5 Billing Dashboard
- ✅ Billing view
  - Location: `/site_admin/billing`
  - Controller: `site_admin/billing_controller.rb`
- ✅ Current plan display
- ✅ Trial information
- ✅ Usage information
  - Current property count vs limit
  - Feature availability
- ✅ Billing period
- ✅ Subscription status
- ✅ Plan upgrade/downgrade (UI links)

---

## 14. DOMAINS & CUSTOM DOMAINS

### 14.1 Domain Management
- ✅ Custom domain support
  - Location: `Pwb::Domain`, `site_admin/domains_controller.rb`
- ✅ Domain listing
- ✅ Domain creation
- ✅ Domain deletion
- ✅ Domain verification
  - DNS verification
  - TXT record checking
  - Location: `site_admin/domains#verify`

### 14.2 Subdomain Management
- ✅ Subdomain support
  - Location: `Pwb::Subdomain`, `tenant_admin/subdomains_controller.rb`
- ✅ Unique subdomain per website
- ✅ Subdomain validation
  - Alphanumeric + hyphens
  - Reserved subdomain list
- ✅ Subdomain pool
  - Pre-populated subdomains for assignment
  - Subdomain population
  - Subdomain release/expiry
- ✅ Case-insensitive lookup

### 14.3 TLS/SSL
- ✅ On-demand TLS verification
  - Route: `/tls/check`
  - For Caddy reverse proxy
  - Location: `pwb/tls_controller.rb`
- ✅ Automatic certificate issuance
  - Via Caddy or similar
- 🔨 Manual SSL setup possible

---

## 15. FILE STORAGE & IMAGES

### 15.1 Active Storage Integration
- ✅ ActiveStorage
  - Rails built-in file attachment system
  - Models: PropPhoto, ContentPhoto, WebsitePhoto, Media, etc.
- ✅ Multiple storage backends
  - Local disk (development)
  - AWS S3 (production)
  - Cloudflare R2 (production, S3-compatible)
  - Other S3-compatible services
- ✅ Configuration in `storage.yml`
- ✅ Variant generation
  - On-demand image resizing
  - Thumbnails, small, medium, large variants
  - WebP support
- ✅ URL strategies
  - Rails blob URLs (work across all backends)
  - CDN direct URLs (when configured)

### 15.2 Photo Management
- ✅ Property photos
  - Model: `Pwb::PropPhoto`
  - Multiple per property
  - Sort ordering
  - Descriptions
  - Bulk upload/delete
- ✅ Content photos
  - Model: `Pwb::ContentPhoto`
  - Associated with content blocks
  - Ordering
  - Deletion
- ✅ Website photos
  - Model: `Pwb::WebsitePhoto`
  - Key-based (logo, favicon, banner, etc.)
- ✅ Media library
  - Model: `Pwb::Media`
  - Hierarchical folders
  - Usage tracking
  - Metadata (dimensions, checksums, content type)

### 15.3 Image Features
- ✅ Upload from file
- ✅ Upload from URL (if enabled)
- ✅ Bulk upload
- ✅ Image variants
- ✅ Image reordering
- ✅ Image deletion
- ✅ Usage tracking
- ✅ Metadata extraction
- ✅ CDN support
- ❌ Image compression automation
- ❌ Image optimization recommendations

### 15.4 Storage Dashboard
- ✅ Active Storage Dashboard
  - Route: `/active_storage_dashboard` (tenant admin only)
  - Location: Mount ActiveStorageDashboard::Engine
  - Features: File browsing, deletion, usage monitoring
- ✅ Storage statistics
  - Location: `site_admin/storage_stats_controller.rb`
  - Shows storage usage
  - Orphan file monitoring
  - Cleanup options

---

## 16. SECURITY & COMPLIANCE

### 16.1 Authentication Security
- ✅ Password encryption (Devise bcrypt)
- ✅ Session management
  - Session timeout
  - Remember-me token
  - Secure cookies
- ✅ Account lockout
  - After failed login attempts
  - Configurable threshold
- ✅ CSRF protection
  - Rails built-in
  - Token validation
- ✅ XSS protection
  - Rails content escaping
  - Sanitization

### 16.2 Authorization
- ✅ Multi-tenant isolation
  - ActsAsTenant enforcement
  - website_id scoping
- ✅ User membership checks
- ✅ Role-based access
  - Owner, admin, member roles
- ⚠️ Authorization system in progress (noted in code)
- 🔨 Custom authorization rules possible

### 16.3 Audit & Logging
- ✅ Auth audit logs
  - Event types: login, logout, registration, failed_login, password_reset
  - IP logging
  - User agent logging
  - Timestamp tracking
  - Metadata storage
- ✅ Activity logs
  - Property creation/modification
  - Page edits
  - User actions
- ✅ Query-friendly scopes
  - By user, IP, event type, date range

### 16.4 Data Security
- ✅ Database encryption
  - Via pgcrypto (PostgreSQL extension)
- ✅ Password reset via email
  - Token-based
  - Time-limited
- ✅ Account verification
  - Email verification for new accounts
  - Resend verification emails
- ✅ Multi-tenant data isolation
  - Database-level via website_id
  - Query-level via ActsAsTenant

### 16.5 Security Features
- ✅ Recaptcha support
  - Per-website configuration
  - Form protection
- ✅ Account deactivation
  - Soft delete support
- ⚠️ Two-factor authentication (Firebase capable, not implemented)
- ✗ WAF integration
- ✗ Rate limiting (Rails level possible)

### 16.6 Compliance
- ✅ GDPR-ready
  - Data deletion capabilities
  - User data export
  - Privacy controls
- ✅ Multi-tenant isolation
  - Data segregation
- 🔨 HIPAA/PCI compliance (requires setup)
- 🔨 Custom compliance controls possible

---

## 17. DEVELOPER TOOLS

### 17.1 Testing Infrastructure
- ✅ RSpec for unit/integration tests
- ✅ FactoryBot for test data
- ✅ Playwright for E2E tests
- ✅ Database fixtures
- ✅ Seed data system
- Location: `spec/`, `tests/e2e/`

### 17.2 Development Tools
- ✅ Rails console access
- ✅ Rails migrations
- ✅ Database seeds
- ✅ CLI tools
- ✅ Development logger (Logster)
  - Route: `/logs` (tenant admin only)
- ✅ GraphQL IDE (GraphiQL)
  - Route: `/graphiql` (development only)
- ✅ Performance monitoring
  - Route: `/performance` (tenant admin only)
  - RailsPerformance dashboard
- ✅ Background job monitoring
  - Route: `/jobs` (tenant admin only)
  - Mission Control::Jobs dashboard

### 17.3 Monitoring & Debugging
- ✅ Error logging (Logster)
  - Persistent error logs
  - Searchable by type/date
- ✅ Activity monitoring (Ahoy)
  - Visitor tracking
  - Event tracking
- ✅ Performance monitoring
  - RailsPerformance integration
- ✅ Health check endpoints
  - `/health`
  - `/health/live`
  - `/health/ready`
  - `/health/details` (JSON)

---

## 18. DEPLOYMENT & OPERATIONS

### 18.1 Deployment Options
- ✅ Documented guides for:
  - Render
  - Heroku
  - Dokku
  - Cloud66
  - Koyeb
  - Northflank
  - Qoddi
  - AlwaysData
  - DomCloud
  - Argonaut
  - Coherence
- 📌 Guides in `/docs/deployment/`

### 18.2 Background Jobs
- ✅ ActiveJob framework
- ✅ Sidekiq capable
- ✅ Solid Queue support
- 🔨 Async processing setup
- 🔨 Scheduled jobs possible

### 18.3 Database
- ✅ PostgreSQL
- ✅ Migrations
- ✅ Indexes
- ✅ Constraints
- ✅ Materialized views (Scenic)

### 18.4 Environment Configuration
- ✅ .env support
- ✅ Configurable via environment
- ✅ Feature flags possible
- ✅ Secrets management (Rails credentials)

---

## 19. DOCUMENTATION

### 19.1 Built-in Documentation
- ✅ Comprehensive README
- ✅ Architecture guides
  - `/docs/architecture/`
- ✅ Feature documentation
  - Scattered across `/docs/`
- ✅ Admin guides
  - `/docs/admin/`
- ✅ Seeding guides
  - `/docs/seeding/`
- ✅ API documentation
  - Swagger/OpenAPI
  - GraphQL schema
- ✅ Theming guides
  - `/docs/theming/`
- ✅ Multi-tenancy guides
  - `/docs/multi_tenancy/`
- ✅ Deployment guides
  - `/docs/deployment/`

### 19.2 Code Documentation
- ✅ Schema comments
- ✅ Model associations documented
- ✅ Key methods documented
- ✅ Controller actions documented
- ✅ Example code in guides

### 19.3 External Documentation
- ✅ GitHub repository (public)
- ✅ Issue tracking
- ✅ Release notes
- 🔨 Community forums possible

---

## 20. FEATURE SUMMARY TABLE

| Category | Feature | Status | Notes |
|----------|---------|--------|-------|
| **Admin** | Dashboard | ✅ | Dual-tier system |
| | Pages/Content | ✅ | Full CRUD, 20+ parts |
| | User Management | ✅ | Multi-website support |
| | Settings | ✅ | Comprehensive |
| **Properties** | CRUD | ✅ | Excellent UI |
| | Photos | ✅ | Batch upload, reorder |
| | Search | ✅ | Advanced filters, AJAX |
| | Import/Export | ✅ | CSV, MLS (basic) |
| | Versioning | ✅ | Archive/history |
| **Content** | Pages | ✅ | Multi-language, slugs |
| | Blog | ❌ | Pages work but not optimized |
| | Blocks | ✅ | 20+ templates |
| | Media Library | ✅ | Folders, variants |
| **Translations** | Multi-language | ✅ | 7 languages, JSONB |
| | URL locales | ✅ | hreflang support |
| **Auth** | Email/Password | ✅ | Devise |
| | Firebase | ✅ | Full integration |
| | OAuth | ✅ | Facebook, extensible |
| | Audit Logging | ✅ | Detailed tracking |
| **CRM** | Contacts | ✅ | Basic model |
| | Messages | ✅ | Inquiry tracking |
| | Pipeline | ❌ | No workflow |
| **Email** | Templates | ✅ | Customizable |
| | Notifications | ✅ | On forms, inquiries |
| | Marketing | ❌ | No campaigns |
| **Analytics** | Visitor Tracking | ✅ | Ahoy integration |
| | Dashboard | ⚠️ | Basic, needs expansion |
| | Reports | ❌ | No export |
| **SEO** | Sitemaps | ✅ | Dynamic |
| | Meta Tags | ⚠️ | Framework, incomplete |
| | Structured Data | 💡 | Possible via Liquid |
| | Audit Tools | ❌ | No suite |
| **Themes** | Customization | ✅ | CSS variables, Tailwind |
| | Inheritance | ✅ | Parent-child support |
| | Builder | ❌ | No drag-drop builder |
| **Multi-Tenancy** | Isolation | ✅ | Native, database-level |
| | White-label | ✅ | Per-tenant themes |
| **Billing** | Plans | ✅ | Feature-based |
| | Subscriptions | ✅ | Trial, states |
| | Payments | 🔨 | Framework ready |
| **Integrations** | Maps | ✅ | Google Maps |
| | Analytics | 🔨 | Configured, needs UI |
| | MLS | ⚠️ | CSV import only |
| | CRM | ❌ | No integrations |
| **API** | REST | ✅ | v1, documented |
| | GraphQL | ✅ | Full schema |
| **Testing** | E2E | ✅ | Playwright |
| | Unit | ✅ | RSpec |
| **Deployment** | Hosting Guides | ✅ | 11 platforms |
| | Docker | ✅ | Ready to deploy |

---

## Summary Statistics

**Total Features**: 200+  
**Fully Implemented**: ~150 (75%)  
**Partially Implemented**: ~30 (15%)  
**Not Implemented**: ~20 (10%)  
**Framework Ready (needs setup)**: ~15  

**Priority Gaps**:
1. Advanced SEO tools
2. Advanced CRM
3. Advanced Analytics
4. Email Marketing
5. Professional MLS Integration

**Strengths**:
- Property management
- Multi-tenancy
- Admin interface
- Theme system
- Authentication

**Weaknesses**:
- Content marketing (no blog)
- Lead management (basic only)
- Marketing tools (no email/campaigns)
- Integrations (limited ecosystem)
- Mobile apps (not available)

---

**Document Version**: 1.0  
**Last Updated**: December 28, 2025  
**Scope**: Complete feature inventory of PropertyWebBuilder
