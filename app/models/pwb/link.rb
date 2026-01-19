# frozen_string_literal: true

module Pwb
  # Link represents navigation links for a website.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Link for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
# == Schema Information
#
# Table name: pwb_links
# Database name: primary
#
#  id               :integer          not null, primary key
#  flags            :integer          default(0), not null
#  href_class       :string
#  href_target      :string
#  icon_class       :string
#  is_deletable     :boolean          default(FALSE)
#  is_external      :boolean          default(FALSE)
#  link_path        :string
#  link_path_params :string
#  link_url         :string
#  page_slug        :string
#  parent_slug      :string
#  placement        :integer          default("top_nav")
#  slug             :string
#  sort_order       :integer          default(0)
#  translations     :jsonb            not null
#  visible          :boolean          default(TRUE)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  website_id       :integer
#
# Indexes
#
#  index_pwb_links_on_flags                (flags)
#  index_pwb_links_on_page_slug            (page_slug)
#  index_pwb_links_on_placement            (placement)
#  index_pwb_links_on_translations         (translations) USING gin
#  index_pwb_links_on_website_id           (website_id)
#  index_pwb_links_on_website_id_and_slug  (website_id,slug) UNIQUE
#
  class Link < ApplicationRecord
    extend Mobility

    self.table_name = 'pwb_links'

    belongs_to :website, class_name: 'Pwb::Website', optional: true, touch: true

    # Mobility translations with container backend (single JSONB column)
    translates :link_title

    belongs_to :page, optional: true, class_name: 'Pwb::Page', foreign_key: 'page_slug', primary_key: 'slug'

    enum :placement, { top_nav: 0, footer: 1, social_media: 2, admin: 3 }

    # Scopes
    scope :ordered_visible_admin, -> { where(visible: true, placement: :admin).order('sort_order asc') }
    scope :ordered_visible_top_nav, -> { where(visible: true, placement: :top_nav).order('sort_order asc') }
    scope :ordered_visible_footer, -> { where(visible: true, placement: :footer).order('sort_order asc') }
    scope :ordered_top_nav, -> { where(placement: :top_nav).order('sort_order asc') }
    scope :ordered_footer, -> { where(placement: :footer).order('sort_order asc') }

    def as_json(options = nil)
      super({
        only: %w[sort_order placement href_class is_deletable slug link_path visible link_title page_slug],
        methods: admin_attribute_names
      }.merge(options || {}))
    end

    # API-formatted JSON for frontend consumption
    # Uses consistent field names matching the frontend contract
    def as_api_json
      {
        "id" => id,
        "slug" => slug,
        "title" => link_title,
        "url" => resolved_url,
        "position" => placement,
        "order" => sort_order,
        "visible" => visible,
        "external" => is_external || false
      }
    end

    # Resolves the URL for this link
    # Prefers link_url (absolute), falls back to generating from link_path
    def resolved_url
      if link_url.present?
        link_url
      elsif link_path.present?
        helper = Rails.application.routes.url_helpers
        path_params = parsed_link_path_params
        begin
          if path_params.is_a?(Hash)
            helper.public_send(link_path, **path_params.symbolize_keys, locale: I18n.locale)
          elsif path_params.present?
            helper.public_send(link_path, path_params, locale: I18n.locale)
          else
            helper.public_send(link_path, locale: I18n.locale)
          end
        rescue NoMethodError, ArgumentError
          # Fall back to a best-effort path if the helper isn't available.
          path_name = link_path.gsub('_path', '')
          "/#{I18n.locale}/#{path_params.presence || path_name}"
        end
      elsif page_slug.present?
        "/#{I18n.locale}/#{page_slug}"
      else
        "#"
      end
    end

    def parsed_link_path_params
      return if link_path_params.blank?
      return link_path_params if link_path_params.is_a?(Hash) || link_path_params.is_a?(Array)
      return link_path_params unless link_path_params.is_a?(String)

      begin
        parsed = JSON.parse(link_path_params)
        return parsed if parsed.is_a?(Hash) || parsed.is_a?(Array)
      rescue JSON::ParserError
      end

      begin
        parsed = YAML.safe_load(link_path_params, permitted_classes: [Symbol], aliases: true)
        return parsed if parsed.is_a?(Hash) || parsed.is_a?(Array)
      rescue Psych::SyntaxError
      end

      if link_path_params.include?('=>')
        begin
          parsed = JSON.parse(link_path_params.gsub('=>', ':'))
          return parsed if parsed.is_a?(Hash) || parsed.is_a?(Array)
        rescue JSON::ParserError
        end
      end

      link_path_params
    end

    def admin_attribute_names
      mobility_attribute_names
    end

    def mobility_attribute_names
      attributes = []
      self.class.mobility_attributes.each do |attr|
        I18n.available_locales.each do |locale|
          attributes << "#{attr}_#{locale}".to_sym
        end
      end
      attributes
    end
  end
end
