# frozen_string_literal: true

module SiteAdmin
  # TourController
  # Handles guided tour completion tracking for site admin users.
  #
  # The tour uses Shepherd.js to walk users through the site admin interface.
  # This controller provides a server-side endpoint to persist tour completion
  # status, complementing the localStorage-based tracking on the client side.
  #
  class TourController < SiteAdminController
    # POST /site_admin/tour/complete
    # Marks the guided tour as completed for the current user
    def complete
      if current_user
        current_user.update(site_admin_onboarding_completed_at: Time.current)
        render json: { success: true, message: 'Tour completed' }, status: :ok
      else
        render json: { success: false, message: 'User not found' }, status: :unauthorized
      end
    end
  end
end
