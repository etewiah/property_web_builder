# Vue App Documentation (`v-public-app`)

## Overview

The `v-public-app` is a Vue 3 application located at `app/frontend/v-public-app`. It serves as the public-facing frontend for the Property Web Builder application, handling property searches, listings, and dynamic content pages.

It is integrated into the Rails application using **Vite** (via `vite_rails` and `vite-plugin-ruby`) and uses **Quasar Framework** for UI components.

## Tech Stack

-   **Framework**: Vue.js 3
-   **UI Library**: Quasar Framework
-   **Build Tool**: Vite
-   **Routing**: Vue Router
-   **State Management**: Custom reactive providers (Composition API)
-   **Data Fetching**: GraphQL (via `@urql/vue`)
-   **Maps**: `@fawmi/vue-google-maps`

## Directory Structure

```
app/frontend/v-public-app/
├── src/
│   ├── components/       # Vue components (Pages, Cards, Widgets)
│   ├── compose/          # Composition API logic and state providers
│   ├── layouts/          # App layouts (e.g., PublicLayout)
│   ├── router/           # Router configuration
│   ├── VPublicApp.vue    # Root component
│   └── v-public.css      # Global styles
```

## Entrypoint

The application entrypoint is **`app/frontend/entrypoints/v-public.js`**.

-   **Mount Point**: `#app`
-   **Initialization**:
    -   Creates the Vue app using `VPublicApp.vue`.
    -   Installs plugins: `Quasar`, `VueGoogleMaps`, `urql`, `router`.
    -   Configures URQL client with `/graphql` endpoint.

## Routing

Routes are defined in **`src/router/routes.js`**. The app uses lazy loading for route components.

**Key Routes:**
-   `/`: Root path, uses `PublicLayout`.
    -   `""` (Home): Renders `PageContainer`.
    -   `/:publicLocale`: Locale-prefixed routes (e.g., `/en`, `/es`).
        -   `""` (Locale Home): Renders `PageContainer`.
        -   `p/:pageSlug`: Dynamic pages (e.g., `/en/p/about-us`), renders `PageContainer`.
        -   `contact-us`: Renders `SearchView`.
        -   `for-sale`: Renders `SearchView` (Sale mode).
        -   `for-sale/:listingSlug`: Renders `ListingView`.
        -   `for-rent`: Renders `SearchView` (Rental mode).
        -   `for-rent/:listingSlug`: Renders `ListingView`.

## State Management & Data

The app uses a combination of **URQL** for data fetching and **Custom Providers** for global state.

### GraphQL (URQL)
Components fetch data directly using `useQuery`.
-   **`VPublicApp.vue`**: Fetches global site details (`getSiteDetails`) and translations (`getTranslations`) based on the current locale.
-   **`PageContainer.vue`**: Fetches page-specific content (`findPage`) using `pageSlug`.
-   **`SearchView.vue`**: Fetches properties (`searchProperties`) based on search criteria.

### Custom Providers (`src/compose`)
-   **`sitedetails-provider.js`**: Manages global site state like navigation links (`topNavLinkItems`, `footerNavLinkItems`), agency details, and supported locales. It exposes a `readonly` state object and setter methods.
-   **`localise-provider.js`**: Likely manages translation strings and localization logic (injected into components).

## Key Components

### `VPublicApp.vue`
The root component.
-   Watches route changes to update `publicLocale`.
-   Fetches initial data (site details, translations).
-   Populates `sitedetailsProvider` and `localiseProvider` with fetched data.
-   Handles global GraphQL errors.

### `PageContainer.vue`
Renders dynamic content pages.
-   Fetches page data using `findPage` query.
-   Renders raw HTML content from `pageContents`.

### `SearchView.vue`
Handles property searches for both Sales and Rentals.
-   Determines mode (Sale vs. Rent) based on route name.
-   Contains `VerticalSearchForm` for filtering.
-   Displays results using `ListingsSummaryCard`.
-   Fetches data using `searchProperties` query.

## Configuration

-   **`vite.config.ts`** (Root): Configures Vite with `RubyPlugin`, `VuePlugin`, and `quasar` plugin.
-   **`package.json`** (Root): Lists dependencies including `vue`, `quasar`, `@urql/vue`, `vite`, etc.
