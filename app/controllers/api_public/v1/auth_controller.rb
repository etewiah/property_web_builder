module ApiPublic
  module V1
    class AuthController < BaseController
      # Skip verify_authenticity_token is already handled in BaseController
      
      def firebase
        token = params[:token]
        unless token
          return render json: { error: "Token is missing" }, status: :bad_request
        end

        begin
          user = Pwb::FirebaseAuthService.new(token).call
          
          if user
            sign_in(user)
            # Return user info and maybe a session cookie/token depending on auth strategy
            render json: { 
              user: {
                id: user.id,
                email: user.email,
                firebase_uid: user.firebase_uid
              },
              message: "Logged in successfully" 
            }
          else
            render json: { error: "Invalid token" }, status: :unauthorized
          end
        rescue StandardError => e
          render json: { error: e.message }, status: :internal_server_error
        end
      end
    end
  end
end
