# frozen_string_literal: true

module SiteAdmin
  module SearchFilters
    # FeaturesController
    # Manages property feature options for search filters.
    #
    # Features are amenities/attributes like pool, garage, garden, etc.
    # that can be used to filter properties in search forms.
    #
    class FeaturesController < SiteAdminController
      before_action :set_feature, only: %i[edit update destroy toggle_visibility toggle_search]

      def index
        @features = features_scope.ordered

        # Group features by category if categories exist
        @features_by_category = @features.group_by(&:category)
      end

      def new
        @feature = Pwb::SearchFilterOption.new(
          filter_type: Pwb::SearchFilterOption::FEATURE,
          visible: true,
          show_in_search: true
        )
      end

      def edit; end

      def create
        @feature = Pwb::SearchFilterOption.new(feature_params)
        @feature.website = current_website
        @feature.filter_type = Pwb::SearchFilterOption::FEATURE

        if @feature.save
          redirect_to site_admin_search_filters_features_path,
                      notice: "Feature '#{@feature.display_label}' was created."
        else
          render :new, status: :unprocessable_content
        end
      end

      def update
        if @feature.update(feature_params)
          redirect_to site_admin_search_filters_features_path,
                      notice: "Feature '#{@feature.display_label}' was updated."
        else
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        label = @feature.display_label

        if @feature.destroy
          redirect_to site_admin_search_filters_features_path,
                      notice: "Feature '#{label}' was deleted."
        else
          redirect_to site_admin_search_filters_features_path,
                      alert: "Could not delete feature: #{@feature.errors.full_messages.join(', ')}"
        end
      end

      # Quick toggle visibility
      def toggle_visibility
        @feature.update!(visible: !@feature.visible)

        respond_to do |format|
          format.html { redirect_to site_admin_search_filters_features_path }
          format.json { render json: { visible: @feature.visible } }
        end
      end

      # Quick toggle show_in_search
      def toggle_search
        @feature.update!(show_in_search: !@feature.show_in_search)

        respond_to do |format|
          format.html { redirect_to site_admin_search_filters_features_path }
          format.json { render json: { show_in_search: @feature.show_in_search } }
        end
      end

      # Reorder via drag-and-drop (AJAX)
      def reorder
        ids = params[:ids] || []

        ids.each_with_index do |id, index|
          features_scope.find_by(id: id)&.update(sort_order: index)
        end

        head :ok
      end

      # Import features from external provider
      def import_from_provider
        provider_name = params[:provider] || 'resales_online'

        begin
          manager = Pwb::ExternalFeed::Manager.new(current_website)
          provider_features = manager.filter_options[:features] || []

          imported = Pwb::SearchFilterOption.import_options(
            website: current_website,
            filter_type: Pwb::SearchFilterOption::FEATURE,
            options: provider_features.map do |feat|
              {
                value: feat[:value].to_s.parameterize,
                label: feat[:label],
                external_code: feat[:value]
              }
            end
          )

          redirect_to site_admin_search_filters_features_path,
                      notice: "Imported #{imported.size} features from #{provider_name}."
        rescue StandardError => e
          redirect_to site_admin_search_filters_features_path,
                      alert: "Import failed: #{e.message}"
        end
      end

      private

      def features_scope
        Pwb::SearchFilterOption.features.where(website: current_website)
      end

      def set_feature
        @feature = features_scope.find(params[:id])
      end

      def feature_params
        params.require(:search_filter_option).permit(
          :global_key,
          :external_code,
          :visible,
          :show_in_search,
          :sort_order,
          :icon,
          translations: {}
        ).tap do |whitelisted|
          # Handle dynamic locale fields (label_en, label_es, etc.)
          I18n.available_locales.each do |locale|
            key = "label_#{locale}"
            if params[:search_filter_option][key].present?
              whitelisted[:translations] ||= {}
              whitelisted[:translations][locale.to_s] = params[:search_filter_option][key]
            end
          end

          # Handle category metadata
          if params[:search_filter_option][:category].present?
            whitelisted[:metadata] ||= {}
            whitelisted[:metadata][:category] = params[:search_filter_option][:category]
          end

          # Handle param_name for external API
          if params[:search_filter_option][:param_name].present?
            whitelisted[:metadata] ||= {}
            whitelisted[:metadata][:param_name] = params[:search_filter_option][:param_name]
          end
        end
      end
    end
  end
end
