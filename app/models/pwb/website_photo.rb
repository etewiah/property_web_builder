module Pwb
  # WebsitePhoto stores branding images for websites.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::WebsitePhoto for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class WebsitePhoto < ApplicationRecord
    belongs_to :website, optional: true
    has_one_attached :image

    # validates_processing_of :image
    # validate :image_size_validation

    # def optimized_image_url
    #   unless image.url.present?
    #     # if this method is called too soon after an image is
    #     # uploaded, might need to reload the record to
    #     # have the url available
    #     reload
    #   end
    #   if Rails.application.config.use_cloudinary
    #     options = {height: 800, crop: "scale", quality: "auto"}
    #     image_url = Cloudinary::Utils.cloudinary_url image, options
    #   else
    #     image_url = image.url
    #   end
    #   image_url
    # end

    # private
    # def image_size_validation
    #   errors[:image] << "should be less than 500KB" if image.size > 0.5.megabytes
    # end
  end
end
