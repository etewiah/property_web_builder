module Pwb
  class ContentPhoto < ApplicationRecord
    mount_uploader :image, ContentPhotoUploader
    belongs_to :content


    # validates_processing_of :image
    # validate :image_size_validation

    # private
    # def image_size_validation
    #   errors[:image] << "should be less than 500KB" if image.size > 0.5.megabytes
    # end

  end
end
