# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_access_codes
# Database name: primary
#
#  id         :uuid             not null, primary key
#  active     :boolean          default(TRUE), not null
#  code       :string           not null
#  expires_at :datetime
#  max_uses   :integer
#  uses_count :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_access_codes_on_website_id           (website_id)
#  index_pwb_access_codes_on_website_id_and_code  (website_id,code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
module Pwb
  class AccessCode < ApplicationRecord
    self.table_name = 'pwb_access_codes'

    belongs_to :website

    validates :code, presence: true, uniqueness: { scope: :website_id }

    scope :active, -> { where(active: true) }
    scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
    scope :not_exhausted, -> { where('max_uses IS NULL OR uses_count < max_uses') }
    scope :valid, -> { active.not_expired.not_exhausted }

    def valid_code?
      active? && !expired? && !exhausted?
    end

    def expired?
      expires_at.present? && expires_at < Time.current
    end

    def exhausted?
      max_uses.present? && uses_count >= max_uses
    end

    def redeem!
      increment!(:uses_count)
    end
  end
end
