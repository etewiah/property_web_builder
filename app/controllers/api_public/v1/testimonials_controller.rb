# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API endpoint for testimonials
    # Returns visible testimonials for display on the website
    class TestimonialsController < BaseController

      # GET /api_public/v1/testimonials
      # Returns testimonials for the current website
      #
      # Query Parameters:
      # - locale: optional locale code (e.g., "en", "es")
      # - limit: max number of testimonials to return (default: all)
      # - featured_only: if true, only return featured testimonials
      #
      # Response:
      # {
      #   "testimonials": [
      #     {
      #       "id": 1,
      #       "quote": "Great service!",
      #       "author_name": "John Doe",
      #       "author_role": "Buyer",
      #       "author_photo": "https://...",
      #       "rating": 5,
      #       "position": 1
      #     }
      #   ]
      # }
      def index
        locale = params[:locale]
        I18n.locale = locale if locale.present?

        testimonials = Pwb::Current.website.testimonials.visible.ordered
        testimonials = testimonials.featured if params[:featured_only] == 'true'
        testimonials = testimonials.limit(params[:limit].to_i) if params[:limit].present?

        render json: {
          testimonials: testimonials.map(&:as_api_json)
        }
      end
    end
  end
end
