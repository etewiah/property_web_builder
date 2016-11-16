module Pwb
  class ContentPhoto < ApplicationRecord
    mount_uploader :image, ContentPhotoUploader
    belongs_to :content

  end
end
