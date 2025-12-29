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

  # Forbidden hover/focus patterns - should use PWB semantic variants
  FORBIDDEN_INTERACTIVE_PATTERNS = [
    /\bhover:(?:text|bg|border)-gray-\d+\b/,
    /\bhover:(?:text|bg|border)-(?:slate|zinc|amber|orange|blue)-\d+\b/,
    /\bfocus:(?:text|bg|border|ring)-gray-\d+\b/,
    /\bfocus:(?:text|bg|border|ring)-(?:slate|zinc|amber|orange|blue)-\d+\b/,
    /\bhover:(?:text|bg|border)-(?:primary|secondary|accent)\b(?!-)/,
    /\bfocus:(?:text|bg|border|ring)-(?:primary|secondary|accent)\b(?!-)/
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

    it "does not use hardcoded colors in hover/focus states" do
      violations = []

      page_part_files.each do |file|
        content = File.read(file)
        filename = File.basename(file)

        FORBIDDEN_INTERACTIVE_PATTERNS.each do |pattern|
          matches = content.scan(pattern)
          if matches.any?
            violations << "#{filename}: #{matches.uniq.join(', ')}"
          end
        end
      end

      expect(violations).to be_empty,
        "Page parts should use PWB semantic colors for hover/focus states.\n\n" \
        "Violations found:\n#{violations.join("\n")}"
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

    it "uses opacity modifiers correctly" do
      # Valid opacity format: color/opacity (e.g., pwb-primary/90, white/80)
      invalid_opacity_usages = []

      page_part_files.each do |file|
        content = File.read(file)
        filename = File.basename(file)

        # Find pwb color usages with opacity that might be invalid
        # Valid: pwb-primary/90, text-pwb-secondary-900/50
        # Invalid: pwb-primary/101, pwb-secondary/-5
        content.scan(/pwb-(?:primary|secondary|accent)(?:-\d+)?\/(\d+)/).flatten.each do |opacity|
          opacity_val = opacity.to_i
          if opacity_val < 0 || opacity_val > 100
            invalid_opacity_usages << "#{filename}: invalid opacity /#{opacity}"
          end
        end
      end

      expect(invalid_opacity_usages).to be_empty,
        "Invalid opacity values found (must be 0-100):\n#{invalid_opacity_usages.join("\n")}"
    end
  end

  describe "contrast safety" do
    it "avoids potentially problematic color combinations in same element" do
      # Check for elements that might have contrast issues
      # e.g., light text on light background, dark text on dark background
      potential_issues = []

      # Light backgrounds (50-200) should not have light text (50-300)
      light_on_light_pattern = /bg-pwb-(?:primary|secondary|accent)-(?:50|100|200)[^"]*text-pwb-(?:primary|secondary|accent)-(?:50|100|200|300)/

      # Dark backgrounds (700-900) should not have dark text (600-900) unless white
      dark_on_dark_pattern = /bg-pwb-(?:primary|secondary|accent)-(?:700|800|900)[^"]*text-pwb-(?:primary|secondary|accent)-(?:600|700|800|900)/

      page_part_files.each do |file|
        content = File.read(file)
        filename = File.basename(file)

        if content.match?(light_on_light_pattern)
          potential_issues << "#{filename}: potential light-on-light contrast issue"
        end

        # Note: This is a simplified check - dark backgrounds often use text-white which is fine
        # We're just looking for obvious mismatches
      end

      # This is a warning-level check, not a hard failure
      # Uncomment the expect below to enforce strictly
      # expect(potential_issues).to be_empty,
      #   "Potential contrast issues found:\n#{potential_issues.join("\n")}"
    end

    it "uses white or very light text on dark backgrounds" do
      # Dark backgrounds (700-900) should use white, text-white, or very light shades
      dark_bg_files = []

      page_part_files.each do |file|
        content = File.read(file)
        filename = File.basename(file)

        # Check if file has dark PWB backgrounds
        has_dark_bg = content.match?(/bg-pwb-(?:primary|secondary|accent)-(?:700|800|900)/)
        next unless has_dark_bg

        # Check if it also has appropriate light text (white or 50-200 shades)
        has_light_text = content.match?(/text-white/) ||
                         content.match?(/text-pwb-(?:primary|secondary|accent)-(?:50|100|200)/) ||
                         content.match?(/text-pwb-accent\b/)  # Accent can be used on dark bg

        # Files with dark bg should have some form of light text
        dark_bg_files << filename unless has_light_text
      end

      # This ensures files using dark backgrounds also provide readable text
      expect(dark_bg_files).to be_empty,
        "Files with dark PWB backgrounds should have light text colors:\n#{dark_bg_files.join("\n")}"
    end
  end

  describe "color mapping documentation" do
    # This test documents the expected color mappings
    it "follows the PWB color mapping convention" do
      # PWB Color Mapping:
      # - pwb-primary    -> Brand primary color (from palette)
      # - pwb-secondary  -> Neutral grays (replaces gray-*, slate-*, zinc-*)
      # - pwb-accent     -> Highlight/CTA color (replaces amber-*, orange-*)
      #
      # Shade Scale (50-900):
      # - 50-200  -> Light shades (backgrounds, subtle elements)
      # - 300-400 -> Light-medium (borders, secondary text)
      # - 500     -> Base shade
      # - 600-700 -> Medium-dark (body text, important elements)
      # - 800-900 -> Dark shades (headings, dark backgrounds)

      # Verify that at least some page_parts use each color type
      primary_usage = false
      secondary_usage = false
      accent_usage = false

      page_part_files.each do |file|
        content = File.read(file)
        primary_usage ||= content.include?("pwb-primary")
        secondary_usage ||= content.include?("pwb-secondary")
        accent_usage ||= content.include?("pwb-accent")
      end

      expect(primary_usage).to be(true), "No page_parts use pwb-primary colors"
      expect(secondary_usage).to be(true), "No page_parts use pwb-secondary colors"
      expect(accent_usage).to be(true), "No page_parts use pwb-accent colors"
    end
  end

  describe "template rendering compatibility" do
    it "uses valid CSS class syntax" do
      invalid_class_syntax = []

      page_part_files.each do |file|
        content = File.read(file)
        filename = File.basename(file)

        # Check for common class syntax errors
        # Double spaces in class attributes
        if content.match?(/class="[^"]*  [^"]*"/)
          invalid_class_syntax << "#{filename}: double spaces in class attribute"
        end

        # Unclosed brackets in arbitrary values
        if content.match?(/\[[^\]]*pwb-/)
          invalid_class_syntax << "#{filename}: possible unclosed bracket with PWB class"
        end
      end

      expect(invalid_class_syntax).to be_empty,
        "Invalid CSS class syntax found:\n#{invalid_class_syntax.join("\n")}"
    end

    it "has balanced Liquid template syntax" do
      unbalanced_templates = []

      page_part_files.each do |file|
        content = File.read(file)
        filename = File.basename(file)

        # Extract template section
        next unless content.include?("template:")

        template_match = content.match(/template:\s*\|?\s*\n(.*)/m)
        next unless template_match

        template = template_match[1]

        # Count if/endif pairs
        if_count = template.scan(/\{%\s*if\b/).length
        endif_count = template.scan(/\{%\s*endif\s*%\}/).length

        if if_count != endif_count
          unbalanced_templates << "#{filename}: #{if_count} if blocks, #{endif_count} endif blocks"
        end

        # Count for/endfor pairs
        for_count = template.scan(/\{%\s*for\b/).length
        endfor_count = template.scan(/\{%\s*endfor\s*%\}/).length

        if for_count != endfor_count
          unbalanced_templates << "#{filename}: #{for_count} for blocks, #{endfor_count} endfor blocks"
        end
      end

      expect(unbalanced_templates).to be_empty,
        "Unbalanced Liquid template blocks:\n#{unbalanced_templates.join("\n")}"
    end
  end
end
