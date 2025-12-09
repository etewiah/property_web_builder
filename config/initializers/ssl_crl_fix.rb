# frozen_string_literal: true

# Fix for SSL certificate verification failures on macOS with Ruby 3.4+ and OpenSSL 3.6+
#
# OpenSSL 3.6 enables CRL (Certificate Revocation List) checking by default,
# but macOS doesn't provide a CRL bundle, causing SSL handshakes to fail with:
#   "certificate verify failed (unable to get certificate CRL)"
#
# This affects connections to S3-compatible services like Cloudflare R2.
#
# See: https://github.com/rails/rails/issues/55886
# See: https://github.com/ruby/openssl/issues/949
#
require 'openssl'

# Remove verify_flags from DEFAULT_PARAMS to prevent CRL checking
if defined?(OpenSSL::SSL::SSLContext::DEFAULT_PARAMS)
  OpenSSL::SSL::SSLContext::DEFAULT_PARAMS.delete(:verify_flags)
end

# Configure AWS SDK for S3-compatible services (Cloudflare R2)
begin
  require 'aws-sdk-s3'

  aws_config = {
    # R2 doesn't support multiple checksums - disable SDK's default checksum behavior
    request_checksum_calculation: 'when_required',
    response_checksum_validation: 'when_required'
  }

  # Skip SSL verification in non-production environments (CRL issue workaround)
  aws_config[:ssl_verify_peer] = false unless Rails.env.production?

  Aws.config.update(aws_config)
rescue LoadError
  # aws-sdk-s3 not installed, skip configuration
end
