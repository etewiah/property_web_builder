# frozen_string_literal: true

# Seed data for client themes (A themes)
# These are the Astro-rendered themes for client-mode websites

puts "Seeding client themes..."

Pwb::ClientTheme.find_or_create_by!(name: 'amsterdam') do |theme|
  theme.friendly_name = 'Amsterdam Modern'
  theme.description = 'A clean, modern theme with Dutch-inspired design elements'
  theme.version = '1.0.0'
  theme.default_config = {
    'primary_color' => '#FF6B35',
    'secondary_color' => '#004E89',
    'accent_color' => '#F7C59F',
    'background_color' => '#FFFFFF',
    'text_color' => '#1A1A1A',
    'font_heading' => 'Inter',
    'font_body' => 'Open Sans'
  }
  theme.color_schema = {
    'primary_color' => { 'type' => 'color', 'label' => 'Primary Color', 'default' => '#FF6B35' },
    'secondary_color' => { 'type' => 'color', 'label' => 'Secondary Color', 'default' => '#004E89' },
    'accent_color' => { 'type' => 'color', 'label' => 'Accent Color', 'default' => '#F7C59F' },
    'background_color' => { 'type' => 'color', 'label' => 'Background', 'default' => '#FFFFFF' },
    'text_color' => { 'type' => 'color', 'label' => 'Text Color', 'default' => '#1A1A1A' }
  }
  theme.font_schema = {
    'font_heading' => {
      'type' => 'select',
      'label' => 'Heading Font',
      'options' => %w[Inter Montserrat Playfair\ Display Poppins],
      'default' => 'Inter'
    },
    'font_body' => {
      'type' => 'select',
      'label' => 'Body Font',
      'options' => ['Open Sans', 'Roboto', 'Lato', 'Source Sans Pro'],
      'default' => 'Open Sans'
    }
  }
  theme.layout_options = {
    'header_style' => {
      'type' => 'select',
      'label' => 'Header Style',
      'options' => %w[minimal standard expanded],
      'default' => 'standard'
    }
  }
end

Pwb::ClientTheme.find_or_create_by!(name: 'athens') do |theme|
  theme.friendly_name = 'Athens Classic'
  theme.description = 'An elegant theme inspired by Greek classical architecture'
  theme.version = '1.0.0'
  theme.default_config = {
    'primary_color' => '#1E3A5F',
    'secondary_color' => '#D4AF37',
    'accent_color' => '#F5F5DC',
    'background_color' => '#FAFAFA',
    'text_color' => '#2D2D2D',
    'font_heading' => 'Playfair Display',
    'font_body' => 'Lato'
  }
  theme.color_schema = {
    'primary_color' => { 'type' => 'color', 'label' => 'Primary Color', 'default' => '#1E3A5F' },
    'secondary_color' => { 'type' => 'color', 'label' => 'Secondary Color', 'default' => '#D4AF37' },
    'accent_color' => { 'type' => 'color', 'label' => 'Accent Color', 'default' => '#F5F5DC' },
    'background_color' => { 'type' => 'color', 'label' => 'Background', 'default' => '#FAFAFA' },
    'text_color' => { 'type' => 'color', 'label' => 'Text Color', 'default' => '#2D2D2D' }
  }
  theme.font_schema = {
    'font_heading' => {
      'type' => 'select',
      'label' => 'Heading Font',
      'options' => ['Playfair Display', 'Cormorant Garamond', 'Libre Baskerville'],
      'default' => 'Playfair Display'
    },
    'font_body' => {
      'type' => 'select',
      'label' => 'Body Font',
      'options' => ['Lato', 'Open Sans', 'Source Sans Pro'],
      'default' => 'Lato'
    }
  }
  theme.layout_options = {
    'header_style' => {
      'type' => 'select',
      'label' => 'Header Style',
      'options' => %w[classic centered ornate],
      'default' => 'classic'
    }
  }
end

Pwb::ClientTheme.find_or_create_by!(name: 'austin') do |theme|
  theme.friendly_name = 'Austin Bold'
  theme.description = 'A vibrant, bold theme with Texas-inspired warmth'
  theme.version = '1.0.0'
  theme.default_config = {
    'primary_color' => '#BF5700',
    'secondary_color' => '#333F48',
    'accent_color' => '#F8971F',
    'background_color' => '#FFFFFF',
    'text_color' => '#1C1C1C',
    'font_heading' => 'Montserrat',
    'font_body' => 'Roboto'
  }
  theme.color_schema = {
    'primary_color' => { 'type' => 'color', 'label' => 'Primary Color', 'default' => '#BF5700' },
    'secondary_color' => { 'type' => 'color', 'label' => 'Secondary Color', 'default' => '#333F48' },
    'accent_color' => { 'type' => 'color', 'label' => 'Accent Color', 'default' => '#F8971F' },
    'background_color' => { 'type' => 'color', 'label' => 'Background', 'default' => '#FFFFFF' },
    'text_color' => { 'type' => 'color', 'label' => 'Text Color', 'default' => '#1C1C1C' }
  }
  theme.font_schema = {
    'font_heading' => {
      'type' => 'select',
      'label' => 'Heading Font',
      'options' => %w[Montserrat Oswald Raleway],
      'default' => 'Montserrat'
    },
    'font_body' => {
      'type' => 'select',
      'label' => 'Body Font',
      'options' => %w[Roboto Open\ Sans Nunito],
      'default' => 'Roboto'
    }
  }
  theme.layout_options = {
    'header_style' => {
      'type' => 'select',
      'label' => 'Header Style',
      'options' => %w[bold modern rustic],
      'default' => 'bold'
    }
  }
end

puts "Created #{Pwb::ClientTheme.count} client themes"
