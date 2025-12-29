# frozen_string_literal: true

namespace :pwb do
  namespace :themes do
    desc "Audit palette files and config.json for inconsistencies"
    task audit_palettes: :environment do
      puts "\n🔍 Auditing Theme Palettes..."
      puts "=" * 60

      themes_path = Rails.root.join("app/themes")
      config_path = themes_path.join("config.json")
      themes_config = JSON.parse(File.read(config_path))

      issues = []
      stats = { themes: 0, palettes: 0, config_palettes: 0, legacy_keys: 0, missing_colors: 0 }

      # Required colors from schema
      required_colors = %w[
        primary_color secondary_color accent_color background_color text_color
        header_background_color header_text_color footer_background_color footer_text_color
      ]

      # Legacy keys that should be removed
      legacy_keys = %w[light_color action_color header_bg_color footer_bg_color footer_main_text_color]

      # config.json is an array of theme objects, not {"themes": [...]}
      themes_config.each do |theme|
        theme_name = theme["name"]
        stats[:themes] += 1
        puts "\n📁 Theme: #{theme_name}"

        # Check config.json palettes
        if theme["palettes"].present?
          config_palette_count = theme["palettes"].keys.count
          stats[:config_palettes] += config_palette_count
          puts "   ⚠️  config.json has #{config_palette_count} embedded palettes (should be removed)"
          issues << { theme: theme_name, issue: "config.json has #{config_palette_count} embedded palettes" }
        end

        # Check separate palette files
        palettes_dir = themes_path.join(theme_name, "palettes")
        if Dir.exist?(palettes_dir)
          Dir.glob(palettes_dir.join("*.json")).each do |file|
            stats[:palettes] += 1
            palette = JSON.parse(File.read(file))
            palette_id = palette["id"] || File.basename(file, ".json")
            colors = palette["colors"] || {}

            # Check for legacy keys
            found_legacy = colors.keys & legacy_keys
            if found_legacy.any?
              stats[:legacy_keys] += found_legacy.count
              puts "   ⚠️  #{palette_id}: Legacy keys found: #{found_legacy.join(', ')}"
              issues << { theme: theme_name, palette: palette_id, issue: "Legacy keys: #{found_legacy.join(', ')}" }
            end

            # Check for missing required colors
            missing = required_colors - colors.keys
            if missing.any?
              stats[:missing_colors] += missing.count
              puts "   ❌ #{palette_id}: Missing required: #{missing.join(', ')}"
              issues << { theme: theme_name, palette: palette_id, issue: "Missing: #{missing.join(', ')}" }
            else
              puts "   ✅ #{palette_id}: All required colors present"
            end
          end
        else
          puts "   ❌ No palettes directory found"
          issues << { theme: theme_name, issue: "No palettes directory" }
        end
      end

      puts "\n" + "=" * 60
      puts "📊 Summary:"
      puts "   Themes: #{stats[:themes]}"
      puts "   Separate palette files: #{stats[:palettes]}"
      puts "   Config.json palettes (to remove): #{stats[:config_palettes]}"
      puts "   Legacy keys found: #{stats[:legacy_keys]}"
      puts "   Missing required colors: #{stats[:missing_colors]}"
      puts "   Total issues: #{issues.count}"

      if issues.any?
        puts "\n⚠️  Run 'rails pwb:themes:migrate_palettes' to fix issues"
      else
        puts "\n✅ All palettes are clean!"
      end
    end

    desc "Migrate and clean up palette files"
    task migrate_palettes: :environment do
      puts "\n🔧 Migrating and Cleaning Palettes..."
      puts "=" * 60

      themes_path = Rails.root.join("app/themes")

      # Key mapping for standardization
      key_mapping = {
        "header_bg_color" => "header_background_color",
        "footer_bg_color" => "footer_background_color",
        "footer_main_text_color" => "footer_text_color"
      }

      # Keys to remove (non-standard)
      keys_to_remove = %w[light_color action_color]

      # Default colors for missing required fields
      default_colors = {
        "card_background_color" => "#ffffff",
        "card_text_color" => nil, # Will use text_color
        "border_color" => "#e5e7eb",
        "surface_color" => "#ffffff",
        "surface_alt_color" => "#f9fafb",
        "success_color" => "#10b981",
        "warning_color" => "#f59e0b",
        "error_color" => "#ef4444",
        "muted_text_color" => "#6b7280",
        "link_color" => nil, # Will use primary_color
        "link_hover_color" => nil # Will darken primary_color
      }

      updated_count = 0

      Dir.glob(themes_path.join("*/palettes/*.json")).each do |file|
        palette = JSON.parse(File.read(file))
        palette_id = palette["id"] || File.basename(file, ".json")
        colors = palette["colors"] || {}
        modified = false

        # 1. Map legacy keys to standard keys
        key_mapping.each do |old_key, new_key|
          if colors[old_key] && !colors[new_key]
            colors[new_key] = colors[old_key]
            colors.delete(old_key)
            modified = true
            puts "   📝 #{palette_id}: Renamed #{old_key} → #{new_key}"
          elsif colors[old_key]
            colors.delete(old_key)
            modified = true
            puts "   🗑️  #{palette_id}: Removed duplicate #{old_key}"
          end
        end

        # 2. Remove non-standard keys
        keys_to_remove.each do |key|
          if colors.delete(key)
            modified = true
            puts "   🗑️  #{palette_id}: Removed non-standard #{key}"
          end
        end

        # 3. Add smart defaults for optional colors
        default_colors.each do |key, default_value|
          next if colors[key]

          if default_value.nil?
            # Use related color
            case key
            when "card_text_color"
              colors[key] = colors["text_color"] if colors["text_color"]
            when "link_color"
              colors[key] = colors["primary_color"] if colors["primary_color"]
            when "link_hover_color"
              if colors["primary_color"]
                colors[key] = darken_color(colors["primary_color"], 15)
              end
            end
          else
            colors[key] = default_value
          end
          modified = true if colors[key]
        end

        palette["colors"] = colors

        if modified
          File.write(file, JSON.pretty_generate(palette) + "\n")
          updated_count += 1
          puts "   ✅ Updated: #{file}"
        end
      end

      puts "\n📊 Updated #{updated_count} palette files"
      puts "\nNext step: Run 'rails pwb:themes:remove_config_palettes' to clean config.json"
    end

    desc "Remove palette definitions from config.json (use separate files only)"
    task remove_config_palettes: :environment do
      puts "\n🗑️  Removing palettes from config.json..."
      puts "=" * 60

      config_path = Rails.root.join("app/themes/config.json")
      backup_path = Rails.root.join("app/themes/config.json.backup")

      # Create backup
      FileUtils.cp(config_path, backup_path)
      puts "   📦 Backup created: #{backup_path}"

      themes_config = JSON.parse(File.read(config_path))
      removed_count = 0

      # config.json is an array of theme objects
      themes_config.each do |theme|
        if theme["palettes"].present?
          count = theme["palettes"].keys.count
          theme.delete("palettes")
          removed_count += count
          puts "   🗑️  #{theme['name']}: Removed #{count} palette definitions"
        end
      end

      File.write(config_path, JSON.pretty_generate(themes_config) + "\n")

      puts "\n✅ Removed #{removed_count} palette definitions from config.json"
      puts "   Palettes are now loaded from app/themes/{theme}/palettes/*.json only"
      puts "\n   Backup saved to: #{backup_path}"
    end

    desc "Verify palette loading works correctly"
    task verify_palettes: :environment do
      puts "\n🔍 Verifying Palette Loading..."
      puts "=" * 60

      loader = Pwb::PaletteLoader.new
      errors = []

      %w[default brisbane bologna barcelona biarritz].each do |theme|
        puts "\n📁 Theme: #{theme}"
        begin
          palettes = loader.load_theme_palettes(theme)
          if palettes.empty?
            puts "   ⚠️  No palettes loaded"
            errors << "#{theme}: No palettes"
          else
            puts "   ✅ Loaded #{palettes.count} palettes"
            palettes.each do |id, data|
              colors = data["colors"] || {}
              puts "      • #{id}: #{colors.count} colors"
            end

            # Test default palette
            default = loader.get_default_palette(theme)
            if default
              puts "   ✅ Default palette: #{default['id'] || default['name']}"
            else
              puts "   ⚠️  No default palette set"
            end
          end
        rescue => e
          puts "   ❌ Error: #{e.message}"
          errors << "#{theme}: #{e.message}"
        end
      end

      puts "\n" + "=" * 60
      if errors.any?
        puts "❌ Verification failed with #{errors.count} errors"
        errors.each { |e| puts "   • #{e}" }
      else
        puts "✅ All palettes loading correctly!"
      end
    end

    private

    def darken_color(hex, percent)
      # Simple color darkening
      hex = hex.gsub("#", "")
      r = [0, hex[0..1].to_i(16) - (255 * percent / 100)].max
      g = [0, hex[2..3].to_i(16) - (255 * percent / 100)].max
      b = [0, hex[4..5].to_i(16) - (255 * percent / 100)].max
      "#%02x%02x%02x" % [r, g, b]
    end
  end
end
