module Types
  class QueryType < Types::BaseObject
    # Add `node(id: ID!) and `nodes(ids: [ID!]!)`
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # # TODO: remove me
    # field :test_field, String, null: false,
    #                            description: "An example field added by the generator"

    # def test_field
    #   "Hello World!"
    # end

    # field :all_pages, [Types::PageType], null: false, description: "Get all the page items."

    field :page, Types::PageType, null: false do
      description "Get a page item based on id."
      argument :id, ID, required: true
    end

    def page(id:)
      Pwb::Current.website.pages.find(id)
    end

    field :find_page, Types::PageType, null: true do
      description "Get a page based on slug."
      argument :slug, String, required: true
      argument :locale, String, required: true
    end

    def find_page(slug:, locale:)
      I18n.locale = locale
      Pwb::Current.website.pages.find_by_slug(slug)
    end

    field :search_properties, [Types::PropertyType], null: false do
      description "Search for properties"
      argument :sale_or_rental, String, required: false, default_value: "sale"
      argument :currency, String, required: false, default_value: "usd"
      argument :for_sale_price_from, String, required: false, default_value: "none"
      argument :for_sale_price_till, String, required: false, default_value: "none"
      argument :for_rent_price_from, String, required: false, default_value: "none"
      argument :for_rent_price_till, String, required: false, default_value: "none"
      argument :bedrooms_from, String, required: false, default_value: "none"
      argument :bathrooms_from, String, required: false, default_value: "none"
    end

    def search_properties(**args)
      # I18n.locale = "es"
      Pwb::Current.website.props.properties_search(**args)
    end

    field :get_translations, Types::TranslationType, null: true do
      description "Get translations for a locale."
      argument :locale, String, required: true
    end

    def get_translations(locale:)
      return {
               locale: locale,
               result: I18n.t(".", locale: locale),
             }
    end

    field :get_links, [Types::LinkType], null: false do
      description "Return a list of links"
      argument :placement, String
    end

    def get_links(placement:)
      Pwb::Current.website.links.where(placement: placement)
    end

    field :get_top_nav_links, [Types::LinkType], null: false do
      description "Get top nav links for a locale."
      argument :locale, String, required: true
    end

    def get_top_nav_links(locale:)
      I18n.locale = locale
      Pwb::Current.website.links.where(placement: "top_nav").where(visible: true)
    end

    field :get_footer_links, [Types::LinkType], null: false do
      description "Get top nav links for a locale."
      argument :locale, String, required: true
    end

    def get_footer_links(locale:)
      I18n.locale = locale
      Pwb::Current.website.links.where(placement: "footer").where(visible: true)
    end

    field :get_site_details, Types::WebsiteType, null: false do
      description "Get site details."
      argument :locale, String, required: true
    end

    def get_site_details(locale:)
      I18n.locale = locale
      Pwb::Current.website
    end

    field :find_property, Types::PropertyType, null: true do
      description "Get a property based on id."
      argument :id, String, required: true
      argument :locale, String, required: true
    end

    def find_property(id:, locale:)
      I18n.locale = locale
      Pwb::Current.website.props.find(id)
    end
  end
end
