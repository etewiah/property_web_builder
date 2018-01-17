require_dependency 'pwb/application_controller'

module Pwb
	class OmniauthCallbacksController < Devise::OmniauthCallbacksController
	   def facebook
	     @user = User.find_for_oauth(request.env['omniauth.auth'])
	    	if @user.persisted?
	       sign_in_and_redirect @user, event: :authentication
	       set_flash_message(:notice, :success, kind: 'Facebook') if is_navigational_format?
	    end
	  end
	end
end