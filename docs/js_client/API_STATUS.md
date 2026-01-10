# PropertyWebBuilder API Support - Current State

**Last Updated**: 2026-01-10

## Overview

PropertyWebBuilder has **THREE active API systems**:

| API | Base Path | Purpose | Auth Required |
|-----|-----------|---------|---------------|
| Public REST | `/api_public/v1/` | Read-only property/content data | No |
| Admin REST | `/api/v1/` | CRUD operations for admin | Yes (session) |
| Signup | `/api/signup/` | Tenant provisioning flow | Partial |
| GraphQL | `/graphql` | **DEPRECATED** | - |

**For Next.js Client**: Use only the **Public REST API** (`/api_public/v1/`)

---

## 1. Public REST API (`/api_public/v1/`)

**Status**: ✅ Active and Documented
**Purpose**: Read-only API for property listings, site content
**Swagger Docs**: `swagger/v1/api_public_swagger.yaml`

### Properties Endpoints

#### Search Properties
```
GET /api_public/v1/properties
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `locale` | string | Language code (en, es, etc.) |
| `sale_or_rental` | string | Filter: "sale" or "rental" |
| `property_type` | string | Filter: "apartment", "house", etc. |
| `for_sale_price_from` | integer | Min sale price (cents) |
| `for_sale_price_till` | integer | Max sale price (cents) |
| `for_rent_price_from` | integer | Min rental price (cents) |
| `for_rent_price_till` | integer | Max rental price (cents) |
| `bedrooms_from` | integer | Min bedrooms |
| `bathrooms_from` | integer | Min bathrooms |
| `page` | integer | Page number (default: 1) |
| `per_page` | integer | Results per page (default: 20) |

**Response:**
```json
{
  "properties": [
    {
      "id": 123,
      "slug": "modern-apartment-downtown",
      "title": "Modern Apartment in Downtown",
      "description": "Beautiful 2BR apartment...",
      "price_sale_current_cents": 25000000,
      "price_rental_monthly_current_cents": null,
      "currency": "EUR",
      "area_unit": "sqm",
      "constructed_area": 85,
      "count_bedrooms": 2,
      "count_bathrooms": 1,
      "count_garages": 1,
      "for_sale": true,
      "for_rent": false,
      "latitude": 40.4168,
      "longitude": -3.7038,
      "prop_photos": [
        { "id": 1, "image": "https://..." }
      ]
    }
  ],
  "meta": {
    "total": 150,
    "page": 1,
    "per_page": 20,
    "total_pages": 8
  }
}
```

#### Get Single Property
```
GET /api_public/v1/properties/:id
GET /api_public/v1/properties/:slug
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `locale` | string | Language code |

### Site Content Endpoints

#### Get Page
```
GET /api_public/v1/pages/:id
GET /api_public/v1/pages/by_slug/:slug
```

**Response:**
```json
{
  "id": 1,
  "slug": "home",
  "title": "Home",
  "meta_title": "Welcome to Our Real Estate",
  "meta_description": "Find your dream property...",
  "page_parts": [
    {
      "key": "hero_centered",
      "part_type": "heroes/hero_centered",
      "content": {
        "title": "Find Your Dream Home",
        "subtitle": "Browse our listings",
        "background_image": "https://..."
      },
      "position": 1
    }
  ]
}
```

#### Get Navigation Links
```
GET /api_public/v1/links
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `position` | string | Filter: "top_nav", "footer" |

#### Get Site Configuration
```
GET /api_public/v1/site_details
```

**Response:**
```json
{
  "name": "Example Real Estate",
  "logo_url": "https://...",
  "primary_color": "#3B82F6",
  "contact_email": "info@example.com",
  "contact_phone": "+34 123 456 789",
  "default_currency": "EUR",
  "default_area_unit": "sqm",
  "locales": ["en", "es"],
  "default_locale": "en"
}
```

#### Get Select Values (Dropdowns)
```
GET /api_public/v1/select_values
```

Returns property types, locations, and other dropdown options.

#### Get Translations
```
GET /api_public/v1/translations
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `locale` | string | Language code |

### Features
- ✅ OpenAPI/Swagger documented
- ✅ No authentication required (public data)
- ✅ JSON responses
- ✅ Multi-language support via `locale` param
- ✅ CORS enabled for client-side requests
- ✅ Pagination with meta information

---

## 2. Admin REST API (`/api/v1/`)

**Status**: ✅ Active  
**Purpose**: Admin operations (CRUD for site content, properties, etc.)  
**Authentication**: Required (session-based or token)

### Endpoints

#### Translations Management
- `GET /api/v1/translations/list/:locale` - List translations
- `GET /api/v1/translations/batch/:batch_key` - Get batch translations
- `POST /api/v1/translations` - Create translation
- `POST /api/v1/translations/create_for_locale` - Create for locale
- `PUT /api/v1/translations/:id/update_for_locale` - Update for locale
- `DELETE /api/v1/translations/:id` - Delete translation

#### Agency/Website Management
- `GET /api/v1/agency` - Get agency details
- `PUT /api/v1/agency` - Update agency
- `PUT /api/v1/website` - Update website settings
- `PUT /api/v1/master_address` - Update master address
- `GET /api/v1/infos` - Get agency info

#### Pages/CMS
- `GET /api/v1/pages/:page_name` - Get page
- `PUT /api/v1/pages` - Update page
- `PUT /api/v1/pages/page_part_visibility` - Toggle page part
- `PUT /api/v1/pages/page_fragment` - Save page fragment
- `POST /api/v1/pages/photos/:page_slug/:page_part_key/:block_label` - Upload photo

#### Properties (via additional controllers)
- Properties CRUD via `Pwb::Api::V1::PropertiesController`
- Lite properties via `Pwb::Api::V1::LitePropertiesController`

#### Other Resources
- Contacts - `Pwb::Api::V1::ContactsController`
- Links - `Pwb::Api::V1::LinksController`
- Themes - `Pwb::Api::V1::ThemesController`
- MLS data - `Pwb::Api::V1::MlsController`

### Features
- ✅ Full CRUD operations
- ✅ Multi-tenant aware
- ⚠️ Requires authentication
- ⚠️ Less documented than public API

---

## 3. Signup/Provisioning API (`/api/signup/`)

**Status**: ✅ Active  
**Purpose**: Tenant signup and website provisioning  
**Used By**: External signup UIs, signup components

### Endpoints

#### Signup Flow
- `POST /api/signup/start` - Start signup (create user + reserve subdomain)
- `POST /api/signup/configure` - Configure site settings
- `POST /api/signup/provision` - Provision website
- `GET /api/signup/status` - Check provisioning status

#### Subdomain Management
- `GET /api/signup/check_subdomain` - Check availability
- `GET /api/signup/suggest_subdomain` - Get suggestions
- `GET /api/signup/lookup_subdomain` - Lookup existing

#### Email Verification
- `GET /api/signup/verify_email` - Verify email token
- `POST /api/signup/resend_verification` - Resend email
- `POST /api/signup/complete_registration` - Complete after verification

#### Metadata
- `GET /api/signup/site_types` - Get available site types

### Features
- ✅ Multi-step signup process
- ✅ Email verification
- ✅ Subdomain management
- ✅ Async provisioning with status tracking

---

## 4. GraphQL API (DEPRECATED)

**Status**: ❌ Deprecated (December 2024)  
**Purpose**: Query-based API (formerly used)  
**Location**: `app/graphql/`

### Deprecation Notice

From `app/graphql/DEPRECATED.md`:

> The GraphQL API is **deprecated** and will no longer be actively maintained. 
> New features should use the REST API endpoints instead.

### Migration Path

| GraphQL Query | REST Equivalent |
|--------------|-----------------|
| `search_properties` | `GET /api_public/v1/properties` |
| `find_property` | `GET /api_public/v1/properties/:id` |
| `get_site_details` | `GET /api_public/v1/website` |
| `get_top_nav_links` | `GET /api_public/v1/links?position=top_nav` |
| `get_footer_links` | `GET /api_public/v1/links?position=footer` |

### Endpoints (Still Functional)
- `POST /graphql` - GraphQL endpoint (deprecated)
- `GET /graphiql` - GraphiQL IDE (dev only, deprecated)

**Recommendation**: Do not use for new integrations.

---

## API Controllers Summary

```
app/controllers/
├── api/
│   ├── base_controller.rb (base for all API controllers)
│   └── signup/
│       └── signups_controller.rb (signup API)
├── api_public/
│   └── v1/
│       ├── properties_controller.rb
│       ├── pages_controller.rb
│       ├── links_controller.rb
│       ├── site_details_controller.rb
│       ├── select_values_controller.rb
│       ├── translations_controller.rb
│       ├── auth_controller.rb
│       └── widgets_controller.rb
└── pwb/api/v1/
    ├── agency_controller.rb
    ├── contacts_controller.rb
    ├── links_controller.rb
    ├── lite_properties_controller.rb
    ├── mls_controller.rb
    ├── page_controller.rb
    ├── properties_controller.rb
    ├── select_values_controller.rb
    ├── themes_controller.rb
    ├── translations_controller.rb
    └── website_controller.rb
```

---

## Documentation

### Swagger/OpenAPI
- ✅ `swagger/v1/api_public_swagger.yaml` - Public API docs
- ✅ `swagger/v1/swagger.yaml` - Main API docs
- Access via: `/api-docs` (if rswag gem configured)

### Test Coverage
- ✅ Public API: `spec/requests/api_public/`
- ✅ Admin API: `spec/requests/pwb/api/`
- ✅ Signup API: `spec/requests/api/signup/`
- ⚠️ GraphQL: `spec/graphql/` (deprecated, may not be maintained)

---

## Authentication

### Public API (`/api_public/v1/`)
- No authentication required
- Read-only access
- Rate limiting may apply

### Admin API (`/api/v1/`)
- Session-based authentication (cookies)
- Token authentication (if configured)
- Requires admin permissions

### Signup API (`/api/signup/`)
- No authentication for initial steps
- Email verification required
- Creates authenticated session on completion

---

## Common Response Formats

### Success Response
```json
{
  "data": { ... },
  "meta": {
    "total": 100,
    "page": 1,
    "per_page": 20
  }
}
```

### Error Response
```json
{
  "error": "Resource not found",
  "status": 404
}
```

---

## Usage Examples

### Public API - Search Properties
```bash
curl https://yourdomain.com/api_public/v1/properties?locale=en&page=1&per_page=10
```

### Admin API - Update Agency
```bash
curl -X PUT https://yourdomain.com/api/v1/agency \
  -H "Content-Type: application/json" \
  -H "Cookie: your_session_cookie" \
  -d '{"agency": {"name": "New Name"}}'
```

### Signup API - Check Subdomain
```bash
curl https://yourdomain.com/api/signup/check_subdomain?subdomain=mysite
```

---

## Recommendations

### For Public Data Integration
✅ Use `/api_public/v1/` endpoints  
✅ Consult `swagger/v1/api_public_swagger.yaml`  
✅ No authentication needed

### For Admin Operations
✅ Use `/api/v1/` endpoints  
⚠️ Implement proper authentication  
⚠️ Check permissions before exposing

### For New Signups
✅ Use `/api/signup/` flow  
✅ Follow multi-step process  
✅ Implement email verification

### For Existing GraphQL Users
⚠️ Plan migration to REST  
❌ Do not build new features on GraphQL  
✅ Use migration table above

---

## Future Plans

- [ ] Complete OpenAPI docs for admin API
- [ ] Add API rate limiting
- [ ] Add API versioning strategy (v2)
- [ ] Add webhook support for events
- [ ] Possibly remove GraphQL in future major version

---

**Current State**: ✅ REST APIs are active, documented, and well-tested. GraphQL is deprecated but still functional.

