# frozen_string_literal: true

module Pwb
  module Site
    module My
      # Controller for managing saved/favorited properties.
      # Users access this via token-based authentication (no login required).
      class SavedPropertiesController < Pwb::ApplicationController
        before_action :ensure_favorites_available, only: [:create]
        before_action :set_saved_property_by_token, only: [:show, :update, :destroy]
        before_action :set_properties_by_manage_token, only: [:index]

        # POST /my/favorites
        # Save a property to favorites
        def create
          @saved_property = PwbTenant::SavedProperty.new(saved_property_params)
          @saved_property.website = current_website

          # Fetch and cache property data if not provided
          if @saved_property.property_data.blank?
            fetch_and_cache_property_data
          end

          if @saved_property.save
            respond_to do |format|
              format.html do
                redirect_to my_favorites_path(token: @saved_property.manage_token),
                            notice: "Property saved to favorites!"
              end
              format.json do
                render json: {
                  success: true,
                  message: "Property saved to favorites",
                  manage_url: my_favorites_url(token: @saved_property.manage_token),
                  saved_property_id: @saved_property.id
                }, status: :created
              end
            end
          else
            respond_to do |format|
              format.html do
                flash[:alert] = @saved_property.errors.full_messages.join(", ")
                redirect_back fallback_location: external_listings_path
              end
              format.json do
                render json: { success: false, errors: @saved_property.errors.full_messages },
                       status: :unprocessable_content
              end
            end
          end
        end

        # GET /my/favorites?token=XXX
        # List all favorited properties for this email
        def index
          if @saved_properties.empty?
            render :no_favorites
            return
          end

          @email = @saved_properties.first.email
        end

        # GET /my/favorites/:id?token=XXX
        # Show a single saved property
        def show
          # Optionally refresh the property data
          refresh_property_data if params[:refresh]
        end

        # PATCH /my/favorites/:id?token=XXX
        # Update notes
        def update
          if @saved_property.update(saved_property_update_params)
            respond_to do |format|
              format.html do
                redirect_to my_favorite_path(id: @saved_property.id, token: params[:token]),
                            notice: "Property updated"
              end
              format.json { render json: { success: true } }
            end
          else
            respond_to do |format|
              format.html do
                flash.now[:alert] = @saved_property.errors.full_messages.join(", ")
                render :show, status: :unprocessable_content
              end
              format.json do
                render json: { success: false, errors: @saved_property.errors.full_messages },
                       status: :unprocessable_content
              end
            end
          end
        end

        # DELETE /my/favorites/:id?token=XXX
        def destroy
          email = @saved_property.email
          @saved_property.destroy

          respond_to do |format|
            format.html do
              other_property = PwbTenant::SavedProperty.for_email(email).first
              if other_property
                redirect_to my_favorites_path(token: other_property.manage_token),
                            notice: "Property removed from favorites"
              else
                redirect_to root_path, notice: "Property removed. You have no more saved properties."
              end
            end
            format.json { render json: { success: true } }
          end
        end

        # POST /my/favorites/check
        # Check if properties are saved (for UI buttons)
        def check
          email = params[:email].to_s.downcase.strip
          references = Array(params[:references])

          saved = PwbTenant::SavedProperty
                  .for_email(email)
                  .where(external_reference: references)
                  .pluck(:external_reference)

          render json: { saved: saved }
        end

        private

        def ensure_favorites_available
          # Internal properties (provider: "internal") don't require external feed
          return if params.dig(:saved_property, :provider) == "internal"

          # External properties require configured feed
          feed = current_website.external_feed
          unless feed.configured?
            redirect_to root_path, alert: "Favorites are not available"
          end
        end

        def set_saved_property_by_token
          @saved_property = PwbTenant::SavedProperty.find_by(manage_token: params[:token])
          @saved_property ||= PwbTenant::SavedProperty.find_by(id: params[:id], manage_token: params[:token])

          unless @saved_property
            flash[:alert] = "Invalid or expired link"
            redirect_to root_path
          end
        end

        def set_properties_by_manage_token
          property = PwbTenant::SavedProperty.find_by(manage_token: params[:token])

          if property
            @saved_properties = PwbTenant::SavedProperty.for_email(property.email).recent
          else
            @saved_properties = []
          end
        end

        def saved_property_params
          params.require(:saved_property).permit(
            :email,
            :provider,
            :external_reference,
            :notes,
            property_data: {}
          ).tap do |p|
            # Handle property data from form
            if params[:property_data].present?
              p[:property_data] = params[:property_data].to_unsafe_h
            elsif params[:saved_property][:property_data].is_a?(String)
              p[:property_data] = JSON.parse(params[:saved_property][:property_data])
            end
          end
        end

        def saved_property_update_params
          params.require(:saved_property).permit(:notes)
        end

        def fetch_and_cache_property_data
          return unless @saved_property.provider.present? && @saved_property.external_reference.present?

          feed = current_website.external_feed
          property = feed.find(@saved_property.external_reference)

          if property
            @saved_property.property_data = property.to_h
            @saved_property.original_price_cents = property.price
            @saved_property.current_price_cents = property.price
          end
        end

        def refresh_property_data
          feed = current_website.external_feed
          property = feed.find(@saved_property.external_reference)

          if property
            @saved_property.update_property_data!(property.to_h)
          end
        end
      end
    end
  end
end
