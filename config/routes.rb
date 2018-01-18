Pwb::Engine.routes.draw do


  # devise_for :users, class_name: "Pwb::User", module: :devise
  root to: 'welcome#index'
  resources :welcome, only: :index

  # admin_constraint = lambda do |request|
  #   request.env['warden'].authenticate? and request.env['warden'].user.admin?
  # end
  # constraints admin_constraint do
  #   mount Logster::Web, at: "/logs"
  # end

  authenticate :user do
    get '/propertysquares' => 'squares#vue'
    get '/propertysquares/*path' => 'squares#vue'
    get '/squares/:client_id' => 'squares#show_client'
    get '/squares/:client_id/:prop_id' => 'squares#show_prop'
    get "/admin" => "admin_panel#show"
    get "/admin/*path" => "admin_panel#show"
    get "/admin-1" => "admin_panel#show_legacy_1"
    get "/admin-1/*path" => "admin_panel#show_legacy_1"
    scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
      get "/admin" => "admin_panel#show", as: "admin_with_locale"
      get "/admin/*path" => "admin_panel#show"
      get "/admin-1" => "admin_panel#show_legacy_1", as: "admin_with_locale_legacy"
      get "/admin-1/*path" => "admin_panel#show_legacy_1"
    end
    get '/config' => 'config#show'
    get '/config/:params' => 'config#show'

  end

  get "/custom_css/:theme_name" => "css#custom_css", as: "custom_css"


  # We need to define devise_for just omniauth_callbacks:auth_callbacks otherwise it does not work with scoped locales
  # see https://github.com/plataformatec/devise/issues/2813 &
  # https://github.com/plataformatec/devise/wiki/How-To:-OmniAuth-inside-localized-scope
  devise_for :users, class_name: "Pwb::User", only: :omniauth_callbacks, controllers: { omniauth_callbacks: 'pwb/devise/omniauth_callbacks' }


  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do

    devise_scope :user do
      get "/users/edit_success" => "devise/registrations#edit_success", as: "user_edit_success"
    end

    # We define here a route inside the locale thats just saves the current locale in the session
    get 'omniauth/:provider' => 'omniauth#localized', as: :localized_omniauth


    # https://github.com/plataformatec/devise/wiki/How-To:-Use-devise-inside-a-mountable-engine
    devise_for :users, skip: :omniauth_callbacks, class_name: "Pwb::User", module: :devise, :controllers => { :registrations => "pwb/devise/registrations", omniauth_callbacks: 'pwb/devise/omniauth_callbacks' }
    # specifying controllers above is from:
    # https://github.com/plataformatec/devise/wiki/How-To:-Customize-the-redirect-after-a-user-edits-their-profile



    get "/" => "welcome#index", as: "home"
    get "/p/:page_slug" => "pages#show_page", as: "show_page"
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


    get "/admin" => "admin_panel#show"
    get "/admin/*path" => "admin_panel#show"

  end

  namespace :api_ext do
    namespace :v1 do
      jsonapi_resources :props
      post '/properties/create_with_token' => 'props#create_with_token'
      # post '/properties/bulk_create_with_token' => 'props#bulk_create_with_token'
    end
  end

  authenticate :user do
    namespace :import do
      get "/mls_experiment" => "mls#experiment"
      get "/mls" => "mls#retrieve"
      get "/scrapper" => "scrapper#from_webpage"
      get "/scrapper/from_api" => "scrapper#from_api"
      post "/properties/retrieve_from_pwb" => "properties#retrieve_from_pwb"
      post "/properties/retrieve_from_mls" => "properties#retrieve_from_mls"
      post "/properties/retrieve_from_mls" => "properties#retrieve_from_mls"
      post "/translations" => "translations#multiple"
      post "/web_contents" => "web_contents#multiple"
    end
    namespace :export do
      get "/translations/all" => "translations#all"
      get "/web_contents/all" => "web_contents#all"
      get "/website/all" => "website#all"
      get "/properties" => "properties#all"
    end

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

        post '/pages/photos/:page_slug/:page_part_key/:block_label' => 'page#set_photo'
        # post '/cms-pages/photos/:page_id/:block_label' => 'cms_pages#set_photo'
        # jsonapi_resources :cms_pages


        get "/web-contents" => "agency#infos"
        jsonapi_resources :lite_properties
        jsonapi_resources :properties
        # jsonapi_resources :clients
        jsonapi_resources :web_contents
        resources :contacts

        get "/links" => "links#index"
        put "/links" => "links#bulk_update"

        get "/themes" => "themes#index"
        get "/mls" => "mls#index"
        get "/select_values" => "select_values#by_field_names"

        # TODO - rename properties below to prop
        post "properties/update_extras" => "properties#update_extras"

        delete "properties/photos/:id" => "properties#remove_photo"
        post '/properties/bulk_create' => 'properties#bulk_create'
        post '/properties/:id/photo' => 'properties#add_photo'
        post '/properties/:id/photo_from_url' => 'properties#add_photo_from_url'
        put "properties/:id/order_photos" => "properties#order_photos"

        post "properties/set_owner" => "properties#set_owner"
        post "properties/unset_owner" => "properties#unset_owner"


        put '/web_contents/photos/:id/:content_tag' => 'web_contents#update_photo'
        # above is used by logo and about_me photos
        # where only one photo is allowed

        post '/web_contents/photo/:tag' => 'web_contents#create_content_with_photo'
        # above for carousel photos where I need to be able to
        # create content along with the photo

      end
    end

    # comfy_route :cms_admin, :path => '/comfy-admin'

    # # Make sure this routeset is defined last
    # comfy_route :cms, :path => '/comfy', :sitemap => false

  end
end
