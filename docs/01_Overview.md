# PropertyWebBuilder Documentation

## Overview

Welcome to the PropertyWebBuilder documentation. This documentation covers PropertyWebBuilder v2.0.0, a major release representing a complete architectural overhaul from the original Rails engine.

PropertyWebBuilder is a multi-tenant Ruby on Rails application for creating real estate websites. It is designed to be a flexible and extensible platform that can host multiple real estate websites from a single installation, each with their own properties, themes, and configurations.

### Key Concepts

- **Multi-Tenancy:** Each website is a tenant. The `acts_as_tenant` gem ensures data isolation between tenants.
- **Dual Admin Interfaces:** `site_admin` for super admins (cross-tenant), `tenant_admin` for per-tenant management.
- **Property Model:** Properties are `RealtyAsset` records with separate `SaleListing` and `RentalListing` records for different listing types.
- **Theming:** Tailwind CSS-based themes with CSS variables, Liquid templates, and a page parts system.

### Documentation Sections

*   **Overview:** High-level architecture and main components.
*   **Data Models:** Database schema, models, and associations including the tenant-scoped `PwbTenant::` namespace.
*   **Controllers:** Controller actions, request handling, and the dual admin architecture.
*   **API:** RESTful and GraphQL API documentation.
*   **Frontend:** Vue.js 3 admin applications and Tailwind CSS public themes.
*   **Multi-Tenancy:** How tenant isolation works with `acts_as_tenant`.
*   **Theming System:** Creating and customizing themes.
*   **Authentication:** Firebase and Devise authentication options.

## Architecture

PropertyWebBuilder is a multi-tenant Ruby on Rails application with a modern tech stack:

- **Backend:** Ruby on Rails 8.0, Ruby 3.4.7, PostgreSQL
- **Multi-Tenancy:** `acts_as_tenant` gem with `Pwb::` (base) and `PwbTenant::` (tenant-scoped) namespaces
- **Frontend:** Rails Views (ERB) with Tailwind CSS, Vue.js 3 with Quasar Framework for admin
- **Build Tool:** Vite with vite-plugin-ruby
- **API:** RESTful API for admin panel and external integrations, GraphQL API for flexible data querying
- **Authentication:** Firebase authentication with Devise fallback
- **File Storage:** ActiveStorage with S3/Cloudflare R2 support
- **Translations:** Mobility gem for multilingual content

## Version History

- **v2.0.0 (December 2024):** Major rewrite - standalone app, multi-tenancy, Rails 8, Tailwind CSS
- **v1.4.0 (February 2020):** Last Rails engine version with Cloudinary and Globalize

