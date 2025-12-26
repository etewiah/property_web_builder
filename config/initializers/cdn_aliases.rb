# frozen_string_literal: true

# CDN Environment Variable Aliases
#
# This initializer provides backward compatibility during the transition
# from old variable names to new, clearer naming conventions.
#
# OLD NAMES (deprecated, still work):
#   R2_PUBLIC_URL     -> CDN for uploaded images
#   ASSET_HOST        -> CDN for static assets
#   R2_BUCKET         -> Bucket for uploads
#   R2_ASSETS_BUCKET  -> Bucket for assets
#
# NEW NAMES (preferred):
#   CDN_IMAGES_URL    -> CDN for uploaded images (property photos, media library)
#   CDN_ASSETS_URL    -> CDN for static assets (JS, CSS, fonts)
#   CDN_IMAGES_BUCKET -> Bucket for uploaded images
#   CDN_ASSETS_BUCKET -> Bucket for static assets
#
# The new naming convention clearly distinguishes:
#   CDN_IMAGES_* -> User-uploaded content
#   CDN_ASSETS_* -> Compiled static files
#   R2_*         -> API credentials only

Rails.application.config.before_configuration do
  # Images CDN (user uploads: property photos, media library)
  ENV["CDN_IMAGES_URL"] ||= ENV["R2_PUBLIC_URL"]
  ENV["CDN_IMAGES_BUCKET"] ||= ENV["R2_BUCKET"]

  # Assets CDN (static files: JS, CSS, fonts, theme images)
  ENV["CDN_ASSETS_URL"] ||= ENV["ASSET_HOST"]
  ENV["CDN_ASSETS_BUCKET"] ||= ENV["R2_ASSETS_BUCKET"]

  # Seed images (development/demo data)
  ENV["CDN_SEED_IMAGES_BUCKET"] ||= ENV["R2_SEED_IMAGES_BUCKET"]
end

# Log deprecation warnings in development
Rails.application.config.after_initialize do
  next unless Rails.env.development?

  deprecated_vars = {
    "R2_PUBLIC_URL" => "CDN_IMAGES_URL",
    "ASSET_HOST" => "CDN_ASSETS_URL",
    "R2_ASSETS_BUCKET" => "CDN_ASSETS_BUCKET"
  }

  deprecated_vars.each do |old_name, new_name|
    if ENV[old_name].present? && ENV[new_name].blank?
      Rails.logger.warn(
        "[DEPRECATION] Environment variable #{old_name} is deprecated. " \
        "Please use #{new_name} instead."
      )
    end
  end
end
