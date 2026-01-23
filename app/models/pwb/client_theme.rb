# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_client_themes
# Database name: primary
#
#  id                :bigint           not null, primary key
#  color_schema      :jsonb
#  default_config    :jsonb
#  description       :text
#  enabled           :boolean          default(TRUE), not null
#  font_schema       :jsonb
#  friendly_name     :string           not null
#  layout_options    :jsonb
#  name              :string           not null
#  preview_image_url :string
#  version           :string           default("1.0.0")
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_pwb_client_themes_on_enabled  (enabled)
#  index_pwb_client_themes_on_name     (name) UNIQUE
#
module Pwb
  class ClientTheme < ApplicationRecord
    self.table_name = 'pwb_client_themes'

    # ===================
    # Validations
    # ===================
    validates :name, presence: true, uniqueness: true,
                     format: { with: /\A[a-z][a-z0-9_]*\z/, message: 'must be lowercase letters, numbers, and underscores' }
    validates :friendly_name, presence: true

    # ===================
    # Scopes
    # ===================
    scope :enabled, -> { where(enabled: true) }
    scope :by_name, ->(name) { where(name: name) }

    # Find a single theme by name
    def self.by_name(name)
      find_by(name: name)
    end

    # ===================
    # Instance Methods
    # ===================

    # Get the merged config for a website (defaults + website overrides)
    #
    # @param website [Pwb::Website] The website to get config for
    # @return [Hash] Merged configuration
    def config_for_website(website)
      default_config.merge(website.client_theme_config || {})
    end

    # Generate CSS variables from a configuration
    #
    # @param config [Hash] Configuration to convert (defaults to default_config)
    # @return [String] CSS :root block with variables
    def generate_css_variables(config = default_config)
      return '' if config.blank?

      css_vars = config.map do |key, value|
        css_var_name = key.to_s.tr('_', '-')
        "--#{css_var_name}: #{value}"
      end

      ":root { #{css_vars.join('; ')}; }"
    end

    # API serialization
    #
    # @return [Hash] Theme data for API responses
    def as_api_json
      {
        name: name,
        friendly_name: friendly_name,
        version: version,
        description: description,
        preview_image_url: preview_image_url,
        default_config: default_config,
        color_schema: color_schema,
        font_schema: font_schema,
        layout_options: layout_options
      }
    end

    # For select options in forms
    #
    # @return [Array<Array>] Array of [friendly_name, name] pairs
    def self.options_for_select
      enabled.order(:friendly_name).pluck(:friendly_name, :name)
    end
  end
end
