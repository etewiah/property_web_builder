module ApiPublic
  module V1
    class AuthController < BaseController
      include ::Devise::Controllers::Helpers

      def firebase
        token = params[:token]
        unless token
          return render json: { error: "Token is missing" }, status: :bad_request
        end

        begin
          user = Pwb::FirebaseAuthService.new(
            token,
            website: current_website,
            verification_token: params[:verification_token]
          ).call

          if user
            # Ensure user has access to this website before signing in
            unless user.website_id == current_website&.id || user.admin_for?(current_website)
              # User exists but doesn't have access to this website
              # Create a membership for them (as member, not admin)
              Pwb::UserMembershipService.grant_access(
                user: user,
                website: current_website,
                role: 'member'
              ) if current_website
            end

            # Use bypass: true to skip active_for_authentication? check
            # Firebase has already verified the user's identity
            sign_in(user, store: true)

            # Log the Firebase login success
            Pwb::AuthAuditLog.log_login_success(
              user: user,
              request: request,
              website: current_website
            )

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
          Rails.logger.error("[FirebaseAuth] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
          render json: { error: e.message }, status: :internal_server_error
        end
      end
    end
  end
end
