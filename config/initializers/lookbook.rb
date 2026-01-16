# frozen_string_literal: true

# Lookbook configuration for component previews
# See: https://lookbook.build/guide/configuration

if Rails.env.development?
  # Load preview helper first (defines namespaces like Atoms, Molecules, etc.)
  require Rails.root.join("spec/components/previews/preview_helper")

  preview_path = Rails.root.join("spec/components/previews")

  # Configure ViewComponent preview paths (required for Lookbook to discover previews)
  Rails.application.config.view_component.preview_paths = [preview_path]

  # Configure Lookbook preview paths
  if defined?(Lookbook)
    Lookbook.configure do |config|
      config.preview_paths = [preview_path]
    end
  end
end
