# frozen_string_literal: true

namespace :tailwind do
  desc "Build all Tailwind CSS files for themes"
  task :build do
    puts "Building Tailwind CSS for all themes..."

    # Check if npm is available
    unless system("which npm > /dev/null 2>&1")
      puts "WARNING: npm not found, skipping Tailwind build"
      puts "Make sure Node.js is installed for Tailwind CSS compilation"
      next
    end

    # Run npm install if node_modules doesn't exist
    unless File.directory?(Rails.root.join("node_modules"))
      puts "Installing npm dependencies..."
      system("npm install") || raise("npm install failed")
    end

    # Build all theme CSS files
    puts "Running: npm run tailwind:build"
    unless system("npm run tailwind:build")
      raise "Tailwind build failed! Check that tailwindcss is installed correctly."
    end

    puts "Tailwind CSS build completed successfully!"
  end

  desc "Setup git hooks for Tailwind CSS workflow"
  task :setup_hooks do
    puts "Setting up git hooks..."

    hooks_path = Rails.root.join(".githooks")
    unless File.directory?(hooks_path)
      puts "ERROR: .githooks directory not found"
      exit 1
    end

    # Configure git to use .githooks directory
    system("git config core.hooksPath .githooks")

    puts "Git hooks installed successfully!"
    puts "Pre-commit hook will now check Tailwind CSS builds."
  end
end

# Hook into assets:precompile to build Tailwind CSS first
if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance(["tailwind:build"])
end
