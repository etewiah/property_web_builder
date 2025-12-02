namespace :bristol do
  desc "Build Bristol theme CSS"
  task :build => :environment do
    # Find the executable path
    # Try different ways to find it
    executable = nil
    begin
      executable = Gem.bin_path("tailwindcss-rails", "tailwindcss")
    rescue Gem::GemNotFoundException
      # Fallback to looking in the gem directory
      gem_path = Gem::Specification.find_by_name("tailwindcss-rails").gem_dir
      executable = File.join(gem_path, "exe", "tailwindcss")
    end

    unless File.exist?(executable)
      # Try to find the platform specific binary if it exists
      # But usually the 'tailwindcss' in exe is a wrapper or the binary itself
      # Let's try to find it in the gem dir recursively if needed, but simple first
      puts "Could not find tailwindcss executable at #{executable}"
      # Try to find the upstream executable
      require "tailwindcss/upstream"
      executable = Tailwindcss::Upstream::EXECUTABLE
    end
    
    input = Rails.root.join("app/assets/tailwind/application.css").to_s
    output = Rails.root.join("app/assets/builds/bristol_theme.css").to_s
    
    command = "#{executable} -i #{input} -o #{output} --minify"
    puts "Running: #{command}"
    system(command)
  end
  
  desc "Watch Bristol theme CSS"
  task :watch => :environment do
    # Copy of build logic for finding executable
    executable = nil
    begin
      executable = Gem.bin_path("tailwindcss-rails", "tailwindcss")
    rescue Gem::GemNotFoundException
      gem_path = Gem::Specification.find_by_name("tailwindcss-rails").gem_dir
      executable = File.join(gem_path, "exe", "tailwindcss")
    end

    unless File.exist?(executable)
      require "tailwindcss/upstream"
      executable = Tailwindcss::Upstream::EXECUTABLE
    end

    input = Rails.root.join("app/assets/tailwind/application.css").to_s
    output = Rails.root.join("app/assets/builds/bristol_theme.css").to_s
    
    command = "#{executable} -i #{input} -o #{output} --watch"
    puts "Running: #{command}"
    system(command)
  end
end
