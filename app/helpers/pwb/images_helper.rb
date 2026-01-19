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
      return photo.description if photo.respond_to?(:description) && photo.description.present?

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
      return photo.content.title if photo.respond_to?(:content) && photo.content&.respond_to?(:title) && photo.content.title.present?

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
        return external_image_picture(photo.external_url, options) if use_picture

        return image_tag(photo.external_url, options)

      end

      # Fall back to ActiveStorage
      return nil unless photo.respond_to?(:image) && photo.image.attached?

      # Build variant options if dimensions specified
      variant_options = {}
      variant_options[:resize_to_limit] = [width, height].compact if width || height

      # Use picture element with WebP source for better performance
      if use_picture && photo.image.variable?
        optimized_image_picture(photo, variant_options, options)
      elsif variant_options.present? && photo.image.variable?
        image_tag photo.image.variant(variant_options), options
      else
        image_tag url_for(photo.image), options
      end
    end

    # Generate a responsive <picture> element with multiple formats and sizes.
    # This is the recommended method for rendering images with full responsive support.
    #
    # @param photo [Object] A photo model (PropPhoto, ContentPhoto, WebsitePhoto)
    # @param sizes [Symbol, String] Size preset (:hero, :card, :thumbnail, :content) or custom sizes string
    # @param options [Hash] HTML and behavior options
    #   - :alt [String] Alt text (defaults to photo description)
    #   - :class [String] CSS classes for the img element
    #   - :picture_class [String] CSS classes for the picture element
    #   - :eager [Boolean] Load eagerly for above-fold images (sets loading="eager", fetchpriority="high")
    #   - :avif [Boolean] Include AVIF source if supported (default: true)
    #   - :fallback_url [String] URL for placeholder if no image
    # @return [String, nil] Picture element HTML or nil if no image
    #
    # @example Property card
    #   <%= responsive_image_tag @property.primary_photo, sizes: :card, alt: @property.title %>
    #
    # @example Hero image (above fold)
    #   <%= responsive_image_tag @property.primary_photo, sizes: :hero, eager: true %>
    #
    # @example Custom sizes
    #   <%= responsive_image_tag @photo, sizes: "(min-width: 800px) 400px, 100vw" %>
    #
    def responsive_image_tag(photo, sizes: :card, **options)
      return placeholder_image_tag(options) if photo.blank?

      # Handle external URLs (no srcset generation possible)
      if photo.respond_to?(:external?) && photo.external?
        return external_responsive_image_tag(photo, sizes, options)
      end

      # Handle ActiveStorage attachments
      return placeholder_image_tag(options) unless photo.respond_to?(:image) && photo.image.attached?
      return placeholder_image_tag(options) unless photo.image.variable?

      build_responsive_picture(photo.image, sizes, options)
    end

    private def build_responsive_picture(attachment, sizes, options)
      sizes_value = ResponsiveVariants.sizes_for(sizes)
      include_avif = options.fetch(:avif, true) && ResponsiveVariants.avif_supported?
      original_width = attachment.blob.metadata[:width]

      content_tag(:picture, class: options[:picture_class]) do
        sources = []

        # AVIF source (best compression, newest browsers)
        if include_avif
          avif_srcset = build_variant_srcset(attachment, :avif, original_width)
          sources << tag.source(srcset: avif_srcset, sizes: sizes_value, type: "image/avif") if avif_srcset.present?
        end

        # WebP source (good compression, wide support)
        webp_srcset = build_variant_srcset(attachment, :webp, original_width)
        sources << tag.source(srcset: webp_srcset, sizes: sizes_value, type: "image/webp") if webp_srcset.present?

        # Fallback img with JPEG srcset
        jpeg_srcset = build_variant_srcset(attachment, :jpeg, original_width)
        fallback_img = build_fallback_img(attachment, jpeg_srcset, sizes_value, options)

        safe_join(sources + [fallback_img])
      end
    rescue StandardError => e
      Rails.logger.warn("[responsive_image_tag] Failed to build picture: #{e.message}")
      image_tag url_for(attachment), extract_img_options(options)
    end

    private def build_variant_srcset(attachment, format, original_width)
      widths = ResponsiveVariants.widths_for(original_width)

      entries = widths.map do |width|
        transformations = ResponsiveVariants.transformations_for(width, format)
        url = url_for(attachment.variant(transformations))
        "#{url} #{width}w"
      rescue StandardError => e
        Rails.logger.debug("[build_variant_srcset] Skipping #{width}w #{format}: #{e.message}")
        nil
      end.compact

      entries.join(", ")
    end

    private def build_fallback_img(attachment, srcset, sizes, options)
      img_options = extract_img_options(options)
      img_options[:srcset] = srcset if srcset.present?
      img_options[:sizes] = sizes

      # Default src is the original image
      default_src = url_for(attachment)

      tag.img(src: default_src, **img_options)
    end

    private def extract_img_options(options)
      eager = options[:eager]

      {
        alt: options[:alt] || "",
        class: options[:class],
        loading: eager ? "eager" : "lazy",
        decoding: "async",
        fetchpriority: eager ? "high" : nil,
        width: options[:width],
        height: options[:height]
      }.compact
    end

    private def external_responsive_image_tag(photo, sizes, options)
      url = photo.external_url
      sizes_value = ResponsiveVariants.sizes_for(sizes)

      # For trusted sources with WebP versions, use picture element
      if trusted_webp_source?(url) && url.to_s.match?(/\.jpe?g$/i)
        pic_options = extract_img_options(options).merge(sizes: sizes_value, responsive: true)
        external_image_picture(url, pic_options)
      else
        # Simple img tag for external URLs without WebP support
        image_tag(url, extract_img_options(options))
      end
    end

    private def placeholder_image_tag(options)
      placeholder_url = options[:fallback_url] || "/assets/placeholder.jpg"

      tag.img(
        src: placeholder_url,
        alt: options[:alt] || "Image not available",
        class: options[:class],
        loading: "lazy"
      )
    end

    public

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
      return image_tag(url, html_options) unless url.to_s.match?(/\.jpe?g$/i) && trusted_webp_source?(url)

      sizes = html_options.delete(:sizes)
      responsive = html_options.delete(:responsive)

      webp_url = url.sub(/\.jpe?g$/i, '.webp')

      content_tag(:picture) do
        sources = []

        # WebP source for modern browsers
        if responsive && sizes
          webp_srcset = generate_external_srcset(webp_url)
          sources << tag.source(srcset: webp_srcset, sizes: sizes, type: "image/webp")
        else
          sources << tag.source(srcset: webp_url, type: "image/webp")
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
        'seed-assets.propertywebbuilder.com', # R2 seed assets bucket
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
    #   - :sizes [String, Symbol] Responsive sizes attribute or preset name
    #   - :responsive [Boolean] Enable responsive srcset generation
    # @return [String] Picture element HTML
    def optimized_image_picture(photo, variant_options = {}, html_options = {})
      sizes = html_options.delete(:sizes)
      responsive = html_options.delete(:responsive)
      sizes_value = sizes.is_a?(Symbol) ? ResponsiveVariants.sizes_for(sizes) : sizes

      webp_options = variant_options.merge(format: :webp, saver: { quality: 80 })
      fallback_url = if variant_options.present?
                       url_for(photo.image.variant(variant_options))
                     else
                       url_for(photo.image)
                     end

      content_tag(:picture) do
        sources = []

        if responsive && sizes_value
          # Include AVIF if supported
          if ResponsiveVariants.avif_supported?
            avif_srcset = generate_responsive_srcset(photo, format: :avif)
            sources << tag.source(srcset: avif_srcset, sizes: sizes_value, type: "image/avif") if avif_srcset.present?
          end

          # Generate responsive WebP srcset
          webp_srcset = generate_responsive_srcset(photo, format: :webp)
          sources << tag.source(srcset: webp_srcset, sizes: sizes_value, type: "image/webp") if webp_srcset.present?

          # Generate responsive JPEG srcset for fallback
          jpeg_srcset = generate_responsive_srcset(photo, format: :jpeg)
          html_options[:srcset] = jpeg_srcset if jpeg_srcset.present?
          html_options[:sizes] = sizes_value
        else
          # Single WebP source
          sources << tag.source(srcset: url_for(photo.image.variant(webp_options)),
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
    # @param format [Symbol] Image format (:webp, :jpeg, :avif)
    # @return [String] srcset attribute value
    def generate_responsive_srcset(photo, format: :jpeg)
      return "" unless photo.respond_to?(:image) && photo.image.attached? && photo.image.variable?

      original_width = photo.image.blob.metadata[:width]
      widths = ResponsiveVariants.widths_for(original_width)

      srcset_entries = widths.map do |width|
        transformations = ResponsiveVariants.transformations_for(width, format)
        url = url_for(photo.image.variant(transformations))
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
      return image_tag(photo.external_url, html_options) if photo.respond_to?(:external?) && photo.external?

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

      tag.link(rel: "preload",
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

    # Scans HTML for image tags and replaces them with responsive versions
    # where possible (e.g. for seed images).
    # Also ensures lazy loading is enabled.
    # @param html_content [String] HTML content to process
    # @param options [Hash] Options for responsive behavior
    #   - :sizes [Symbol, String] Size preset or custom sizes (default: :content)
    # @return [String] Processed HTML
    def make_media_responsive(html_content, options = {})
      return html_content if html_content.blank?

      doc = Nokogiri::HTML::DocumentFragment.parse(html_content)
      sizes = ResponsiveVariants.sizes_for(options[:sizes] || :content)

      doc.css('img').each do |img_node|
        # Skip if already inside a picture element
        next if img_node.ancestors('picture').any?

        src = img_node['src']
        next if src.blank?

        # Ensure lazy loading
        img_node['loading'] ||= 'lazy'
        img_node['decoding'] ||= 'async'

        # Check if we can upgrade to picture element with WebP support
        if trusted_webp_source?(src) && src.match?(/\.jpe?g$/i)
          # Create options for external_image_picture
          pic_options = {
            class: img_node['class'],
            alt: img_node['alt'],
            loading: img_node['loading'],
            decoding: img_node['decoding'],
            style: img_node['style'],
            width: img_node['width'],
            height: img_node['height'],
            sizes: sizes,
            responsive: true,
            data: img_node.keys.select { |k| k.start_with?('data-') }.each_with_object({}) { |k, h| h[k] = img_node[k] }
          }

          # Generates the picture tag string with WebP source
          picture_html = external_image_picture(src, pic_options)

          # Replace the original img node with the new picture node
          img_node.replace(picture_html)
        end
      end

      doc.to_html
    end
  end
end
