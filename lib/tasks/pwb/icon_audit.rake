# frozen_string_literal: true

namespace :pwb do
  namespace :icons do
    desc "Audit icon usage across templates and find potential issues"
    task audit: :environment do
      puts "\n🔍 Auditing Icon Usage..."
      puts "=" * 60

      # Load the IconHelper to access ALLOWED_ICONS
      include Pwb::IconHelper

      used_icons = Set.new
      unknown_icons = Set.new
      brand_icons_used = Set.new
      files_with_issues = []

      # Patterns to search for - more precise to avoid false positives
      icon_patterns = [
        /\bicon\s*\(\s*:(\w+)/,                    # icon(:name) - Ruby symbol
        /\bicon\s*\(\s*['"]([a-z_]+)['"]/,         # icon("name") - Ruby string, lowercase only
        /\bicon\s*['"]([a-z_]+)['"]/,              # icon "name" - shorthand
        /<%=\s*icon\s+:(\w+)/,                     # <%= icon :name - ERB
        /\{\{\s*icon\s+['"]([a-z_]+)['"]/          # {{ icon "name" - Liquid
      ]

      brand_pattern = /\bbrand_icon\s*\(\s*:(\w+)/

      # Scan view files only (skip helpers which contain documentation/examples)
      erb_files = Dir.glob(Rails.root.join("app/**/*.erb"))
      liquid_files = Dir.glob(Rails.root.join("app/**/*.liquid"))

      # Skip icon_helper.rb itself (it contains documentation examples)
      all_files = (erb_files + liquid_files).reject { |f| f.include?("icon_helper") }

      puts "\n📁 Scanning #{all_files.count} files..."

      all_files.each do |file|
        content = File.read(file)
        file_issues = []

        # Find icon usages
        icon_patterns.each do |pattern|
          content.scan(pattern).flatten.each do |icon_name|
            next if icon_name.blank?

            # Normalize the icon name
            normalized = normalize_icon_name(icon_name)
            used_icons << normalized

            unless Pwb::IconHelper::ALLOWED_ICONS.include?(normalized)
              unknown_icons << { original: icon_name, normalized: normalized, file: file }
              file_issues << "Unknown icon: #{icon_name} (→ #{normalized})"
            end
          end
        end

        # Find brand icon usages
        content.scan(brand_pattern).flatten.each do |brand_name|
          next if brand_name.blank?

          brand_name = brand_name.downcase
          brand_icons_used << brand_name

          unless Pwb::IconHelper::ALLOWED_BRANDS.include?(brand_name)
            file_issues << "Unknown brand: #{brand_name}"
          end
        end

        if file_issues.any?
          relative_path = file.sub(Rails.root.to_s + "/", "")
          files_with_issues << { file: relative_path, issues: file_issues }
        end
      end

      # Report: Used icons
      puts "\n📊 Icon Usage Summary"
      puts "-" * 40
      puts "   Total unique icons used: #{used_icons.count}"
      puts "   Total icons in ALLOWED_ICONS: #{Pwb::IconHelper::ALLOWED_ICONS.count}"

      # Report: Unused icons in ALLOWED_ICONS
      unused_icons = Pwb::IconHelper::ALLOWED_ICONS - used_icons.to_a
      if unused_icons.any?
        puts "\n⚠️  Unused icons in ALLOWED_ICONS (#{unused_icons.count}):"
        unused_icons.sort.each_slice(6) do |icons|
          puts "   #{icons.join(', ')}"
        end
      end

      # Report: Unknown icons
      if unknown_icons.any?
        puts "\n❌ Unknown icons found (#{unknown_icons.count}):"
        unknown_icons.group_by { |i| i[:normalized] }.each do |normalized, occurrences|
          files = occurrences.map { |o| o[:file].sub(Rails.root.to_s + "/", "") }.uniq
          puts "   • #{normalized}"
          files.first(3).each { |f| puts "     └─ #{f}" }
          puts "     └─ ... and #{files.count - 3} more" if files.count > 3
        end
      else
        puts "\n✅ All icons are recognized!"
      end

      # Report: Brand icons
      puts "\n🏷️  Brand Icons Used:"
      if brand_icons_used.any?
        brand_icons_used.sort.each { |b| puts "   • #{b}" }
      else
        puts "   (none found)"
      end

      # Report: Files with issues
      if files_with_issues.any?
        puts "\n📝 Files with issues (#{files_with_issues.count}):"
        files_with_issues.each do |item|
          puts "   #{item[:file]}"
          item[:issues].each { |issue| puts "      ⚠️  #{issue}" }
        end
      end

      puts "\n" + "=" * 60
      puts "💡 Tips:"
      puts "   • Add missing icons to ALLOWED_ICONS in app/helpers/pwb/icon_helper.rb"
      puts "   • Browse Material Symbols: https://fonts.google.com/icons"
      puts "   • Consider removing unused icons to reduce the allowlist"
    end

    desc "List all allowed icons"
    task list: :environment do
      puts "\n📋 Allowed Material Icons (#{Pwb::IconHelper::ALLOWED_ICONS.count}):"
      puts "-" * 40

      Pwb::IconHelper::ALLOWED_ICONS.sort.each_slice(5) do |icons|
        puts "   #{icons.join(', ')}"
      end

      puts "\n🏷️  Allowed Brand Icons (#{Pwb::IconHelper::ALLOWED_BRANDS.count}):"
      puts "-" * 40
      puts "   #{Pwb::IconHelper::ALLOWED_BRANDS.sort.join(', ')}"
    end

    desc "Check if specific icons are valid"
    task :check, [:icons] => :environment do |_t, args|
      icons = args[:icons]&.split(",")&.map(&:strip) || []

      if icons.empty?
        puts "Usage: rails pwb:icons:check[icon1,icon2,icon3]"
        exit 1
      end

      include Pwb::IconHelper

      puts "\n🔍 Checking icons..."
      puts "-" * 40

      icons.each do |icon|
        normalized = normalize_icon_name(icon)
        if Pwb::IconHelper::ALLOWED_ICONS.include?(normalized)
          if normalized != icon
            puts "   ✅ #{icon} → #{normalized} (alias)"
          else
            puts "   ✅ #{icon}"
          end
        else
          puts "   ❌ #{icon} (not found)"
        end
      end
    end
  end
end
