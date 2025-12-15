# frozen_string_literal: true

module TenantAdmin
  class UsersController < TenantAdminController
    before_action :set_user, only: [:show, :edit, :update, :destroy]

    def index
      @users = Pwb::User.unscoped.order(created_at: :desc)
      
      # Search by email
      if params[:search].present?
        @users = @users.where("email ILIKE ?", "%#{params[:search]}%")
      end
      
      # Filter by website - DISABLED (No association exists)
      # if params[:website_id].present?
      #   @users = @users.where(pwb_website_id: params[:website_id])
      # end
      
      # Filter by admin status
      if params[:admin].present?
        @users = @users.where(admin: params[:admin] == 'true')
      end
    end

    def show
      # @user set by before_action
    end

    def new
      @user = Pwb::User.new
      @websites = Pwb::Website.unscoped.order(:subdomain)
    end

    def create
      @user = Pwb::User.new(user_params)
      
      if @user.save
        redirect_to tenant_admin_user_path(@user), notice: "User created successfully."
      else
        @websites = Pwb::Website.unscoped.order(:subdomain)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @websites = Pwb::Website.unscoped.order(:subdomain)
    end

    def update
      if @user.update(user_params)
        redirect_to tenant_admin_user_path(@user), notice: "User updated successfully."
      else
        @websites = Pwb::Website.unscoped.order(:subdomain)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Safety checks before deletion
      deletion_result = check_user_deletion_safety(@user)

      if deletion_result[:can_delete]
        @user.destroy
        redirect_to tenant_admin_users_path, notice: "User '#{@user.email}' deleted successfully."
      else
        redirect_to tenant_admin_user_path(@user), alert: deletion_result[:reason]
      end
    end

    # Transfer ownership of websites before deleting user
    def transfer_ownership
      @user = Pwb::User.unscoped.find(params[:id])
      new_owner = Pwb::User.unscoped.find(params[:new_owner_id])

      transferred = 0
      @user.user_memberships.where(role: 'owner').each do |membership|
        # Create new owner membership
        Pwb::UserMembership.find_or_create_by!(user: new_owner, website: membership.website) do |m|
          m.role = 'owner'
          m.active = true
        end
        # Downgrade old owner to admin
        membership.update!(role: 'admin')
        transferred += 1
      end

      redirect_to tenant_admin_user_path(@user), notice: "Transferred ownership of #{transferred} website(s) to #{new_owner.email}."
    end

    private

    def set_user
      @user = Pwb::User.unscoped.find(params[:id])
    end

    def user_params
      params.require(:pwb_user).permit(
        :email,
        :password,
        :password_confirmation,
        :admin,
        :website_id
      )
    end

    def check_user_deletion_safety(user)
      # Check if user is sole owner of any website
      sole_owner_websites = []

      user.user_memberships.where(role: 'owner').each do |membership|
        website = membership.website
        # Count other owners for this website
        other_owners = website.user_memberships.where(role: 'owner').where.not(user_id: user.id).count
        sole_owner_websites << website if other_owners.zero?
      end

      if sole_owner_websites.any?
        website_names = sole_owner_websites.map(&:subdomain).join(', ')
        return {
          can_delete: false,
          reason: "Cannot delete user: sole owner of website(s): #{website_names}. Transfer ownership first.",
          sole_owner_websites: sole_owner_websites
        }
      end

      { can_delete: true }
    end
  end
end
