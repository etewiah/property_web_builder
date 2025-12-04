# frozen_string_literal: true

module SiteAdmin
  # UsersController
  # Manages users for the current website
  class UsersController < SiteAdminController
    def index
      @users = Pwb::User.order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        @users = @users.where('email ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      @user = Pwb::User.find(params[:id])
    end
  end
end
