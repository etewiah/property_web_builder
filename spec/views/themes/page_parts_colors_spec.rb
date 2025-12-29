# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Page Parts Color System", type: :view do
  let(:page_parts_dir) { Rails.root.join("db/yml_seeds/page_parts") }
  let(:page_part_files) { Dir.glob("#{page_parts_dir}/*.yml") }

  # Hardcoded color patterns that should NOT appear in page_parts
  # These should be replaced with PWB semantic color classes
  FORBIDDEN_COLOR_PATTERNS = [
    # Hardcoded gray shades - use pwb-secondary instead
    /\btext-gray-\d+\b/,
    /\bbg-gray-\d+\b/,
    /\bborder-gray-\d+\b/,

    # Hardcoded amber/orange - use pwb-accent instead
    /\btext-amber-\d+\b/,
    /\bbg-amber-\d+\b/,
    /\btext-orange-\d+\b/,
    /\bbg-orange-\d+\b/,

    # Non-prefixed primary/secondary (ambiguous, could conflict with other frameworks)
    /\btext-primary\b(?!-)/,
    /\bbg-primary\b(?!-)/,
    /\btext-secondary\b(?!-)/,
    /\bbg-secondary\b(?!-)/,

    # Hardcoded blue shades - use pwb-primary instead
    /\btext-blue-\d+\b/,
    /\bbg-blue-\d+\b/,

    # Hardcoded slate/zinc - use pwb-secondary instead
    /\btext-slate-\d+\b/,
    /\bbg-slate-\d+\b/,
    /\btext-zinc-\d+\b/,
    /\bbg-zinc-\d+\b/
  ].freeze

  # Allowed patterns - these are semantic PWB colors
  ALLOWED_PATTERNS = [
    /pwb-primary/,
    /pwb-secondary/,
    /pwb-accent/
  ].freeze

  describe "page_parts use PWB color system" do
    it "does not use hardcoded gray colors" do
      violations = []

      page_part_files.each do |file|
        content = File.read(file)
        filename = File.basename(file)

        FORBIDDEN_COLOR_PATTERNS.each do |pattern|
          matches = content.scan(pattern)
          if matches.any?
            violations << "#{filename}: #{matches.uniq.join(', ')}"
          end
        end
      end

      expect(violations).to be_empty,
        "Page parts should use PWB semantic colors (pwb-primary, pwb-secondary, pwb-accent) " \
        "instead of hardcoded Tailwind colors.\n\nViolations found:\n#{violations.join("\n")}"
    end

    it "uses PWB semantic color classes when using Tailwind color utilities" do
      files_without_pwb_colors = []

      # Patterns that indicate actual Tailwind color utilities (not custom CSS class names)
      tailwind_color_patterns = [
        /\b(?:text|bg|border)-(?:gray|slate|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-\d+\b/,
        /\b(?:text|bg|border)-(?:primary|secondary|accent)\b(?!-)/
      ]

      page_part_files.each do |file|
        content = File.read(file)
        filename = File.basename(file)

        # Skip files that don't have templates (e.g., empty or config-only)
        next unless content.include?("template:")

        has_pwb_colors = ALLOWED_PATTERNS.any? { |pattern| content.match?(pattern) }
        has_tailwind_colors = tailwind_color_patterns.any? { |pattern| content.match?(pattern) }

        # If the template uses Tailwind color utilities, it should use PWB colors
        if has_tailwind_colors && !has_pwb_colors
          files_without_pwb_colors << filename
        end
      end

      expect(files_without_pwb_colors).to be_empty,
        "Page parts with Tailwind color utilities should use PWB semantic colors.\n" \
        "Files without PWB colors: #{files_without_pwb_colors.join(', ')}"
    end
  end

  describe "color class consistency" do
    it "uses consistent shade scales" do
      # Check that page_parts use the defined PWB shade scale
      # Valid shades: 50, 100, 200, 300, 400, 500, 600, 700, 800, 900
      valid_shades = %w[50 100 200 300 400 500 600 700 800 900]
      invalid_shade_usages = []

      page_part_files.each do |file|
        content = File.read(file)
        filename = File.basename(file)

        # Find all pwb color usages with shade numbers
        content.scan(/pwb-(?:primary|secondary|accent)-(\d+)/).flatten.each do |shade|
          unless valid_shades.include?(shade)
            invalid_shade_usages << "#{filename}: invalid shade -#{shade}"
          end
        end
      end

      expect(invalid_shade_usages).to be_empty,
        "Invalid PWB color shades found:\n#{invalid_shade_usages.join("\n")}"
    end
  end
end
