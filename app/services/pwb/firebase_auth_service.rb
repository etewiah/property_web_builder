module Pwb
  class FirebaseAuthService
    def initialize(token, website: nil)
      @token = token
      @website = website
    end

    def call
      begin
        payload = FirebaseIdToken::Signature.verify(@token)
      rescue FirebaseIdToken::Exceptions::CertificateException => e
        Rails.logger.error "Firebase certificate error: #{e.message}"
        # Return nil to indicate verification failed
        return nil
      rescue => e
        Rails.logger.error "Firebase verification error: #{e.message}"
        return nil
      end
      
      return nil unless payload

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
