# frozen_string_literal: true

module SiteAdmin
  # UsersController
  # Manages users for the current website
  class UsersController < SiteAdminController
    def index
      # Scope to current website for multi-tenant isolation
      @users = Pwb::User.where(website_id: current_website&.id).order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        @users = @users.where('email ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      # Scope to current website for security
      @user = Pwb::User.where(website_id: current_website&.id).find(params[:id])
    end
  end
end
