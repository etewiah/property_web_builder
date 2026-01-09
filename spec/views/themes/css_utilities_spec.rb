# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PWB CSS Utilities", type: :view do
  let(:tailwind_input_path) { Rails.root.join("app/assets/stylesheets/tailwind-input.css") }
  let(:base_variables_path) { Rails.root.join("app/views/pwb/custom_css/_base_variables.css.erb") }
  let(:themes_path) { Rails.root.join("app/themes") }
  let(:views_path) { Rails.root.join("app/views/pwb") }

  # Extract defined CSS classes from tailwind-input.css
  def defined_utility_classes
    @defined_utility_classes ||= begin
      content = File.read(tailwind_input_path)
      # Match base classes like .bg-pwb-primary-500
      base_classes = content.scan(/\.((?:bg|text|border|ring)-pwb-[a-z0-9-]+)\s*\{/).flatten
      # Match hover variants like .hover\:bg-pwb-primary:hover
      hover_classes = content.scan(/\.hover\\:((?:bg|text|border|ring)-pwb-[a-z0-9-]+):hover/).flatten.map { |c| "hover:#{c}" }
      # Match focus variants
      focus_classes = content.scan(/\.focus\\:((?:bg|text|border|ring|outline)-pwb-[a-z0-9-]+):focus/).flatten.map { |c| "focus:#{c}" }
      # Match active variants
      active_classes = content.scan(/\.active\\:((?:bg|text|border|ring)-pwb-[a-z0-9-]+):active/).flatten.map { |c| "active:#{c}" }

      (base_classes + hover_classes + focus_classes + active_classes).uniq.sort
    end
  end

  # Extract CSS classes used in templates
  def used_utility_classes
    @used_utility_classes ||= begin
      all_classes = []

      # Scan theme templates
      Dir.glob("#{themes_path}/**/*.erb").each do |file|
        content = File.read(file)
        # Base classes
        all_classes.concat(content.scan(/((?:bg|text|border|ring)-pwb-[a-z0-9-]+)/).flatten)
        # Hover variants
        all_classes.concat(content.scan(/hover:((?:bg|text|border|ring)-pwb-[a-z0-9-]+)/).flatten.map { |c| "hover:#{c}" })
        # Focus variants
        all_classes.concat(content.scan(/focus:((?:bg|text|border|ring|outline)-pwb-[a-z0-9-]+)/).flatten.map { |c| "focus:#{c}" })
        # Active variants
        all_classes.concat(content.scan(/active:((?:bg|text|border|ring)-pwb-[a-z0-9-]+)/).flatten.map { |c| "active:#{c}" })
      end

      # Scan pwb views
      Dir.glob("#{views_path}/**/*.erb").each do |file|
        content = File.read(file)
        all_classes.concat(content.scan(/((?:bg|text|border|ring)-pwb-[a-z0-9-]+)/).flatten)
        all_classes.concat(content.scan(/hover:((?:bg|text|border|ring)-pwb-[a-z0-9-]+)/).flatten.map { |c| "hover:#{c}" })
        all_classes.concat(content.scan(/focus:((?:bg|text|border|ring|outline)-pwb-[a-z0-9-]+)/).flatten.map { |c| "focus:#{c}" })
        all_classes.concat(content.scan(/active:((?:bg|text|border|ring)-pwb-[a-z0-9-]+)/).flatten.map { |c| "active:#{c}" })
      end

      all_classes.uniq.sort
    end
  end

  # Extract CSS variables defined in base_variables.css.erb
  def defined_css_variables
    @defined_css_variables ||= begin
      content = File.read(base_variables_path)
      content.scan(/(--pwb-[a-z0-9-]+):/).flatten.uniq.sort
    end
  end

  # Extract CSS variables referenced in tailwind utilities
  def referenced_css_variables
    @referenced_css_variables ||= begin
      content = File.read(tailwind_input_path)
      # Match var(--pwb-*) patterns, extracting the variable name
      content.scan(/var\((--pwb-[a-z0-9-]+)/).flatten.uniq.sort
    end
  end

  describe "utility class completeness" do
    it "defines all PWB utility classes used in templates" do
      missing = used_utility_classes - defined_utility_classes

      if missing.any?
        # Group by type for better error messages
        grouped = missing.group_by do |cls|
          case cls
          when /^hover:/ then "hover variants"
          when /^focus:/ then "focus variants"
          when /^active:/ then "active variants"
          else "base classes"
          end
        end

        error_message = grouped.map do |type, classes|
          "#{type}:\n  - #{classes.join("\n  - ")}"
        end.join("\n\n")

        raise "Missing PWB utility classes in tailwind-input.css:\n\n#{error_message}\n\n" \
              "Add these classes to app/assets/stylesheets/tailwind-input.css"
      end
    end

    it "only uses valid PWB color suffixes" do
      invalid_suffixes = []

      used_utility_classes.each do |cls|
        # Extract the color scale number if present
        next unless (match = cls.match(/-pwb-(?:primary|secondary|accent)-(\d+)/))

        suffix = match[1].to_i
        valid_suffixes = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
        invalid_suffixes << "#{cls} (#{suffix} is not a valid Tailwind scale)" unless valid_suffixes.include?(suffix)
      end

      expect(invalid_suffixes).to be_empty,
        "Invalid color scale suffixes found:\n  - #{invalid_suffixes.join("\n  - ")}"
    end
  end

  describe "CSS variable naming consistency" do
    it "uses correct variable names in tailwind utilities" do
      content = File.read(tailwind_input_path)

      # Tailwind utilities should use the palette-generated variables:
      # --pwb-primary-color, --pwb-secondary-color, --pwb-accent-color
      # These are set by generate_dynamic_palette_css in website_styleable.rb

      # Check that the correct patterns ARE present
      correct_patterns = [
        /--pwb-primary-color/,
        /--pwb-secondary-color/,
        /--pwb-accent-color/
      ]

      correct_patterns.each do |pattern|
        expect(content).to match(pattern),
          "Expected to find '#{pattern.source}' in tailwind-input.css.\n" \
          "Tailwind utilities should use the palette-generated variable names."
      end
    end

    it "references CSS variables that are generated by palette_css at runtime" do
      # The --pwb-*-color variables are generated at runtime by
      # generate_dynamic_palette_css in website_styleable.rb, NOT defined
      # statically in _base_variables.css.erb
      #
      # This test verifies tailwind-input.css references the correct variable names
      # that palette_css will provide at runtime

      expected_runtime_vars = %w[
        --pwb-primary-color
        --pwb-secondary-color
        --pwb-accent-color
      ]

      content = File.read(tailwind_input_path)

      expected_runtime_vars.each do |var|
        expect(content).to include(var),
          "Expected tailwind-input.css to reference '#{var}' which is generated by palette_css at runtime"
      end
    end
  end

  describe "contrast safety" do
    # These color combinations should always be available for proper contrast
    REQUIRED_TEXT_COLORS = %w[
      text-pwb-primary-50 text-pwb-primary-100 text-pwb-primary-200 text-pwb-primary-300 text-pwb-primary-400
      text-pwb-secondary-50 text-pwb-secondary-100 text-pwb-secondary-200 text-pwb-secondary-300 text-pwb-secondary-400
    ].freeze

    REQUIRED_BG_COLORS = %w[
      bg-pwb-primary-700 bg-pwb-primary-800 bg-pwb-primary-900
      bg-pwb-secondary-700 bg-pwb-secondary-800 bg-pwb-secondary-900
    ].freeze

    it "provides light text colors for dark backgrounds" do
      missing_text = REQUIRED_TEXT_COLORS - defined_utility_classes

      expect(missing_text).to be_empty,
        "Missing light text colors needed for dark backgrounds:\n  - #{missing_text.join("\n  - ")}\n\n" \
        "These are required to prevent white-on-white text when using dark PWB backgrounds."
    end

    it "provides dark background colors for sections" do
      missing_bg = REQUIRED_BG_COLORS - defined_utility_classes

      expect(missing_bg).to be_empty,
        "Missing dark background colors:\n  - #{missing_bg.join("\n  - ")}\n\n" \
        "These are required for headers, footers, and dark sections."
    end
  end

  describe "hover/focus variant coverage" do
    it "provides hover variants for commonly used interactive colors" do
      # If a base class is used with hover:, the hover variant must be defined
      hover_usages = used_utility_classes.select { |c| c.start_with?("hover:") }
      missing_hover = hover_usages - defined_utility_classes

      expect(missing_hover).to be_empty,
        "Missing hover variants:\n  - #{missing_hover.join("\n  - ")}\n\n" \
        "Add these to tailwind-input.css in the 'Hover variants' section."
    end

    it "provides focus variants for commonly used interactive colors" do
      focus_usages = used_utility_classes.select { |c| c.start_with?("focus:") }
      missing_focus = focus_usages - defined_utility_classes

      expect(missing_focus).to be_empty,
        "Missing focus variants:\n  - #{missing_focus.join("\n  - ")}\n\n" \
        "Add these to tailwind-input.css in the 'Focus variants' section."
    end
  end
end
