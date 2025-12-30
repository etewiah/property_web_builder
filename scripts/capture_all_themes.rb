#!/usr/bin/env ruby
# Script to capture screenshots for all themes
# Run with: bundle exec rails runner scripts/capture_all_themes.rb

require 'open3'

THEMES = ['default', 'barcelona', 'biarritz', 'bologna', 'brisbane']
SCREENSHOT_SCRIPT = Rails.root.join('scripts', 'take-screenshots.js')

website = Pwb::Website.first
original_theme = website.theme_name

puts "Starting multi-theme screenshot capture..."
puts "Current theme: #{original_theme || 'default'}"

THEMES.each do |theme|
  puts "\n" + "="*50
  puts "Switching to theme: #{theme}"
  puts "="*50

  # Update the website theme
  website.update!(theme_name: theme)
  puts "Theme updated to: #{website.reload.theme_name || 'default'}"

  # Clear Rails cache to ensure theme change takes effect
  Rails.cache.clear if Rails.cache.respond_to?(:clear)

  # Run the screenshot script with theme-specific output
  env = { 'SCREENSHOT_THEME' => theme }
  stdout, stderr, status = Open3.capture3(env, "node #{SCREENSHOT_SCRIPT}")

  puts stdout unless stdout.empty?
  puts stderr unless stderr.empty?

  if status.success?
    puts "Screenshots captured for #{theme} theme"
  else
    puts "Error capturing screenshots for #{theme}"
  end
end

# Restore original theme
puts "\n" + "="*50
puts "Restoring original theme: #{original_theme || 'default'}"
website.update!(theme_name: original_theme)
puts "Done!"
