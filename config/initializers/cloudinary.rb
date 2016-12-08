Cloudinary.config do |config|
  cloudinary_url = Rails.application.secrets.cloudinary_url

  uri = URI.parse(cloudinary_url)
  config.api_key = uri.user
  config.api_secret = uri.password
  config.cloud_name = uri.host
end