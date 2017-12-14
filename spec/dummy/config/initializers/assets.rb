# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )

# PWB precompile assets are defined here 
# /pwb/lib/pwb/engine.rb
# and there has not been an issue
# till I added "gem 'property_web_scraper', github: 'RealEstateWebTools/property_web_scraper' "
# to gemfile.
# Now get "Asset was not declared to be precompiled in production" error
# and need to add below to fix that:
Rails.application.config.assets.precompile += %w( pwb/themes/default.css )