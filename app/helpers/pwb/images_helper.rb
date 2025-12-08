module Pwb
  module ImagesHelper
    def bg_image(photo, options = {})
      image_url = get_opt_image_url photo, options
      # style="background-image:linear-gradient( rgba(0, 0, 0, 0.8), rgba(0, 0, 0, 0.1) ),url(<%= carousel_item.default_photo %>);"
      if options[:gradient]
        "background-image: linear-gradient(#{options[:gradient]}), url(#{image_url});".html_safe
      else
        "background-image: url(#{image_url});".html_safe
      end
    end

    def opt_image_tag(photo, options = {})
      return nil unless photo

      # Handle external URLs first
      if photo.respond_to?(:external?) && photo.external?
        return image_tag(photo.external_url, options)
      end

      # Fall back to ActiveStorage
      return nil unless photo.image.attached?

      if Rails.application.config.use_cloudinary
        cl_image_tag photo.image, options
      else
        image_tag url_for(photo.image), options
      end
    end

    # Display a photo with support for external URLs and variants
    # @param photo [Object] A photo model (PropPhoto, ContentPhoto, WebsitePhoto)
    # @param variant_options [Hash] Options for image variant (e.g., resize_to_limit: [200, 200])
    # @param html_options [Hash] HTML options for the image tag (e.g., class, alt)
    def photo_image_tag(photo, variant_options: nil, **html_options)
      return nil unless photo

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

    def opt_image_url(photo, options = {})
      get_opt_image_url photo, options
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

    private

    def get_opt_image_url(photo, options)
      return "" unless photo

      # Handle external URLs
      if photo.respond_to?(:external?) && photo.external?
        return photo.external_url
      end

      # Fall back to ActiveStorage
      return "" unless photo.respond_to?(:image) && photo.image.attached?

      if Rails.application.config.use_cloudinary
        image_url = cl_image_path photo.image, options
      else
        image_url = url_for(photo.image)
      end
    end
  end
end
