# frozen_string_literal: true

namespace :assets do
  desc "Generate Font Awesome subset with only icons used in the application"
  task font_awesome_subset: :environment do
    require 'yaml'
    require 'fileutils'

    public_fonts_dir = Rails.root.join('public/fonts/fontawesome-subset')
    vendor_fonts_dir = Rails.root.join('vendor/assets/fonts/fontawesome-subset')

    # Skip if fonts already exist in public (already generated)
    if Dir.exist?(public_fonts_dir) && Dir.glob("#{public_fonts_dir}/*.woff2").any?
      puts "Font Awesome subset already exists in public/fonts - skipping generation"
      next
    end

    icons_config = YAML.load_file(Rails.root.join('config/font_awesome_icons.yml'))
    solid_icons = icons_config['solid'] || []
    brand_icons = icons_config['brands'] || []

    puts "Font Awesome Subset Generator"
    puts "=" * 50
    puts "Solid icons: #{solid_icons.count}"
    puts "Brand icons: #{brand_icons.count}"
    puts "Total icons: #{solid_icons.count + brand_icons.count}"
    puts

    # Check if npx is available
    unless system('which npx > /dev/null 2>&1')
      puts "Warning: npx not found. Using pre-generated fonts from public/fonts."
      next
    end

    # Check if fontawesome-subset is installed
    unless system('npm list fontawesome-subset > /dev/null 2>&1')
      puts "Installing fontawesome-subset..."
      unless system('npm install --save-dev fontawesome-subset @fortawesome/fontawesome-free')
        puts "Warning: Could not install fontawesome-subset. Using pre-generated fonts."
        next
      end
    end

    # Create subset script
    script_content = <<~JS
      const { fontawesomeSubset } = require('fontawesome-subset');

      const solidIcons = #{solid_icons.to_json};
      const brandIcons = #{brand_icons.to_json};

      fontawesomeSubset({
        solid: solidIcons,
        brands: brandIcons
      }, 'vendor/assets/fonts/fontawesome-subset', {
        targetFormats: ['woff2', 'woff']
      });

      console.log('Font Awesome subset generated successfully!');
    JS

    script_path = Rails.root.join('tmp/generate_fa_subset.js')
    File.write(script_path, script_content)

    # Run the script
    puts "Generating Font Awesome subset..."
    if system("node #{script_path}")
      # Copy to public directory
      FileUtils.mkdir_p(public_fonts_dir)
      FileUtils.cp_r(Dir.glob("#{vendor_fonts_dir}/*"), public_fonts_dir)
      puts "Success! Fonts copied to public/fonts/fontawesome-subset/"
    else
      puts "Warning: Font generation failed. Using pre-generated fonts if available."
    end

    # Cleanup
    FileUtils.rm_f(script_path)
  end

  # Hook into assets:precompile to ensure FA subset is generated first
  # This runs automatically during Dokku/Heroku deployment
  Rake::Task['assets:precompile'].enhance(['assets:font_awesome_subset'])

  desc "List Font Awesome icons used in the application"
  task font_awesome_audit: :environment do
    puts "Scanning for Font Awesome icons..."
    puts

    icons = {}
    glob_pattern = Rails.root.join('app/**/*.{erb,html,yml}')

    Dir.glob(glob_pattern).each do |file|
      content = File.read(file)
      matches = content.scan(/fa-([a-z0-9-]+)/)
      matches.flatten.each do |icon|
        next if %w[2x 4x lg spin].include?(icon) # Skip utility classes
        icons[icon] ||= []
        icons[icon] << file.sub(Rails.root.to_s, '')
      end
    end

    puts "Icons found: #{icons.keys.count}"
    puts
    icons.keys.sort.each do |icon|
      puts "  fa-#{icon}"
    end
    puts
    puts "Update config/font_awesome_icons.yml with any missing icons."
  end
end
