Rails.application.routes.draw do
  # Silence Chrome DevTools MCP requests
  get '/.well-known/appspecific/com.chrome.devtools.json', to: proc { [204, {}, []] }

  # Health check endpoints for monitoring and load balancers
  get '/health', to: 'health#live'
  get '/health/live', to: 'health#live'
  get '/health/ready', to: 'health#ready'
  get '/health/details', to: 'health#details'

  # On-demand TLS verification endpoint
  # Reverse proxies (like Caddy) query this to verify domains before issuing certificates
  get '/tls/check', to: 'pwb/tls#check'

  # SEO: XML Sitemap and robots.txt (dynamic per-tenant)
  get '/sitemap.xml', to: 'sitemaps#index', defaults: { format: 'xml' }
  get '/robots.txt', to: 'robots#index', defaults: { format: 'text' }

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  get '/api-public-docs', to: 'api_public_docs#index'

  if Rails.env.development?
    mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
  end
  post "/graphql", to: "graphql#execute"

  # Tenant Admin - Cross-tenant management dashboard
  # Note: Authentication only for now, authorization will be added in Phase 2
  namespace :tenant_admin do
    root to: 'dashboard#index'

    resources :websites do
      member do
        post :seed
      end
      # Nested resources for tenant-specific data
      resources :users, only: %i[index show]
      resources :agencies, only: %i[index show]
      resources :props, only: %i[index show]
      resources :pages, only: %i[index show]
      resources :admins, controller: 'website_admins', only: %i[index create destroy]
    end

    resources :users
    resources :agencies, only: %i[index show new create edit update destroy]
    resources :props, only: %i[index show]
    resources :pages, only: %i[index show]
    resources :page_parts, only: %i[index show]
    resources :contents, only: %i[index show]
    resources :messages, only: %i[index show]
    resources :contacts, only: %i[index show]

    # Security & Audit
    resources :auth_audit_logs, only: %i[index show] do
      collection do
        get 'user/:user_id', action: :user_logs, as: :user
        get 'ip/:ip', action: :ip_logs, as: :ip, constraints: { ip: /[^\/]+/ }
      end
    end
  end

  # Site Admin - Single website/tenant management dashboard
  # Scoped to current website via SubdomainTenant concern
  # Note: Available to any logged in user for now, authorization will be added later
  namespace :site_admin do
    root to: 'dashboard#index'

    # Domain management for custom domains
    resource :domain, only: %i[show update] do
      post :verify
    end

    # Image library API for page part editor
    resources :images, only: %i[index create]

    resources :props, only: %i[index show] do
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
        get 'edit', to: 'props#edit_general' # Default to general tab
        patch :update
      end

      # Nested resources for sale listings
      resources :sale_listings, controller: 'props/sale_listings', only: %i[new create edit update destroy] do
        member do
          patch :activate
          patch :archive
          patch :unarchive
        end
      end

      # Nested resources for rental listings
      resources :rental_listings, controller: 'props/rental_listings', only: %i[new create edit update destroy] do
        member do
          patch :activate
          patch :archive
          patch :unarchive
        end
      end
    end
    resources :pages, only: %i[index show edit update] do
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
    resources :users, only: %i[index show]

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

    # Properties Settings
    namespace :properties do
      get 'settings', to: 'settings#index', as: 'settings'
      get 'settings/:category', to: 'settings#show', as: 'settings_category'
      post 'settings/:category', to: 'settings#create'
      patch 'settings/:category/:id', to: 'settings#update'
      delete 'settings/:category/:id', to: 'settings#destroy'
    end

    # Website Settings
    namespace :website do
      get 'settings', to: 'settings#show', as: 'settings'
      get 'settings/:tab', to: 'settings#show', as: 'settings_tab'
      patch 'settings', to: 'settings#update'
      # Navigation links management
      patch 'settings/links', to: 'settings#update_links', as: 'update_links'
      # Notification testing
      post 'test_notifications', to: 'settings#test_notifications'
    end
  end

  # devise_for :users, class_name: "Pwb::User", module: :devise
  scope module: :pwb do
    root to: "welcome#index"
    resources :welcome, only: :index

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

    # get "/config" => "config#show"
    # get "/config/:params" => "config#show"
    # get "/v-admin" => "admin_panel_vue#show"
    # get "/v-admin/*path" => "admin_panel_vue#show"

    # get "/v-public" => "vue_public#show"
    # get "/v-public/*path" => "vue_public#show"
    # get "/v-public-2" => "vue_public_2#show"
    # get "/v-public-2/*path" => "vue_public_2#show"

    get "/firebase_login" => "firebase_login#index"
    get "/firebase_sign_up" => "firebase_login#sign_up"
    get "/firebase_forgot_password" => "firebase_login#forgot_password"
    get "/firebase_change_password" => "firebase_login#change_password"

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
      devise_for :users, skip: :omniauth_callbacks, class_name: "Pwb::User", module: :devise, controllers: {
        registrations: "pwb/devise/registrations",
        omniauth_callbacks: "pwb/devise/omniauth_callbacks",
        sessions: "pwb/devise/sessions",
        passwords: "pwb/devise/passwords"
      }
      # specifying controllers above is from:
      # https://github.com/plataformatec/devise/wiki/How-To:-Customize-the-redirect-after-a-user-edits-their-profile

      get "/" => "welcome#index", as: "home"
      get "/p/:page_slug" => "pages#show_page", as: "show_page"
      get "/p/:page_slug/:page_part_key" => "pages#show_page_part", as: "show_page_part"
      # get "/c/:page_slug" => "comfy#show"

      get "/properties/for-rent/:id/:url_friendly_title" => "props#show_for_rent", as: "prop_show_for_rent"
      get "/properties/for-sale/:id/:url_friendly_title" => "props#show_for_sale", as: "prop_show_for_sale"

      get "/about-us" => "pages#show_page", page_slug: "about-us"
      get "/contact-us" => "contact_us#index", as: "contact_us" #
      post "/contact_us" => "contact_us#contact_us_ajax"

      get "/buy" => "search#buy"
      get "/rent" => "search#rent"

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
        resources :page_parts, only: %i[show update]
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
      get "/properties/:id" => "properties#show"
      get "/properties" => "properties#search"
      get "/pages/:id" => "pages#show"
      get "/pages/by_slug/:slug" => "pages#show_by_slug"
      get "/translations" => "translations#index"
      get "/links" => "links#index"
      get "/site_details" => "site_details#index"
      get "/select_values" => "select_values#index"
      post "/auth/firebase" => "auth#firebase"
    end
  end

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
    end
  end
end
