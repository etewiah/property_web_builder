# frozen_string_literal: true

module SiteAdmin
  module SearchFilters
    # PropertyTypesController
    # Manages property type options for search filters.
    #
    # Property types appear in search form dropdowns/checkboxes and can be
    # mapped to external feed provider codes for integrated listings.
    #
    class PropertyTypesController < SiteAdminController
      before_action :set_property_type, only: %i[edit update destroy toggle_visibility toggle_search]

      def index
        @property_types = property_types_scope.ordered.with_children

        # Calculate usage stats
        @usage_stats = calculate_usage_stats
      end

      def new
        @property_type = Pwb::SearchFilterOption.new(
          filter_type: Pwb::SearchFilterOption::PROPERTY_TYPE,
          visible: true,
          show_in_search: true
        )
        @parent_options = property_types_scope.roots.ordered
      end

      def edit
        @parent_options = property_types_scope.roots.where.not(id: @property_type.id).ordered
      end

      def create
        @property_type = Pwb::SearchFilterOption.new(property_type_params)
        @property_type.website = current_website
        @property_type.filter_type = Pwb::SearchFilterOption::PROPERTY_TYPE

        if @property_type.save
          redirect_to site_admin_search_filters_property_types_path,
                      notice: "Property type '#{@property_type.display_label}' was created."
        else
          @parent_options = property_types_scope.roots.ordered
          render :new, status: :unprocessable_content
        end
      end

      def update
        if @property_type.update(property_type_params)
          redirect_to site_admin_search_filters_property_types_path,
                      notice: "Property type '#{@property_type.display_label}' was updated."
        else
          @parent_options = property_types_scope.roots.where.not(id: @property_type.id).ordered
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        label = @property_type.display_label

        if @property_type.destroy
          redirect_to site_admin_search_filters_property_types_path,
                      notice: "Property type '#{label}' was deleted."
        else
          redirect_to site_admin_search_filters_property_types_path,
                      alert: "Could not delete property type: #{@property_type.errors.full_messages.join(', ')}"
        end
      end

      # Quick toggle visibility
      def toggle_visibility
        @property_type.update!(visible: !@property_type.visible)

        respond_to do |format|
          format.html { redirect_to site_admin_search_filters_property_types_path }
          format.json { render json: { visible: @property_type.visible } }
        end
      end

      # Quick toggle show_in_search
      def toggle_search
        @property_type.update!(show_in_search: !@property_type.show_in_search)

        respond_to do |format|
          format.html { redirect_to site_admin_search_filters_property_types_path }
          format.json { render json: { show_in_search: @property_type.show_in_search } }
        end
      end

      # Reorder via drag-and-drop (AJAX)
      def reorder
        ids = params[:ids] || []

        ids.each_with_index do |id, index|
          property_types_scope.find_by(id: id)&.update(sort_order: index)
        end

        head :ok
      end

      # Import property types from external provider
      def import_from_provider
        provider_name = params[:provider] || 'resales_online'

        begin
          manager = Pwb::ExternalFeed::Manager.new(current_website)
          provider_types = manager.filter_options[:property_types] || []

          imported = Pwb::SearchFilterOption.import_options(
            website: current_website,
            filter_type: Pwb::SearchFilterOption::PROPERTY_TYPE,
            options: provider_types.map do |pt|
              {
                value: pt[:value].to_s.parameterize,
                label: pt[:label],
                external_code: pt[:value]
              }
            end
          )

          redirect_to site_admin_search_filters_property_types_path,
                      notice: "Imported #{imported.size} property types from #{provider_name}."
        rescue StandardError => e
          redirect_to site_admin_search_filters_property_types_path,
                      alert: "Import failed: #{e.message}"
        end
      end

      private

      def property_types_scope
        Pwb::SearchFilterOption.property_types.where(website: current_website)
      end

      def set_property_type
        @property_type = property_types_scope.find(params[:id])
      end

      def property_type_params
        params.require(:search_filter_option).permit(
          :global_key,
          :external_code,
          :visible,
          :show_in_search,
          :sort_order,
          :parent_id,
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
        end
      end

      def calculate_usage_stats
        # Count how many properties use each type
        # This requires integration with RealtyAsset - placeholder for now
        {}
      end
    end
  end
end
