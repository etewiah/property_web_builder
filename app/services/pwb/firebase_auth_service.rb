module Pwb
  class FirebaseAuthService
    def initialize(token, website: nil)
      @token = token
      @website = website
    end

    def call
      StructuredLogger.info('[FirebaseAuth] Starting token verification',
        token_length: @token&.length || 0,
        website_id: @website&.id
      )

      begin
        verifier = FirebaseTokenVerifier.new(@token)
        payload = verifier.verify!
        StructuredLogger.info('[FirebaseAuth] Token verified successfully')
      rescue FirebaseTokenVerifier::CertificateError => e
        # Certificates missing or invalid - try refreshing
        StructuredLogger.warn('[FirebaseAuth] Certificate error, attempting refresh',
          error: e.message
        )
        begin
          FirebaseTokenVerifier.fetch_certificates!
          verifier = FirebaseTokenVerifier.new(@token)
          payload = verifier.verify!
          StructuredLogger.info('[FirebaseAuth] Token verified after certificate refresh')
        rescue StandardError => retry_error
          StructuredLogger.error('[FirebaseAuth] Retry after certificate refresh failed',
            error_class: retry_error.class.name,
            error_message: retry_error.message
          )
          return nil
        end
      rescue StandardError => e
        StructuredLogger.exception(e, '[FirebaseAuth] Token verification failed')
        return nil
      end

      unless payload
        StructuredLogger.warn('[FirebaseAuth] Payload is nil after verification')
        return nil
      end

      # Firebase uses 'sub' for user ID, 'user_id' is also included for compatibility
      uid = payload['sub'] || payload['user_id']
      email = payload['email']

      # Find user by firebase_uid or email
      user = User.find_by(firebase_uid: uid) || User.find_by(email: email)

      if user
        # Ensure firebase_uid is set if found by email
        if user.firebase_uid.blank?
          user.update(firebase_uid: uid)
          StructuredLogger.info('[FirebaseAuth] Updated existing user with firebase_uid',
            user_id: user.id,
            email: email
          )
        end
        StructuredLogger.info('[FirebaseAuth] Existing user authenticated',
          user_id: user.id,
          email: email
        )
      else
        # Create new user if not found
        # Use provided website or fall back to Pwb::Current.website or first website
        website = @website || Pwb::Current.website || Website.first

        unless website
          StructuredLogger.error('[FirebaseAuth] No website available for user creation',
            email: email,
            firebase_uid: uid
          )
          return nil
        end

        begin
          user = User.new(
            email: email,
            firebase_uid: uid,
            password: ::Devise.friendly_token[0, 20],
            website: website # Keep for backwards compatibility
          )
          user.save!

          # Create membership for the website
          # Default role is 'member', admin must be granted manually
          UserMembershipService.grant_access(
            user: user,
            website: website,
            role: 'member'
          )

          StructuredLogger.info('[FirebaseAuth] New user created via Firebase',
            user_id: user.id,
            email: email,
            website_id: website.id,
            website_subdomain: website.subdomain
          )
        rescue StandardError => e
          StructuredLogger.exception(e, '[FirebaseAuth] Failed to create new user',
            email: email,
            firebase_uid: uid,
            website_id: website&.id
          )
          return nil
        end
      end

      user
    end
  end
end
