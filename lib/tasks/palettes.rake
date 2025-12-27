# frozen_string_literal: true

namespace :palettes do
  desc "Validate all theme palettes"
  task validate: :environment do
    loader = Pwb::PaletteLoader.new
    themes = %w[default brisbane bologna barcelona biarritz]

    puts "Validating theme palettes..."
    puts "=" * 60

    all_valid = true

    themes.each do |theme|
      puts "\n#{theme.upcase} Theme:"
      puts "-" * 40

      results = loader.validate_theme_palettes(theme)

      if results[:error]
        puts "  ERROR: #{results[:error]}"
        all_valid = false
        next
      end

      results.each do |file, result|
        status = result[:valid] ? "\e[32mVALID\e[0m" : "\e[31mINVALID\e[0m"
        puts "  #{file}: #{status}"

        result[:errors].each do |error|
          puts "    \e[31mError: #{error}\e[0m"
          all_valid = false
        end

        result[:warnings].each do |warning|
          puts "    \e[33mWarning: #{warning}\e[0m"
        end
      end
    end

    puts "\n" + "=" * 60
    if all_valid
      puts "\e[32mAll palettes are valid!\e[0m"
    else
      puts "\e[31mSome palettes have validation errors.\e[0m"
      exit 1
    end
  end

  desc "List all available palettes for each theme"
  task list: :environment do
    loader = Pwb::PaletteLoader.new
    themes = %w[default brisbane bologna barcelona biarritz]

    puts "Available Theme Palettes"
    puts "=" * 60

    themes.each do |theme|
      puts "\n#{theme.upcase} Theme:"
      puts "-" * 40

      palettes = loader.list_palettes(theme)
      if palettes.empty?
        puts "  No palettes found"
        next
      end

      palettes.each do |palette|
        default_marker = palette[:is_default] ? " (default)" : ""
        puts "  #{palette[:id]}#{default_marker}"
        puts "    Name: #{palette[:name]}"
        puts "    Description: #{palette[:description]}"
        puts "    Preview: #{palette[:preview_colors].join(', ')}" if palette[:preview_colors]
      end
    end
  end

  desc "Generate CSS custom properties for a theme palette"
  task :css, [:theme, :palette] => :environment do |_t, args|
    theme = args[:theme] || "default"
    palette = args[:palette]

    loader = Pwb::PaletteLoader.new
    css = loader.generate_css_variables(theme, palette)

    if css.empty?
      puts "No palette found for theme '#{theme}'"
      exit 1
    end

    puts ":root {"
    puts "  #{css}"
    puts "}"
  end

  desc "Generate all shade variants for main colors"
  task :shades, [:hex] => :environment do |_t, args|
    hex = args[:hex]

    unless hex
      puts "Usage: rake palettes:shades[#3498db]"
      exit 1
    end

    puts "Shade scale for #{hex}:"
    puts "-" * 40

    shades = Pwb::ColorUtils.generate_shade_scale(hex)
    shades.each do |step, color|
      puts "  #{step}: #{color}"
    end
  end

  desc "Check contrast ratios for a palette"
  task :contrast, [:theme, :palette] => :environment do |_t, args|
    theme = args[:theme] || "default"
    palette_id = args[:palette]

    loader = Pwb::PaletteLoader.new
    palette = palette_id ? loader.get_palette(theme, palette_id) : loader.get_default_palette(theme)

    unless palette
      puts "Palette not found"
      exit 1
    end

    colors = palette["colors"]
    puts "Contrast Ratios for #{palette['name']}"
    puts "=" * 60

    checks = [
      ["Header", colors["header_text_color"], colors["header_background_color"]],
      ["Footer", colors["footer_text_color"], colors["footer_background_color"]],
      ["Body text on background", colors["text_color"], colors["background_color"]],
      ["Primary on background", colors["primary_color"], colors["background_color"]],
      ["Link on background", colors["link_color"], colors["background_color"]]
    ]

    checks.each do |name, fg, bg|
      next unless fg && bg

      ratio = Pwb::ColorUtils.contrast_ratio(fg, bg)
      aa_normal = ratio >= 4.5
      aa_large = ratio >= 3.0

      status = if aa_normal
                 "\e[32mAA (Normal & Large)\e[0m"
               elsif aa_large
                 "\e[33mAA (Large text only)\e[0m"
               else
                 "\e[31mFails AA\e[0m"
               end

      puts "#{name}:"
      puts "  #{fg} on #{bg}"
      puts "  Ratio: #{ratio.round(2)}:1 - #{status}"
      puts
    end
  end

  desc "Migrate palettes from config.json to separate files"
  task migrate: :environment do
    themes_path = Rails.root.join("app/themes")
    config_path = themes_path.join("config.json")

    unless File.exist?(config_path)
      puts "config.json not found"
      exit 1
    end

    themes = JSON.parse(File.read(config_path))
    validator = Pwb::PaletteValidator.new

    themes.each do |theme|
      theme_name = theme["name"]
      palettes = theme["palettes"]

      next unless palettes

      palettes_dir = themes_path.join(theme_name, "palettes")
      FileUtils.mkdir_p(palettes_dir)

      palettes.each do |id, palette_data|
        # Normalize the palette
        result = validator.validate(palette_data)

        # Write to separate file
        file_path = palettes_dir.join("#{id}.json")

        if File.exist?(file_path)
          puts "Skipping #{file_path} (already exists)"
          next
        end

        File.write(file_path, JSON.pretty_generate(result.normalized_palette))
        puts "Created #{file_path}"

        result.warnings.each do |warning|
          puts "  Warning: #{warning}"
        end
      end
    end

    puts "\nMigration complete!"
    puts "Run 'rake palettes:validate' to verify all palettes."
  end
end
