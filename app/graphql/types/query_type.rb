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

    field :find_page, Types::PageType, null: true do
      description "Get a page based on slug."
      argument :slug, String, required: true
    end

    def find_page(slug:)
      Pwb::Page.find_by_slug(slug)
    end

    # field :search_for_rentals, [Types::LinkType], null: false do
    #   description "Return a list of links"
    #   argument :placement, String
    # end

    # def search_for_rentals(placement:)
    #   Pwb::Prop.where(placement: placement)
    # end

    field :get_properties,
          [Types::PropertyType],
          null: false,
          description: "Return a list of properties"

    def get_properties
      Pwb::Prop.all
    end

    field :get_links, [Types::LinkType], null: false do
      description "Return a list of links"
      argument :placement, String
    end

    def get_links(placement:)
      Pwb::Link.where(placement: placement)
    end

    field :get_top_nav_links, [Types::LinkType], null: false

    def get_top_nav_links()
      Pwb::Link.where(placement: "top_nav").where(visible: true)
    end

    field :get_footer_links, [Types::LinkType], null: false

    def get_footer_links()
      Pwb::Link.where(placement: "footer").where(visible: true)
    end

    field :find_property, Types::PropertyType, null: true do
      description "Get a property based on id."
      argument :id, String, required: true
    end

    def find_property(id:)
      Pwb::Prop.find(id)
      # Page.find_by_slug("place_of_origin = ?", slug)
    end
  end
end
