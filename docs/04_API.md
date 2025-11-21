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
