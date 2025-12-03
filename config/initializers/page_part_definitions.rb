# frozen_string_literal: true

# This is an example of how to define page parts using the Ruby DSL
# Uncomment and modify as needed

# Pwb::PagePartDefinition.define :landing_hero do
#   field :landing_title_a, type: :single_line_text, label: "Hero Title"
#   field :landing_content_a, type: :html, label: "Hero Description"
#   field :landing_img, type: :image, label: "Background Image"
# end

# Pwb::PagePartDefinition.define :our_agency do
#   field :agency_title, type: :single_line_text, label: "Agency Title"
#   field :agency_description, type: :html, label: "Agency Description"
#   field :agency_image, type: :image, label: "Agency Photo"
# end

# Pwb::PagePartDefinition.define :about_us_services do
#   field :services_title, type: :single_line_text, label: "Services Title"
#   field :services_description, type: :html, label: "Services Description"
# end

# To use these definitions:
# 1. Uncomment the definitions you want to use
# 2. Ensure the field names match the variables used in your .liquid templates
# 3. The definitions will be validated against templates on startup
# 4. Use Pwb::PagePartRegistry.find(:landing_hero) to access definitions programmatically
