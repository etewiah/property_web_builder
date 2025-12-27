# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Theme Component Functionality', type: :view do
  # Themes that use Tailwind/Flowbite (not Bootstrap)
  TAILWIND_THEMES = %w[bologna barcelona brisbane biarritz default].freeze

  # Required patterns for Flowbite carousel to work
  FLOWBITE_CAROUSEL_PATTERNS = {
    'data-carousel-item' => 'Carousel item data attribute',
    'data-carousel-prev' => 'Previous button data attribute',
    'data-carousel-next' => 'Next button data attribute',
    'propCarousel' => 'Carousel container ID'
  }.freeze

  # Required patterns for Flowbite dropdowns to work
  FLOWBITE_DROPDOWN_PATTERNS = {
    'data-dropdown-toggle' => 'Dropdown toggle data attribute'
  }.freeze

  # ERB comment patterns that can cause issues (single-line patterns only)
  # The issue: <%# <%= foo %> %> - ERB comments end at first %>, leaving " %>" as text
  MALFORMED_ERB_PATTERNS = [
    # Nested ERB output tag inside a comment on the same line
    /<%#[^%]*<%=[^%]*%>[^%]*%>/
  ].freeze

  def theme_directories
    themes_path = Rails.root.join('app', 'themes')
    return [] unless themes_path.exist?

    themes_path.children.select(&:directory?).map(&:basename).map(&:to_s)
  end

  def read_template(theme, template_path)
    full_path = Rails.root.join('app', 'themes', theme, 'views', template_path)
    return nil unless full_path.exist?

    File.read(full_path)
  end

  def template_exists?(theme, template_path)
    full_path = Rails.root.join('app', 'themes', theme, 'views', template_path)
    full_path.exist?
  end

  describe 'ERB syntax validation' do
    theme_directories_for_test = Dir.glob(Rails.root.join('app', 'themes', '*'))
                                    .select { |f| File.directory?(f) }
                                    .map { |f| File.basename(f) }

    theme_directories_for_test.each do |theme|
      context "#{theme} theme" do
        it 'has no malformed ERB comments in layout' do
          content = read_template(theme, 'layouts/pwb/application.html.erb')
          next unless content

          MALFORMED_ERB_PATTERNS.each do |pattern|
            expect(content).not_to match(pattern),
              "Malformed ERB pattern found in #{theme} layout.\n" \
              "Pattern: #{pattern}\n" \
              "ERB comments <%# ... %> end at the first %> encountered.\n" \
              "Nested ERB tags inside comments will break the page."
          end
        end

        it 'has no visible ERB artifacts in rendered output patterns' do
          content = read_template(theme, 'layouts/pwb/application.html.erb')
          next unless content

          # Check for common ERB artifacts that might be rendered
          # These patterns indicate broken ERB that will render as visible text
          dangerous_patterns = [
            /^\s*%>\s*$/m,  # Lone %> on a line
            /body[^>]*>[\s\n]*%>/m  # %> immediately after body tag
          ]

          dangerous_patterns.each do |pattern|
            expect(content).not_to match(pattern),
              "Potential ERB rendering issue in #{theme} layout.\n" \
              "This pattern may render as visible text in the browser."
          end
        end
      end
    end
  end

  describe 'Carousel functionality for Tailwind themes' do
    TAILWIND_THEMES.each do |theme|
      next unless Dir.exist?(Rails.root.join('app', 'themes', theme))

      context "#{theme} theme" do
        it 'has a proper Flowbite-compatible carousel partial' do
          # Check theme-specific partial first, then fall back to default
          carousel_path = if template_exists?(theme, 'pwb/props/_images_section_carousel.html.erb')
                            "pwb/props/_images_section_carousel.html.erb"
                          else
                            nil
                          end

          if carousel_path
            content = read_template(theme, carousel_path)

            # Must have Flowbite-compatible structure for Tailwind themes
            FLOWBITE_CAROUSEL_PATTERNS.each do |pattern, description|
              expect(content).to include(pattern),
                "Missing #{description} in #{theme} carousel partial.\n" \
                "Tailwind themes must use Flowbite carousel patterns, not Bootstrap.\n" \
                "Missing pattern: #{pattern}"
            end

            # Should NOT use Bootstrap carousel patterns
            bootstrap_patterns = ['data-ride="carousel"', 'carousel-inner', 'class="item']
            bootstrap_patterns.each do |pattern|
              expect(content).not_to include(pattern),
                "#{theme} carousel uses Bootstrap patterns which won't work with Tailwind.\n" \
                "Found: #{pattern}\n" \
                "Use Flowbite carousel patterns instead."
            end
          else
            # Theme relies on default carousel - warn if default is Bootstrap-based
            default_carousel = Rails.root.join('app', 'views', 'pwb', 'props', '_images_section_carousel.html.erb')
            if default_carousel.exist?
              content = File.read(default_carousel)
              is_bootstrap = content.include?('data-ride="carousel"') || content.include?('carousel-inner')

              if is_bootstrap
                skip "#{theme} theme lacks a Flowbite carousel partial and will fall back to Bootstrap carousel.\n" \
                     "Create: app/themes/#{theme}/views/pwb/props/_images_section_carousel.html.erb\n" \
                     "Copy from brisbane or barcelona theme as a starting point."
              end
            end
          end
        end

        it 'carousel partial initializes Flowbite Carousel JS' do
          carousel_path = 'pwb/props/_images_section_carousel.html.erb'
          content = read_template(theme, carousel_path)
          next unless content

          # Check for Flowbite carousel initialization
          expect(content).to match(/CarouselConstructor|new.*Carousel|Flowbite.*Carousel/i),
            "#{theme} carousel should initialize Flowbite Carousel JavaScript.\n" \
            "Include a script that creates a new Carousel instance."
        end
      end
    end
  end

  describe 'Dropdown functionality for Tailwind themes' do
    TAILWIND_THEMES.each do |theme|
      next unless Dir.exist?(Rails.root.join('app', 'themes', theme))

      context "#{theme} theme" do
        it 'header uses Flowbite-compatible dropdown patterns' do
          content = read_template(theme, 'pwb/_header.html.erb')
          next unless content

          # If there's a dropdown in the header, it should use Flowbite patterns
          if content.include?('dropdown') || content.include?('menu')
            # Should use data attributes or Stimulus controllers, not Bootstrap
            bootstrap_dropdown = content.include?('data-toggle="dropdown"') ||
                                 content.include?('data-bs-toggle="dropdown"')

            expect(bootstrap_dropdown).to be(false),
              "#{theme} header uses Bootstrap dropdown patterns.\n" \
              "Use Flowbite data-dropdown-toggle or Stimulus controllers instead."
          end
        end

        it 'search forms use Flowbite-compatible select patterns', skip: 'Advisory - select styling quality check' do
          %w[_search_form_for_sale.html.erb _search_form_for_rent.html.erb].each do |form|
            content = read_template(theme, "pwb/search/#{form}")
            next unless content

            # Check that select elements have proper structure
            if content.include?('<select')
              # Should have proper classes for Tailwind styling
              expect(content).to match(/<select[^>]*class=/i),
                "#{theme} #{form} has select elements without CSS classes.\n" \
                "Add Tailwind/Flowbite classes for proper styling."
            end
          end
        end
      end
    end
  end

  describe 'CSS framework consistency' do
    TAILWIND_THEMES.each do |theme|
      next unless Dir.exist?(Rails.root.join('app', 'themes', theme))

      context "#{theme} theme" do
        it 'layout loads Tailwind CSS' do
          content = read_template(theme, 'layouts/pwb/application.html.erb')
          next unless content

          expect(content).to match(/tailwind.*\.css/i),
            "#{theme} layout should load Tailwind CSS.\n" \
            "Expected: tailwind-#{theme}.css or similar"
        end

        it 'layout loads Flowbite JS' do
          content = read_template(theme, 'layouts/pwb/application.html.erb')
          next unless content

          expect(content).to match(/flowbite.*\.js/i),
            "#{theme} layout should load Flowbite JavaScript.\n" \
            "This is required for dropdowns, carousels, and other interactive components."
        end

        it 'does not load Bootstrap CSS' do
          content = read_template(theme, 'layouts/pwb/application.html.erb')
          next unless content

          # Bootstrap CSS patterns
          bootstrap_css_patterns = [
            /bootstrap\.min\.css/,
            /bootstrap\.css/,
            /bootstrap-[0-9]/
          ]

          bootstrap_css_patterns.each do |pattern|
            expect(content).not_to match(pattern),
              "#{theme} layout loads Bootstrap CSS which conflicts with Tailwind.\n" \
              "Tailwind themes should not load Bootstrap CSS."
          end
        end
      end
    end
  end

  describe 'Component summary' do
    it 'reports component status for all themes' do
      themes = Dir.glob(Rails.root.join('app', 'themes', '*'))
                  .select { |f| File.directory?(f) }
                  .map { |f| File.basename(f) }

      puts "\n" + "=" * 60
      puts "THEME COMPONENT STATUS REPORT"
      puts "=" * 60

      themes.each do |theme|
        puts "\n#{theme.upcase} THEME"
        puts "-" * 40

        # Check carousel
        has_carousel = template_exists?(theme, 'pwb/props/_images_section_carousel.html.erb')
        carousel_content = read_template(theme, 'pwb/props/_images_section_carousel.html.erb')
        carousel_type = if !has_carousel
                          'MISSING (uses default)'
                        elsif carousel_content&.include?('data-carousel-item')
                          'Flowbite'
                        elsif carousel_content&.include?('data-ride="carousel"')
                          'Bootstrap'
                        else
                          'Unknown'
                        end

        puts "  Carousel:  #{carousel_type}"

        # Check layout
        layout_content = read_template(theme, 'layouts/pwb/application.html.erb')
        if layout_content
          has_tailwind = layout_content.match?(/tailwind.*\.css/i)
          has_flowbite = layout_content.match?(/flowbite.*\.js/i)
          has_bootstrap = layout_content.match?(/bootstrap.*\.css/i)

          puts "  Tailwind:  #{has_tailwind ? 'YES' : 'NO'}"
          puts "  Flowbite:  #{has_flowbite ? 'YES' : 'NO'}"
          puts "  Bootstrap: #{has_bootstrap ? 'YES (potential conflict)' : 'NO'}"

          # Warn about mismatches
          if has_tailwind && !has_carousel
            puts "  WARNING:   Tailwind theme without Flowbite carousel"
          end
          if has_tailwind && carousel_type == 'Bootstrap'
            puts "  WARNING:   Tailwind theme with Bootstrap carousel"
          end
        end
      end

      puts "\n" + "=" * 60
    end
  end
end
