# TODO: remove - no longer in use - jan 2018
module Pwb
  class Api::V1::ClientsController < JSONAPI::ResourceController
    # # Skipping action below allows me to browse to endpoint
    # # without having set mime type
    # skip_before_action :ensure_valid_accept_media_type
    # # later version changes above method name
    # # https://github.com/cerebris/jsonapi-resources/pull/806/files
    # # https://github.com/cerebris/jsonapi-resources/pull/801

    # # def index
    # #   # can't figure out why default jsonapi index action returns nothing..
    # #   sections = Section.all
    # #   # JSONAPI::ResourceSerializer.new(Api::V1::SectionResource).serialize_to_hash(Api::V1::SectionResource.new(sections, nil))
    # #   render json: sections
    # # end

    # def bulk_update
    #   sectionsJSON = JSON.parse params[:items]
    #   sections = []
    #   sectionsJSON.each do |sectionJSON|
    #     section = Section.find sectionJSON["id"]
    #     section.update(sectionJSON.slice("show_in_top_nav", "show_in_footer", "sort_order"))
    #     sections.push section
    #   end

    #   render json: sections.as_json
    # end

    # private

    # def sections_params
    #   params.permit(:items, items: [])
    # end
  end
end
