module ApiPublic
  module V1
    class BaseController < ActionController::Base
      before_action :set_website
      skip_before_action :verify_authenticity_token

      private

      def set_website
        Pwb::Current.website = Pwb::Website.first
      end
    end
  end
end
