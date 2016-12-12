Pwb::Engine.routes.draw do
  # devise_for :users, class_name: "Pwb::User", module: :devise
  root to: 'welcome#index'
  resources :welcome, only: :index

  authenticate :user do
    get "/admin" => "admin_panel#show"
    get "/admin/*path" => "admin_panel#show"
    scope "(:locale)", locale: /en|nl|es|fr|de|pt|it|ca|ar/ do
      get "/admin" => "admin_panel#show", as: "admin_with_locale"
      get "/admin/*path" => "admin_panel#show"
    end
  end

  get "/agency_css" => "css#agency_css", as: "agency_css"

  # TODO - get locales dynamically
  scope "(:locale)", locale: /en|nl|es|fr|de|pt|it|ca|ar/ do
    # https://github.com/plataformatec/devise/wiki/How-To:-Use-devise-inside-a-mountable-engine
    devise_for :users, class_name: "Pwb::User", module: :devise

    get "/" => "welcome#index", as: "home"

    get "/properties/for-rent/:id/:url_friendly_title" => "props#show_for_rent", as: "prop_show_for_rent"
    get "/properties/for-sale/:id/:url_friendly_title" => "props#show_for_sale", as: "prop_show_for_sale"

    get "/about-us" => "sections#about_us"
    get "/sell" => "sections#sell"
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

  authenticate :user do

  namespace :api do
    namespace :v1 do
      get "/client_translations/:locale" => "client_translations#index"


      # below gets FieldConfig values for a batch_key such as "person-titles"
      # and returns all the locale translations so an admin
      # can manage them..
      get "/lang/admin_translations/:batch_key" => "client_translations#get_by_batch"
      post "/lang/admin_translations" => "client_translations#create_translation_value"

      # post "/lang/admin_translations/add_locale_translation" => "client_translations#add_locale_translation"
      delete "/lang/admin_translations/:id" => "client_translations#delete_translation_values"


      get "/agency" => "agency#show"
      get "/infos" => "agency#infos"

      #TODO - change legacy admin code to put to /agency
      put "tenant" => "agency#update"
      put "/master_address" => "agency#update_master_address"

      # get "/web-contents" => "agency#infos"
      jsonapi_resources :lite_properties
      jsonapi_resources :properties
      jsonapi_resources :web_contents
      get "/select_values" => "select_values#by_field_names"


      # TODO - rename properties below to prop
      post "properties/update_extras" => "properties#update_extras"

      delete "properties/photos/:id" => "properties#remove_photo"
      post '/properties/:id/photo' => 'properties#add_photo'
      post '/properties/:id/photo_from_url' => 'properties#add_photo_from_url'
      put "properties/:id/order_photos" => "properties#order_photos"

      post "properties/set_owner" => "properties#set_owner"
      post "properties/unset_owner" => "properties#unset_owner"


      put '/web_contents/photos/:id/:content_tag' => 'web_contents#update_photo'
      # above is used by logo and about_me photos
      # where only one photo is allowed

    end
  end
end
end
