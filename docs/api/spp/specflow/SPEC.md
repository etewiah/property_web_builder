# SPP-PWB Integration — Project Specification

## Vision

Enable PropertyWebBuilder (PWB) tenants to publish standalone marketing microsites for individual properties via SinglePropertyPages (SPP), with PWB serving as the data backend and SPP operating independently on its own domain.

## Problem Statement

PWB currently generates property listing pages as part of a multi-property website. These pages are functional but generic — they share the site's layout and cannot be individually branded or optimized for marketing. Agents who want to promote a premium property need a dedicated, rich marketing page on its own URL, with curated content, photos, and features — without leaving the PWB ecosystem for data management.

**Affected users:** Real estate agents and agencies using PWB who want premium single-property marketing pages.

## Success Criteria

- [ ] An agent can publish an SPP marketing page for any property from PWB, receiving a live URL
- [ ] An agent can unpublish an SPP page without affecting the PWB listing
- [ ] A property can have both a sale and rental SPP page published simultaneously, each independent
- [ ] Each SPP listing has its own price, marketing texts, curated photo selection/order, and highlighted features
- [ ] Visitor enquiries submitted on SPP pages are stored in PWB and retrievable via the leads endpoint
- [ ] PWB's property page sets canonical URL to SPP when an SPP listing is active (no SEO duplication)
- [ ] CORS is configured so SPP's browser can POST enquiries to PWB's public API
- [ ] SPP authenticates to PWB's manage API via API key (server-to-server, key never exposed to browser)
- [ ] SppListing follows the same model pattern as SaleListing/RentalListing (ListingStateable, concerns, Mobility translations)
- [ ] The data model includes a general-purpose JSONB expansion field (`extra_data`) for future needs

## Constraints

- **Technical:** PWB is a Rails 8 multi-tenant app. SPP is Astro.js. Communication is via REST API.
- **Multi-tenancy:** All queries must be scoped to `current_website`. SPP configuration is per-tenant in `client_theme_config`.
- **Existing patterns:** SppListing must follow the established listing model pattern (ListingStateable, NtfyListingNotifications, RefreshesPropertiesView, Mobility).
- **No new auth system:** Use existing `WebsiteIntegration` model for API key storage.
- **No new CORS gem:** Use existing `rack-cors` (v3.0) already configured in the app.
- **Server-side keys:** API keys are used only in SPP's Astro server routes, never in browser JavaScript.

## Non-Goals

- SPP frontend implementation (Astro.js side) — this spec covers only the PWB backend
- Admin UI for managing SPP listings within PWB's admin panel
- Webhook-based real-time data push (Phase 2 — deferred)
- Multi-locale SPP pages with hreflang coordination (deferred)
- Custom per-property SPP domains (Approach B dynamic CORS — deferred)
- SPP page analytics or tracking integration

## Open Questions

- Should the publish endpoint pre-populate the SppListing's price from the corresponding SaleListing/RentalListing if one exists?
- Should the enquiry form include a `source` field to distinguish SPP leads from PWB leads?
- What is the exact SPP domain pattern for production? (Determines CORS regex)

## Fidelity Level

**Alpha** — Working integration between two production systems. Needs to be correct and secure, but admin UI and webhook infrastructure can be deferred.

## Technology Stack

- **Language:** Ruby 3.x
- **Framework:** Rails 8
- **Database:** PostgreSQL (UUID primary keys, JSONB columns)
- **Gems:** money-rails (monetize), mobility (translations), rack-cors, sidekiq (jobs)
- **Testing:** RSpec + FactoryBot
