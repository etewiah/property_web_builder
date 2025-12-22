# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("app", "assets", "stylesheets", "pwb", "themes")
Rails.application.config.assets.paths << Rails.root.join("app", "assets", "javascripts", "pwb", "themes")

# Add app/javascript for importmap-rails
Rails.application.config.assets.paths << Rails.root.join("app", "javascript")
Rails.application.config.assets.paths << Rails.root.join("app", "javascript", "controllers")

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w[
  pwb_admin_panel/application_legacy_1.css
  pwb/themes/default.css
  default.js
  pwb_admin_panel/application_legacy_1.js
  pwb/config.js
  tailwind-default.css
  tailwind-bologna.css
  tailwind-brisbane.css
]
