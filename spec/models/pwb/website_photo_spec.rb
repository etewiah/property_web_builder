# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_website_photos
# Database name: primary
#
#  id           :bigint           not null, primary key
#  description  :string
#  external_url :string
#  file_size    :integer
#  folder       :string           default("weebrix")
#  image        :string
#  photo_key    :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  website_id   :bigint
#
# Indexes
#
#  index_pwb_website_photos_on_photo_key   (photo_key)
#  index_pwb_website_photos_on_website_id  (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe WebsitePhoto, type: :model do
    pending "add some examples to (or delete) #{__FILE__}"
  end
end
