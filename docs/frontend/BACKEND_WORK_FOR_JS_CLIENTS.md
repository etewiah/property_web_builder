# Backend Work Required for JS Client Support

> This document details the Rails backend work needed to fully support headless JavaScript clients (Next.js, Nuxt, etc.) based on gaps identified in [public_frontend_functionality.md](public_frontend_functionality.md).

---

## Priority Overview

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| **P0** | Favorites API CRUD | 2-3 days | Enables favorites without HTML scraping |
| **P0** | Saved Searches API CRUD | 2-3 days | Enables saved search alerts for JS clients |
| **P1** | Locales Endpoint | 0.5 day | Required for i18n and hreflang |
| **P1** | Page Parts in Pages API | 1 day | Enables CMS page rendering |
| **P1** | Cache Headers (ETag/Cache-Control) | 1-2 days | Performance critical |
| **P2** | Search Facets Endpoint | 1 day | Lightweight filter counts |
| **P2** | JSON-LD Schema Endpoint | 0.5 day | SEO convenience |
| **P2** | Image Variants in API Responses | 1 day | Responsive images |
| **P3** | Map Defaults in Theme/Site Details | 0.5 day | Consistent map behavior |
| **P3** | Analytics Config in Site Details | 0.5 day | Client-side analytics |

---

## P0: Critical (Blocks Core Functionality)

### 1. Favorites API (`/api_public/v1/favorites`)

**Current State**: HTML-based controller at `app/controllers/pwb/site/my/saved_properties_controller.rb` handles favorites via form posts and token-based access.

**Needed**: JSON API endpoints mirroring the HTML flows.

**File to Create**: `app/controllers/api_public/v1/favorites_controller.rb`

```ruby
# frozen_string_literal: true

module ApiPublic
  module V1
    class FavoritesController < BaseController
      before_action :set_favorite_by_token, only: [:show, :update, :destroy]
      before_action :set_favorites_by_manage_token, only: [:index]

      # GET /api_public/v1/favorites?token=XXX
      # List all favorites for email associated with token
      def index
        render json: {
          email: @favorites.first&.email,
          favorites: @favorites.map { |f| favorite_json(f) }
        }
      end

      # POST /api_public/v1/favorites
      # Create a new favorite
      # Body: { email, provider, external_reference, property_data?, notes? }
      def create
        favorite = PwbTenant::SavedProperty.new(favorite_params)
        favorite.website = Pwb::Current.website

        if favorite.save
          render json: {
            success: true,
            favorite: favorite_json(favorite),
            manage_token: favorite.manage_token,
            manage_url: favorites_manage_url(favorite.manage_token)
          }, status: :created
        else
          render json: { success: false, errors: favorite.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end

      # GET /api_public/v1/favorites/:id?token=XXX
      def show
        render json: favorite_json(@favorite)
      end

      # PATCH /api_public/v1/favorites/:id?token=XXX
      # Update notes
      def update
        if @favorite.update(favorite_update_params)
          render json: { success: true, favorite: favorite_json(@favorite) }
        else
          render json: { success: false, errors: @favorite.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api_public/v1/favorites/:id?token=XXX
      def destroy
        @favorite.destroy
        render json: { success: true }
      end

      # POST /api_public/v1/favorites/check
      # Check which references are already saved for an email
      # Body: { email, references: [] }
      def check
        email = params[:email].to_s.downcase.strip
        references = Array(params[:references])

        saved = PwbTenant::SavedProperty
                .for_email(email)
                .where(external_reference: references)
                .pluck(:external_reference)

        render json: { saved: saved }
      end

      private

      def set_favorite_by_token
        @favorite = PwbTenant::SavedProperty.find_by(manage_token: params[:token])
        @favorite ||= PwbTenant::SavedProperty.find_by(id: params[:id], manage_token: params[:token])
        render json: { error: "Invalid token" }, status: :unauthorized unless @favorite
      end

      def set_favorites_by_manage_token
        sample = PwbTenant::SavedProperty.find_by(manage_token: params[:token])
        unless sample
          render json: { error: "Invalid token" }, status: :unauthorized
          return
        end
        @favorites = PwbTenant::SavedProperty.for_email(sample.email).recent
      end

      def favorite_params
        params.require(:favorite).permit(:email, :provider, :external_reference, :notes, property_data: {})
      end

      def favorite_update_params
        params.require(:favorite).permit(:notes)
      end

      def favorite_json(fav)
        {
          id: fav.id,
          email: fav.email,
          provider: fav.provider,
          external_reference: fav.external_reference,
          notes: fav.notes,
          title: fav.title,
          price: fav.price,
          price_formatted: fav.price_formatted,
          image_url: fav.image_url,
          property_url: fav.property_url,
          original_price_cents: fav.original_price_cents,
          current_price_cents: fav.current_price_cents,
          price_changed: fav.price_changed_at.present?,
          price_changed_at: fav.price_changed_at,
          created_at: fav.created_at,
          manage_token: fav.manage_token
        }
      end

      def favorites_manage_url(token)
        # Return URL for JS client redirect
        "#{request.protocol}#{request.host_with_port}/my/favorites?token=#{token}"
      end
    end
  end
end
```

**Routes to Add** (in `config/routes.rb` under `namespace :api_public > namespace :v1`):
```ruby
resources :favorites, only: [:index, :show, :create, :update, :destroy] do
  collection do
    post :check
  end
end
```

**Tests Required**: `spec/requests/api_public/v1/favorites_spec.rb`

---

### 2. Saved Searches API (`/api_public/v1/saved_searches`)

**Current State**: HTML-based controller at `app/controllers/pwb/site/my/saved_searches_controller.rb`.

**File to Create**: `app/controllers/api_public/v1/saved_searches_controller.rb`

```ruby
# frozen_string_literal: true

module ApiPublic
  module V1
    class SavedSearchesController < BaseController
      before_action :set_search_by_token, only: [:show, :update, :destroy, :unsubscribe]
      before_action :set_searches_by_manage_token, only: [:index]

      # GET /api_public/v1/saved_searches?token=XXX
      def index
        render json: {
          email: @searches.first&.email,
          saved_searches: @searches.map { |s| search_json(s) }
        }
      end

      # POST /api_public/v1/saved_searches
      # Body: { email, search_criteria: {}, alert_frequency: "none"|"daily"|"weekly", name? }
      def create
        search = PwbTenant::SavedSearch.new(search_params)
        search.website = Pwb::Current.website

        if search.save
          # Optionally send verification email
          search.send_verification_email! if search.frequency_daily? || search.frequency_weekly?

          render json: {
            success: true,
            saved_search: search_json(search),
            manage_token: search.manage_token,
            manage_url: saved_searches_manage_url(search.manage_token),
            verification_required: !search.email_verified?
          }, status: :created
        else
          render json: { success: false, errors: search.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # GET /api_public/v1/saved_searches/:id?token=XXX
      def show
        render json: search_json(@search, include_alerts: true)
      end

      # PATCH /api_public/v1/saved_searches/:id?token=XXX
      # Update frequency, name, or enabled status
      def update
        if @search.update(search_update_params)
          render json: { success: true, saved_search: search_json(@search) }
        else
          render json: { success: false, errors: @search.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api_public/v1/saved_searches/:id?token=XXX
      def destroy
        @search.destroy
        render json: { success: true }
      end

      # POST /api_public/v1/saved_searches/:id/unsubscribe?token=XXX
      # Or GET with unsubscribe_token
      def unsubscribe
        @search.update!(enabled: false, alert_frequency: :none)
        render json: { success: true, message: "Unsubscribed from alerts" }
      end

      # GET /api_public/v1/saved_searches/verify?token=XXX
      def verify
        search = PwbTenant::SavedSearch.find_by(verification_token: params[:token])
        
        if search
          search.verify_email!
          render json: { success: true, message: "Email verified", saved_search: search_json(search) }
        else
          render json: { success: false, error: "Invalid verification token" }, status: :not_found
        end
      end

      private

      def set_search_by_token
        @search = PwbTenant::SavedSearch.find_by(manage_token: params[:token])
        @search ||= PwbTenant::SavedSearch.find_by(id: params[:id], manage_token: params[:token])
        @search ||= PwbTenant::SavedSearch.find_by(unsubscribe_token: params[:token])
        render json: { error: "Invalid token" }, status: :unauthorized unless @search
      end

      def set_searches_by_manage_token
        sample = PwbTenant::SavedSearch.find_by(manage_token: params[:token])
        unless sample
          render json: { error: "Invalid token" }, status: :unauthorized
          return
        end
        @searches = PwbTenant::SavedSearch.for_email(sample.email).order(created_at: :desc)
      end

      def search_params
        params.require(:saved_search).permit(:email, :name, :alert_frequency, search_criteria: {})
      end

      def search_update_params
        params.require(:saved_search).permit(:name, :alert_frequency, :enabled)
      end

      def search_json(search, include_alerts: false)
        json = {
          id: search.id,
          email: search.email,
          name: search.name,
          search_criteria: search.search_criteria_hash,
          alert_frequency: search.alert_frequency,
          enabled: search.enabled?,
          email_verified: search.email_verified?,
          last_run_at: search.last_run_at,
          last_result_count: search.last_result_count,
          created_at: search.created_at,
          manage_token: search.manage_token,
          unsubscribe_token: search.unsubscribe_token
        }

        if include_alerts
          json[:recent_alerts] = search.alerts.recent.limit(10).map do |alert|
            {
              id: alert.id,
              new_properties_count: alert.new_properties_count,
              sent_at: alert.sent_at,
              created_at: alert.created_at
            }
          end
        end

        json
      end

      def saved_searches_manage_url(token)
        "#{request.protocol}#{request.host_with_port}/my/saved_searches?token=#{token}"
      end
    end
  end
end
```

**Routes to Add**:
```ruby
resources :saved_searches, only: [:index, :show, :create, :update, :destroy] do
  member do
    post :unsubscribe
  end
  collection do
    get :verify
  end
end
```

---

## P1: High Priority (Needed for Production-Ready JS Clients)

### 3. Locales Endpoint (`/api_public/v1/locales`)

**Why**: JS clients need to know available locales for language switcher and hreflang tags.

**File to Create**: `app/controllers/api_public/v1/locales_controller.rb`

```ruby
# frozen_string_literal: true

module ApiPublic
  module V1
    class LocalesController < BaseController
      # GET /api_public/v1/locales
      def index
        website = Pwb::Current.website
        
        render json: {
          default_locale: website.default_locale || I18n.default_locale.to_s,
          available_locales: available_locales(website),
          current_locale: I18n.locale.to_s
        }
      end

      private

      def available_locales(website)
        # Website may have enabled_locales field, otherwise fall back to app defaults
        locales = website.respond_to?(:enabled_locales) ? website.enabled_locales : nil
        locales ||= %w[en es de fr nl pt it]

        locales.map do |code|
          {
            code: code,
            name: locale_name(code),
            native_name: locale_native_name(code),
            flag_emoji: locale_flag(code)
          }
        end
      end

      def locale_name(code)
        {
          'en' => 'English', 'es' => 'Spanish', 'de' => 'German',
          'fr' => 'French', 'nl' => 'Dutch', 'pt' => 'Portuguese',
          'it' => 'Italian', 'ru' => 'Russian', 'zh' => 'Chinese'
        }[code] || code.upcase
      end

      def locale_native_name(code)
        {
          'en' => 'English', 'es' => 'Español', 'de' => 'Deutsch',
          'fr' => 'Français', 'nl' => 'Nederlands', 'pt' => 'Português',
          'it' => 'Italiano', 'ru' => 'Русский', 'zh' => '中文'
        }[code] || code.upcase
      end

      def locale_flag(code)
        {
          'en' => '🇬🇧', 'es' => '🇪🇸', 'de' => '🇩🇪',
          'fr' => '🇫🇷', 'nl' => '🇳🇱', 'pt' => '🇵🇹',
          'it' => '🇮🇹', 'ru' => '🇷🇺', 'zh' => '🇨🇳'
        }[code] || '🏳️'
      end
    end
  end
end
```

**Route**: `get "/locales" => "locales#index"`

---

### 4. Page Parts in Pages API

**Current State**: `pages#show` returns `page.as_json` but doesn't include resolved page parts.

**File to Modify**: `app/controllers/api_public/v1/pages_controller.rb`

**Changes**:
```ruby
def show
  # ... existing code ...
  
  include_parts = params[:include_parts] == 'true'
  render json: page_json(page, include_parts: include_parts)
end

private

def page_json(page, include_parts: false)
  json = page.as_json
  
  if include_parts
    json[:page_parts] = page.page_parts.visible.ordered.map do |part|
      {
        id: part.id,
        key: part.page_part_key,
        position: part.position,
        visible: part.visible?,
        template: part.template_name,
        content: part.content_hash,  # JSON content for the part
        rendered_html: nil  # Optionally: part.render_liquid(assigns) if needed
      }
    end
  end
  
  json
end
```

**Also add to model** (`app/models/pwb/page_part.rb` or tenant equivalent):
```ruby
def content_hash
  # Return the content fields as a hash for JS clients to render
  {
    heading: heading,
    subheading: subheading,
    body: body_html,
    image_url: image_url,
    cta_text: cta_text,
    cta_url: cta_url,
    items: items_array  # For list-based parts
  }.compact
end
```

---

### 5. Cache Headers (ETag / Cache-Control)

**Why**: Theme, site_details, translations, search/config change infrequently and should be cached.

**File to Create**: `app/controllers/concerns/api_public/cacheable.rb`

```ruby
# frozen_string_literal: true

module ApiPublic
  module Cacheable
    extend ActiveSupport::Concern

    private

    # For rarely-changing data (theme, site_details, search_config)
    def set_long_cache(max_age: 1.hour, etag_data: nil)
      response.headers['Cache-Control'] = "public, max-age=#{max_age.to_i}, stale-while-revalidate=#{(max_age / 2).to_i}"
      
      if etag_data
        fresh_when(etag: etag_data, public: true)
      end
    end

    # For moderately-changing data (properties, pages)
    def set_short_cache(max_age: 5.minutes, etag_data: nil)
      response.headers['Cache-Control'] = "public, max-age=#{max_age.to_i}"
      
      if etag_data
        fresh_when(etag: etag_data, public: true)
      end
    end

    # For frequently-changing or personalized data
    def set_no_cache
      response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate'
    end
  end
end
```

**Apply to Controllers**:

```ruby
# theme_controller.rb
class ThemeController < BaseController
  include ApiPublic::Cacheable

  def index
    website = Pwb::Current.website
    etag_data = [website.id, website.updated_at, website.style_variables]
    
    set_long_cache(max_age: 1.hour, etag_data: etag_data)
    return if performed?  # Early return if 304 Not Modified
    
    render json: { theme: build_theme_response(website) }
  end
end

# site_details_controller.rb - similar pattern

# search_config_controller.rb - similar pattern

# translations_controller.rb - similar pattern

# properties_controller.rb
class PropertiesController < BaseController
  include ApiPublic::Cacheable

  def search
    set_short_cache(max_age: 2.minutes)
    # ... existing code ...
  end
end
```

---

## P2: Medium Priority (Improves Experience)

### 6. Search Facets Endpoint (`/api_public/v1/search/facets`)

**Why**: Lightweight counts per filter value without full search results.

**File to Create**: `app/controllers/api_public/v1/search_facets_controller.rb`

```ruby
# frozen_string_literal: true

module ApiPublic
  module V1
    class SearchFacetsController < BaseController
      include ApiPublic::Cacheable

      # GET /api_public/v1/search/facets?sale_or_rental=sale
      def index
        website = Pwb::Current.website
        base_scope = website.listed_properties.visible

        # Apply sale/rent filter if specified
        if params[:sale_or_rental] == 'rent'
          base_scope = base_scope.for_rent
        elsif params[:sale_or_rental] == 'sale'
          base_scope = base_scope.for_sale
        end

        set_short_cache(max_age: 5.minutes)

        render json: {
          total_count: base_scope.count,
          property_types: facet_counts(base_scope, :prop_type_key),
          zones: facet_counts(base_scope, :zone),
          localities: facet_counts(base_scope, :locality),
          bedrooms: facet_counts(base_scope, :count_bedrooms),
          bathrooms: facet_counts(base_scope, :count_bathrooms),
          price_ranges: price_range_facets(base_scope, params[:sale_or_rental])
        }
      end

      private

      def facet_counts(scope, field)
        scope.where.not(field => [nil, ''])
             .group(field)
             .count
             .transform_keys(&:to_s)
             .sort_by { |_k, v| -v }
             .to_h
      end

      def price_range_facets(scope, sale_or_rental)
        price_field = sale_or_rental == 'rent' ? :price_rental_monthly_current_cents : :price_sale_current_cents
        
        ranges = [
          { label: '< €100k', min: 0, max: 100_000_00 },
          { label: '€100k - €250k', min: 100_000_00, max: 250_000_00 },
          { label: '€250k - €500k', min: 250_000_00, max: 500_000_00 },
          { label: '€500k - €1M', min: 500_000_00, max: 1_000_000_00 },
          { label: '> €1M', min: 1_000_000_00, max: nil }
        ]

        ranges.map do |range|
          query = scope.where("#{price_field} >= ?", range[:min])
          query = query.where("#{price_field} < ?", range[:max]) if range[:max]
          
          { label: range[:label], count: query.count }
        end
      end
    end
  end
end
```

**Route**: `get "/search/facets" => "search_facets#index"`

---

### 7. JSON-LD Schema Endpoint

**Why**: Convenience for JS SSR to include structured data without reconstructing from property fields.

**Add to Properties Controller**:

```ruby
# GET /api_public/v1/properties/:id/schema
def schema
  property = find_property
  
  render json: {
    "@context": "https://schema.org",
    "@type": "RealEstateListing",
    "name": property.title,
    "description": property.description_stripped,
    "url": property_url(property),
    "datePosted": property.created_at.iso8601,
    "offers": {
      "@type": "Offer",
      "price": property.price_cents / 100,
      "priceCurrency": property.currency || "EUR",
      "availability": "https://schema.org/InStock"
    },
    "address": {
      "@type": "PostalAddress",
      "streetAddress": property.address,
      "addressLocality": property.locality,
      "addressRegion": property.zone,
      "addressCountry": property.country_code
    },
    "geo": {
      "@type": "GeoCoordinates",
      "latitude": property.latitude,
      "longitude": property.longitude
    },
    "image": property.photo_urls,
    "numberOfRooms": property.count_bedrooms,
    "numberOfBathroomsTotal": property.count_bathrooms
  }.compact
end
```

**Route**: `get "/properties/:id/schema" => "properties#schema"`

---

### 8. Image Variants in API Responses

**Why**: Enable responsive images without guessing Active Storage variant URLs.

**Add helper module** (`app/controllers/concerns/api_public/image_variants.rb`):

```ruby
# frozen_string_literal: true

module ApiPublic
  module ImageVariants
    extend ActiveSupport::Concern

    private

    def image_variants_for(attachment)
      return nil unless attachment.attached?

      {
        thumbnail: variant_url(attachment, resize_to_fill: [150, 100]),
        small: variant_url(attachment, resize_to_fill: [300, 200]),
        medium: variant_url(attachment, resize_to_fill: [600, 400]),
        large: variant_url(attachment, resize_to_fill: [1200, 800]),
        original: rails_blob_url(attachment)
      }
    rescue StandardError => e
      Rails.logger.warn("[ImageVariants] Error generating variants: #{e.message}")
      nil
    end

    def variant_url(attachment, transformations)
      Rails.application.routes.url_helpers.rails_representation_url(
        attachment.variant(transformations).processed,
        only_path: false
      )
    end
  end
end
```

**Modify Property `as_json`** or create a serializer:

```ruby
# In properties_controller.rb or property serializer
def property_json(property)
  property.as_json.merge(
    images: property.photos.map do |photo|
      {
        id: photo.id,
        alt: photo.alt_text,
        variants: image_variants_for(photo.image)
      }
    end
  )
end
```

---

## P3: Lower Priority (Nice to Have)

### 9. Map Defaults in Theme/Site Details

**Modify** `theme_controller.rb` to include:

```ruby
def build_theme_response(website)
  {
    # ... existing fields ...
    map_config: {
      tile_url: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
      attribution: '&copy; OpenStreetMap contributors',
      default_zoom: 13,
      max_zoom: 18,
      scroll_wheel_zoom: false,
      default_center: website.default_map_center || { lat: 40.4168, lng: -3.7038 }
    }
  }
end
```

---

### 10. Analytics Config in Site Details

**Modify** `site_details_controller.rb`:

```ruby
def index
  website = Pwb::Current.website
  
  render json: website.as_json.merge(
    analytics: {
      posthog_key: website.posthog_api_key.presence,
      ga4_id: website.ga4_measurement_id.presence,
      gtm_id: website.gtm_container_id.presence
    }.compact
  )
end
```

---

## Implementation Checklist

### Phase 1 (P0 - Week 1-2)
- [x] Create `app/controllers/api_public/v1/favorites_controller.rb`
- [x] Create `app/controllers/api_public/v1/saved_searches_controller.rb`
- [x] Add routes for both controllers
- [x] Create request specs: `spec/requests/api_public/v1/favorites_spec.rb`
- [x] Create request specs: `spec/requests/api_public/v1/saved_searches_spec.rb`
- [ ] Update Swagger documentation

### Phase 2 (P1 - Week 2-3)
- [x] Create `app/controllers/api_public/v1/locales_controller.rb`
- [x] Extend `pages_controller.rb` with `include_parts` param
- [x] Create `app/controllers/concerns/api_public/cacheable.rb`
- [x] Add ETag/Cache-Control to theme, site_details, translations, search_config
- [x] Add request specs for locales

### Phase 3 (P2 - Week 3-4)
- [x] Create `app/controllers/api_public/v1/search_facets_controller.rb`
- [x] Add `#schema` action to properties controller
- [ ] Create `app/controllers/concerns/api_public/image_variants.rb`
- [ ] Update property JSON serialization with image variants
- [x] Add request specs for search_facets

### Phase 4 (P3 - Week 4)
- [x] Add `map_config` to theme response
- [x] Add `analytics` to site_details response
- [ ] Update E2E tests for new endpoints
- [ ] Update public_frontend_functionality.md with finalized API docs

---

## Testing Requirements

Each new endpoint needs:

1. **Request Specs** (`spec/requests/api_public/v1/`):
   - Success cases (200/201)
   - Authentication failures (401 for token-protected)
   - Validation failures (422)
   - Not found cases (404)
   - Multi-tenant isolation

2. **E2E Tests** (`tests/e2e/public/`):
   - JS client simulation calling endpoints
   - Full flow: create favorite → list → update → delete

3. **Swagger Documentation** (`swagger/v1/`):
   - OpenAPI spec for each endpoint
   - Example requests/responses

---

## Database Considerations

No new migrations needed - existing models (`Pwb::SavedProperty`, `Pwb::SavedSearch`) already have all required fields. Just need to:

1. Ensure `PwbTenant::SavedProperty` and `PwbTenant::SavedSearch` are properly scoped (they already are via `website_id`)
2. Consider adding indices if missing:
   ```ruby
   add_index :pwb_saved_properties, [:website_id, :email], if_not_exists: true
   add_index :pwb_saved_searches, [:website_id, :email], if_not_exists: true
   ```

---

## Related Files

- Existing HTML favorites controller: [app/controllers/pwb/site/my/saved_properties_controller.rb](../../app/controllers/pwb/site/my/saved_properties_controller.rb)
- Existing HTML saved searches controller: [app/controllers/pwb/site/my/saved_searches_controller.rb](../../app/controllers/pwb/site/my/saved_searches_controller.rb)
- SavedProperty model: [app/models/pwb/saved_property.rb](../../app/models/pwb/saved_property.rb)
- SavedSearch model: [app/models/pwb/saved_search.rb](../../app/models/pwb/saved_search.rb)
- Routes: [config/routes.rb](../../config/routes.rb) (line ~720 for api_public namespace)
- Existing API controllers: [app/controllers/api_public/v1/](../../app/controllers/api_public/v1/)
