Cloudinary.config do |config|
  cloudinary_url = Rails.application.secrets.cloudinary_url
  # If deploying to heroku, set below in secrets.yml so above works
  #   cloudinary_url: <%= ENV['CLOUDINARY_URL'] %>
  if cloudinary_url
    uri = URI.parse(cloudinary_url)
    config.api_key = uri.user
    config.api_secret = uri.password
    config.cloud_name = uri.host
    Rails.application.config.use_cloudinary = true
  else
    Rails.application.config.use_cloudinary = false
  end
end
