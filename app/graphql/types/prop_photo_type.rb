# frozen_string_literal: true

module Types
  class PropPhotoType < Types::BaseObject
    field :created_at, GraphQL::Types::ISO8601DateTime
    field :image, String
  end
end
