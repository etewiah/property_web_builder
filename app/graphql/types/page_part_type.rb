# frozen_string_literal: true

module Types
  class PagePartType < Types::BaseObject
    field :page_slug, String
    field :created_at, GraphQL::Types::ISO8601DateTime
    field :block_contents, GraphQL::Types::JSON

    # field :page_parts, [Types::PagePartType], null: false

    # field :price_cents, Integer, null: false

    # def price_cents
    #   (100 * object.price).to_i
    # end
  end
end
