# Admin Pages Implementation

This document details the implementation of the admin interfaces in PropertyWebBuilder. There are currently two admin interfaces: the **Legacy Admin Panel** and the new **Vue.js Admin Panel**.

## Overview

The application supports two distinct admin experiences, routed through different controllers and layouts.

-   **Legacy Admin Panel**: Server-rendered views with jQuery/legacy JavaScript.
-   **Vue Admin Panel**: A Single Page Application (SPA) built with Vue.js 3 and Vite.

## Routing

The routes are defined in `config/routes.rb` under the `scope module: :pwb` block.

| Path | Controller | Action | Description |
| :--- | :--- | :--- | :--- |
| `/admin` | `Pwb::AdminPanelController` | `show` | Main entry point for the admin panel (currently points to legacy). |
| `/admin-1` | `Pwb::AdminPanelController` | `show_legacy_1` | Explicit route for the legacy admin panel. |
| `/v-admin` | `Pwb::AdminPanelVueController` | `show` | Entry point for the Vue.js admin panel. |

## Legacy Admin Panel

The legacy admin panel is built using standard Rails views and the asset pipeline.

### Controller
-   **Class**: `Pwb::AdminPanelController`
-   **File**: `app/controllers/pwb/admin_panel_controller.rb`
-   **Layout**: `pwb/admin_panel`

### Views & Layouts
-   **Layout**: `app/views/layouts/pwb/admin_panel.html.erb`
-   **View**: `app/views/pwb/admin_panel/show.html.erb`

### Assets
The legacy JavaScript and CSS are managed via the Rails Asset Pipeline.
-   **JavaScript Entry**: `app/assets/javascripts/pwb_admin_panel/application.js`
    -   Requires `pwb-admin-vendor` and `pwb-admin`.

## Vue.js Admin Panel

The new admin panel is a Vue.js SPA served via Vite.

### Controller
-   **Class**: `Pwb::AdminPanelVueController`
-   **File**: `app/controllers/pwb/admin_panel_vue_controller.rb`
-   **Layout**: `pwb/admin_panel_vue`

### Views & Layouts
-   **Layout**: `app/views/layouts/pwb/admin_panel_vue.html.erb`
    -   Includes the Vite entry point: `<%= vite_javascript_tag 'v-admin' %>`
    -   Mounts the Vue app to `<div id="app"></div>`.

### Frontend Architecture

The Vue application is located in `app/frontend`.

-   **Entry Point**: `app/frontend/entrypoints/v-admin.js`
-   **App Source**: `app/frontend/v-admin-app`

#### Directory Structure (`app/frontend/v-admin-app/src`)

-   **`router/`**: Contains Vue Router configuration.
    -   `routes.js`: Defines the client-side routes.
-   **`pages/`**: Top-level page components (views).
    -   `AgencyEdit.vue`
    -   `PagesEdit.vue`
    -   `TranslationsEdit.vue`
    -   `WebsiteEdit.vue`
    -   `PropertiesList.vue`
    -   `PropertyEdit.vue`
-   **`components/`**: Reusable Vue components, organized by feature (e.g., `website`, `pages`, `translations`, `properties`).
-   **`layouts/`**: App layouts (e.g., `MainLayout.vue`).

#### Client-Side Routing

The Vue Router handles navigation within the `/v-admin` path. Key routes include:

| Path | Component | Description |
| :--- | :--- | :--- |
| `/agency` | `AgencyEdit.vue` | Edit agency details (General, Location). |
| `/pages/:pageName` | `PagesEdit.vue` | Edit dynamic pages. |
| `/translations` | `TranslationsEdit.vue` | Manage translations. |
| `/website/settings` | `WebsiteEdit.vue` | Configure website settings (General, Appearance, Navigation). |
| `/properties/list/all` | `PropertiesList.vue` | List all properties. |
| `/properties/s/:prop_id` | `PropertyEdit.vue` | Edit a specific property. |

## API Interaction

Both admin panels interact with the backend via the API defined in `app/controllers/pwb/api/v1`.

-   **Namespace**: `api/v1`
-   **Key Controllers**:
    -   `AgencyController`: Agency details.
    -   `WebsiteController`: Website settings.
    -   `PageController`: Page content and structure.
    -   `TranslationsController`: I18n translations.
    -   `PropertiesController`: Property management.
