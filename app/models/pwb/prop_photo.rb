module Pwb
  class PropPhoto < ApplicationRecord
    # TODO - add optimised cloudinary images ..
    mount_uploader :image, PropPhotoUploader
    belongs_to :prop, optional: true
  end
end
