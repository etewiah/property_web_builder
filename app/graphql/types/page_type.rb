# frozen_string_literal: true

module Types
  class PageType < Types::BaseObject
    # field :page_parts, Types::ReferencesType
    field :created_at, GraphQL::Types::ISO8601DateTime
    field :raw_html, String

    field :page_parts, [Types::PagePartType], null: false
    field :page_contents, [Types::PageContentType], null: true

    # field :price_cents, Integer, null: false

    # def price_cents
    #   (100 * object.price).to_i
    # end
  end
end
