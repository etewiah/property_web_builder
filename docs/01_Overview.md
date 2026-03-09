# PropertyWebBuilder Documentation

## Overview

Welcome to the PropertyWebBuilder documentation. This documentation covers PropertyWebBuilder v2.0.0, a major release representing a complete architectural overhaul from the original Rails engine.

PropertyWebBuilder is a multi-tenant Ruby on Rails application for creating real estate websites. It is designed to be a flexible and extensible platform that can host multiple real estate websites from a single installation, each with their own properties, themes, and configurations.

### Key Concepts

- **Multi-Tenancy:** Each website is a tenant. The `acts_as_tenant` gem ensures data isolation between tenants.
- **Dual Admin Interfaces:** `site_admin` for per-website management and `tenant_admin` for cross-tenant/platform operations.
- **Property Model:** Properties are `RealtyAsset` records with separate `SaleListing` and `RentalListing` records for different listing types.
- **Theming:** Tailwind CSS-based themes with CSS variables, Liquid templates, and a page parts system.

### Documentation Sections

*   **Overview:** High-level architecture and main components.
*   **Data Models:** Database schema, models, and associations including the tenant-scoped `PwbTenant::` namespace.
*   **Controllers:** Controller actions, request handling, and the dual admin architecture.
*   **API:** REST-first API documentation plus notes for deprecated GraphQL surfaces.
*   **Frontend:** Tailwind CSS public themes.
*   **Multi-Tenancy:** How tenant isolation works with `acts_as_tenant`.
*   **Theming System:** Creating and customizing themes.
*   **Authentication:** Firebase and Devise authentication options.

## Architecture

PropertyWebBuilder is a multi-tenant Ruby on Rails application with a modern tech stack:

- **Backend:** Ruby on Rails 8.1, Ruby 3.4.7, PostgreSQL
- **Multi-Tenancy:** `acts_as_tenant` gem with `Pwb::` (base) and `PwbTenant::` (tenant-scoped) namespaces
- **Frontend:** Rails Views (ERB) with Tailwind CSS for admin and public themes
- **API:** RESTful APIs for admin panel and external integrations, with deprecated GraphQL support retained only for legacy clients
- **Authentication:** Firebase authentication with Devise fallback
- **File Storage:** ActiveStorage with S3/Cloudflare R2 support
- **Translations:** Mobility gem for multilingual content

## Version History

- **v2.0.0 (December 2024):** Major rewrite - standalone app, multi-tenancy, Rails 8, Tailwind CSS
- **v1.4.0 (February 2020):** Last Rails engine version with Cloudinary and Globalize

