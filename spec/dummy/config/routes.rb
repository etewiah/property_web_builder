Rails.application.routes.draw do
  mount Pwb::Engine => '/'

  # mount PropertyWebScraper::Engine => '/io/'

  # comfy_route :cms_admin, :path => '/comfy-admin'
  # # Make sure this routeset is defined last
  # comfy_route :cms, :path => '/comfy', :sitemap => false
end
