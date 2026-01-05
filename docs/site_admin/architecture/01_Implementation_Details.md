# Admin Pages Implementation

This document details the implementation of the admin interfaces in PropertyWebBuilder.

## Overview

The application's admin interface is built with standard Rails conventions, using server-rendered ERB views. Interactivity is provided by the Stimulus JavaScript framework.

-   **Admin Panel**: Server-rendered views with Stimulus.js for interactivity.

## Routing

The routes are defined in `config/routes.rb` under the `scope module: :pwb` block. The primary admin interface is located at `/site_admin`.

| Path | Controller | Action | Description |
| :--- | :--- | :--- | :--- |
| `/site_admin` | `Pwb::SiteAdmin::DashboardController` | `show` | Main entry point for the admin panel. |
| `/tenant_admin` | `Pwb::TenantAdmin::DashboardController` | `show` | Entry point for the super admin panel. |

## Admin Panel

The admin panel is built using standard Rails views and the asset pipeline.

### Controller
-   **Class**: `Pwb::SiteAdmin::DashboardController` (and other controllers under `Pwb::SiteAdmin`)
-   **Layout**: `pwb/site_admin`

### Views & Layouts
-   **Layout**: `app/views/layouts/pwb/site_admin.html.erb`
-   **Views**: `app/views/pwb/site_admin/`

### Assets
The JavaScript and CSS are managed via the Rails Asset Pipeline with importmaps and Tailwind CSS.
-   **JavaScript Entry**: `app/javascript/application.js`
-   **Stimulus Controllers**: `app/javascript/controllers/`

## API Interaction

Both admin panels interact with the backend via the API defined in `app/controllers/pwb/api/v1`.

-   **Namespace**: `api/v1`
-   **Key Controllers**:
    -   `AgencyController`: Agency details.
    -   `WebsiteController`: Website settings.
    -   `PageController`: Page content and structure.
    -   `TranslationsController`: I18n translations.
    -   `PropertiesController`: Property management.
