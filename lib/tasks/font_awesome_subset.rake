# frozen_string_literal: true

namespace :assets do
  desc "Generate Font Awesome subset with only icons used in the application"
  task font_awesome_subset: :environment do
    require 'yaml'
    require 'fileutils'

    icons_config = YAML.load_file(Rails.root.join('config/font_awesome_icons.yml'))
    solid_icons = icons_config['solid'] || []
    brand_icons = icons_config['brands'] || []

    puts "Font Awesome Subset Generator"
    puts "=" * 50
    puts "Solid icons: #{solid_icons.count}"
    puts "Brand icons: #{brand_icons.count}"
    puts "Total icons: #{solid_icons.count + brand_icons.count}"
    puts

    # Check if fontawesome-subset is installed
    unless system('which npx > /dev/null 2>&1')
      puts "Error: npx not found. Please install Node.js."
      exit 1
    end

    # Create package.json if needed
    package_json = Rails.root.join('package.json')
    unless File.exist?(package_json)
      File.write(package_json, '{"private": true, "devDependencies": {}}')
    end

    # Install fontawesome-subset if not present
    puts "Checking fontawesome-subset installation..."
    unless system('npm list fontawesome-subset > /dev/null 2>&1')
      puts "Installing fontawesome-subset..."
      system('npm install --save-dev fontawesome-subset @fortawesome/fontawesome-free')
    end

    # Create subset script
    script_content = <<~JS
      const fontawesomeSubset = require('fontawesome-subset');

      const solidIcons = #{solid_icons.to_json};
      const brandIcons = #{brand_icons.to_json};

      fontawesomeSubset({
        solid: solidIcons,
        brands: brandIcons
      }, 'vendor/assets/fonts/fontawesome-subset', {
        targetFormats: ['woff2', 'woff']
      });

      console.log('Font Awesome subset generated successfully!');
      console.log('Output: vendor/assets/fonts/fontawesome-subset/');
    JS

    script_path = Rails.root.join('tmp/generate_fa_subset.js')
    File.write(script_path, script_content)

    # Run the script
    puts "Generating Font Awesome subset..."
    if system("node #{script_path}")
      puts "Success! Subset generated at vendor/assets/fonts/fontawesome-subset/"
      puts
      puts "To use the subset, update your layout to reference:"
      puts "  - vendor/assets/fonts/fontawesome-subset/css/fontawesome.min.css"
      puts "  - vendor/assets/fonts/fontawesome-subset/css/solid.min.css"
      puts "  - vendor/assets/fonts/fontawesome-subset/css/brands.min.css"
    else
      puts "Error generating subset. See output above for details."
    end

    # Cleanup
    FileUtils.rm_f(script_path)
  end

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
