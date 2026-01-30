# frozen_string_literal: true

module Pwb
  # Registry of available page part templates.
  # Scans the page_parts directory to discover available templates.
  #
  class PagePartLibrary
    # Categories of page parts
    CATEGORIES = {
      heroes: {
        label: 'Hero Sections',
        description: 'Large banner sections typically used at the top of pages',
        icon: 'hero'
      },
      features: {
        label: 'Features',
        description: 'Sections showcasing features, services, or benefits',
        icon: 'grid'
      },
      testimonials: {
        label: 'Testimonials',
        description: 'Customer reviews and testimonials',
        icon: 'quote'
      },
      cta: {
        label: 'Call to Action',
        description: 'Sections designed to encourage user action',
        icon: 'megaphone'
      },
      stats: {
        label: 'Statistics',
        description: 'Number counters and statistics displays',
        icon: 'chart'
      },
      teams: {
        label: 'Team',
        description: 'Team member profiles and listings',
        icon: 'users'
      },
      galleries: {
        label: 'Galleries',
        description: 'Image galleries and portfolios',
        icon: 'image'
      },
      pricing: {
        label: 'Pricing',
        description: 'Pricing tables and plan comparisons',
        icon: 'tag'
      },
      faqs: {
        label: 'FAQs',
        description: 'Frequently asked questions sections',
        icon: 'help'
      },
      content: {
        label: 'Content',
        description: 'General content sections',
        icon: 'text'
      },
      contact: {
        label: 'Contact',
        description: 'Contact forms and information',
        icon: 'mail'
      },
      layout: {
        label: 'Layout Containers',
        description: 'Containers for arranging page parts side-by-side',
        icon: 'layout'
      }
    }.freeze

    # Page part definitions with metadata
    # Fields can be either:
    # - Array of field names (legacy format, types inferred from names)
    # - Hash of field definitions (modern format, explicit types and metadata)
    DEFINITIONS = {
      # Heroes
      'heroes/hero_centered' => {
        category: :heroes,
        label: 'Centered Hero',
        description: 'Full-width hero with centered content and optional CTA buttons',
        fields: {
          pretitle: {
            type: :text,
            label: 'Pre-title',
            hint: 'Small text displayed above the main title',
            placeholder: 'e.g., Welcome to',
            max_length: 50,
            group: :titles
          },
          title: {
            type: :text,
            label: 'Main Title',
            hint: 'The primary headline for this hero section',
            required: true,
            max_length: 80,
            content_guidance: {
              recommended_length: '40-60 characters',
              seo_tip: 'Include your primary keyword naturally'
            },
            group: :titles
          },
          subtitle: {
            type: :textarea,
            label: 'Subtitle',
            hint: 'Supporting text below the main title',
            max_length: 200,
            rows: 2,
            content_guidance: {
              recommended_length: '80-150 characters',
              best_practice: 'Expand on the title with a clear value proposition'
            },
            group: :titles
          },
          cta_text: {
            type: :text,
            label: 'Primary Button Text',
            hint: 'Text for the main call-to-action button',
            placeholder: 'e.g., Get Started',
            max_length: 30,
            content_guidance: {
              recommended_length: '2-4 words',
              best_practice: 'Use action verbs like "Get", "Start", "Discover"'
            },
            group: :cta,
            paired_with: :cta_link
          },
          cta_link: {
            type: :url,
            label: 'Primary Button Link',
            hint: 'URL for the primary button',
            placeholder: '/contact or https://...',
            group: :cta,
            paired_with: :cta_text
          },
          cta_secondary_text: {
            type: :text,
            label: 'Secondary Button Text',
            hint: 'Text for the secondary button (optional)',
            placeholder: 'e.g., Learn More',
            max_length: 30,
            group: :cta,
            paired_with: :cta_secondary_link
          },
          cta_secondary_link: {
            type: :url,
            label: 'Secondary Button Link',
            hint: 'URL for the secondary button',
            placeholder: '/about or https://...',
            group: :cta,
            paired_with: :cta_secondary_text
          },
          background_image: {
            type: :image,
            component: 'ImageBlockPicker',
            label: 'Background Image',
            hint: 'Full-width background image for the hero',
            required: true,
            aspect_ratio: '16:9',
            recommended_size: '1920x1080',
            content_guidance: {
              best_practice: 'Use a high-quality image that complements your text',
              seo_tip: 'Optimize image size for fast loading (under 500KB ideal)'
            },
            group: :media
          }
        },
        field_groups: {
          titles: { label: 'Titles & Text', order: 1 },
          cta: { label: 'Call to Action Buttons', order: 2 },
          media: { label: 'Media', order: 3 }
        }
      },
      'heroes/hero_split' => {
        category: :heroes,
        label: 'Split Hero',
        description: 'Two-column hero with content on one side and image on the other',
        fields: %w[pretitle title subtitle description cta_text cta_link cta_secondary_text cta_secondary_link image image_alt]
      },
      'heroes/hero_search' => {
        category: :heroes,
        label: 'Hero with Search',
        description: 'Hero section with integrated property search form',
        fields: %w[title subtitle background_image search_action label_buy label_rent placeholder_location label_all_types button_text]
      },

      # Features
      'features/feature_grid_3col' => {
        category: :features,
        label: '3-Column Feature Grid',
        description: 'Three feature cards in a grid layout',
        fields: %w[section_pretitle section_title section_subtitle feature_1_icon feature_1_title feature_1_description feature_1_link feature_2_icon feature_2_title feature_2_description feature_3_icon feature_3_title feature_3_description]
      },
      'features/feature_cards_icons' => {
        category: :features,
        label: '4-Column Icon Cards',
        description: 'Four icon cards with colored backgrounds',
        fields: %w[section_title section_subtitle card_1_icon card_1_title card_1_text card_1_color card_2_icon card_2_title card_2_text card_3_icon card_3_title card_3_text card_4_icon card_4_title card_4_text]
      },

      # Testimonials
      'testimonials/testimonial_carousel' => {
        category: :testimonials,
        label: 'Testimonial Carousel',
        description: 'Sliding carousel of customer testimonials',
        fields: %w[section_title section_subtitle testimonial_1_text testimonial_1_name testimonial_1_role testimonial_1_image testimonial_2_text testimonial_2_name testimonial_2_role testimonial_2_image testimonial_3_text testimonial_3_name testimonial_3_role testimonial_3_image]
      },
      'testimonials/testimonial_grid' => {
        category: :testimonials,
        label: 'Testimonial Grid',
        description: 'Grid of testimonial cards with ratings',
        fields: %w[section_title section_subtitle testimonial_1_text testimonial_1_name testimonial_1_role testimonial_1_image testimonial_2_text testimonial_2_name testimonial_2_role testimonial_2_image testimonial_3_text testimonial_3_name testimonial_3_role testimonial_3_image]
      },

      # CTA
      'cta/cta_banner' => {
        category: :cta,
        label: 'CTA Banner',
        description: 'Full-width call-to-action banner',
        fields: {
          title: {
            type: :text,
            label: 'Title',
            hint: 'The main headline for this CTA',
            required: true,
            max_length: 80,
            group: :content
          },
          subtitle: {
            type: :textarea,
            label: 'Subtitle',
            hint: 'Supporting text below the title',
            max_length: 200,
            rows: 2,
            group: :content
          },
          button_text: {
            type: :text,
            label: 'Primary Button Text',
            hint: 'Text for the main action button',
            placeholder: 'e.g., Get Started',
            max_length: 30,
            group: :buttons,
            paired_with: :button_link
          },
          button_link: {
            type: :url,
            label: 'Primary Button Link',
            hint: 'URL for the primary button',
            group: :buttons,
            paired_with: :button_text
          },
          button_style: {
            type: :select,
            label: 'Primary Button Style',
            hint: 'Visual style for the primary button',
            choices: [
              { value: 'primary', label: 'Primary (Filled)' },
              { value: 'secondary', label: 'Secondary (Outline)' },
              { value: 'white', label: 'White' },
              { value: 'dark', label: 'Dark' }
            ],
            default: 'primary',
            group: :buttons
          },
          secondary_button_text: {
            type: :text,
            label: 'Secondary Button Text',
            hint: 'Text for the secondary button (optional)',
            max_length: 30,
            group: :buttons,
            paired_with: :secondary_button_link
          },
          secondary_button_link: {
            type: :url,
            label: 'Secondary Button Link',
            hint: 'URL for the secondary button',
            group: :buttons,
            paired_with: :secondary_button_text
          },
          style: {
            type: :select,
            label: 'Banner Style',
            hint: 'Visual style for the banner background',
            choices: [
              { value: 'light', label: 'Light Background' },
              { value: 'dark', label: 'Dark Background' },
              { value: 'primary', label: 'Primary Color' },
              { value: 'gradient', label: 'Gradient' }
            ],
            default: 'primary',
            group: :style
          }
        },
        field_groups: {
          content: { label: 'Content', order: 1 },
          buttons: { label: 'Buttons', order: 2 },
          style: { label: 'Appearance', order: 3 }
        }
      },
      'cta/cta_split_image' => {
        category: :cta,
        label: 'CTA with Image',
        description: 'Split CTA with image on one side',
        fields: %w[pretitle title description features button_text button_link image bg_style]
      },

      # Stats
      'stats/stats_counter' => {
        category: :stats,
        label: 'Stats Counter',
        description: 'Animated number counters for statistics',
        fields: %w[section_title section_subtitle stat_1_value stat_1_label stat_1_prefix stat_1_suffix stat_2_value stat_2_label stat_3_value stat_3_label stat_4_value stat_4_label style]
      },

      # Teams
      'teams/team_grid' => {
        category: :teams,
        label: 'Team Grid',
        description: 'Grid of team member cards with social links',
        fields: %w[section_title section_subtitle member_1_name member_1_role member_1_image member_1_bio member_1_linkedin member_1_email member_2_name member_2_role member_2_image member_2_bio member_3_name member_3_role member_3_image member_3_bio member_4_name member_4_role member_4_image member_4_bio]
      },

      # Galleries
      'galleries/image_gallery' => {
        category: :galleries,
        label: 'Image Gallery',
        description: 'Grid gallery with lightbox support',
        fields: %w[section_title section_subtitle columns image_1 caption_1 image_2 caption_2 image_3 caption_3 image_4 caption_4 image_5 caption_5 image_6 caption_6]
      },

      # Pricing
      'pricing/pricing_table' => {
        category: :pricing,
        label: 'Pricing Table',
        description: 'Three-column pricing comparison table',
        fields: %w[section_title section_subtitle plan_1_name plan_1_price plan_1_currency plan_1_period plan_1_description plan_1_features plan_1_button plan_1_link plan_2_name plan_2_price plan_2_badge plan_2_features plan_2_button plan_3_name plan_3_price plan_3_features plan_3_button]
      },

      # FAQs
      'faqs/faq_accordion' => {
        category: :faqs,
        label: 'FAQ Accordion',
        description: 'Expandable FAQ section',
        fields: {
          section_title: {
            type: :text,
            label: 'Section Title',
            hint: 'Title displayed above the FAQ list',
            placeholder: 'e.g., Frequently Asked Questions',
            max_length: 80,
            group: :header
          },
          section_subtitle: {
            type: :textarea,
            label: 'Section Subtitle',
            hint: 'Optional description below the title',
            max_length: 200,
            rows: 2,
            group: :header
          },
          faq_items: {
            type: :faq_array,
            label: 'FAQ Items',
            hint: 'Add questions and answers',
            required: true,
            min_items: 1,
            max_items: 20,
            item_schema: {
              question: {
                type: :text,
                label: 'Question',
                required: true,
                max_length: 200,
                content_guidance: {
                  best_practice: 'Start with "How", "What", "Why", "When", or "Can"'
                }
              },
              answer: {
                type: :textarea,
                label: 'Answer',
                required: true,
                max_length: 2000,
                rows: 4,
                content_guidance: {
                  recommended_length: '50-300 characters',
                  best_practice: 'Be concise and direct. Use bullet points for complex answers.'
                }
              }
            },
            group: :faqs,
            content_guidance: {
              best_practice: 'Include 5-10 of your most commonly asked questions',
              seo_tip: 'FAQ content can appear as rich snippets in search results'
            }
          }
        },
        field_groups: {
          header: { label: 'Section Header', order: 1 },
          faqs: { label: 'Questions & Answers', order: 2 }
        }
      },

      # Legacy page parts (from original system)
      'our_agency' => {
        category: :content,
        label: 'Our Agency',
        description: 'Agency introduction section',
        fields: %w[title_a content_a our_agency_img],
        legacy: true
      },
      'about_us_services' => {
        category: :features,
        label: 'About Us Services',
        description: 'Three-column services section',
        fields: %w[title_a content_a title_b content_b title_c content_c],
        legacy: true
      },
      'content_html' => {
        category: :content,
        label: 'HTML Content',
        description: 'Free-form HTML content section',
        fields: {
          content_html: {
            type: :html,
            label: 'Content',
            hint: 'The main HTML content for this section',
            required: true,
            max_length: 50_000,
            content_guidance: {
              recommended_length: '500-2000 characters',
              best_practice: 'Use headings (H2, H3) to structure long content for better readability',
              seo_tip: 'Break up text with subheadings and bullet points for better SEO'
            }
          }
        },
        legacy: true
      },
      'footer_content_html' => {
        category: :content,
        label: 'Footer Content',
        description: 'Footer HTML content',
        fields: %w[content_html],
        legacy: true
      },
      'footer_social_links' => {
        category: :content,
        label: 'Social Links',
        description: 'Social media links',
        fields: %w[facebook twitter instagram linkedin youtube],
        legacy: true
      },
      'form_and_map' => {
        category: :contact,
        label: 'Contact Form & Map',
        description: 'Contact form with embedded map',
        fields: %w[title map_embed],
        legacy: true
      },
      'search_cmpt' => {
        category: :content,
        label: 'Search Component',
        description: 'Property search component',
        fields: [],
        legacy: true
      },

      # Contact Form Page Parts
      # Modern configurable forms using URL-safe naming convention: {category}_{purpose}_{variant}
      'contact_general_enquiry' => {
        category: :contact,
        label: 'General Contact Form',
        description: 'Configurable contact form for general enquiries',
        fields: {
          section_title: {
            type: :text,
            label: 'Section Title',
            hint: 'Title displayed above the form',
            placeholder: 'Contact Us',
            max_length: 80,
            group: :header
          },
          section_subtitle: {
            type: :textarea,
            label: 'Section Description',
            hint: 'Optional description below the title',
            max_length: 200,
            rows: 2,
            group: :header
          },
          show_phone_field: {
            type: :boolean,
            label: 'Show Phone Field',
            hint: 'Display phone number input',
            default: true,
            group: :form_config
          },
          show_subject_field: {
            type: :boolean,
            label: 'Show Subject Field',
            hint: 'Display subject line input',
            default: true,
            group: :form_config
          },
          submit_button_text: {
            type: :text,
            label: 'Submit Button Text',
            placeholder: 'Send Message',
            max_length: 30,
            group: :form_config
          },
          form_style: {
            type: :select,
            label: 'Form Style',
            hint: 'Visual appearance of the form',
            choices: [
              { value: 'default', label: 'Default (Border)' },
              { value: 'shadowed', label: 'Shadowed' },
              { value: 'minimal', label: 'Minimal' }
            ],
            default: 'default',
            group: :form_config
          },
          success_message: {
            type: :textarea,
            label: 'Success Message',
            hint: 'Message shown after successful submission',
            placeholder: 'Thank you! We will get back to you soon.',
            max_length: 200,
            group: :messages
          }
        },
        field_groups: {
          header: { label: 'Section Header', order: 1 },
          form_config: { label: 'Form Settings', order: 2 },
          messages: { label: 'Messages', order: 3 }
        }
      },
      'contact_location_map' => {
        category: :contact,
        label: 'Contact Form with Map',
        description: 'Two-column layout with contact form and location map',
        fields: {
          section_title: {
            type: :text,
            label: 'Section Title',
            hint: 'Title displayed above the section',
            placeholder: 'Get in Touch',
            max_length: 80,
            group: :header
          },
          section_subtitle: {
            type: :textarea,
            label: 'Section Description',
            hint: 'Optional description below the title',
            max_length: 200,
            rows: 2,
            group: :header
          },
          form_title: {
            type: :text,
            label: 'Form Column Title',
            placeholder: 'Send us a message',
            max_length: 60,
            group: :form_config
          },
          show_phone_field: {
            type: :boolean,
            label: 'Show Phone Field',
            default: true,
            group: :form_config
          },
          show_subject_field: {
            type: :boolean,
            label: 'Show Subject Field',
            default: false,
            group: :form_config
          },
          submit_button_text: {
            type: :text,
            label: 'Submit Button Text',
            placeholder: 'Send Message',
            max_length: 30,
            group: :form_config
          },
          success_message: {
            type: :textarea,
            label: 'Success Message',
            placeholder: 'Thank you! We will get back to you soon.',
            max_length: 200,
            group: :form_config
          },
          map_title: {
            type: :text,
            label: 'Map Column Title',
            placeholder: 'Our Location',
            max_length: 60,
            group: :map_config
          },
          map_latitude: {
            type: :text,
            label: 'Latitude',
            hint: 'Map center latitude (e.g., 40.7128)',
            placeholder: '40.7128',
            group: :map_config
          },
          map_longitude: {
            type: :text,
            label: 'Longitude',
            hint: 'Map center longitude (e.g., -74.0060)',
            placeholder: '-74.0060',
            group: :map_config
          },
          map_zoom: {
            type: :number,
            label: 'Map Zoom Level',
            hint: 'Zoom level (1-18, default 14)',
            default: 14,
            min: 1,
            max: 18,
            group: :map_config
          },
          marker_title: {
            type: :text,
            label: 'Marker Title',
            hint: 'Text shown when clicking the map marker',
            placeholder: 'Our Office',
            max_length: 60,
            group: :map_config
          },
          show_contact_info: {
            type: :boolean,
            label: 'Show Contact Info',
            hint: 'Display address, phone, email below map',
            default: true,
            group: :contact_info
          },
          address: {
            type: :textarea,
            label: 'Address',
            hint: 'Physical address displayed below map',
            rows: 2,
            group: :contact_info
          },
          phone: {
            type: :text,
            label: 'Phone Number',
            group: :contact_info
          },
          email: {
            type: :email,
            label: 'Email Address',
            group: :contact_info
          }
        },
        field_groups: {
          header: { label: 'Section Header', order: 1 },
          form_config: { label: 'Form Settings', order: 2 },
          map_config: { label: 'Map Settings', order: 3 },
          contact_info: { label: 'Contact Information', order: 4 }
        }
      },

      # Layout Containers - for composable side-by-side layouts
      # Containers have is_container: true and define named slots
      # Keys use path format (layout/xxx) to match template location
      'layout/layout_two_column_equal' => {
        category: :layout,
        label: 'Two Column (50/50)',
        description: 'Two equal-width columns for side-by-side content',
        is_container: true,
        fields: {},
        slots: {
          left: {
            label: 'Left Column',
            description: 'Content for the left column',
            width: '50%'
          },
          right: {
            label: 'Right Column',
            description: 'Content for the right column',
            width: '50%'
          }
        }
      },
      'layout/layout_two_column_wide_narrow' => {
        category: :layout,
        label: 'Two Column (67/33)',
        description: 'Two columns with wider left column',
        is_container: true,
        fields: {},
        slots: {
          left: {
            label: 'Main Column',
            description: 'Content for the wider left column',
            width: '67%'
          },
          right: {
            label: 'Side Column',
            description: 'Content for the narrower right column',
            width: '33%'
          }
        }
      },
      'layout/layout_sidebar_left' => {
        category: :layout,
        label: 'Sidebar Left (25/75)',
        description: 'Sidebar on left with main content on right',
        is_container: true,
        fields: {},
        slots: {
          sidebar: {
            label: 'Sidebar',
            description: 'Content for the left sidebar',
            width: '25%'
          },
          main: {
            label: 'Main Content',
            description: 'Primary content area',
            width: '75%'
          }
        }
      },
      'layout/layout_sidebar_right' => {
        category: :layout,
        label: 'Sidebar Right (75/25)',
        description: 'Main content on left with sidebar on right',
        is_container: true,
        fields: {},
        slots: {
          main: {
            label: 'Main Content',
            description: 'Primary content area',
            width: '75%'
          },
          sidebar: {
            label: 'Sidebar',
            description: 'Content for the right sidebar',
            width: '25%'
          }
        }
      },
      'layout/layout_three_column_equal' => {
        category: :layout,
        label: 'Three Column (33/33/33)',
        description: 'Three equal-width columns',
        is_container: true,
        fields: {},
        slots: {
          left: {
            label: 'Left Column',
            description: 'Content for the left column',
            width: '33.33%'
          },
          center: {
            label: 'Center Column',
            description: 'Content for the center column',
            width: '33.33%'
          },
          right: {
            label: 'Right Column',
            description: 'Content for the right column',
            width: '33.33%'
          }
        }
      }
    }.freeze

    class << self
      # Get all page part keys
      # @return [Array<String>]
      def all_keys
        DEFINITIONS.keys
      end

      # Get all page parts grouped by category
      # @return [Hash]
      def by_category
        DEFINITIONS.group_by { |_key, config| config[:category] }
                   .transform_values { |items| items.to_h }
      end

      # Get page parts for a specific category
      # @param category [Symbol, String]
      # @return [Hash]
      def for_category(category)
        DEFINITIONS.select { |_key, config| config[:category].to_sym == category.to_sym }
      end

      # Get definition for a page part
      # @param key [String, Symbol]
      # @return [Hash, nil]
      def definition(key)
        DEFINITIONS[key.to_s]
      end

      # Check if a page part exists
      # @param key [String, Symbol]
      # @return [Boolean]
      def exists?(key)
        DEFINITIONS.key?(key.to_s) || template_exists?(key)
      end

      # Check if template file exists
      # @param key [String, Symbol]
      # @return [Boolean]
      def template_exists?(key)
        template_path(key).present?
      end

      # Get the template path for a page part
      # @param key [String, Symbol]
      # @return [Pathname, nil]
      def template_path(key)
        # Check in categorized directory
        if key.to_s.include?('/')
          path = Rails.root.join("app/views/pwb/page_parts/#{key}.liquid")
          return path if File.exist?(path)
        end

        # Check in root page_parts directory
        root_path = Rails.root.join("app/views/pwb/page_parts/#{key}.liquid")
        return root_path if File.exist?(root_path)

        nil
      end

      # Get all categories
      # @return [Hash]
      def categories
        CATEGORIES
      end

      # Get category info
      # @param category [Symbol, String]
      # @return [Hash, nil]
      def category_info(category)
        CATEGORIES[category.to_sym]
      end

      # Get non-legacy page parts
      # @return [Hash]
      def modern_parts
        DEFINITIONS.reject { |_key, config| config[:legacy] }
      end

      # Get legacy page parts
      # @return [Hash]
      def legacy_parts
        DEFINITIONS.select { |_key, config| config[:legacy] }
      end

      # Get all container page parts
      # @return [Hash]
      def container_parts
        DEFINITIONS.select { |_key, config| config[:is_container] }
      end

      # Check if a page part is a container
      # @param key [String, Symbol]
      # @return [Boolean]
      def container?(key)
        definition(key)&.dig(:is_container) == true
      end

      # Get slot definitions for a container page part
      # @param key [String, Symbol]
      # @return [Hash, nil]
      def slots_for(key)
        return nil unless container?(key)

        definition(key)&.dig(:slots)
      end

      # Get slot names for a container page part
      # @param key [String, Symbol]
      # @return [Array<String>]
      def slot_names(key)
        slots_for(key)&.keys&.map(&:to_s) || []
      end

      # Convert to JSON for API responses
      # @return [Hash]
      def to_json_schema
        {
          categories: CATEGORIES.map do |key, info|
            {
              key: key,
              label: info[:label],
              description: info[:description],
              icon: info[:icon],
              parts: for_category(key).map do |part_key, part_config|
                part_json = {
                  key: part_key,
                  label: part_config[:label],
                  description: part_config[:description],
                  fields: part_config[:fields],
                  legacy: part_config[:legacy] || false
                }
                # Include container-specific info
                if part_config[:is_container]
                  part_json[:is_container] = true
                  part_json[:slots] = part_config[:slots]
                end
                part_json
              end
            }
          end
        }
      end
    end
  end
end
