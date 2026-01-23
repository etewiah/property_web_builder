# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_client_themes
# Database name: primary
#
#  id                :bigint           not null, primary key
#  color_schema      :jsonb
#  default_config    :jsonb
#  description       :text
#  enabled           :boolean          default(TRUE), not null
#  font_schema       :jsonb
#  friendly_name     :string           not null
#  layout_options    :jsonb
#  name              :string           not null
#  preview_image_url :string
#  version           :string           default("1.0.0")
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_pwb_client_themes_on_enabled  (enabled)
#  index_pwb_client_themes_on_name     (name) UNIQUE
#
FactoryBot.define do
  factory :pwb_client_theme, class: 'Pwb::ClientTheme' do
    sequence(:name) { |n| "theme_#{n}" }
    sequence(:friendly_name) { |n| "Theme #{n}" }
    version { '1.0.0' }
    description { 'A test theme for client-side rendering' }
    enabled { true }
    default_config do
      {
        'primary_color' => '#FF6B35',
        'secondary_color' => '#004E89',
        'font_heading' => 'Inter',
        'font_body' => 'Open Sans'
      }
    end
    color_schema do
      {
        'primary_color' => { 'type' => 'color', 'label' => 'Primary Color', 'default' => '#FF6B35' },
        'secondary_color' => { 'type' => 'color', 'label' => 'Secondary Color', 'default' => '#004E89' }
      }
    end
    font_schema do
      {
        'font_heading' => {
          'type' => 'select',
          'label' => 'Heading Font',
          'options' => %w[Inter Montserrat Poppins],
          'default' => 'Inter'
        }
      }
    end
    layout_options { {} }

    # Named themes matching seed data
    trait :amsterdam do
      name { 'amsterdam' }
      friendly_name { 'Amsterdam Modern' }
      description { 'A clean, modern theme with Dutch-inspired design elements' }
      default_config do
        {
          'primary_color' => '#FF6B35',
          'secondary_color' => '#004E89',
          'accent_color' => '#F7C59F',
          'font_heading' => 'Inter',
          'font_body' => 'Open Sans'
        }
      end
    end

    trait :athens do
      name { 'athens' }
      friendly_name { 'Athens Classic' }
      description { 'An elegant theme inspired by Greek classical architecture' }
      default_config do
        {
          'primary_color' => '#1E3A5F',
          'secondary_color' => '#D4AF37',
          'font_heading' => 'Playfair Display',
          'font_body' => 'Lato'
        }
      end
    end

    trait :austin do
      name { 'austin' }
      friendly_name { 'Austin Bold' }
      description { 'A vibrant, bold theme with Texas-inspired warmth' }
      default_config do
        {
          'primary_color' => '#BF5700',
          'secondary_color' => '#333F48',
          'font_heading' => 'Montserrat',
          'font_body' => 'Roboto'
        }
      end
    end

    trait :disabled do
      enabled { false }
    end
  end
end
