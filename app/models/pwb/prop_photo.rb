module Pwb
  class PropPhoto < ApplicationRecord
    mount_uploader :image, PropPhotoUploader
    belongs_to :prop, optional: true
  end
end
