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
      Page.find(id)
    end

    field :find_page, Types::PageType, null: false do
      description "Get a page based on slug."
      argument :slug, String, required: true
    end

    def find_page(slug:)
      Pwb::Page.find_by_slug(slug)
      # Page.find_by_slug("place_of_origin = ?", slug)
    end

    field :pages,
          [Types::PageType],
          null: false,
          description: "Return a list of pages"

    def pages
      Pwb::Page.all
    end
  end
end
