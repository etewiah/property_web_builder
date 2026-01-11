module ApiPublic
  module V1
    class LinksController < BaseController

      def index
        # Accept both 'placement' and 'position' for API compatibility
        placement = params[:placement] || params[:position]
        locale = params[:locale]

        if locale
          I18n.locale = locale
        end

        links = if placement
                  Pwb::Current.website.links.where(placement: placement)
                else
                  Pwb::Current.website.links
                end

        # Filter by visibility if needed, similar to GraphQL implementation
        if params[:visible_only] == 'true' || placement == 'top_nav' || placement == 'footer'
           links = links.where(visible: true).order('sort_order asc')
        end

        render json: { data: links.map(&:as_api_json) }
      end
    end
  end
end

