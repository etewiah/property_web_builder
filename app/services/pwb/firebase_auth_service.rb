module Pwb
  class FirebaseAuthService
    def initialize(token)
      @token = token
    end

    def call
      payload = FirebaseIdToken::Signature.verify(@token)
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
        user = User.new(
          email: email,
          firebase_uid: uid,
          password: ::Devise.friendly_token[0, 20]
        )
        user.save!
      end
      
      user
    end
  end
end
