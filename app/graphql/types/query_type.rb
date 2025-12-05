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
      description "Search for properties with field key filtering"
      argument :sale_or_rental, String, required: false, default_value: "sale"
      argument :currency, String, required: false, default_value: "usd"
      argument :for_sale_price_from, String, required: false, default_value: "none"
      argument :for_sale_price_till, String, required: false, default_value: "none"
      argument :for_rent_price_from, String, required: false, default_value: "none"
      argument :for_rent_price_till, String, required: false, default_value: "none"
      argument :bedrooms_from, String, required: false, default_value: "none"
      argument :bathrooms_from, String, required: false, default_value: "none"
      # New field key filter arguments
      argument :property_type, String, required: false, description: "Property type key (e.g., types.apartment)"
      argument :property_state, String, required: false, description: "Property state key (e.g., states.new_build)"
      argument :features, [String], required: false, description: "List of feature/amenity keys to filter by"
      argument :features_match, String, required: false, default_value: "all", description: "Match 'all' or 'any' features"
    end

    def search_properties(**args)
      # Use ListedProperty (materialized view) for optimized reads
      properties = Pwb::Current.website.listed_properties.visible

      # Apply sale/rental filter
      if args[:sale_or_rental] == "rental"
        properties = properties.for_rent
      else
        properties = properties.for_sale
      end

      # Apply property type filter
      if args[:property_type].present?
        properties = properties.with_property_type(args[:property_type])
      end

      # Apply property state filter
      if args[:property_state].present?
        properties = properties.with_property_state(args[:property_state])
      end

      # Apply feature filters
      if args[:features].present?
        feature_keys = args[:features].reject(&:blank?)
        if feature_keys.any?
          if args[:features_match] == "any"
            properties = properties.with_any_features(feature_keys)
          else
            properties = properties.with_features(feature_keys)
          end
        end
      end

      # Apply price filters
      currency_string = args[:currency] || "usd"
      currency = Money::Currency.find(currency_string)

      [:for_sale_price_from, :for_sale_price_till, :for_rent_price_from, :for_rent_price_till].each do |price_key|
        value = args[price_key]
        next if value.blank? || value == "none"

        cents = value.to_s.gsub(/\D/, "").to_i * currency.subunit_to_unit
        properties = properties.public_send(price_key, cents) if cents > 0
      end

      # Apply room count filters
      if args[:bedrooms_from].present? && args[:bedrooms_from] != "none"
        properties = properties.bedrooms_from(args[:bedrooms_from].to_i)
      end

      if args[:bathrooms_from].present? && args[:bathrooms_from] != "none"
        properties = properties.bathrooms_from(args[:bathrooms_from].to_i)
      end

      properties
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
      description "Get a property based on id or slug."
      argument :id, String, required: true, description: "Property ID or slug"
      argument :locale, String, required: true
    end

    def find_property(id:, locale:)
      I18n.locale = locale
      # Use ListedProperty (materialized view) for optimized reads
      # Support both ID and slug lookup
      scope = Pwb::Current.website.listed_properties
      property = scope.find_by(slug: id)
      property ||= scope.find_by(id: id)
      property
    end
  end
end
