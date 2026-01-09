# frozen_string_literal: true

module Pwb
  # Centralized access to Cloudflare R2 configuration.
  #
  # Prefer Rails encrypted credentials, fall back to ENV for backwards compatibility.
  #
  # Expected credentials structure:
  #
  #   r2:
  #     access_key_id: "..."
  #     secret_access_key: "..."
  #     account_id: "..."
  #     bucket: "..."              # uploads/images bucket
  #     public_url: "https://..."   # public CDN/domain for images
  #     assets_bucket: "..."        # optional separate bucket for assets
  #     seed_images_bucket: "..."   # optional bucket for seed images
  #     assets_access_key_id: "..."     # optional separate key for assets
  #     assets_secret_access_key: "..." # optional separate secret for assets
  module R2Credentials
    module_function

    def dig(*keys)
      Rails.application.credentials.dig(:r2, *keys)
    rescue ActiveSupport::EncryptedFile::MissingKeyError,
           ActiveSupport::MessageEncryptor::InvalidMessage,
           NoMethodError
      nil
    end

    def access_key_id
      dig(:access_key_id) || ENV["R2_ACCESS_KEY_ID"]
    end

    def secret_access_key
      dig(:secret_access_key) || ENV["R2_SECRET_ACCESS_KEY"]
    end

    def account_id
      dig(:account_id) || ENV["R2_ACCOUNT_ID"]
    end

    def bucket
      dig(:bucket) || ENV["R2_BUCKET"]
    end

    def public_url
      dig(:public_url) || ENV["R2_PUBLIC_URL"]
    end

    def assets_bucket
      dig(:assets_bucket) || ENV["R2_ASSETS_BUCKET"]
    end

    def seed_images_bucket
      dig(:seed_images_bucket) || ENV["R2_SEED_IMAGES_BUCKET"]
    end

    def assets_access_key_id
      dig(:assets_access_key_id) || ENV["R2_ASSETS_ACCESS_KEY_ID"]
    end

    def assets_secret_access_key
      dig(:assets_secret_access_key) || ENV["R2_ASSETS_SECRET_ACCESS_KEY"]
    end

    def endpoint
      return nil if account_id.blank?

      "https://#{account_id}.r2.cloudflarestorage.com"
    end
  end
end
