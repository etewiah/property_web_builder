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
      unless photo && photo.image.present?
        return nil
      end
      if Rails.application.config.use_cloudinary
        cl_image_tag photo.image, options
      else
        image_tag photo.image.url, options
      end
    end

    def opt_image_url(photo, options = {})
      get_opt_image_url photo, options
    end

    private

    def get_opt_image_url(photo, options)
      unless photo && photo.image.present?
        return ""
      end
      if Rails.application.config.use_cloudinary
        image_url = cl_image_path photo.image, options
      else
        image_url = image_url photo.image.url
      end
    end
  end
end
