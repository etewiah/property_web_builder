# frozen_string_literal: true

module Types
  class LinkType < Types::BaseObject
    field :id, Integer
    # field :placement, String
    field :link_path_params, String, null: true
    field :link_path, String, null: true
    field :link_url, String, null: true
    field :link_title, String, null: true
    field :placement, String, null: true
    field :slug, String, null: true
    field :sort_order, Integer, null: true
  end
end
