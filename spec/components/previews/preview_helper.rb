# frozen_string_literal: true

# Define namespaces for atomic design preview organization
module Atoms; end
module Molecules; end
module Organisms; end
module Templates; end

# Helper module for Lookbook previews
# Provides utilities for theme switching and mock data
module PreviewHelper
  PALETTES = {
    default: {
      "pwb-primary-color" => "#3b82f6",
      "pwb-secondary-color" => "#64748b",
      "pwb-accent-color" => "#f59e0b"
    },
    ocean: {
      "pwb-primary-color" => "#0891b2",
      "pwb-secondary-color" => "#0e7490",
      "pwb-accent-color" => "#06b6d4"
    },
    sunset: {
      "pwb-primary-color" => "#f97316",
      "pwb-secondary-color" => "#ea580c",
      "pwb-accent-color" => "#fbbf24"
    },
    forest: {
      "pwb-primary-color" => "#16a34a",
      "pwb-secondary-color" => "#15803d",
      "pwb-accent-color" => "#84cc16"
    }
  }.freeze

  # Wrap content with CSS custom properties for a specific palette
  def with_palette(palette_name, &block)
    vars = PALETTES[palette_name.to_sym] || PALETTES[:default]
    style = vars.map { |k, v| "--#{k}: #{v}" }.join("; ")

    content_tag(:div, style: style, class: "pwb-preview-wrapper", &block)
  end

  # Create a mock property object for previews
  def mock_property(**overrides)
    defaults = {
      id: 1,
      title: "Luxury Villa with Pool",
      slug: "luxury-villa",
      formatted_price: "€500,000",
      count_bedrooms: 4,
      count_bathrooms: 3,
      count_garages: 2,
      highlighted: false,
      for_sale: true,
      for_rent: false,
      primary_photo_url: "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=640&h=360&fit=crop"
    }

    OpenStruct.new(defaults.merge(overrides)).tap do |p|
      p.define_singleton_method(:highlighted?) { p.highlighted }
      p.define_singleton_method(:for_sale?) { p.for_sale }
      p.define_singleton_method(:for_rent?) { p.for_rent }
    end
  end

  # Create a mock agency/team member for previews
  def mock_team_member(**overrides)
    defaults = {
      id: 1,
      name: "John Smith",
      title: "Senior Property Consultant",
      email: "john.smith@example.com",
      phone: "+1 (555) 123-4567",
      photo_url: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop"
    }

    OpenStruct.new(defaults.merge(overrides))
  end
end
