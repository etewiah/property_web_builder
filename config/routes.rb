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
    get "/admin" => "admin_panel#show"
    get "/admin/*path" => "admin_panel#show"
    scope "(:locale)", locale: /en|nl|es|fr|de|pt|it/ do
      get "/admin" => "admin_panel#show", as: "admin_with_locale"
      get "/admin/*path" => "admin_panel#show"
    end
  end

  get "/custom_css" => "css#custom_css", as: "custom_css"

  # TODO - get locales dynamically
  scope "(:locale)", locale: /en|nl|es|fr|de|pt|it|ca|ar|ru/ do

    devise_scope :user do
      get "/users/edit_success" => "devise/registrations#edit_success", as: "user_edit_success"
    end
    # https://github.com/plataformatec/devise/wiki/How-To:-Use-devise-inside-a-mountable-engine
    devise_for :users, class_name: "Pwb::User", module: :devise, :controllers => { :registrations => "pwb/devise/registrations" }
    # specifying controllers above is from:
    # https://github.com/plataformatec/devise/wiki/How-To:-Customize-the-redirect-after-a-user-edits-their-profile



    get "/" => "welcome#index", as: "home"
    get "/p/:page_slug" => "pages#show_page", as: "show_page"
    get "/c/:page_slug" => "comfy#show"

    get "/properties/for-rent/:id/:url_friendly_title" => "props#show_for_rent", as: "prop_show_for_rent"
    get "/properties/for-sale/:id/:url_friendly_title" => "props#show_for_sale", as: "prop_show_for_sale"

    get "/about-us" => "sections#about_us"
    # get "/sell" => "sections#sell"
    # get "/sell" => "comfy#show"
    get "/buy" => "search#buy"
    get "/rent" => "search#rent"

    get "/contact-us" => "sections#contact_us", as: "contact_us" #
    get "/privacy-policy" => "sections#privacy_policy"
    get "/legal" => "sections#legal"

    post "/contact_us" => "sections#contact_us_ajax"
    post "/search_ajax_for_sale" => "search#search_ajax_for_sale"
    post "/search_ajax_for_rent" => "search#search_ajax_for_rent"
    # post "/ajax_find_by_ref" => "search#ajax_find_by_ref"
    post "/request_property_info" => "props#request_property_info_ajax"


    get "/admin" => "admin_panel#show"
    get "/admin/*path" => "admin_panel#show"

  end

  namespace :api_public do
    namespace :v1 do
      jsonapi_resources :props
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


        get "/agency" => "agency#show"
        put "/agency" => "agency#update"
        put "/website" => "website#update"
        get "/infos" => "agency#infos"

        # put "tenant" => "agency#update_legacy"
        put "/master_address" => "agency#update_master_address"

        post '/cms-pages/photos/:page_id/:block_label' => 'cms_pages#set_photo'
        get "/cms-pages/meta/:page_name" => "cms_pages#meta"
        jsonapi_resources :cms_pages

        # get "/web-contents" => "agency#infos"
        jsonapi_resources :lite_properties
        jsonapi_resources :properties
        # jsonapi_resources :sections
        jsonapi_resources :web_contents

        get "/sections" => "sections#index"
        put "/sections" => "sections#bulk_update"

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
