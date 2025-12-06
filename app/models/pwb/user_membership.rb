module Pwb
  # UserMembership represents the relationship between users and websites.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::UserMembership for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
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
      role_level > other_membership.role_level
    end
  end
end
