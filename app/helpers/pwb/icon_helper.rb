# frozen_string_literal: true

module Pwb
  # Central icon helper - THE ONLY approved way to render icons in the application.
  #
  # This helper enforces the use of Material Icons across the entire application
  # and provides a consistent API for rendering icons with proper accessibility.
  #
  # @example Basic usage in ERB
  #   <%= icon(:home) %>
  #   # => <span class="material-symbols-outlined" aria-hidden="true">home</span>
  #
  # @example With size and style options
  #   <%= icon(:search, size: :lg, filled: true) %>
  #
  # @example Accessible icon with label
  #   <%= icon(:warning, aria: { label: "Warning message" }) %>
  #
  # @example Brand icons (social media)
  #   <%= brand_icon(:facebook) %>
  #
  module IconHelper
    # Render a Material Symbol icon
    #
    # @param name [Symbol, String] Icon name from Material Symbols
    # @param options [Hash] Rendering options
    # @option options [Symbol] :size Icon size - :sm (18px), :md (24px), :lg (36px), :xl (48px)
    # @option options [Boolean] :filled Use filled variant instead of outlined
    # @option options [String] :class Additional CSS classes
    # @option options [Hash] :aria Accessibility attributes (use :label for meaningful icons)
    # @option options [Hash] :data Data attributes for Stimulus controllers, etc.
    #
    # @return [ActiveSupport::SafeBuffer] HTML span element with icon
    #
    def icon(name, options = {})
      original_name = name.to_s
      name = normalize_icon_name(name)
      fallback_info = validate_icon_name!(name, original_name)

      # Use fallback icon if validation failed
      if fallback_info
        name = fallback_info[:fallback]
        options = options.merge(class: [options[:class], "icon-fallback"].compact.join(" "))
        options[:data] = (options[:data] || {}).merge(original_icon: fallback_info[:original])
      end

      size_class = icon_size_class(options[:size])
      filled_class = options[:filled] ? "filled" : nil
      custom_class = options[:class]

      classes = ["material-symbols-outlined", size_class, filled_class, custom_class].compact.join(" ")

      aria_attrs = build_aria_attributes(options[:aria])
      data_attrs = options[:data] || {}

      content_tag(:span, name, class: classes, **aria_attrs, data: data_attrs)
    end

    # Render an icon inside a button element
    #
    # @param name [Symbol, String] Icon name
    # @param options [Hash] Options (same as #icon, plus button-specific)
    # @option options [String] :button_class CSS class for the button element
    # @option options [String] :type Button type attribute (default: "button")
    #
    def icon_button(name, options = {})
      button_class = options.delete(:button_class) || "icon-button"
      button_type = options.delete(:type) || "button"
      aria_label = options.dig(:aria, :label)

      button_attrs = { class: button_class, type: button_type }
      button_attrs[:"aria-label"] = aria_label if aria_label

      content_tag(:button, icon(name, options.merge(aria: nil)), **button_attrs)
    end

    # Render a brand/logo icon using SVG sprite
    #
    # Material Icons doesn't include brand logos (Facebook, Instagram, etc.)
    # so we use an SVG sprite for these.
    #
    # @param name [Symbol, String] Brand name (facebook, instagram, linkedin, etc.)
    # @param options [Hash] Rendering options
    # @option options [Integer] :size Icon size in pixels (default: 24)
    # @option options [String] :class Additional CSS classes
    #
    # @return [ActiveSupport::SafeBuffer] HTML SVG element
    #
    def brand_icon(name, options = {})
      original_name = name.to_s.downcase
      fallback_info = validate_brand_name!(original_name)

      size = options[:size] || 24

      # Use fallback Material icon if brand not found
      if fallback_info
        return icon(fallback_info[:fallback],
                    size: size_to_symbol(size),
                    class: [options[:class], "brand-icon-fallback"].compact.join(" "),
                    data: { original_brand: fallback_info[:original] })
      end

      css_class = ["brand-icon", "brand-icon-#{original_name}", options[:class]].compact.join(" ")

      content_tag(:svg, class: css_class, width: size, height: size,
                        viewBox: "0 0 24 24", fill: "currentColor",
                        "aria-hidden": "true") do
        content_tag(:use, nil, href: "#icon-#{original_name}")
      end
    end

    # Convert pixel size to symbol size for icon helper
    def size_to_symbol(size)
      case size.to_i
      when 0..17 then :xs
      when 18..23 then :sm
      when 24..35 then :md
      when 36..47 then :lg
      else :xl
      end
    end

    # Render social media icon link
    #
    # @param platform [Symbol, String] Social platform name
    # @param url [String] Link URL
    # @param options [Hash] Options
    # @option options [Integer] :size Icon size
    # @option options [String] :class Additional CSS classes
    #
    def social_icon_link(platform, url, options = {})
      return nil if url.blank?

      platform = platform.to_s.downcase
      link_class = ["social-link", "social-link-#{platform}", options[:class]].compact.join(" ")

      link_to url, class: link_class, target: "_blank", rel: "noopener noreferrer",
                   "aria-label": "Follow us on #{platform.titleize}" do
        brand_icon(platform, size: options[:size] || 24)
      end
    end

    private

    # List of allowed Material Symbol icon names
    # Add new icons here as needed
    ALLOWED_ICONS = %w[
      home
      search
      arrow_back
      arrow_forward
      chevron_left
      chevron_right
      expand_more
      expand_less
      arrow_drop_down
      arrow_drop_up
      menu
      close
      check
      check_circle
      bed
      bathroom
      bathtub
      shower
      local_parking
      directions_car
      garage
      phone
      email
      mail
      person
      account_circle
      people
      group
      location_on
      place
      map
      public
      language
      edit
      delete
      add
      remove
      visibility
      visibility_off
      star
      star_border
      star_half
      favorite
      favorite_border
      share
      send
      contacts
      fullscreen
      fullscreen_exit
      zoom_in
      zoom_out
      filter_list
      tune
      sort
      photo_library
      image
      photo
      collections
      info
      info_outline
      warning
      error
      help
      help_outline
      login
      logout
      settings
      format_quote
      lock
      lock_open
      key
      vpn_key
      attach_money
      payments
      euro
      euro_symbol
      handshake
      wb_sunny
      light_mode
      dark_mode
      brightness_5
      brightness_6
      brightness_7
      tag
      label
      category
      description
      file_copy
      article
      grid_view
      view_list
      list
      refresh
      sync
      autorenew
      upload
      download
      cloud_upload
      cloud_download
      open_in_new
      link
      content_copy
      print
      calendar_today
      schedule
      access_time
      verified
      thumb_up
      thumb_down
      comment
      chat
      forum
      notifications
      arrow_right_alt
      trending_up
      trending_down
      analytics
      insights
      dashboard
      home_work
      apartment
      house
      villa
      cottage
      real_estate_agent
      sell
      shopping_cart
      receipt
      calculate
      straighten
      square_foot
      crop_square
      aspect_ratio
      layers
      terrain
      park
      pool
      fitness_center
      ac_unit
      local_laundry_service
      kitchen
      balcony
      deck
      roofing
      foundation
      stairs
      elevator
      accessible
      pets
      smoke_free
      wifi
      tv
      security
      camera_outdoor
      doorbell
      solar_power
      bolt
      water_drop
      local_fire_department
      thermostat
    ].freeze

    # Map common aliases and legacy names to Material icon names
    ICON_ALIASES = {
      # Legacy Font Awesome mappings
      "fa-home" => "home",
      "fa-search" => "search",
      "fa-user" => "person",
      "fa-envelope" => "email",
      "fa-phone" => "phone",
      "fa-map-marker-alt" => "location_on",
      "fa-map-marker" => "location_on",
      "fa-check" => "check",
      "fa-check-square" => "check_circle",
      "fa-bed" => "bed",
      "fa-bath" => "bathroom",
      "fa-shower" => "shower",
      "fa-car" => "directions_car",
      "fa-money" => "attach_money",
      "fa-key" => "key",
      "fa-lock" => "lock",
      "fa-globe" => "public",
      "fa-star" => "star",
      "fa-edit" => "edit",
      "fa-pencil" => "edit",
      "fa-chevron-down" => "expand_more",
      "fa-chevron-up" => "expand_less",
      "fa-chevron-left" => "chevron_left",
      "fa-chevron-right" => "chevron_right",
      "fa-angle-left" => "chevron_left",
      "fa-angle-right" => "chevron_right",
      "fa-bars" => "menu",
      "fa-times" => "close",
      "fa-expand" => "fullscreen",
      "fa-arrows-alt" => "fullscreen",
      "fa-filter" => "filter_list",
      "fa-images" => "photo_library",
      "fa-info-circle" => "info",
      "fa-quote-left" => "format_quote",
      "fa-spinner" => "sync",
      "fa-sign-out-alt" => "logout",
      "fa-cloud-upload-alt" => "cloud_upload",
      "fa-external-link" => "open_in_new",
      "fa-hand-holding-usd" => "payments",

      # Legacy Phosphor mappings
      "ph-house" => "home",
      "ph-house-line" => "home",
      "ph-magnifying-glass" => "search",
      "ph-user" => "person",
      "ph-envelope" => "email",
      "ph-envelope-simple" => "email",
      "ph-phone" => "phone",
      "ph-map-pin" => "location_on",
      "ph-check" => "check",
      "ph-bed" => "bed",
      "ph-bathtub" => "bathroom",
      "ph-shower" => "shower",
      "ph-car" => "directions_car",
      "ph-hand-coins" => "payments",
      "ph-key" => "key",
      "ph-lock" => "lock",
      "ph-star" => "star",
      "ph-caret-left" => "chevron_left",
      "ph-caret-right" => "chevron_right",
      "ph-caret-down" => "expand_more",
      "ph-caret-up" => "expand_less",
      "ph-arrows-out" => "fullscreen",
      "ph-info" => "info",
      "ph-sun" => "wb_sunny",
      "ph-sun-horizon" => "brightness_6",
      "ph-sun-dim" => "brightness_5",
      "ph-paper-plane-tilt" => "send",
      "ph-buildings" => "apartment",
      "ph-map-trifold" => "map",
      "ph-file-text" => "description",
      "ph-tag" => "tag",
      "ph-currency-circle-dollar" => "attach_money",
      "ph-hash" => "tag",
      "ph-ruler" => "straighten",
      "ph-arrow-right" => "arrow_forward",
      "ph-chat-circle-text" => "chat",
      "ph-address-book" => "contacts",

      # Material icon aliases (same icon, different names)
      "keyboard_arrow_down" => "expand_more",
      "keyboard_arrow_up" => "expand_less",
      "keyboard_arrow_left" => "chevron_left",
      "keyboard_arrow_right" => "chevron_right",

      # Semantic aliases
      bedroom: "bed",
      bedrooms: "bed",
      bathroom: "bathroom",
      bathrooms: "bathroom",
      parking: "local_parking",
      car: "directions_car",
      back: "arrow_back",
      forward: "arrow_forward",
      left: "chevron_left",
      right: "chevron_right",
      down: "expand_more",
      up: "expand_less",
      hamburger: "menu",
      envelope: "email",
      user: "person",
      marker: "location_on",
      location: "location_on",
      globe: "public",
      pencil: "edit",
      trash: "delete",
      plus: "add",
      minus: "remove",
      eye: "visibility",
      eye_off: "visibility_off",
      expand: "fullscreen",
      quote: "format_quote",
      money: "attach_money",
      price: "attach_money",
      sun: "wb_sunny",
      property: "home",
      house: "home",
      apartment: "apartment",
      building: "apartment"
    }.freeze

    # Allowed brand icon names
    ALLOWED_BRANDS = %w[
      facebook
      instagram
      linkedin
      youtube
      twitter
      x
      whatsapp
      pinterest
      tiktok
      google
    ].freeze

    def normalize_icon_name(name)
      name = name.to_s.strip.downcase

      # Check aliases first with original name (e.g., "ph-magnifying-glass")
      return ICON_ALIASES[name]&.to_s if ICON_ALIASES.key?(name)

      # Remove legacy prefixes
      name = name.gsub(/^(fa|fas|fab|ph)\s+/, "")
      name = name.gsub(/^(fa-|ph-)/, "")

      # Convert to underscore format
      name = name.tr("-", "_")

      # Check aliases again with normalized name
      ICON_ALIASES[name.to_sym]&.to_s || ICON_ALIASES[name]&.to_s || name
    end

    # Fallback icon for unknown icons
    FALLBACK_ICON = "help_outline"

    # Validate icon name and return fallback info if invalid
    # @param name [String] Normalized icon name
    # @param original_name [String] Original icon name before normalization
    # @return [Hash, nil] Fallback info hash or nil if valid
    def validate_icon_name!(name, original_name = nil)
      return nil if ALLOWED_ICONS.include?(name)

      original_name ||= name

      # In development/test, raise an error to catch issues early
      if Rails.env.development? || Rails.env.test?
        raise ArgumentError, <<~MSG
          Unknown icon: '#{name}'#{original_name != name ? " (from '#{original_name}')" : ""}

          If this is a valid Material Symbol, add it to ALLOWED_ICONS in IconHelper.
          Browse icons at: https://fonts.google.com/icons

          For brand icons (Facebook, Instagram, etc.), use brand_icon(:name) instead.
        MSG
      else
        # In production, log warning and return fallback
        Rails.logger.warn("IconHelper: Unknown icon '#{name}' (from '#{original_name}') - using fallback '#{FALLBACK_ICON}'")
        { fallback: FALLBACK_ICON, original: original_name }
      end
    end

    # Fallback brand icon (generic link icon)
    FALLBACK_BRAND = "link"

    # Validate brand name and return fallback info if invalid
    # @param name [String] Brand name
    # @return [Hash, nil] Fallback info hash or nil if valid
    def validate_brand_name!(name)
      return nil if ALLOWED_BRANDS.include?(name)

      if Rails.env.development? || Rails.env.test?
        raise ArgumentError, <<~MSG
          Unknown brand icon: '#{name}'

          Allowed brands: #{ALLOWED_BRANDS.join(", ")}

          To add a new brand, update ALLOWED_BRANDS and add the SVG to brands.svg sprite.
        MSG
      else
        Rails.logger.warn("IconHelper: Unknown brand icon '#{name}' - using fallback")
        { fallback: FALLBACK_BRAND, original: name }
      end
    end

    def icon_size_class(size)
      case size&.to_sym
      when :xs then "md-14"
      when :sm then "md-18"
      when :md, nil then "md-24"
      when :lg then "md-36"
      when :xl then "md-48"
      else "md-24"
      end
    end

    def build_aria_attributes(aria)
      return { "aria-hidden" => "true" } if aria.nil?

      if aria[:label].present?
        { "aria-label" => aria[:label], role: "img" }
      else
        { "aria-hidden" => "true" }.merge(aria.except(:label))
      end
    end
  end
end
