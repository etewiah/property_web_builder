# frozen_string_literal: true

module Pwb
  # Defines the schema for theme settings that can be customized per website.
  # This schema is used by the admin UI to render appropriate form controls.
  #
  # Field types:
  #   :color       - Color picker (hex value)
  #   :font_select - Font family dropdown
  #   :select      - Single select dropdown
  #   :range       - Slider with min/max/step
  #   :size        - Size input with unit (px, rem, etc.)
  #   :toggle      - Boolean on/off switch
  #   :text        - Single line text input
  #   :textarea    - Multi-line text input
  #
  class ThemeSettingsSchema
    SCHEMA = {
      # ===== Colors Section =====
      colors: {
        label: 'Colors',
        icon: 'palette',
        fields: {
          primary_color: {
            type: :color,
            label: 'Primary Color',
            description: 'Main brand color used for buttons, links, and accents',
            default: '#e91b23'
          },
          secondary_color: {
            type: :color,
            label: 'Secondary Color',
            description: 'Supporting color for secondary elements',
            default: '#3498db'
          },
          accent_color: {
            type: :color,
            label: 'Accent Color',
            description: 'Highlight color for special elements',
            default: '#27ae60'
          },
          bg_light: {
            type: :color,
            label: 'Light Background',
            description: 'Background for light sections',
            default: '#f8f9fa'
          },
          text_primary: {
            type: :color,
            label: 'Primary Text',
            description: 'Main text color',
            default: '#212529'
          },
          text_secondary: {
            type: :color,
            label: 'Secondary Text',
            description: 'Muted text color',
            default: '#6c757d'
          }
        }
      },

      # ===== Footer Section =====
      footer: {
        label: 'Footer',
        icon: 'footer',
        fields: {
          footer_bg_color: {
            type: :color,
            label: 'Footer Background',
            description: 'Background color for the footer',
            default: '#2c3e50'
          },
          footer_main_text_color: {
            type: :color,
            label: 'Footer Text',
            description: 'Text color in the footer',
            default: '#ffffff'
          },
          footer_link_color: {
            type: :color,
            label: 'Footer Links',
            description: 'Link color in the footer',
            default: '#3498db'
          }
        }
      },

      # ===== Typography Section =====
      typography: {
        label: 'Typography',
        icon: 'text',
        fields: {
          font_primary: {
            type: :font_select,
            label: 'Heading Font',
            description: 'Font family for headings and titles',
            default: 'Inter, system-ui, sans-serif',
            options: [
              { value: 'Inter, system-ui, sans-serif', label: 'Inter' },
              { value: 'Open Sans, sans-serif', label: 'Open Sans' },
              { value: 'Roboto, sans-serif', label: 'Roboto' },
              { value: 'Lato, sans-serif', label: 'Lato' },
              { value: 'Montserrat, sans-serif', label: 'Montserrat' },
              { value: 'Poppins, sans-serif', label: 'Poppins' },
              { value: 'Playfair Display, serif', label: 'Playfair Display' },
              { value: 'Merriweather, serif', label: 'Merriweather' }
            ]
          },
          font_secondary: {
            type: :font_select,
            label: 'Body Font',
            description: 'Font family for body text',
            default: 'Georgia, serif',
            options: [
              { value: 'Georgia, serif', label: 'Georgia' },
              { value: 'Inter, system-ui, sans-serif', label: 'Inter' },
              { value: 'Open Sans, sans-serif', label: 'Open Sans' },
              { value: 'Roboto, sans-serif', label: 'Roboto' },
              { value: 'Lato, sans-serif', label: 'Lato' },
              { value: 'Source Sans Pro, sans-serif', label: 'Source Sans Pro' },
              { value: 'Merriweather, serif', label: 'Merriweather' },
              { value: 'Vollkorn, serif', label: 'Vollkorn' }
            ]
          },
          font_size_base: {
            type: :range,
            label: 'Base Font Size',
            description: 'Default font size for body text',
            default: '16px',
            min: 14,
            max: 20,
            step: 1,
            unit: 'px'
          },
          line_height_base: {
            type: :range,
            label: 'Line Height',
            description: 'Spacing between lines of text',
            default: '1.6',
            min: 1.2,
            max: 2.0,
            step: 0.1
          }
        }
      },

      # ===== Layout Section =====
      layout: {
        label: 'Layout',
        icon: 'layout',
        fields: {
          container_max_width: {
            type: :select,
            label: 'Container Width',
            description: 'Maximum width of the main content area',
            default: '1200px',
            options: [
              { value: '960px', label: 'Narrow (960px)' },
              { value: '1140px', label: 'Medium (1140px)' },
              { value: '1200px', label: 'Standard (1200px)' },
              { value: '1400px', label: 'Wide (1400px)' },
              { value: '100%', label: 'Full Width' }
            ]
          },
          container_padding: {
            type: :range,
            label: 'Container Padding',
            description: 'Horizontal padding inside containers',
            default: '1rem',
            min: 0.5,
            max: 3,
            step: 0.25,
            unit: 'rem'
          },
          spacing_unit: {
            type: :range,
            label: 'Spacing Unit',
            description: 'Base unit for spacing calculations',
            default: '1rem',
            min: 0.5,
            max: 1.5,
            step: 0.125,
            unit: 'rem'
          }
        }
      },

      # ===== Appearance Section =====
      appearance: {
        label: 'Appearance',
        icon: 'appearance',
        fields: {
          border_radius: {
            type: :range,
            label: 'Border Radius',
            description: 'Roundness of corners on cards and buttons',
            default: '0.5rem',
            min: 0,
            max: 2,
            step: 0.125,
            unit: 'rem'
          },
          shadow_intensity: {
            type: :select,
            label: 'Shadow Intensity',
            description: 'How prominent shadows appear',
            default: 'normal',
            options: [
              { value: 'none', label: 'None' },
              { value: 'subtle', label: 'Subtle' },
              { value: 'normal', label: 'Normal' },
              { value: 'strong', label: 'Strong' }
            ]
          },
          color_scheme: {
            type: :select,
            label: 'Color Scheme',
            description: 'Light or dark mode preference',
            default: 'light',
            options: [
              { value: 'light', label: 'Light' },
              { value: 'dark', label: 'Dark' },
              { value: 'auto', label: 'Auto (follows system)' }
            ]
          }
        }
      },

      # ===== Buttons Section =====
      buttons: {
        label: 'Buttons',
        icon: 'button',
        fields: {
          button_style: {
            type: :select,
            label: 'Button Style',
            description: 'Default appearance of buttons',
            default: 'solid',
            options: [
              { value: 'solid', label: 'Solid' },
              { value: 'outline', label: 'Outline' },
              { value: 'soft', label: 'Soft' }
            ]
          },
          button_radius: {
            type: :select,
            label: 'Button Roundness',
            description: 'How rounded button corners appear',
            default: 'default',
            options: [
              { value: 'none', label: 'Square' },
              { value: 'sm', label: 'Slightly Rounded' },
              { value: 'default', label: 'Rounded' },
              { value: 'lg', label: 'Very Rounded' },
              { value: 'full', label: 'Pill Shaped' }
            ]
          }
        }
      },

      # ===== Header Section =====
      header: {
        label: 'Header',
        icon: 'header',
        fields: {
          header_style: {
            type: :select,
            label: 'Header Style',
            description: 'How the header appears',
            default: 'solid',
            options: [
              { value: 'solid', label: 'Solid Background' },
              { value: 'transparent', label: 'Transparent' },
              { value: 'sticky', label: 'Sticky on Scroll' }
            ]
          },
          header_bg_color: {
            type: :color,
            label: 'Header Background',
            description: 'Background color of the header',
            default: '#ffffff'
          },
          header_text_color: {
            type: :color,
            label: 'Header Text',
            description: 'Text color in the header',
            default: '#212529'
          }
        }
      }
    }.freeze

    class << self
      def schema
        SCHEMA
      end

      def sections
        SCHEMA.keys
      end

      def section(name)
        SCHEMA[name.to_sym]
      end

      def field(section_name, field_name)
        section(section_name)&.dig(:fields, field_name.to_sym)
      end

      def all_fields
        SCHEMA.flat_map do |section_name, section|
          section[:fields].map do |field_name, field_config|
            field_config.merge(
              name: field_name,
              section: section_name
            )
          end
        end
      end

      def defaults
        all_fields.each_with_object({}) do |field, hash|
          hash[field[:name].to_s] = field[:default]
        end
      end

      # Generate JSON schema for frontend consumption
      def to_json_schema
        {
          sections: SCHEMA.map do |section_name, section|
            {
              name: section_name,
              label: section[:label],
              icon: section[:icon],
              fields: section[:fields].map do |field_name, field_config|
                field_config.merge(name: field_name)
              end
            }
          end
        }
      end

      # Validate style variables against schema
      def validate(style_variables)
        errors = []

        style_variables.each do |key, value|
          field = all_fields.find { |f| f[:name].to_s == key.to_s }
          next unless field

          case field[:type]
          when :color
            unless value.match?(/^#[0-9A-Fa-f]{6}$/)
              errors << "#{key}: Invalid color format (expected hex like #RRGGBB)"
            end
          when :range
            num_value = value.to_s.gsub(/[^0-9.]/, '').to_f
            if field[:min] && num_value < field[:min]
              errors << "#{key}: Value #{num_value} is below minimum #{field[:min]}"
            end
            if field[:max] && num_value > field[:max]
              errors << "#{key}: Value #{num_value} is above maximum #{field[:max]}"
            end
          when :select, :font_select
            valid_values = field[:options].map { |o| o[:value] }
            unless valid_values.include?(value)
              errors << "#{key}: Invalid option '#{value}'"
            end
          end
        end

        errors
      end
    end
  end
end
