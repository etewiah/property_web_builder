# PropertyWebBuilder Feature Inventory (December 2024)

## Overview

PropertyWebBuilder is a modern, open-source real estate website platform built on Rails 8, Ruby 3.4.7, with a modern tech stack including Vue.js 3, Quasar, and Vite. It's a multi-tenant SaaS application where each website is a separate tenant with complete data isolation.

**Repository**: https://github.com/etewiah/property_web_builder

---

## 1. Admin/CMS Capabilities

### Admin Panel Structure
- **Dual Admin System**:
  - **Tenant Admin** (`/tenant_admin`): Cross-tenant management dashboard for system administrators
  - **Site Admin** (`/site_admin`): Per-website management dashboard for website administrators
  
- **Tenant Admin Dashboard** Features:
  - Website management and seeding
  - Cross-tenant user management
  - Agency management
  - Property oversight
  - Page management
  - Contact and message monitoring
  - User administration
  - Auth audit logs and security monitoring
  - Active Storage dashboard access
  - Logster integration for error logs

- **Site Admin Dashboard** Features:
  - Property management (full CRUD)
  - Page editing and content management
  - Page parts (content blocks) management
  - Contact management
  - Message/inquiry management
  - User management per website
  - Website settings and configuration
  - Properties settings (field configuration)
  - Website branding and customization
  - Navigation links management
  - Image library for content editors

### Content Management System
- **Page Management**:
  - Multi-language support (Mobility translations)
  - Custom slug-based URLs
  - Page visibility controls
  - Navigation menu integration (top nav and footer)
  - SEO-friendly page titles and link titles
  - Page-level metadata storage

- **Page Parts (Content Blocks)**:
  - 20+ pre-built page part templates
  - Block-based content editing
  - Visibility toggles per page part
  - Theme-aware page parts
  - Locale-specific templates
  - In-context editing support

- **In-Context Editor** (`/edit` routes):
  - Live page editing without leaving frontend
  - Page parts editing from frontend
  - Theme settings customization
  - Image library integration
  - Inline saving

### Content Types
- **Web Contents**:
  - Generic content storage with translations
  - Photo attachments via ContentPhoto model
  - Block-level content with JSONB storage
  - Tag-based organization (carousel, logos, testimonials, etc.)
  - Sort ordering for galleries

---

## 2. Property Management Features

### Property Model Architecture
- **Dual Model System**:
  - **Legacy Prop Model**: Original property model (backwards compatibility)
  - **New RealtyAsset + Listing Models**: Modern normalized structure
    - `RealtyAsset`: Core property data (address, description, specs)
    - `SaleListing`: Sale-specific listing with pricing and status
    - `RentalListing`: Rental-specific listing with seasonal pricing

### Property Attributes
- **Basic Information**:
  - Reference/ID
  - Title and description (multi-language)
  - Address components (street, city, postal code, region, country)
  - GPS coordinates (latitude/longitude)

- **Physical Attributes**:
  - Bedrooms, bathrooms, toilets
  - Garages
  - Plot area (configurable units: sqm or sqft)
  - Constructed area
  - Year of construction
  - Energy rating and performance
  - Furnished flag

- **Property Type Classification**:
  - Property type keys (apartment, house, commercial, etc.)
  - Property state keys (new, renovated, etc.)
  - Property origin keys
  - Zone/locality classification

- **Rental Capabilities**:
  - Short-term rental support
  - Long-term rental support
  - Seasonal pricing (low, high, standard)
  - Monthly rental prices
  - Rental period availability dates

- **Sale Capabilities**:
  - Sale price (current and original)
  - Commission tracking
  - Service charges
  - Listing status (sold, reserved)

- **Status Management**:
  - Visible/hidden flag
  - Active from date
  - Archived flag
  - Highlighted flag
  - Reserved flag
  - Soft delete support

- **Features System**:
  - Configurable property features (pool, garage, garden, etc.)
  - Feature key-based organization
  - Multi-language support

### Photo Management
- Multiple photos per property
- Sort ordering
- Photo descriptions
- Active Storage integration (S3, local disk, etc.)
- Bulk photo upload
- Individual photo removal
- Photo reordering

### Price Management
- Multi-currency support
- Money gem integration for currency handling
- Separate current and original prices for sales
- Seasonal pricing for rentals
- Price range search support

### Search & Filtering
- Advanced search filters:
  - Property type
  - Property state
  - Price range (sale and rental)
  - Bedrooms/bathrooms count
  - Location/city
  - Furnished status
  - For sale/for rent flags
  - Highlighted properties

- Materialized View (`ListedProperty`):
  - Optimized read-only view for search performance
  - De-normalized property data for fast queries
  - Used by search and listing pages

---

## 3. User/Agent Management

### User Model
- **Authentication Methods**:
  - Email/password (Devise)
  - Firebase authentication
  - OAuth (Facebook)
  - OmniAuth integration

- **User Attributes**:
  - Email (unique)
  - Password (encrypted via Devise)
  - First/last names
  - Skype handle
  - Phone number
  - Preferred language/locale
  - Preferred currency

- **User Tracking**:
  - Sign-in count
  - Current/last sign-in timestamps
  - Current/last sign-in IP
  - Account lock status
  - Failed login attempts
  - Remember-me cookie support

- **Multi-Website Support**:
  - User memberships via `UserMembership` model
  - Role-based access (owner, admin, member)
  - Active/inactive membership status
  - Cross-website user access

### User Roles & Permissions
- **Tenant Admin**: System-wide administrator access
- **Website Owner**: Full control of a specific website
- **Website Admin**: Administrative access to website
- **Website Member**: Basic access to website
- **Anonymous Users**: Public website visitors

### Authorization System
- **Scope-based**:
  - Multi-tenant isolation via `ActsAsTenant`
  - Website ID-based scoping
  - User membership checks
  - Role-based authorization (in progress per code comments)

- **Audit Logging**:
  - Auth audit logs tracking:
    - User ID, email, provider
    - Event type (login, logout, registration, failed_login, etc.)
    - IP address and user agent
    - Request path
    - Failure reasons
    - Timestamps
  - Queryable by user, IP, event type, date range

### Agency/Organization Management
- **Agency Model**:
  - Company name and display name
  - Contact information (phone, mobile, email)
  - Website URL
  - Skype contact
  - Social media handles
  - Analytics integration (GA, other)
  - Primary and secondary addresses
  - Company ID support
  - Payment plan tracking
  - Theme selection
  - Multi-language support
  - Multi-currency support

---

## 4. SEO Features

### Built-in SEO Capabilities
- **URL Structure**:
  - Slug-based URLs for properties and pages
  - SEO-friendly property URLs: `/properties/for-sale/:id/:url_friendly_title`
  - Custom page slugs
  - Locale support in URLs (`/:locale/...`)

- **Page Metadata**:
  - Page titles (overrideable)
  - Link titles for navigation
  - Custom page descriptions
  - Metadata storage in JSONB

- **Property Display**:
  - Property-specific page titles
  - Descriptions in multiple languages
  - Location-based indexing (address components)
  - Image alt text support

- **Structured Data**:
  - JSON-LD support (via liquid tags)
  - Schema.org compliance potential
  - Property-specific schema generation

- **Technical SEO**:
  - Google Maps API integration for location data
  - Google Analytics integration support
  - Custom CSS files per theme
  - Favicon and logo configuration
  - Responsive design (mobile-friendly)

---

## 5. Theme/Customization Options

### Theme System Architecture
- **Theme Management**:
  - Theme model using ActiveJSON (loaded from `config.json`)
  - Multiple built-in themes: default, brisbane, bologna
  - Per-website theme selection
  - Theme versioning

- **Theme Inheritance**:
  - Parent theme support (themes can extend other themes)
  - Inheritance chain resolution
  - View path resolution with fallback
  - Template overriding in child themes

- **Page Part Library**:
  - 20+ pre-built page part templates:
    - Heroes (banner sections)
    - Features (feature lists)
    - Testimonials (client quotes)
    - CTAs (Call-to-action sections)
    - Stats (statistics display)
    - Teams (team member profiles)
    - Galleries (image galleries)
    - FAQs (Frequently asked questions)
    - Pricing (price tables)
    - And more...

- **CSS Customization**:
  - CSS custom properties (variables)
  - Theme-specific color schemes
  - Light/dark mode support
  - Per-tenant style customization
  - Raw CSS override support
  - Google Font selection

- **Style Variables System**:
  - Configurable style variables per theme
  - Default values per theme
  - Per-website customization
  - Color, spacing, font customization
  - JSON schema-based configuration UI

- **Liquid Template Tags**:
  - Custom property display tags
  - Featured properties tags
  - Contact form tags
  - Page part inclusion tags
  - Dynamic content rendering

- **Per-Tenant Customization**:
  - Theme style variables override
  - Website-specific color schemes
  - Logo and favicon URLs
  - Social media customization
  - Raw CSS injection
  - Recaptcha configuration per website

### Built-in Themes Details
- **Default Theme**: Base theme with core page parts and layouts
- **Brisbane Theme**: Real estate-focused theme with modern design
- **Bologna Theme**: Alternative design theme

---

## 6. Multi-Tenancy Features

### Core Multi-Tenancy Architecture
- **Website Model as Tenant**:
  - Each website is a separate tenant
  - Subdomain-based routing
  - Slug-based routing alternative
  - Unique subdomain per website

- **Data Isolation**:
  - Website ID foreign key on all tenant-scoped models
  - Subdomain/Website constraint via `SubdomainTenant` concern
  - `ActsAsTenant` gem integration
  - Automatic tenant scoping in queries

- **Tenant-Scoped Models**:
  - PwbTenant namespace provides tenant-scoped versions
  - Automatic website_id filtering
  - Safe queries without manual scoping
  - Models include:
    - Prop, RealtyAsset, SaleListing, RentalListing
    - Page, PagePart, PageContent
    - Content, Contact, Message
    - User, Agency, Link
    - FieldKey, Feature
    - WebsitePhoto

- **User Membership System**:
  - Users can belong to multiple websites
  - UserMembership join model
  - Role-based access per website
  - Active/inactive membership status

- **Subdomain Support**:
  - Unique subdomain per website
  - Case-insensitive subdomain lookup
  - Reserved subdomain validation
  - Subdomain format validation (alphanumeric, hyphens)

### Tenant Admin Features
- System-wide dashboard for managing multiple websites
- User management across tenants
- Website seeding capabilities
- Cross-tenant data visibility (limited)
- Logs and audit trail access

---

## 7. Integrations

### External Service Integrations
- **Google Maps**:
  - Maps API key configuration
  - Property location display
  - Geocoding support (via Geocoder gem)
  - Latitude/longitude storage
  - Map marker generation

- **Google Analytics**:
  - Analytics ID configuration per website
  - Multiple analytics provider types (GA, custom)
  - Analytics tracking setup

- **Firebase Authentication**:
  - Firebase UID support
  - Firebase-based registration and login
  - Multi-factor authentication capable
  - Email/password authentication via Firebase

- **OAuth/Social Login**:
  - Facebook OAuth integration
  - OmniAuth support for extensibility

- **Recaptcha**:
  - Per-website Recaptcha key configuration
  - Support for form protection

- **Email Services**:
  - Generic mailer support (configured in Rails)
  - Contact form submissions
  - User notifications
  - Password reset emails

- **Active Storage**:
  - Multiple storage backend support (S3, local, etc.)
  - ActiveStorageDashboard for admin management
  - Photo attachment management
  - Content media management

- **Cloudflare R2** (documented):
  - Cloud storage alternative to AWS S3
  - Setup documentation available

### API Integrations
- **MLS (Multiple Listing Service)**:
  - MLS import capability
  - MLS property synchronization
  - TSV file format support
  - Property data mapping

- **PropertyWebBuilder Import**:
  - CSV import from other PWB sites
  - Property bulk creation
  - Data mapping and transformation

- **Data Export**:
  - Translation export functionality
  - Web content export
  - Website configuration export
  - Property export
  - Data backup capabilities

---

## 8. Search Functionality

### Advanced Search Features
- **Property Search**:
  - For sale search (`/buy`)
  - For rent search (`/rent`)
  - AJAX-based search results
  - Real-time filtering

- **Search Filters**:
  - Property type (field keys)
  - Price range (sale and rental)
  - Bedrooms/bathrooms count
  - Location/city
  - Property state (new, renovated, etc.)
  - Furnished status
  - Highlighted properties

- **Search Configuration**:
  - Per-website search settings
  - Configurable price ranges
  - Configurable search fields
  - Search behavior customization
  - Landing page search defaults

- **Map Integration**:
  - Property location visualization
  - Interactive map search
  - Map marker clustering
  - Map privacy (hide/obscure map options)

- **Result Ordering**:
  - Client-side JavaScript ordering
  - Relevance-based sorting
  - Price sorting
  - Date sorting

- **Materialized Views**:
  - ListedProperty view for search optimization
  - Denormalized property data for fast queries
  - Read-only access for search operations

---

## 9. Lead Management/CRM Features

### Lead Capture
- **Contact Forms**:
  - Site-wide contact form integration
  - Property inquiry forms
  - Separate contact form handlers:
    - General contact form (`/contact-us`)
    - Property inquiry form (`/request_property_info`)

- **Lead Data**:
  - Contact model for storing leads:
    - First/last name
    - Title (Mr., Mrs., etc.)
    - Email (primary and secondary)
    - Phone (primary and secondary)
    - Skype/Facebook/LinkedIn/Twitter IDs
    - Website URL
    - Nationality and documentation ID
    - Address information
    - Contact status flags

### Message Management
- **Inquiry Storage**:
  - Message model for storing inquiries
  - Associated with Contact records
  - Tracking of origin IP and user agent
  - Timestamp and locale tracking
  - Delivery status tracking
  - Delivery email logging

- **Admin Management**:
  - Message listing and viewing
  - Contact history per contact
  - Message/contact association
  - Status tracking

### Basic CRM Capabilities
- **Contact Database**:
  - Store and organize leads
  - Multiple contact records per inquiry
  - Address management
  - Social media handles storage
  - Documentation tracking
  - Custom details JSONB storage

- **Inquiry Tracking**:
  - Associate inquiries with contacts
  - Track inquiry source
  - Track inquiry date
  - Delivery confirmation
  - Origin tracking (IP, user agent)

### Limitations
- **Currently Limited CRM Features** (as noted in code comments):
  - No advanced lead scoring
  - No lead nurturing workflows
  - No email marketing automation
  - No sales pipeline management
  - No built-in email client integration
  - Authorization still being implemented

---

## 10. Media Management

### Photo Management System
- **Property Photos**:
  - Multiple photos per property
  - Photo ordering (sort_order)
  - Photo descriptions
  - Photo deletion
  - Photo reordering via PATCH
  - Bulk photo operations

- **Active Storage Integration**:
  - Flexible storage backend support
  - S3 integration support
  - Local storage support
  - Cloudflare R2 support
  - ActiveStorageDashboard for admin viewing
  - Variant generation for thumbnails

- **Content Photos**:
  - Content attachment system
  - Photo organization by block key
  - Sort ordering
  - Description storage
  - Folder organization

- **Website Media**:
  - Website photos (logo, favicon, banners)
  - Photo key-based organization
  - Website-specific storage

- **Image Library**:
  - Site admin image library (`/site_admin/images`)
  - Centralized image management
  - Image upload functionality
  - Integration with page editors

### Photo Operations
- Upload from file
- Upload from URL
- Remove/delete
- Reorder/sort
- Bulk operations (via API)

---

## 11. Blog/Content Management

### Content Management
- **Page System**:
  - Static pages (about, contact, etc.)
  - Custom page creation
  - Page versioning support
  - Multi-language support
  - Page visibility controls
  - Navigation menu integration

- **Page Parts**:
  - Modular content blocks
  - 20+ pre-built templates
  - Custom page part creation
  - Liquid template support
  - Block-level content management
  - Theme-specific variants

- **Web Contents**:
  - Generic content storage
  - Tag-based organization
  - Carousel support (galleries)
  - Photo integration
  - Multi-language support
  - Translation management

### Blog Capabilities
- **Currently Limited Blog Features**:
  - No dedicated blog posts model (not seen in exploration)
  - Page-based content possible but not optimized
  - No blog-specific UI in admin
  - Could be extended via page parts

### Content Editing
- **In-Context Editor**:
  - Edit content inline on website
  - Page parts editing from frontend
  - Theme settings adjustment
  - No page reload required
  - Visual feedback

- **Admin Editor**:
  - Server-side editing
  - Page part management
  - Content management
  - Multi-language translation management

---

## 12. Additional Notable Features

### GraphQL API
- **GraphQL Endpoint** (`/graphql`):
  - Full GraphQL schema support
  - Query and mutation support
  - Development mode includes GraphiQL IDE
  - Type system with base types:
    - PropertyType, AgencyType, PageType
    - UserType, WebsiteType, LinkType
    - TranslationType
  - Connection/pagination support
  - Sample mutation: ListingEnquiry submission

### REST API
- **Public API** (`/api_public/v1`):
  - Public property search
  - Public page viewing
  - Translation listing
  - Site configuration retrieval
  - Read-only for most operations

- **Internal API** (`/api/v1`):
  - Properties management
  - Agency management
  - Contacts management
  - Links management
  - Pages management
  - Translations management
  - Web contents management
  - File upload and management

### Field Keys System
- **Dynamic Field Configuration**:
  - Configurable property type keys
  - Configurable property state keys
  - Configurable feature keys
  - Translations for field labels
  - Visibility control
  - Display ordering
  - Search form inclusion
  - Per-website field configuration

- **Translation Management**:
  - Field key translations
  - Multiple language support
  - Custom translation values
  - Batch translation operations
  - Import/export capabilities

### Localization & Multi-Language
- **Mobility Gem Integration**:
  - JSONB-based translations
  - Container backend for all translations
  - Multi-language content:
    - Property titles and descriptions
    - Page content
    - Page part content
    - Link titles
    - Web contents
    - Realty asset descriptions

- **Available Locales**:
  - Configurable per website
  - Default locale selection
  - Locale-based URL routing (`/:locale/...`)
  - Admin locale preference per user
  - Client locale preference per user

- **Multi-Currency Support**:
  - Money gem integration
  - Currency per website
  - Exchange rates tracking
  - User currency preference
  - Admin currency preference
  - Price display in multiple currencies

### Email Notifications
- **Email Delivery**:
  - User registration confirmations
  - Password reset emails
  - Contact form notifications
  - Property inquiry notifications
  - Delivery tracking

- **Configurable Recipients**:
  - General contact form recipient
  - Property inquiry form recipient
  - Admin notifications

### Security & Audit
- **Auth Audit Logging**:
  - Event-based logging (login, logout, registration, failed_login, etc.)
  - User tracking
  - IP address logging
  - User agent tracking
  - Request path logging
  - Metadata storage for additional info
  - Timestamp and date range queries
  - Queryable by user, IP, or event type

- **Account Security**:
  - Password encryption via Devise
  - Account lockout after failed attempts
  - Session timeout support
  - Remember-me cookie support
  - CSRF protection
  - Recaptcha support

---

## 13. Architecture & Technical Details

### Core Technologies
- **Framework**: Rails 8.0
- **Ruby**: 3.4.7
- **Database**: PostgreSQL with extensions (pgcrypto)
- **Frontend**: Vue.js 3 + Quasar framework
- **Build Tool**: Vite with vite-ruby
- **CSS**: Tailwind CSS support
- **Styling**: Custom CSS variables system

### Key Gems & Libraries
- **Authentication**: Devise, OmniAuth, Firebase Admin SDK
- **Authorization**: ActsAsTenant, role-based access
- **Content**: Mobility (I18n), Globalize migration support
- **Payments**: Money gem for multi-currency
- **API**: GraphQL-Ruby, JSONAPI
- **Jobs**: Active Job (Sidekiq capable)
- **Storage**: ActiveStorage with variant support
- **Monitoring**: Logster for error logs
- **Documentation**: RSwag for OpenAPI/Swagger

### Database Design
- **Multi-tenant Architecture**:
  - Website ID foreign key pattern
  - Composite unique indexes with website_id
  - ActsAsTenant configuration

- **Materialized Views**:
  - ListedProperty view for search optimization

- **JSONB Storage**:
  - translations JSONB column pattern
  - Configuration storage (site_configuration, style_variables)
  - Flexible schema support

- **Polymorphic Relationships**:
  - ActiveStorage attachment system
  - Message/Contact associations

### API Standards
- **GraphQL**: Modern query language API
- **REST**: Versioned API (v1)
- **JSON**: Standard response format
- **JSONAPI**: Compatible with JSONAPI spec

---

## 14. Feature Maturity Assessment

### Mature/Production-Ready Features
1. **Property Management**: Full CRUD with photos, pricing, status management
2. **Multi-Tenancy**: Solid subdomain/website isolation with user memberships
3. **Page Management**: Complete page system with translations and navigation
4. **Theme System**: Sophisticated inheritance and customization
5. **Search/Filtering**: Advanced property search with map integration
6. **Authentication**: Multiple auth methods (email/password, Firebase, OAuth)
7. **Localization**: Multi-language content via Mobility
8. **Media Management**: Active Storage integration with variant support
9. **API**: REST and GraphQL endpoints with good documentation
10. **Security**: Auth audit logging and standard protections

### Partially Implemented Features
1. **CRM/Lead Management**: Contact/Message models exist but limited workflow
2. **Blog/Content Management**: Page parts system is robust but no dedicated blog
3. **Authorization**: Role-based system in progress (noted in code comments)
4. **MLS Integration**: Import capability present but limited documentation

### Not Yet Implemented Features
- **Mobile Apps**: iOS/Android apps not built
- **Advanced CRM**: No lead scoring, nurturing, or sales pipeline
- **Email Marketing**: No automation or drip campaigns
- **Advanced Analytics**: Google Analytics setup only
- **Neighborhood Data**: Zillow API integration not implemented
- **RETS Support**: Professional MLS sync not implemented
- **Calendar**: No rental property calendar functionality
- **WordPress Import**: Blog migration tools absent

---

## 15. Key Code Structure

### Controller Organization
- `TenantAdminController`: System-wide admin routes
- `SiteAdminController`: Per-website admin routes
- `ApplicationController`: Public website controller
- RESTful resource controllers for CRUD operations
- Specialized controllers for search, import/export, editor

### Model Organization
- `Pwb::` namespace: Non-scoped models (useful for console/cross-tenant ops)
- `PwbTenant::` namespace: Tenant-scoped models (safe for web requests)
- `Pwb::ApplicationRecord`: Base class with ActsAsTenant configuration

### View Organization
- Theme-based view hierarchy
- Page parts templates in `app/views/pwb/page_parts/`
- Admin views in `app/views/site_admin/`
- Theme overrides in `app/themes/{theme_name}/views/`

---

## 16. Deployment & Operations

### Supported Hosting Platforms
Comprehensive deployment guides for:
- Render, Heroku, Dokku, Cloud66, Koyeb, Northflank, Qoddi, AlwaysData, DomCloud, Argonaut, Coherence

### Storage Options
- Local disk storage
- AWS S3
- Cloudflare R2
- Other ActiveStorage backends

### Background Jobs
- ActiveJob framework configured
- Sidekiq capability
- Email delivery queuing

---

## 17. Documentation Quality

### Available Documentation
- Comprehensive README with features list
- API documentation (Swagger/RSwag)
- Frontend documentation (Vue.js/Quasar)
- Multi-tenancy guides
- Authentication/authorization guides
- Theming system documentation
- Field keys system documentation
- Database seeding documentation
- Deployment guides for 10+ platforms
- Firebase setup guides
- ActiveStorage migration guides

### Documentation Locations
- `/docs/` folder with detailed guides
- Code comments in key files
- GraphQL schema introspection
- OpenAPI/Swagger endpoints

---

## 18. Recommendations for Future Development

### High-Value Features to Implement
1. **Advanced CRM Dashboard**: Sales pipeline, lead scoring, activity tracking
2. **Email Marketing Integration**: Mailchimp/SendGrid integration for campaigns
3. **Advanced Analytics**: Property view tracking, conversion metrics
4. **Blog System**: Dedicated blog with SEO optimization
5. **Automated Lead Workflows**: Lead assignment, follow-up automation
6. **Mobile Apps**: iOS and Android native apps
7. **RETS/MLS Advanced**: Professional MLS synchronization with update tracking

### Architecture Improvements Needed
1. Complete authorization system implementation (noted in code)
2. Refactor theming system per recommendations in docs
3. Add comprehensive integration tests
4. Document tenant-scoped vs non-scoped model usage
5. Improve error handling and user feedback

### Performance Optimizations
1. ListedProperty materialized view is good start
2. Consider caching for theme configuration
3. Optimize image variant generation
4. Index optimization for search queries
5. GraphQL N+1 query prevention

---

## Summary

PropertyWebBuilder is a **mature, production-ready real estate platform** with:

- Strong property management capabilities
- Excellent multi-tenancy architecture
- Sophisticated theming and customization system
- Modern tech stack (Rails 8, Vue 3, GraphQL)
- Comprehensive documentation and deployment options
- Multi-language and multi-currency support
- Solid authentication and security features
- Good API coverage (REST and GraphQL)

**Best suited for**:
- Real estate agencies needing custom websites
- Real estate platforms managing multiple agency sites
- Developers extending with custom features
- Organizations wanting full control over data and hosting

**Primary gaps**:
- Advanced CRM and lead management workflows
- Professional MLS/RETS integration
- Mobile applications
- Email marketing automation
- Advanced analytics
