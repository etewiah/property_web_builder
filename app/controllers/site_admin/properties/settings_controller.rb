module SiteAdmin
  module Properties
    class SettingsController < ::SiteAdminController
      before_action :set_category, only: [:show, :create, :update, :destroy]
      before_action :set_field_key, only: [:update, :destroy]
      
      # Maps URL-friendly category names to database tags
      # Updated to reflect new field key categorization (see docs/09_Field_Keys.md)
      VALID_CATEGORIES = {
        'property_types' => 'property-types',      # What the property IS (apartment, villa, etc.)
        'property_states' => 'property-states',    # Physical condition (new, renovated, etc.)
        'property_features' => 'property-features', # Permanent physical attributes (pool, garden, etc.)
        'property_amenities' => 'property-amenities', # Equipment & services (AC, heating, etc.)
        'property_status' => 'property-status',    # Transaction status (sold, reserved, etc.)
        'property_highlights' => 'property-highlights', # Marketing flags (featured, luxury, etc.)
        'listing_origin' => 'listing-origin'       # Source of listing (direct, MLS, etc.)
      }.freeze

      # Human-readable labels for each category
      CATEGORY_LABELS = {
        'property_types' => 'Property Types',
        'property_states' => 'Property States',
        'property_features' => 'Features',
        'property_amenities' => 'Amenities',
        'property_status' => 'Status Labels',
        'property_highlights' => 'Highlights',
        'listing_origin' => 'Listing Origin'
      }.freeze

      # Brief descriptions for each category
      CATEGORY_DESCRIPTIONS = {
        'property_types' => 'Define what types of properties can be listed (e.g., Apartment, Villa, Office)',
        'property_states' => 'Define physical condition options (e.g., New Build, Needs Renovation)',
        'property_features' => 'Define permanent physical attributes (e.g., Pool, Garden, Terrace)',
        'property_amenities' => 'Define equipment and services (e.g., Air Conditioning, Heating, Elevator)',
        'property_status' => 'Define transaction status labels (e.g., Sold, Reserved, Under Offer)',
        'property_highlights' => 'Define marketing highlight labels (e.g., Featured, Luxury, Price Reduced)',
        'listing_origin' => 'Define listing source options (e.g., Direct Entry, MLS Feed, Partner)'
      }.freeze
      
      def index
        # Show landing page with all category tabs
        @categories = VALID_CATEGORIES.keys
        @category_labels = CATEGORY_LABELS
        @category_descriptions = CATEGORY_DESCRIPTIONS
      end
      
      def show
        # Show specific category with its field keys
        @field_keys = Pwb::FieldKey
          .where(tag: category_tag)
          .for_website(current_website.id)
          .order(:sort_order, :created_at)

        @category_label = CATEGORY_LABELS[@category]
        @category_description = CATEGORY_DESCRIPTIONS[@category]
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
        # Generate global key using new English-based format
        # Format: {prefix}.{snake_case_name}
        # Examples: types.apartment, features.private_pool, amenities.air_conditioning
        first_translation = params[:field_key][:translations]&.values&.first
        base_name = first_translation&.parameterize(separator: '_') || 'entry'

        # Map category tag to key prefix
        prefix = case category_tag
                 when 'property-types' then 'types'
                 when 'property-states' then 'states'
                 when 'property-features' then 'features'
                 when 'property-amenities' then 'amenities'
                 when 'property-status' then 'status'
                 when 'property-highlights' then 'highlights'
                 when 'listing-origin' then 'origin'
                 else category_tag.split('-').last
                 end

        # Ensure uniqueness by checking if key exists
        proposed_key = "#{prefix}.#{base_name}"
        if Pwb::FieldKey.exists?(global_key: proposed_key)
          # Add timestamp suffix if key exists
          proposed_key = "#{prefix}.#{base_name}_#{Time.current.to_i}"
        end

        proposed_key
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
