# frozen_string_literal: true

module SiteAdmin
  # WidgetsController manages embeddable property widgets
  # Allows users to create, customize, and get embed codes for property widgets
  class WidgetsController < SiteAdminController
    before_action :set_widget, only: [:show, :edit, :update, :destroy, :preview]

    def index
      @widgets = current_website.widget_configs.order(created_at: :desc)
    end

    def show
      # Show embed codes and stats
    end

    def new
      @widget = current_website.widget_configs.build(
        name: "Widget #{current_website.widget_configs.count + 1}",
        layout: 'grid',
        columns: 3,
        max_properties: 12
      )
    end

    def create
      @widget = current_website.widget_configs.build(widget_params)

      if @widget.save
        redirect_to site_admin_widget_path(@widget), notice: 'Widget created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @widget.update(widget_params)
        redirect_to site_admin_widget_path(@widget), notice: 'Widget updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @widget.destroy
      redirect_to site_admin_widgets_path, notice: 'Widget deleted successfully.'
    end

    # GET /site_admin/widgets/:id/preview
    # Renders a preview of the widget
    def preview
      @properties = @widget.properties_query.with_eager_loading.limit(6)
      render layout: false
    end

    private

    def set_widget
      @widget = current_website.widget_configs.find(params[:id])
    end

    def widget_params
      params.require(:pwb_widget_config).permit(
        :name, :active, :layout, :columns, :max_properties,
        :show_search, :show_filters, :show_pagination,
        :listing_type, :min_price_cents, :max_price_cents,
        :min_bedrooms, :max_bedrooms, :highlighted_only,
        property_types: [], allowed_domains: [],
        theme: [:primary_color, :secondary_color, :text_color,
                :background_color, :card_background, :border_color,
                :border_radius, :font_family],
        visible_fields: [:price, :bedrooms, :bathrooms, :area,
                         :location, :reference, :property_type]
      )
    end
  end
end
