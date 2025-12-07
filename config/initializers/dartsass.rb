Rails.application.config.dartsass.builds = {
  "../../stylesheets/pwb/application.scss" => "pwb/application.css",
  "../../stylesheets/pwb-admin-manifest.scss" => "pwb-admin.css",
  "../../stylesheets/pwb/themes/berlin.scss" => "pwb/themes/berlin.css",
  "../../stylesheets/pwb/themes/chic.scss" => "pwb/themes/chic.css",
  "../../stylesheets/pwb/themes/default.scss" => "pwb/themes/default.css",
  "../../stylesheets/pwb/themes/squares.scss" => "pwb/themes/squares.css",
  "../../stylesheets/pwb_admin_panel/application.scss" => "pwb_admin_panel/application.css"
}

Rails.application.config.dartsass.build_options << " --load-path=app/stylesheets --load-path=vendor/assets/stylesheets"
