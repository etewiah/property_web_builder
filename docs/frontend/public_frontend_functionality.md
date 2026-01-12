# Public Frontend Functionality Guide

> Purpose: A deep, implementation-level reference so a competent JavaScript engineer can reproduce all public-facing behavior (search, listings, maps, favorites, saved searches, contact, theming, page parts, and supporting UX flows).

## 1) Architecture at a Glance
- Server-rendered Rails views with Liquid page parts; Tailwind utilities for layout/styling.
- Stimulus controllers via importmap (no bundling): map, local-favorites, dropdowns/tabs/galleries/forms.
- Leaflet + OSM tiles for maps; Rails UJS for AJAX search updates; vanilla JS glue for DOM swaps.
- Multi-tenant: all data scoping through current website; themes resolved child → parent → default.

## 2) Navigation & Routing (Public)
- Home `/` (localized: `/:locale/`): hero + ordered page parts.
- Search: `/buy`, `/rent` (localized variants) handled by `Pwb::SearchController`.
- Property detail: `/properties/:id-or-slug` (localized prefix).
- CMS pages: `/p/:page_slug`.
- Contact: `/contact-us` (localized prefix) with AJAX form post.
- Saved items (tokenized, no login):
  - Favorites list: `/my/favorites?token=...`
  - Saved searches list: `/my/saved_searches?token=...`

## 3) Search Experience (Buy/Rent)
### Layout
- ≥lg: two-column flex; filters 25% (`w-full lg:w-1/4`), results 75% (`w-full lg:w-3/4`).
- <lg: filters hidden; toggle button reveals filters; results full width.
- Map renders only when markers exist.

### Filters & Params
- Price from/to (for-sale or for-rent variants), property type, zone, locality, bedrooms, bathrooms, features (checkbox list) + features match mode (`all` vs `any`).
- Values persist via query params; direct deep links respected (e.g. `/buy?type=apartment&features=pool,garden`).

### Submission & Updates
- Forms marked `remote: true`; Rails UJS issues AJAX POST to `search_ajax_for_sale` or `search_ajax_for_rent`.
- Loading UX: spinner + opacity reduction on results during request.
- Response JS replaces `#inmo-search-results` HTML, updates map markers, dispatches `search:updated` event with markers payload.

### Results
- Grid/list cards (max 45 items currently; pagination UI hidden). Each card shows image (lazy), title, reference, beds/baths/area/garages, contextual price, optional featured badge, link on title/image/button to contextual detail URL.
- "No results" state shows helper text + clear-filters action.

### Map (Search Pages)
- Leaflet map initialized via Stimulus `map` controller; markers from server JSON: `{ id, title, show_url, image_url, display_price, position:{lat,lng} }`.
- Behavior: `fitBounds` with padding; clamp zoom to 15; scroll-wheel disabled by default to avoid scroll hijack; popup shows title link, price, thumbnail.
- Markers refreshed on AJAX via `updateMarkers` from `search:updated` detail.

## 4) Property Detail Page
- Structure: breadcrumb + meta tags; carousel (cached), facts list (cached), description, extras, social sharing; sidebar contact/request forms (sticky on lg).
- Map: rendered when `@map_markers` present; same Leaflet controller with zoom 15 default.
- Favorites modal (server-backed): posts to `/my/favorites`; pre-fills email from `localStorage`; stores email after submit; includes notes; overlay/ESC closes.

## 5) Favorites & Saved Searches (Server-Persisted)
### Data & Models
- Favorites: `Pwb::SavedProperty` (tenant-scoped wrapper under `PwbTenant`). Fields: email, provider, external_reference, property_data (cached), manage_token, price tracking fields (`original_price_cents`, `current_price_cents`, `price_changed_at`).
- Saved searches: `Pwb::SavedSearch` with JSON criteria, alert_frequency enum (none/daily/weekly), manage/unsubscribe/verify tokens, seen_property_refs.

### Flows
- Add favorite from detail: modal collects email/notes; server caches property data & price; returns manage URL `/my/favorites?token=...`.
- Favorites list: token-based access; shows all favorites for that email; supports CRUD via token.
- Saved search: modal (on external listings page) collects email + frequency; creates search with criteria; manage via token link; unsubscribe link disables alerts.
- Alerts: `Pwb::SearchAlertJob` executes saved searches, diff new refs, sends mail, records `SearchAlert` rows; daily/weekly rake schedulers available.

## 6) Favorites (Local Storage Variant)
- Stimulus `local-favorites` controller handles anonymous/local-only favorites separate from server persistence.
- Stores list under `favorites` key with expiry support; max 100 items; requires preferences-consent check via `localStorageService`.
- UI hooks: toggle heart button (aria-pressed), count badge, mini list, empty state, consent prompt. Dispatches `pwb:favorites-updated` on changes; toast feedback for add/remove/full.

## 7) Contact Forms (Public)
- Page: `/contact-us` renders page content and optional map marker for agency address when enabled.
- AJAX endpoint `contact_us_ajax`:
  - Upserts `Contact` (email, phone, name) and creates `Message` with content, locale, referer, host, IP, UA, delivery_email.
  - Validates and returns success/error partials; logs structured events.
  - Sends email async via `EnquiryMailer.general_enquiry_targeting_agency`; optional NTFY push when enabled.
  - Handles missing delivery email with fallback placeholder.

## 8) Maps Implementation Details
- Controller: `app/javascript/controllers/map_controller.js`.
- Props/values: markers array, zoom (default 13), maxZoom (18), scrollWheelZoom (false), tile URL, attribution.
- Lifecycle: waits for global `L`; fixes default icon URLs via CDN; cleans up on disconnect.
- Methods: `addMarkers` (bind popups, store refs, fit bounds), `highlightMarker` (open popup/pan on card hover), `updateMarkers` (clear + re-add), `refresh` (invalidate size), `escapeHtml` utility.

## 9) Theming & Page Parts (Keeping Content Fresh)
- Themes defined in `app/themes/config.json`; view resolution order: active theme → parent theme → default.
- Page Part Library enumerates reusable Liquid page sections (heroes, features, testimonials, CTA, stats, teams, galleries, pricing, FAQs, contact, content). Rendering priority: DB-saved page part instance if present, else template file.
- Custom Liquid tags:
  - `page_part` embeds a part; nested parts allowed.
  - `featured_properties` and `property_card` render property blocks with options (limit, type, highlighted, style/columns, show_price/location).
  - `contact_form` renders styled forms with options (style, property_id, show_phone/message, button text, success message).
- Style variables: CSS custom properties emitted from `_base_variables.css.erb`; merged from theme defaults plus per-website `style_variables`. Components reference `var(--pwb-*)`, so admin palette changes apply without recompiling Tailwind.
- Per-tenant isolation: `acts_as_tenant` on themed data; style overrides stored per site ensure edits in admin reflect immediately on public pages.

## 10) Media & Assets (Public Surface)
- Images served via Active Storage (CDN-aware when configured); property cards use lazy loading; carousels optimized height.
- Social sharing partial adds OG/Twitter meta tags on detail pages.

## 11) Caching & Performance Notes
- Fragment caches on detail page (carousel, info blocks) keyed by `property_detail_cache_key` to bust when photos/data change.
- Property cards cached per operation type.
- Map initialization avoids scroll hijack by default (scrollWheelZoom false).

## 12) Accessibility & UX Considerations
- Buttons/links include aria states on toggles (favorites heart uses `aria-pressed`).
- Keyboard escape closes modals; overlay click closes favorites modal.
- Popup HTML escaped in map controller to avoid XSS.

## 13) How to Replicate End-to-End (Checklist)
1) Render SSR pages with Tailwind classes per spec; implement two-column search layout with mobile toggle.
2) Wire forms to AJAX endpoints; swap results container HTML; emit a `search:updated` event carrying markers; refresh map markers accordingly.
3) Implement Leaflet map with OSM tiles, icon path fix, `fitBounds`, zoom clamp 15, popups with title link/price/image, scrollWheelZoom off.
4) Build card/grid rendering with lazy images, featured badge, contextual price, deep links.
5) Implement server favorites + saved searches: tokenized access, email capture, optional notes, price tracking, alert job + mailer, manage/unsubscribe links.
6) Implement local-storage favorites with consent gating, max 100, toast feedback, count badge, list rendering, global update event.
7) Contact form AJAX: create/update Contact + Message, log, enqueue mail + optional NTFY; return success/error partials.
8) Honor theme resolution order and page-part fallback; use CSS variables from merged theme + site overrides so admin edits propagate instantly.
9) Ensure per-tenant scoping across data and theme assets.

## 14) Key Source References
- Frontend overview: [docs/05_Frontend.md](docs/05_Frontend.md)
- Search spec: [docs/ui/SEARCH_UI_SPECIFICATION.md](docs/ui/SEARCH_UI_SPECIFICATION.md)
- Theming system: [docs/theming/11_Theming_System.md](docs/theming/11_Theming_System.md)
- Server favorites/saved searches: [docs/features/saved_searches_and_favorites.md](docs/features/saved_searches_and_favorites.md)
- Quick ref favorites: [docs/claude_thoughts/favorites_quick_reference.md](docs/claude_thoughts/favorites_quick_reference.md)
- Map controller: [app/javascript/controllers/map_controller.js](app/javascript/controllers/map_controller.js)
- Local favorites controller: [app/javascript/controllers/local_favorites_controller.js](app/javascript/controllers/local_favorites_controller.js)
- Property detail view (favorites modal, map usage): [app/themes/default/views/pwb/props/show.html.erb](app/themes/default/views/pwb/props/show.html.erb)
- Contact controller: [app/controllers/pwb/contact_us_controller.rb](app/controllers/pwb/contact_us_controller.rb)

## 15) Public API Coverage for JS Clients (current)
This section maps each frontend function to the available `api_public` endpoints and data contracts.

### Site boot & global config
- Site details (host, currency, area unit, company info): `GET /api_public/v1/site_details` → [app/controllers/api_public/v1/site_details_controller.rb](app/controllers/api_public/v1/site_details_controller.rb).
- Theme (palette, CSS variables, fonts, dark-mode flags, raw CSS): `GET /api_public/v1/theme` → [app/controllers/api_public/v1/theme_controller.rb](app/controllers/api_public/v1/theme_controller.rb).
- Translations (all strings for a locale): `GET /api_public/v1/translations?locale=xx` → [app/controllers/api_public/v1/translations_controller.rb](app/controllers/api_public/v1/translations_controller.rb).
- Navigation links (top/footer/etc, visibility-filtered): `GET /api_public/v1/links?placement=top_nav|footer&visible_only=true` → [app/controllers/api_public/v1/links_controller.rb](app/controllers/api_public/v1/links_controller.rb).
- Pages (by id or slug; includes page parts payload via `as_json`): `GET /api_public/v1/pages/:id` or `GET /api_public/v1/pages/slug/:slug` → [app/controllers/api_public/v1/pages_controller.rb](app/controllers/api_public/v1/pages_controller.rb).

### Search & listings
- Search config (types, price presets, features, beds/baths ranges, sort options, currency/area unit): `GET /api_public/v1/search/config` → [app/controllers/api_public/v1/search_config_controller.rb](app/controllers/api_public/v1/search_config_controller.rb).
- Select values (field-key driven dropdowns): `GET /api_public/v1/select_values?field_names=feature,property_type,...` → [app/controllers/api_public/v1/select_values_controller.rb](app/controllers/api_public/v1/select_values_controller.rb).
- Property search (server-side filtering, sorting, pagination, markers): `GET /api_public/v1/properties/search` with params `sale_or_rental`, price ranges, beds/baths, property_type, `highlighted`, `sort`, `page`, `per_page`, `limit`. Returns `data`, `map_markers`, `meta` → [app/controllers/api_public/v1/properties_controller.rb](app/controllers/api_public/v1/properties_controller.rb).
- Property detail (JSON, uses listed_properties scope): `GET /api_public/v1/properties/:id-or-slug` → [app/controllers/api_public/v1/properties_controller.rb](app/controllers/api_public/v1/properties_controller.rb).
- Widgets (embeddable, with config + properties + impression/click tracking): `GET /api_public/v1/widgets/:widget_key` and `GET /api_public/v1/widgets/:widget_key/properties`; events: `POST /impression`, `POST /click` → [app/controllers/api_public/v1/widgets_controller.rb](app/controllers/api_public/v1/widgets_controller.rb).
- Testimonials: `GET /api_public/v1/testimonials?featured_only=true&limit=...` → [app/controllers/api_public/v1/testimonials_controller.rb](app/controllers/api_public/v1/testimonials_controller.rb).

### Contact & enquiries
- General contact: `POST /api_public/v1/contact` (name, email, phone, subject, message) → [app/controllers/api_public/v1/contact_controller.rb](app/controllers/api_public/v1/contact_controller.rb).
- Property enquiry: `POST /api_public/v1/enquiries` (name, email, phone, message, property_id) → [app/controllers/api_public/v1/enquiries_controller.rb](app/controllers/api_public/v1/enquiries_controller.rb).

### Auth (public)
- Firebase login helper: `POST /api_public/v1/auth/firebase` (token[, verification_token]) → [app/controllers/api_public/v1/auth_controller.rb](app/controllers/api_public/v1/auth_controller.rb). Grants membership if needed.

## 16) Gaps & Suggested API Additions for JS Clients
- Favorites (server): add CRUD endpoints for saved properties (`/api_public/v1/favorites`) mirroring `/my/favorites` flows, including manage/unsubscribe tokens and price-change flags. Needed to avoid scraping HTML modals.
- Saved searches: add CRUD + verify/unsubscribe endpoints for saved search definitions (`/api_public/v1/saved_searches`) returning manage tokens and alert frequencies.
- Page parts feed: extend Pages API to optionally include resolved page-part data (ordered, visible-only) plus rendered Liquid-safe JSON so headless clients can render page sections without duplicating composition logic. Consider `include_parts=true` flag.
- Search facets: add lightweight `/api_public/v1/search/facets` (counts per type/zone/locality/features) to avoid heavy full-search calls when building filter UIs.
- CDN/cache hints: include `Cache-Control/ETag` on static-ish endpoints (theme, site_details, links, search/config, translations) and return `last_modified` fields for client caching. Consider `If-None-Match` handling.
- Map tiles/meta: expose map defaults (tile URL, attribution, default zoom, scroll setting) via theme or site details to keep client and SSR behavior aligned.
- Language/locale list: add `/api_public/v1/locales` returning enabled locales and default locale per site, to avoid hardcoding language options in clients.
- Media variants: for properties and testimonials, include explicit image variant URLs (thumb, medium, full) to let clients pick responsive sizes without guessing.

## 17) Performance & Caching Guidance for JS Clients
- Use ETags / Cache-Control: theme, site_details, translations, links, search/config are good candidates for long-lived caching with revalidation; properties/search should set short TTL + ETag.
- Paginate aggressively: property search already supports `page`/`per_page`; default to modest `per_page` (e.g., 12–20) and implement infinite scroll or numbered paging.
- Prefer config endpoints before UI render: hydrate UI with `site_details`, `theme`, `translations`, `search/config`, `links` before first paint to avoid layout thrash.
- Map markers: use the `map_markers` array from search API instead of recomputing; defer Leaflet load until markers are present; keep scrollWheelZoom disabled by default.
- Assets: request image variants (once exposed) appropriate to viewport; apply client-side `loading="lazy"` and responsive `srcset`.
- Reduce over-fetching: use `highlighted=true` or `limit` for hero/featured stripes; reuse widget endpoints for embeddable carousels with built-in field selection.

---

## 18) SEO Implementation (Critical for Real Estate)
Real estate websites depend heavily on organic search traffic. PWB has comprehensive SEO support.

### Sitemap & Robots.txt
- **XML Sitemap**: `GET /sitemap.xml` → [app/controllers/sitemaps_controller.rb](app/controllers/sitemaps_controller.rb).
  - Includes: homepage (priority 1.0, daily), sale properties (0.9, weekly), rental properties (0.9, weekly), static pages (0.8, monthly).
  - Auto-scoped per tenant; uses `ListedProperty` materialized view for efficiency.
  - Includes `lastmod` timestamps; eager-loads photo blobs for image sitemaps.
- **Robots.txt**: `GET /robots.txt` → [app/controllers/robots_controller.rb](app/controllers/robots_controller.rb).
  - Blocks: `/admin`, `/auth`, `/api`, `/health`, admin paths.
  - Allows: property and page paths; includes sitemap reference; sets crawl-delay (1s).

### Meta Tags (via `SeoHelper`)
- Helper: [app/helpers/seo_helper.rb](app/helpers/seo_helper.rb) (~450 lines).
- **Page Titles**: composable with site name; controller calls `set_seo(title: ...)`.
- **Meta Description**: per-page with website default fallback.
- **Canonical URL**: auto-generated stripping query params; honors `set_seo(canonical_url: ...)`.
- **Open Graph**: full set (og:type, og:title, og:description, og:url, og:site_name, og:image, og:locale).
- **Twitter Cards**: summary_large_image with title/description/image.
- **Hreflang Tags**: alternate locale URLs + x-default; auto-generated from enabled locales.
- **Meta Robots**: supports noindex/nofollow directives.
- **Verification Tags**: Google Search Console (`google-site-verification`), Bing (`msvalidate.01`) via `social_media` JSON.

### Structured Data (JSON-LD)
- **RealEstateListing**: name, description, offers (price/currency), address, geo, images, date posted.
- **Organization (RealEstateAgent)**: contact info, logo.
- **BreadcrumbList**: navigation path.
- Helper methods: `property_json_ld(prop)`, `organization_json_ld`, `breadcrumb_json_ld`.

### SEO Fields in Database
| Model | Fields |
|-------|--------|
| `pwb_props` | `seo_title`, `meta_description` |
| `pwb_pages` | `seo_title`, `meta_description` |
| `pwb_websites` | `default_meta_description`, `default_seo_title` |

### For JS Clients
- Sitemap/robots: serve from Rails; headless clients should link to origin `/sitemap.xml`.
- Meta tags: Next.js/Nuxt should call `/api_public/v1/properties/:slug` and `/api_public/v1/pages/slug/:slug` to build head tags server-side; use title/description/images from response.
- Structured data: generate JSON-LD client-side from property API response matching schema above, or add a `/api_public/v1/properties/:id/schema` endpoint returning pre-built JSON-LD.
- Canonical URLs: ensure SSR routes produce consistent, query-stripped URLs; pass `canonical` in page metadata.
- Hreflang: derive from enabled locales (gap: add `/api_public/v1/locales` endpoint).

---

## 19) Testing Strategy
Preventing regressions requires layered coverage: unit specs (RSpec), request specs (API), E2E (Playwright), and visual regression.

### Existing Test Suites
| Layer | Location | Coverage |
|-------|----------|----------|
| **RSpec Models** | `spec/models/pwb/` | SavedSearch, SavedProperty, SearchAlert, SearchFilterOption, Property Searchable concern |
| **RSpec Helpers** | `spec/helpers/seo_helper_spec.rb` | Verification meta tags (partial; needs expansion) |
| **RSpec Requests (API)** | `spec/requests/api_public/v1/` | auth, contact, links, pages, properties (search, detail, pagination, sorting), search_config, site_details, testimonials, theme, translations |
| **RSpec Controllers** | `spec/controllers/pwb/search_controller_spec.rb` | Basic buy/rent actions (minimal) |
| **Playwright E2E (public)** | `tests/e2e/public/` | property-search, property-details, property-browsing, contact-forms, theme-rendering, search-layout-compliance |
| **Playwright E2E (admin)** | `tests/e2e/admin/` | onboarding, editor, properties-settings, admin-to-site-integration, site-settings-integration |
| **Visual/Production** | `tests/e2e/visual/production.spec.js` | Screenshot comparisons |

### Running Tests
```bash
# RSpec (unit + request)
bundle exec rspec

# Playwright E2E (requires e2e env)
RAILS_ENV=e2e bin/rails playwright:reset   # seed 2 tenants
npm run test:e2e

# Lighthouse CI
npx lhci autorun --config=lighthouserc.js
node scripts/lighthouse-monitor-prod.js   # production audits
```

### Recommended Additions
1. **SEO Helper Specs** – expand `spec/helpers/seo_helper_spec.rb` to cover `seo_title`, `seo_description`, `seo_canonical_url`, `seo_meta_tags`, `property_json_ld`, hreflang generation.
2. **Sitemap/Robots Specs** – request specs for `/sitemap.xml` and `/robots.txt` validating XML structure, tenant scoping, property inclusion.
3. **Favorites API Specs** – once endpoints exist, add CRUD + token-access specs.
4. **Search Filter Specs** – verify filter combinations, price ranges, features match logic.
5. **Map Marker Specs** – confirm `map_markers` array structure and coordinate presence.
6. **Theme CSS Variable Specs** – verify `--pwb-*` variables emitted correctly per palette.
7. **Playwright SEO Checks** – E2E assertions for `<title>`, `og:*`, `canonical`, JSON-LD presence on property pages.
8. **Visual Regression** – expand screenshot baselines for all themes × key pages; integrate with CI.

### CI Pipeline Recommendations
- Run RSpec + Playwright on every PR.
- Run Lighthouse CI on staging deploy; fail on score regression > 5 pts.
- Nightly full E2E + visual diff against production subdomains.
- Post-deploy smoke test: hit `/sitemap.xml`, `/robots.txt`, homepage, one property detail.

---

## 20) Internationalization (i18n)
- Translations endpoint: `GET /api_public/v1/translations?locale=xx` returns full key tree.
- Supported locales: en, es, de, fr, nl, pt, it (configurable per website).
- Gap: add `/api_public/v1/locales` returning enabled locales + default for JS clients.
- URL structure: `/:locale/buy`, `/:locale/rent`, `/:locale/properties/...`; locale prefix optional when default.
- Hreflang tags auto-generated; ensure JS client SSR emits matching `<link rel="alternate" ...>`.

---

## 21) External Listings (Feed Integration)
- External feeds (e.g., Resales Online, Kyero) inject listings alongside internal properties.
- Display: `/external_listings/:ref?listing_type=sale|rent`.
- Favorites/saved searches work the same (provider field distinguishes source).
- Search config includes external property types/features; filters apply uniformly.
- Gap: document external feed config in site_admin and how JS clients should handle mixed sources.

---

## 22) Social Sharing
- Share partial on property detail pages emits OG + Twitter meta for link previews.
- Buttons: Facebook, Twitter/X, WhatsApp, Email (share URLs with encoded title/URL).
- Gap: add Pinterest (image-rich vertical); LinkedIn for commercial properties.

---

## 23) Accessibility (a11y) Baseline
- Aria states on interactive elements (favorites toggle `aria-pressed`, nav dropdowns `aria-expanded`).
- Keyboard: Escape closes modals; Tab order preserved.
- Contrast: Tailwind utilities; theme CSS variables should pass WCAG AA.
- Gap: full WCAG audit + axe-core integration in Playwright tests.

---

## 24) Monitoring & Analytics Hooks
- Posthog integration plan exists (docs/analytics/posthog_integration_plan.md).
- Widget endpoints support impression/click tracking; extend to general page views.
- Gap: expose analytics config (Posthog/GA4 keys) via `/api_public/v1/site_details` for JS client injection.
