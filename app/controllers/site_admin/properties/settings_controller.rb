# frozen_string_literal: true

module SiteAdmin
  module Properties
    class SettingsController < ::SiteAdminController
      before_action :set_category, only: [:show, :create, :update, :destroy]
      before_action :set_field_key, only: [:update, :destroy]

      # Uses Pwb::Config::FIELD_KEY_CATEGORIES for centralized configuration
      # Maps URL-friendly category names to database tags
      def self.valid_categories
        Pwb::Config.field_key_url_to_tag_mapping
      end

      # Human-readable labels for each category
      def self.category_labels
        Pwb::Config::FIELD_KEY_CATEGORIES.transform_values { |info| info[:title] }
                                         .transform_keys { |tag| Pwb::Config::FIELD_KEY_CATEGORIES[tag][:url_key] }
      end

      # Brief descriptions for each category
      def self.category_descriptions
        Pwb::Config::FIELD_KEY_CATEGORIES.transform_values { |info| info[:description] }
                                         .transform_keys { |tag| Pwb::Config::FIELD_KEY_CATEGORIES[tag][:url_key] }
      end

      def index
        # Show landing page with all category tabs
        @categories = self.class.valid_categories.keys
        @category_labels = self.class.category_labels
        @category_descriptions = self.class.category_descriptions
      end

      def show
        # Show specific category with its field keys
        # PwbTenant::FieldKey automatically scopes to current_website via acts_as_tenant
        @field_keys = PwbTenant::FieldKey
          .where(tag: category_tag)
          .ordered

        @category_label = self.class.category_labels[@category]
        @category_description = self.class.category_descriptions[@category]

        # Get website's supported locales for the editing UI
        # Format: [{locale: 'en', variant: 'uk', full: 'en-UK', label: 'English'}]
        @website_locales = build_website_locales
      end

      def create
        # PwbTenant::FieldKey automatically assigns website via acts_as_tenant
        @field_key = PwbTenant::FieldKey.new(
          tag: category_tag,
          global_key: generate_global_key,
          visible: field_key_params&.fetch(:visible, true) || true,
          sort_order: field_key_params&.fetch(:sort_order, 0) || 0
        )

        if @field_key.save
          save_translations(@field_key, params.dig(:field_key, :translations))

          redirect_to site_admin_properties_settings_category_path(@category),
                      notice: 'Setting created successfully'
        else
          @field_keys = load_field_keys
          flash.now[:alert] = "Failed to create setting: #{@field_key.errors.full_messages.join(', ')}"
          render :show, status: :unprocessable_entity
        end
      end

      def update
        @field_key.visible = field_key_params[:visible] if params[:field_key].key?(:visible)
        @field_key.sort_order = field_key_params[:sort_order] if params[:field_key].key?(:sort_order)

        if @field_key.save
          save_translations(@field_key, params.dig(:field_key, :translations))

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
        unless self.class.valid_categories.key?(@category)
          redirect_to site_admin_root_path, alert: 'Invalid category'
        end
      end

      def category_tag
        self.class.valid_categories[@category]
      end

      def set_field_key
        # PwbTenant::FieldKey automatically scopes to current website
        @field_key = PwbTenant::FieldKey.find_by!(global_key: params[:id])
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
        first_translation = params.dig(:field_key, :translations)&.values&.first
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

        # Ensure uniqueness within current website by checking if key exists
        proposed_key = "#{prefix}.#{base_name}"
        if PwbTenant::FieldKey.exists?(global_key: proposed_key)
          # Add timestamp suffix if key exists
          proposed_key = "#{prefix}.#{base_name}_#{Time.current.to_i}"
        end

        proposed_key
      end

      def save_translations(field_key, translations_hash)
        Rails.logger.info "[FieldKey Update] save_translations called"
        Rails.logger.info "[FieldKey Update] translations_hash: #{translations_hash.inspect}"

        return unless translations_hash.present?

        # Use Mobility to save translations directly to the model's JSONB column
        translations_hash.each do |locale, text|
          Rails.logger.info "[FieldKey Update] Processing locale=#{locale}, text=#{text.inspect}"
          next if text.blank?

          # Mobility provides locale-specific setters: label_en=, label_es=, etc.
          Mobility.with_locale(locale.to_sym) do
            field_key.label = text
          end
          Rails.logger.info "[FieldKey Update] Set label for locale #{locale}: #{text}"
        end

        field_key.save!
        Rails.logger.info "[FieldKey Update] Field key saved with translations: #{field_key.translations.inspect}"
      end

      def load_field_keys
        PwbTenant::FieldKey
          .where(tag: category_tag)
          .ordered
      end

      # Build locale details for the website's supported locales
      # Uses Pwb::Config for centralized locale configuration
      def build_website_locales
        supported = current_website.supported_locales || ['en']
        Pwb::Config.build_locale_details(supported)
      end
    end
  end
end
