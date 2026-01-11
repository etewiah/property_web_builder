# API Documentation

This section provides a detailed overview of the PropertyWebBuilder API. The API is divided into two parts: a RESTful API and a GraphQL API.

## RESTful API

The RESTful API is used to interact with the application's data from client-side applications, such as the admin panel. The API is versioned, and the current version is v1.

---

### Properties (`/api/v1/properties`)

The properties endpoint is used to manage property listings.

**Actions:**

*   **`POST /api/v1/properties/bulk_create`**: Creates multiple properties in a single request.
*   **`PATCH /api/v1/properties/:id/update_extras`**: Updates the features (extras) of a property.
*   **`POST /api/v1/properties/order_photos`**: Reorders the photos of a property.
*   **`POST /api/v1/properties/:id/add_photo_from_url`**: Adds a photo to a property from a URL.
*   **`POST /api/v1/properties/:id/add_photo`**: Uploads and adds a photo to a property.
*   **`DELETE /api/v1/properties/:prop_id/remove_photo/:id`**: Removes a photo from a property.

---

### Agency (`/api/v1/agency`)

The agency endpoint is used to manage the agency's information.

**Actions:**

*   **`GET /api/v1/agency/show`**: Returns the agency's information, as well as the website's configuration.
*   **`PUT /api/v1/agency/update`**: Updates the agency's information.
*   **`PUT /api/v1/agency/update_master_address`**: Updates the agency's primary address.

---

### Contacts (`/api/v1/contacts`)

The contacts endpoint is used to manage contacts.

**Actions:**

*   **`GET /api/v1/contacts`**: Returns a list of all contacts.
*   **`GET /api/v1/contacts/:id`**: Returns a single contact.
*   **`POST /api/v1/contacts`**: Creates a new contact.
*   **`PUT /api/v1/contacts/:id`**: Updates a contact.

---

### Links (`/api/v1/links`)

The links endpoint is used to manage navigational links.

**Actions:**

*   **`GET /api/v1/links`**: Returns a list of all links, grouped by placement.
*   **`PUT /api/v1/links/bulk_update`**: Updates multiple links in a single request.

---

### Lite Properties (`/api/v1/lite_properties`)

The lite properties endpoint is a `JSONAPI::ResourceController` that provides a lightweight version of the properties endpoint. It is used to retrieve a list of properties with a minimal set of attributes.

---

### MLS (`/api/v1/mls`)

The MLS endpoint is used to manage MLS (Multiple Listing Service) integrations.

**Actions:**

*   **`GET /api/v1/mls`**: Returns a list of all configured MLS integrations.

---

### Page (`/api/v1/page`)

The page endpoint is used to manage pages and their content.

**Actions:**

*   **`GET /api/v1/page/:page_name`**: Returns a single page.
*   **`POST /api/v1/page/:page_slug/set_photo`**: Adds a photo to a page fragment.
*   **`PUT /api/v1/page/update`**: Updates a page.
*   **`PUT /api/v1/page/:page_slug/update_page_part_visibility`**: Updates the visibility of a page fragment.
*   **`POST /api/v1/page/:page_slug/save_page_fragment`**: Saves the content of a page fragment.

---

### Select Values (`/api/v1/select_values`)

The select values endpoint is used to retrieve the possible values for select fields (dropdowns) in the admin panel.

**Actions:**

*   **`GET /api/v1/select_values/by_field_names`**: Returns a hash of arrays containing the possible values for the specified select fields.

---

### Themes (`/api/v1/themes`)

The themes endpoint is used to manage themes.

**Actions:**

*   **`GET /api/v1/themes`**: Returns a list of all available themes.

---

### Translations (`/api/v1/translations`)

The translations endpoint is used to manage translations.

**Actions:**

*   **`GET /api/v1/translations/list`**: Returns a list of all translations for a given locale.
*   **`GET /api/v1/translations/get_by_batch`**: Returns all translations for a given batch key.
*   **`DELETE /api/v1/translations/delete_translation_values`**: Deletes a translation.
*   **`POST /api/v1/translations/create_translation_value`**: Creates a new translation.
*   **`PUT /api/v1/translations/:id/update_for_locale`**: Updates a translation for a specific locale.
*   **`POST /api/v1/translations/create_for_locale`**: Creates a new translation for a specific locale.

---

### Web Contents (`/api/v1/web_contents`)

The web contents endpoint is used to manage website content, such as photos and other media.

**Actions:**

*   **`PUT /api/v1/web_contents/update_photo`**: Updates a photo for a specific content tag (e.g., "logo", "about_us_photo").
*   **`POST /api/v1/web_contents/create_content_with_photo`**: Creates a new content block with an associated photo.

---

### Website (`/api/v1/website`)

The website endpoint is used to manage the website's configuration.

**Actions:**

*   **`PUT /api/v1/website/update`**: Updates the website's configuration.

---

## Public API (Headless Frontend)

The Public API (`/api_public/v1/`) is designed for headless JavaScript frontends (Astro.js, Next.js, etc.) and does not require authentication.

### Properties

**`GET /api_public/v1/properties`** - Search properties

Query Parameters:
- `sale_or_rental` - "sale" or "rent"
- `property_type` - Filter by property type
- `for_sale_price_from/till` - Price range for sale
- `for_rent_price_from/till` - Price range for rent
- `bedrooms_from` - Minimum bedrooms
- `bathrooms_from` - Minimum bathrooms
- `highlighted` - "true" to filter featured properties
- `limit` - Limit results
- `page` - Page number (default: 1)
- `per_page` - Results per page (default: 12)
- `locale` - Locale code

Response:
```json
{
  "data": [...],
  "map_markers": [{"id": 1, "lat": 41.40, "lng": 2.17, "title": "...", "price": "..."}],
  "meta": {"total": 100, "page": 1, "per_page": 12, "total_pages": 9}
}
```

**`GET /api_public/v1/properties/:id`** - Get property by ID or slug

---

### Search Configuration

**`GET /api_public/v1/search/config`** - Get search filter options

Response:
```json
{
  "property_types": [{"key": "apartment", "label": "Apartment", "count": 15}],
  "price_options": {"sale": {"from": [...], "to": [...]}, "rent": {...}},
  "features": [{"key": "has_pool", "label": "Swimming Pool"}],
  "bedrooms": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  "bathrooms": [0, 1, 2, 3, 4, 5, 6],
  "sort_options": [{"value": "price_asc", "label": "Price: Low to High"}]
}
```

---

### Site Configuration

**`GET /api_public/v1/site_details`** - Get website configuration

Response includes: `company_display_name`, `theme_name`, `contact_info`, `social_links`, `top_nav_links`, `footer_links`, `agency`

**`GET /api_public/v1/theme`** - Get theme/CSS configuration

Response: `theme_name`, `colors`, `css_variables`, `fonts`, `dark_mode`

---

### Pages & Content

**`GET /api_public/v1/pages/by_slug/:slug`** - Get page content by slug

**`GET /api_public/v1/translations?locale=xx`** - Get all translations for a locale

**`GET /api_public/v1/links?position=top_nav`** - Get navigation links

---

### Forms

**`POST /api_public/v1/enquiries`** - Submit property enquiry
```json
{"enquiry": {"name": "...", "email": "...", "phone": "...", "message": "...", "property_id": "..."}}
```

**`POST /api_public/v1/contact`** - Submit general contact form
```json
{"contact": {"name": "...", "email": "...", "phone": "...", "subject": "...", "message": "..."}}
```

---

### Dynamic Content

**`GET /api_public/v1/testimonials`** - Get testimonials

**`GET /api_public/v1/select_values?field_names=property-types`** - Get select options

---

## GraphQL API

The GraphQL API provides a more flexible and powerful way to query the application's data.

### Queries

The following queries are available:

*   **`page(id: ID!)`**: Retrieves a single page by its ID.
*   **`find_page(slug: String!, locale: String!)`**: Retrieves a single page by its slug and locale.
*   **`search_properties(...)`**: Searches for properties based on a variety of criteria.
*   **`get_translations(locale: String!)`**: Retrieves all translations for a given locale.
*   **`get_links(placement: String!)`**: Retrieves all links for a given placement (e.g., "top_nav", "footer").
*   **`get_top_nav_links(locale: String!)`**: Retrieves all visible top navigation links for a given locale.
*   **`get_footer_links(locale: String!)`**: Retrieves all visible footer links for a given locale.
*   **`get_site_details(locale: String!)`**: Retrieves the website's configuration.
*   **`find_property(id: String!, locale: String!)`**: Retrieves a single property by its ID and locale.

---

### Mutations

The following mutations are available:

*   **`submit_listing_enquiry(propertyId: String!, contact: JSON!)`**: Submits an inquiry for a property.

---
