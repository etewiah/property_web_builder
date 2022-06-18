Cloudinary.config do |config|
  cloudinary_url = ENV["CLOUDINARY_URL"]
  # If deploying to heroku, set ENV['CLOUDINARY_URL'] in secrets.yml so above works
  if cloudinary_url.present?
    uri = URI.parse(cloudinary_url)
    config.api_key = uri.user
    config.api_secret = uri.password
    config.cloud_name = uri.host
    Rails.application.config.use_cloudinary = true
  else
    Rails.application.config.use_cloudinary = false
  end
end
