Rails.application.routes.draw do
  # Silence Chrome DevTools MCP requests
  get '/.well-known/appspecific/com.chrome.devtools.json', to: proc { [204, {}, []] }

  # Health check endpoints for monitoring and load balancers
  get '/health', to: 'health#live'
  get '/health/live', to: 'health#live'
  get '/health/ready', to: 'health#ready'
  get '/health/details', to: 'health#details'

  # E2E test support endpoints (only available in e2e environment)
  namespace :e2e, defaults: { format: :json } do
    get 'health', to: 'test_support#health'
    post 'reset_website_settings', to: 'test_support#reset_website_settings'
    post 'reset_all', to: 'test_support#reset_all'
  end

  # On-demand TLS verification endpoint
  # Reverse proxies (like Caddy) query this to verify domains before issuing certificates
  get '/tls/check', to: 'pwb/tls#check'

  # ===================
  # Client Proxy Routes (for Astro A themes)
  # ===================
  # These routes proxy requests to the Astro client for websites using client rendering mode.
  # The constraint checks if the website uses client rendering and the path is not excluded.
  constraints ClientRenderingConstraint.new do
    # Admin routes require authentication
    match '/client-admin/*path', to: 'pwb/client_proxy#admin_proxy', via: :all
    match '/client-admin', to: 'pwb/client_proxy#admin_proxy', via: :all

    # Root path (/) must be explicitly defined as *path doesn't match empty path
    root to: 'pwb/client_proxy#public_proxy', as: :client_proxy_root

    # All other non-excluded paths go to public proxy
    # This is a catch-all, so it should be last in the constraint block
    match '*path', to: 'pwb/client_proxy#public_proxy', via: :all, as: :client_proxy_catchall
  end

  # SEO: XML Sitemap and robots.txt (dynamic per-tenant)
  get '/sitemap.xml', to: 'sitemaps#index', defaults: { format: 'xml' }
  get '/robots.txt', to: 'robots#index', defaults: { format: 'text' }

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  get '/api-public-docs', to: 'api_public_docs#index'

  if Rails.env.development?
    mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"

    # Component preview and documentation (Lookbook)
    mount Lookbook::Engine, at: "/lookbook"
  end

  post "/graphql", to: "graphql#execute"

  # Tenant Admin - Cross-tenant management dashboard
  # Note: Authentication only for now, authorization will be added in Phase 2
  namespace :tenant_admin do
    root to: 'dashboard#index'

    resources :websites do
      member do
        post :seed
        get :seed, action: :seed_form
        post :retry_provisioning
        get :appearance, action: :appearance_form
        patch :update_appearance
      end
      # Nested resources for tenant-specific data
      resources :users, only: %i[index show]
      resources :agencies, only: %i[index show]
      resources :props, only: %i[index show]
      resources :pages, only: %i[index show]
      resources :admins, controller: 'website_admins', only: %i[index create destroy]
    end

    resources :users do
      member do
        post :transfer_ownership
      end
    end
    resources :agencies, only: %i[index show new create edit update destroy]

    # Subscription Management
    resources :plans
    resources :subscriptions do
      member do
        post :activate
        post :cancel
        post :change_plan
      end
      collection do
        post :expire_trials
      end
    end
    resources :props, only: %i[index show]
    resources :pages, only: %i[index show]

    # Themes & Palettes Dashboard
    resources :themes, only: %i[index show] do
      member do
        get :websites
      end
    end
    resources :page_parts, only: %i[index show]
    resources :contents, only: %i[index show]
    resources :messages, only: %i[index show]
    resources :contacts, only: %i[index show]

    # Support Tickets - Platform-wide support management
    resources :support_tickets, only: %i[index show] do
      member do
        patch :assign
        patch :change_status
        post :add_message
      end
    end

    # Subdomain Pool Management
    resources :subdomains do
      member do
        post :release
      end
      collection do
        post :release_expired
        post :populate
      end
    end

    # Custom Domain Management
    resources :domains, only: %i[index show edit update] do
      member do
        post :verify
        delete :remove
      end
    end

    # Security & Audit
    resources :auth_audit_logs, only: %i[index show] do
      collection do
        get 'user/:user_id', action: :user_logs, as: :user
        get 'ip/:ip', action: :ip_logs, as: :ip, constraints: { ip: /[^\/]+/ }
      end
    end

    # Email Template Management (cross-tenant)
    resources :email_templates do
      member do
        get :preview
      end
      collection do
        get :preview_default
      end
    end

    # Tenant Settings (singleton resource)
    resource :settings, only: %i[show update], controller: 'settings'

    # Platform Notifications - ntfy management and metrics
    resources :platform_notifications, only: %i[index] do
      collection do
        post :test
        post :send_daily_summary
        post :send_test_alert
      end
    end

    # Site Imports - Scrape content from existing PWB websites to create seed packs
    resources :site_imports, only: %i[index new create show destroy] do
      member do
        post :apply
      end
    end

    # Shard Management
    resources :shards, only: %i[index show] do
      member do
        get :health
        get :websites
        get :statistics
      end
      collection do
        get :health_summary
      end
    end

    # Shard operations on websites
    resources :websites do
      member do
        get :shard, action: :shard_form
        patch :assign_shard
        get :shard_history
      end
    end

    # Shard Audit Logs
    resources :shard_audit_logs, only: %i[index show] do
      collection do
        get 'website/:website_id', action: :website_logs, as: :website
        get 'user/:email', action: :user_logs, as: :user
      end
    end
  end

  # Site Admin - Single website/tenant management dashboard
  # Scoped to current website via SubdomainTenant concern
  # Note: Available to any logged in user for now, authorization will be added later
  namespace :site_admin do
    root to: 'dashboard#index'

    # Onboarding wizard for new users
    get 'onboarding', to: 'onboarding#show', as: 'onboarding'
    get 'onboarding/:step', to: 'onboarding#show'
    post 'onboarding', to: 'onboarding#update'
    post 'onboarding/:step', to: 'onboarding#update'
    post 'onboarding/:step/skip', to: 'onboarding#skip_step', as: 'onboarding_skip'
    get 'onboarding/:step/skip', to: 'onboarding#skip_step'
    get 'onboarding/complete', to: 'onboarding#complete', as: 'onboarding_complete'
    post 'onboarding/restart', to: 'onboarding#restart', as: 'onboarding_restart'

    # Guided tour completion tracking
    post 'tour/complete', to: 'tour#complete', as: 'tour_complete'

    # Domain management for custom domains
    resource :domain, only: %i[show update] do
      post :verify
    end

    # Agency profile management
    resource :agency, only: %i[edit update], controller: 'agency'

    # Billing/subscription management
    resource :billing, only: %i[show], controller: 'billing'

    # Activity logs
    resources :activity_logs, only: %i[index show]

    # Image library API for page part editor
    resources :images, only: %i[index create]

    # Media Library
    resources :media_library, only: %i[index show new create edit update destroy] do
      collection do
        post :bulk_destroy
        post :bulk_move
        get :folders
        post :create_folder
        patch 'folders/:id', action: :update_folder, as: :update_folder
        delete 'folders/:id', action: :destroy_folder, as: :destroy_folder
      end
    end

    # Property bulk import/export
    scope :property_import_export, controller: 'property_import_export', as: 'property_import_export' do
      get '/', action: :index
      post :import, action: :import
      get :export, action: :export
      get :download_template, action: :download_template
      delete :clear_results, action: :clear_results
    end

    # Property URL import (scraping)
    scope :property_url_import, controller: 'property_url_import', as: 'property_url_import' do
      get '/', action: :new
      post '/', action: :create
      post :manual_html, action: :manual_html
      get ':id/preview', action: :preview, as: :preview
      post ':id/confirm', action: :confirm_import, as: :confirm
      get :history, action: :history
      get :batch, action: :batch
      post :batch_process, action: :batch_process
    end

    # SEO Audit Dashboard
    resource :seo_audit, only: [:show], controller: 'seo_audit', as: 'seo_audit' do
      get '/', action: :index, on: :collection
    end

    resources :props, only: %i[index show new create] do
      member do
        get 'edit/general', to: 'props#edit_general', as: 'edit_general'
        get 'edit/text', to: 'props#edit_text', as: 'edit_text'
        get 'edit/sale_rental', to: 'props#edit_sale_rental', as: 'edit_sale_rental'
        get 'edit/location', to: 'props#edit_location', as: 'edit_location'
        get 'edit/labels', to: 'props#edit_labels', as: 'edit_labels'
        get 'edit/photos', to: 'props#edit_photos', as: 'edit_photos'
        post 'upload_photos', to: 'props#upload_photos', as: 'upload_photos'
        delete 'remove_photo', to: 'props#remove_photo', as: 'remove_photo'
        patch 'reorder_photos', to: 'props#reorder_photos', as: 'reorder_photos'
        patch 'update_photo_alt', to: 'props#update_photo_alt', as: 'update_photo_alt'
        get 'edit', to: 'props#edit_general' # Default to general tab
        patch :update
      end

      # Nested resources for sale listings
      resources :sale_listings, controller: 'props/sale_listings', only: %i[new create edit update destroy] do
        member do
          patch :activate
          patch :archive
          patch :unarchive
          patch :enable_game
          patch :disable_game
        end
      end

      # Nested resources for rental listings
      resources :rental_listings, controller: 'props/rental_listings', only: %i[new create edit update destroy] do
        member do
          patch :activate
          patch :archive
          patch :unarchive
          patch :enable_game
          patch :disable_game
        end
      end
    end
    resources :pages, only: %i[index show update] do
      member do
        get :settings
        patch :settings, action: :update_settings
        get :edit  # New edit page with page parts management
        patch :reorder_parts  # For drag-drop reordering
      end
      # Nested page parts for editing content blocks
      resources :page_parts, controller: 'pages/page_parts', only: %i[show edit update] do
        member do
          patch :toggle_visibility
        end
      end
    end
    resources :page_parts, only: %i[index show]
    resources :contents, only: %i[index show]
    resources :messages, only: %i[index show]
    resources :contacts, only: %i[index show]

    # Unified Inbox - CRM-style contact/message view
    resources :inbox, only: [:index] do
      member do
        get '/', action: :show, as: 'conversation'
      end
    end

    resources :users do
      member do
        post :resend_invitation
        patch :update_role
        patch :deactivate
        patch :reactivate
      end
    end

    # Email template management
    resources :email_templates do
      member do
        get :preview
      end
      collection do
        get :preview_default
      end
    end

    # Storage statistics and orphan monitoring
    resource :storage_stats, only: [:show] do
      post :cleanup
    end

    # Analytics dashboard for visitor tracking
    resource :analytics, only: [:show], controller: 'analytics' do
      get :traffic
      get :properties
      get :conversions
      get :realtime
    end

    # Embeddable Widgets for external websites
    resources :widgets do
      member do
        get :preview
      end
    end

    # Search Filter Management (Property Types, Features, etc.)
    namespace :search_filters do
      resources :property_types do
        member do
          patch :toggle_visibility
          patch :toggle_search
        end
        collection do
          post :reorder
          post :import_from_provider
        end
      end

      resources :features do
        member do
          patch :toggle_visibility
          patch :toggle_search
        end
        collection do
          post :reorder
          post :import_from_provider
        end
      end
    end

    # Properties Settings
    namespace :properties do
      get 'settings', to: 'settings#index', as: 'settings'
      get 'settings/:category', to: 'settings#show', as: 'settings_category'
      post 'settings/:category', to: 'settings#create'
      # Allow dots in :id (e.g., "types.apartment") by using constraint
      patch 'settings/:category/:id', to: 'settings#update', constraints: { id: /[^\/]+/ }
      delete 'settings/:category/:id', to: 'settings#destroy', constraints: { id: /[^\/]+/ }
    end

    # Website Settings
    namespace :website do
      get 'settings', to: 'settings#show', as: 'settings'
      get 'settings/:tab', to: 'settings#show', as: 'settings_tab'
      patch 'settings', to: 'settings#update'
      # Navigation links management
      patch 'settings/links', to: 'settings#update_links', as: 'update_links'
      # Reset search configuration to defaults
      delete 'settings/search/reset', to: 'settings#reset_search_config', as: 'reset_search_config'
      # Notification testing
      post 'test_notifications', to: 'settings#test_notifications'
    end

    # Support Tickets - Website admin support requests
    resources :support_tickets, only: %i[index show new create] do
      member do
        post :add_message
      end
    end

    # External Feed Configuration
    resource :external_feed, only: %i[show update] do
      post :test_connection
      post :clear_cache
    end
  end

  # devise_for :users, class_name: "Pwb::User", module: :devise
  scope module: :pwb do
    # Setup page for unseeded websites
    get "/setup" => "setup#index", as: "pwb_setup"
    post "/setup" => "setup#create"

    root to: "welcome#index"
    resources :welcome, only: :index

    # Currency preference
    post "/set_currency" => "currencies#set", as: "set_currency"

    # Locked website pages (email verification, registration pending)
    get "/resend_verification" => "locked#resend_verification", as: "resend_verification"
    post "/resend_verification" => "locked#submit_resend_verification"

    # Signup/Onboarding flow for new tenants
    get "/signup" => "signup#new", as: "signup"
    post "/signup/start" => "signup#start", as: "signup_start"
    get "/signup/configure" => "signup#configure", as: "signup_configure"
    post "/signup/configure" => "signup#save_configuration", as: "signup_save_configuration"
    get "/signup/provisioning" => "signup#provisioning", as: "signup_provisioning"
    post "/signup/provision" => "signup#provision", as: "signup_provision"
    get "/signup/status" => "signup#status", as: "signup_status"
    get "/signup/complete" => "signup#complete", as: "signup_complete"
    get "/signup/check_subdomain" => "signup#check_subdomain", as: "signup_check_subdomain"
    get "/signup/suggest_subdomain" => "signup#suggest_subdomain", as: "signup_suggest_subdomain"

    # Use same authorization as TenantAdminController for admin tools
    # Requires user email to be in TENANT_ADMIN_EMAILS env var
    require_relative '../lib/constraints/tenant_admin_constraint'
    constraints Constraints::TenantAdminConstraint.new do
      mount ActiveStorageDashboard::Engine => "/active_storage_dashboard"
      mount Logster::Web, at: "/logs"
      mount PgHero::Engine, at: "/pghero" if defined?(PgHero)

      # Performance monitoring dashboard (self-hosted APM)
      mount RailsPerformance::Engine, at: "/performance"

      # Background job monitoring dashboard (Solid Queue)
      mount MissionControl::Jobs::Engine, at: "/jobs"
    end






    # Legacy /admin routes - redirect to /site_admin
    # These provide backward compatibility for existing links using admin_with_locale_path
    get "/admin", to: redirect('/site_admin')
    get "/admin/*path", to: redirect('/site_admin')
    scope "(:locale)", locale: /#{I18n.available_locales.join('|')}/ do
      get "/admin", to: redirect('/site_admin'), as: "admin_with_locale"
      get "/admin/*path", to: redirect('/site_admin')
    end

    get "/pwb_login" => "firebase_login#index"
    get "/pwb_sign_up" => "firebase_login#sign_up"
    get "/pwb_forgot_password" => "firebase_login#forgot_password"
    get "/pwb_change_password" => "firebase_login#change_password"

    # Unified auth routes (work for both Firebase and Devise)
    delete "/auth/logout" => "auth#logout", as: :unified_logout


    get "/custom_css/:theme_name" => "css#custom_css", as: "custom_css"

    # We need to define devise_for just omniauth_callbacks:auth_callbacks otherwise it does not work with scoped locales
    # see https://github.com/plataformatec/devise/issues/2813 &
    # https://github.com/plataformatec/devise/wiki/How-To:-OmniAuth-inside-localized-scope
    devise_for :users, class_name: "Pwb::User", only: :omniauth_callbacks, controllers: { omniauth_callbacks: "pwb/devise/omniauth_callbacks" }

    scope "(:locale)", locale: /#{I18n.available_locales.join('|')}/ do
      devise_scope :user do
        get "/users/edit_success" => "devise/registrations#edit_success", as: "user_edit_success"
      end

      # We define here a route inside the locale thats just saves the current locale in the session
      get "omniauth/:provider" => "omniauth#localized", as: :localized_omniauth

      # https://github.com/plataformatec/devise/wiki/How-To:-Use-devise-inside-a-mountable-engine
      # Note: The deprecation warnings about 'resource received a hash argument' come from
      # Devise 4.9.4 internally and will be fixed in a future Devise release for Rails 8.2
      devise_for :users, skip: :omniauth_callbacks, class_name: "Pwb::User", module: :devise, controllers: {
        registrations: "pwb/devise/registrations",
        omniauth_callbacks: "pwb/devise/omniauth_callbacks",
        sessions: "pwb/devise/sessions",
        passwords: "pwb/devise/passwords"
      }
      # specifying controllers above is from:
      # https://github.com/plataformatec/devise/wiki/How-To:-Customize-the-redirect-after-a-user-edits-their-profile

      get "/" => "welcome#index", as: "home"

      # Price Game - "Guess the Price" shareable game for listings
      get "/g/:token" => "price_game#show", as: "price_game"
      post "/g/:token/guess" => "price_game#guess", as: "price_game_guess"
      post "/g/:token/share" => "price_game#track_share", as: "price_game_share"

      get "/p/:page_slug" => "pages#show_page", as: "show_page"
      # page_part_key can contain slashes like "cta/cta_split_image"
      get "/p/:page_slug/*page_part_key" => "pages#show_page_part", as: "show_page_part"
      # get "/c/:page_slug" => "comfy#show"

      get "/properties/for-rent/:id/:url_friendly_title" => "props#show_for_rent", as: "prop_show_for_rent"
      get "/properties/for-sale/:id/:url_friendly_title" => "props#show_for_sale", as: "prop_show_for_sale"

      get "/about-us" => "pages#show_page", page_slug: "about-us"
      get "/contact-us" => "contact_us#index", as: "contact_us" #
      post "/contact_us" => "contact_us#contact_us_ajax"

      get "/buy" => "search#buy"
      get "/rent" => "search#rent"

      # External property listings (from third-party feeds)
      # New URL structure aligned with internal listings:
      #   /external/buy, /external/rent - listing pages
      #   /external/for-sale/:ref/:title, /external/for-rent/:ref/:title - detail pages
      scope module: :site do
        # Type-specific index pages (like /buy and /rent for internal)
        get "external/buy" => "external_listings#buy", as: "external_buy"
        get "external/rent" => "external_listings#rent", as: "external_rent"

        # SEO-friendly show pages with listing type in path
        get "external/for-sale/:reference/:url_friendly_title" => "external_listings#show_for_sale",
            as: "external_show_for_sale"
        get "external/for-rent/:reference/:url_friendly_title" => "external_listings#show_for_rent",
            as: "external_show_for_rent"

        # API/AJAX endpoints (keep original paths for backward compatibility)
        resources :external_listings, only: [], param: :reference do
          collection do
            get :locations
            get :property_types
            get :filters
          end
          member do
            get :similar
          end
        end

        # Legacy redirects for old URL patterns
        get "external_listings" => "external_listings#legacy_index"
        get "external_listings/search" => "external_listings#legacy_index"
        get "external_listings/:reference" => "external_listings#legacy_show", as: "legacy_external_listing"

        # User's saved searches and favorites (token-based, no login required)
        namespace :my do
          resources :saved_searches, only: [:index, :show, :create, :update, :destroy] do
            collection do
              get :unsubscribe
              get :verify
            end
          end

          resources :saved_properties, path: "favorites", as: "favorites", only: [:index, :show, :create, :update, :destroy] do
            collection do
              post :check
            end
          end
        end
      end

      post "/search_ajax_for_sale" => "search#search_ajax_for_sale"
      post "/search_ajax_for_rent" => "search#search_ajax_for_rent"
      # post "/ajax_find_by_ref" => "search#ajax_find_by_ref"
      post "/request_property_info" => "props#request_property_info_ajax"

      # Legacy /admin routes within locale scope - redirect to /site_admin
      get "/admin", to: redirect('/site_admin')
      get "/admin/*path", to: redirect('/site_admin')

      # In-context editor
      get "/edit" => "editor#show", as: :editor

      namespace :editor do
        # page_part IDs can contain slashes like "faqs/faq_accordion"
        get "page_parts/*id" => "page_parts#show", as: :page_part
        patch "page_parts/*id" => "page_parts#update"
        put "page_parts/*id" => "page_parts#update"
        resource :theme_settings, only: %i[show update]
        resources :images, only: %i[index create]
      end

      get "/edit/*path" => "editor#show"
    end

    # namespace :api_ext do
    #   namespace :v1 do
    #     jsonapi_resources :props
    #     # below for habitat:
    #     post "/properties/create_with_token" => "props#create_with_token"
    #     # post '/properties/bulk_create_with_token' => 'props#bulk_create_with_token'
    #   end
    # end

    authenticate :user do
      namespace :import do
        get "/mls_experiment" => "mls#experiment"
        get "/mls" => "mls#retrieve"
        # get "/scrapper" => "scrapper#from_webpage"
        # get "/scrapper/from_api" => "scrapper#from_api"
        post "/properties/retrieve_from_pwb" => "properties#retrieve_from_pwb"
        post "/properties/retrieve_from_mls" => "properties#retrieve_from_mls"
        post "/properties/retrieve_from_mls" => "properties#retrieve_from_mls"
        post "/translations" => "translations#multiple"
        post "/web_contents" => "web_contents#multiple"
      end
      # namespace :export do
      #   get "/translations/all" => "translations#all"
      #   get "/web_contents/all" => "web_contents#all"
      #   get "/website/all" => "website#all"
      #   get "/properties" => "properties#all"
      # end

      namespace :export do
        get "/translations/all" => "translations#all"
        get "/web_contents/all" => "web_contents#all"
        get "/website/all" => "website#all"
        get "/properties" => "properties#all"
      end

      # comfy_route :cms_admin, :path => '/comfy-admin'

      # # Make sure this routeset is defined last
      # comfy_route :cms, :path => '/comfy', :sitemap => false
    end

    # API routes moved outside authenticate block to allow BYPASS_API_AUTH env var
    namespace :api do
      namespace :v1 do
        # get "/cms/tag/:tag_name" => "cms#tag"
        get "/translations/list/:locale" => "translations#list"

        # below gets FieldConfig values for a batch_key such as "person-titles"
        # and returns all the locale translations so an admin
        # can manage them..
        get "/translations/batch/:batch_key" => "translations#get_by_batch"
        post "/translations" => "translations#create_translation_value"

        post "/translations/create_for_locale" => "translations#create_for_locale"
        put "/translations/:id/update_for_locale" => "translations#update_for_locale"
        delete "/translations/:id" => "translations#delete_translation_values"

        # put "tenant" => "agency#update_legacy"
        put "/master_address" => "agency#update_master_address"

        get "/agency" => "agency#show"
        put "/agency" => "agency#update"
        put "/website" => "website#update"
        get "/infos" => "agency#infos"

        put "/pages" => "page#update"
        put "/pages/page_part_visibility" => "page#update_page_part_visibility"
        put "/pages/page_fragment" => "page#save_page_fragment"
        get "/pages/:page_name" => "page#show"

        # post '/page_fragments/photos/:page_id/:block_label' => 'page_fragments#set_photo'

        post "/pages/photos/:page_slug/:page_part_key/:block_label" => "page#set_photo"
        # post '/cms-pages/photos/:page_id/:block_label' => 'cms_pages#set_photo'
        # jsonapi_resources :cms_pages

        get "/web-contents" => "agency#infos"

        # Properties API endpoints (JSON format, compatible with previous JSONAPI structure)
        resources :lite_properties, only: %i[index show], path: 'lite-properties'
        resources :properties, only: %i[index show]
        # resources :clients
        resources :web_contents, only: %i[index show], path: 'web-contents'

        resources :contacts

        get "/links" => "links#index"
        put "/links" => "links#bulk_update"

        get "/themes" => "themes#index"
        get "/mls" => "mls#index"
        get "/select_values" => "select_values#by_field_names"

        # TODO: rename to update_features:
        post "properties/update_extras" => "properties#update_extras"

        delete "properties/photos/:id" => "properties#remove_photo"
        delete "properties/photos/:id/:prop_id" => "properties#remove_photo"
        post "/properties/bulk_create" => "properties#bulk_create"
        post "/properties/:id/photo" => "properties#add_photo"
        post "/properties/:id/photo_from_url" => "properties#add_photo_from_url"
        put "properties/:id/order_photos" => "properties#order_photos"

        post "properties/set_owner" => "properties#set_owner"
        post "properties/unset_owner" => "properties#unset_owner"

        put "/web_contents/photos/:id/:content_tag" => "web_contents#update_photo"
        # above is used by logo and about_me photos
        # where only one photo is allowed

        post "/web_contents/photo/:tag" => "web_contents#create_content_with_photo"
        # above for carousel photos where I need to be able to
        # create content along with the photo
      end
    end
  end

  namespace :api_public do
    namespace :v1 do
      # ==================================================
      # Locale-prefixed routes (preferred for CDN caching)
      # ==================================================
      # These routes include locale in the path for better cache key generation
      # Example: /api_public/v1/en/properties instead of /api_public/v1/properties?locale=en
      scope "/:locale", locale: /[a-z]{2}(-[A-Z]{2})?/ do
        # Properties
        get "/properties/:id" => "properties#show"
        get "/properties" => "properties#search"
        get "/properties/:id/schema" => "properties#schema"

        # Pages
        get "/pages/:id" => "pages#show"
        # get "/pages/by_slug/:slug" => "pages#show_by_slug"

        # Localized page with comprehensive SEO metadata
        # Returns full page data including OG tags, JSON-LD, translations, etc.
        get "/localized_page/by_slug/:page_slug" => "localized_pages#show"

        # Translations
        get "/translations" => "translations#index"

        # Testimonials
        get "/testimonials" => "testimonials#index"

        # Links
        get "/links" => "links#index"

        # Site details
        get "/site_details" => "site_details#index"

        # Client config with includes
        get "/client-config" => "website_client_config#show"

        # Search
        get "/search/config" => "search_config#index"
        get "/search/facets" => "search_facets#index"
      end

      # ==================================================
      # Non-locale routes (backward compatible)
      # ==================================================
      # These routes still support ?locale= query parameter
      get "/properties/:id" => "properties#show"
      get "/properties" => "properties#search"
      get "/properties/:id/schema" => "properties#schema"
      get "/pages/:id" => "pages#show"
      # get "/pages/by_slug/:slug" => "pages#show_by_slug"
      get "/translations" => "translations#index"
      get "/links" => "links#index"
      # get "/site_details" => "site_details#index"
      get "/select_values" => "select_values#index"
      get "/theme" => "theme#index"
      get "/themes/:theme_name/palettes" => "theme_palettes#index"
      get "/themes/:theme_name/palettes/:palette_id" => "theme_palettes#show"
      patch "/theme_settings/palette" => "theme_settings#update_palette"
      get "/search/config" => "search_config#index"
      get "/search/facets" => "search_facets#index"
      get "/testimonials" => "testimonials#index"
      get "/locales" => "locales#index"
      post "/enquiries" => "enquiries#create"
      post "/contact" => "contact#create"
      post "/auth/firebase" => "auth#firebase"
      get "/all-themes" => "all_themes#index"

      # Client Themes API (for Astro A themes)
      get "/client-themes" => "client_themes#index"
      get "/client-themes/:name" => "client_themes#show"
      get "/client-config" => "website_client_config#show"

      # Favorites API (server-persisted)
      resources :favorites, only: [:index, :show, :create, :update, :destroy] do
        collection do
          post :check
        end
      end

      # Saved Searches API
      resources :saved_searches, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :unsubscribe
        end
        collection do
          get :verify
        end
      end

      # Embeddable Widget API
      get "/widgets/:widget_key" => "widgets#show"
      get "/widgets/:widget_key/properties" => "widgets#properties"
      post "/widgets/:widget_key/impression" => "widgets#impression"
      post "/widgets/:widget_key/click" => "widgets#click"
    end
  end

  # Widget iframe/JavaScript serving routes (outside API namespace)
  get "/widget.js" => "widgets#javascript", as: :widget_js
  get "/widget/:widget_key" => "widgets#iframe", as: :widget_iframe

  # External Signup API
  # These endpoints are called by external signup UIs (like the signup_component)
  # to persist data in PropertyWebBuilder without needing to implement PWB models
  namespace :api do
    namespace :signup do
      post 'start', to: 'signups#start'
      post 'configure', to: 'signups#configure'
      post 'provision', to: 'signups#provision'
      get 'status', to: 'signups#status'
      get 'check_subdomain', to: 'signups#check_subdomain'
      get 'suggest_subdomain', to: 'signups#suggest_subdomain'
      get 'site_types', to: 'signups#site_types'
      get 'lookup_subdomain', to: 'signups#lookup_subdomain'

      # Email verification endpoints
      get 'verify_email', to: 'signups#verify_email'
      post 'resend_verification', to: 'signups#resend_verification'
      post 'complete_registration', to: 'signups#complete_registration'
    end
  end
end
