module TenantAdmin
  class WebsiteAdminsController < TenantAdminController
    before_action :set_website

    def index
      @admins = @website.admins
      # Exclude users who are already admins
      existing_admin_ids = @admins.pluck(:id)
      @users = Pwb::User.where.not(id: existing_admin_ids)
    end

    def create
      user = Pwb::User.find(params[:user_id])
      membership = @website.user_memberships.find_or_initialize_by(user: user)
      membership.role = 'admin'
      membership.active = true
      
      if membership.save
        redirect_to tenant_admin_website_admins_path(@website), notice: "Admin added successfully."
      else
        redirect_to tenant_admin_website_admins_path(@website), alert: "Failed to add admin."
      end
    end

    def destroy
      user = Pwb::User.find(params[:id])
      membership = @website.user_memberships.find_by(user: user)
      
      if membership&.destroy
        redirect_to tenant_admin_website_admins_path(@website), notice: "Admin removed successfully."
      else
        redirect_to tenant_admin_website_admins_path(@website), alert: "Failed to remove admin."
      end
    end

    private

    def set_website
      @website = Pwb::Website.unscoped.find(params[:website_id])
    end
  end
end
