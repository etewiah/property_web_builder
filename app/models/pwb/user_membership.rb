module Pwb
  # UserMembership represents the relationship between users and websites.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::UserMembership for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
# == Schema Information
#
# Table name: pwb_user_memberships
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  role       :string           default("member"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_user_memberships_on_user_id       (user_id)
#  index_pwb_user_memberships_on_website_id    (website_id)
#  index_user_memberships_on_user_and_website  (user_id,website_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
  #
  class UserMembership < ApplicationRecord
    # Available roles in hierarchical order
    ROLES = %w[owner admin member viewer].freeze
    
    # Associations
    belongs_to :user, class_name: 'Pwb::User'
    belongs_to :website, class_name: 'Pwb::Website'
    
    # Validations
    validates :role, presence: true, inclusion: { in: ROLES }
    validates :user_id, uniqueness: { scope: :website_id, message: "already has a membership for this website" }
    validates :active, inclusion: { in: [true, false] }
    
    # Scopes
    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }
    scope :admins, -> { where(role: ['owner', 'admin']) }
    scope :owners, -> { where(role: 'owner') }
    scope :for_website, ->(website) { where(website: website) }
    scope :for_user, ->(user) { where(user: user) }
    
    # Class methods
    def self.role_hierarchy
      ROLES.each_with_index.to_h
    end
    
    # Instance methods
    def admin?
      role.in?(['owner', 'admin'])
    end
    
    def owner?
      role == 'owner'
    end
    
    def active?
      active == true
    end
    
    def role_level
      self.class.role_hierarchy[role] || -1
    end
    
    def can_manage?(other_membership)
      return false unless active?
      # Lower role_level means higher authority (owner=0 is highest)
      role_level < other_membership.role_level
    end
  end
end
