namespace :theme do
  desc "List all available themes"
  task list: :environment do
    themes_dir = Rails.root.join('app/themes')
    themes = Dir.entries(themes_dir).select do |entry|
      File.directory?(themes_dir.join(entry)) && !entry.start_with?('.')
    end

    puts "Available themes:"
    themes.each do |theme|
      config_file = themes_dir.join('config.json')
      if File.exist?(config_file)
        config = JSON.parse(File.read(config_file))
        theme_config = config.find { |t| t['name'] == theme || t['id'] == theme }
        if theme_config
          puts "  - #{theme}: #{theme_config['friendly_name'] || theme_config['description']}"
        else
          puts "  - #{theme}"
        end
      else
        puts "  - #{theme}"
      end
    end
  end

  desc "Set theme for a website (e.g., rake theme:set[tenant-a,bologna])"
  task :set, [:subdomain, :theme_name] => :environment do |_t, args|
    subdomain = args[:subdomain] || 'tenant-a'
    theme_name = args[:theme_name]

    unless theme_name
      puts "Usage: rake theme:set[subdomain,theme_name]"
      puts "Example: rake theme:set[tenant-a,bologna]"
      exit 1
    end

    website = Pwb::Website.find_by(subdomain: subdomain)
    unless website
      puts "Website with subdomain '#{subdomain}' not found"
      exit 1
    end

    # Verify theme exists
    theme_dir = Rails.root.join('app/themes', theme_name)
    unless File.directory?(theme_dir)
      puts "Theme '#{theme_name}' not found in app/themes/"
      exit 1
    end

    website.update!(theme_name: theme_name)
    puts "Set theme '#{theme_name}' for website '#{subdomain}'"
  end

  desc "Test a theme by loading the homepage (e.g., rake theme:test[bologna])"
  task :test, [:theme_name] => :environment do |_t, args|
    theme_name = args[:theme_name]

    unless theme_name
      puts "Usage: rake theme:test[theme_name]"
      exit 1
    end

    # Set theme for tenant-a
    website = Pwb::Website.find_by(subdomain: 'tenant-a')
    unless website
      puts "tenant-a website not found. Run: RAILS_ENV=e2e bin/rails db:seed"
      exit 1
    end

    old_theme = website.theme_name
    website.update!(theme_name: theme_name)
    puts "Testing theme: #{theme_name}"

    # Try to render the homepage
    begin
      require 'action_controller/test_case'

      # Set up the test environment
      Pwb::Current.website = website

      # Create a controller instance
      controller = Pwb::WelcomeController.new
      controller.request = ActionDispatch::TestRequest.create
      controller.request.host = 'tenant-a.e2e.localhost'
      controller.response = ActionDispatch::TestResponse.new

      # Try to render the index
      controller.send(:set_locale)
      controller.index

      puts "  Homepage rendered successfully"
    rescue => e
      puts "  ERROR: #{e.class}: #{e.message}"
      puts "  #{e.backtrace.first(5).join("\n  ")}"
    ensure
      website.update!(theme_name: old_theme) if old_theme != theme_name
    end
  end

  desc "Test all themes and report issues"
  task test_all: :environment do
    themes_dir = Rails.root.join('app/themes')
    themes = Dir.entries(themes_dir).select do |entry|
      File.directory?(themes_dir.join(entry)) && !entry.start_with?('.')
    end

    results = {}

    themes.each do |theme_name|
      puts "\n=== Testing theme: #{theme_name} ==="

      website = Pwb::Website.find_by(subdomain: 'tenant-a')
      unless website
        puts "tenant-a website not found. Run: RAILS_ENV=e2e bin/rails db:seed"
        exit 1
      end

      website.update!(theme_name: theme_name)

      begin
        Pwb::Current.website = website

        # Test by checking if view files exist and have valid ERB syntax
        views_dir = themes_dir.join(theme_name, 'views')
        if File.directory?(views_dir)
          erb_files = Dir.glob(views_dir.join('**/*.erb'))
          erb_errors = []

          erb_files.each do |file|
            begin
              content = File.read(file)
              # Basic ERB syntax check
              ERB.new(content)
            rescue SyntaxError => e
              erb_errors << { file: file.sub(views_dir.to_s, ''), error: e.message }
            end
          end

          if erb_errors.any?
            results[theme_name] = { status: :erb_errors, errors: erb_errors }
            erb_errors.each do |err|
              puts "  ERB Error in #{err[:file]}: #{err[:error]}"
            end
          else
            results[theme_name] = { status: :ok, file_count: erb_files.count }
            puts "  OK - #{erb_files.count} ERB files checked"
          end
        else
          results[theme_name] = { status: :no_views }
          puts "  No views directory found"
        end
      rescue => e
        results[theme_name] = { status: :error, error: "#{e.class}: #{e.message}" }
        puts "  ERROR: #{e.class}: #{e.message}"
      end
    end

    puts "\n=== Summary ==="
    results.each do |theme, result|
      case result[:status]
      when :ok
        puts "  #{theme}: OK (#{result[:file_count]} files)"
      when :erb_errors
        puts "  #{theme}: ERB ERRORS (#{result[:errors].count})"
      when :no_views
        puts "  #{theme}: No views"
      when :error
        puts "  #{theme}: ERROR - #{result[:error]}"
      end
    end
  end
end
