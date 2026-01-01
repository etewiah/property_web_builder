# frozen_string_literal: true

module Pwb
  module ImagesHelper
    # Default loading behavior for images
    # Set to "lazy" for below-the-fold images, "eager" for critical images
    DEFAULT_LOADING = "lazy"

    # Get the alt text for a photo, falling back to description or generic text
    # @param photo [Object] A photo model (PropPhoto, ContentPhoto, WebsitePhoto)
    # @param fallback [String] Fallback text if no description available
    # @return [String] Alt text for the image
    def photo_alt_text(photo, fallback: "Image")
      return fallback unless photo

      # Use description if available (stored alt-text)
      if photo.respond_to?(:description) && photo.description.present?
        return photo.description
      end

      # For prop photos, try to get a descriptive fallback from the property
      if photo.respond_to?(:realty_asset) && photo.realty_asset.present?
        asset = photo.realty_asset
        # Build a descriptive alt from available data
        parts = []
        parts << asset.prop_type_key&.humanize if asset.respond_to?(:prop_type_key) && asset.prop_type_key.present?
        parts << "in #{asset.city}" if asset.respond_to?(:city) && asset.city.present?
        return "#{parts.join(' ')} - property photo" if parts.any?
      end

      # For content photos, use content title
      if photo.respond_to?(:content) && photo.content&.respond_to?(:title) && photo.content.title.present?
        return photo.content.title
      end

      fallback
    end

    # Generate background-image CSS style for a photo
    # @param photo [Object] A photo model (PropPhoto, ContentPhoto, WebsitePhoto)
    # @param options [Hash] Options including :gradient for overlay
    # @return [String] CSS background-image style
    def bg_image(photo, options = {})
      image_url = photo_url(photo)
      return "" if image_url.blank?

      if options[:gradient]
        "background-image: linear-gradient(#{options[:gradient]}), url(#{image_url});".html_safe
      else
        "background-image: url(#{image_url});".html_safe
      end
    end

    # Display a photo with support for external URLs and modern formats
    # @param photo [Object] A photo model (PropPhoto, ContentPhoto, WebsitePhoto)
    # @param options [Hash] HTML options for the image tag, plus:
    #   - :use_picture [Boolean] Use <picture> element with WebP source (default: false)
    #   - :width, :height [Integer] Resize dimensions
    #   - :quality [String] Image quality (e.g., "auto", "80")
    #   - :crop [String] Crop mode (e.g., "scale", "fill")
    #   - :lazy [Boolean] Enable lazy loading (default: true)
    #   - :eager [Boolean] Disable lazy loading for above-the-fold images
    #   - :fetchpriority [String] Set fetch priority ("high", "low", "auto")
    #   - :alt [String] Alt text (defaults to photo description if not provided)
    # @return [String, nil] Image tag or nil if no image
    def opt_image_tag(photo, options = {})
      return nil unless photo

      # Extract custom options
      use_picture = options.delete(:use_picture)
      width = options.delete(:width)
      height = options.delete(:height)
      _quality = options.delete(:quality) # Reserved for future CDN usage
      _crop = options.delete(:crop) # Reserved for future CDN usage

      # Set alt text from photo description if not explicitly provided
      options[:alt] ||= photo_alt_text(photo, fallback: "Property photo")

      # Handle lazy loading - default to lazy unless eager is specified
      eager = options.delete(:eager)
      lazy = options.delete(:lazy)

      # Apply lazy loading unless explicitly disabled
      unless eager == true || lazy == false
        options[:loading] ||= DEFAULT_LOADING
        options[:decoding] ||= "async"
      end

      # For eager/critical images, set high fetch priority
      if eager == true
        options[:fetchpriority] ||= "high"
        options[:loading] = "eager"
      end

      # Handle external URLs first
      if photo.respond_to?(:external?) && photo.external?
        if use_picture
          return external_image_picture(photo.external_url, options)
        else
          return image_tag(photo.external_url, options)
        end
      end

      # Fall back to ActiveStorage
      return nil unless photo.respond_to?(:image) && photo.image.attached?

      # Build variant options if dimensions specified
      variant_options = {}
      if width || height
        variant_options[:resize_to_limit] = [width, height].compact
      end

      # Use picture element with WebP source for better performance
      if use_picture && photo.image.variable?
        optimized_image_picture(photo, variant_options, options)
      elsif variant_options.present? && photo.image.variable?
        image_tag photo.image.variant(variant_options), options
      else
        image_tag url_for(photo.image), options
      end
    end

    # Responsive image breakpoints (width in pixels)
    RESPONSIVE_SIZES = [320, 640, 768, 1024, 1280].freeze

    # Generate a <picture> element with WebP source for external URLs
    # Only uses WebP optimization for known seed image URLs where WebP versions exist
    # For third-party URLs (e.g., rightmove, zoopla), just renders the original image
    # @param url [String] The JPEG image URL
    # @param html_options [Hash] HTML options for the img tag
    #   - :sizes [String] Responsive sizes attribute (e.g., "(max-width: 768px) 100vw, 50vw")
    #   - :responsive [Boolean] Enable responsive srcset generation (requires pre-generated sizes)
    # @return [String] Picture element HTML
    def external_image_picture(url, html_options = {})
      # Only use picture element optimization for our own seed images
      # Third-party URLs won't have WebP versions available
      unless url.to_s.match?(/\.jpe?g$/i) && trusted_webp_source?(url)
        return image_tag(url, html_options)
      end

      sizes = html_options.delete(:sizes)
      responsive = html_options.delete(:responsive)

      webp_url = url.sub(/\.jpe?g$/i, '.webp')

      content_tag(:picture) do
        sources = []

        # WebP source for modern browsers
        if responsive && sizes
          webp_srcset = generate_external_srcset(webp_url)
          sources << tag(:source, srcset: webp_srcset, sizes: sizes, type: "image/webp")
        else
          sources << tag(:source, srcset: webp_url, type: "image/webp")
        end

        # Fallback img tag with original JPEG (also with srcset if responsive)
        if responsive && sizes
          jpeg_srcset = generate_external_srcset(url)
          html_options[:srcset] = jpeg_srcset
          html_options[:sizes] = sizes
        end

        fallback_img = image_tag(url, html_options)
        safe_join(sources + [fallback_img])
      end
    end

    # Check if the URL is from a trusted source where WebP versions are available
    # Currently only our seed images bucket has pre-generated WebP versions
    # @param url [String] The image URL to check
    # @return [Boolean] true if WebP version should exist
    def trusted_webp_source?(url)
      return false if url.blank?

      # Only our seed images bucket has WebP versions
      # Add other trusted domains here as needed
      trusted_domains = [
        'pwb-seed-images.s3',
        'cloudflare-ipfs.com', # IPFS gateway for seed images
        'localhost',           # Local development
        '127.0.0.1'            # Local development
      ]

      trusted_domains.any? { |domain| url.to_s.include?(domain) }
    end

    # Generate srcset for external image URL
    # Assumes sized versions exist at path/image-WIDTHw.ext
    # @param url [String] The image URL
    # @return [String] srcset attribute value
    def generate_external_srcset(url)
      # For seed images, we use the original image for all sizes
      # as resized versions aren't pre-generated
      # This still provides browser with size hints
      "#{url} 1280w"
    end

    # Generate a <picture> element with WebP source and fallback
    # @param photo [Object] A photo model with ActiveStorage image
    # @param variant_options [Hash] Options for image variant
    # @param html_options [Hash] HTML options for the img tag
    #   - :sizes [String] Responsive sizes attribute (e.g., "(max-width: 768px) 100vw, 50vw")
    #   - :responsive [Boolean] Enable responsive srcset generation
    # @return [String] Picture element HTML
    def optimized_image_picture(photo, variant_options = {}, html_options = {})
      sizes = html_options.delete(:sizes)
      responsive = html_options.delete(:responsive)

      webp_options = variant_options.merge(format: :webp)
      fallback_url = if variant_options.present?
                       url_for(photo.image.variant(variant_options))
                     else
                       url_for(photo.image)
                     end

      content_tag(:picture) do
        sources = []

        if responsive && sizes
          # Generate responsive WebP srcset
          webp_srcset = generate_responsive_srcset(photo, format: :webp)
          sources << tag(:source, srcset: webp_srcset, sizes: sizes, type: "image/webp")

          # Generate responsive JPEG srcset for fallback
          jpeg_srcset = generate_responsive_srcset(photo, format: :jpeg)
          html_options[:srcset] = jpeg_srcset
          html_options[:sizes] = sizes
        else
          # Single WebP source
          sources << tag(:source,
                         srcset: url_for(photo.image.variant(webp_options)),
                         type: "image/webp")
        end

        # Fallback img tag
        fallback_img = image_tag(fallback_url, html_options)
        safe_join(sources + [fallback_img])
      end
    rescue StandardError => e
      # Fall back to regular image if variant generation fails
      Rails.logger.warn("Failed to generate optimized image: #{e.message}")
      image_tag url_for(photo.image), html_options
    end

    # Generate responsive srcset for ActiveStorage image
    # @param photo [Object] A photo model with ActiveStorage image
    # @param format [Symbol] Image format (:webp, :jpeg)
    # @return [String] srcset attribute value
    def generate_responsive_srcset(photo, format: :jpeg)
      srcset_entries = RESPONSIVE_SIZES.map do |width|
        variant_options = { resize_to_limit: [width, nil] }
        variant_options[:format] = format if format
        url = url_for(photo.image.variant(variant_options))
        "#{url} #{width}w"
      end
      srcset_entries.join(", ")
    rescue StandardError => e
      Rails.logger.warn("Failed to generate responsive srcset: #{e.message}")
      ""
    end

    # Display a photo with support for external URLs and variants
    # @param photo [Object] A photo model (PropPhoto, ContentPhoto, WebsitePhoto)
    # @param variant_options [Hash] Options for image variant (e.g., resize_to_limit: [200, 200])
    # @param html_options [Hash] HTML options for the image tag (e.g., class, alt)
    #   - :lazy [Boolean] Enable lazy loading (default: true)
    #   - :eager [Boolean] Disable lazy loading for above-the-fold images
    #   - :fetchpriority [String] Set fetch priority ("high", "low", "auto")
    #   - :alt [String] Alt text (defaults to photo description if not provided)
    # @return [String, nil] Image tag or nil if no image
    def photo_image_tag(photo, variant_options: nil, **html_options)
      return nil unless photo

      # Set alt text from photo description if not explicitly provided
      html_options[:alt] ||= photo_alt_text(photo, fallback: "Property photo")

      # Handle lazy loading - default to lazy unless eager is specified
      eager = html_options.delete(:eager)
      lazy = html_options.delete(:lazy)

      unless eager == true || lazy == false
        html_options[:loading] ||= DEFAULT_LOADING
        html_options[:decoding] ||= "async"
      end

      # For eager/critical images, set high fetch priority
      if eager == true
        html_options[:fetchpriority] ||= "high"
        html_options[:loading] = "eager"
      end

      # Handle external URLs - variants not supported for external URLs
      if photo.respond_to?(:external?) && photo.external?
        return image_tag(photo.external_url, html_options)
      end

      # Fall back to ActiveStorage
      return nil unless photo.respond_to?(:image) && photo.image.attached?

      if variant_options && photo.image.variable?
        image_tag photo.image.variant(variant_options), html_options
      else
        image_tag url_for(photo.image), html_options
      end
    end

    # Get optimized image URL (alias for photo_url for backwards compatibility)
    # @param photo [Object] A photo model
    # @param _options [Hash] Unused, kept for backwards compatibility
    # @return [String] The URL or empty string if no image
    def opt_image_url(photo, _options = {})
      photo_url(photo) || ""
    end

    # Get the URL for a photo (external or ActiveStorage)
    # @param photo [Object] A photo model
    # @return [String, nil] The URL or nil if no image
    def photo_url(photo)
      return nil unless photo

      if photo.respond_to?(:external?) && photo.external?
        photo.external_url
      elsif photo.respond_to?(:image) && photo.image.attached?
        url_for(photo.image)
      end
    end

    # Generate preload link tag for LCP image
    # Use in page_head yield block for hero/banner images
    # @param url [String] The image URL to preload
    # @param options [Hash] Options including :as, :type, :fetchpriority
    # @return [String] Preload link tag HTML
    def preload_image_tag(url, options = {})
      return "" if url.blank?

      as_type = options.delete(:as) || "image"
      fetchpriority = options.delete(:fetchpriority) || "high"

      tag(:link,
          rel: "preload",
          href: url,
          as: as_type,
          fetchpriority: fetchpriority,
          **options)
    end

    # Check if photo has an image (external or uploaded)
    # @param photo [Object] A photo model
    # @return [Boolean]
    def photo_has_image?(photo)
      return false unless photo

      if photo.respond_to?(:has_image?)
        photo.has_image?
      elsif photo.respond_to?(:external?) && photo.external?
        true
      elsif photo.respond_to?(:image)
        photo.image.attached?
      else
        false
      end
    end
  end
end
