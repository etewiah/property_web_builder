# frozen_string_literal: true

# Lookbook configuration for component previews
# See: https://lookbook.build/guide/configuration
#
# NOTE: Configuration must be set via Rails.application.config.lookbook
# BEFORE the app initializes, so Lookbook's engine uses the correct paths.

if Rails.env.development?
  preview_path = Rails.root.join("spec/components/previews").to_s

  Rails.application.configure do
    config.lookbook.preview_paths = [preview_path]

    # Add preview path to view paths so Rails can find preview templates
    config.paths["app/views"].unshift(preview_path)
  end
end
