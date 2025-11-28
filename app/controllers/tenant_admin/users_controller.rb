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
      
      # Filter by website
      if params[:website_id].present?
        @users = @users.where(pwb_website_id: params[:website_id])
      end
      
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
      @user.destroy
      redirect_to tenant_admin_users_path, notice: "User deleted successfully."
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
        :pwb_website_id
      )
    end
  end
end
