# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Theme Completeness', type: :view do
  # All themes must have these core templates to function properly
  REQUIRED_TEMPLATES = [
    # Layout
    'layouts/pwb/application.html.erb',

    # Header and Footer
    'pwb/_header.html.erb',
    'pwb/_footer.html.erb',

    # Home/Welcome page
    'pwb/welcome/index.html.erb',

    # Search pages
    'pwb/search/buy.html.erb',
    'pwb/search/rent.html.erb',
    'pwb/search/_search_form_for_sale.html.erb',
    'pwb/search/_search_form_for_rent.html.erb',
    'pwb/search/_search_results.html.erb',

    # Property detail page
    'pwb/props/show.html.erb',

    # Generic pages (About Us, etc.)
    'pwb/pages/show.html.erb',

    # Contact page
    'pwb/sections/contact_us.html.erb',
    'pwb/sections/_contact_us_form.html.erb',

    # Components
    'pwb/components/_generic_page_part.html.erb',
    'pwb/components/_form_and_map.html.erb',
  ].freeze

  # Optional but recommended templates
  RECOMMENDED_TEMPLATES = [
    'pwb/search/_search_form_landing.html.erb',
    'pwb/welcome/_single_property_row.html.erb',
    'pwb/welcome/_about_us.html.erb',
    'pwb/props/_breadcrumb_row.html.erb',
    'pwb/props/_images_section_carousel.html.erb',
    'pwb/props/_request_prop_info.html.erb',
  ].freeze

  # Custom CSS partials required for theme rendering
  REQUIRED_CSS_PARTIALS = [
    # Custom CSS partial in app/views/pwb/custom_css/_<theme>.css.erb
    # This is loaded by the layout via custom_styles helper
  ].freeze

  # Get all theme directories
  def theme_directories
    themes_path = Rails.root.join('app', 'themes')
    return [] unless themes_path.exist?

    themes_path.children.select(&:directory?).map(&:basename).map(&:to_s)
  end

  # Check if a template exists for a theme
  def template_exists?(theme, template_path)
    full_path = Rails.root.join('app', 'themes', theme, 'views', template_path)
    full_path.exist?
  end

  # Directories in app/themes/ that are not actual themes
  NON_THEME_DIRECTORIES = %w[shared].freeze

  describe 'Required templates' do
    theme_directories_for_test = Dir.glob(Rails.root.join('app', 'themes', '*'))
      .select { |f| File.directory?(f) }
      .map { |f| File.basename(f) }
      .reject { |name| NON_THEME_DIRECTORIES.include?(name) }

    theme_directories_for_test.each do |theme|
      context "#{theme} theme" do
        REQUIRED_TEMPLATES.each do |template|
          it "has required template: #{template}" do
            full_path = Rails.root.join('app', 'themes', theme, 'views', template)
            expect(full_path).to exist,
              "Missing required template: #{template}\n" \
              "Expected at: #{full_path}\n" \
              "This template is required for the theme to function properly."
          end
        end
      end
    end
  end

  describe 'Recommended templates' do
    theme_directories_for_test = Dir.glob(Rails.root.join('app', 'themes', '*'))
      .select { |f| File.directory?(f) }
      .map { |f| File.basename(f) }
      .reject { |name| NON_THEME_DIRECTORIES.include?(name) }

    theme_directories_for_test.each do |theme|
      context "#{theme} theme" do
        RECOMMENDED_TEMPLATES.each do |template|
          it "has recommended template: #{template}", skip: 'Advisory only - not required' do
            full_path = Rails.root.join('app', 'themes', theme, 'views', template)
            expect(full_path).to exist,
              "Missing recommended template: #{template}\n" \
              "This template improves the theme but is not strictly required."
          end
        end
      end
    end
  end

  describe 'Custom CSS partials' do
    theme_directories_for_test = Dir.glob(Rails.root.join('app', 'themes', '*'))
      .select { |f| File.directory?(f) }
      .map { |f| File.basename(f) }
      .reject { |name| NON_THEME_DIRECTORIES.include?(name) }

    theme_directories_for_test.each do |theme|
      context "#{theme} theme" do
        it "has custom CSS partial at app/views/pwb/custom_css/_#{theme}.css.erb" do
          css_partial = Rails.root.join('app', 'views', 'pwb', 'custom_css', "_#{theme}.css.erb")
          expect(css_partial).to exist,
            "Missing required CSS partial: _#{theme}.css.erb\n" \
            "Expected at: #{css_partial}\n" \
            "This partial is required by the layout's custom_styles helper.\n" \
            "Create it with theme-specific CSS variables and styles."
        end
      end
    end
  end

  describe 'Theme summary' do
    it 'reports completeness for all themes' do
      themes_path = Rails.root.join('app', 'themes')
      themes = Dir.glob(themes_path.join('*')).select { |f| File.directory?(f) }.map { |f| File.basename(f) }

      puts "\n" + "=" * 60
      puts "THEME COMPLETENESS REPORT"
      puts "=" * 60

      themes.each do |theme|
        required_count = REQUIRED_TEMPLATES.count { |t| Rails.root.join('app', 'themes', theme, 'views', t).exist? }
        recommended_count = RECOMMENDED_TEMPLATES.count { |t| Rails.root.join('app', 'themes', theme, 'views', t).exist? }
        has_css_partial = Rails.root.join('app', 'views', 'pwb', 'custom_css', "_#{theme}.css.erb").exist?

        required_percentage = (required_count.to_f / REQUIRED_TEMPLATES.size * 100).round(1)
        total_percentage = ((required_count + recommended_count).to_f / (REQUIRED_TEMPLATES.size + RECOMMENDED_TEMPLATES.size) * 100).round(1)

        status = required_percentage == 100 && has_css_partial ? 'COMPLETE' : 'INCOMPLETE'

        puts "\n#{theme.upcase} THEME [#{status}]"
        puts "-" * 40
        puts "  Required:    #{required_count}/#{REQUIRED_TEMPLATES.size} (#{required_percentage}%)"
        puts "  CSS Partial: #{has_css_partial ? 'YES' : 'NO'}"
        puts "  Recommended: #{recommended_count}/#{RECOMMENDED_TEMPLATES.size}"
        puts "  Overall:     #{total_percentage}%"

        if required_percentage < 100
          missing = REQUIRED_TEMPLATES.reject { |t| Rails.root.join('app', 'themes', theme, 'views', t).exist? }
          puts "  MISSING REQUIRED:"
          missing.each { |t| puts "    - #{t}" }
        end

        unless has_css_partial
          puts "  MISSING CSS PARTIAL:"
          puts "    - app/views/pwb/custom_css/_#{theme}.css.erb"
        end
      end

      puts "\n" + "=" * 60
    end
  end
end
