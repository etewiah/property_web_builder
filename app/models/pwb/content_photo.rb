module Pwb
  class ContentPhoto < ApplicationRecord
    mount_uploader :image, ContentPhotoUploader
    belongs_to :content, optional: true
    # I use block_key col to indicate if there is a fragment block associated
    # with this photo

    # validates_processing_of :image
    # validate :image_size_validation

    def optimized_image_url
      unless image.url.present?
        # if this method is called too soon after an image is
        # uploaded, might need to reload the record to
        # have the url available
        reload
      end
      if Rails.application.config.use_cloudinary
        options = {height: 800, crop: "scale", quality: "auto"}
        image_url = Cloudinary::Utils.cloudinary_url image, options
      else
        image_url = image.url
      end
      image_url
    end

    # private
    # def image_size_validation
    #   errors[:image] << "should be less than 500KB" if image.size > 0.5.megabytes
    # end
  end
end
