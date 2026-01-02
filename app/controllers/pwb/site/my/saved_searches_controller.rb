# frozen_string_literal: true

module Pwb
  module Site
    module My
      # Controller for managing saved searches and email alerts.
      # Users access this via token-based authentication (no login required).
      class SavedSearchesController < Pwb::ApplicationController
        before_action :ensure_feed_enabled, only: [:create]
        before_action :set_saved_search_by_token, only: [:show, :update, :destroy]
        before_action :set_searches_by_manage_token, only: [:index]

        # POST /my/saved_searches
        # Create a new saved search from search criteria
        def create
          @saved_search = PwbTenant::SavedSearch.new(saved_search_params)
          @saved_search.website = current_website

          if @saved_search.save
            # Send verification email if required (optional feature)
            # For now, mark as verified immediately for simplicity
            @saved_search.verify_email!

            respond_to do |format|
              format.html do
                redirect_to my_saved_search_path(@saved_search.manage_token),
                            notice: "Search saved! You'll receive alerts for new properties."
              end
              format.json do
                render json: {
                  success: true,
                  message: "Search saved successfully",
                  manage_url: my_saved_search_url(@saved_search.manage_token)
                }, status: :created
              end
            end
          else
            respond_to do |format|
              format.html do
                flash.now[:alert] = @saved_search.errors.full_messages.join(", ")
                render "pwb/site/external_listings/index", status: :unprocessable_content
              end
              format.json do
                render json: { success: false, errors: @saved_search.errors.full_messages },
                       status: :unprocessable_content
              end
            end
          end
        end

        # GET /my/saved_searches?token=XXX
        # List all saved searches for this email (via manage token)
        def index
          if @saved_searches.empty?
            render :no_searches
            return
          end

          @email = @saved_searches.first.email
        end

        # GET /my/saved_searches/:id?token=XXX
        # Show a single saved search
        def show
          @alerts = @saved_search.alerts.recent.limit(10)
        end

        # PATCH /my/saved_searches/:id?token=XXX
        # Update alert settings
        def update
          if @saved_search.update(saved_search_update_params)
            respond_to do |format|
              format.html do
                redirect_to my_saved_search_path(id: @saved_search.id, token: params[:token]),
                            notice: "Settings updated successfully"
              end
              format.json { render json: { success: true } }
            end
          else
            respond_to do |format|
              format.html do
                flash.now[:alert] = @saved_search.errors.full_messages.join(", ")
                render :show, status: :unprocessable_content
              end
              format.json do
                render json: { success: false, errors: @saved_search.errors.full_messages },
                       status: :unprocessable_content
              end
            end
          end
        end

        # DELETE /my/saved_searches/:id?token=XXX
        def destroy
          email = @saved_search.email
          @saved_search.destroy

          respond_to do |format|
            format.html do
              # Find another search to redirect to, or show empty page
              other_search = PwbTenant::SavedSearch.for_email(email).first
              if other_search
                redirect_to my_saved_searches_path(token: other_search.manage_token),
                            notice: "Search deleted"
              else
                redirect_to root_path, notice: "Search deleted. You have no more saved searches."
              end
            end
            format.json { render json: { success: true } }
          end
        end

        # GET /my/saved_searches/unsubscribe?token=XXX
        # Unsubscribe from alerts (via unsubscribe token)
        def unsubscribe
          @saved_search = PwbTenant::SavedSearch.find_by(unsubscribe_token: params[:token])

          if @saved_search
            @saved_search.unsubscribe!
            @email = @saved_search.email
          else
            flash[:alert] = "Invalid or expired unsubscribe link"
            redirect_to root_path
          end
        end

        # GET /my/saved_searches/verify?token=XXX
        # Verify email address
        def verify
          @saved_search = PwbTenant::SavedSearch.find_by(verification_token: params[:token])

          if @saved_search
            @saved_search.verify_email!
            redirect_to my_saved_searches_path(token: @saved_search.manage_token),
                        notice: "Email verified! You'll now receive property alerts."
          else
            flash[:alert] = "Invalid or expired verification link"
            redirect_to root_path
          end
        end

        private

        def ensure_feed_enabled
          feed = current_website.external_feed
          unless feed.configured?
            redirect_to root_path, alert: "Property alerts are not available"
          end
        end

        def set_saved_search_by_token
          # Find by manage token or unsubscribe token
          @saved_search = PwbTenant::SavedSearch.find_by(manage_token: params[:token])
          @saved_search ||= PwbTenant::SavedSearch.find_by(id: params[:id], manage_token: params[:token])

          unless @saved_search
            flash[:alert] = "Invalid or expired link"
            redirect_to root_path
          end
        end

        def set_searches_by_manage_token
          # Find the search by token, then get all searches for that email
          search = PwbTenant::SavedSearch.find_by(manage_token: params[:token])

          if search
            @saved_searches = PwbTenant::SavedSearch.for_email(search.email).recent
          else
            @saved_searches = []
          end
        end

        def saved_search_params
          params.require(:saved_search).permit(
            :email,
            :name,
            :alert_frequency,
            search_criteria: {}
          ).tap do |p|
            # Handle search criteria from form
            if params[:search_criteria].present?
              p[:search_criteria] = params[:search_criteria].to_unsafe_h
            elsif params[:saved_search][:search_criteria].is_a?(String)
              p[:search_criteria] = JSON.parse(params[:saved_search][:search_criteria])
            end
          end
        end

        def saved_search_update_params
          params.require(:saved_search).permit(:name, :alert_frequency, :enabled)
        end
      end
    end
  end
end
