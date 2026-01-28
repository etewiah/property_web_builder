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

# Load custom Liquid tags and filters for PropertyWebBuilder
Rails.application.config.to_prepare do
  # Load filters
  require Rails.root.join("app/lib/pwb/liquid_filters")

  # Load tag class definitions
  Dir[Rails.root.join("app/lib/pwb/liquid_tags/*.rb")].each { |f| require f }

  # Register filters globally on the default environment
  # Provides: localize_url - prepends locale to URL paths
  Liquid::Environment.default.register_filter(Pwb::LiquidFilters)

  # Register tags on the default environment (not Template which is deprecated)
  # This prevents: "Template.register_tag is deprecated. Use Environment#register_tag instead"
  env = Liquid::Environment.default
  env.register_tag("contact_form", Pwb::LiquidTags::ContactFormTag)
  env.register_tag("property_card", Pwb::LiquidTags::PropertyCardTag)
  env.register_tag("featured_properties", Pwb::LiquidTags::FeaturedPropertiesTag)
  env.register_tag("page_part", Pwb::LiquidTags::PagePartTag)
  env.register_tag("render_slot", Pwb::LiquidTags::RenderSlotTag)
end
