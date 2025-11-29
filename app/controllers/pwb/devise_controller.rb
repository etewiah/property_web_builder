module Pwb
  class DeviseController < ApplicationController
    # This controller is registered in
    # config/initializers/devise.rb
    # with:
    #   config.parent_controller = 'Pwb::DeviseController'
    #
    # Set the layout for all Devise controllers
    layout "pwb/devise"

    # https://github.com/plataformatec/devise/blob/master/lib/devise/controllers/helpers.rb

    # Method used by sessions controller to sign out a user. You can overwrite
    # it in your ApplicationController to provide a custom hook for a custom
    # scope. Notice that differently from +after_sign_in_path_for+ this method
    # receives a symbol with the scope, and not the resource.
    #
    # Overwriting the sign_out redirect path method
    # By default it is the root_path.
    def after_sign_out_path_for(_resource_or_scope)
      # scope = Devise::Mapping.find_scope!(resource_or_scope)
      # router_name = Devise.mappings[scope].router_name
      # context = router_name ? send(router_name) : self
      # context.respond_to?(:root_path) ? context.root_path : "/"
      home_path
    end

    def after_sign_in_path_for(_resource_or_scope)
      # TODO: - check for admin v standard users
      admin_path
      # stored_location_for(resource_or_scope) || signed_in_root_path(resource_or_scope)
    end
  end
end
