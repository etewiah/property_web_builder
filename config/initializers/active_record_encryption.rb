# frozen_string_literal: true

# Configure Active Record Encryption for development and test environments.
# Production should use credentials stored in Rails credentials.
#
# To set up production encryption keys:
#   rails secret (run 3 times)
#   rails credentials:edit --environment production
#   Add:
#     active_record_encryption:
#       primary_key: <32 byte key>
#       deterministic_key: <32 byte key>
#       key_derivation_salt: <32 byte salt>

unless Rails.env.production?
  # Use deterministic keys for development/test to avoid credential setup
  # IMPORTANT: These keys are for development only. Never use in production!
  Rails.application.config.active_record.encryption.primary_key = 'dev_primary_key_32_bytes_long_x'
  Rails.application.config.active_record.encryption.deterministic_key = 'dev_deterministic_key_32_bytesX'
  Rails.application.config.active_record.encryption.key_derivation_salt = 'dev_salt_32_bytes_long_xxxxxxx'
end
