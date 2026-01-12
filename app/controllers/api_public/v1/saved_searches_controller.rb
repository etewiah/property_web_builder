# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API for managing saved searches and alerts
    # Users access this via token-based authentication (no login required)
    class SavedSearchesController < BaseController
      before_action :set_search_by_token, only: %i[show update destroy unsubscribe]
      before_action :set_searches_by_manage_token, only: [:index]

      # GET /api_public/v1/saved_searches?token=XXX
      def index
        render json: {
          email: @searches.first&.email,
          saved_searches: @searches.map { |s| search_json(s) }
        }
      end

      # GET /api_public/v1/saved_searches/:id?token=XXX
      def show
        render json: search_json(@search, include_alerts: true)
      end

      # POST /api_public/v1/saved_searches
      # Body: { saved_search: { email, search_criteria: {}, alert_frequency: "none"|"daily"|"weekly", name? } }
      def create
        search = saved_search_class.new(search_params)
        search.website = Pwb::Current.website

        if search.save
          # Send verification email for searches with alerts enabled
          search.send_verification_email! if (search.frequency_daily? || search.frequency_weekly?) && search.respond_to?(:send_verification_email!)

          render json: {
            success: true,
            saved_search: search_json(search),
            manage_token: search.manage_token,
            manage_url: saved_searches_manage_url(search.manage_token),
            verification_required: !search.email_verified?
          }, status: :created
        else
          render json: { success: false, errors: search.errors.full_messages },
                 status: :unprocessable_content
        end
      end

      # PATCH /api_public/v1/saved_searches/:id?token=XXX
      # Update frequency, name, or enabled status
      def update
        if @search.update(search_update_params)
          render json: { success: true, saved_search: search_json(@search) }
        else
          render json: { success: false, errors: @search.errors.full_messages },
                 status: :unprocessable_content
        end
      end

      # DELETE /api_public/v1/saved_searches/:id?token=XXX
      def destroy
        @search.destroy
        render json: { success: true }
      end

      # POST /api_public/v1/saved_searches/:id/unsubscribe?token=XXX
      # Or accessed via unsubscribe_token
      def unsubscribe
        @search.update!(enabled: false, alert_frequency: :none)
        render json: { success: true, message: "Unsubscribed from alerts" }
      end

      # GET /api_public/v1/saved_searches/verify?token=XXX
      def verify
        search = saved_search_class.find_by(verification_token: params[:token])

        if search
          search.verify_email! if search.respond_to?(:verify_email!)
          render json: { success: true, message: "Email verified", saved_search: search_json(search) }
        else
          render json: { success: false, error: "Invalid verification token" }, status: :not_found
        end
      end

      private

      def set_search_by_token
        @search = saved_search_class.find_by(manage_token: params[:token])
        @search ||= saved_search_class.find_by(id: params[:id], manage_token: params[:token])
        @search ||= saved_search_class.find_by(unsubscribe_token: params[:token])

        return if @search

        render json: { error: "Invalid token" }, status: :unauthorized
      end

      def set_searches_by_manage_token
        sample = saved_search_class.find_by(manage_token: params[:token])

        unless sample
          render json: { error: "Invalid token" }, status: :unauthorized
          return
        end

        @searches = saved_search_class.for_email(sample.email).order(created_at: :desc)
      end

      def search_params
        params.require(:saved_search).permit(:email, :name, :alert_frequency, search_criteria: {})
      end

      def search_update_params
        params.require(:saved_search).permit(:name, :alert_frequency, :enabled)
      end

      def search_json(search, include_alerts: false)
        json = {
          id: search.id,
          email: search.email,
          name: search.name,
          search_criteria: search.search_criteria_hash,
          alert_frequency: search.alert_frequency,
          enabled: search.enabled?,
          email_verified: search.email_verified?,
          last_run_at: search.last_run_at,
          last_result_count: search.last_result_count,
          created_at: search.created_at,
          manage_token: search.manage_token,
          unsubscribe_token: search.unsubscribe_token
        }

        if include_alerts && search.respond_to?(:alerts)
          json[:recent_alerts] = search.alerts.recent.limit(10).map do |alert|
            {
              id: alert.id,
              new_properties_count: alert.new_properties_count,
              sent_at: alert.sent_at,
              created_at: alert.created_at
            }
          end
        end

        json
      end

      def saved_searches_manage_url(token)
        "#{request.protocol}#{request.host_with_port}/my/saved_searches?token=#{token}"
      end

      def saved_search_class
        # Use tenant-specific model if available, otherwise fall back to Pwb
        if defined?(PwbTenant::SavedSearch)
          PwbTenant::SavedSearch
        else
          Pwb::SavedSearch
        end
      end
    end
  end
end
