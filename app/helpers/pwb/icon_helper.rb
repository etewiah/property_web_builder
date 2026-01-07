# frozen_string_literal: true

module Pwb
  # Central icon helper - THE ONLY approved way to render icons in the application.
  #
  # This helper renders inline SVG icons from Lucide (https://lucide.dev)
  # and provides a consistent API for rendering icons with proper accessibility.
  #
  # @example Basic usage in ERB
  #   <%= icon(:home) %>
  #   # => <svg class="icon icon-md" aria-hidden="true">...</svg>
  #
  # @example With size and style options
  #   <%= icon(:search, size: :lg, class: "text-gray-500") %>
  #
  # @example Accessible icon with label
  #   <%= icon(:warning, aria: { label: "Warning message" }) %>
  #
  # @example Brand icons (social media)
  #   <%= brand_icon(:facebook) %>
  #
  module IconHelper
    # Render an icon from Lucide SVG icons
    #
    # @param name [Symbol, String] Icon name (Material Symbols name, will be mapped to Lucide)
    # @param options [Hash] Rendering options
    # @option options [Symbol] :size Icon size - :xs (14px), :sm (18px), :md (24px), :lg (36px), :xl (48px)
    # @option options [Boolean] :filled Use filled variant (adds fill, removes stroke)
    # @option options [String] :class Additional CSS classes
    # @option options [Hash] :aria Accessibility attributes (use :label for meaningful icons)
    # @option options [Hash] :data Data attributes for Stimulus controllers, etc.
    #
    # @return [ActiveSupport::SafeBuffer] HTML SVG element with icon
    #
    def icon(name, options = {})
      original_name = name.to_s
      normalized_name = normalize_icon_name(name)
      lucide_name = ICON_MAP[normalized_name]

      # Validate icon exists
      unless lucide_name
        fallback_info = validate_icon_name!(normalized_name, original_name)
        if fallback_info
          lucide_name = ICON_MAP[fallback_info[:fallback]] || "help-circle"
          options = options.merge(class: [options[:class], "icon-fallback"].compact.join(" "))
          options[:data] = (options[:data] || {}).merge(original_icon: fallback_info[:original])
        end
      end

      render_svg_icon(lucide_name, options)
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

    # Render a brand/logo icon using inline SVG
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

      # Use fallback icon if brand not found
      if fallback_info
        return icon(fallback_info[:fallback],
                    size: size_to_symbol(size),
                    class: [options[:class], "brand-icon-fallback"].compact.join(" "),
                    data: { original_brand: fallback_info[:original] })
      end

      # Brand icons use the Lucide social icons
      lucide_name = BRAND_ICON_MAP[original_name] || original_name
      css_class = ["brand-icon", "brand-icon-#{original_name}", options[:class]].compact.join(" ")

      render_svg_icon(lucide_name, size: size_to_symbol(size), class: css_class)
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

    # Render an SVG icon by reading the file and inlining it
    #
    # @param lucide_name [String] The Lucide icon filename (without .svg)
    # @param options [Hash] Rendering options
    # @return [ActiveSupport::SafeBuffer] The SVG element
    #
    def render_svg_icon(lucide_name, options = {})
      size_class = icon_size_class(options[:size])
      filled_class = options[:filled] ? "icon-filled" : nil
      custom_class = options[:class]

      classes = ["icon", size_class, filled_class, custom_class].compact.join(" ")
      aria_attrs = build_aria_attributes(options[:aria])
      data_attrs = (options[:data] || {}).dup
      data_attrs[:icon_name] ||= lucide_name

      # Read SVG file
      svg_path = Rails.root.join("app", "assets", "images", "icons", "#{lucide_name}.svg")

      if File.exist?(svg_path)
        svg_content = File.read(svg_path)

        # Parse and modify SVG attributes
        # Remove width/height attributes (we use CSS), add our classes and aria
        svg_content = svg_content
          .gsub(/\s*width="[^"]*"/, "")
          .gsub(/\s*height="[^"]*"/, "")
          .gsub(/<svg/, "<svg class=\"#{classes}\"")

        # Add aria attributes
        if aria_attrs[:role]
          svg_content = svg_content.gsub(/<svg/, "<svg role=\"#{aria_attrs[:role]}\"")
        end
        if aria_attrs["aria-hidden"]
          svg_content = svg_content.gsub(/<svg/, "<svg aria-hidden=\"true\"")
        end
        if aria_attrs["aria-label"]
          svg_content = svg_content.gsub(/<svg/, "<svg aria-label=\"#{aria_attrs["aria-label"]}\"")
        end

        # Add data attributes
        data_attrs.each do |key, value|
          svg_content = svg_content.gsub(/<svg/, "<svg data-#{key.to_s.dasherize}=\"#{value}\"")
        end

        svg_content.html_safe
      else
        # Fallback: render a placeholder with error indication
        Rails.logger.warn("IconHelper: SVG file not found: #{svg_path}")
        content_tag(:span, "[#{lucide_name}]", class: "#{classes} icon-missing", **aria_attrs, data: data_attrs)
      end
    end

    # Map Material Symbols icon names to Lucide icon filenames
    # Format: 'material_name' => 'lucide-filename'
    ICON_MAP = {
      # Property/Real Estate
      "home" => "house",
      "apartment" => "building",
      "bed" => "bed",
      "shower" => "shower-head",
      "bathtub" => "bath",
      "bathroom" => "bath",
      "directions_car" => "car",
      "local_parking" => "car",
      "garage" => "warehouse",
      "square_foot" => "square",
      "straighten" => "ruler",
      "landscape" => "mountain",
      "terrain" => "mountain",
      "pool" => "waves",
      "fitness_center" => "dumbbell",
      "ac_unit" => "snowflake",
      "kitchen" => "cooking-pot",
      "balcony" => "fence",
      "deck" => "fence",
      "roofing" => "home",
      "stairs" => "arrow-up-down",
      "elevator" => "arrow-up-down",
      "accessible" => "accessibility",
      "pets" => "paw-print",
      "smoke_free" => "cigarette-off",
      "wifi" => "wifi",
      "tv" => "tv",
      "security" => "shield",
      "solar_power" => "sun",
      "bolt" => "zap",
      "water_drop" => "droplet",
      "thermostat" => "thermometer",
      "house" => "house",
      "villa" => "castle",
      "cottage" => "home",
      "real_estate_agent" => "user",
      "home_work" => "building-2",
      "park" => "trees",
      "local_laundry_service" => "shirt",
      "foundation" => "layers",
      "doorbell" => "bell",
      "camera_outdoor" => "camera",
      "local_fire_department" => "flame",

      # Navigation
      "chevron_left" => "chevron-left",
      "chevron_right" => "chevron-right",
      "expand_more" => "chevron-down",
      "expand_less" => "chevron-up",
      "keyboard_arrow_down" => "chevron-down",
      "keyboard_arrow_up" => "chevron-up",
      "arrow_back" => "arrow-left",
      "arrow_forward" => "arrow-right",
      "arrow_drop_down" => "chevron-down",
      "arrow_drop_up" => "chevron-up",
      "arrow_right_alt" => "arrow-right",
      "close" => "x",
      "menu" => "menu",

      # Communication
      "email" => "mail",
      "mail" => "mail",
      "phone" => "phone",
      "location_on" => "map-pin",
      "place" => "map-pin",
      "map" => "map",
      "public" => "globe",
      "language" => "globe",
      "send" => "send",
      "chat" => "message-circle",
      "forum" => "messages-square",
      "contacts" => "contact",
      "comment" => "message-square",
      "notifications" => "bell",

      # Actions
      "search" => "search",
      "filter_list" => "filter",
      "tune" => "sliders-horizontal",
      "sort" => "arrow-up-down",
      "refresh" => "refresh-cw",
      "sync" => "refresh-cw",
      "autorenew" => "refresh-cw",
      "check" => "check",
      "check_circle" => "check-circle",
      "edit" => "pencil",
      "delete" => "trash-2",
      "add" => "plus",
      "remove" => "minus",
      "fullscreen" => "maximize",
      "fullscreen_exit" => "minimize",
      "zoom_in" => "zoom-in",
      "zoom_out" => "zoom-out",
      "visibility" => "eye",
      "visibility_off" => "eye-off",
      "upload" => "upload",
      "download" => "download",
      "cloud_upload" => "cloud-upload",
      "cloud_download" => "cloud-download",
      "open_in_new" => "external-link",
      "link" => "link",
      "content_copy" => "copy",
      "print" => "printer",
      "share" => "share-2",

      # UI Elements
      "tag" => "tag",
      "label" => "tag",
      "category" => "folder",
      "description" => "file-text",
      "file_copy" => "files",
      "article" => "file-text",
      "grid_view" => "grid-3x3",
      "view_list" => "list",
      "list" => "list",
      "photo_library" => "images",
      "image" => "image",
      "photo" => "image",
      "collections" => "images",
      "layers" => "layers",
      "aspect_ratio" => "ratio",
      "crop_square" => "square",

      # Status/Info
      "info" => "info",
      "warning" => "alert-triangle",
      "error" => "alert-circle",
      "help" => "help-circle",
      "help_outline" => "help-circle",
      "verified" => "badge-check",
      "thumb_up" => "thumbs-up",
      "thumb_down" => "thumbs-down",
      "trending_up" => "trending-up",
      "trending_down" => "trending-down",

      # User/Account
      "person" => "user",
      "account_circle" => "user-circle",
      "people" => "users",
      "group" => "users",
      "login" => "log-in",
      "logout" => "log-out",
      "settings" => "settings",
      "lock" => "lock",
      "lock_open" => "unlock",
      "key" => "key",
      "vpn_key" => "key",

      # Commerce
      "attach_money" => "dollar-sign",
      "payments" => "credit-card",
      "euro" => "euro",
      "euro_symbol" => "euro",
      "shopping_cart" => "shopping-cart",
      "receipt" => "receipt",
      "calculate" => "calculator",
      "sell" => "tag",
      "handshake" => "handshake",

      # Favorites/Rating
      "star" => "star",
      "star_border" => "star",
      "star_half" => "star-half",
      "favorite" => "heart",
      "favorite_border" => "heart",

      # Misc
      "format_quote" => "quote",
      "wb_sunny" => "sun",
      "wb_twilight" => "sun",
      "light_mode" => "sun",
      "dark_mode" => "moon",
      "brightness_5" => "sun",
      "brightness_6" => "sun",
      "brightness_7" => "sun",
      "calendar_today" => "calendar",
      "schedule" => "clock",
      "access_time" => "clock",
      "dashboard" => "layout-dashboard",
      "analytics" => "bar-chart-2",
      "insights" => "lightbulb",
    }.freeze

    # Map brand names to Lucide icon filenames (for social media)
    BRAND_ICON_MAP = {
      "facebook" => "facebook",
      "instagram" => "instagram",
      "linkedin" => "linkedin",
      "youtube" => "youtube",
      "twitter" => "twitter",
      "x" => "twitter",
      "whatsapp" => "message-circle",
      "pinterest" => "pin",
      "tiktok" => "music",
      "google" => "globe",
    }.freeze

    # Map common aliases and legacy names to normalized icon names
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

      # Semantic aliases
      "bedroom" => "bed",
      "bedrooms" => "bed",
      "bathrooms" => "bathroom",
      "parking" => "local_parking",
      "car" => "directions_car",
      "back" => "arrow_back",
      "forward" => "arrow_forward",
      "left" => "chevron_left",
      "right" => "chevron_right",
      "down" => "expand_more",
      "up" => "expand_less",
      "hamburger" => "menu",
      "envelope" => "email",
      "user" => "person",
      "marker" => "location_on",
      "location" => "location_on",
      "globe" => "public",
      "info_outline" => "info",
      "pencil" => "edit",
      "trash" => "delete",
      "plus" => "add",
      "minus" => "remove",
      "eye" => "visibility",
      "eye_off" => "visibility_off",
      "expand" => "fullscreen",
      "quote" => "format_quote",
      "money" => "attach_money",
      "price" => "attach_money",
      "sun" => "wb_sunny",
      "property" => "home",
      "building" => "apartment",
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
      return ICON_ALIASES[name] if ICON_ALIASES.key?(name)

      # Remove legacy prefixes
      name = name.gsub(/^(fa|fas|fab|ph)\s+/, "")
      name = name.gsub(/^(fa-|ph-)/, "")

      # Convert to underscore format
      name = name.tr("-", "_")

      # Check aliases again with normalized name
      ICON_ALIASES[name.to_sym]&.to_s || ICON_ALIASES[name] || name
    end

    # Fallback icon for unknown icons
    FALLBACK_ICON = "help_outline"

    # Validate icon name and return fallback info if invalid
    # @param name [String] Normalized icon name
    # @param original_name [String] Original icon name before normalization
    # @return [Hash, nil] Fallback info hash or nil if valid
    def validate_icon_name!(name, original_name = nil)
      return nil if ICON_MAP.key?(name)

      original_name ||= name

      # In development/test, raise an error to catch issues early
      if Rails.env.development? || Rails.env.test?
        raise ArgumentError, <<~MSG
          Unknown icon: '#{name}'#{original_name != name ? " (from '#{original_name}')" : ""}

          If this is a valid icon, add it to ICON_MAP in IconHelper.
          Browse Lucide icons at: https://lucide.dev/icons

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

          To add a new brand, update ALLOWED_BRANDS and BRAND_ICON_MAP.
        MSG
      else
        Rails.logger.warn("IconHelper: Unknown brand icon '#{name}' - using fallback")
        { fallback: FALLBACK_BRAND, original: name }
      end
    end

    def icon_size_class(size)
      case size&.to_sym
      when :xs then "icon-xs"
      when :sm then "icon-sm"
      when :md, nil then "icon-md"
      when :lg then "icon-lg"
      when :xl then "icon-xl"
      else "icon-md"
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
