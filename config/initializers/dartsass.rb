Rails.application.config.dartsass.builds = {
  "pwb/application.scss" => "pwb/application.css",
  "pwb-admin-manifest.scss" => "pwb-admin.css",
  "pwb/themes/berlin.scss" => "pwb/themes/berlin.css",
  "pwb/themes/chic.scss" => "pwb/themes/chic.css",
  "pwb/themes/default.scss" => "pwb/themes/default.css",
  "pwb/themes/matt.scss" => "pwb/themes/matt.css",
  "pwb/themes/squares.scss" => "pwb/themes/squares.css",
  "pwb/themes/squares.scss" => "pwb/themes/squares.css",
  "pwb/themes/vic.scss" => "pwb/themes/vic.css",
  "pwb_admin_panel/application.scss" => "pwb_admin_panel/application.css"
}

Rails.application.config.dartsass.build_options << " --load-path=app/assets/sass --load-path=vendor/assets/stylesheets"
