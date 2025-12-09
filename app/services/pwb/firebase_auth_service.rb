module Pwb
  class FirebaseAuthService
    def initialize(token, website: nil)
      @token = token
      @website = website
    end

    def call
      Rails.logger.info "FirebaseAuthService: Starting token verification"
      Rails.logger.debug "FirebaseAuthService: Token length: #{@token&.length || 0}"

      begin
        payload = FirebaseIdToken::Signature.verify(@token)
        Rails.logger.info "FirebaseAuthService: Token verified successfully"
      rescue FirebaseIdToken::Exceptions::NoCertificatesError => e
        # Certificates missing from Redis - fetch them and retry once
        Rails.logger.warn "FirebaseAuthService: No certificates found, fetching from Google..."
        begin
          FirebaseIdToken::Certificates.request!
          payload = FirebaseIdToken::Signature.verify(@token)
          Rails.logger.info "FirebaseAuthService: Token verified after certificate refresh"
        rescue StandardError => retry_error
          Rails.logger.error "FirebaseAuthService: Retry failed - #{retry_error.class}: #{retry_error.message}"
          return nil
        end
      rescue StandardError => e
        Rails.logger.error "FirebaseAuthService: Verification failed - #{e.class}: #{e.message}"
        Rails.logger.error "FirebaseAuthService: Backtrace: #{e.backtrace.first(5).join("\n")}"
        return nil
      end
      
      unless payload
        Rails.logger.warn "FirebaseAuthService: Payload is nil after verification"
        return nil
      end

      uid = payload['user_id']
      email = payload['email']
      
      # Find user by firebase_uid or email
      user = User.find_by(firebase_uid: uid) || User.find_by(email: email)

      if user
        # Ensure firebase_uid is set if found by email
        user.update(firebase_uid: uid) if user.firebase_uid.blank?
      else
        # Create new user if not found
        # Use provided website or fall back to Pwb::Current.website or first website
        website = @website || Pwb::Current.website || Website.first
        
        unless website
          Rails.logger.error "No website available for user creation"
          return nil
        end
        
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
      end
      
      user
    end
  end
end
