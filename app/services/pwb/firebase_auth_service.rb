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
          website: website
        )
        user.save!
      end
      
      user
    end
  end
end
