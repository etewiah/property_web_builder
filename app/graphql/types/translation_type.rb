# frozen_string_literal: true

module Types
  class TranslationType < Types::BaseObject
    field :result, GraphQL::Types::JSON, null: true
    field :locale, String
  end
end
