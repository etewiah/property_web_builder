# frozen_string_literal: true

module ApiManage
  module V1
    # API endpoint for AI-powered property description generation
    #
    # POST /api_manage/v1/:locale/properties/:property_id/ai_description
    #   Generates a new AI description for the property
    #
    # GET /api_manage/v1/:locale/properties/:property_id/ai_description/history
    #   Returns history of AI generation requests for this property
    #
    # Body params (POST):
    # - locale: Target locale for the description (optional, defaults to URL locale)
    # - tone: Writing tone ('professional', 'casual', 'luxury', 'warm', 'modern')
    #
    class AiDescriptionsController < BaseController
      before_action :set_property

      # POST /api_manage/v1/:locale/properties/:property_id/ai_description
      def create
        generator = ::Ai::ListingDescriptionGenerator.new(
          property: @property,
          locale: params[:locale] || I18n.locale.to_s,
          tone: generation_params[:tone] || 'professional',
          user: current_user
        )

        result = generator.generate

        if result.success?
          render json: {
            success: true,
            title: result.title,
            description: result.description,
            meta_description: result.meta_description,
            compliance: result.compliance,
            request_id: result.request_id
          }
        else
          render json: {
            success: false,
            error: result.error
          }, status: :unprocessable_entity
        end
      rescue ::Ai::ConfigurationError => e
        render json: {
          success: false,
          error: "AI is not configured: #{e.message}",
          provider: e.provider,
          model: e.model
        }.compact, status: :service_unavailable
      rescue ::Ai::RateLimitError => e
        render json: {
          success: false,
          error: "Rate limit exceeded for #{e.provider || 'AI provider'}. Please try again later.",
          retry_after: e.retry_after,
          provider: e.provider,
          model: e.model
        }.compact, status: :too_many_requests
      end

      # GET /api_manage/v1/:locale/properties/:property_id/ai_description/history
      def history
        # Query by property_id stored in input_data since properties can be
        # RealtyAsset, ListedProperty, or Prop models
        requests = Pwb::AiGenerationRequest
                     .where(website_id: current_website&.id)
                     .where(request_type: 'listing_description')
                     .where("input_data->>'property_id' = ?", @property.id.to_s)
                     .order(created_at: :desc)
                     .limit(10)

        render json: {
          requests: requests.map { |r| serialize_request(r) }
        }
      end

      private

      def set_property
        # Use RealtyAsset (same as site_admin) - this is the main property model
        # that stores bedrooms, bathrooms, location, etc.
        @property = Pwb::RealtyAsset.where(website_id: current_website&.id).find(params[:property_id])
      end

      def generation_params
        params.permit(:locale, :tone)
      end

      def current_user
        # TODO: Get current user from authentication
        nil
      end

      def serialize_request(request)
        {
          id: request.id,
          status: request.status,
          locale: request.locale,
          created_at: request.created_at.iso8601,
          title: request.generated_title,
          description: request.generated_description,
          meta_description: request.generated_meta_description,
          compliance: request.compliance_result,
          error: request.error_message,
          tokens: {
            input: request.input_tokens,
            output: request.output_tokens,
            total: request.total_tokens
          }
        }.compact
      end
    end
  end
end
