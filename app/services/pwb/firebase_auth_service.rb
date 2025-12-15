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

        # Check if website is locked_pending_registration - only owner can sign up
        if website.locked_pending_registration?
          unless email.downcase == website.owner_email&.downcase
            StructuredLogger.warn('[FirebaseAuth] Non-owner email attempted signup on locked website',
              email: email,
              owner_email: website.owner_email,
              website_id: website.id,
              website_subdomain: website.subdomain
            )
            raise StandardError, "Only the verified owner email (#{website.owner_email}) can create an account for this website."
          end
        end

        begin
          user = User.new(
            email: email,
            firebase_uid: uid,
            password: ::Devise.friendly_token[0, 20],
            website: website # Keep for backwards compatibility
          )
          user.save!

          # Determine role based on website state
          # If website is locked_pending_registration and this is the owner, grant admin
          # Otherwise, grant member role (admin must be granted manually)
          if website.locked_pending_registration? && email.downcase == website.owner_email&.downcase
            role = 'admin'
            StructuredLogger.info('[FirebaseAuth] Granting admin role to website owner',
              user_id: user.id,
              email: email,
              website_id: website.id
            )

            # Transition website to live state
            if website.may_complete_owner_registration?
              website.complete_owner_registration!
              StructuredLogger.info('[FirebaseAuth] Website transitioned to live state',
                website_id: website.id,
                website_subdomain: website.subdomain
              )
            end
          else
            role = 'member'
          end

          # Create membership for the website
          UserMembershipService.grant_access(
            user: user,
            website: website,
            role: role
          )

          StructuredLogger.info('[FirebaseAuth] New user created via Firebase',
            user_id: user.id,
            email: email,
            website_id: website.id,
            website_subdomain: website.subdomain,
            role: role
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
