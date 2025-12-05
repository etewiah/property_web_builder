# frozen_string_literal: true

# Configure Liquid template system for PropertyWebBuilder
# This allows templates to use {% include 'partial_name' %} syntax

# Set up file system for Liquid partials
# Partials are stored in app/views/pwb/partials/
# Using Environment.default.file_system to avoid deprecation warning
# (Liquid::Template.file_system= is deprecated in favor of Environment#file_system=)
Liquid::Environment.default.file_system = Liquid::LocalFileSystem.new(
  Rails.root.join("app/views/pwb/partials")
)

# Register custom filters if needed in the future
# Liquid::Template.register_filter(Pwb::LiquidFilters)
