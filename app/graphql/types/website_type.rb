# frozen_string_literal: true

module Types
  class WebsiteType < Types::BaseObject
    field :company_display_name, String, null: true
    field :default_currency, String, null: true
    # field :social_media, String, null: true
    # field :phone_number_primary, String, null: true
    # field :phone_number_primary, String, null: true
    # field :phone_number_primary, String, null: true
    field :phone_number_primary, String, null: true
    field :social_media, GraphQL::Types::JSON, null: true

    field :supported_locales, GraphQL::Types::JSON, null: true
    field :supported_locales_with_variants, GraphQL::Types::JSON, null: true
    field :style_variables, GraphQL::Types::JSON, null: true
    field :top_nav_display_links, [Types::LinkType], null: true
    field :footer_display_links, [Types::LinkType], null: true
    field :agency, Types::AgencyType, null: false
  end
end
