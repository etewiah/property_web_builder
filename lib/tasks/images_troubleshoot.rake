
namespace :images do
  namespace :troubleshoot do
    desc "Run full responsive images troubleshooting suite"
    task all: [:environment, :check_dependencies, :check_config, :verify_html, :test_generation]

    desc "Check system dependencies (Vips/ImageMagick)"
    task check_dependencies: :environment do
      headline "Checking Dependencies"

      # Check Config
      processor = Rails.application.config.active_storage.variant_processor
      puts "Configured Variant Processor: :#{processor}"

      if processor == :vips
        if defined?(Vips)
          puts "✅ Vips gem loaded"
          puts "   Vips Version: #{Vips.version}" rescue puts "   (Version unknown)"
        else
          puts "❌ Vips gem NOT loaded. Add 'ruby-vips' to Gemfile."
        end
      elsif processor == :mini_magick
        if defined?(MiniMagick)
          puts "✅ MiniMagick gem loaded"
          puts "   MiniMagick Version: #{MiniMagick.version}" rescue puts "   (Version unknown)"
          
          # Check system install
          cli_version = `magick -version 2>&1` || `convert -version 2>&1`
          if $?.success?
            puts "✅ ImageMagick system library found"
            puts "   #{cli_version.lines.first.strip}"
          else
            puts "❌ ImageMagick NOT found in system PATH"
          end
        else
          puts "❌ MiniMagick gem NOT loaded. Add 'mini_magick' to Gemfile."
        end
      else
        puts "⚠️ Unknown variant processor: #{processor}"
      end
    end

    desc "Check Rails configuration (URL options)"
    task check_config: :environment do
      headline "Checking Configuration"

      # Check default_url_options
      url_options = Rails.application.routes.default_url_options
      if url_options.present? && url_options[:host].present?
        puts "✅ Rails.application.routes.default_url_options set: #{url_options}"
      else
        puts "❌ Rails.application.routes.default_url_options MISSING or empty"
        puts "   Fix: Add to config/environments/#{Rails.env}.rb:"
        puts "   Rails.application.routes.default_url_options = { host: 'localhost', port: 3000 }"
      end

      # Check ActiveStorage::Current (simulated check)
      # In a rake task, this won't be set automatically like in a controller,
      # but we can check if the module is included in controllers.
      controllers_to_check = [
        "Pwb::ApplicationController",
        "ApiPublic::V1::BaseController"
      ]

      controllers_to_check.each do |controller_name|
        begin
          klass = controller_name.constantize
          if klass.ancestors.include?(ActiveStorage::SetCurrent)
            puts "✅ #{controller_name} includes ActiveStorage::SetCurrent"
          else
            puts "❌ #{controller_name} MISSING ActiveStorage::SetCurrent"
            puts "   Fix: Add 'include ActiveStorage::SetCurrent' to #{controller_name}"
          end
        rescue NameError
          puts "⚠️ Could not load #{controller_name}"
        end
      end
    end

    desc "Verify HTML content structure in database"
    task verify_html: :environment do
      headline "Verifying HTML Content"

      # Sample content check
      sample_keys = ['landing_hero', 'about_us_services', 'footer_content_html']
      found_any = false

      sample_keys.each do |key|
        content = Pwb::Content.find_by_page_part_key(key) || Pwb::Content.find_by_key(key)
        next unless content

        found_any = true
        raw_html = content.raw.to_s
        
        puts "Checking '#{key}':"
        
        if raw_html.include?("<picture>")
          puts "✅ Contains <picture> tags"
        elsif raw_html.include?("<img")
          puts "⚠️ Contains <img> tags but NO <picture> tags"
          puts "   Run 'rake images:fix_nested_pictures' or re-save via PagePartManager"
        else
          puts "ℹ️ No images found in content"
        end

        if raw_html.include?("loading=\"lazy\"")
          puts "✅ Lazy loading enabled"
        else
          puts "⚠️ Lazy loading missing"
        end
        puts ""
      end

      unless found_any
        puts "⚠️ No sample content found to check."
      end
    end

    desc "Test variant URL generation"
    task test_generation: :environment do
      headline "Testing Variant URL Generation"

      # Simulate request context
      defaults = Rails.application.routes.default_url_options
      ActiveStorage::Current.url_options = defaults.presence || { host: "localhost", port: 3000 }
      
      # Find valid image
      photo = Pwb::PropPhoto.joins(:image_attachment).first || 
              Pwb::ContentPhoto.joins(:image_attachment).first ||
              Pwb::WebsitePhoto.joins(:image_attachment).first

      if photo
        puts "Testing with #{photo.class.name} ID: #{photo.id}"
        
        begin
          variant = photo.image.variant(resize_to_limit: [100, 100]).processed
          url = variant.url
          puts "✅ Variant generated successfully"
          puts "   URL: #{url}"
        rescue StandardError => e
          puts "❌ Variant generation FAILED"
          puts "   Error: #{e.message}"
          puts "   Cause: #{e.cause.message}" if e.cause
          puts ""
          puts "   Backtrace:"
          puts e.backtrace.take(5).map { |l| "   #{l}" }
        end
      else
        puts "⚠️ No photos with attachments found to test."
      end
    end

    def headline(text)
      puts "\n=== #{text} ==="
      puts "-" * (text.length + 8)
    end
  end
end
