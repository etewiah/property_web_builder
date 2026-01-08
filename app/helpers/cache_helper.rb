# frozen_string_literal: true

# CacheHelper provides consistent cache key generation and fragment caching
# for the multi-tenant PropertyWebBuilder application.
#
# All cache keys are scoped to the current website (tenant) to prevent
# cross-tenant data leakage.
#
# EDIT MODE & WEBSITE LOCKING:
# When edit_mode is active or website is being compiled for locking,
# caching should be skipped to ensure fresh content is rendered.
# Use `cacheable?` to check before caching, or use `cache_unless_editing`
# helper which handles this automatically.
#
# Usage in views:
#   <%# Automatic edit mode handling: %>
#   <% cache_unless_editing page_cache_key(@page) do %>
#     <%= render @page %>
#   <% end %>
#
#   <%# Or manual check: %>
#   <% if cacheable? %>
#     <% cache property_cache_key(@property) do %>
#       <%= render @property %>
#     <% end %>
#   <% else %>
#     <%= render @property %>
#   <% end %>
#
# Usage in controllers/models:
#   Rails.cache.fetch(cache_key_for("properties", @property)) { expensive_query }
#
module CacheHelper
  # Generate a tenant-scoped cache key for any object
  # Includes website_id, locale, and object's cache_key_with_version
  def cache_key_for(*parts)
    website_id = current_website_id
    locale = I18n.locale

    base_parts = ["w#{website_id}", "l#{locale}"]

    expanded_parts = parts.map do |part|
      case part
      when ActiveRecord::Base
        part.cache_key_with_version
      when ActiveRecord::Relation
        part.cache_key_with_version
      else
        part.to_s
      end
    end

    (base_parts + expanded_parts).join("/")
  end

  # Cache key for a single property
  # Includes property version and photo count for proper invalidation
  def property_cache_key(property, options = {})
    return nil unless property

    parts = [
      "property",
      property.id,
      property.updated_at.to_i,
      property.prop_photos.count
    ]

    parts << options[:variant] if options[:variant]
    cache_key_for(*parts)
  end

  # Cache key for property detail page sections
  # Separate keys for different sections enable Russian doll caching
  def property_detail_cache_key(property, section = "main")
    return nil unless property

    base_parts = [
      "prop_detail",
      property.id,
      section,
      property.updated_at.to_i
    ]

    # For image carousel, include photo timestamp for proper invalidation
    if section == "carousel"
      photo_updated = property.prop_photos.maximum(:updated_at)&.to_i || 0
      base_parts << photo_updated
    end

    cache_key_for(*base_parts)
  end

  # Cache key for property card (used in listings)
  # Includes user's currency preference to cache converted prices correctly
  def property_card_cache_key(property, operation_type = nil)
    return nil unless property

    # Include currency preference if CurrencyHelper is available
    currency = respond_to?(:user_preferred_currency) ? user_preferred_currency : "default"

    cache_key_for(
      "card",
      property.id,
      property.updated_at.to_i,
      operation_type || "default",
      "c#{currency}"
    )
  end

  # Cache key for a collection of properties
  # Uses max updated_at for proper invalidation
  def properties_collection_cache_key(properties, prefix = "collection")
    return cache_key_for(prefix, "empty") if properties.blank?

    max_updated = properties.maximum(:updated_at)&.to_i || 0
    count = properties.count

    cache_key_for(prefix, count, max_updated)
  end

  # Cache key for search results
  # Includes search params for uniqueness
  def search_results_cache_key(params, operation_type)
    search_params = params[:search]&.to_h || {}
    param_hash = Digest::MD5.hexdigest(search_params.sort.to_s)[0..8]
    page = params[:page] || 1

    cache_key_for(
      "search",
      operation_type,
      param_hash,
      "p#{page}"
    )
  end

  # Cache key for navigation/header elements
  def navigation_cache_key
    website = current_website
    return cache_key_for("nav", "none") unless website

    cache_key_for(
      "nav",
      website.updated_at.to_i,
      website.pages.visible.maximum(:updated_at)&.to_i || 0
    )
  end

  # Cache key for footer
  def footer_cache_key
    website = current_website
    return cache_key_for("footer", "none") unless website

    cache_key_for(
      "footer",
      website.updated_at.to_i
    )
  end

  # Cache key for page content
  def page_cache_key(page)
    return nil unless page

    cache_key_for(
      "page",
      page.slug,
      page.updated_at.to_i,
      page.page_contents.maximum(:updated_at)&.to_i || 0
    )
  end

  # Cache key for external listing detail page sections
  # Uses reference ID and listing type as identifier since external listings aren't AR models
  # @param listing [Pwb::ExternalFeed::NormalizedProperty] the listing object
  # @param section [String] the section name (e.g., "gallery", "info", "features")
  def external_listing_cache_key(listing, section = "main")
    return nil unless listing

    cache_key_for(
      "ext_listing",
      listing.reference,
      listing.listing_type,
      section,
      listing.updated_at&.to_i || Time.current.to_i
    )
  end

  # Cache key for a page part/component
  # Includes page part version and block contents hash for proper invalidation
  # @param page_part [Pwb::PagePart] the page part object
  # @param page_content [Pwb::PageContent] optional page content for context-specific caching
  def page_part_cache_key(page_part, page_content = nil)
    return nil unless page_part

    parts = [
      "page_part",
      page_part.page_part_key,
      page_part.updated_at.to_i
    ]

    # Include page content version if provided (for page-specific overrides)
    if page_content
      parts << "pc#{page_content.id}"
      parts << page_content.updated_at.to_i
    end

    # Include block_contents hash for JSON data changes
    if page_part.respond_to?(:block_contents) && page_part.block_contents.present?
      parts << Digest::MD5.hexdigest(page_part.block_contents.to_json)[0..8]
    end

    cache_key_for(*parts)
  end

  # ---------------------------------------------------------------------------
  # Edit Mode & Website Locking Compatibility
  # ---------------------------------------------------------------------------

  # Check if the current request is in edit mode
  # Edit mode should never use cached content as editors need fresh data
  def edit_mode?
    # Return memoized value if already computed (not nil)
    return @_edit_mode unless @_edit_mode.nil?

    @_edit_mode = if defined?(params) && params[:edit_mode] == "true"
                    true
                  elsif defined?(@edit_mode) && @edit_mode
                    true
                  else
                    false
                  end
  end

  # Check if the website is being compiled for locking
  # During compilation, we want fresh content, not cached
  def compiling_for_lock?
    # Return memoized value if already computed (not nil)
    return @_compiling_for_lock unless @_compiling_for_lock.nil?

    @_compiling_for_lock = if defined?(@compiling_for_lock) && @compiling_for_lock
                             true
                           else
                             false
                           end
  end

  # Check if fragment caching should be used
  # Returns false when in edit mode or during lock compilation
  # This ensures editors always see fresh content and locked pages
  # are compiled from the true source of truth
  def cacheable?
    !edit_mode? && !compiling_for_lock?
  end

  # Helper to conditionally cache content based on edit mode
  # Skips caching when editing, uses cache otherwise
  #
  # Usage:
  #   <% cache_unless_editing page_cache_key(@page) do %>
  #     <%= expensive_render %>
  #   <% end %>
  #
  # @param key [String, Array] the cache key (from cache_key_for or similar)
  # @param options [Hash] options passed to Rails cache helper
  # @yield the content to cache/render
  def cache_unless_editing(key, options = {}, &block)
    if cacheable? && key.present?
      cache(key, options, &block)
    else
      capture(&block)
    end
  end

  private

  def current_website_id
    if defined?(current_website) && current_website
      current_website.id
    elsif defined?(Pwb::Current) && Pwb::Current.website
      Pwb::Current.website.id
    else
      "global"
    end
  end

  def current_website
    if defined?(@current_website)
      @current_website
    elsif defined?(Pwb::Current)
      Pwb::Current.website
    end
  end
end
