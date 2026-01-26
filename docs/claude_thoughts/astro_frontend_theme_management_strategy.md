# Astro Frontend Theme Management Strategy

**Date**: 2026-01-15
**Context**: Two fundamentally different rendering pipelines for PropertyWebBuilder
**Approach**: Reverse Proxy

---

## Executive Summary

PropertyWebBuilder needs to support **two mutually exclusive rendering modes**:

1. **Rails Mode** (B themes) - Server-side rendering via Rails + Liquid templates
2. **Client Mode** (A themes) - Client-side rendering via Astro JavaScript application

These are fundamentally different systems that cannot be mixed. A website chooses ONE mode at deployment time, and this decision is essentially permanent.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         WEBSITE DEPLOYMENT                               │
│                                                                          │
│   ┌─────────────────────┐              ┌─────────────────────┐          │
│   │  rendering_mode:    │              │  rendering_mode:    │          │
│   │      "rails"        │              │     "client"        │          │
│   └─────────┬───────────┘              └──────────┬──────────┘          │
│             │                                     │                      │
│             ▼                                     ▼                      │
│   ┌─────────────────────┐              ┌─────────────────────┐          │
│   │   B THEMES          │              │   A THEMES          │          │
│   │                     │              │                     │          │
│   │ - Barcelona         │              │ - Amsterdam         │          │
│   │ - Bologna           │              │ - Athens            │          │
│   │ - Brisbane          │              │ - Austin            │          │
│   │ - Brussels          │              │ - (future themes)   │          │
│   │ - Biarritz          │              │                     │          │
│   │                     │              │                     │          │
│   │ Rendered by:        │              │ Rendered by:        │          │
│   │ Rails + Liquid      │              │ Astro + JavaScript  │          │
│   │                     │              │                     │          │
│   │ Theme model:        │              │ Theme model:        │          │
│   │ Pwb::Theme          │              │ Pwb::ClientTheme    │          │
│   │ (ActiveJSON/file)   │              │ (Database)          │          │
│   │                     │              │                     │          │
│   │ Management:         │              │ Management:         │          │
│   │ Rails Admin UI      │              │ Astro Client UI     │          │
│   └─────────────────────┘              └─────────────────────┘          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Why Two Separate Systems?

### B Themes (Rails-Rendered)

| Aspect | Description |
|--------|-------------|
| **Source** | `app/themes/` directory with Liquid templates |
| **Config** | `app/themes/config.json` via ActiveJSON |
| **Model** | `Pwb::Theme` (file-based, not database) |
| **Rendering** | Server-side (Rails renders HTML) |
| **Page Parts** | Liquid templates in `app/themes/*/views/` |
| **Palettes** | JSON files in `app/themes/*/palettes/` |
| **Admin** | Rails admin UI at `/site_admin/` |

### A Themes (Astro Client-Rendered)

| Aspect | Description |
|--------|-------------|
| **Source** | Astro client `src/layouts/` components |
| **Config** | Needs new `Pwb::ClientTheme` model (database) |
| **Model** | `Pwb::ClientTheme` (database-backed) |
| **Rendering** | Client-side (Astro/JavaScript) |
| **Components** | Astro components (`.astro` files) |
| **Styles** | Tailwind CSS + CSS variables |
| **Admin** | Astro client UI (accessed via reverse proxy) |

**Key Insight**: These cannot share the same theme management system because:
- B themes use Liquid templates that Rails renders
- A themes use Astro components that JavaScript renders
- The page structure, templating, and styling systems are completely different

---

## Reverse Proxy Approach

### Overview

The reverse proxy approach allows:
1. All website URLs served from Rails domain
2. Rails handles authentication for all routes
3. Astro content/management pages proxied seamlessly
4. Single domain experience for users

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           USER REQUEST                                   │
│                    https://tenant.example.com/*                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          NGINX / LOAD BALANCER                          │
│                                                                          │
│   All requests → Rails Application                                      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          RAILS APPLICATION                               │
│                                                                          │
│   1. Check rendering_mode for current_website                           │
│                                                                          │
│   IF rendering_mode == "rails":                                         │
│      → Render normally with B themes (Liquid)                           │
│                                                                          │
│   IF rendering_mode == "client":                                        │
│      → Check route type:                                                │
│         - /site_admin/* → Rails admin (settings, properties, etc.)     │
│         - /api/* → Rails API endpoints                                  │
│         - /* → Proxy to Astro client server                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                        (if client mode + public route)
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          ASTRO CLIENT SERVER                            │
│                                                                          │
│   - Renders A themes (Amsterdam, Athens, Austin)                        │
│   - Serves theme management UI at /manage-content/*                       │
│   - Fetches data from Rails API                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Steps

### Phase 1: Database Schema Changes

#### Step 1.1: Add rendering_mode to Website

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_rendering_mode_to_websites.rb
class AddRenderingModeToWebsites < ActiveRecord::Migration[7.0]
  def change
    add_column :pwb_websites, :rendering_mode, :string, default: 'rails', null: false
    add_column :pwb_websites, :client_theme_name, :string
    add_column :pwb_websites, :client_theme_config, :jsonb, default: {}

    add_index :pwb_websites, :rendering_mode

    # Add check constraint to ensure valid values
    add_check_constraint :pwb_websites,
      "rendering_mode IN ('rails', 'client')",
      name: 'rendering_mode_valid'
  end
end
```

#### Step 1.2: Create ClientTheme Model

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_client_themes.rb
class CreateClientThemes < ActiveRecord::Migration[7.0]
  def change
    create_table :pwb_client_themes do |t|
      t.string :name, null: false
      t.string :friendly_name, null: false
      t.string :version, default: '1.0.0'
      t.text :description
      t.string :preview_image_url
      t.jsonb :default_config, default: {}
      t.jsonb :color_schema, default: {}
      t.jsonb :font_schema, default: {}
      t.jsonb :layout_options, default: {}
      t.boolean :enabled, default: true, null: false
      t.timestamps

      t.index :name, unique: true
      t.index :enabled
    end
  end
end
```

#### Step 1.3: Seed Initial Client Themes

```ruby
# db/seeds/client_themes.rb
Pwb::ClientTheme.find_or_create_by!(name: 'amsterdam') do |theme|
  theme.friendly_name = 'Amsterdam Modern'
  theme.description = 'A clean, modern theme with Dutch-inspired design elements'
  theme.version = '1.0.0'
  theme.default_config = {
    primary_color: '#FF6B35',
    secondary_color: '#004E89',
    accent_color: '#F7C59F',
    font_heading: 'Inter',
    font_body: 'Open Sans'
  }
  theme.color_schema = {
    primary_color: { type: 'color', label: 'Primary Color', default: '#FF6B35' },
    secondary_color: { type: 'color', label: 'Secondary Color', default: '#004E89' },
    accent_color: { type: 'color', label: 'Accent Color', default: '#F7C59F' },
    background_color: { type: 'color', label: 'Background', default: '#FFFFFF' },
    text_color: { type: 'color', label: 'Text Color', default: '#1A1A1A' }
  }
  theme.font_schema = {
    font_heading: {
      type: 'select',
      label: 'Heading Font',
      options: ['Inter', 'Montserrat', 'Playfair Display', 'Poppins'],
      default: 'Inter'
    },
    font_body: {
      type: 'select',
      label: 'Body Font',
      options: ['Open Sans', 'Roboto', 'Lato', 'Source Sans Pro'],
      default: 'Open Sans'
    }
  }
end

Pwb::ClientTheme.find_or_create_by!(name: 'athens') do |theme|
  theme.friendly_name = 'Athens Classic'
  theme.description = 'An elegant theme inspired by Greek classical architecture'
  theme.version = '1.0.0'
  theme.default_config = {
    primary_color: '#1E3A5F',
    secondary_color: '#D4AF37',
    accent_color: '#F5F5DC',
    font_heading: 'Playfair Display',
    font_body: 'Lato'
  }
  theme.color_schema = {
    primary_color: { type: 'color', label: 'Primary Color', default: '#1E3A5F' },
    secondary_color: { type: 'color', label: 'Secondary Color', default: '#D4AF37' },
    accent_color: { type: 'color', label: 'Accent Color', default: '#F5F5DC' },
    background_color: { type: 'color', label: 'Background', default: '#FAFAFA' },
    text_color: { type: 'color', label: 'Text Color', default: '#2D2D2D' }
  }
  theme.font_schema = {
    font_heading: {
      type: 'select',
      label: 'Heading Font',
      options: ['Playfair Display', 'Cormorant Garamond', 'Libre Baskerville'],
      default: 'Playfair Display'
    },
    font_body: {
      type: 'select',
      label: 'Body Font',
      options: ['Lato', 'Open Sans', 'Source Sans Pro'],
      default: 'Lato'
    }
  }
end

Pwb::ClientTheme.find_or_create_by!(name: 'austin') do |theme|
  theme.friendly_name = 'Austin Bold'
  theme.description = 'A vibrant, bold theme with Texas-inspired warmth'
  theme.version = '1.0.0'
  theme.default_config = {
    primary_color: '#BF5700',
    secondary_color: '#333F48',
    accent_color: '#F8971F',
    font_heading: 'Montserrat',
    font_body: 'Roboto'
  }
  theme.color_schema = {
    primary_color: { type: 'color', label: 'Primary Color', default: '#BF5700' },
    secondary_color: { type: 'color', label: 'Secondary Color', default: '#333F48' },
    accent_color: { type: 'color', label: 'Accent Color', default: '#F8971F' },
    background_color: { type: 'color', label: 'Background', default: '#FFFFFF' },
    text_color: { type: 'color', label: 'Text Color', default: '#1C1C1C' }
  }
  theme.font_schema = {
    font_heading: {
      type: 'select',
      label: 'Heading Font',
      options: ['Montserrat', 'Oswald', 'Raleway'],
      default: 'Montserrat'
    },
    font_body: {
      type: 'select',
      label: 'Body Font',
      options: ['Roboto', 'Open Sans', 'Nunito'],
      default: 'Roboto'
    }
  }
end
```

---

### Phase 2: Models

#### Step 2.1: Create ClientTheme Model

```ruby
# app/models/pwb/client_theme.rb
# frozen_string_literal: true

module Pwb
  class ClientTheme < ApplicationRecord
    self.table_name = 'pwb_client_themes'

    # Validations
    validates :name, presence: true, uniqueness: true
    validates :friendly_name, presence: true

    # Scopes
    scope :enabled, -> { where(enabled: true) }
    scope :by_name, ->(name) { find_by(name: name) }

    # Get the merged config for a website (defaults + overrides)
    def config_for_website(website)
      default_config.merge(website.client_theme_config || {})
    end

    # Generate CSS variables from config
    def generate_css_variables(config = default_config)
      css_vars = []
      config.each do |key, value|
        css_var_name = key.to_s.tr('_', '-')
        css_vars << "--#{css_var_name}: #{value};"
      end
      ":root { #{css_vars.join(' ')} }"
    end

    # API serialization
    def as_api_json
      {
        name: name,
        friendly_name: friendly_name,
        version: version,
        description: description,
        preview_image_url: preview_image_url,
        default_config: default_config,
        color_schema: color_schema,
        font_schema: font_schema,
        layout_options: layout_options
      }
    end
  end
end
```

#### Step 2.2: Update Website Model

```ruby
# app/models/concerns/pwb/website_rendering_mode.rb
# frozen_string_literal: true

module Pwb
  module WebsiteRenderingMode
    extend ActiveSupport::Concern

    RENDERING_MODES = %w[rails client].freeze

    included do
      validates :rendering_mode, inclusion: { in: RENDERING_MODES }
      validates :client_theme_name, presence: true, if: :client_rendering?
      validate :client_theme_must_exist, if: :client_rendering?

      # Prevent changing rendering_mode after initial setup
      validate :rendering_mode_immutable, on: :update
    end

    # Check if using Rails rendering (B themes)
    def rails_rendering?
      rendering_mode == 'rails'
    end

    # Check if using client rendering (A themes)
    def client_rendering?
      rendering_mode == 'client'
    end

    # Get the client theme object
    def client_theme
      return nil unless client_rendering?

      @client_theme ||= ClientTheme.enabled.by_name(client_theme_name)
    end

    # Get merged theme config (defaults + website overrides)
    def effective_client_theme_config
      return {} unless client_theme

      client_theme.config_for_website(self)
    end

    # Check if rendering mode can still be changed
    # (only allowed before first content is created)
    def rendering_mode_locked?
      # Lock after website has been provisioned and has content
      provisioning_completed_at.present? && page_contents.any?
    end

    private

    def client_theme_must_exist
      return unless client_theme_name.present?

      unless ClientTheme.enabled.exists?(name: client_theme_name)
        errors.add(:client_theme_name, "is not a valid client theme")
      end
    end

    def rendering_mode_immutable
      return unless rendering_mode_changed?
      return unless rendering_mode_locked?

      errors.add(:rendering_mode, "cannot be changed after website has content")
    end
  end
end
```

Add to Website model:

```ruby
# In app/models/pwb/website.rb, add:
include Pwb::WebsiteRenderingMode
```

---

### Phase 3: Reverse Proxy Infrastructure

#### Step 3.1: Create Proxy Controller

```ruby
# app/controllers/pwb/client_proxy_controller.rb
# frozen_string_literal: true

module Pwb
  class ClientProxyController < ApplicationController
    include SubdomainTenant

    before_action :set_current_website_from_request
    before_action :ensure_client_rendering_mode
    before_action :authenticate_for_admin_routes!, only: [:admin_proxy]

    # Proxy public pages to Astro client
    def public_proxy
      proxy_to_astro_client(request.fullpath)
    end

    # Proxy admin/management pages to Astro client (requires auth)
    def admin_proxy
      # Add auth headers for Astro to verify
      proxy_to_astro_client(request.fullpath, with_auth: true)
    end

    private

    def ensure_client_rendering_mode
      unless Pwb::Current.website&.client_rendering?
        # Fall through to normal Rails rendering
        raise ActionController::RoutingError, 'Not Found'
      end
    end

    def authenticate_for_admin_routes!
      unless user_signed_in?
        store_location_for(:user, request.fullpath)
        redirect_to new_user_session_path, alert: 'Please sign in to access this page.'
      end
    end

    def proxy_to_astro_client(path, with_auth: false)
      astro_url = build_astro_url(path)

      # Build request headers
      headers = proxy_headers
      headers.merge!(auth_headers) if with_auth

      begin
        response = HTTP
          .timeout(connect: 5, read: 30)
          .headers(headers)
          .get(astro_url)

        render_proxy_response(response)
      rescue HTTP::Error => e
        Rails.logger.error "Astro proxy error: #{e.message}"
        render_proxy_error
      end
    end

    def build_astro_url(path)
      astro_base_url = astro_client_url
      "#{astro_base_url}#{path}"
    end

    def astro_client_url
      # Configure via environment variable
      ENV.fetch('ASTRO_CLIENT_URL', 'http://localhost:4321')
    end

    def proxy_headers
      {
        'X-Forwarded-Host' => request.host,
        'X-Forwarded-Proto' => request.protocol.chomp('://'),
        'X-Website-Slug' => Pwb::Current.website&.slug,
        'X-Website-Id' => Pwb::Current.website&.id.to_s,
        'X-Rendering-Mode' => 'client',
        'X-Client-Theme' => Pwb::Current.website&.client_theme_name,
        'Accept' => request.headers['Accept'],
        'Accept-Language' => request.headers['Accept-Language']
      }
    end

    def auth_headers
      {
        'X-User-Id' => current_user&.id.to_s,
        'X-User-Email' => current_user&.email,
        'X-User-Role' => current_user_role,
        'X-Auth-Token' => generate_proxy_auth_token
      }
    end

    def current_user_role
      return 'guest' unless current_user

      membership = current_user.user_memberships.find_by(website: Pwb::Current.website)
      membership&.role || 'member'
    end

    def generate_proxy_auth_token
      # Short-lived token for Astro to verify the request came from Rails
      payload = {
        user_id: current_user&.id,
        website_id: Pwb::Current.website&.id,
        exp: 5.minutes.from_now.to_i
      }
      JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
    end

    def render_proxy_response(response)
      # Set response headers
      response.headers.each do |key, value|
        # Skip hop-by-hop headers
        next if %w[connection keep-alive transfer-encoding].include?(key.downcase)

        headers[key] = value
      end

      # Handle content type
      content_type = response.content_type&.mime_type || 'text/html'

      render body: response.body.to_s,
             status: response.status,
             content_type: content_type
    end

    def render_proxy_error
      if request.format.html?
        render 'errors/proxy_unavailable', status: :service_unavailable
      else
        render json: { error: 'Client application unavailable' },
               status: :service_unavailable
      end
    end
  end
end
```

#### Step 3.2: Create Proxy Error View

```erb
<%# app/views/errors/proxy_unavailable.html.erb %>
<!DOCTYPE html>
<html>
<head>
  <title>Service Temporarily Unavailable</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      background: #f5f5f5;
    }
    .container {
      text-align: center;
      padding: 2rem;
    }
    h1 { color: #333; }
    p { color: #666; }
    .retry-btn {
      display: inline-block;
      margin-top: 1rem;
      padding: 0.75rem 1.5rem;
      background: #007bff;
      color: white;
      text-decoration: none;
      border-radius: 4px;
    }
    .retry-btn:hover { background: #0056b3; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Service Temporarily Unavailable</h1>
    <p>We're having trouble connecting to the page. Please try again in a moment.</p>
    <a href="javascript:location.reload()" class="retry-btn">Retry</a>
  </div>
</body>
</html>
```

#### Step 3.3: Add Gemfile Dependency

```ruby
# Gemfile - add HTTP gem for proxy requests
gem 'http', '~> 5.0'
gem 'jwt', '~> 2.7'  # For auth token generation
```

---

### Phase 4: Routing Configuration

#### Step 4.1: Update Routes

```ruby
# config/routes.rb

Rails.application.routes.draw do
  # ... existing routes ...

  # Client rendering proxy routes
  # These are matched AFTER all other routes, acting as a catch-all
  # for client-rendered websites

  constraints(->(request) { client_rendering_request?(request) }) do
    # Admin routes for client-rendered sites (require auth)
    scope '/manage-content' do
      match '*path', to: 'pwb/client_proxy#admin_proxy', via: :all
      root to: 'pwb/client_proxy#admin_proxy'
    end

    # Public routes for client-rendered sites
    match '*path', to: 'pwb/client_proxy#public_proxy', via: :all,
          constraints: ->(req) { !excluded_from_proxy?(req.path) }
  end
end

# Helper methods in config/initializers/routing_helpers.rb
module RoutingHelpers
  def client_rendering_request?(request)
    # Determine website from request
    website = Pwb::Website.find_by_host(request.host)
    website&.client_rendering?
  end

  def excluded_from_proxy?(path)
    # These paths should always go to Rails, even for client-rendered sites
    excluded_prefixes = %w[
      /site_admin
      /tenant_admin
      /api
      /api_public
      /users
      /rails
      /assets
      /packs
    ]

    excluded_prefixes.any? { |prefix| path.start_with?(prefix) }
  end
end

# Make helpers available to routing constraints
Rails.application.routes.draw do
  extend RoutingHelpers
end
```

#### Step 4.2: Create Routing Constraint

```ruby
# app/constraints/client_rendering_constraint.rb
# frozen_string_literal: true

class ClientRenderingConstraint
  EXCLUDED_PATHS = %w[
    /site_admin
    /tenant_admin
    /api
    /api_public
    /users
    /rails
    /assets
    /packs
    /cable
    /active_storage
  ].freeze

  def matches?(request)
    return false if excluded_path?(request.path)

    website = website_from_request(request)
    website&.client_rendering?
  end

  private

  def website_from_request(request)
    # Try custom domain first
    website = Pwb::Website.find_by(custom_domain: request.host)
    return website if website

    # Try subdomain
    subdomain = extract_subdomain(request.host)
    Pwb::Website.find_by(subdomain: subdomain) if subdomain
  end

  def extract_subdomain(host)
    parts = host.split('.')
    return nil if parts.length < 3

    parts.first
  end

  def excluded_path?(path)
    EXCLUDED_PATHS.any? { |prefix| path.start_with?(prefix) }
  end
end
```

---

### Phase 5: API Endpoints for Client Theme Management

#### Step 5.1: Client Themes API Controller

```ruby
# app/controllers/api_public/v1/client_themes_controller.rb
# frozen_string_literal: true

module ApiPublic
  module V1
    class ClientThemesController < BaseController
      # GET /api_public/v1/client-themes
      # List all available client themes
      def index
        themes = Pwb::ClientTheme.enabled.order(:friendly_name)

        render json: {
          client_themes: themes.map(&:as_api_json)
        }
      end

      # GET /api_public/v1/client-themes/:name
      # Get specific client theme details
      def show
        theme = Pwb::ClientTheme.enabled.find_by!(name: params[:name])

        render json: {
          client_theme: theme.as_api_json
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Client theme not found' }, status: :not_found
      end
    end
  end
end
```

#### Step 5.2: Website Client Config API

```ruby
# app/controllers/api_public/v1/website_client_config_controller.rb
# frozen_string_literal: true

module ApiPublic
  module V1
    class WebsiteClientConfigController < BaseController
      # GET /api_public/v1/client-config
      # Returns full config for client-rendered website
      def show
        website = Pwb::Current.website

        unless website&.client_rendering?
          render json: { error: 'Website is not using client rendering' },
                 status: :bad_request
          return
        end

        render json: {
          rendering_mode: 'client',
          client_theme: {
            name: website.client_theme_name,
            config: website.effective_client_theme_config,
            schema: website.client_theme&.as_api_json
          },
          website: website_config(website),
          css_variables: generate_css_variables(website)
        }
      end

      private

      def website_config(website)
        {
          company_display_name: website.company_display_name,
          logo_url: website.logo_url,
          favicon_url: website.favicon_url,
          supported_locales: website.supported_locales,
          default_client_locale: website.default_client_locale,
          dark_mode_setting: website.dark_mode_setting
        }
      end

      def generate_css_variables(website)
        config = website.effective_client_theme_config
        return '' if config.blank?

        css_vars = config.map do |key, value|
          "--#{key.to_s.tr('_', '-')}: #{value}"
        end

        ":root { #{css_vars.join('; ')}; }"
      end
    end
  end
end
```

#### Step 5.3: Admin API for Client Theme Settings

```ruby
# app/controllers/pwb/api/v1/client_theme_settings_controller.rb
# frozen_string_literal: true

module Pwb
  module Api
    module V1
      class ClientThemeSettingsController < BaseController
        before_action :authenticate_user!
        before_action :ensure_admin_access!
        before_action :ensure_client_rendering!

        # GET /api/v1/client-theme-settings
        def show
          render json: {
            client_theme_name: current_website.client_theme_name,
            client_theme_config: current_website.client_theme_config,
            available_themes: Pwb::ClientTheme.enabled.map(&:as_api_json)
          }
        end

        # PATCH /api/v1/client-theme-settings
        def update
          if current_website.update(client_theme_params)
            render json: {
              success: true,
              client_theme_name: current_website.client_theme_name,
              client_theme_config: current_website.client_theme_config
            }
          else
            render json: {
              success: false,
              errors: current_website.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        private

        def client_theme_params
          params.require(:website).permit(
            :client_theme_name,
            client_theme_config: {}
          )
        end

        def ensure_client_rendering!
          unless current_website.client_rendering?
            render json: { error: 'Website is not using client rendering' },
                   status: :bad_request
          end
        end

        def ensure_admin_access!
          unless current_user_admin?
            render json: { error: 'Admin access required' }, status: :forbidden
          end
        end

        def current_user_admin?
          membership = current_user.user_memberships.find_by(website: current_website)
          %w[owner admin].include?(membership&.role)
        end

        def current_website
          @current_website ||= Pwb::Current.website
        end
      end
    end
  end
end
```

#### Step 5.4: Add API Routes

```ruby
# config/routes.rb - add these routes

namespace :api_public do
  namespace :v1 do
    # Client themes (public)
    resources :client_themes, only: [:index, :show], path: 'client-themes', param: :name

    # Client config for current website (public)
    resource :client_config, only: [:show], path: 'client-config',
             controller: 'website_client_config'
  end
end

namespace :pwb do
  namespace :api do
    namespace :v1 do
      # Client theme settings (authenticated)
      resource :client_theme_settings, only: [:show, :update],
               path: 'client-theme-settings'
    end
  end
end
```

---

### Phase 6: Tenant Admin UI for Rendering Mode Selection

#### Step 6.1: Rendering Mode Controller

```ruby
# app/controllers/tenant_admin/rendering_mode_controller.rb
# frozen_string_literal: true

module TenantAdmin
  class RenderingModeController < BaseController
    before_action :ensure_super_admin!
    before_action :ensure_mode_changeable!, only: [:update]

    def show
      @website = current_website
      @client_themes = Pwb::ClientTheme.enabled.order(:friendly_name)
    end

    def update
      @website = current_website

      if @website.update(rendering_mode_params)
        redirect_to tenant_admin_rendering_mode_path,
                    notice: 'Rendering mode updated successfully.'
      else
        @client_themes = Pwb::ClientTheme.enabled.order(:friendly_name)
        render :show, status: :unprocessable_entity
      end
    end

    private

    def rendering_mode_params
      params.require(:website).permit(:rendering_mode, :client_theme_name)
    end

    def ensure_super_admin!
      unless current_user_super_admin?
        redirect_to tenant_admin_root_path,
                    alert: 'Only super admins can change rendering mode.'
      end
    end

    def ensure_mode_changeable!
      if current_website.rendering_mode_locked?
        redirect_to tenant_admin_rendering_mode_path,
                    alert: 'Rendering mode cannot be changed after website has content.'
      end
    end

    def current_user_super_admin?
      membership = current_user.user_memberships.find_by(website: current_website)
      membership&.role == 'owner'
    end
  end
end
```

#### Step 6.2: Rendering Mode View

```erb
<%# app/views/tenant_admin/rendering_mode/show.html.erb %>
<div class="container mx-auto px-4 py-8 max-w-2xl">
  <h1 class="text-2xl font-bold mb-6">Website Rendering Mode</h1>

  <% if @website.rendering_mode_locked? %>
    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
      <div class="flex items-center">
        <svg class="w-5 h-5 text-yellow-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
        </svg>
        <p class="text-yellow-800 font-medium">Rendering mode is locked</p>
      </div>
      <p class="text-yellow-700 text-sm mt-2">
        This setting cannot be changed because the website already has content.
        Contact support if you need to migrate to a different rendering mode.
      </p>
    </div>
  <% end %>

  <div class="bg-white rounded-lg shadow p-6">
    <%= form_with model: @website, url: tenant_admin_rendering_mode_path, method: :patch do |f| %>
      <div class="space-y-6">

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-3">
            Select Rendering Mode
          </label>

          <div class="space-y-4">
            <!-- Rails Mode -->
            <label class="flex items-start p-4 border rounded-lg cursor-pointer
                          <%= @website.rails_rendering? ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-gray-300' %>
                          <%= 'opacity-50 cursor-not-allowed' if @website.rendering_mode_locked? %>">
              <%= f.radio_button :rendering_mode, 'rails',
                                 class: 'mt-1 h-4 w-4 text-blue-600',
                                 disabled: @website.rendering_mode_locked? %>
              <div class="ml-3">
                <span class="block font-medium text-gray-900">Rails Rendering (B Themes)</span>
                <span class="block text-sm text-gray-500 mt-1">
                  Server-side rendering using Liquid templates.
                  Themes: Barcelona, Bologna, Brisbane, Brussels, Biarritz
                </span>
              </div>
            </label>

            <!-- Client Mode -->
            <label class="flex items-start p-4 border rounded-lg cursor-pointer
                          <%= @website.client_rendering? ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-gray-300' %>
                          <%= 'opacity-50 cursor-not-allowed' if @website.rendering_mode_locked? %>">
              <%= f.radio_button :rendering_mode, 'client',
                                 class: 'mt-1 h-4 w-4 text-blue-600',
                                 disabled: @website.rendering_mode_locked?,
                                 data: { action: 'change->rendering-mode#toggleClientOptions' } %>
              <div class="ml-3">
                <span class="block font-medium text-gray-900">Client Rendering (A Themes)</span>
                <span class="block text-sm text-gray-500 mt-1">
                  Client-side JavaScript application using Astro.
                  Themes: Amsterdam, Athens, Austin
                </span>
              </div>
            </label>
          </div>
        </div>

        <!-- Client Theme Selection (shown when client mode selected) -->
        <div id="client-theme-options"
             class="<%= 'hidden' unless @website.client_rendering? %>"
             data-rendering-mode-target="clientOptions">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Select Client Theme
          </label>
          <%= f.select :client_theme_name,
                       @client_themes.map { |t| [t.friendly_name, t.name] },
                       { include_blank: '-- Select a theme --' },
                       class: 'mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500',
                       disabled: @website.rendering_mode_locked? %>

          <% @client_themes.each do |theme| %>
            <div class="mt-4 p-4 border rounded-lg hidden"
                 data-theme-preview="<%= theme.name %>">
              <h4 class="font-medium"><%= theme.friendly_name %></h4>
              <p class="text-sm text-gray-600 mt-1"><%= theme.description %></p>
              <% if theme.preview_image_url.present? %>
                <img src="<%= theme.preview_image_url %>"
                     alt="<%= theme.friendly_name %> preview"
                     class="mt-3 rounded border max-w-full h-auto">
              <% end %>
            </div>
          <% end %>
        </div>

        <% unless @website.rendering_mode_locked? %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4">
            <p class="text-red-800 text-sm">
              <strong>Warning:</strong> This setting determines how your entire website
              is rendered and cannot be easily changed after you start adding content.
              Choose carefully.
            </p>
          </div>

          <div class="flex justify-end">
            <%= f.submit 'Save Rendering Mode',
                         class: 'px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2' %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

#### Step 6.3: Stimulus Controller for Form Interaction

```javascript
// app/javascript/controllers/rendering_mode_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clientOptions"]

  connect() {
    this.updateClientOptionsVisibility()
    this.setupThemePreview()
  }

  toggleClientOptions(event) {
    this.updateClientOptionsVisibility()
  }

  updateClientOptionsVisibility() {
    const clientRadio = this.element.querySelector('input[value="client"]')
    if (clientRadio && clientRadio.checked) {
      this.clientOptionsTarget.classList.remove('hidden')
    } else {
      this.clientOptionsTarget.classList.add('hidden')
    }
  }

  setupThemePreview() {
    const select = this.element.querySelector('select[name*="client_theme_name"]')
    if (select) {
      select.addEventListener('change', (e) => this.showThemePreview(e.target.value))
      // Show initial preview if theme selected
      if (select.value) {
        this.showThemePreview(select.value)
      }
    }
  }

  showThemePreview(themeName) {
    // Hide all previews
    this.element.querySelectorAll('[data-theme-preview]').forEach(el => {
      el.classList.add('hidden')
    })

    // Show selected preview
    if (themeName) {
      const preview = this.element.querySelector(`[data-theme-preview="${themeName}"]`)
      if (preview) {
        preview.classList.remove('hidden')
      }
    }
  }
}
```

#### Step 6.4: Add Tenant Admin Routes

```ruby
# config/routes.rb - add to tenant_admin namespace

namespace :tenant_admin do
  # ... existing routes ...

  resource :rendering_mode, only: [:show, :update], controller: 'rendering_mode'
end
```

---

### Phase 7: Nginx/Infrastructure Configuration

#### Step 7.1: Nginx Configuration (Production)

```nginx
# /etc/nginx/sites-available/propertywebbuilder

upstream rails_app {
    server 127.0.0.1:3000;
    keepalive 32;
}

upstream astro_client {
    server 127.0.0.1:4321;
    keepalive 32;
}

server {
    listen 80;
    listen 443 ssl http2;
    server_name *.propertywebbuilder.com;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/propertywebbuilder.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/propertywebbuilder.com/privkey.pem;

    # All requests go to Rails first
    # Rails determines if it should proxy to Astro based on rendering_mode
    location / {
        proxy_pass http://rails_app;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";

        proxy_buffering off;
        proxy_read_timeout 300;
    }

    # Static assets - serve directly
    location /assets/ {
        alias /var/www/propertywebbuilder/public/assets/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Active Storage
    location /rails/active_storage/ {
        proxy_pass http://rails_app;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }
}
```

#### Step 7.2: Environment Variables

```bash
# .env.production

# Astro client server URL (for reverse proxy)
ASTRO_CLIENT_URL=http://127.0.0.1:4321

# JWT secret for proxy auth tokens (use Rails secret or separate)
# PROXY_AUTH_SECRET defaults to Rails.application.secret_key_base
```

#### Step 7.3: Docker Compose (Development)

```yaml
# docker-compose.yml

version: '3.8'

services:
  rails:
    build: .
    ports:
      - "3000:3000"
    environment:
      - ASTRO_CLIENT_URL=http://astro:4321
      - DATABASE_URL=postgres://postgres:password@db:5432/pwb_development
    depends_on:
      - db
      - astro
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle

  astro:
    build:
      context: ../pwb-astrojs-client
      dockerfile: Dockerfile
    ports:
      - "4321:4321"
    environment:
      - API_BASE_URL=http://rails:3000
    volumes:
      - ../pwb-astrojs-client:/app
      - node_modules:/app/node_modules

  db:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  bundle_cache:
  node_modules:
  postgres_data:
```

---

### Phase 8: Astro Client Updates

#### Step 8.1: Auth Middleware for Astro

```typescript
// src/middleware/auth.ts (Astro client)
import { defineMiddleware } from 'astro:middleware';
import jwt from 'jsonwebtoken';

interface AuthPayload {
  user_id: number;
  website_id: number;
  exp: number;
}

export const authMiddleware = defineMiddleware(async ({ request, locals }, next) => {
  // Check for auth token from Rails proxy
  const authToken = request.headers.get('X-Auth-Token');

  if (authToken) {
    try {
      const secret = import.meta.env.PROXY_AUTH_SECRET;
      const payload = jwt.verify(authToken, secret) as AuthPayload;

      locals.user = {
        id: payload.user_id,
        websiteId: payload.website_id,
        authenticated: true
      };
    } catch (error) {
      console.error('Auth token verification failed:', error);
      locals.user = { authenticated: false };
    }
  } else {
    locals.user = { authenticated: false };
  }

  // Extract website info from headers
  locals.website = {
    id: request.headers.get('X-Website-Id'),
    slug: request.headers.get('X-Website-Slug'),
    theme: request.headers.get('X-Client-Theme'),
    renderingMode: request.headers.get('X-Rendering-Mode')
  };

  return next();
});
```

#### Step 8.2: Client Config Fetching

```typescript
// src/lib/api/clientConfig.ts (Astro client)

export interface ClientConfig {
  rendering_mode: 'client';
  client_theme: {
    name: string;
    config: Record<string, string>;
    schema: ThemeSchema;
  };
  website: {
    company_display_name: string;
    logo_url: string;
    favicon_url: string;
    supported_locales: string[];
    default_client_locale: string;
    dark_mode_setting: string;
  };
  css_variables: string;
}

export async function fetchClientConfig(websiteSlug: string): Promise<ClientConfig> {
  const apiBase = import.meta.env.API_BASE_URL || '';

  const response = await fetch(`${apiBase}/api_public/v1/client-config`, {
    headers: {
      'X-Website-Slug': websiteSlug,
      'Accept': 'application/json'
    }
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch client config: ${response.status}`);
  }

  return response.json();
}
```

#### Step 8.3: Theme Layout Selection

```astro
---
// src/layouts/ClientThemeLayout.astro
import AmsterdamLayout from './themes/AmsterdamLayout.astro';
import AthensLayout from './themes/AthensLayout.astro';
import AustinLayout from './themes/AustinLayout.astro';
import BaseLayout from './BaseLayout.astro';

interface Props {
  themeName: string;
  themeConfig: Record<string, string>;
}

const { themeName, themeConfig } = Astro.props;

const THEME_LAYOUTS = {
  amsterdam: AmsterdamLayout,
  athens: AthensLayout,
  austin: AustinLayout,
} as const;

const Layout = THEME_LAYOUTS[themeName as keyof typeof THEME_LAYOUTS] || BaseLayout;

// Generate CSS variables from config
const cssVariables = Object.entries(themeConfig)
  .map(([key, value]) => `--${key.replace(/_/g, '-')}: ${value}`)
  .join('; ');
---

<style set:html={`:root { ${cssVariables} }`}></style>

<Layout>
  <slot />
</Layout>
```

---

### Phase 9: Testing

#### Step 9.1: Model Specs

```ruby
# spec/models/pwb/client_theme_spec.rb
require 'rails_helper'

RSpec.describe Pwb::ClientTheme, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:friendly_name) }
    it { should validate_uniqueness_of(:name) }
  end

  describe 'scopes' do
    let!(:enabled_theme) { create(:client_theme, enabled: true) }
    let!(:disabled_theme) { create(:client_theme, enabled: false) }

    it 'returns only enabled themes' do
      expect(described_class.enabled).to include(enabled_theme)
      expect(described_class.enabled).not_to include(disabled_theme)
    end
  end

  describe '#config_for_website' do
    let(:theme) { create(:client_theme, default_config: { 'primary_color' => '#FF0000' }) }
    let(:website) { create(:website, client_theme_config: { 'primary_color' => '#00FF00' }) }

    it 'merges website overrides with defaults' do
      config = theme.config_for_website(website)
      expect(config['primary_color']).to eq('#00FF00')
    end
  end
end

# spec/models/concerns/pwb/website_rendering_mode_spec.rb
require 'rails_helper'

RSpec.describe Pwb::WebsiteRenderingMode, type: :model do
  describe 'validations' do
    let(:website) { build(:website) }

    it 'requires client_theme_name when client rendering' do
      website.rendering_mode = 'client'
      website.client_theme_name = nil
      expect(website).not_to be_valid
      expect(website.errors[:client_theme_name]).to be_present
    end

    it 'validates client theme exists' do
      website.rendering_mode = 'client'
      website.client_theme_name = 'nonexistent'
      expect(website).not_to be_valid
    end
  end

  describe '#rendering_mode_locked?' do
    let(:website) { create(:website, :provisioned) }

    it 'returns true when website has content' do
      create(:page_content, website: website)
      expect(website.rendering_mode_locked?).to be true
    end

    it 'returns false for new websites' do
      new_website = create(:website)
      expect(new_website.rendering_mode_locked?).to be false
    end
  end
end
```

#### Step 9.2: Controller Specs

```ruby
# spec/controllers/pwb/client_proxy_controller_spec.rb
require 'rails_helper'

RSpec.describe Pwb::ClientProxyController, type: :controller do
  let(:client_theme) { create(:client_theme, name: 'amsterdam') }
  let(:website) { create(:website, rendering_mode: 'client', client_theme_name: 'amsterdam') }

  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe 'GET #public_proxy' do
    context 'when Astro server is available' do
      before do
        stub_request(:get, "#{ENV['ASTRO_CLIENT_URL']}/")
          .to_return(status: 200, body: '<html>Astro Content</html>')
      end

      it 'proxies the request to Astro' do
        get :public_proxy, params: { path: '' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Astro Content')
      end
    end

    context 'when website uses Rails rendering' do
      let(:website) { create(:website, rendering_mode: 'rails') }

      it 'raises routing error' do
        expect {
          get :public_proxy, params: { path: '' }
        }.to raise_error(ActionController::RoutingError)
      end
    end
  end

  describe 'GET #admin_proxy' do
    let(:user) { create(:user) }

    before do
      sign_in user
      create(:user_membership, user: user, website: website, role: 'admin')
    end

    it 'includes auth headers in proxy request' do
      stub_request(:get, "#{ENV['ASTRO_CLIENT_URL']}/manage-content/themes")
        .to_return(status: 200, body: '<html>Admin</html>')

      get :admin_proxy, params: { path: 'themes' }

      expect(WebMock).to have_requested(:get, "#{ENV['ASTRO_CLIENT_URL']}/manage-content/themes")
        .with(headers: { 'X-User-Id' => user.id.to_s })
    end
  end
end
```

#### Step 9.3: Request Specs

```ruby
# spec/requests/api_public/v1/client_themes_spec.rb
require 'rails_helper'

RSpec.describe 'Client Themes API', type: :request do
  let!(:amsterdam) { create(:client_theme, name: 'amsterdam', friendly_name: 'Amsterdam Modern') }
  let!(:athens) { create(:client_theme, name: 'athens', friendly_name: 'Athens Classic') }
  let!(:disabled) { create(:client_theme, name: 'disabled', enabled: false) }

  describe 'GET /api_public/v1/client-themes' do
    it 'returns enabled client themes' do
      get '/api_public/v1/client-themes'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      names = json['client_themes'].map { |t| t['name'] }
      expect(names).to include('amsterdam', 'athens')
      expect(names).not_to include('disabled')
    end
  end

  describe 'GET /api_public/v1/client-themes/:name' do
    it 'returns theme details' do
      get '/api_public/v1/client-themes/amsterdam'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['client_theme']['name']).to eq('amsterdam')
      expect(json['client_theme']['friendly_name']).to eq('Amsterdam Modern')
    end

    it 'returns 404 for unknown theme' do
      get '/api_public/v1/client-themes/unknown'
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

---

### Phase 10: Deployment Checklist

#### Pre-Deployment

- [ ] Run migrations in staging
- [ ] Seed client themes data
- [ ] Configure `ASTRO_CLIENT_URL` environment variable
- [ ] Deploy Astro client to its server
- [ ] Test proxy connectivity between Rails and Astro
- [ ] Verify auth token generation/verification

#### Deployment

- [ ] Deploy Rails application with new code
- [ ] Run migrations: `rails db:migrate`
- [ ] Seed client themes: `rails db:seed:client_themes`
- [ ] Verify API endpoints respond correctly
- [ ] Test rendering mode selection in tenant admin

#### Post-Deployment

- [ ] Monitor proxy error rates
- [ ] Check Astro server logs for auth failures
- [ ] Verify existing Rails-rendered websites unaffected
- [ ] Test client-rendered website creation flow

---

## Summary

This reverse proxy approach provides:

1. **Single domain** - Users access everything through Rails URLs
2. **Centralized auth** - Rails handles all authentication
3. **Clean separation** - Rails mode unchanged, client mode fully isolated
4. **Early decision** - Rendering mode set once at deployment
5. **Separate theme models** - `Pwb::Theme` for Rails, `Pwb::ClientTheme` for Astro

The key architectural principle: **B themes and A themes are completely different systems that happen to share the same API for data retrieval.**
