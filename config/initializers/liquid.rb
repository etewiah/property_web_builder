# frozen_string_literal: true

# Configure Liquid template system for PropertyWebBuilder
# This allows templates to use {% include 'partial_name' %} syntax

# Set up file system for Liquid partials
# Partials are stored in app/views/pwb/partials/
Liquid::Template.file_system = Liquid::LocalFileSystem.new(
  Rails.root.join("app/views/pwb/partials")
)

# Register custom filters if needed in the future
# Liquid::Template.register_filter(Pwb::LiquidFilters)
