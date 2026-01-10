# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_testimonials
# Database name: primary
#
#  id              :bigint           not null, primary key
#  author_name     :string           not null
#  author_role     :string
#  featured        :boolean          default(FALSE), not null
#  position        :integer          default(0), not null
#  quote           :text             not null
#  rating          :integer
#  visible         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  author_photo_id :bigint
#  website_id      :bigint           not null
#
# Indexes
#
#  index_pwb_testimonials_on_author_photo_id  (author_photo_id)
#  index_pwb_testimonials_on_position         (position)
#  index_pwb_testimonials_on_visible          (visible)
#  index_pwb_testimonials_on_website_id       (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (author_photo_id => pwb_media.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
module Pwb
  class Testimonial < ApplicationRecord
    # ===================
    # Associations
    # ===================
    belongs_to :website, class_name: 'Pwb::Website'
    belongs_to :author_photo, class_name: 'Pwb::Media', optional: true

    # ===================
    # Validations
    # ===================
    validates :author_name, presence: true
    validates :quote, presence: true, length: { minimum: 10, maximum: 1000 }
    validates :rating, numericality: { 
      only_integer: true, 
      greater_than_or_equal_to: 1, 
      less_than_or_equal_to: 5 
    }, allow_nil: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # ===================
    # Scopes
    # ===================
    scope :visible, -> { where(visible: true) }
    scope :featured, -> { where(featured: true) }
    scope :ordered, -> { order(position: :asc, created_at: :desc) }

    # ===================
    # Instance Methods
    # ===================
    
    def author_photo_url
      author_photo&.image_url
    end

    def as_api_json
      {
        id: id,
        quote: quote,
        author_name: author_name,
        author_role: author_role,
        author_photo: author_photo_url,
        rating: rating,
        position: position
      }
    end
  end
end
