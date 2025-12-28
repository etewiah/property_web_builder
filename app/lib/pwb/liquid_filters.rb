# frozen_string_literal: true

module Pwb
  # Custom Liquid filters for PropertyWebBuilder templates
  #
  # Usage in Liquid templates:
  #   {{ "/search/buy" | localize_url }}
  #   {{ page_part.cta_link.content | localize_url }}
  #   {{ "home" | material_icon }}
  #   {{ page_part.feature_1_icon.content | material_icon: "lg" }}
  #
  # This module wraps UrlLocalizationHelper for use in Liquid templates.
  # The core URL localization logic is shared with ERB views via UrlLocalizationHelper.
  #
  module LiquidFilters
    # Icon name mappings from legacy formats to Material Symbols
    # Mirrors the mappings in Pwb::IconHelper::ICON_ALIASES
    ICON_MAPPINGS = {
      # Legacy Font Awesome mappings
      "fa fa-home" => "home", "fa-home" => "home",
      "fa fa-search" => "search", "fa-search" => "search",
      "fa fa-user" => "person", "fa-user" => "person",
      "fa fa-envelope" => "email", "fa-envelope" => "email",
      "fa fa-phone" => "phone", "fa-phone" => "phone",
      "fa fa-map-marker-alt" => "location_on", "fa-map-marker-alt" => "location_on",
      "fa fa-map-marker" => "location_on", "fa-map-marker" => "location_on",
      "fa fa-check" => "check", "fa-check" => "check",
      "fa fa-check-square" => "check_circle", "fa-check-square" => "check_circle",
      "fa fa-bed" => "bed", "fa-bed" => "bed",
      "fa fa-bath" => "bathroom", "fa-bath" => "bathroom",
      "fa fa-shower" => "shower", "fa-shower" => "shower",
      "fa fa-car" => "directions_car", "fa-car" => "directions_car",
      "fa fa-money" => "attach_money", "fa-money" => "attach_money",
      "fa fa-key" => "key", "fa-key" => "key",
      "fa fa-lock" => "lock", "fa-lock" => "lock",
      "fa fa-globe" => "public", "fa-globe" => "public",
      "fa fa-star" => "star", "fa-star" => "star",
      "fa fa-edit" => "edit", "fa-edit" => "edit",
      "fa fa-pencil" => "edit", "fa-pencil" => "edit",
      "fa fa-bars" => "menu", "fa-bars" => "menu",
      "fa fa-times" => "close", "fa-times" => "close",
      "fa fa-expand" => "fullscreen", "fa-expand" => "fullscreen",
      "fa fa-arrows-alt" => "fullscreen", "fa-arrows-alt" => "fullscreen",
      "fa fa-filter" => "filter_list", "fa-filter" => "filter_list",
      "fa fa-images" => "photo_library", "fa-images" => "photo_library",
      "fa fa-info-circle" => "info", "fa-info-circle" => "info",
      "fa fa-quote-left" => "format_quote", "fa-quote-left" => "format_quote",
      "fa fa-spinner" => "sync", "fa-spinner" => "sync",
      "fa fa-refresh" => "refresh", "fa-refresh" => "refresh",
      "fa fa-handshake" => "handshake", "fa-handshake" => "handshake",
      "fa fa-external-link" => "open_in_new", "fa-external-link" => "open_in_new",
      "fa fa-chevron-down" => "expand_more", "fa-chevron-down" => "expand_more",
      "fa fa-chevron-up" => "expand_less", "fa-chevron-up" => "expand_less",
      "fa fa-chevron-left" => "chevron_left", "fa-chevron-left" => "chevron_left",
      "fa fa-chevron-right" => "chevron_right", "fa-chevron-right" => "chevron_right",
      # Legacy Phosphor mappings
      "ph ph-house" => "home", "ph-house" => "home",
      "ph ph-house-line" => "home", "ph-house-line" => "home",
      "ph ph-magnifying-glass" => "search", "ph-magnifying-glass" => "search",
      "ph ph-user" => "person", "ph-user" => "person",
      "ph ph-envelope" => "email", "ph-envelope" => "email",
      "ph ph-envelope-simple" => "email", "ph-envelope-simple" => "email",
      "ph ph-phone" => "phone", "ph-phone" => "phone",
      "ph ph-map-pin" => "location_on", "ph-map-pin" => "location_on",
      "ph ph-check" => "check", "ph-check" => "check",
      "ph ph-bed" => "bed", "ph-bed" => "bed",
      "ph ph-bathtub" => "bathroom", "ph-bathtub" => "bathroom",
      "ph ph-shower" => "shower", "ph-shower" => "shower",
      "ph ph-car" => "directions_car", "ph-car" => "directions_car",
      "ph ph-hand-coins" => "payments", "ph-hand-coins" => "payments",
      "ph ph-key" => "key", "ph-key" => "key",
      "ph ph-lock" => "lock", "ph-lock" => "lock",
      "ph ph-star" => "star", "ph-star" => "star",
      "ph ph-caret-left" => "chevron_left", "ph-caret-left" => "chevron_left",
      "ph ph-caret-right" => "chevron_right", "ph-caret-right" => "chevron_right",
      "ph ph-caret-down" => "expand_more", "ph-caret-down" => "expand_more",
      "ph ph-caret-up" => "expand_less", "ph-caret-up" => "expand_less",
      "ph ph-arrows-out" => "fullscreen", "ph-arrows-out" => "fullscreen",
      "ph ph-info" => "info", "ph-info" => "info",
      "ph ph-buildings" => "apartment", "ph-buildings" => "apartment",
      "ph ph-paper-plane-tilt" => "send", "ph-paper-plane-tilt" => "send",
      "ph ph-chat-circle-text" => "chat", "ph-chat-circle-text" => "chat",
      "ph ph-currency-circle-dollar" => "attach_money", "ph-currency-circle-dollar" => "attach_money",
      "ph ph-hash" => "tag", "ph-hash" => "tag",
      "ph ph-ruler" => "straighten", "ph-ruler" => "straighten",
      "ph ph-arrow-right" => "arrow_forward", "ph-arrow-right" => "arrow_forward",
      "ph ph-image" => "image", "ph-image" => "image",
      "ph ph-map-trifold" => "map", "ph-map-trifold" => "map",
      "ph ph-address-book" => "contacts", "ph-address-book" => "contacts"
    }.freeze

    # Render a Material Symbol icon from an icon name
    #
    # @param name [String] Icon name (Material Symbol name, or legacy FA/Phosphor)
    # @param size [String, nil] Size: "sm" (18px), "md" (24px), "lg" (36px), "xl" (48px)
    # @return [String] HTML span element with icon
    #
    # Examples:
    #   {{ "home" | material_icon }}
    #   {{ "fa fa-home" | material_icon }}  # Legacy support
    #   {{ "search" | material_icon: "lg" }}
    #   {{ page_part.icon.content | material_icon }}
    #
    def material_icon(name, size = nil)
      return "" if name.blank?

      # Normalize icon name
      icon_name = normalize_icon_name(name.to_s.strip)
      size_class = icon_size_class(size)

      css_classes = ["material-symbols-outlined", size_class].compact.join(" ")
      %(<span class="#{css_classes}" aria-hidden="true">#{icon_name}</span>)
    end

    # Render a brand/social icon using SVG sprite
    #
    # @param name [String] Brand name (facebook, instagram, linkedin, etc.)
    # @param size [Integer] Icon size in pixels (default: 24)
    # @return [String] HTML SVG element
    #
    # Examples:
    #   {{ "facebook" | brand_icon }}
    #   {{ "instagram" | brand_icon: 32 }}
    #
    def brand_icon(name, size = 24)
      return "" if name.blank?

      brand = name.to_s.downcase.strip
      # Map legacy FA brand classes
      brand = brand.gsub(/^(fa fa-|fab fa-|ph ph-)/, "")
      brand = "x" if brand == "x-twitter" || brand == "twitter" # Map twitter to X

      css_class = "brand-icon brand-icon-#{brand}"
      %(
        <svg class="#{css_class}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <use href="#icon-#{brand}"></use>
        </svg>
      ).squish
    end

    # Prepend the current locale to a URL path
    #
    # @param url [String] The URL path (e.g., "/search/buy", "/contact")
    # @return [String] The localized URL (e.g., "/es/search/buy", "/es/contact")
    #
    # Examples:
    #   {{ "/search/buy" | localize_url }}  => "/es/search/buy" (when locale is :es)
    #   {{ "/contact" | localize_url }}     => "/fr/contact" (when locale is :fr)
    #   {{ "https://example.com" | localize_url }} => "https://example.com" (external URLs unchanged)
    #   {{ "" | localize_url }}             => "" (empty strings unchanged)
    #   {{ "#section" | localize_url }}     => "#section" (anchors unchanged)
    #
    def localize_url(url)
      return url if url.blank?
      return url if external_url?(url)
      return url if anchor_only?(url)
      return url if already_localized?(url)

      locale = current_locale
      return url if locale.blank? || locale.to_s == I18n.default_locale.to_s

      # Ensure URL starts with /
      path = url.start_with?('/') ? url : "/#{url}"

      "/#{locale}#{path}"
    end

    private

    # Check if URL is external (starts with http://, https://, or //)
    def external_url?(url)
      url.match?(%r{\A(https?:)?//})
    end

    # Check if URL is an anchor-only link
    def anchor_only?(url)
      url.start_with?('#')
    end

    # Check if URL already has a locale prefix
    def already_localized?(url)
      available_locales = I18n.available_locales.map(&:to_s)
      # Match /en/, /es/, /fr/, etc. at the start of the path
      url.match?(%r{\A/(#{available_locales.join('|')})(/|$)})
    end

    # Get current locale from context or I18n
    def current_locale
      # Try to get locale from Liquid context registers
      if @context&.registers&.dig(:locale)
        @context.registers[:locale]
      else
        I18n.locale
      end
    end

    # Normalize icon name from legacy formats to Material Symbol name
    def normalize_icon_name(name)
      # Check if it's in the mappings
      return ICON_MAPPINGS[name] if ICON_MAPPINGS.key?(name)

      # Strip legacy prefixes
      name = name.gsub(/^(fa|fas|fab|ph)\s+/, "")
      name = name.gsub(/^(fa-|ph-)/, "")

      # Check mappings again after stripping prefix
      return ICON_MAPPINGS[name] if ICON_MAPPINGS.key?(name)

      # Convert dashes to underscores (Material uses underscores)
      name.tr("-", "_")
    end

    # Get CSS size class for icon
    def icon_size_class(size)
      case size&.to_s&.downcase
      when "xs" then "md-14"
      when "sm" then "md-18"
      when "md" then "md-24"
      when "lg" then "md-36"
      when "xl" then "md-48"
      else nil # Default size (24px)
      end
    end
  end
end
