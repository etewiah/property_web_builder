# frozen_string_literal: true

module Types
  class PageContentType < Types::BaseObject
    field :created_at, GraphQL::Types::ISO8601DateTime
    field :content, GraphQL::Types::JSON, null: true

    # field :page_parts, [Types::PageContentType], null: false

    # field :price_cents, Integer, null: false

    # def price_cents
    #   (100 * object.price).to_i
    # end
  end
end
