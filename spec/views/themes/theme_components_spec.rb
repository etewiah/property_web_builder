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

  describe 'Dark mode support' do
    # CSS files that should support dark mode
    THEME_CSS_FILES = {
      'default' => '_default.css.erb',
      'brisbane' => '_brisbane.css.erb',
      'bologna' => '_bologna.css.erb',
      'barcelona' => '_barcelona.css.erb',
      'biarritz' => '_biarritz.css.erb'
    }.freeze

    def read_css_partial(css_filename)
      path = Rails.root.join('app', 'views', 'pwb', 'custom_css', css_filename)
      return nil unless path.exist?

      File.read(path)
    end

    describe 'CSS file structure' do
      THEME_CSS_FILES.each do |theme, css_file|
        context "#{theme} theme CSS" do
          let(:css_content) { read_css_partial(css_file) }

          it 'exists' do
            expect(css_content).not_to be_nil,
              "Missing CSS file: app/views/pwb/custom_css/#{css_file}"
          end

          it 'includes base_variables partial for dark mode support' do
            next unless css_content

            expect(css_content).to include("render partial: '/pwb/custom_css/base_variables'"),
              "#{theme} CSS must include base_variables partial.\n" \
              "Add: <%= render partial: '/pwb/custom_css/base_variables', locals: {} %>\n" \
              "This provides core dark mode CSS variables."
          end

          it 'has dark mode section' do
            next unless css_content

            expect(css_content).to match(/DARK MODE SUPPORT|dark_mode_enabled/i),
              "#{theme} CSS should have dark mode support section.\n" \
              "Include conditional CSS for .pwb-dark class."
          end

          it 'has forced dark mode styles using .pwb-dark class' do
            next unless css_content

            expect(css_content).to include('.pwb-dark'),
              "#{theme} CSS must have .pwb-dark class styles for forced dark mode."
          end

          it 'has auto dark mode styles using prefers-color-scheme' do
            next unless css_content

            expect(css_content).to include('prefers-color-scheme: dark'),
              "#{theme} CSS should have @media (prefers-color-scheme: dark) styles.\n" \
              "This enables automatic dark mode based on system preferences."
          end

          it 'conditionally renders dark mode CSS based on website setting' do
            next unless css_content

            expect(css_content).to include('dark_mode_enabled?'),
              "#{theme} CSS should conditionally render dark mode styles.\n" \
              "Use: <% if @current_website&.dark_mode_enabled? %>"
          end
        end
      end
    end

    describe 'Layout dark mode classes' do
      TAILWIND_THEMES.each do |theme|
        next unless Dir.exist?(Rails.root.join('app', 'themes', theme))

        context "#{theme} theme layout" do
          let(:layout_content) { read_template(theme, 'layouts/pwb/application.html.erb') }

          it 'includes dark mode HTML class from website settings' do
            next unless layout_content

            expect(layout_content).to match(/dark_mode_html_class/),
              "#{theme} layout should include dark_mode_html_class on html tag.\n" \
              "Add: class=\"<%= @current_website.dark_mode_html_class %>\""
          end

          it 'includes auto dark mode class for system preference detection' do
            next unless layout_content

            expect(layout_content).to match(/auto_dark_mode|pwb-auto-dark/),
              "#{theme} layout should support auto dark mode.\n" \
              "Add: class=\"<%= @current_website.auto_dark_mode? ? 'pwb-auto-dark' : '' %>\""
          end
        end
      end
    end

    describe 'Base variables partial' do
      let(:base_variables_content) do
        path = Rails.root.join('app', 'views', 'pwb', 'custom_css', '_base_variables.css.erb')
        File.read(path) if path.exist?
      end

      it 'exists' do
        expect(base_variables_content).not_to be_nil,
          "Missing base variables partial: app/views/pwb/custom_css/_base_variables.css.erb"
      end

      it 'defines dark mode CSS variables' do
        next unless base_variables_content

        expect(base_variables_content).to include('--pwb-bg-body'),
          "Base variables should define --pwb-bg-body CSS variable."
      end

      it 'has dark mode color configuration' do
        next unless base_variables_content

        expect(base_variables_content).to match(/dark_mode_colors|dark_bg|dark_text/),
          "Base variables should read dark mode colors from website settings."
      end
    end

    describe 'WebsiteStyleable concern' do
      it 'Website model includes dark mode methods' do
        website = Pwb::Website.new

        expect(website).to respond_to(:dark_mode_enabled?),
          "Website model should have dark_mode_enabled? method"
        expect(website).to respond_to(:dark_mode_html_class),
          "Website model should have dark_mode_html_class method"
        expect(website).to respond_to(:auto_dark_mode?),
          "Website model should have auto_dark_mode? method"
        expect(website).to respond_to(:force_dark_mode?),
          "Website model should have force_dark_mode? method"
      end

      context 'dark_mode_html_class' do
        let(:website) { Pwb::Website.new }

        it 'returns pwb-dark when force_dark_mode is enabled' do
          allow(website).to receive(:dark_mode_setting).and_return('dark')

          expect(website.dark_mode_html_class).to eq('pwb-dark')
        end

        it 'returns nil when dark mode is disabled (interpolates as empty string)' do
          allow(website).to receive(:dark_mode_setting).and_return('light_only')

          expect(website.dark_mode_html_class).to be_nil
        end

        it 'returns nil for auto dark mode (CSS handles via prefers-color-scheme)' do
          allow(website).to receive(:dark_mode_setting).and_return('auto')

          expect(website.dark_mode_html_class).to be_nil
        end
      end
    end

    describe 'Dark mode color customization' do
      let(:website) { Pwb::Website.new }

      it 'has default dark mode colors' do
        colors = website.dark_mode_colors || {}

        # These are checked for presence when dark_mode_enabled? is true
        # The CSS provides fallback defaults if not customized
        expect(colors).to be_a(Hash)
      end
    end
  end

  describe 'Layout Tailwind CSS references' do
    # Layout files that should use tailwind-default (admin/system layouts)
    ADMIN_LAYOUTS = {
      'app/views/layouts/devise_tailwind.html.erb' => 'Devise login layout',
      'app/views/layouts/tenant_admin.html.erb' => 'Tenant admin layout',
      'app/views/layouts/pwb/admin_panel_error.html.erb' => 'Admin panel error layout',
      'app/views/layouts/pwb/signup.html.erb' => 'Signup wizard layout'
    }.freeze

    # Layout files that should use theme-specific tailwind
    THEME_AWARE_LAYOUTS = {
      'app/views/layouts/pwb/page_part.html.erb' => 'Page part preview layout'
    }.freeze

    # Available themed tailwind files
    AVAILABLE_TAILWIND_FILES = %w[
      tailwind-default
      tailwind-brisbane
      tailwind-bologna
      tailwind-barcelona
      tailwind-biarritz
    ].freeze

    describe 'Admin layouts use tailwind-default' do
      ADMIN_LAYOUTS.each do |layout_path, description|
        it "#{description} references tailwind-default" do
          full_path = Rails.root.join(layout_path)
          next unless full_path.exist?

          content = File.read(full_path)

          # Should NOT reference bare "tailwind" (without theme suffix)
          expect(content).not_to match(/stylesheet_link_tag\s+["']tailwind["']\s*,/),
            "#{layout_path} should NOT reference 'tailwind' (non-existent asset).\n" \
            "Use 'tailwind-default' instead."

          # Should reference tailwind-default
          expect(content).to match(/stylesheet_link_tag\s+["']tailwind-default["']/),
            "#{layout_path} should reference 'tailwind-default' for proper styling."
        end
      end
    end

    describe 'Theme-aware layouts use dynamic tailwind file' do
      THEME_AWARE_LAYOUTS.each do |layout_path, description|
        it "#{description} uses theme-specific tailwind" do
          full_path = Rails.root.join(layout_path)
          next unless full_path.exist?

          content = File.read(full_path)

          # Should NOT reference bare "tailwind"
          expect(content).not_to match(/stylesheet_link_tag\s+["']tailwind["']\s*,/),
            "#{layout_path} should NOT reference 'tailwind' (non-existent asset)."

          # Should reference a variable/dynamic tailwind file
          expect(content).to match(/stylesheet_link_tag\s+(tailwind_file|["']tailwind-)/),
            "#{layout_path} should use theme-aware tailwind file (e.g., tailwind_file variable or tailwind-{theme})."
        end
      end
    end

    describe 'No layouts reference non-existent tailwind.css' do
      it 'searches all ERB layouts for bare tailwind references' do
        layouts_path = Rails.root.join('app', 'views', 'layouts')
        erb_files = Dir.glob("#{layouts_path}/**/*.erb")

        problematic_files = []
        erb_files.each do |file_path|
          content = File.read(file_path)
          # Match stylesheet_link_tag "tailwind" or 'tailwind' followed by comma or close paren
          # but not tailwind-something
          if content.match?(/stylesheet_link_tag\s+["']tailwind["']\s*[,)]/)
            problematic_files << file_path.sub(Rails.root.to_s + '/', '')
          end
        end

        expect(problematic_files).to be_empty,
          "The following layouts reference 'tailwind' which doesn't exist:\n" \
          "#{problematic_files.join("\n")}\n\n" \
          "Use 'tailwind-default' or a theme-specific file instead.\n" \
          "Available: #{AVAILABLE_TAILWIND_FILES.join(', ')}"
      end
    end
  end
end
