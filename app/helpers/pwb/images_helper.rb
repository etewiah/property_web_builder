# frozen_string_literal: true

module Pwb
  module ImagesHelper
    # Default loading behavior for images
    # Set to "lazy" for below-the-fold images, "eager" for critical images
    DEFAULT_LOADING = "lazy"

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
    # @return [String, nil] Image tag or nil if no image
    def opt_image_tag(photo, options = {})
      return nil unless photo

      # Extract custom options
      use_picture = options.delete(:use_picture)
      width = options.delete(:width)
      height = options.delete(:height)
      _quality = options.delete(:quality) # Reserved for future CDN usage
      _crop = options.delete(:crop) # Reserved for future CDN usage

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
        return image_tag(photo.external_url, options)
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

    # Generate a <picture> element with WebP source and fallback
    # @param photo [Object] A photo model with ActiveStorage image
    # @param variant_options [Hash] Options for image variant
    # @param html_options [Hash] HTML options for the img tag
    # @return [String] Picture element HTML
    def optimized_image_picture(photo, variant_options = {}, html_options = {})
      webp_options = variant_options.merge(format: :webp)
      fallback_url = if variant_options.present?
                       url_for(photo.image.variant(variant_options))
                     else
                       url_for(photo.image)
                     end

      content_tag(:picture) do
        # WebP source for modern browsers
        webp_source = tag(:source,
                          srcset: url_for(photo.image.variant(webp_options)),
                          type: "image/webp")
        # Fallback img tag
        fallback_img = image_tag(fallback_url, html_options)

        safe_join([webp_source, fallback_img])
      end
    rescue StandardError => e
      # Fall back to regular image if variant generation fails
      Rails.logger.warn("Failed to generate optimized image: #{e.message}")
      image_tag url_for(photo.image), html_options
    end

    # Display a photo with support for external URLs and variants
    # @param photo [Object] A photo model (PropPhoto, ContentPhoto, WebsitePhoto)
    # @param variant_options [Hash] Options for image variant (e.g., resize_to_limit: [200, 200])
    # @param html_options [Hash] HTML options for the image tag (e.g., class, alt)
    #   - :lazy [Boolean] Enable lazy loading (default: true)
    #   - :eager [Boolean] Disable lazy loading for above-the-fold images
    #   - :fetchpriority [String] Set fetch priority ("high", "low", "auto")
    # @return [String, nil] Image tag or nil if no image
    def photo_image_tag(photo, variant_options: nil, **html_options)
      return nil unless photo

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
