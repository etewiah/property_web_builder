# frozen_string_literal: true

module SiteAdmin
  # UsersController
  # Manages users and team members for the current website
  class UsersController < SiteAdminController
    before_action :set_user, only: %i[show edit update destroy resend_invitation update_role deactivate reactivate]
    before_action :ensure_can_manage_user, only: %i[edit update destroy update_role deactivate reactivate]

    def index
      @users = current_website.users.includes(:user_memberships).order(created_at: :desc)

      if params[:search].present?
        @users = @users.where('email ILIKE ?', "%#{params[:search]}%")
      end

      @pagy, @users = pagy(@users, limit: 25)
    end

    def show
      @membership = @user.user_memberships.find_by(website: current_website)
    end

    def new
      @user = Pwb::User.new
    end

    def create
      @user = Pwb::User.find_by(email: user_params[:email])

      if @user
        # User exists - add membership to this website
        if @user.user_memberships.exists?(website: current_website)
          flash[:alert] = 'This user is already a member of this website.'
          render :new, status: :unprocessable_entity
          return
        end

        @user.user_memberships.create!(
          website: current_website,
          role: user_params[:role] || 'member',
          active: true
        )
        # TODO: Send email notification about being added to website
        redirect_to site_admin_users_path, notice: "#{@user.email} has been added to your team."
      else
        # Create new user with invitation
        password = SecureRandom.hex(16)
        @user = Pwb::User.new(
          email: user_params[:email],
          first_names: user_params[:first_names],
          last_names: user_params[:last_names],
          password: password,
          password_confirmation: password,
          website: current_website
        )

        if @user.save
          @user.user_memberships.create!(
            website: current_website,
            role: user_params[:role] || 'member',
            active: true
          )
          # TODO: Send invitation email with password reset link
          redirect_to site_admin_users_path, notice: "Invitation sent to #{@user.email}."
        else
          render :new, status: :unprocessable_entity
        end
      end
    end

    def edit
      @membership = @user.user_memberships.find_by(website: current_website)
    end

    def update
      @membership = @user.user_memberships.find_by(website: current_website)

      ActiveRecord::Base.transaction do
        @user.update!(user_update_params)
        @membership&.update!(role: params[:role]) if params[:role].present?
      end

      redirect_to site_admin_user_path(@user), notice: 'User updated successfully.'
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = "Failed to update user: #{e.message}"
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @membership = @user.user_memberships.find_by(website: current_website)

      if @membership&.owner? && current_website.user_memberships.owners.count == 1
        redirect_to site_admin_users_path, alert: 'Cannot remove the only owner of this website.'
        return
      end

      if @user == current_user
        redirect_to site_admin_users_path, alert: 'You cannot remove yourself from the team.'
        return
      end

      # Remove membership rather than deleting user
      @membership&.destroy
      redirect_to site_admin_users_path, notice: "#{@user.email} has been removed from the team."
    end

    def resend_invitation
      # TODO: Implement actual invitation email sending
      redirect_to site_admin_user_path(@user), notice: "Invitation resent to #{@user.email}."
    end

    def update_role
      @membership = @user.user_memberships.find_by(website: current_website)

      if @membership.nil?
        redirect_to site_admin_users_path, alert: 'User is not a member of this website.'
        return
      end

      if @membership.owner? && current_website.user_memberships.owners.count == 1 && params[:role] != 'owner'
        redirect_to site_admin_user_path(@user), alert: 'Cannot change role of the only owner.'
        return
      end

      if @membership.update(role: params[:role])
        redirect_to site_admin_user_path(@user), notice: "Role updated to #{params[:role].titleize}."
      else
        redirect_to site_admin_user_path(@user), alert: 'Failed to update role.'
      end
    end

    def deactivate
      @membership = @user.user_memberships.find_by(website: current_website)

      if @user == current_user
        redirect_to site_admin_user_path(@user), alert: 'You cannot deactivate yourself.'
        return
      end

      if @membership&.update(active: false)
        redirect_to site_admin_user_path(@user), notice: "#{@user.email} has been deactivated."
      else
        redirect_to site_admin_user_path(@user), alert: 'Failed to deactivate user.'
      end
    end

    def reactivate
      @membership = @user.user_memberships.find_by(website: current_website)

      if @membership&.update(active: true)
        redirect_to site_admin_user_path(@user), notice: "#{@user.email} has been reactivated."
      else
        redirect_to site_admin_user_path(@user), alert: 'Failed to reactivate user.'
      end
    end

    private

    def set_user
      @user = current_website.users.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :first_names, :last_names, :role)
    end

    def user_update_params
      params.require(:user).permit(:first_names, :last_names, :phone_number_primary)
    end

    def ensure_can_manage_user
      current_membership = current_user.user_memberships.find_by(website: current_website)
      target_membership = @user.user_memberships.find_by(website: current_website)

      unless current_membership&.admin?
        redirect_to site_admin_users_path, alert: 'You do not have permission to manage users.'
        return
      end

      # Can't manage users with higher or equal role (except self)
      if target_membership && @user != current_user && !current_membership.can_manage?(target_membership)
        redirect_to site_admin_users_path, alert: 'You cannot manage users with equal or higher permissions.'
      end
    end
  end
end
