# Admin Functionality Gap Analysis

This document details the functionality present in the legacy admin interface (`/admin/` - Ember.js) that is currently missing or incomplete in the new admin interface (`/v-admin/` - Quasar/Vue.js).

## High-Level Summary

The new Quasar admin implements the core CRUD functionality for Properties, Clients, Contacts, and basic Agency/Website settings. However, it lacks several advanced features, specifically in **Website Configuration** (theme customization, page-specific settings), **Import/Export** capabilities, and **Relationship Management** (linking owners to properties, viewing client properties).

## Detailed Gap Analysis

### 1. Properties Management (`/admin/properties`)

The core property editing is well-implemented in Quasar, but the following are missing:

*   **Owner Assignment**: The legacy admin has an **Owner Tab** (`owner-tab.hbs`) that allows searching for and assigning a Client/Contact as the owner of a property. This is completely missing in Quasar.
*   **Detailed Sale/Rent Fields**: The legacy admin's **Venta Tab** (`venta-tab.hbs`) appears to have more granular control over sale and rental details (e.g., "Situación llaves" - Key location, specific fee percentages) which might be simplified or missing in Quasar's **Pricing** tab.
*   **Text/Description Tab**: Legacy admin separates text descriptions into a specific tab (`text-tab.hbs`), whereas Quasar merges this into the **General** tab. This is a design choice but ensures all multilingual fields are accessible.

### 2. Website Management (`/admin/website`)

This is the area with the most significant gaps. The legacy admin provides extensive configuration options via `tabs-website` which are largely missing in Quasar.

**Missing Tabs/Functionality:**
*   **About Us Tab** (`about-us-tab.hbs`): Configuration for the "About Us" page/section.
*   **Advanced Tab** (`advanced-tab.hbs`): Likely contains advanced settings, scripts, or raw configuration.
*   **Appearance Tab** (`appearance-tab.hbs`): Theme customization, colors, fonts, and layout options.
*   **Home Tab** (`home-tab.hbs`): Configuration specifically for the homepage layout and content.
*   **Landing Carousel** (`landing-carousel-tab.hbs`): Management of the homepage slider/carousel images and text.
*   **Legal Tab** (`legal-tab.hbs`): Configuration for legal notice, privacy policy, and cookies.
*   **Search Tab** (`search-tab.hbs`): Configuration for the property search engine (filters, layout).
*   **Content Area Cols** (`content-area-cols-tab.hbs`): Layout configuration for content columns.
*   **Navigation**: Quasar has a placeholder "Coming soon" for the Navigation menu builder. Legacy admin allows managing menu items.

### 3. Import/Export (`/admin/io`)

Quasar implements basic CSV upload, but lacks the broader integration features of the legacy admin.

**Missing Functionality:**
*   **API Importer** (`api-importer.hbs`): Ability to import properties via external APIs.
*   **Website Importer** (`website-importer.hbs`): Functionality to scrape or import from other websites.
*   **MLS Integration** (`mls-importer.hbs`): While Quasar has an "MLS CSV" option, the legacy admin likely supports more direct MLS connections or advanced mapping.
*   **Import Preview** (`preview-properties.hbs`): The legacy admin allows previewing properties *before* final import. Quasar currently processes the upload immediately without a preview step.

### 4. Agency Settings (`/admin/agency`)

*   **User Profile**: The legacy admin includes a **User Tab** (`user-tab.hbs`) within the Agency section (or as a separate route) to manage the current user's profile (password, name, etc.). This is missing in Quasar.

### 5. Client Management (`/admin/clients`)

*   **Client Properties**: The legacy admin has a **Properties Tab** (`properties-tab.hbs`) in the Client Edit view, which likely lists properties owned or rented by that client. This relationship view is missing in Quasar.

## Prioritized Recommendations

To bring the new admin up to parity, the following features should be prioritized:

1.  **Owner Assignment**: Critical for property management CRM features.
2.  **Navigation Builder**: Essential for website content management.
3.  **Appearance/Theme Settings**: Users need to customize the look of their public site.
4.  **Home & Carousel Settings**: The homepage is the most important page for users; they need control over it.
5.  **Import Preview**: Safely importing data is crucial to prevent database pollution.
