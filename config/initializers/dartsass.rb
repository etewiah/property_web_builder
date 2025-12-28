Rails.application.config.dartsass.builds = {
  "../../stylesheets/pwb/application.scss" => "pwb/application.css",
  "../../stylesheets/pwb/themes/default.scss" => "pwb/themes/default.css"
}

Rails.application.config.dartsass.build_options << " --load-path=app/stylesheets --load-path=vendor/assets/stylesheets"
