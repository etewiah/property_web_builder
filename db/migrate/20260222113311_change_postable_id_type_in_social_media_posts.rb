# frozen_string_literal: true

# Fix polymorphic postable_id column type: bigint cannot store UUID primary keys.
# pwb_realty_assets uses UUID primary keys, so postable_id must be a string
# to correctly store and look up the polymorphic association.
class ChangePostableIdTypeInSocialMediaPosts < ActiveRecord::Migration[8.1]
  def up
    change_column :pwb_social_media_posts, :postable_id, :string
  end

  def down
    change_column :pwb_social_media_posts, :postable_id, :bigint
  end
end
