# frozen_string_literal: true

namespace :icons do
  desc "Audit codebase for non-Material icon usage (Font Awesome, Phosphor, etc.)"
  task audit: :environment do
    require "find"

    puts "=" * 60
    puts "Icon Audit Report"
    puts "=" * 60
    puts

    patterns = {
      "Font Awesome (fa fa-*)" => /\bfa\s+fa-\w+/,
      "Font Awesome Solid (fas fa-*)" => /\bfas\s+fa-\w+/,
      "Font Awesome Brands (fab fa-*)" => /\bfab\s+fa-\w+/,
      "Phosphor Icons (ph ph-*)" => /\bph\s+ph-\w+/,
      "Glyphicons" => /\bglyphicon-\w+/,
      "Material Design Iconic (zmdi)" => /\bzmdi-\w+/
    }

    results = Hash.new { |h, k| h[k] = [] }
    total_instances = 0

    extensions = %w[.erb .html .liquid .rb .yml .yaml .js .jsx .ts .tsx]
    search_dirs = [
      Rails.root.join("app"),
      Rails.root.join("db"),
      Rails.root.join("lib"),
      Rails.root.join("config")
    ]

    search_dirs.each do |base_dir|
      next unless base_dir.exist?

      Find.find(base_dir) do |path|
        # Skip unwanted directories
        if File.directory?(path)
          Find.prune if path.include?("node_modules") || path.include?(".git")
          next
        end

        next unless extensions.include?(File.extname(path))

        content = File.read(path, encoding: "UTF-8")

        patterns.each do |name, pattern|
          matches = content.scan(pattern)
          next if matches.empty?

          relative_path = Pathname.new(path).relative_path_from(Rails.root).to_s
          results[name] << {
            file: relative_path,
            count: matches.length,
            examples: matches.uniq.first(3)
          }
          total_instances += matches.length
        end
      rescue ArgumentError => e
        # Skip binary files
        next if e.message.include?("invalid byte sequence")
      end
    end

    if results.empty?
      puts "No forbidden icon patterns found! Your codebase is clean."
      puts
      puts "Use the icon(:name) helper for all icons."
      puts "See: docs/architecture/MATERIAL_ICONS_MIGRATION_PLAN.md"
    else
      results.each do |icon_type, files|
        puts "-" * 60
        puts "#{icon_type}: #{files.sum { |f| f[:count] }} instances in #{files.length} files"
        puts "-" * 60

        files.sort_by { |f| -f[:count] }.each do |file|
          puts "  #{file[:file]} (#{file[:count]} instances)"
          puts "    Examples: #{file[:examples].join(', ')}" if file[:examples].any?
        end
        puts
      end

      puts "=" * 60
      puts "TOTAL: #{total_instances} instances to migrate"
      puts "=" * 60
      puts
      puts "Run `rake icons:migrate_templates` to auto-fix template files."
      puts "Run `rake icons:migrate_database` to update database records."
    end
  end

  desc "Show icon mapping from legacy to Material Icons"
  task mapping: :environment do
    mappings = {
      "Navigation" => {
        "fa-home / ph-house" => "home",
        "fa-search / ph-magnifying-glass" => "search",
        "fa-chevron-left / ph-caret-left" => "chevron_left",
        "fa-chevron-right / ph-caret-right" => "chevron_right",
        "fa-chevron-down" => "expand_more",
        "fa-chevron-up" => "expand_less",
        "fa-bars" => "menu",
        "fa-times" => "close",
        "fa-expand / ph-arrows-out" => "fullscreen"
      },
      "Property Features" => {
        "fa-bed / ph-bed" => "bed",
        "fa-bath / ph-bathtub" => "bathroom",
        "fa-shower / ph-shower" => "shower",
        "fa-car / ph-car" => "directions_car",
        "fa-images" => "photo_library"
      },
      "Contact" => {
        "fa-phone / ph-phone" => "phone",
        "fa-envelope / ph-envelope" => "email",
        "fa-user / ph-user" => "person",
        "fa-map-marker-alt / ph-map-pin" => "location_on",
        "fa-globe" => "public"
      },
      "Actions" => {
        "fa-edit / fa-pencil" => "edit",
        "fa-check / ph-check" => "check",
        "fa-star / ph-star" => "star",
        "fa-filter" => "filter_list",
        "fa-sign-out-alt" => "logout"
      },
      "Other" => {
        "fa-info-circle / ph-info" => "info",
        "fa-lock / ph-lock" => "lock",
        "fa-key / ph-key" => "key",
        "fa-money / ph-hand-coins" => "attach_money",
        "fa-quote-left" => "format_quote",
        "fa-spinner" => "sync"
      }
    }

    puts "=" * 70
    puts "Icon Mapping: Legacy -> Material Icons"
    puts "=" * 70
    puts

    mappings.each do |category, icons|
      puts "#{category}:"
      puts "-" * 50
      icons.each do |old, new|
        puts "  #{old.ljust(35)} -> #{new}"
      end
      puts
    end

    puts "For brand icons (Facebook, Instagram, etc.), use:"
    puts "  <%= brand_icon(:facebook) %>"
    puts
    puts "Full mapping in: app/helpers/pwb/icon_helper.rb (ICON_ALIASES)"
  end

  desc "Update database icon_class values to Material Icons"
  task migrate_database: :environment do
    icon_map = {
      # Font Awesome to Material
      "fa fa-facebook" => "facebook",
      "fa fa-facebook-f" => "facebook",
      "fa fa-instagram" => "instagram",
      "fa fa-linkedin" => "linkedin",
      "fa fa-linkedin-in" => "linkedin",
      "fa fa-youtube" => "youtube",
      "fa fa-twitter" => "twitter",
      "fa fa-x-twitter" => "x",
      "fa fa-whatsapp" => "whatsapp",
      "fa fa-pinterest" => "pinterest",
      "fa fa-home" => "home",
      "fa fa-user" => "person",
      "fa fa-envelope" => "email",
      "fa fa-phone" => "phone",
      "fa fa-map-marker-alt" => "location_on",
      "fa fa-search" => "search",
      "fa fa-check" => "check",
      "fa fa-bed" => "bed",
      "fa fa-bath" => "bathroom",
      "fa fa-car" => "directions_car",
      "fa fa-money" => "attach_money",
      "fa fa-key" => "key",
      "fa fa-globe" => "public",
      "fa fa-star" => "star",
      # Phosphor to Material
      "ph ph-house" => "home",
      "ph ph-house-line" => "home",
      "ph ph-user" => "person",
      "ph ph-envelope" => "email",
      "ph ph-phone" => "phone",
      "ph ph-map-pin" => "location_on",
      "ph ph-magnifying-glass" => "search",
      "ph ph-check" => "check",
      "ph ph-bed" => "bed",
      "ph ph-bathtub" => "bathroom",
      "ph ph-car" => "directions_car",
      "ph ph-hand-coins" => "payments",
      "ph ph-key" => "key"
    }.freeze

    puts "Migrating database icon_class values..."
    puts

    # Migrate Link model
    if defined?(Pwb::Link)
      updated = 0
      skipped = 0

      Pwb::Link.find_each do |link|
        next unless link.icon_class.present?

        new_class = icon_map[link.icon_class]
        if new_class
          puts "  Link ##{link.id}: '#{link.icon_class}' -> '#{new_class}'"
          link.update_column(:icon_class, new_class)
          updated += 1
        elsif link.icon_class.match?(/^(fa|ph)\s/)
          puts "  WARNING: Unknown icon class on Link ##{link.id}: '#{link.icon_class}'"
          skipped += 1
        end
      end

      puts
      puts "Links: #{updated} updated, #{skipped} skipped (unknown patterns)"
    end

    # Migrate PagePart block_contents with icon values
    if defined?(Pwb::PagePart)
      updated = 0

      Pwb::PagePart.find_each do |page_part|
        next unless page_part.block_contents.is_a?(Hash)

        changed = false
        contents = page_part.block_contents.deep_dup

        # Check all icon keys in block_contents
        icon_keys = %w[feature_1_icon feature_2_icon feature_3_icon icon]

        # Check top-level and locale-nested structures
        ([""] + %w[en es de fr nl it pt tr]).each do |locale|
          target = locale.empty? ? contents : contents.dig(locale, "blocks")
          next unless target.is_a?(Hash)

          icon_keys.each do |key|
            if target[key].is_a?(Hash) && target[key]["content"].present?
              old_value = target[key]["content"]
              new_value = icon_map[old_value]
              if new_value
                target[key]["content"] = new_value
                changed = true
                puts "  PagePart ##{page_part.id} (#{locale.presence || 'root'}): '#{old_value}' -> '#{new_value}'"
              end
            elsif target[key].is_a?(String)
              old_value = target[key]
              new_value = icon_map[old_value]
              if new_value
                target[key] = new_value
                changed = true
                puts "  PagePart ##{page_part.id} (#{locale.presence || 'root'}): '#{old_value}' -> '#{new_value}'"
              end
            end
          end
        end

        if changed
          page_part.update_column(:block_contents, contents)
          updated += 1
        end
      end

      puts
      puts "PageParts: #{updated} updated"
    end

    puts
    puts "Database migration complete!"
    puts "Remember to clear Rails cache: rails tmp:cache:clear"
  end

  desc "Automatically migrate icon patterns in ERB templates"
  task migrate_templates: :environment do
    require "find"

    # Icon mappings for auto-replacement
    replacements = {
      # Font Awesome to Material (for ERB files, we use the icon helper)
      # Simple icon patterns
      '<i class="fa fa-home"' => '<%= icon(:home) %>',
      '<i class="fa fa-search"' => '<%= icon(:search) %>',
      '<i class="fa fa-user"' => '<%= icon(:person) %>',
      '<i class="fa fa-envelope"' => '<%= icon(:email) %>',
      '<i class="fa fa-phone"' => '<%= icon(:phone) %>',
      '<i class="fa fa-check"' => '<%= icon(:check) %>',
      '<i class="fa fa-bed"' => '<%= icon(:bed) %>',
      '<i class="fa fa-bath"' => '<%= icon(:bathroom) %>',
      '<i class="fa fa-shower"' => '<%= icon(:shower) %>',
      '<i class="fa fa-star"' => '<%= icon(:star) %>',
      '<i class="fa fa-bars"' => '<%= icon(:menu) %>',
      '<i class="fa fa-times"' => '<%= icon(:close) %>',
      '<i class="fa fa-expand"' => '<%= icon(:fullscreen) %>',
      '<i class="fa fa-filter"' => '<%= icon(:filter_list) %>',
      '<i class="fa fa-refresh"' => '<%= icon(:refresh) %>',
      '<i class="fa fa-pencil"' => '<%= icon(:edit) %>',
      '<i class="fa fa-map-marker"' => '<%= icon(:location_on) %>',
      '<i class="fa fa-globe"' => '<%= icon(:public) %>',
      '<i class="fa fa-arrows-alt"' => '<%= icon(:fullscreen) %>',
      '<i class="fa fa-angle-left"' => '<%= icon(:chevron_left) %>',
      '<i class="fa fa-angle-right"' => '<%= icon(:chevron_right) %>',
      '<i class="fa fa-external-link"' => '<%= icon(:open_in_new) %>',
      '<i class="fa fa-info-circle"' => '<%= icon(:info) %>',
      # Brand icons
      '<i class="fa fa-facebook"' => '<%= brand_icon(:facebook) %>',
      '<i class="fa fa-instagram"' => '<%= brand_icon(:instagram) %>',
      '<i class="fa fa-linkedin"' => '<%= brand_icon(:linkedin) %>',
      '<i class="fa fa-youtube"' => '<%= brand_icon(:youtube) %>',
      '<i class="fa fa-twitter"' => '<%= brand_icon(:x) %>',
      '<i class="fa fa-whatsapp"' => '<%= brand_icon(:whatsapp) %>',
      '<i class="fab fa-facebook"' => '<%= brand_icon(:facebook) %>',
      '<i class="fab fa-x-twitter"' => '<%= brand_icon(:x) %>',
      '<i class="fab fa-instagram"' => '<%= brand_icon(:instagram) %>',
      '<i class="fab fa-linkedin"' => '<%= brand_icon(:linkedin) %>',
      '<i class="fab fa-youtube"' => '<%= brand_icon(:youtube) %>',
      '<i class="fab fa-whatsapp"' => '<%= brand_icon(:whatsapp) %>'
    }

    # Files to process
    extensions = %w[.erb .html.erb]
    search_dirs = [
      Rails.root.join("app/views"),
      Rails.root.join("app/themes")
    ]

    updated_files = 0
    total_replacements = 0

    search_dirs.each do |base_dir|
      next unless base_dir.exist?

      Find.find(base_dir) do |path|
        if File.directory?(path)
          Find.prune if path.include?("node_modules")
          next
        end

        next unless extensions.any? { |ext| path.end_with?(ext) }

        content = File.read(path, encoding: "UTF-8")
        original_content = content.dup
        file_replacements = 0

        replacements.each do |old_pattern, new_pattern|
          if content.include?(old_pattern)
            # Handle patterns that might have closing tags or additional attributes
            count = content.scan(Regexp.escape(old_pattern)).count
            # Replace the opening tag - the closing might still need manual attention
            content = content.gsub(/#{Regexp.escape(old_pattern)}[^>]*><\/i>/) do |match|
              file_replacements += 1
              new_pattern
            end
            # Also handle patterns that might have aria-hidden
            content = content.gsub(/#{Regexp.escape(old_pattern)}[^>]*>/) do |match|
              if match.end_with?("></i>")
                new_pattern
              else
                match
              end
            end
          end
        end

        if content != original_content
          File.write(path, content)
          relative_path = Pathname.new(path).relative_path_from(Rails.root).to_s
          puts "  Updated: #{relative_path} (#{file_replacements} replacements)"
          updated_files += 1
          total_replacements += file_replacements
        end
      rescue ArgumentError => e
        next if e.message.include?("invalid byte sequence")
      end
    end

    puts
    puts "=" * 60
    puts "Template migration complete!"
    puts "Updated #{updated_files} files with #{total_replacements} replacements"
    puts "=" * 60
    puts
    puts "NOTE: Some patterns may require manual review."
    puts "Run `rake icons:audit` to check remaining instances."
  end

  desc "Check for forbidden icon patterns (used in CI)"
  task check: :environment do
    require "find"

    patterns = [
      /\bfa\s+fa-\w+/,
      /\bfas\s+fa-\w+/,
      /\bfab\s+fa-\w+/,
      /\bph\s+ph-\w+/,
      /\bglyphicon-\w+/
    ]

    violations = []
    extensions = %w[.erb .html .liquid .rb .yml .yaml]

    [Rails.root.join("app"), Rails.root.join("db")].each do |base_dir|
      next unless base_dir.exist?

      Find.find(base_dir) do |path|
        if File.directory?(path)
          Find.prune if path.include?("node_modules")
          next
        end

        next unless extensions.include?(File.extname(path))

        content = File.read(path, encoding: "UTF-8")
        line_number = 0

        content.each_line do |line|
          line_number += 1
          patterns.each do |pattern|
            if line.match?(pattern)
              relative_path = Pathname.new(path).relative_path_from(Rails.root).to_s
              violations << "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end
        end
      rescue ArgumentError
        next
      end
    end

    if violations.any?
      puts "ERROR: Forbidden icon patterns found!"
      puts
      violations.each { |v| puts v }
      puts
      puts "Use icon(:name) helper instead of inline icon classes."
      puts "See: docs/architecture/MATERIAL_ICONS_MIGRATION_PLAN.md"
      exit 1
    else
      puts "No forbidden icon patterns found."
      exit 0
    end
  end
end
