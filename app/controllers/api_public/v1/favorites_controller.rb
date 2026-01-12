# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API for managing saved/favorited properties
    # Users access this via token-based authentication (no login required)
    class FavoritesController < BaseController
      before_action :set_favorite_by_token, only: %i[show update destroy]
      before_action :set_favorites_by_manage_token, only: [:index]

      # GET /api_public/v1/favorites?token=XXX
      # List all favorites for email associated with token
      def index
        render json: {
          email: @favorites.first&.email,
          favorites: @favorites.map { |f| favorite_json(f) }
        }
      end

      # GET /api_public/v1/favorites/:id?token=XXX
      def show
        render json: favorite_json(@favorite)
      end

      # POST /api_public/v1/favorites
      # Create a new favorite
      # Body: { favorite: { email, provider, external_reference, property_data?, notes? } }
      def create
        favorite = build_favorite

        if favorite.save
          render json: {
            success: true,
            favorite: favorite_json(favorite),
            manage_token: favorite.manage_token,
            manage_url: favorites_manage_url(favorite.manage_token)
          }, status: :created
        else
          render json: { success: false, errors: favorite.errors.full_messages },
                 status: :unprocessable_content
        end
      end

      # PATCH /api_public/v1/favorites/:id?token=XXX
      # Update notes
      def update
        if @favorite.update(favorite_update_params)
          render json: { success: true, favorite: favorite_json(@favorite) }
        else
          render json: { success: false, errors: @favorite.errors.full_messages },
                 status: :unprocessable_content
        end
      end

      # DELETE /api_public/v1/favorites/:id?token=XXX
      def destroy
        @favorite.destroy
        render json: { success: true }
      end

      # POST /api_public/v1/favorites/check
      # Check which references are already saved for an email
      # Body: { email, references: [] }
      def check
        email = params[:email].to_s.downcase.strip
        references = Array(params[:references])

        saved = saved_property_class
                .for_email(email)
                .where(external_reference: references)
                .pluck(:external_reference)

        render json: { saved: saved }
      end

      private

      def set_favorite_by_token
        @favorite = saved_property_class.find_by(manage_token: params[:token])
        @favorite ||= saved_property_class.find_by(id: params[:id], manage_token: params[:token])

        return if @favorite

        render json: { error: "Invalid token" }, status: :unauthorized
      end

      def set_favorites_by_manage_token
        sample = saved_property_class.find_by(manage_token: params[:token])

        unless sample
          render json: { error: "Invalid token" }, status: :unauthorized
          return
        end

        @favorites = saved_property_class.for_email(sample.email).recent
      end

      def build_favorite
        favorite = saved_property_class.new(favorite_params)
        favorite.website = Pwb::Current.website

        # Fetch and cache property data if not provided
        fetch_and_cache_property_data(favorite) if favorite.property_data.blank? && favorite.external_reference.present?

        favorite
      end

      def fetch_and_cache_property_data(favorite)
        # For internal properties, fetch from database
        return unless favorite.provider == "internal"

        property = Pwb::Current.website.listed_properties.find_by(
          id: favorite.external_reference
        ) || Pwb::Current.website.listed_properties.find_by(
          slug: favorite.external_reference
        )

        return unless property

        favorite.property_data = {
          title: property.title,
          price: property.price_hash,
          image_url: property.primary_image_url,
          property_url: "/properties/#{property.slug}",
          bedrooms: property.count_bedrooms,
          bathrooms: property.count_bathrooms,
          area: property.plot_area
        }
        favorite.original_price_cents = property.price_cents
        favorite.current_price_cents = property.price_cents

        # External properties would use the feed API - handled elsewhere
      end

      def favorite_params
        params.require(:favorite).permit(
          :email, :provider, :external_reference, :notes,
          property_data: {}
        )
      end

      def favorite_update_params
        params.require(:favorite).permit(:notes)
      end

      def favorite_json(fav)
        {
          id: fav.id,
          email: fav.email,
          provider: fav.provider,
          external_reference: fav.external_reference,
          notes: fav.notes,
          title: fav.title,
          price: fav.price,
          price_formatted: fav.price_formatted,
          image_url: fav.image_url,
          property_url: fav.property_url,
          original_price_cents: fav.original_price_cents,
          current_price_cents: fav.current_price_cents,
          price_changed: fav.price_changed_at.present?,
          price_changed_at: fav.price_changed_at,
          created_at: fav.created_at,
          manage_token: fav.manage_token
        }
      end

      def favorites_manage_url(token)
        "#{request.protocol}#{request.host_with_port}/my/favorites?token=#{token}"
      end

      def saved_property_class
        # Use tenant-specific model if available, otherwise fall back to Pwb
        if defined?(PwbTenant::SavedProperty)
          PwbTenant::SavedProperty
        else
          Pwb::SavedProperty
        end
      end
    end
  end
end
