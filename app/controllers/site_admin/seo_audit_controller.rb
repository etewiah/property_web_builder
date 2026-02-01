# frozen_string_literal: true

module SiteAdmin
  # SEO Audit Dashboard Controller
  # Provides an overview of SEO health across properties and pages
  #
  # Features:
  # - Summary statistics for SEO completeness
  # - Lists of items missing SEO data
  # - Quick links to fix issues
  class SeoAuditController < SiteAdminController
    def index
      # Get all properties for this website
      @properties = Pwb::ListedProperty
                      .where(website_id: current_website.id)
                      .order(created_at: :desc)

      # Get all pages for this website
      @pages = Pwb::Page.where(website_id: current_website.id).order(:slug)

      # Calculate statistics
      calculate_property_stats
      calculate_page_stats
      calculate_image_stats

      # Overall SEO score
      calculate_overall_score
    end

    private

    def calculate_property_stats
      total = @properties.count

      # Count properties with SEO fields
      # We need to check through listings (sale_listing or rental_listing)
      properties_with_seo_title = 0
      properties_with_meta_desc = 0

      @properties.each do |prop|
        has_seo_title = prop.respond_to?(:seo_title) && prop.seo_title.present?
        has_meta_desc = prop.respond_to?(:meta_description) && prop.meta_description.present?

        properties_with_seo_title += 1 if has_seo_title || prop.title.present?
        properties_with_meta_desc += 1 if has_meta_desc || prop.description.present?
      end

      @property_stats = {
        total: total,
        with_title: properties_with_seo_title,
        with_description: properties_with_meta_desc,
        missing_title: total - properties_with_seo_title,
        missing_description: total - properties_with_meta_desc,
        title_percentage: total.positive? ? (properties_with_seo_title * 100.0 / total).round : 0,
        description_percentage: total.positive? ? (properties_with_meta_desc * 100.0 / total).round : 0
      }

      # Get list of properties missing SEO (limited for display)
      @properties_missing_seo = @properties.select do |p|
        title_missing = p.title.blank? && (!p.respond_to?(:seo_title) || p.seo_title.blank?)
        desc_missing = p.description.blank? && (!p.respond_to?(:meta_description) || p.meta_description.blank?)
        title_missing || desc_missing
      end.first(10)
    end

    def calculate_page_stats
      total = @pages.count
      with_seo_title = @pages.count { |p| p.seo_title.present? || p.page_title.present? }
      with_meta_desc = @pages.count { |p| p.meta_description.present? }

      @page_stats = {
        total: total,
        with_title: with_seo_title,
        with_description: with_meta_desc,
        missing_title: total - with_seo_title,
        missing_description: total - with_meta_desc,
        title_percentage: total.positive? ? (with_seo_title * 100.0 / total).round : 0,
        description_percentage: total.positive? ? (with_meta_desc * 100.0 / total).round : 0
      }

      # Pages missing SEO
      @pages_missing_seo = @pages.select do |p|
        (p.seo_title.blank? && p.page_title.blank?) || p.meta_description.blank?
      end.first(10)
    end

    def calculate_image_stats
      # Get all prop photos for this website's properties
      property_ids = @properties.pluck(:id)

      # Count photos via RealtyAsset association
      total_photos = Pwb::PropPhoto
                       .joins("INNER JOIN pwb_realty_assets ON pwb_prop_photos.realty_asset_id = pwb_realty_assets.id")
                       .where(pwb_realty_assets: { website_id: current_website.id })
                       .count

      photos_with_alt = Pwb::PropPhoto
                          .joins("INNER JOIN pwb_realty_assets ON pwb_prop_photos.realty_asset_id = pwb_realty_assets.id")
                          .where(pwb_realty_assets: { website_id: current_website.id })
                          .where.not(description: [nil, ''])
                          .count

      @image_stats = {
        total: total_photos,
        with_alt: photos_with_alt,
        missing_alt: total_photos - photos_with_alt,
        alt_percentage: total_photos.positive? ? (photos_with_alt * 100.0 / total_photos).round : 0
      }

      # Properties with photos missing alt text (limited)
      @properties_with_missing_alt = Pwb::RealtyAsset
                                       .where(website_id: current_website.id)
                                       .joins(:prop_photos)
                                       .where(pwb_prop_photos: { description: [nil, ''] })
                                       .distinct
                                       .limit(10)
    end

    def calculate_overall_score
      # Weight: Properties 40%, Pages 30%, Images 30%
      property_score = (@property_stats[:title_percentage] + @property_stats[:description_percentage]) / 2.0
      page_score = (@page_stats[:title_percentage] + @page_stats[:description_percentage]) / 2.0
      image_score = @image_stats[:alt_percentage]

      @overall_score = (property_score * 0.4 + page_score * 0.3 + image_score * 0.3).round

      @score_grade = case @overall_score
                     when 90..100 then { letter: 'A', color: 'green', message: 'Excellent SEO health!' }
                     when 75..89 then { letter: 'B', color: 'blue', message: 'Good, but room for improvement' }
                     when 60..74 then { letter: 'C', color: 'yellow', message: 'Needs attention' }
                     when 40..59 then { letter: 'D', color: 'orange', message: 'Significant improvements needed' }
                     else { letter: 'F', color: 'red', message: 'Critical SEO issues' }
                     end
    end
  end
end
