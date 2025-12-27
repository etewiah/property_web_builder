# PropertyWebBuilder: Comprehensive Codebase Analysis

## Executive Summary

PropertyWebBuilder is a modern Rails 8 real estate website builder with a multi-tenant architecture. It allows agencies to create and manage property listings, pages, and contact forms without technical knowledge. The application has been recently upgraded from a Rails engine to a standalone Rails application with Vue.js 3, Quasar, and modern build tooling.

### Key Stack
- **Backend**: Rails 8, Ruby 3.4.7
- **Frontend**: Vue.js 3, Quasar Framework, Vite
- **Database**: PostgreSQL (multi-tenant with subdomain isolation)
- **APIs**: REST (public and private), GraphQL
- **Authentication**: Devise with OmniAuth (Facebook, Firebase)
- **Multi-Tenancy**: Subdomain-based with acts_as_tenant gem

---

## 1. Application Overview

### Purpose
PropertyWebBuilder is a SaaS platform for creating real estate websites. Each "website" is a distinct tenant with its own properties, pages, users, and content.

### Architecture Approach
- **Multi-tenant**: Each organization/agency operates on a subdomain (e.g., `acme.example.com`)
- **Scope isolation**: Data automatically scoped via `acts_as_tenant` using `Pwb::Current.website`
- **Dual model structure**: 
  - `Pwb::*` models (unscoped, useful for cross-tenant operations)
  - `PwbTenant::*` models (automatically scoped to current tenant)

---

## 2. Core Data Models & Relationships

### Website (Tenant)
**Model**: `Pwb::Website`
- Root entity representing a real estate agency website
- Contains all data for that tenant
- **Key Attributes**:
  - `subdomain`: Unique identifier (validates format, reserved names)
  - `company_display_name`, `theme_name`, `default_currency`
  - `slug`, `visible`
- **Associations**:
  - `has_many :users` (website-specific users)
  - `has_many :user_memberships` (multi-website support)
  - `has_many :props` (legacy model, for backwards compatibility)
  - `has_many :realty_assets` (normalized property model)
  - `has_many :sale_listings`, `has_many :rental_listings`
  - `has_many :pages`, `has_many :links`, `has_many :contents`
  - `has_many :contacts`, `has_many :messages`
  - `has_one :agency` (agency info for the website)

### Users & Authentication
**Models**: `Pwb::User`, `Pwb::UserMembership`

**User Model**:
- Devise-based authentication
- Can belong to multiple websites via `user_memberships`
- **Key Attributes**:
  - `email`, `password`, `admin` (legacy flag)
  - `website_id` (backward compatible, made optional)
  - `encrypted_password`, `confirmation_token`, etc.
- **Relationships**:
  - `has_many :user_memberships`
  - `has_many :websites` (through memberships)
  - `has_many :authorizations` (OmniAuth)
  - `belongs_to :website` (legacy)

**UserMembership Model** (Multi-Website Support):
- Joins users to websites with role-based access
- **Roles**: `owner`, `admin`, `member`, `viewer`
- **Attributes**:
  - `user_id`, `website_id`, `role`, `active` (boolean)
- **Methods**:
  - `admin?` (owner or admin)
  - `owner?`
  - `active?`
  - `can_manage?(other_membership)` (role hierarchy)
- **Scopes**: `active`, `inactive`, `admins`, `owners`

### Properties (Normalized Model)

The application uses a **normalized property schema** with:

**RealtyAsset** (The property itself):
- Represents physical property (building/land)
- **Key Attributes**:
  - `slug` (unique), `reference`, `website_id`
  - Address data: `street_address`, `city`, `postal_code`, `country`
  - Geocoding: `latitude`, `longitude`
  - `visible` (boolean)
- **Associations**:
  - `has_many :sale_listings` (sale transactions)
  - `has_many :rental_listings` (rental transactions)
  - `has_many :prop_photos` (ordered images)
  - `has_many :features` (property amenities/attributes)

**SaleListing** (Sale transaction):
- Represents a sale of a property
- **Key Attributes**:
  - `realty_asset_id`, `active`, `visible`, `archived`, `highlighted`
  - Pricing: `price_sale_current_cents`, `price_sale_current_currency`
  - Commission: `commission_cents`, `commission_currency`
  - Marketing: `title_*`, `description_*` (translatable via Mobility)
- **Validations**: Only one active listing per property
- **Scopes**: `active`, `visible`, `highlighted`, `archived`

**RentalListing** (Rental transaction):
- Represents a rental of a property
- **Key Attributes**:
  - Similar structure to SaleListing
  - Price fields: `price_rental_monthly_current_cents`, plus seasonal variants
  - `for_rent_short_term`, `for_rent_long_term` (boolean flags)
  - Marketing: `title_*`, `description_*` (translatable)

**ListedProperty** (Materialized View for reads):
- Denormalized, query-optimized view of properties
- Combines RealtyAsset + active Listing data
- **Used for**:
  - Admin dashboard property listings
  - Public property search
  - Performance optimization
- **Note**: Refreshed after SaleListing/RentalListing changes

**PropPhoto**:
- Images for properties, ordered by `sort_order`
- **Associations**: `belongs_to :realty_asset`

### Legacy Prop Model
- Still exists for backward compatibility
- Deprecated in favor of RealtyAsset + Listings
- Contains all old property data

### Pages & Content Management

**Page** (CMS pages):
- Represents a website page
- **Key Attributes**:
  - `slug` (unique within website), `visible`, `show_in_top_nav`, `show_in_footer`
  - `page_title`, `link_title`, `raw_html` (all translatable via Mobility)
  - `sort_order_top_nav`, `sort_order_footer`
- **Associations**:
  - `has_many :page_parts` (editable content sections)
  - `has_many :page_contents` (join model with Content)
  - `has_many :contents` (through page_contents)
  - `has_many :links` (navigation links to this page)

**PagePart** (Editable content block):
- Represents a section of a page that can be edited
- **Key Attributes**:
  - `page_slug`, `page_part_key` (e.g., "hero-section", "contact-form")
  - `is_rails_part` (boolean - native Rails partial vs liquid template)
  - `editor_setup` (configuration for admin editor)
  - `block_contents` (JSONB - liquid template data)
  - `show_in_editor`, `order_in_editor`
- **Cache Strategy**: Template cached, expires 5s in dev, 1h in prod
- **Template Loading Priority**: Database > Theme-specific file > Default file

**Content** (Translatable content block):
- Represents the actual content for a page/page-part
- **Key Attributes**:
  - `key`, `page_part_key`, `visible_on_page` (boolean)
  - `raw_*` (raw HTML, translatable via Mobility for multiple locales)
- **Associations**:
  - `has_many :content_photos` (associated images)
  - `has_many :page_contents` (join model)
  - `has_many :pages` (through page_contents)
- **Methods**:
  - `default_photo` (first associated photo)
  - `default_photo_url`

**PageContent** (Join Model):
- Associates Page with Content
- **Attributes**: `page_id`, `content_id`, `page_part_key`, `visible_on_page`
- **Scopes**: `ordered_visible` (for rendering)

### Agency & Contact Management

**Agency**:
- Represents the real estate agency info
- **Key Attributes**:
  - `display_name`, `company_name`
  - Contact: `phone_number_primary`, `phone_number_mobile`, `phone_number_other`
  - Email: `email_primary`, `email_for_property_contact_form`, `email_for_general_contact_form`
  - Primary/secondary address associations
- **Methods**: `as_json` (customized for API)

**Contact**:
- A person who interacts with the website
- **Key Attributes**:
  - `title` (enum: mr, mrs), `first_name`, `last_name`, `email`, `phone_number`
  - `primary_address_id`, `secondary_address_id` (foreign keys)
  - `user_id` (optional, if contact is also a website user)
- **Associations**:
  - `has_many :messages` (inquiries from this contact)
  - `belongs_to :primary_address`, `belongs_to :secondary_address`

**Message**:
- An inquiry/contact form submission
- **Key Attributes**:
  - `contact_id`, `website_id`
  - Message content (stored as JSON or text)
- **Associations**: `belongs_to :contact`, `belongs_to :website`

**Address**:
- Reusable address model
- **Key Attributes**: `street_number`, `street_address`, `city`, `postal_code`, `region`, `country`

### Linking & Navigation

**Link**:
- Represents navigation links and internal page references
- **Key Attributes**:
  - `page_slug` (which page the link appears on)
  - `target` (URL), `placement` (top_nav, footer, etc.)
  - `title_*` (translatable link text)
  - `sort_order`
- **Scopes**: Filtered by placement for different areas

---

## 3. User Roles & Personas

### 1. Website Owner/Super Admin
- Creates and manages multiple websites
- **Accessible Paths**: 
  - `/tenant_admin/` - Cross-tenant management dashboard
  - Can see all websites, users, properties
- **Key Actions**:
  - Create new website
  - Manage users across websites
  - Create website admins
  - View cross-tenant reports

### 2. Website Admin
- Manages a single website and its content
- **Role**: Admin or Owner in UserMembership
- **Accessible Paths**:
  - `/site_admin/` (scoped to their website via subdomain)
  - `/admin` (Vue.js admin panel)
  - `/edit` (in-context editor)
- **Key Actions**:
  - Add/edit/delete properties
  - Create/edit pages
  - Manage contacts and messages
  - Configure website settings
  - Upload images
  - Manage page parts (content sections)
  - Invite other users to the website

### 3. Website Editor/Member
- Can edit content but has limited access
- **Role**: Member in UserMembership
- **Accessible Paths**: Same as admin, but with limited actions
- **Key Actions**:
  - Edit existing content
  - View properties and pages
  - Respond to messages

### 4. Viewer/Read-Only User
- Can only view content
- **Role**: Viewer in UserMembership
- **Accessible Paths**: Limited to viewing pages
- **Key Actions**: View properties, pages (no editing)

### 5. Public Visitor
- Unauthenticated user accessing public website
- **Accessible Paths**:
  - `/` (home page)
  - `/properties/for-sale/*` (property listing pages)
  - `/properties/for-rent/*` (rental property pages)
  - `/buy`, `/rent` (search pages)
  - `/contact-us` (contact form)
  - `/p/:page_slug` (custom pages)
  - API: `/api_public/v1/*`
- **Key Actions**:
  - View property listings
  - Search for properties
  - Submit contact form
  - View custom pages

---

## 4. Controllers & Routes Structure

### Admin Controllers

#### TenantAdminController (Cross-tenant)
- **Base**: `/tenant_admin/`
- **No tenant scoping** - operates across all websites
- **Authentication**: Devise (user must be logged in)
- **Authorization**: None yet (Phase 2 - will add super_admin check)
- **Sub-controllers**:
  - `DashboardController` - Overview of all tenants
  - `WebsitesController` - Manage websites
  - `UsersController` - System users
  - `AgenciesController`, `PropsController`, `PagesController` - Cross-tenant views

#### SiteAdminController (Single tenant)
- **Base**: `/site_admin/`
- **Tenant scoped**: Via SubdomainTenant concern + acts_as_tenant
- **Authentication**: Devise
- **Authorization**: Phase 2
- **Layout**: `site_admin`
- **Key sub-controllers**:
  ```
  site_admin/
    dashboard - Dashboard with stats
    props - Property management
    pages - Page management
    page_parts - Content block editing
    users - User management
    contents - Content blocks
    messages - Inquiries
    contacts - Contact list
    images - Image library
    properties/settings - Property field configuration
    website/settings - Website configuration
  ```

### Public Controllers

#### ApplicationController (Base)
- Located in `pwb/application_controller.rb`
- Includes SubdomainTenant concern (resolves current website)
- Sets locale from browser/params
- Provides `@current_website`, `@current_agency` helpers

#### PropsController
- **Routes**:
  - `GET /properties/for-sale/:id/:url_friendly_title` - Show sale property
  - `GET /properties/for-rent/:id/:url_friendly_title` - Show rental property
  - `POST /request_property_info` - Submit property inquiry form
- **Uses**: `Pwb::ListedProperty` (materialized view) for reads
- **Features**:
  - Shows property details, images, location map
  - Contact form for property inquiry
  - Returns 404 if property not visible or listing doesn't exist

#### SearchController
- **Routes**:
  - `GET /buy` - Sale properties search page
  - `GET /rent` - Rental properties search page
  - `POST /search_ajax_for_sale` - AJAX search for sale
  - `POST /search_ajax_for_rent` - AJAX search for rent
- **Features**:
  - Advanced filtering (price, bedrooms, property type, etc.)
  - Map markers for results
  - Client-side ordering with Paloma JS

#### PagesController
- **Routes**:
  - `GET /:locale?/p/:page_slug` - Show custom page
  - `GET /:locale?/p/:page_slug/:page_part_key` - Show single page part
  - `GET /about-us` - Special route to about-us page
  - `GET /contact-us` - Contact page
- **Features**: Renders page with ordered visible content blocks

#### ContactUsController
- **Routes**:
  - `GET /contact-us` - Contact form page
  - `POST /contact_us` - Submit contact form
- **Features**: Creates Message/Contact records, sends email

#### EditorController
- **Routes**:
  - `GET /edit` - Load in-context editor (Vue.js)
  - `GET /edit/*path` - Wildcard for Vue routing
  - `POST /editor/page_parts` - Update page part
  - `POST /editor/theme_settings` - Update theme styles
  - `POST /editor/images` - Upload images
- **Features**: In-place page editing for admins

### API Controllers

#### Admin API (`pwb/api/v1/`)
- Private API for admin panel
- Routes for CRUD operations on models
- **Controllers**:
  - `PropertiesController` - Property CRUD
  - `PagesController` - Page management
  - `WebContentController` - Content blocks
  - `AgencyController` - Agency info
  - `TranslationsController` - Translation management
  - `ThemesController` - Theme listing
  - `ContactsController` - Contact management

#### Public API (`api_public/v1/`)
- **Purpose**: External API for public data
- **Authentication**: Optional (header `X-Website-Slug` for multi-tenant routing)
- **CORS**: Enabled for cross-origin requests
- **Controllers**:
  - `PropertiesController` - Property search/show
  - `PagesController` - Get page by ID or slug
  - `TranslationsController` - Get translations for locale
  - `LinksController` - Get navigation links
  - `SiteDetailsController` - Get website info
  - `AuthController` - Firebase auth
  - `SelectValuesController` - Get field value options
- **Response Format**: JSON

#### GraphQL (`/graphql`)
- **Purpose**: Modern API for frontend apps
- **Features**:
  - Multi-tenant routing via subdomain or `X-Website-Slug` header
  - Queries: `searchProperties`, `findProperty`, `website`, `pages`, etc.
  - Mutations: Content management (Phase 2)
  - Full tenant isolation via `StandalonePwbSchema`
- **Available in**: Development at `/graphiql` (GraphiQL explorer)
- **Context**: Passes `current_user`, `session`, `request_*` info

---

## 5. Multi-Tenancy Architecture

### Subdomain-Based Routing
```
acme.example.com => Pwb::Website with subdomain: "acme"
realtor.example.com => Pwb::Website with subdomain: "realtor"
```

### Tenant Resolution (Priority Order)
1. **Request Header** `X-Website-Slug` - Highest priority
2. **Subdomain** - Secondary
3. **Default** - `Pwb::Website.first` if unresolved

### Current Context Management
```ruby
Pwb::Current.website  # ActiveSupport::CurrentAttributes for tenant
Pwb::Current.reset    # Clear context (important in tests)
```

### Automatic Scoping
**Acts-as-Tenant Pattern**:
- All `PwbTenant::*` models are auto-scoped to `Pwb::Current.website`
- Controllers set tenant: `ActsAsTenant.current_tenant = current_website`
- Queries don't need `where(website_id: ...)` when using PwbTenant models

**Manual Scoping**:
- `Pwb::*` models (not scoped) require explicit `where(website_id: ...)`
- Useful for cross-tenant operations or admin panels

### Data Isolation Examples

**Tenant-Scoped (Safe)**:
```ruby
# In SiteAdminController (has SubdomainTenant concern)
@props = PwbTenant::Prop.all  # Only returns props for current website
```

**Cross-Tenant (Must be explicit)**:
```ruby
# In TenantAdminController (no SubdomainTenant)
@all_props = Pwb::Prop.all  # Returns ALL props, must filter manually
@props = Pwb::Prop.where(website_id: website.id)
```

**Bypass Tenant Scoping**:
```ruby
# For super-admin operations
ActsAsTenant.without_tenant { Pwb::Prop.all }
```

---

## 6. Key Features & User Workflows

### Feature 1: Property Management
**Admin Workflow**:
1. Create RealtyAsset (physical property)
2. Create SaleListing or RentalListing with pricing/marketing text
3. Upload PropPhotos (ordered)
4. Set Features (amenities/attributes)
5. Publish (make visible)

**Paths**:
- `/site_admin/props` - List properties
- `/site_admin/props/:id/edit/general` - Edit property details
- `/site_admin/props/:id/edit/text` - Edit title/description
- `/site_admin/props/:id/edit/sale_rental` - Edit sale/rental pricing
- `/site_admin/props/:id/edit/location` - Edit address/coordinates
- `/site_admin/props/:id/edit/photos` - Upload/manage images
- `/site_admin/props/:id/sale_listings` - Manage sale listing

**Key Actions**:
- CRUD property records
- Upload multiple photos with ordering
- Manage multiple listings per property (sale + rental)
- Activate/archive listings
- Apply property labels/features

### Feature 2: Page Management
**Admin Workflow**:
1. Create Page (with slug like "about-us")
2. Create/assign PageParts (content sections) to page
3. Create Content blocks with translations
4. Arrange PageParts with visibility/ordering
5. Configure navigation appearance

**Paths**:
- `/site_admin/pages` - List pages
- `/site_admin/pages/:id/edit` - Edit page
- `/site_admin/pages/:id/page_parts` - Edit page parts
- `/edit` - In-context editor (Vue.js)

**Key Actions**:
- CRUD pages with translatable fields
- Manage page parts/sections
- Set page visibility and navigation placement
- In-place editing of page content

### Feature 3: Property Search
**Public Workflow**:
1. User visits `/buy` or `/rent`
2. Enters search criteria (price, location, property type, etc.)
3. Results displayed with map
4. Clicks property for details
5. Submits inquiry form

**Paths**:
- `GET /buy` - Sale search page
- `POST /search_ajax_for_sale` - AJAX results
- `GET /properties/for-sale/:id/:title` - Property detail page

**API**:
- `GET /api_public/v1/properties` - Search with filters
- `GET /api_public/v1/properties/:id` - Get single property

### Feature 4: Contact Management
**Public Workflow**:
1. User fills contact form (general or property-specific)
2. Form submitted
3. Message created, Contact created/updated
4. Admin notified via email

**Admin Workflow**:
1. Visit `/site_admin/messages`
2. View message details
3. Track contact interactions

**Paths**:
- `POST /contact_us` - Submit general contact form
- `POST /request_property_info` - Submit property inquiry
- `GET /site_admin/messages` - View all messages
- `GET /site_admin/contacts` - View all contacts

### Feature 5: Website Customization
**Admin Workflow**:
1. Select theme (applies layout/styling)
2. Configure website settings
3. Add navigation links
4. Upload logo/branding images
5. Set up contact form fields
6. Configure property labels/features

**Paths**:
- `/site_admin/website/settings` - Website configuration
- `/site_admin/properties/settings` - Property field configuration
- `/edit` - In-context theme editor

**Key Settings**:
- Website name, company info
- Theme selection
- Default currency/language
- Supported locales
- Navigation links and structure

---

## 7. Testing Overview

### Current Test Coverage

**Test Types**:
1. **Model Tests** (`spec/models/`)
   - User authentication and authorization
   - Multi-tenancy uniqueness
   - Associations and validations
   - Property/listing logic

2. **Controller Tests** (`spec/controllers/`)
   - Admin panel access
   - API endpoints
   - Authentication checks

3. **Request/Integration Tests** (`spec/requests/`)
   - API endpoint behaviors
   - Multi-tenancy isolation
   - GraphQL queries
   - Form submission flows

4. **Feature/E2E Tests** (`spec/features/`)
   - Contact form submission
   - Theme rendering
   - Admin UI workflows
   - Session management

5. **View Tests** (`spec/views/`)
   - Template rendering
   - Theme-specific views

### Key Test Files
- `spec/models/pwb/user_spec.rb` - User model with OmniAuth
- `spec/models/pwb/multi_tenancy_uniqueness_spec.rb` - Tenant isolation
- `spec/requests/subdomain_multi_tenancy_spec.rb` - GraphQL multi-tenancy
- `spec/features/pwb/contact_forms_spec.rb` - Contact form submission
- `spec/requests/api_public/v1/properties_spec.rb` - Property API

### Test Setup
**Factories** (`spec/factories/`):
- `pwb_users` - User factory with optional membership
- `pwb_websites` - Website factory with auto-created agency
- `pwb_addresses`, `pwb_prop_photos` - Related data
- Database cleaner (Capybara tests)

**Helpers** (`spec/support/`):
- `controller_helpers` - For testing protected routes
- `feature_helpers` - For Capybara tests
- `vcr_setup` - For HTTP mocking
- `matchers/json_matchers` - JSON response validation

**Rails Helper**:
- Database transactions for test isolation
- VCR for mocking external APIs
- RSpec configuration with Capybara

---

## 8. Critical Testing Paths

### Must Test: Authentication & Authorization

1. **User Sign-up/Sign-in**
   - Create account
   - Log in with email/password
   - OmniAuth (Facebook, Firebase)
   - Session management
   - Logout

2. **Multi-Website Access**
   - User with memberships to multiple websites
   - Can only access assigned websites
   - Role-based access (owner, admin, member, viewer)
   - Cannot escalate permissions

3. **Subdomain Isolation**
   - User from acme.example.com cannot access realtor.example.com
   - Header override (X-Website-Slug) works correctly
   - GraphQL queries filtered by subdomain

### Must Test: Property Management

1. **Create/Edit Property**
   - Create RealtyAsset
   - Create SaleListing (with pricing, title, description)
   - Upload photos (ordering)
   - Apply features/labels
   - Set visibility/active status

2. **Property Search**
   - Search by price range
   - Filter by property type
   - Filter by bedrooms/bathrooms
   - Filter by location
   - Map markers update

3. **Property Display**
   - Visible properties shown, hidden properties hidden
   - Images display in order
   - Correct listing type (sale vs. rental)
   - Pricing displayed correctly
   - Agent contact info shown

### Must Test: Page/Content Management

1. **Create/Edit Pages**
   - Create page with slug
   - Add page parts (content sections)
   - Set visibility/nav placement
   - Create translatable content
   - In-context editing works

2. **Page Rendering**
   - Custom pages display correctly
   - Navigation reflects settings
   - Translations display for correct locale
   - Images in content display properly

### Must Test: Contact Management

1. **Form Submission**
   - General contact form submission
   - Property inquiry form submission
   - Creates Contact and Message records
   - Email sent to agency
   - Confirmation message shown to user

2. **Admin Message View**
   - View all messages
   - View contact details
   - Filter/search messages
   - Track contact interactions

### Must Test: Multi-Tenancy Isolation

1. **Data Isolation**
   - User from website A cannot see/edit website B's data
   - Contact B's admin should NOT see website A's properties
   - API calls return only tenant's data

2. **Cross-Tenant Security**
   - Cannot access other tenant's resources by ID
   - Cannot list other tenant's items
   - GraphQL queries respect tenant boundaries

### Must Test: API Endpoints

1. **Public API** (`/api_public/v1/`)
   - Property search with filters
   - Property detail by ID
   - Page retrieval by ID or slug
   - Translations for locale
   - All multi-tenant scoped correctly

2. **GraphQL** (`/graphql`)
   - Property search query
   - Find single property
   - Website details
   - Page queries
   - Proper tenant isolation

### Must Test: Admin Features

1. **Property Field Configuration**
   - Create custom property types/categories
   - Create feature options
   - Assign features to properties
   - Display in search/filters

2. **Website Settings**
   - Change theme
   - Update company info
   - Configure contact form fields
   - Manage navigation links

---

## 9. Key Files to Reference

### Models
- `/app/models/pwb/website.rb` - Website (tenant) root entity
- `/app/models/pwb/user.rb` - User with multi-website support
- `/app/models/pwb/user_membership.rb` - Role-based website membership
- `/app/models/pwb/realty_asset.rb` - Property normalization
- `/app/models/pwb/sale_listing.rb` - Sale transaction
- `/app/models/pwb/rental_listing.rb` - Rental transaction
- `/app/models/pwb/page.rb` - CMS page
- `/app/models/pwb/page_part.rb` - Page content section
- `/app/models/pwb/content.rb` - Translatable content
- `/app/models/pwb/contact.rb` - Contact/inquiry
- `/app/models/pwb/message.rb` - Contact message

### Controllers
- `/app/controllers/site_admin_controller.rb` - Single-tenant base
- `/app/controllers/tenant_admin_controller.rb` - Cross-tenant base
- `/app/controllers/site_admin/props_controller.rb` - Property CRUD
- `/app/controllers/site_admin/pages_controller.rb` - Page management
- `/app/controllers/pwb/props_controller.rb` - Public property display
- `/app/controllers/pwb/search_controller.rb` - Property search
- `/app/controllers/api_public/v1/base_controller.rb` - Public API base
- `/app/controllers/graphql_controller.rb` - GraphQL entry point

### Routes
- `/config/routes.rb` - All routes defined here

### Concerns
- `/app/controllers/concerns/subdomain_tenant.rb` - Tenant resolution
- `/app/controllers/concerns/admin_auth_bypass.rb` - Dev bypass for testing

### Multi-Tenancy
- `/app/models/pwb_tenant/application_record.rb` - Auto-scoped base
- `/app/models/pwb/current.rb` - CurrentAttributes for context

---

## 10. Development & Testing Best Practices

### Setting Up Tests

**Authentication in Tests**:
```ruby
# Use factory
user = FactoryBot.create(:pwb_user)
sign_in user

# Or bypass with env variable (for E2E tests)
ENV['BYPASS_ADMIN_AUTH'] = 'true'
```

**Multi-Tenancy in Tests**:
```ruby
# Always reset current tenant between tests
before(:each) do
  Pwb::Current.reset
end

# Test tenant isolation
let!(:website1) { FactoryBot.create(:pwb_website) }
let!(:website2) { FactoryBot.create(:pwb_website) }
let!(:prop1) { FactoryBot.create(:pwb_prop, website: website1) }

# Simulate subdomain
host! "tenant1.example.com"
get "/api_public/v1/properties"  # Should only return website1's properties
```

**Property Creation in Tests**:
```ruby
# Create full property with listings
prop = FactoryBot.create(:pwb_prop, :sale, website: website)
# Factory handles RealtyAsset creation if needed

# Manual creation
asset = Pwb::RealtyAsset.create!(website: website, ...)
listing = asset.sale_listings.create!(price_sale_current_cents: 50000000, ...)
photos = asset.prop_photos.create!(image: file)
```

### Common Pitfalls to Avoid

1. **Forgetting tenant scoping** - Always explicitly scope when using `Pwb::*` models
2. **Not resetting Pwb::Current** - Between tests, reset with `Pwb::Current.reset`
3. **Testing unscoped data** - Use `PwbTenant::*` models when testing with SubdomainTenant concern
4. **Not mocking external APIs** - Use VCR or WebMock for OAuth, geocoding, etc.
5. **Relying on database state** - Use factories for consistent test setup
6. **Not testing both directions** - Test that admin A cannot access tenant B, and vice versa

---

## 11. Deployment Considerations

### Environment Variables
- `RAILS_ENV` - Rails environment (development, test, production)
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Rails secret key
- `BYPASS_ADMIN_AUTH` - Dev/E2E bypass (set to 'true' to disable auth)
- `BYPASS_API_AUTH` - API auth bypass for development
- Firebase credentials for authentication
- AWS/CloudFlare credentials for storage

### Database Migrations
- Multi-tenant schema is stable
- New features: migrations for website settings, field keys
- Materialized view refresh: `refresh_properties_view` called on listing changes

### Caching
- Page part templates cached: 5s (dev), 1h (production)
- Use `Rails.cache.clear` to invalidate
- ActiveStorage for images (configurable backend)

---

## 12. Recent Changes & Current State

### Latest Upgrades (November 2024)
- Rails 8.0 upgrade
- Ruby 3.4.7
- Vite build tooling (replacing Webpacker)
- Vue.js 3 admin panel (in development)
- Quasar framework integration
- Comprehensive documentation in `docs/` folder

### Current Architecture Files
- `docs/06_Multi_Tenancy.md` - Multi-tenancy implementation
- `docs/08_PagePart_System.md` - Page part architecture
- `docs/09_Field_Keys.md` - Dynamic property field system
- `docs/10_Page_Part_Routes.md` - Page part rendering routes
- `docs/MULTIPLE_LISTINGS.md` - Sale/rental listing model

### Known Issues/TODOs
- Authorization layer (Phase 2) - Not yet enforced in site_admin
- Super-admin flag for cross-tenant ops
- Improved error handling and validation messages
- Additional GraphQL mutations for content management

---

## Summary: Test Coverage Checklist

Use this as a reference for comprehensive test coverage:

- [ ] User authentication (sign-up, sign-in, OmniAuth)
- [ ] User authorization (roles: owner, admin, member, viewer)
- [ ] Multi-website access control
- [ ] Property CRUD (create, read, update, delete)
- [ ] Property search with all filter types
- [ ] Property visibility management
- [ ] Photo uploads and ordering
- [ ] Sale and rental listings (separate and combined)
- [ ] Page CRUD
- [ ] Page part editing
- [ ] Content translations (multiple locales)
- [ ] Contact form submission (general and property-specific)
- [ ] Message management
- [ ] Navigation link configuration
- [ ] Theme switching
- [ ] Website settings management
- [ ] Multi-tenant data isolation (critical)
- [ ] API endpoints (public and admin)
- [ ] GraphQL queries and mutations
- [ ] Subdomain routing
- [ ] Cross-domain security
- [ ] Admin dashboard statistics
- [ ] Image library and management
- [ ] Email notifications
- [ ] Error handling and validation

