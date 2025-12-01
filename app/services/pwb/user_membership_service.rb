module Pwb
  class UserMembershipService
    class << self
      def grant_access(user:, website:, role: 'member')
        membership = UserMembership.find_or_initialize_by(user: user, website: website)
        membership.role = role
        membership.active = true
        membership.save!
        membership
      end

      def revoke_access(user:, website:)
        membership = UserMembership.find_by(user: user, website: website)
        return false unless membership
        
        membership.update!(active: false)
      end

      def change_role(user:, website:, new_role:)
        raise ArgumentError, "Invalid role" unless UserMembership::ROLES.include?(new_role)
        
        membership = UserMembership.find_by!(user: user, website: website)
        membership.update!(role: new_role)
      end

      def list_user_websites(user:, role: nil)
        scope = user.user_memberships.active.includes(:website)
        scope = scope.where(role: role) if role
        scope.map(&:website)
      end
      
      def list_website_users(website:, role: nil)
        scope = website.user_memberships.active.includes(:user)
        scope = scope.where(role: role) if role
        scope.map(&:user)
      end
    end
  end
end
