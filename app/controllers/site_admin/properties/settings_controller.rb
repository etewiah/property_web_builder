module SiteAdmin
  module Properties
    class SettingsController < ::SiteAdminController
      before_action :set_category, only: [:show, :create, :update, :destroy]
      before_action :set_field_key, only: [:update, :destroy]
      
      VALID_CATEGORIES = {
        'property_types' => 'property-types',
        'features' => 'extras',
        'property_states' => 'property-states',
        'property_labels' => 'property-labels'
      }.freeze
      
      def index
        # Show landing page with all four tabs
        @categories = VALID_CATEGORIES.keys
      end
      
      def show
        # Show specific category with its field keys
        @field_keys = Pwb::FieldKey
          .where(tag: category_tag)
          .for_website(current_website.id)
          .order(:sort_order, :created_at)
      end
      
      def create
        @field_key = Pwb::FieldKey.new
        @field_key.tag = category_tag
        @field_key.pwb_website_id = current_website.id
        @field_key.global_key = generate_global_key
        @field_key.visible = field_key_params[:visible] || true
        @field_key.sort_order = field_key_params[:sort_order] || 0
        
        if @field_key.save
          # Store translations in I18n (simplified approach for now)
          # In production, you might use i18n-active_record gem
          save_translations(@field_key, params[:field_key][:translations])
          
          redirect_to site_admin_properties_settings_category_path(@category),
                      notice: 'Setting created successfully'
        else
          @field_keys = load_field_keys
          flash.now[:alert] = 'Failed to create setting'
          render :show, status: :unprocessable_entity
        end
      end
      
      def update
        @field_key.visible = field_key_params[:visible] if params[:field_key].key?(:visible)
        @field_key.sort_order = field_key_params[:sort_order] if params[:field_key].key?(:sort_order)
        
        if @field_key.save
          save_translations(@field_key, params[:field_key][:translations])
          
          redirect_to site_admin_properties_settings_category_path(@category),
                      notice: 'Setting updated successfully'
        else
          @field_keys = load_field_keys
          flash.now[:alert] = 'Failed to update setting'
          render :show, status: :unprocessable_entity
        end
      end
      
      def destroy
        if @field_key.destroy
          redirect_to site_admin_properties_settings_category_path(@category),
                      notice: 'Setting deleted successfully'
        else
          redirect_to site_admin_properties_settings_category_path(@category),
                      alert: 'Failed to delete setting'
        end
      end
      
      private
      
      def set_category
        @category = params[:category]
        unless VALID_CATEGORIES.key?(@category)
          redirect_to site_admin_root_path, alert: 'Invalid category'
        end
      end
      
      def category_tag
        VALID_CATEGORIES[@category]
      end
      
      def set_field_key
        @field_key = Pwb::FieldKey.find_by!(
          global_key: params[:id],
          pwb_website_id: current_website.id
        )
      rescue ActiveRecord::RecordNotFound
        redirect_to site_admin_properties_settings_category_path(@category),
                    alert: 'Setting not found'
      end
      
      def field_key_params
        params.require(:field_key).permit(:visible, :sort_order) if params[:field_key].present?
      end
      
      def generate_global_key
        # Generate unique global key based on first translation
        first_translation = params[:field_key][:translations]&.values&.first
        base_name = first_translation&.parameterize || 'entry'
        timestamp = Time.current.to_i
        "#{category_tag}.#{base_name}_#{timestamp}"
      end
      
      def save_translations(field_key, translations_hash)
        # Store translations in memory for this request
        # TODO: In production, use i18n-active_record or similar gem for persistence
        return unless translations_hash.present?
        
        translations_hash.each do |locale, text|
          next if text.blank?
          I18n.backend.store_translations(
            locale.to_sym,
            { field_key.global_key => text },
            escape: false
          )
        end
      end
      
      def load_field_keys
        Pwb::FieldKey
          .where(tag: category_tag)
          .for_website(current_website.id)
          .order(:sort_order, :created_at)
      end
    end
  end
end
