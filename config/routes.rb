Pwb::Engine.routes.draw do
  root to: 'welcome#index'
  resources :welcome, only: :index

  get "/admin" => "admin_panel#show"
  get "/admin/*path" => "admin_panel#show"


  get "/agency_css" => "css#agency_css", as: "agency_css"

  # TODO - get locales dynamically
  scope "(:locale)", locale: /en|nl|es|fr|de|pt|it|ca|ar/ do
    # resources :welcome, only: :index
    get "/" => "welcome#index", as: "home"

    get "/properties/for-rent/:id/:url_friendly_title" => "props#show_for_rent", as: "prop_show_for_rent"
    get "/properties/for-sale/:id/:url_friendly_title" => "props#show_for_sale", as: "prop_show_for_sale"

    get "/about-us" => "sections#about_us"
    get "/sell" => "sections#sell"
    get "/contact-us" => "sections#contact_us", as: "contact_us" #
    get "/privacy-policy" => "sections#privacy_policy"
    get "/legal" => "sections#legal"


    get "/admin" => "admin_panel#show"
    get "/admin/*path" => "admin_panel#show"

  end

  namespace :api do
    namespace :v1 do
      get "/client_translations/:locale" => "client_translations#index"


      # below gets FieldConfig values for a batch_key such as "person-titles"
      # and returns all the locale translations so an admin
      # can manage them..
      get "/lang/admin_translations/:batch_key" => "client_translations#get_by_batch"
      # post "/lang/admin_translations" => "client_translations#create_translation_value"

      # post "/lang/admin_translations/add_locale_translation" => "client_translations#add_locale_translation"
      # delete "/lang/admin_translations/:id" => "client_translations#delete_translation_values"


      get "/agency" => "agency#show"
      get "/infos" => "agency#infos"

      #TODO - change legacy admin code to put to /agency
      put "tenant" => "agency#update"

      # get "/web-contents" => "agency#infos"
      jsonapi_resources :lite_properties
      jsonapi_resources :properties
      jsonapi_resources :web_contents
      get "/select_values" => "select_values#by_field_names"

      # get "/lite-properties" => "lite_props#index"
    end
  end

end
