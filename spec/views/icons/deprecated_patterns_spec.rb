# frozen_string_literal: true

require 'rails_helper'

# This spec ensures deprecated icon patterns are not reintroduced to the codebase.
# It scans templates for old <i class=""> patterns that should use the new icon system.
#
# Approved icon patterns:
# - ERB: <%= icon(:name) %>
# - Liquid: {{ "name" | material_icon }}
# - Liquid: {{ variable | material_icon: "size" }}
#
# Deprecated patterns that should NOT be used:
# - <i class="fa fa-*">
# - <i class="ph ph-*">
# - <i class="{{ variable }}">
# - Direct <span class="material-symbols-outlined"> without helper
#
# Note: Admin areas (editor, site_admin, tenant_admin) are excluded as they
# may still use Font Awesome for the drag-and-drop editor components.
# The focus is on public-facing templates and themes.
#
RSpec.describe 'Deprecated Icon Patterns', type: :view do
  # Patterns that indicate old icon usage
  DEPRECATED_PATTERNS = [
    # Font Awesome patterns
    { pattern: /<i\s+class=["']fa\s+fa-/, description: 'Font Awesome <i class="fa fa-*">' },
    { pattern: /<i\s+class=["']fas\s+fa-/, description: 'Font Awesome Solid <i class="fas fa-*">' },
    { pattern: /<i\s+class=["']fab\s+fa-/, description: 'Font Awesome Brands <i class="fab fa-*">' },

    # Phosphor patterns
    { pattern: /<i\s+class=["']ph\s+ph-/, description: 'Phosphor Icons <i class="ph ph-*">' }

    # Note: Dynamic class without filter is checked separately for Liquid templates
  ].freeze

  # YAML embedded templates need special handling for icon patterns
  YAML_DEPRECATED_PATTERNS = [
    # Old pattern: <i class="{{ page_part["icon"]["content"] }}">
    { pattern: /<i class="\{\{ page_part\[/, description: 'Page part icon without material_icon filter in YAML template' }
  ].freeze

  # Directories to exclude from checks (admin areas that still need Font Awesome)
  EXCLUDED_PATHS = [
    'app/views/pwb/editor/',
    'app/views/site_admin/',
    'app/views/tenant_admin/',
    'app/views/layouts/pwb/devise',
    'app/views/layouts/pwb/page_part'
  ].freeze

  def excluded?(file)
    EXCLUDED_PATHS.any? { |path| file.include?(path) }
  end

  describe 'ERB templates (public-facing)' do
    let(:erb_files) do
      (Dir.glob(Rails.root.join('app/views/**/*.erb')) +
        Dir.glob(Rails.root.join('app/themes/**/*.erb')))
        .reject { |f| excluded?(f) }
    end

    DEPRECATED_PATTERNS.each do |check|
      it "does not contain #{check[:description]}" do
        violations = []

        erb_files.each do |file|
          content = File.read(file)
          if content.match?(check[:pattern])
            matches = content.scan(check[:pattern])
            violations << { file: file.sub(Rails.root.to_s + '/', ''), matches: matches.size }
          end
        end

        if violations.any?
          failure_message = "Found #{check[:description]} in:\n"
          violations.each { |v| failure_message += "  - #{v[:file]} (#{v[:matches]} occurrences)\n" }
          failure_message += "\nUse <%= icon(:name) %> helper instead."
          fail failure_message
        end
      end
    end
  end

  describe 'Liquid templates' do
    let(:liquid_files) do
      Dir.glob(Rails.root.join('app/views/**/*.liquid')) +
        Dir.glob(Rails.root.join('app/themes/**/*.liquid'))
    end

    DEPRECATED_PATTERNS.each do |check|
      it "does not contain #{check[:description]}" do
        violations = []

        liquid_files.each do |file|
          content = File.read(file)
          if content.match?(check[:pattern])
            matches = content.scan(check[:pattern])
            violations << { file: file.sub(Rails.root.to_s + '/', ''), matches: matches.size }
          end
        end

        if violations.any?
          failure_message = "Found #{check[:description]} in:\n"
          violations.each { |v| failure_message += "  - #{v[:file]} (#{v[:matches]} occurrences)\n" }
          failure_message += "\nUse {{ \"name\" | material_icon }} filter instead."
          fail failure_message
        end
      end
    end

    it 'does not use dynamic <i class="{{ }}"> without material_icon filter' do
      violations = []
      # Pattern: <i class="{{ something }}"></i> without material_icon
      pattern = /<i\s+class=["']\{\{[^}|]+\}\}["']>/

      liquid_files.each do |file|
        content = File.read(file)
        # Only flag if it doesn't have material_icon nearby
        lines = content.lines
        lines.each_with_index do |line, idx|
          if line.match?(pattern) && !line.include?('material_icon')
            violations << { file: file.sub(Rails.root.to_s + '/', ''), line: idx + 1, content: line.strip }
          end
        end
      end

      if violations.any?
        failure_message = "Found dynamic <i class=\"{{ }}\"> without material_icon filter:\n"
        violations.each { |v| failure_message += "  - #{v[:file]}:#{v[:line]}: #{v[:content]}\n" }
        failure_message += "\nUse {{ variable | material_icon }} filter instead."
        fail failure_message
      end
    end
  end

  describe 'YAML seed templates' do
    let(:yaml_files) do
      Dir.glob(Rails.root.join('db/yml_seeds/page_parts/*.yml'))
    end

    YAML_DEPRECATED_PATTERNS.each do |check|
      it "does not contain #{check[:description]}" do
        violations = []

        yaml_files.each do |file|
          content = File.read(file)
          if content.match?(check[:pattern])
            matches = content.scan(check[:pattern])
            violations << { file: file.sub(Rails.root.to_s + '/', ''), matches: matches.size }
          end
        end

        if violations.any?
          failure_message = "Found #{check[:description]} in:\n"
          violations.each { |v| failure_message += "  - #{v[:file]} (#{v[:matches]} occurrences)\n" }
          failure_message += "\nUse {{ page_part[\"icon\"][\"content\"] | material_icon: \"size\" }} filter instead."
          fail failure_message
        end
      end
    end
  end

  describe 'Content translation templates' do
    let(:translation_files) do
      Dir.glob(Rails.root.join('db/yml_seeds/content_translations/*.yml'))
    end

    it 'uses material-symbols-rounded for inline icons' do
      violations = []

      translation_files.each do |file|
        content = File.read(file)
        # Check for old <i class="fa "> pattern
        if content.match?(/<i\s+class=["']fa\s+/)
          violations << file.sub(Rails.root.to_s + '/', '')
        end
        # Check for old <i class="ph "> pattern
        if content.match?(/<i\s+class=["']ph\s+/)
          violations << file.sub(Rails.root.to_s + '/', '')
        end
      end

      if violations.any?
        failure_message = "Found deprecated icon patterns in translation files:\n"
        violations.uniq.each { |v| failure_message += "  - #{v}\n" }
        failure_message += "\nUse <span class=\"material-symbols-rounded\">icon_name</span> for inline icons."
        fail failure_message
      end
    end
  end

  describe 'Theme layouts use Material Symbols' do
    let(:theme_layout_files) do
      Dir.glob(Rails.root.join('app/themes/**/layouts/**/*.erb'))
    end

    # TODO: Remove Font Awesome stylesheet includes from theme layouts after
    # confirming all icons are migrated. This test will fail until then.
    it 'does not reference Font Awesome CDN in theme layouts', :pending do
      violations = []

      theme_layout_files.each do |file|
        content = File.read(file)
        if content.match?(/font-awesome/i) || content.match?(/fontawesome/i)
          violations << file.sub(Rails.root.to_s + '/', '')
        end
      end

      if violations.any?
        failure_message = "Found Font Awesome CDN references in theme layouts:\n"
        violations.uniq.each { |v| failure_message += "  - #{v}\n" }
        failure_message += "\nTheme layouts should use Material Symbols font."
        fail failure_message
      end
    end

    # TODO: Remove Phosphor stylesheet includes from theme layouts after
    # confirming all icons are migrated.
    it 'does not reference Phosphor in theme layouts', :pending do
      violations = []

      theme_layout_files.each do |file|
        content = File.read(file)
        if content.match?(/@phosphor-icons/i) || content.match?(/phosphor\.css/i)
          violations << file.sub(Rails.root.to_s + '/', '')
        end
      end

      if violations.any?
        failure_message = "Found Phosphor references in theme layouts:\n"
        violations.uniq.each { |v| failure_message += "  - #{v}\n" }
        failure_message += "\nTheme layouts should use Material Symbols font."
        fail failure_message
      end
    end
  end
end
