class Pwb::Devise::RegistrationsController < Devise::RegistrationsController
  def edit_success
    render "/devise/registrations/edit_success"
  end

  # The default url to be used after updating a resource. You need to overwrite
  # this method in your own RegistrationsController.
  def after_update_path_for(_resource)
    # signed_in_root_path(resource)
    pwb.user_edit_success_path
  end
end
