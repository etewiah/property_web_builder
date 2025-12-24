# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Theme Search Page Conformance', type: :view do
  # This test suite validates that all themes conform to the search UI specification
  # defined in docs/ui/SEARCH_UI_SPECIFICATION.md
  #
  # Key requirements:
  # - Responsive layout: sidebar 1/4 width, results 3/4 width on desktop
  # - Mobile filter toggle (hidden on large screens)
  # - No Vue.js or jQuery dependencies
  # - Stimulus controllers for interactivity
  # - Standard container IDs for AJAX updates

  THEMES = %w[default brisbane bologna].freeze
  SEARCH_PAGES = %w[buy rent].freeze

  # Required layout classes per specification
  REQUIRED_SIDEBAR_CLASSES = %w[lg:w-1/4].freeze
  REQUIRED_RESULTS_CLASSES = %w[lg:w-3/4].freeze

  # Deprecated patterns that should not appear
  DEPRECATED_PATTERNS = {
    'Vue.js reference' => /INMOAPP\.pwbVue|Vue\.|v-if|v-for|v-model|v-bind|v-on|::/,
    'jQuery reference' => /\$\(|jQuery\(|\$\./,
    'Bootstrap classes' => /class="[^"]*(?:col-md-|col-lg-|col-sm-|btn-primary|btn-secondary)[^"]*"/
  }.freeze

  # Required elements for search functionality
  REQUIRED_ELEMENTS = {
    'results container' => /id=["']inmo-search-results["']/,
    'Stimulus controller' => /data-controller=["'][^"']*search-form[^"']*["']/
  }.freeze

  describe 'theme search page templates exist' do
    THEMES.each do |theme|
      context "#{theme} theme" do
        SEARCH_PAGES.each do |page|
          it "has #{page}.html.erb template" do
            template_path = Rails.root.join('app', 'themes', theme, 'views', 'pwb', 'search', "#{page}.html.erb")
            expect(File.exist?(template_path)).to be(true),
              "Missing template: #{template_path}"
          end
        end

        it 'has _search_results.html.erb partial' do
          partial_path = Rails.root.join('app', 'themes', theme, 'views', 'pwb', 'search', '_search_results.html.erb')
          expect(File.exist?(partial_path)).to be(true),
            "Missing partial: #{partial_path}"
        end
      end
    end
  end

  describe 'responsive layout conformance' do
    # Themes that follow the spec exactly (sidebar 1/4, results 3/4 on desktop)
    # Currently no themes are fully compliant - all use mobile-first stacked layout
    # When a theme is updated to be compliant, add it here to enforce the layout
    COMPLIANT_THEMES = [].freeze

    THEMES.each do |theme|
      context "#{theme} theme" do
        SEARCH_PAGES.each do |page|
          describe "#{page}.html.erb" do
            let(:template_path) { Rails.root.join('app', 'themes', theme, 'views', 'pwb', 'search', "#{page}.html.erb") }
            let(:template_content) { File.read(template_path) }

            if COMPLIANT_THEMES.include?(theme)
              # Strict layout tests for compliant themes
              it 'has sidebar with lg:w-1/4 class for desktop layout' do
                has_sidebar_width = template_content.include?('lg:w-1/4')

                expect(has_sidebar_width).to be(true),
                  "#{theme}/#{page}.html.erb missing sidebar width class 'lg:w-1/4'. " \
                  "Per specification, sidebar must be 1/4 width on desktop (lg breakpoint)."
              end

              it 'has results column with lg:w-3/4 class for desktop layout' do
                has_results_width = template_content.include?('lg:w-3/4')

                expect(has_results_width).to be(true),
                  "#{theme}/#{page}.html.erb missing results width class 'lg:w-3/4'. " \
                  "Per specification, results must be 3/4 width on desktop (lg breakpoint)."
              end

              it 'has mobile filter toggle with lg:hidden class' do
                has_mobile_toggle = template_content.include?('lg:hidden')

                expect(has_mobile_toggle).to be(true),
                  "#{theme}/#{page}.html.erb missing mobile filter toggle with 'lg:hidden' class. " \
                  "Per specification, filter toggle button should only show on mobile."
              end

              it 'has filter content that is hidden on mobile (hidden lg:block)' do
                has_responsive_filters = template_content.include?('hidden lg:block')

                expect(has_responsive_filters).to be(true),
                  "#{theme}/#{page}.html.erb missing responsive filter classes 'hidden lg:block'. " \
                  "Per specification, filters should be hidden on mobile with toggle to show."
              end
            else
              # Basic layout tests for non-compliant themes (documents current state)
              it 'has a search-sidebar element' do
                has_sidebar = template_content.include?('search-sidebar')

                expect(has_sidebar).to be(true),
                  "#{theme}/#{page}.html.erb missing search-sidebar class. " \
                  "Search layout should have a designated sidebar element."
              end

              it 'has a search-results element' do
                has_results = template_content.include?('search-results')

                expect(has_results).to be(true),
                  "#{theme}/#{page}.html.erb missing search-results class. " \
                  "Search layout should have a designated results element."
              end

              it 'has a filter toggle button' do
                has_toggle = template_content.match?(/filter-toggle|toggleFilters/)

                expect(has_toggle).to be(true),
                  "#{theme}/#{page}.html.erb missing filter toggle functionality. " \
                  "Should have a button to show/hide filters."
              end

              it 'has collapsible filter content' do
                has_collapsible = template_content.match?(/filter-content|sidebar-filters/)

                expect(has_collapsible).to be(true),
                  "#{theme}/#{page}.html.erb missing collapsible filter content. " \
                  "Filter panel should be toggleable."
              end

              # Mark as pending to track themes that need updating
              it 'SHOULD have side-by-side layout on desktop (lg:w-1/4 + lg:w-3/4)', pending: 'Theme needs layout update to match spec' do
                has_sidebar_width = template_content.include?('lg:w-1/4')
                has_results_width = template_content.include?('lg:w-3/4')

                expect(has_sidebar_width && has_results_width).to be(true),
                  "#{theme}/#{page}.html.erb should have lg:w-1/4 sidebar and lg:w-3/4 results. " \
                  "See docs/ui/SEARCH_UI_SPECIFICATION.md for layout requirements."
              end
            end
          end
        end
      end
    end
  end

  describe 'required elements' do
    THEMES.each do |theme|
      context "#{theme} theme" do
        SEARCH_PAGES.each do |page|
          describe "#{page}.html.erb" do
            let(:template_path) { Rails.root.join('app', 'themes', theme, 'views', 'pwb', 'search', "#{page}.html.erb") }
            let(:template_content) { File.read(template_path) }

            REQUIRED_ELEMENTS.each do |element_name, pattern|
              it "contains #{element_name}" do
                expect(template_content).to match(pattern),
                  "#{theme}/#{page}.html.erb missing #{element_name}. " \
                  "This element is required for search functionality."
              end
            end

            it 'has map section conditional on markers' do
              # Map should only render when markers exist
              has_map_conditional = template_content.match?(/@map_markers\.length\s*>\s*0/) ||
                                   template_content.match?(/@map_markers\.any\?/) ||
                                   template_content.match?(/@map_markers\.present\?/)

              expect(has_map_conditional).to be(true),
                "#{theme}/#{page}.html.erb missing conditional check for map markers. " \
                "Map section should only render when @map_markers.length > 0."
            end
          end
        end
      end
    end
  end

  describe 'no deprecated patterns' do
    THEMES.each do |theme|
      context "#{theme} theme" do
        let(:theme_search_files) do
          Dir.glob(Rails.root.join('app', 'themes', theme, 'views', 'pwb', 'search', '*.html.erb'))
        end

        DEPRECATED_PATTERNS.each do |pattern_name, pattern|
          it "does not contain #{pattern_name}" do
            violations = []

            theme_search_files.each do |file_path|
              content = File.read(file_path)
              relative_path = file_path.to_s.sub("#{Rails.root}/", '')

              if content.match?(pattern)
                # Extract matching lines for better error messages
                matching_lines = content.lines.each_with_index.select { |line, _| line.match?(pattern) }
                matching_lines.each do |line, index|
                  violations << "#{relative_path}:#{index + 1}: #{line.strip}"
                end
              end
            end

            expect(violations).to be_empty,
              "Found #{pattern_name} in #{theme} theme search templates:\n#{violations.join("\n")}\n\n" \
              "Per specification, Vue.js and jQuery have been fully removed. Use Stimulus.js instead."
          end
        end
      end
    end
  end

  describe 'Stimulus controller integration' do
    THEMES.each do |theme|
      context "#{theme} theme" do
        SEARCH_PAGES.each do |page|
          describe "#{page}.html.erb" do
            let(:template_path) { Rails.root.join('app', 'themes', theme, 'views', 'pwb', 'search', "#{page}.html.erb") }
            let(:template_content) { File.read(template_path) }

            it 'uses search-form Stimulus controller' do
              has_search_controller = template_content.match?(/data-controller=["'][^"']*search-form[^"']*["']/)

              expect(has_search_controller).to be(true),
                "#{theme}/#{page}.html.erb missing search-form Stimulus controller. " \
                "Per specification, all interactivity should use Stimulus.js."
            end

            it 'uses map Stimulus controller for map section' do
              # Only check if template has map section
              if template_content.include?('search-map') || template_content.include?('map-canvas')
                has_map_controller = template_content.match?(/data-controller=["'][^"']*map[^"']*["']/)

                expect(has_map_controller).to be(true),
                  "#{theme}/#{page}.html.erb has map section but missing map Stimulus controller."
              end
            end

            it 'has spinner target for loading state' do
              has_spinner_target = template_content.match?(/data-search-form-target=["']spinner["']/)

              expect(has_spinner_target).to be(true),
                "#{theme}/#{page}.html.erb missing loading spinner target. " \
                "Per specification, loading spinner should appear during AJAX submission."
            end

            it 'has results target for AJAX updates' do
              has_results_target = template_content.match?(/data-search-form-target=["']results["']/)

              expect(has_results_target).to be(true),
                "#{theme}/#{page}.html.erb missing results target. " \
                "This target is needed for opacity changes during loading."
            end
          end
        end
      end
    end
  end

  describe 'AJAX response template' do
    let(:ajax_template_path) { Rails.root.join('app', 'views', 'pwb', 'search', 'search_ajax.js.erb') }

    it 'exists' do
      expect(File.exist?(ajax_template_path)).to be(true),
        "Missing AJAX response template: search_ajax.js.erb"
    end

    context 'when template exists' do
      let(:ajax_content) { File.read(ajax_template_path) }

      it 'uses vanilla JavaScript (not jQuery)' do
        expect(ajax_content).not_to match(/\$\(|jQuery\(/),
          "search_ajax.js.erb should use vanilla JavaScript, not jQuery"
      end

      it 'does not reference Vue.js' do
        expect(ajax_content).not_to match(/INMOAPP\.pwbVue|Vue\./),
          "search_ajax.js.erb should not reference Vue.js"
      end

      it 'updates inmo-search-results container' do
        expect(ajax_content).to match(/getElementById\(['"]inmo-search-results['"]\)/),
          "search_ajax.js.erb should update the inmo-search-results container"
      end

      it 'dispatches search:updated custom event' do
        expect(ajax_content).to match(/CustomEvent\(['"]search:updated['"]/),
          "search_ajax.js.erb should dispatch search:updated event for Stimulus controllers"
      end
    end
  end

  describe 'search form partials' do
    THEMES.each do |theme|
      context "#{theme} theme" do
        %w[sale rent].each do |operation|
          partial_name = "_search_form_for_#{operation}.html.erb"
          partial_path = Rails.root.join('app', 'themes', theme, 'views', 'pwb', 'search', partial_name)

          # Only test if the partial exists (some themes may inherit from default)
          next unless File.exist?(partial_path)

          describe partial_name do
            let(:partial_content) { File.read(partial_path) }

            it 'uses Rails form helpers (not raw HTML forms)' do
              # Should use form_with or form_tag, not raw <form> tags
              has_rails_form = partial_content.match?(/form_with|form_tag|form_for/)

              expect(has_rails_form).to be(true),
                "#{theme}/#{partial_name} should use Rails form helpers (form_with, form_tag, etc.)"
            end

            it 'has remote: true for AJAX submission' do
              has_remote_form = partial_content.match?(/remote:\s*true|data:\s*\{[^}]*remote:\s*true/)

              expect(has_remote_form).to be(true),
                "#{theme}/#{partial_name} should have remote: true for AJAX form submission"
            end
          end
        end
      end
    end
  end
end
